import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/VersionMinima.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lo que se ve cuando esta versión de la app ya no la acepta el colegio.
///
/// **No tiene salida, y es a propósito.** Un aviso que se puede cerrar no
/// permite retirar nada: si con la versión vieja se puede seguir entrando, el
/// endpoint viejo sigue haciendo falta y no se ha comprado nada. Lo decidió
/// Joseth el 23 de agosto de 2026 sabiendo eso. Ver
/// [VersionMinima] y docs/backend-pendiente.md §4.
///
/// Lo que sí tiene es el motivo escrito. Alguien a quien se le cierra la app
/// de golpe merece saber que no es un error suyo ni un fallo de red, y qué
/// hacer para volver a entrar.
class ActualizarScreen extends StatelessWidget {
  const ActualizarScreen({super.key});

  /// La ficha de la app en Play. Solo Android: es donde se publica, y en las
  /// demás plataformas un botón que no lleva a ninguna parte sería peor que no
  /// tener botón.
  String? get _tienda {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final paquete = VersionMinima.paquete;
    if (paquete == null) return null;

    return 'https://play.google.com/store/apps/details?id=$paquete';
  }

  @override
  Widget build(BuildContext context) {
    final tienda = _tienda;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, size: 64, color: kPrimaryColor),
                const SizedBox(height: 24),
                const Text(
                  'Hay que actualizar la app',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'El colegio ya no acepta esta versión de Mi Cole Virtual. '
                  'No es un fallo tuyo ni de la conexión: hay una versión nueva '
                  'y hay que instalarla para poder entrar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                if (tienda != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Actualizar'),
                    onPressed: () => _abrir(context, tienda),
                  )
                else
                  const Text(
                    'Búscala como «Mi Cole Virtual» en la tienda de '
                    'aplicaciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                const SizedBox(height: 20),
                Text(
                  _laLetraPequena(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Los dos números, para quien tenga que contarlo por teléfono. Sin ellos,
  /// «no me deja entrar» no se puede diagnosticar desde secretaría.
  String _laLetraPequena() {
    final nuestra = VersionMinima.nuestra;
    final exigida = VersionMinima.exigida;

    if (nuestra == null || exigida == null) return '';

    return 'Tienes la versión $nuestra y el colegio pide la $exigida o una '
        'más nueva.';
  }

  Future<void> _abrir(BuildContext context, String url) async {
    final fue = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);

    if (fue || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('No se pudo abrir la tienda. Búscala como «Mi Cole '
            'Virtual» en Play Store.'),
      ));
  }
}
