import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué estación atendió cada quien la última vez.
///
/// `docs/estaciones.md`, pantalla 01: *«se recuerda: mañana la app abre ahí»*.
/// Un día de matrículas son ocho horas en la misma estación, y elegirla en cada
/// apertura es un toque de más multiplicado por todas las veces que a alguien se
/// le apaga la pantalla con la fila delante.
///
/// **La clave lleva dentro el id del usuario, y aquí eso importa más que en
/// ninguna otra pantalla.** La preferencia de notas se guarda por usuario porque
/// la app se usa en el equipo compartido de la entrada; ésta, porque **la
/// tablet del colegio es justo lo que hay en el patio** y pasa de mano en mano
/// entre estaciones. Una estación recordada a secas se la encontraría puesta
/// quien cogiera el aparato después, y abriría la cola de otro.
class PreferenciaEstacion {
  static String _clave() => 'estaciones.mia.${AuthService.user.id ?? 0}';

  /// El número de la estación, o null si esta persona no ha elegido ninguna.
  ///
  /// Devuelve el número y no la estación entera a propósito: **los nombres y el
  /// recorrido vienen del servidor y pueden haber cambiado** entre ayer y hoy
  /// —el colegio edita sus pasos—. Guardar el nombre sería guardar algo que
  /// caduca; el número se contrasta contra lo que llegue.
  static Future<int?> leer() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_clave());
  }

  static Future<void> guardar(int nroEstacion) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_clave(), nroEstacion);
  }

  /// Para cuando te mueven de puesto.
  static Future<void> olvidar() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_clave());
  }
}
