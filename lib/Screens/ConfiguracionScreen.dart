import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/ConfiguracionApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/ControlOcupado.dart';
import 'package:myvc_flutter/constantes.dart';

/// Cómo está configurado el colegio: se ve todo y se edita lo que cambia a
/// menudo.
///
/// La pantalla equivalente de la plataforma web es la consola de administración
/// entera —crea y borra años, monta la escala de valoración fila a fila,
/// configura los certificados—. Traerla tal cual sería traer a la vez la parte
/// peligrosa y la que nadie hace desde un teléfono. La regla es otra:
///
/// > Se ve todo lo que ayuda a entender por qué la app se comporta como se
/// > comporta. Se edita solo lo que un directivo cambia estando de pie.
///
/// Lo editable son siete interruptores con algo en común: se mueven varias
/// veces al año, en momentos concretos —se cierra el periodo, se bloquean las
/// notas hasta que salgan los boletines— y hoy obligan a sentarse ante un
/// computador para mover una casilla.
///
/// **La restricción a administradores es de la app, no del servidor.** Estos
/// endpoints llevan `auth.personal`, que solo deja fuera a alumnos y
/// acudientes: un docente podría llamarlos. Es alcance, no permiso.
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  List<YearDelColegio> years = [];
  bool cargando = true;
  String? error;

  /// Qué control está esperando al servidor. Uno cada vez y por su nombre, para
  /// que esperar por un interruptor no congele los otros diez.
  final Set<String> _ocupados = {};

  /// Quién puede mover los interruptores.
  bool get _puedeEditar => AuthService.user.esAdmin;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      years = await traerColegio(server);
    } catch (err) {
      error = 'No se pudo traer la configuración: $err';
    }

    setState(() => cargando = false);
  }

  bool _ocupado(String control) => _ocupados.contains(control);

  /// Manda un cambio y deja en pantalla lo que quedó.
  ///
  /// Si falla no se toca nada: el interruptor se queda como estaba y se dice
  /// por qué. Pintar el cambio y revertirlo después parpadea y hace dudar de si
  /// se guardó.
  Future<void> _mandar(
    String control,
    Future<String?> Function() peticion,
    YearDelColegio Function(YearDelColegio) comoQueda,
    int yearId,
  ) async {
    setState(() => _ocupados.add(control));
    final fallo = await peticion();
    setState(() => _ocupados.remove(control));

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    setState(() {
      years = [
        for (final year in years)
          year.id == yearId ? comoQueda(year) : year,
      ];
    });
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
        appBar: AppBar(
          title: const Text('Configuración'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: _buildCuerpo(),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (years.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'El colegio no tiene años cargados.',
          textAlign: TextAlign.center,
        ),
      );
    }

    // El año en el que está el usuario primero, y los demás debajo: es el que
    // se viene a mirar, y bajar hasta él sería tonto.
    final suyo = ContextoAcademico.instancia.yearId;
    final ordenados = [
      ...years.where((y) => y.id == suyo),
      ...years.where((y) => y.id != suyo),
    ];

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (!_puedeEditar) _buildAvisoSoloLectura(),
          ...ordenados.map(_buildYear),
          _buildPie(),
        ],
      ),
    );
  }

  Widget _buildAvisoSoloLectura() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: kPrimaryColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esto es lo que hay configurado. Cambiarlo es cosa de'
              ' administración; aquí sirve para entender por qué la app se'
              ' comporta como se comporta.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYear(YearDelColegio year) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Abierto el año del usuario, cerrados los demás.
        initiallyExpanded: year.id == ContextoAcademico.instancia.yearId,
        shape: const Border(),
        title: Text(
          'Año ${year.year}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (year.actual) 'año actual del colegio',
            if (year.nombreColegio.isNotEmpty) year.nombreColegio,
          ].join(' · '),
          style: const TextStyle(fontSize: 11),
        ),
        children: [
          _buildInterruptoresDelYear(year),
          const Divider(height: 24),
          _buildPeriodos(year),
          const Divider(height: 24),
          _buildDatosDelYear(year),
          const Divider(height: 24),
          _buildEscalas(year),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInterruptoresDelYear(YearDelColegio year) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _interruptor(
            control: 'ver-notas-${year.id}',
            titulo: 'Los alumnos y acudientes pueden ver las notas',
            explicacion: 'Se apaga mientras se cuadran los boletines y se'
                ' vuelve a encender.',
            valor: year.alumnosPuedenVerNotas,
            alCambiar: (nuevo) => _mandar(
              'ver-notas-${year.id}',
              () => cambiarAlumnosPuedenVerNotas(
                server,
                yearId: year.id,
                pueden: nuevo,
              ),
              (y) => y.copiaCon(alumnosPuedenVerNotas: nuevo),
              year.id,
            ),
          ),
          _interruptor(
            control: 'numeros-${year.id}',
            titulo: 'Los estudiantes ven números en sus notas',
            // Se explica al derecho aunque la columna del backend esté al
            // revés: quien mira la pantalla no tiene por qué saber que se
            // llama «solo escalas valorativas».
            explicacion: 'Apagado, solo ven el desempeño: «Alto», «Superior».',
            valor: year.alumnosVenNumeros,
            alCambiar: (nuevo) => _mandar(
              'numeros-${year.id}',
              () => cambiarAlumnosVenNumeros(
                server,
                yearId: year.id,
                ven: nuevo,
              ),
              (y) => y.copiaCon(alumnosVenNumeros: nuevo),
              year.id,
            ),
          ),
          _interruptor(
            control: 'materias-${year.id}',
            titulo: 'Mostrar al docente todas sus materias',
            explicacion: 'Ignora los días configurados en cada asignatura. Es'
                ' lo que decide el filtro «Hoy» de la pantalla de Notas.',
            valor: year.mostrarTodasLasMaterias,
            alCambiar: (nuevo) => _mandar(
              'materias-${year.id}',
              () => cambiarMostrarTodasLasMaterias(
                server,
                yearId: year.id,
                mostrar: nuevo,
              ),
              (y) => y.copiaCon(mostrarTodasLasMaterias: nuevo),
              year.id,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodos(YearDelColegio year) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Los periodos',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          // Dicho con todas las letras porque es el sitio donde se confunden:
          // el de la barra de arriba es en qué periodo mira una persona, y este
          // es en qué periodo está el colegio entero.
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8, right: 4),
            child: Text(
              'El periodo actual es el del colegio entero. El selector de la'
              ' barra de arriba es otra cosa: en qué periodo estás mirando tú.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          if (year.periodos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Este año no tiene periodos.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            ...year.periodos.map((p) => _buildPeriodo(year, p)),
        ],
      ),
    );
  }

  Widget _buildPeriodo(YearDelColegio year, PeriodoDelColegio periodo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(10),
        border: periodo.actual
            ? Border.all(color: kPrimaryColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Periodo ${periodo.numero}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (periodo.actual)
                const Text(
                  'el actual del colegio',
                  style: TextStyle(fontSize: 11, color: kPrimaryColor),
                )
              else if (_puedeEditar)
                ControlOcupado(
                  ocupado: _ocupado('actual-${periodo.id}'),
                  child: TextButton(
                    onPressed: () => _confirmarPeriodoActual(year, periodo),
                    child: const Text('Hacerlo el actual'),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _fecha(
                  etiqueta: 'Inicio',
                  fecha: periodo.inicio,
                  control: 'inicio-${periodo.id}',
                  alElegir: (fecha) => _cambiarFecha(
                    year,
                    periodo,
                    fecha,
                    esElInicio: true,
                  ),
                ),
              ),
              Expanded(
                child: _fecha(
                  etiqueta: 'Fin',
                  fecha: periodo.fin,
                  control: 'fin-${periodo.id}',
                  alElegir: (fecha) => _cambiarFecha(
                    year,
                    periodo,
                    fecha,
                    esElInicio: false,
                  ),
                ),
              ),
            ],
          ),
          _interruptor(
            control: 'editar-${periodo.id}',
            titulo: 'Los docentes pueden editar notas',
            explicacion: 'Notas, indicadores, tardanzas y comportamientos.',
            valor: periodo.puedenEditarNotas,
            alCambiar: (nuevo) => _mandar(
              'editar-${periodo.id}',
              () => cambiarPuedenEditarNotas(
                server,
                periodoId: periodo.id,
                pueden: nuevo,
              ),
              (y) => y.conPeriodo(periodo.copiaCon(puedenEditarNotas: nuevo)),
              year.id,
            ),
          ),
          _interruptor(
            control: 'nivelar-${periodo.id}',
            titulo: 'Los docentes pueden nivelar',
            explicacion: 'Las notas finales. Se abre después de cerrar la'
                ' edición de notas.',
            valor: periodo.puedenNivelar,
            alCambiar: (nuevo) => _mandar(
              'nivelar-${periodo.id}',
              () => cambiarPuedenNivelar(
                server,
                periodoId: periodo.id,
                pueden: nuevo,
              ),
              (y) => y.conPeriodo(periodo.copiaCon(puedenNivelar: nuevo)),
              year.id,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fecha({
    required String etiqueta,
    required DateTime? fecha,
    required String control,
    required ValueChanged<DateTime> alElegir,
  }) {
    return ControlOcupado(
      ocupado: _ocupado(control),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: _puedeEditar ? () => _pedirFecha(fecha, alElegir) : null,
        title: Text(
          etiqueta,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        subtitle: Text(
          fecha == null ? 'sin fecha' : formatoDia(fecha),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }

  Future<void> _pedirFecha(
    DateTime? actual,
    ValueChanged<DateTime> alElegir,
  ) async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? hoy,
      // Un periodo se corre unos días, no unos años; pero se deja margen para
      // corregir el año pasado y montar el siguiente.
      firstDate: DateTime(hoy.year - 2),
      lastDate: DateTime(hoy.year + 2, 12, 31),
    );

    if (elegida != null) alElegir(elegida);
  }

  Future<void> _cambiarFecha(
    YearDelColegio year,
    PeriodoDelColegio periodo,
    DateTime fecha, {
    required bool esElInicio,
  }) {
    final control = '${esElInicio ? 'inicio' : 'fin'}-${periodo.id}';

    return _mandar(
      control,
      () => cambiarFechaDelPeriodo(
        server,
        periodoId: periodo.id,
        fecha: fecha,
        esElInicio: esElInicio,
      ),
      (y) => y.conPeriodo(
        esElInicio
            ? periodo.copiaCon(inicio: fecha)
            : periodo.copiaCon(fin: fecha),
      ),
      year.id,
    );
  }

  /// Cambiar el periodo del colegio va con diálogo y no con un interruptor.
  ///
  /// No es un ajuste más: de él cuelgan las notas que se escriben, los
  /// boletines y los informes de todo el mundo. El front web también avisa
  /// antes, y con razón.
  Future<void> _confirmarPeriodoActual(
    YearDelColegio year,
    PeriodoDelColegio periodo,
  ) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Poner el periodo ${periodo.numero} como el actual?'),
        content: const Text(
          'Cambia el periodo para todo el colegio, no solo para ti. A partir'
          ' de ahí, las notas que se escriban, los boletines y los informes'
          ' son de ese periodo.\n\n'
          'Para cambiar solo lo que tú estás mirando, usa el selector de la'
          ' barra de arriba.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Sí, cambiarlo'),
          ),
        ],
      ),
    );

    if (seguro != true) return;

    await _mandar(
      'actual-${periodo.id}',
      () => establecerPeriodoActual(server, periodoId: periodo.id),
      // Los demás se apagan también: es lo que hace el backend, y si la app
      // solo encendiera este quedarían dos marcados como actuales.
      (y) => y.conActual(periodo.id),
      year.id,
    );
  }

  Widget _buildDatosDelYear(YearDelColegio year) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Lo demás de este año',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          _dato('Nota mínima aceptada',
              '${year.notaMinimaAceptada ?? 'sin fijar'}'),
          _dato('Así llama el colegio a las unidades',
              '${year.unidad} · ${year.subunidad}'),
          _dato('Los docentes pueden editar datos de alumnos',
              _siONo(year.docentesPuedenEditarAlumnos)),
          _dato('Puesto comparativo en el boletín',
              _siONo(year.puestoEnBoletin)),
          _dato('Nota de comportamiento en el boletín',
              _siONo(year.notaComportamientoEnBoletin)),
          _dato('Materias del año pasado en el boletín',
              _siONo(year.anioPasadoEnBoletin)),
          _dato('Recuperar la materia exime de nivelar',
              _siONo(year.recuperarEximeDeNivelar)),
        ],
      ),
    );
  }

  /// La escala de valoración: lo que traduce «85» a «Alto».
  ///
  /// Solo se lee. Montarla es cosa de una vez al año y de una pantalla grande,
  /// pero un docente la consulta más de lo que uno cree, y aquí está.
  Widget _buildEscalas(YearDelColegio year) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'La escala de valoración',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (year.escalas.isEmpty)
            const Text(
              'Este año no tiene escala cargada.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...year.escalas.map(_buildEscala),
        ],
      ),
    );
  }

  Widget _buildEscala(EscalaDeValoracion escala) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              escala.rango,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              escala.desempenio,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: escala.perdido ? Colors.red[700] : Colors.black87,
              ),
            ),
          ),
          if (escala.perdido)
            Text(
              'perdido',
              style: TextStyle(fontSize: 11, color: Colors.red[700]),
            ),
        ],
      ),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Text(valor, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  String _siONo(bool valor) => valor ? 'Sí' : 'No';

  /// Un interruptor con su explicación, en gris si quien mira no lo puede
  /// mover.
  ///
  /// Se enseña apagado y no se esconde: un ajuste que desaparece parece un
  /// fallo de la app, y la mitad de la gracia de esta pantalla es explicar por
  /// qué la app hace lo que hace.
  Widget _interruptor({
    required String control,
    required String titulo,
    required String explicacion,
    required bool valor,
    required ValueChanged<bool> alCambiar,
  }) {
    return ControlOcupado(
      ocupado: _ocupado(control),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        dense: true,
        value: valor,
        onChanged: _puedeEditar ? alCambiar : null,
        title: Text(titulo, style: const TextStyle(fontSize: 13)),
        subtitle: Text(explicacion, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  /// La respuesta a «¿y esto dónde se cambia?», que si no está escrita acaba en
  /// una llamada.
  Widget _buildPie() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        'Lo demás se configura en la plataforma web: crear años y periodos,'
        ' montar la escala de valoración, los certificados y el manual de'
        ' convivencia.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}
