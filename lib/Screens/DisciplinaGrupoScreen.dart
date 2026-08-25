import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/ConfigDisciplinaModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Models/UniformeModel.dart';
import 'package:myvc_flutter/Screens/FaltasAlumnoScreen.dart';
import 'package:myvc_flutter/Screens/FichaDisciplinaScreen.dart';
import 'package:myvc_flutter/Screens/SituacionEditorScreen.dart';
import 'package:myvc_flutter/Screens/UniformesAlumnoScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/TextoPlano.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/SelectorGrupo.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La disciplina de un grupo: quién lleva qué, en los cuatro periodos.
///
/// Es la pantalla `/disciplina` del front web. Allí es una tabla con una
/// columna por periodo y cinco contadores en cada celda; aquí cada alumno es
/// una tarjeta con la tira de los cuatro periodos, y al desplegarla salen los
/// seis contadores de uno de ellos. Cambia la forma porque cuatro columnas de
/// contadores no caben en un teléfono, no lo que se cuenta.
///
/// Se arma con dos llamadas:
///
///   PUT grupos/con-disciplina    grupos, ordinales, config y sugerencias
///   PUT disciplina/alumnos       los alumnos del grupo, con su año entero
///
/// La segunda trae los cuatro periodos de golpe, así que cambiar de periodo en
/// la barra de arriba no pide nada al servidor: solo cambia lo que se pinta.
/// Cambiar de AÑO sí recarga todo, porque los grupos son de un año.
class DisciplinaGrupoScreen extends StatefulWidget {
  const DisciplinaGrupoScreen({super.key});

  @override
  State<DisciplinaGrupoScreen> createState() => _DisciplinaGrupoScreenState();
}

class _DisciplinaGrupoScreenState extends State<DisciplinaGrupoScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  /// El grupo que se estaba mirando la última vez.
  ///
  /// Con clave propia y no la de la pantalla de asistencias: son dos trabajos
  /// distintos y quien pasa la lista de 6-A no tiene por qué acabar anotando
  /// disciplina en 6-A.
  /// Lleva el id del usuario, como [PreferenciaFiltroAsignaturas] y
  /// [PreferenciaGrupo]: en el equipo compartido de la entrada, una clave a
  /// secas dejaba puesto el grupo del docente anterior.
  static String _clavePreferencia() =>
      'disciplinaGrupo.${AuthService.user.id ?? 0}';

  DatosDisciplina? datos;
  List<GrupoModel> grupos = [];
  GrupoModel? grupo;

  List<AlumnoDisciplinaModel> alumnos = [];

  /// Los docentes del colegio, para el selector del editor, y el cruce de
  /// user_id a nombre para decir quién registró cada situación. Salen de la
  /// misma respuesta de /contratos.
  List<DocenteModel> docentes = [];
  Map<int, String> nombresPorUsuario = {};

  /// Qué alumnos tienen la tarjeta desplegada y por qué periodo.
  final Map<int, int> desplegados = {};

  String busqueda = '';

  bool cargando = true;
  bool cargandoAlumnos = false;
  String? error;

  int get periodoActual => ContextoAcademico.instancia.numeroPeriodo ?? 1;

  ConfigDisciplinaModel get config =>
      datos?.config ?? ConfigDisciplinaModel();

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _arrancar() async {
    setState(() {
      cargando = true;
      error = null;
      alumnos = [];
      desplegados.clear();
    });

    try {
      // Los periodos del año hacen falta para poder crear algo en uno que no
      // sea el de la barra: el backend pide el `periodo_id` y el número no le
      // vale. Si falla, la pantalla sigue y solo se puede escribir en el
      // periodo en curso.
      final losAnios = ContextoAcademico.instancia
          .cargarYears(server)
          .catchError((_) {});

      final traidos = await traerDatosDeDisciplina(server);
      final permitidos = await _gruposDelUsuario(traidos.grupos);

      await losAnios;

      setState(() {
        datos = traidos;
        grupos = permitidos;
        cargando = false;
        error = permitidos.isEmpty
            ? 'No hay ningún grupo a tu nombre en este año.'
            : null;
      });

      // No se espera: son nombres para adornar el editor, y la lista de
      // alumnos es lo que se ha venido a ver.
      _cargarDocentes();

      if (permitidos.isEmpty) return;

      final guardado = await _grupoGuardado(permitidos);
      setState(() => grupo = guardado ?? permitidos.first);

      await _cargarAlumnos();
    } catch (err) {
      setState(() {
        cargando = false;
        error = '$err';
      });
    }
  }

  /// Los grupos que le tocan a quien está mirando.
  ///
  /// `grupos/con-disciplina` devuelve TODOS los del año —el backend no filtra—,
  /// así que el recorte es de aquí:
  ///
  ///  - Quien es especial —superusuario, admin, coordinación— los ve todos.
  ///  - Un docente ve aquellos donde tiene asignatura, más el que sea suyo por
  ///    ser titular aunque no le dé ninguna clase.
  ///  - A quien no es ninguna de las dos cosas —una secretaría, sin rol de
  ///    coordinación— se le enseñan todos: no da clase en ninguno, así que
  ///    filtrar por asignaturas le dejaría la pantalla en blanco, y el backend
  ///    ya decidió que es personal del colegio al dejarle pasar.
  Future<List<GrupoModel>> _gruposDelUsuario(List<GrupoModel> todos) async {
    final usuario = AuthService.user;

    if (usuario.esEspecial || !usuario.esDocente) return todos;

    final mios = <int>{};
    try {
      final asignaturas = await traerAsignaturasConUnidades(server);
      for (final asignatura in asignaturas) {
        mios.add(asignatura.asignatura.grupoId);
      }
    } catch (_) {
      // Sin sus asignaturas queda al menos el grupo del que es titular, que es
      // mejor que una pantalla vacía sin explicación.
    }

    final personaId = usuario.personaId;

    return todos
        .where((grupo) =>
            mios.contains(grupo.id) ||
            (personaId != null && grupo.titularId == personaId))
        .toList();
  }

  /// Los docentes y, de la misma respuesta, el cruce de user_id a nombre.
  ///
  /// Una sola llamada a /contratos para las dos cosas: son la misma lista
  /// indexada por dos claves distintas —`profesor_id` para elegir docente,
  /// `user_id` para decir quién registró—, y pedirla dos veces era pedir lo
  /// mismo dos veces.
  Future<void> _cargarDocentes() async {
    try {
      final traidos = await traerDocentesDelColegio(server);

      setState(() {
        docentes = traidos;
        nombresPorUsuario = {
          for (final docente in traidos)
            if (docente.userId != null) docente.userId!: docente.nombre
        };
      });
    } catch (_) {
      // El editor se abre igual, solo que sin poder elegir docente.
    }
  }

  Future<GrupoModel?> _grupoGuardado(List<GrupoModel> disponibles) async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final id = preferencias.getInt(_clavePreferencia());
      if (id == null) return null;

      for (final candidato in disponibles) {
        if (candidato.id == id) return candidato;
      }
    } catch (_) {
      // Si no se pudo leer, se arranca con el primero. No es un error que
      // merezca contarse.
    }
    return null;
  }

  Future<void> _cargarAlumnos() async {
    final elegido = grupo;
    final yearId = ContextoAcademico.instancia.yearId;

    if (elegido == null || yearId == null) return;

    setState(() {
      cargandoAlumnos = true;
      error = null;
      desplegados.clear();
    });

    try {
      final traidos = await traerAlumnosConDisciplina(
        server,
        grupoId: elegido.id,
        yearId: yearId,
      );

      setState(() {
        alumnos = traidos;
        cargandoAlumnos = false;
      });
    } catch (err) {
      setState(() {
        cargandoAlumnos = false;
        alumnos = [];
        error = '$err';
      });
    }
  }

  Future<void> _elegirGrupo(GrupoModel elegido) async {
    setState(() {
      grupo = elegido;
      alumnos = [];
    });

    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setInt(_clavePreferencia(), elegido.id);
    } catch (_) {
      // Que no se recuerde el grupo no impide mirarlo ahora.
    }

    await _cargarAlumnos();
  }

  /// Los alumnos que responden a lo que se está buscando.
  ///
  /// Sin acentos y en minúsculas: quien busca «Peña» escribe «pena».
  List<AlumnoDisciplinaModel> get _filtrados => alumnos
      .where((alumno) => coincideConBusqueda(alumno.nombreCompleto, busqueda))
      .toList();

  void _reemplazar(AlumnoDisciplinaModel nuevo) {
    setState(() {
      alumnos = [
        for (final alumno in alumnos)
          alumno.alumnoId == nuevo.alumnoId ? nuevo : alumno
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: _drawerController,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        body: BarraPlegable(
          titulo: 'Disciplina',
          alAbrirMenu: () => _drawerController.toggle!(),
          alCambiarContexto: _arrancar,
          actions: [
            IconButton(
              tooltip: 'Volver a traer el grupo',
              icon: Icon(Icons.refresh),
              onPressed: cargandoAlumnos ? null : _cargarAlumnos,
            ),
          ],
          child: _cuerpo(),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (cargando) return Center(child: CircularProgressIndicator());

    if (grupos.isEmpty) return _elError();

    return Column(
      children: [
        CampoGrupo(
          grupos: grupos,
          elegido: grupo,
          alElegir: _elegirGrupo,
        ),
        if (alumnos.length > 10) _buscador(),
        Expanded(child: _listado()),
      ],
    );
  }

  Widget _elError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudo abrir la disciplina.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(error ?? 'No hay grupos que mirar.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _arrancar, child: Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Buscar alumno',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (texto) => setState(() => busqueda = texto),
      ),
    );
  }

  Widget _listado() {
    if (cargandoAlumnos) return Center(child: CircularProgressIndicator());

    if (error != null) return _elError();

    final lista = _filtrados;

    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            alumnos.isEmpty
                ? 'Este grupo no tiene alumnos matriculados.'
                : 'Ningún alumno se llama así.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: Analitica.refresco('disciplina-grupo', _cargarAlumnos),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: lista.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, i) => _tarjeta(lista[i], i + 1),
      ),
    );
  }

  Widget _tarjeta(AlumnoDisciplinaModel alumno, int numero) {
    final abierto = desplegados[alumno.alumnoId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          onTap: () => _abrirFicha(alumno, abierto ?? periodoActual),
          leading: AvatarPersona(
            nombre: alumno.nombreCompleto,
            fotoNombre: alumno.fotoNombre,
            radio: 20,
          ),
          title: Row(
            children: [
              Text('$numero. ',
                  style: TextStyle(color: Colors.black38, fontSize: 12)),
              Expanded(
                child: Text(
                  alumno.nombreCompleto,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        alumno.esAsistente ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _tiraDePeriodos(alumno, abierto),
          ),
          trailing: IconButton(
            tooltip: 'Anotar en el periodo $periodoActual',
            icon: Icon(Icons.add_circle_outline, color: kPrimaryColor),
            onPressed: () => _crearSituacion(alumno, periodoActual),
          ),
        ),
        if (abierto != null) _panel(alumno, abierto),
      ],
    );
  }

  /// Los cuatro periodos con su total, que es el resumen que se ve sin abrir
  /// nada.
  ///
  /// Un número por periodo y no seis: seis contadores por cuatro periodos son
  /// veinticuatro cifras en una fila de lista, y ahí ya no se distingue al
  /// alumno que lleva nueve del que lleva una. El total dice a cuál entrar, y
  /// al tocarlo se abre el desglose de ese periodo.
  Widget _tiraDePeriodos(AlumnoDisciplinaModel alumno, int? abierto) {
    final periodos = alumno.periodos.isEmpty ? [1, 2, 3, 4] : alumno.periodos;

    return Row(
      children: [
        for (final numero in periodos)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _Periodo(
              numero: numero,
              cuantos: alumno.totalDe(numero),
              graves: alumno.tieneGravesEn(numero),
              elDeLaBarra: numero == periodoActual,
              abierto: numero == abierto,
              alTocar: () => setState(() {
                if (desplegados[alumno.alumnoId] == numero) {
                  desplegados.remove(alumno.alumnoId);
                } else {
                  desplegados[alumno.alumnoId] = numero;
                }
              }),
            ),
          ),
      ],
    );
  }

  /// El desglose de un periodo: los seis contadores, cada uno con su sitio a
  /// donde ir.
  Widget _panel(AlumnoDisciplinaModel alumno, int periodo) {
    return Container(
      width: double.infinity,
      color: kPrimaryColor.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periodo $periodo',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Contador(
                icono: Icons.checkroom_outlined,
                rotulo: 'Uniforme',
                cuantos: alumno.cuantosUniformes(periodo),
                alTocar: () => _abrirUniformes(alumno, periodo),
              ),
              _Contador(
                icono: Icons.schedule_outlined,
                rotulo: 'Tardanzas',
                color: kColorTardanza,
                cuantos: alumno.cuantasFaltas(periodo, TipoFalta.tardanza),
                alTocar: () => _abrirFaltas(alumno),
              ),
              _Contador(
                icono: Icons.event_busy_outlined,
                rotulo: 'Ausencias',
                color: kColorAusencia,
                cuantos: alumno.cuantasFaltas(periodo, TipoFalta.ausencia),
                alTocar: () => _abrirFaltas(alumno),
              ),
              for (final tipo in ConfigDisciplinaModel.tipos)
                _Contador(
                  rotulo: config.abreviado(tipo),
                  cuantos: alumno.cuantasSituaciones(periodo, tipo),
                  alTocar: () => _abrirFicha(alumno, periodo),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _crearSituacion(alumno, periodo),
                icon: Icon(Icons.add, size: 18),
                label: Text('Anotar aquí'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _abrirFicha(alumno, periodo),
                child: Text('Ver la ficha'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFicha(AlumnoDisciplinaModel alumno, int periodo) async {
    final losDatos = datos;
    final elGrupo = grupo;
    if (losDatos == null || elGrupo == null) return;

    final actualizado = await Navigator.push<AlumnoDisciplinaModel>(
      context,
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'ficha-disciplina'),
        builder: (_) => FichaDisciplinaScreen(
          args: FichaDisciplinaArgs(
            alumno: alumno,
            datos: losDatos,
            docentes: docentes,
            nombresPorUsuario: nombresPorUsuario,
            grupoId: elGrupo.id,
            periodoInicial: periodo,
          ),
        ),
      ),
    );

    if (actualizado != null) _reemplazar(actualizado);
  }

  /// El atajo de la lista: anotar sin pasar por la ficha.
  Future<void> _crearSituacion(
    AlumnoDisciplinaModel alumno,
    int periodo,
  ) async {
    final losDatos = datos;
    if (losDatos == null) return;

    final periodoId = ContextoAcademico.instancia.periodoIdDe(periodo);
    if (periodoId == null) {
      _avisar('No se sabe cuál es el periodo $periodo de este año.');
      return;
    }

    final actualizado = await Navigator.push<AlumnoDisciplinaModel>(
      context,
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'situacion-editor'),
        builder: (_) => SituacionEditorScreen(
          args: SituacionEditorArgs(
            alumno: alumno,
            datos: losDatos,
            numeroPeriodo: periodo,
            periodoId: periodoId,
            docentes: docentes,
          ),
        ),
      ),
    );

    if (actualizado != null) {
      _reemplazar(actualizado);
      // Se deja abierto el periodo en el que se acaba de anotar, para que se
      // vea que el contador subió.
      setState(() => desplegados[alumno.alumnoId] = periodo);
    }
  }

  Future<void> _abrirUniformes(
    AlumnoDisciplinaModel alumno,
    int periodo,
  ) async {
    final periodoId = ContextoAcademico.instancia.periodoIdDe(periodo);
    if (periodoId == null) {
      _avisar('No se sabe cuál es el periodo $periodo de este año.');
      return;
    }

    final devueltas = await Navigator.push<List<UniformeModel>>(
      context,
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'disciplina-uniformes'),
        builder: (_) => UniformesAlumnoScreen(
          args: UniformesAlumnoArgs(
            alumnoId: alumno.alumnoId,
            nombre: alumno.nombreCompleto,
            fotoNombre: alumno.fotoNombre,
            numeroPeriodo: periodo,
            periodoId: periodoId,
            uniformes: alumno.uniformesDe(periodo),
          ),
        ),
      ),
    );

    if (devueltas != null) {
      _reemplazar(alumno.conUniformesDe(periodo, devueltas));
    }
  }

  Future<void> _abrirFaltas(AlumnoDisciplinaModel alumno) async {
    final elGrupo = grupo;
    if (elGrupo == null) return;

    await Navigator.pushNamed(
      context,
      '/faltas-alumno',
      arguments: FaltasAlumnoArgs(
        alumnoId: alumno.alumnoId,
        nombre: alumno.nombreCompleto,
        grupoId: elGrupo.id,
        fotoNombre: alumno.fotoNombre,
      ),
    );

    // Allí se pueden corregir fechas y eso no vuelve por ninguna respuesta:
    // se relee el grupo para que los contadores no se queden viejos.
    await _cargarAlumnos();
  }
}

/// Un periodo dentro de la tira, con lo que lleva.
class _Periodo extends StatelessWidget {
  const _Periodo({
    required this.numero,
    required this.cuantos,
    required this.graves,
    required this.elDeLaBarra,
    required this.abierto,
    required this.alTocar,
  });

  final int numero;
  final int cuantos;

  /// Si hay alguna situación de tipo 2 o 3. Se señala en rojo: no es lo mismo
  /// llevar nueve tardanzas que una expulsión.
  final bool graves;

  /// Si es el periodo en el que está trabajando el usuario.
  final bool elDeLaBarra;

  final bool abierto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final hay = cuantos > 0;
    final tono = graves ? Colors.red[700]! : kPrimaryColor;

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: abierto
              ? tono.withValues(alpha: 0.20)
              : (hay ? tono.withValues(alpha: 0.08) : Colors.transparent),
          border: Border.all(
            color: elDeLaBarra ? tono : Colors.black12,
            width: elDeLaBarra ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'P$numero · $cuantos',
          style: TextStyle(
            fontSize: 12,
            fontWeight: hay ? FontWeight.w700 : FontWeight.normal,
            color: hay ? tono : Colors.black45,
          ),
        ),
      ),
    );
  }
}

/// Uno de los seis contadores del desglose.
class _Contador extends StatelessWidget {
  const _Contador({
    required this.rotulo,
    required this.cuantos,
    required this.alTocar,
    this.icono,
    this.color,
  });

  final String rotulo;
  final int cuantos;
  final VoidCallback alTocar;
  final IconData? icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tono = color ?? kPrimaryColor;
    final hay = cuantos > 0;

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hay ? tono.withValues(alpha: 0.14) : Colors.white,
          border: Border.all(
            color: hay ? tono.withValues(alpha: 0.5) : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 15, color: hay ? tono : Colors.black38),
              const SizedBox(width: 5),
            ],
            Text(
              rotulo,
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              '$cuantos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: hay ? tono : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
