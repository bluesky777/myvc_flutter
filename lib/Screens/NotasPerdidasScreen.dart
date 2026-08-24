import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Http/NotasPerdidasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';
import 'package:myvc_flutter/Widgets/SelectorDocente.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';

/// Qué llevan perdido los alumnos de un docente, y arreglarlo desde aquí.
///
/// Es la pregunta de «¿quién va mal?», que no se hace todos los días pero sí en
/// dos momentos que duelen: cuando se acerca el cierre del periodo y cuando hay
/// que entregar informes. Hoy obliga a abrir el portátil.
///
/// **Del año entero, y los chips estrechan sin volver al servidor.** El árbol
/// se pide con `periodo_a_calcular = 10`, que el backend traduce a «todos los
/// periodos», y filtrar por uno se hace sobre lo ya traído. Es lo contrario de
/// lo que hace el front web cuando entra un docente —allí pide solo hasta el
/// periodo actual y lo de atrás no se ve—, y sale más barato: una petición en
/// vez de una por chip.
///
/// **Una jerarquía que se pliega, no la tabla del web.** Grupo → asignatura →
/// alumno → sus notas, cada nivel diciendo cuánto lleva dentro. En un teléfono
/// una tabla de cuatro niveles no se estrecha, y lo que se busca aquí casi
/// siempre es un alumno concreto dentro de un grupo concreto.
class NotasPerdidasScreen extends StatefulWidget {
  const NotasPerdidasScreen({super.key});

  @override
  State<NotasPerdidasScreen> createState() => _NotasPerdidasScreenState();
}

class _NotasPerdidasScreenState extends State<NotasPerdidasScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  bool get esDocente => AuthService.user.esDocente;

  /// Solo para quien no es docente: de qué docente son las notas.
  List<DocenteModel> docentes = [];
  DocenteModel? docenteElegido;

  List<GrupoConPerdidas> grupos = [];

  /// El periodo elegido en los chips, o null para todos.
  int? periodo;

  /// Las que se han corregido aquí, por id de nota. Se quedan en pantalla
  /// aunque ya no estén perdidas: ver [_buildNota].
  final Map<int, double> _corregidas = {};

  /// Un campo por nota, creado a medida que se despliegan.
  final Map<int, TextEditingController> _campos = {};

  /// Las que están saliendo hacia el servidor ahora mismo.
  final Set<int> _guardando = {};

  bool cargando = true;
  String? error;

  bool get _puedeEditar =>
      ContextoAcademico.instancia.config.puedeEditarNotas;

  @override
  void initState() {
    super.initState();
    // Se construyó entera y no se sabe si le sirve a alguien. Sin parámetros:
    // que se abra es toda la pregunta.
    Analitica.evento('notas_perdidas_abierta');
    _arrancar();
  }

  @override
  void dispose() {
    for (final campo in _campos.values) {
      campo.dispose();
    }
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// Tira lo escrito en los campos y las marcas de corregido.
  ///
  /// Hay que hacerlo en cada recarga. Los campos se guardan por id de nota, y
  /// esos ids siguen siendo los mismos después de refrescar: sin esto, un campo
  /// enseñaría lo que alguien tecleó hace un rato encima de una nota que el
  /// servidor acaba de devolver con otro valor, y las filas verdes de
  /// «corregida» sobrevivirían a los datos que las justificaban.
  ///
  /// Los controladores se tiran en el frame siguiente y no ahora: durante este
  /// todavía puede haber campos montados apuntando a ellos, y usar uno ya
  /// tirado revienta.
  void _olvidarLoEscrito() {
    final viejos = List.of(_campos.values);
    _campos.clear();
    _corregidas.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final campo in viejos) {
        campo.dispose();
      }
    });
  }

  Future<void> _arrancar() async {
    setState(() {
      cargando = true;
      error = null;
      grupos = [];
      _olvidarLoEscrito();
    });

    try {
      if (esDocente) {
        final propio = AuthService.user.personaId;
        if (propio == null) {
          error = 'Tu usuario no tiene ficha de docente.';
        } else {
          grupos = await traerNotasPerdidas(server, profesorId: propio);
        }
      } else {
        docentes = await traerDocentesDelColegio(server);
        if (docenteElegido != null) {
          grupos = await traerNotasPerdidas(
            server,
            profesorId: docenteElegido!.profesorId,
          );
        }
      }
    } catch (err) {
      error = 'No se pudieron traer las notas perdidas: $err';
    }

    setState(() => cargando = false);
  }

  Future<void> _cambiarDocente(DocenteModel elegido) async {
    setState(() {
      docenteElegido = elegido;
      cargando = true;
      error = null;
      grupos = [];
      _olvidarLoEscrito();
    });

    try {
      grupos = await traerNotasPerdidas(
        server,
        profesorId: elegido.profesorId,
      );
    } catch (err) {
      error = 'No se pudieron traer sus notas perdidas: $err';
    }

    setState(() => cargando = false);
  }

  List<GrupoConPerdidas> get _visibles => soloDelPeriodo(grupos, periodo);

  TextEditingController _campoDe(NotaPerdida nota) {
    return _campos.putIfAbsent(
      nota.notaId,
      () => TextEditingController(
        text: notaEscrita(_corregidas[nota.notaId] ?? nota.nota),
      ),
    );
  }

  Future<void> _guardarUna(NotaPerdida nota) async {
    final escrita = notaLeida(_campoDe(nota).text);
    if (escrita == null) {
      _avisar('Escribe la nota nueva.');
      return;
    }

    setState(() => _guardando.add(nota.notaId));
    final fallo = await guardarNota(server, notaId: nota.notaId, nota: escrita);
    setState(() => _guardando.remove(nota.notaId));

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    setState(() => _corregidas[nota.notaId] = escrita);
    _avisar('Guardada: ${notaEscrita(escrita)}.');
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
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
        backgroundColor: const Color(0xFFF4F5F7),
        body: BarraPlegable(
          titulo: 'Notas perdidas',
          alAbrirMenu: () => _drawerController.toggle!(),
          // Lo perdido es del año, no del periodo, pero el año sale de la
          // misma barra: si se cambia, esto es de otro año y hay que releerlo.
          alCambiarContexto: _arrancar,
          child: _buildCuerpo(),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando && grupos.isEmpty && docentes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibles = _visibles;

    return RefreshIndicator(
      onRefresh: Analitica.refresco('notas-perdidas', _arrancar),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!esDocente) _buildSelectorDocente(),
          if (grupos.isNotEmpty) _buildChips(),
          if (cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _buildMensaje(error!, conReintento: true)
          else if (grupos.isEmpty)
            _buildMensaje(
              esDocente
                  ? 'Ninguno de tus alumnos lleva notas perdidas este año.'
                  : 'Elige un docente para ver lo que llevan perdido sus'
                      ' alumnos.',
            )
          else if (visibles.isEmpty)
            _buildMensaje('En ese periodo no hay notas perdidas.')
          else
            ...visibles.asMap().entries.map(
                  (entrada) => _buildGrupo(entrada.value, entrada.key == 0),
                ),
        ],
      ),
    );
  }

  Widget _buildSelectorDocente() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CampoDocente(
        docentes: docentes,
        elegido: docenteElegido,
        titulo: 'Docentes del colegio',
        alElegir: _cambiarDocente,
      ),
    );
  }

  /// Los chips de periodo, solo con los que tienen algo perdido.
  ///
  /// Ofrecer los cuatro siempre sería ofrecer filtros que dejan la pantalla en
  /// blanco, y eso se lee como un fallo de la app y no como «aquí no hay nada».
  Widget _buildChips() {
    final disponibles = periodosConPerdidas(grupos);
    if (disponibles.length < 2) return const SizedBox.shrink();

    final total = grupos.fold<int>(0, (acc, g) => acc + g.cuantasNotas);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(
            texto: 'Todos ($total)',
            activo: periodo == null,
            alTocar: () => setState(() => periodo = null),
          ),
          for (final numero in disponibles)
            _chip(
              texto: 'Periodo $numero',
              activo: periodo == numero,
              alTocar: () => setState(() => periodo = numero),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String texto,
    required bool activo,
    required VoidCallback alTocar,
  }) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? kPrimaryColor : const Color(0xFFEDEDF3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? Colors.white : Colors.black87,
            fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// El primer grupo abierto y los demás cerrados: casi siempre se viene a
  /// mirar uno, y abrirlos todos deja una pantalla que hay que recorrer entera.
  Widget _buildGrupo(GrupoConPerdidas grupo, bool abierto) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: abierto,
        shape: const Border(),
        title: Text(
          grupo.nombre.trim().isEmpty ? grupo.abrev : grupo.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${grupo.asignaturas.length} asignaturas ·'
          ' ${grupo.cuantosAlumnos} alumnos · ${grupo.cuantasNotas} notas',
          style: const TextStyle(fontSize: 11),
        ),
        children: grupo.asignaturas.map(_buildAsignatura).toList(),
      ),
    );
  }

  Widget _buildAsignatura(AsignaturaConPerdidas asignatura) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          asignatura.comoSeLlama,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${asignatura.alumnos.length} alumnos ·'
          ' ${asignatura.cuantasNotas} notas',
          style: const TextStyle(fontSize: 11),
        ),
        children: asignatura.alumnos.map(_buildAlumno).toList(),
      ),
    );
  }

  Widget _buildAlumno(AlumnoConPerdidas alumno) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        shape: const Border(),
        leading: AvatarPersona(
          nombre: alumno.nombreEnLista,
          fotoNombre: alumno.fotoNombre,
          radio: 16,
        ),
        title: Text(
          alumno.nombreEnLista,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          '${alumno.notas.length} notas'
          '${alumno.nee ? ' · NEE' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        children: alumno.notas.map(_buildNota).toList(),
      ),
    );
  }

  /// Una nota perdida, con su campo para arreglarla ahí mismo.
  ///
  /// **La fila arreglada no desaparece.** La consulta del servidor solo
  /// devuelve lo que está por debajo de la mínima, así que una nota que sube a
  /// aprobado dejaría de venir en la siguiente carga. Quitarla de la pantalla
  /// al guardarla la haría parecer perdida —«¿la guardé o no?»—, así que se
  /// queda, en verde y con el número nuevo, hasta que alguien refresque.
  Widget _buildNota(NotaPerdida nota) {
    final campo = _campoDe(nota);
    final corregida = _corregidas.containsKey(nota.notaId);
    final ocupada = _guardando.contains(nota.notaId);

    final escrita = notaLeida(campo.text);
    final cambiada = escrita != null &&
        escrita != (_corregidas[nota.notaId] ?? nota.nota);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: corregida ? const Color(0xFFE8F5E9) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nota.definSubunidad,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'P${nota.numeroPeriodo} · ${nota.definUnidad}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: campo,
              enabled: _puedeEditar && !ocupada,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onTap: () => campo.selection = TextSelection(
                baseOffset: 0,
                extentOffset: campo.text.length,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _guardarUna(nota),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: corregida ? Colors.green[800] : Colors.red[700],
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: ocupada
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                // El botón solo aparece cuando hay algo que guardar: aquí se
                // corrige una nota suelta de vez en cuando, no una columna, y
                // un botón siempre encendido invita a tocarlo sin haber
                // cambiado nada.
                : cambiada && _puedeEditar
                    ? IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        color: Colors.green[800],
                        tooltip: 'Guardar esta nota',
                        onPressed: () => _guardarUna(nota),
                      )
                    : corregida
                        ? Icon(Icons.check_circle,
                            size: 18, color: Colors.green[700])
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMensaje(String texto, {bool conReintento = false}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(texto, textAlign: TextAlign.center),
          if (conReintento) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: _arrancar, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}
