import 'package:shared_preferences/shared_preferences.dart';

/// Cuándo se comprobó por última vez que el token guardado sigue valiendo.
///
/// **Existe para no gastar una petición cara en cada arranque en frío.**
/// [LoginController.restaurar] comprueba la sesión con `GET /years`, y ese
/// endpoint es más caro de lo que su nombre sugiere: `YearsController::getIndex`
/// trae todos los años del colegio y luego, **año por año**, lanza otra consulta
/// por sus periodos. Son del orden de una decena de consultas, y la app **tira
/// la respuesta entera**: solo mira el código de estado.
///
/// Mientras la app era de docentes eso pasaba unas decenas de veces al día. Con
/// las familias dentro pasa cada vez que alguien abre la app —y una notificación
/// de «ya están las notas» hace que cientos de teléfonos arranquen en el mismo
/// minuto, que es justo cuando el servidor no tiene un núcleo que regalar—.
///
/// Así que se recuerda cuándo se comprobó y no se vuelve a preguntar en
/// [vigencia]. Se guarda en disco y no en memoria a propósito: lo que se quiere
/// ahorrar es el arranque en frío, y en memoria no sobreviviría a él.
///
/// ## Qué se pierde, dicho claro
///
/// Entre una comprobación y la siguiente, a quien le revoquen el token —le
/// cambian la clave, le desactivan la cuenta— **la app no lo manda al login: le
/// enseña el error de la primera pantalla que falle**. Antes lo mandaba al
/// login en el siguiente arranque.
///
/// Se acepta por tres razones:
///
/// 1. **Ese agujero ya existía.** `_tokenSigueValiendo` devuelve `true` ante
///    cualquier fallo que no sea 401 o 403 —sin red, un 500, el servidor
///    caído—, o sea que una sesión rota ya podía colarse. Esto lo ensancha; no
///    lo inventa.
/// 2. **Se cierra sola.** Cualquier 401 o 403 del muro llama a [olvidar], así
///    que el siguiente arranque sí pregunta y sí manda al login.
/// 3. Revocar un token es raro; arrancar la app es lo que hace todo el mundo
///    todos los días.
///
/// **El arreglo de fondo es otro** y está anotado en
/// [docs/backend-pendiente.md](../../docs/backend-pendiente.md) §5: dejar de
/// comprobar por adelantado y tratar el 401 de la primera petición de verdad
/// como lo que es. Eso ahorra el 100 % de estas llamadas en vez del 60 %, pero
/// toca la navegación de cuatro pantallas y no es un cambio para meter junto a
/// éste.
///
/// ## El invariante
///
/// El sello vale para el token que hay guardado en ese momento, y eso se
/// sostiene con dos reglas, no con comprobaciones:
///
/// - Entrar **pone** el sello: el propio `POST /login` acaba de demostrar que
///   el token vale.
/// - Salir lo **borra**, junto con la sesión.
///
/// Mientras esas dos se cumplan, no puede haber un sello de un token y otro
/// token en disco.
class VerificacionSesion {
  VerificacionSesion._();

  static const String clave = 'sesionComprobadaEn';

  /// Cuánto vale una comprobación.
  ///
  /// Seis horas cubre una jornada escolar: quien abre la app tres o cuatro
  /// veces en la mañana paga una sola comprobación. Es también el techo de lo
  /// que puede tardar en notarse un token revocado, que es el precio y está
  /// arriba.
  static const Duration vigencia = Duration(hours: 6);

  /// Si hace falta volver a preguntarle al servidor.
  ///
  /// `true` cuando no hay sello, cuando ya caducó, o cuando el guardado no se
  /// entiende —una versión anterior, un disco a medias—: ante la duda se
  /// pregunta, que es el lado seguro.
  ///
  /// `ahora` es para las pruebas, como en [FechaServidor].
  static Future<bool> hayQueComprobar({DateTime? ahora}) async {
    final preferences = await SharedPreferences.getInstance();

    // `getInt` no devuelve null cuando lo guardado es de otro tipo: **lanza**.
    // Pasaría con lo que dejara una versión anterior que guardara aquí otra
    // cosa, y reventaría en `restaurar()`, o sea antes de pintar nada: la app
    // no abriría. Hacer que una caché tumbe el arranque es exactamente lo que
    // no puede pasar, así que ante cualquier duda se pregunta, que es lo mismo
    // que se hacía antes de que esta clase existiera.
    int? guardado;
    try {
      guardado = preferences.getInt(clave);
    } catch (_) {
      return true;
    }

    if (guardado == null) return true;

    final cuando = DateTime.fromMillisecondsSinceEpoch(guardado);
    final desde = (ahora ?? DateTime.now()).difference(cuando);

    // Un sello del futuro es un reloj que se movió hacia atrás. No se confía en
    // él, pero tampoco se deja ahí para siempre: se vuelve a preguntar.
    if (desde.isNegative) return true;

    return desde > vigencia;
  }

  /// Anota que ahora mismo el servidor aceptó el token.
  static Future<void> sellar({DateTime? cuando}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      clave,
      (cuando ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// Tira el sello: la próxima vez se pregunta.
  ///
  /// Se llama al cerrar sesión y **también cuando una petición normal responde
  /// 401 o 403**, que es lo que hace que la ventana de arriba se cierre sola.
  static Future<void> olvidar() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(clave);
  }
}
