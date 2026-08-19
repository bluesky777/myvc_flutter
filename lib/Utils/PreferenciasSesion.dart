import 'package:shared_preferences/shared_preferences.dart';

/// Si este dispositivo recuerda las credenciales del docente.
///
/// Por defecto sí: en el celular propio es lo cómodo, y era el comportamiento
/// de siempre. En el equipo compartido de la entrada se desmarca una vez y deja
/// de rellenarse el formulario, que es lo que hacía que el docente siguiente
/// entrara con la cuenta del anterior y las tardanzas quedaran mal firmadas.
class PreferenciasSesion {
  static const String claveGuardarDatos = 'guardarDatos';
  static const String claveUsername = 'username';
  static const String clavePassword = 'password';

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
      await preferences.remove(clavePassword);
    }
  }
}
