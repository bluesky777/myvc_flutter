import 'package:flutter/foundation.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Si esta versión de la app todavía la acepta el colegio.
///
/// **Existe para que se pueda retirar un endpoint.** Hasta ahora la app no
/// comprobaba en ninguna parte que su versión siguiera siendo aceptable, así
/// que un teléfono con la del año pasado seguía llamando a los mismos
/// endpoints indefinidamente y nadie se enteraba. Mientras eso fuera así,
/// **retirar cualquier ruta dependía de que dieciséis colegios se actualizaran
/// por su cuenta**, que es lo que dejaba sin fecha —que no es lo mismo que
/// lejos— dos planes del backend. El contrato entero, en
/// [docs/backend-pendiente.md](../../docs/backend-pendiente.md) §4.
///
/// El número llega en la respuesta de `POST /login`, que la app ya pide al
/// entrar y al recuperar la sesión guardada: un campo en algo que ya se pide,
/// y no una ruta nueva que costaría una petición más en cada arranque, en un
/// hosting compartido, para leer un entero que cambia dos veces al año.
///
///     POST /login  →  { ..., "version_minima_app": 12 }
///
/// **Lo que de verdad define esta clase es cuándo NO bloquea**, y esa es la
/// parte que no se puede tocar sin pensarlo dos veces:
///
///   · el campo no viene                    → entra
///   · viene ilegible, cero o negativo      → entra
///   · no se sabe la versión propia         → entra
///   · no hay red o el servidor no contesta → entra (nunca llega a preguntarse)
///
/// Un `.env` mal puesto en un colegio no puede dejar a ese colegio entero fuera
/// de la app. Bloquear es lo excepcional, y solo con un número que se entienda.
///
/// **Un número altísimo sí bloquea, y tiene que hacerlo.** Desde aquí no hay
/// forma de distinguir un dedazo de un colegio que de verdad exige la última
/// versión, y adivinarlo sería justo lo contrario de lo que hace fiable a esta
/// comprobación. La defensa contra el dedazo está en el servidor: ese número se
/// sube una vez por retirada, con la misma ceremonia que un despliegue.
class VersionMinima {
  /// La más vieja que el colegio acepta. Null mientras nadie lo haya dicho.
  static int? exigida;

  /// El `versionCode` de este build —el `+N` de `pubspec.yaml`—, leído del
  /// paquete instalado. Null si no se pudo saber.
  ///
  /// Se lee del paquete y no de una constante en el código a propósito: una
  /// constante se queda vieja el día que alguien publique sin acordarse de
  /// subirla, que es exactamente el fallo que esta clase viene a evitar.
  static int? nuestra;

  /// El identificador del paquete, para llevar a la tienda.
  static String? paquete;

  /// Lee la versión propia. Se llama una vez, al arrancar.
  ///
  /// Si falla —en la web no hay paquete, y en las pruebas no hay plataforma—
  /// deja [nuestra] en null, y entonces no se bloquea a nadie.
  static Future<void> arrancar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      nuestra = entero(info.buildNumber);
      paquete = info.packageName.trim().isEmpty ? null : info.packageName;
    } catch (err) {
      debugPrint('No se pudo leer la versión de la app: $err');
    }
  }

  /// Se queda con `version_minima_app` de una respuesta de `/login`.
  ///
  /// Nunca tira: esto se llama desde el camino por el que se entra a la app, y
  /// un campo raro no puede ser el motivo de que nadie pueda entrar.
  static void tomarDe(dynamic cuerpo) {
    if (cuerpo is! Map) return;

    exigida = _sana(entero(cuerpo['version_minima_app']));
  }

  /// Si hay que actualizar antes de seguir.
  static bool get bloquea => esCorta(exigida: exigida, nuestra: nuestra);

  /// La comparación, aparte para poder probarla sin plataforma debajo.
  ///
  /// Solo dice que sí cuando las dos cosas se saben y la nuestra se queda
  /// corta. Cualquier duda es un no.
  static bool esCorta({required int? exigida, required int? nuestra}) {
    final minima = _sana(exigida);

    if (minima == null) return false;
    if (nuestra == null || nuestra <= 0) return false;

    return nuestra < minima;
  }

  /// Un entero positivo, o null. Cero y negativos son un campo mal puesto.
  static int? _sana(int? valor) =>
      (valor == null || valor <= 0) ? null : valor;

  /// Deja la comprobación como recién arrancada. Para las pruebas y para el
  /// cierre de sesión: la versión mínima es del colegio, y al salir se deja de
  /// hablar con él.
  static void limpiar() {
    exigida = null;
  }
}
