import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Las cabeceras que dicen al servidor que la petición viene de la app.
///
/// La auditoría de 8myvc lee el `User-Agent` del login para saber si un cambio
/// se hizo desde la web o desde la app. El de Dart por defecto,
/// `Dart/x.y (dart:io)`, su detector no lo reconoce y lo guardaba como
/// `entorno = 'Bot'`. Van en todas las peticiones de [Server], el login
/// incluido, que es la que se guarda en `historiales`.
///
/// - `User-Agent: MyVC-App/1.1.0 (android; 14; SM-A145M)`, solo en móvil.
/// - `X-MyVC-Cliente: app/1.1.0`, siempre. En la web es la única: el navegador
///   no deja cambiar el User-Agent.
///
/// Solo se añaden cabeceras: ni rutas ni cuerpos cambian, y la misma app habla
/// con los dieciséis colegios.
class ClienteApp {
  /// Vacío hasta [arrancar], y vacío si falla: sin cabeceras la petición sale
  /// igual que antes, que es mejor que no salir.
  static Map<String, String> cabeceras = const {};

  /// Se llama una vez, al arrancar, antes de la primera petición.
  static Future<void> arrancar() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version;
      cabeceras = {
        if (!kIsWeb) 'User-Agent': await _userAgent(version),
        'X-MyVC-Cliente': 'app/$version',
      };
    } catch (err) {
      debugPrint('No se pudieron armar las cabeceras de la app: $err');
    }
  }

  static Future<String> _userAgent(String version) async {
    final info = DeviceInfoPlugin();
    final List<String> partes;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        partes = ['android', a.version.release, a.model];
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        partes = ['ios', i.systemVersion, i.utsname.machine];
      default:
        partes = [defaultTargetPlatform.name.toLowerCase()];
    }

    return userAgent(version, partes);
  }

  /// `MyVC-App/<versión> (<so>; <versión del so>; <modelo>)`.
  ///
  /// Los tramos vacíos se caen, y a cada uno se le quita lo que rompería la
  /// cabecera o el paréntesis: lo que no es ASCII imprimible, `(`, `)` y `;`.
  @visibleForTesting
  static String userAgent(String version, List<String> partes) {
    final limpias = partes
        .map((p) => p.replaceAll(RegExp(r'[^\x20-\x7E]|[();]'), '').trim())
        .where((p) => p.isNotEmpty);

    return 'MyVC-App/$version (${limpias.join('; ')})';
  }
}
