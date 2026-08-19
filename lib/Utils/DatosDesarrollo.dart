import 'package:flutter/foundation.dart';

/// Datos con los que arranca el login mientras se desarrolla.
///
/// En web cada `flutter run` abre Chrome con un perfil nuevo, así que el
/// localStorage —donde viven las credenciales recordadas y el colegio elegido—
/// se pierde entre ejecución y ejecución y hay que reescribirlo todo cada vez.
///
/// Esto solo existe en compilaciones de depuración: `kDebugMode` es constante,
/// de modo que en release el compilador se lleva por delante las tres cadenas y
/// no quedan ni en el bundle. Para apagarlo sin dejar de depurar:
///
///   flutter run -d chrome --dart-define=DEV_LOGIN=false
///
/// Y para usar otras credenciales, DEV_USUARIO, DEV_CLAVE y DEV_SERVIDOR.
class DatosDesarrollo {
  static const bool activo =
      kDebugMode && bool.fromEnvironment('DEV_LOGIN', defaultValue: true);

  static const String username =
      String.fromEnvironment('DEV_USUARIO', defaultValue: 'administrador');

  static const String password =
      String.fromEnvironment('DEV_CLAVE', defaultValue: 'patreongreat');

  /// Se trata como el colegio "Otro", que es el camino de servidor local.
  static const String servidor =
      String.fromEnvironment('DEV_SERVIDOR', defaultValue: 'localhost');
}
