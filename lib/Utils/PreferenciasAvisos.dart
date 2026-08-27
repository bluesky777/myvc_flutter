import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué avisos quiere este teléfono.
///
/// **Por dispositivo y no por cuenta**, igual que
/// [PreferenciasAnalitica](PreferenciasAnalitica.dart). No es una limitación:
/// es lo correcto. Un acudiente puede querer los avisos de notas en su teléfono
/// y no en la tableta que usa el niño, y con la preferencia guardada en el
/// servidor eso no se puede decir.
///
/// **Y no cuesta ni una petición al colegio.** Apagar un tipo es desapuntarse
/// de su tema en Firebase: una llamada a Google, cero filas en la base y cero
/// consultas al enviar, porque el envío no filtra por preferencias — quien no
/// lo quiere ya no está en el tema. Ver docs/notificaciones.md.
///
/// **Todos encendidos por defecto.** Quien instala la app de su colegio quiere
/// enterarse de las notas de su hijo; el interruptor está para el que no, no
/// para tener que buscarlo el primer día.
class PreferenciasAvisos {
  PreferenciasAvisos._();

  /// El prefijo de la clave. Una por tipo, para poder añadir un cuarto sin
  /// migrar lo guardado.
  static const String prefijo = 'avisos_';

  static String claveDe(TipoDeAviso tipo) => '$prefijo${tipo.clave}';

  static Future<bool> quiere(TipoDeAviso tipo) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(claveDe(tipo)) ?? true;
  }

  static Future<void> setQuiere(TipoDeAviso tipo, bool valor) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(claveDe(tipo), valor);
  }

  /// Los tipos encendidos ahora mismo, en el orden en que se declaran.
  static Future<List<TipoDeAviso>> encendidos() async {
    final preferences = await SharedPreferences.getInstance();

    return [
      for (final tipo in TipoDeAviso.values)
        if (preferences.getBool(claveDe(tipo)) ?? true) tipo,
    ];
  }

  /// Olvida lo elegido en este teléfono.
  ///
  /// **No se llama al cerrar sesión.** La preferencia es del teléfono y no de
  /// la cuenta: quien apagó «Disciplina» en su tableta no lo apagó porque fuera
  /// él, lo apagó porque es esa tableta. Lo que sí hay que hacer al cerrar
  /// sesión es **desapuntarse de los temas**, que es otra cosa — si no, el
  /// teléfono prestado sigue recibiendo los avisos del alumno anterior.
  static Future<void> olvidar() async {
    final preferences = await SharedPreferences.getInstance();

    for (final tipo in TipoDeAviso.values) {
      await preferences.remove(claveDe(tipo));
    }
  }
}
