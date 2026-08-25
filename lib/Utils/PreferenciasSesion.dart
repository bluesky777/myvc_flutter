import 'package:shared_preferences/shared_preferences.dart';

/// Si este dispositivo recuerda al docente que entró.
///
/// Por defecto sí: en el celular propio es lo cómodo, y era el comportamiento
/// de siempre. En el equipo compartido de la entrada se desmarca una vez y deja
/// de rellenarse el formulario, que es lo que hacía que el docente siguiente
/// entrara con la cuenta del anterior y las tardanzas quedaran mal firmadas.
///
/// **Lo que se recuerda es el usuario, no la contraseña.** Entrar sin teclear
/// nada ya lo resuelve el token de `SesionGuardada`, que sobrevive a cerrar la
/// app y está protegido por esta misma casilla. Guardar además la contraseña no
/// añadía ninguna comodidad y dejaba un secreto en claro en
/// `shared_preferences`, que no cifra nada: en Android es un XML dentro de la
/// carpeta de la app, legible con root o en una copia de seguridad sin cifrar.
/// Y la política de privacidad promete que no se guarda.
class PreferenciasSesion {
  static const String claveGuardarDatos = 'guardarDatos';
  static const String claveUsername = 'username';

  /// La contraseña que las versiones anteriores dejaban en claro.
  ///
  /// Ya no se escribe nunca. La constante sigue aquí para poder borrar lo que
  /// quedó en los teléfonos que vienen de una versión que sí la guardaba:
  /// ver [purgarPasswordHeredada].
  static const String clavePasswordHeredada = 'password';

  static Future<bool> guardarDatos() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(claveGuardarDatos) ?? true;
  }

  static Future<void> setGuardarDatos(bool valor) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(claveGuardarDatos, valor);

    // Al desmarcar, lo ya guardado se borra ahora y no en el próximo login:
    // si alguien lo desactiva es porque el equipo ya está en otras manos.
    if (!valor) {
      await preferences.remove(claveUsername);
    }
  }

  /// Borra la contraseña que dejó una versión anterior.
  ///
  /// Se llama al arrancar y no al entrar: quien ya tiene la sesión abierta
  /// puede pasar meses sin volver a ver el login, y hasta entonces su
  /// contraseña seguiría ahí. Es una escritura barata y se puede llamar
  /// siempre, haya algo que borrar o no.
  static Future<void> purgarPasswordHeredada() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(clavePasswordHeredada);
  }
}
