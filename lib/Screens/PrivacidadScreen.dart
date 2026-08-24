import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';

/// Los ajustes de privacidad de este teléfono.
///
/// Hoy solo uno: si el dispositivo aparece en las estadísticas de uso.
///
/// **No va dentro de Configuración**, aunque suene a que ahí es su sitio.
/// Configuración es del colegio —periodos, escala, quién puede editar notas— y
/// el menú solo se la ofrece al personal; esto es del dueño del teléfono, y un
/// acudiente tiene el mismo derecho a apagarlo que un coordinador. Meterlo allí
/// habría sido escribir un interruptor que la mitad de la gente no puede ver.
///
/// Cuando entren las notificaciones, sus cinco interruptores son de la misma
/// clase —preferencias del dispositivo, no del colegio— y esta es la pantalla
/// donde encajan.
class PrivacidadScreen extends StatefulWidget {
  const PrivacidadScreen({super.key});

  @override
  State<PrivacidadScreen> createState() => _PrivacidadScreenState();
}

class _PrivacidadScreenState extends State<PrivacidadScreen> {
  final _drawerController = ZoomDrawerController();

  /// Lo que enseña el interruptor. Sale de [Analitica], que ya lo leyó del
  /// disco al arrancar la app: aquí no hay nada que esperar.
  late bool _analitica = Analitica.activa;

  /// Mientras se guarda, para que no se pueda pulsar dos veces.
  bool _guardando = false;

  Future<void> _cambiar(bool valor) async {
    // Se mueve ya y se guarda después: el interruptor que se queda quieto
    // mientras algo pasa por detrás se lee como que no funcionó, y aquí lo que
    // hay por detrás no puede fallar de una forma que importe.
    setState(() {
      _analitica = valor;
      _guardando = true;
    });

    await Analitica.cambiar(valor);

    if (!mounted) return;
    setState(() => _guardando = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(valor
            ? 'Este dispositivo vuelve a aparecer en las estadísticas de uso.'
            : 'Listo: este dispositivo ya no envía estadísticas de uso.'),
      ));
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
          title: const Text('Privacidad'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _tarjeta(
              child: SwitchListTile(
                value: _analitica,
                onChanged: _guardando ? null : _cambiar,
                title: const Text('Enviar estadísticas de uso'),
                subtitle: const Text(
                  'Nos dice qué pantallas se usan y cuáles no, para saber qué'
                  ' mejorar.',
                  style: TextStyle(fontSize: 12),
                ),
                secondary: const Icon(Icons.insights_outlined),
              ),
            ),
            _explicacion(),
          ],
        ),
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

  /// Qué se manda y qué no, dicho entero.
  ///
  /// Está escrito aquí y no solo en la política de privacidad porque quien
  /// duda de un interruptor lo duda **en el momento de tocarlo**, y mandarlo a
  /// buscar un documento en la web es la forma de que lo apague por si acaso.
  Widget _explicacion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qué se envía',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Qué pantallas se abren y cuándo, cuántas veces se usa cada cosa, y'
            ' datos del teléfono como el modelo y la versión de Android. Junto'
            ' a eso solo se guardan dos rasgos: si es alumno, acudiente,'
            ' docente o administrador, y de qué colegio.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          const Text(
            'Qué NO se envía',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ningún nombre, ningún documento, ninguna calificación, ninguna'
            ' anotación de disciplina y ningún nombre de grupo. Nadie puede'
            ' saber, con estas estadísticas, de qué persona son. Y no hay'
            ' publicidad: el identificador publicitario del teléfono está'
            ' desactivado y la app ni siquiera pide permiso para leerlo.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Text(
            'Este ajuste es de este teléfono. Si entra otra persona con su'
            ' cuenta, sigue como usted lo dejó.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
