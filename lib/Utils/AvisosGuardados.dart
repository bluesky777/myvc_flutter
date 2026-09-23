import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que este teléfono recuerda de los avisos entre arranques.
///
/// Dos cosas distintas, y conviene no confundirlas:
///
///  - **El catálogo** — la respuesta entera de `GET notificaciones/temas`, tal
///    como llegó. Es el mapa de qué tema corresponde a qué alumno y a qué tipo.
///  - **Los suscritos** — a qué temas está apuntado el teléfono **ahora mismo**
///    en Firebase.
///
/// ## Por qué el catálogo se guarda
///
/// Porque apagar un interruptor en la pantalla de avisos no puede depender de
/// que el colegio conteste. Sin esto, cada toque a un interruptor sería una
/// petición al servidor para averiguar de qué tema hay que desapuntarse — y en
/// un hosting compartido eso es justo lo que este frente lleva evitando desde
/// el primer día. Con el catálogo guardado, un toque son **cero peticiones al
/// colegio** y una llamada a Google.
///
/// ## Por qué los suscritos se guardan, que es el motivo serio
///
/// **Porque al cerrar sesión ya no hay token con el que preguntar.** Soltar los
/// temas es obligatorio —si no, el teléfono prestado sigue recibiendo los avisos
/// del alumno anterior— y tiene que funcionar sin red y con la sesión ya
/// muerta. Firebase no sabe decir «a qué estoy apuntado», así que la única
/// forma de soltarlos todos es haber anotado cuáles se cogieron.
///
/// Se anota **lo que se pidió**, no lo que se confirmó, y a propósito: un
/// `subscribeToTopic` que falló a medias es peor olvidado que sobrante.
/// Desapuntarse de un tema que no se tenía no hace nada; quedarse apuntado a
/// uno que no se anotó es el fallo que esto existe para evitar.
class AvisosGuardados {
  AvisosGuardados._();

  static const String claveCatalogo = 'avisos_catalogo';
  static const String claveSuscritos = 'avisos_suscritos';
  static const String claveRefresco = 'avisos_catalogo_fecha';

  /// Cada cuánto se vuelve a preguntar por el catálogo en un arranque normal.
  ///
  /// **Una semana, y el número tiene motivo por los dos lados.** Lo que cambia
  /// la lista es que un acudido se matricule o que su matrícula termine: cosas
  /// de un par de veces al año. Preguntarlo en cada arranque serían cientos de
  /// peticiones diarias a un hosting compartido para recibir la misma respuesta
  /// —ver `docs/notificaciones.md`—; no preguntarlo nunca dejaría al acudiente
  /// de quien se fue recibiendo sus avisos. Entrar y abrir la pantalla de
  /// Notificaciones lo refrescan igualmente, sin esperar a que pase la semana.
  static const Duration cadaCuanto = Duration(days: 7);

  /// El catálogo tal como llegó, para poder releerlo sin red.
  static Future<void> guardarCatalogo(String cuerpoCrudo) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(claveCatalogo, cuerpoCrudo);
    await preferences.setInt(
        claveRefresco, DateTime.now().millisecondsSinceEpoch);
  }

  /// ¿Vale con lo guardado, o toca volver a preguntar?
  ///
  /// Sin catálogo siempre toca, aunque la fecha diga lo contrario: un reloj
  /// puesto hacia atrás no puede dejar el teléfono sin temas para siempre.
  static Future<bool> catalogoAlDia() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(claveCatalogo)?.isNotEmpty != true) return false;

    final cuando = preferences.getInt(claveRefresco);
    if (cuando == null) return false;

    final edad =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cuando));

    // Negativa si el reloj del teléfono se movió: eso no es «recién traído».
    return !edad.isNegative && edad < cadaCuanto;
  }

  /// El último catálogo, o `null` si no hay ninguno o dejó de entenderse.
  ///
  /// Que no se entienda no es un error a gritar: el formato del servidor puede
  /// cambiar entre dos versiones de la app, y lo que toca entonces es pedirlo
  /// otra vez, no reventar la pantalla de ajustes.
  static Future<TemasDeNotificacion?> catalogo() async {
    final preferences = await SharedPreferences.getInstance();
    final crudo = preferences.getString(claveCatalogo);
    if (crudo == null || crudo.isEmpty) return null;

    try {
      return TemasDeNotificacion.deCuerpo(crudo);
    } catch (_) {
      return null;
    }
  }

  /// A qué temas está apuntado este teléfono, que se sepa.
  static Future<Set<String>> suscritos() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(claveSuscritos) ?? const []).toSet();
  }

  static Future<void> guardarSuscritos(Iterable<String> temas) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(claveSuscritos, temas.toList()..sort());
  }

  /// Al cerrar sesión, después de haberlos soltado.
  ///
  /// Se van los dos: el catálogo lleva dentro los nombres de los acudidos de
  /// quien se va, que es el mismo cuidado que ya tiene `MuroEnMemoria`.
  static Future<void> olvidar() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(claveCatalogo);
    await preferences.remove(claveSuscritos);
    await preferences.remove(claveRefresco);
  }
}
