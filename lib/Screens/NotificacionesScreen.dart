import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:myvc_flutter/Utils/AvisosGuardados.dart';
import 'package:myvc_flutter/Utils/PreferenciasAvisos.dart';

/// Qué avisos quiere recibir **este teléfono**.
///
/// Pantalla aparte y no una sección de Privacidad, que es donde su comentario
/// decía que encajaban: son tres interruptores, un permiso del sistema y la
/// lista de a quién cubren. Metidos debajo de la analítica quedaban como una
/// nota al pie de otra cosa.
///
/// **Los interruptores no hablan con el colegio.** Apagar «Notas» es soltar un
/// tema en Firebase: una llamada a Google, cero peticiones al servidor. Por eso
/// funcionan sin red, con el catálogo que se guardó al entrar.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.servidor});

  /// Para las pruebas. En la app se construye el suyo.
  final Server? servidor;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _drawerController = ZoomDrawerController();
  late final Server _server = widget.servidor ?? Server();

  bool _cargando = true;
  bool _permiso = false;
  bool _pidiendoPermiso = false;

  /// De tipo a si lo quiere. Se lee una vez y se mueve en memoria: el disco ya
  /// tiene la verdad, y releerlo en cada toque haría parpadear el interruptor.
  final Map<TipoDeAviso, bool> _quiere = {};

  /// A quién cubren los avisos, para que se vea que llegaron los temas.
  List<TemasDeUnAlumno> _alumnos = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final permiso = await Avisos.hayPermiso();

    // Con el permiso puesto se aprovecha la visita para refrescar el catálogo:
    // un acudido nuevo, o uno cuya matrícula terminó, se nota aquí. Es una
    // petición por visita a una pantalla que se abre una vez al año.
    if (permiso) await Avisos.sincronizar(_server);

    final catalogo = await AvisosGuardados.catalogo();
    final quiere = <TipoDeAviso, bool>{};
    for (final tipo in TipoDeAviso.values) {
      quiere[tipo] = await PreferenciasAvisos.quiere(tipo);
    }

    if (!mounted) return;
    setState(() {
      _permiso = permiso;
      _alumnos = catalogo?.alumnos ?? const [];
      _quiere
        ..clear()
        ..addAll(quiere);
      _cargando = false;
    });
  }

  Future<void> _activar() async {
    setState(() => _pidiendoPermiso = true);

    final concedido = await Avisos.pedirPermiso();

    if (!mounted) return;
    setState(() {
      _permiso = concedido;
      _pidiendoPermiso = false;
    });

    if (concedido) {
      await _cargar();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text(
          'Android solo pregunta una vez. Para activarlos hay que entrar en los'
          ' ajustes del teléfono.',
        ),
        action: SnackBarAction(
          label: 'Abrir ajustes',
          onPressed: () {
            FlutterLocalNotificationsPlugin()
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.openAppNotificationSettings();
          },
        ),
      ));
  }

  Future<void> _cambiar(TipoDeAviso tipo, bool valor) async {
    // Se mueve ya y se guarda después, igual que en Privacidad: lo de detrás no
    // puede fallar de una forma que importe —soltar un tema que no se tenía no
    // hace nada— y un interruptor que se queda quieto se lee como roto.
    setState(() => _quiere[tipo] = valor);

    await Avisos.cambiarPreferencia(tipo, valor);
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: const Text('Notificaciones'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (!_permiso) _pedirElPermiso(),
                  for (final tipo in TipoDeAviso.values)
                    _tarjeta(
                      child: SwitchListTile(
                        value: _permiso && (_quiere[tipo] ?? true),
                        onChanged: _permiso ? (v) => _cambiar(tipo, v) : null,
                        title: Text(tipo.rotulo),
                        subtitle: Text(
                          tipo.explicacion,
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: Icon(_iconoDe(tipo)),
                      ),
                    ),
                  if (_alumnos.isNotEmpty) _aQuienCubren(),
                  _explicacion(),
                ],
              ),
      ),
    );
  }

  IconData _iconoDe(TipoDeAviso tipo) {
    switch (tipo) {
      case TipoDeAviso.notas:
        return Icons.assignment_outlined;
      case TipoDeAviso.asistencia:
        return Icons.event_busy_outlined;
      case TipoDeAviso.disciplina:
        return Icons.gavel_outlined;
    }
  }

  /// Sin permiso no hay nada que decidir, así que va arriba y con el porqué.
  Widget _pedirElPermiso() {
    return _tarjeta(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_off_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Los avisos están apagados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Para enterarte de una nota, una falta o una situación sin tener'
              ' que abrir la app a mirar, el teléfono tiene que dejarnos'
              ' avisarte.',
              style: TextStyle(fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _pidiendoPermiso ? null : _activar,
                child: const Text('Activar avisos'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// De quién se reciben avisos, con nombre.
  ///
  /// Está porque es la única forma de que un acudiente vea que el colegio le
  /// reconoce los acudidos que cree tener. Si falta uno, el problema es del
  /// parentesco en la plataforma y no del teléfono, y así se puede decir.
  Widget _aQuienCubren() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'De quién recibes avisos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final alumno in _alumnos)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• ${alumno.nombre}',
                  style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  /// Lo que el aviso NO lleva dentro, dicho donde se duda.
  Widget _explicacion() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qué dice cada aviso',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            'Nunca la nota. Un aviso dice «hay 4 notas nuevas en Matemáticas»,'
            ' nunca cuáles son: se ve en la pantalla bloqueada, en el bus y con'
            ' gente al lado. Para verlas hay que abrir la app.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          Text(
            'Estos interruptores son de este teléfono',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            'Apagar «Notas» aquí no lo apaga en la tableta de casa, y al revés.'
            ' No se guardan en el colegio: quedan en el dispositivo.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }
}
