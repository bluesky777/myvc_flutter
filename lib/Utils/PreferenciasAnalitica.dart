import 'package:shared_preferences/shared_preferences.dart';

/// Si este dispositivo aparece en las estadísticas de uso.
///
/// **Por dispositivo y no por cuenta**, igual que las preferencias de
/// notificaciones: quien lo apaga lo apaga en el teléfono que tiene en la mano,
/// y no tiene por qué arrastrar esa decisión al equipo compartido de la
/// portería ni al revés. Además así no hace falta guardar nada en el servidor
/// del colegio, que es lo que hay que evitar en un hosting compartido.
///
/// Por defecto encendida. La analítica está para saber qué construir después
/// —ver docs/analitica.md— y no manda ningún dato que identifique a nadie; el
/// interruptor existe porque en una app de menores poder decir que no es lo
/// correcto, no porque el valor por defecto sea dudoso.
class PreferenciasAnalitica {
  static const String claveActiva = 'analiticaActiva';

  static Future<bool> activa() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(claveActiva) ?? true;
  }

  static Future<void> setActiva(bool valor) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(claveActiva, valor);
  }
}
