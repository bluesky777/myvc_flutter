import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// Si a quien tiene la sesión abierta le falta votar, **sabido sin preguntar**.
///
/// ## Esto no cuesta ninguna petición, y ahí está todo el diseño
///
/// El servidor ya lo calcula en el login. `App\Services\VotacionesPendientes`
/// —que `LoginController::postIndex` llama, y también `GET /api/auth/me`, a
/// propósito para que las dos devuelvan lo mismo— mira las elecciones abiertas
/// en las que esta persona vota, comprueba cargo por cargo si ya votó, y **sólo
/// cuelga las que le faltan**, en la clave `votaciones`.
///
/// Y la clave **no aparece cuando no hay ninguna**. Eso es contrato escrito en
/// el docblock de ese servicio: *«No se pone a lista vacía cuando no las hay, y
/// eso es contrato: el frontend comprueba la existencia de la clave, no su
/// longitud»*. Así que la pregunta «¿hay que avisarle hoy?» se contesta **con
/// una clave de una respuesta que la app ya pide para entrar**, y no con una
/// ruta más golpeando un hosting de un núcleo cada vez que alguien abre el muro.
///
/// De aquí salen las dos primeras pantallas del módulo: la tarjeta de la portada
/// y el aviso que se abre solo. Ninguna de las dos llama al servidor para
/// aparecer.
///
/// ## Lo que NO trae, y por eso el tarjetón sí pide
///
/// Las filas que cuelga el servicio son `vt_votaciones` **sin los cargos
/// dentro**: `en-accion-inscrito` los cuelga, el login no. Así que la tarjeta y
/// el aviso saben *que hay* una votación abierta y cómo se llama, y los cargos
/// concretos —con su `votado` y sus candidatos— los trae
/// `candidatos/conaspiraciones` cuando la persona toca «Empezar». Es una
/// petición, y ocurre **después de un toque**, no al abrir la app.
///
/// ## Por qué es un estático y no un `Provider`
///
/// Por lo mismo que [HorarioDeHoy]: lo llena el login y lo leen pantallas que no
/// tienen relación entre sí. Se limpia al cerrar sesión, con el resto — la
/// elección abierta de un colegio no puede sobrevivir al usuario que se va.
class VotacionPendiente {
  VotacionPendiente._();

  static final VotacionPendiente instancia = VotacionPendiente._();

  List<VotacionAbierta> _abiertas = const [];

  /// Si el aviso ya se ofreció en esta sesión.
  ///
  /// **Aquí y no en el teléfono, a propósito.** El permiso de avisos se recuerda
  /// en `SharedPreferences` porque preguntarlo dos veces es gastar la única
  /// pregunta que da Android; esto es lo contrario: la jornada electoral dura un
  /// día y **el aviso tiene que volver a salir mañana**, o al volver a entrar. Lo
  /// que no puede es reaparecer en bucle cada vez que el muro se recarga, que es
  /// exactamente lo que hace que la gente le dé a «Ahora no» sin leerlo.
  bool _yaSeOfrecio = false;

  /// Lo que el login dijo. Vacío cuando no dijo nada, que es lo normal.
  List<VotacionAbierta> get abiertas => _abiertas;

  /// La elección que la portada enseña.
  ///
  /// **La primera de la lista y no una elegida por fecha.** El servidor devuelve
  /// las que están `actual` e `in_action`, y en la práctica es una: la elección
  /// del año, abierta el día de la jornada. Ordenar por `fecha_fin` aquí sería
  /// inventar una regla de desempate que el colegio no ha pedido — y con dos
  /// abiertas a la vez, la portada enseña una y el tarjetón lleva a sus cargos,
  /// que es lo que hace falta.
  VotacionAbierta? get laDeHoy => _abiertas.isEmpty ? null : _abiertas.first;

  /// Si hay que enseñar la tarjeta de la portada.
  ///
  /// Tres condiciones, y las tres tienen que estar: el interruptor, que el
  /// servidor haya mandado una elección abierta, y que **le falte votar**. La
  /// tercera la contesta el servicio del backend por partida doble —sólo cuelga
  /// las incompletas, y además manda `completos`—, así que se comprueba lo que
  /// manda y no sólo el hecho de que venga.
  bool get hayQueVotar {
    if (!Interruptores.votaciones) return false;

    final votacion = laDeHoy;
    return votacion != null && !votacion.completos && votacion.pareceAbierta;
  }

  /// Si toca abrir el aviso que se abre solo. Ver [_yaSeOfrecio].
  bool get tocaAvisar => hayQueVotar && !_yaSeOfrecio;

  /// Que no vuelva a salir en esta sesión. Se llama **al abrirlo**, no al
  /// cerrarlo: si se llamara al cerrarlo, un aviso que se cierra deslizando
  /// —sin tocar ninguno de los dos botones— volvería a salir al siguiente
  /// refresco del muro, que es el bucle que hay que evitar.
  void yaSeOfrecio() => _yaSeOfrecio = true;

  /// Toma lo que trae `POST /api/login` y `GET /api/auth/me`.
  ///
  /// Se llama desde `LoginController.tomarUsuarioDe`, que es por donde pasan las
  /// **dos** formas de entrar —con usuario y contraseña, y recuperando la sesión
  /// guardada—, así que ninguna se lo salta.
  void tomarDelLogin(Map<String, dynamic> datos) {
    _abiertas = const [];

    if (!Interruptores.votaciones) return;

    final crudo = datos['votaciones'];
    if (crudo is! List) return;

    _abiertas = crudo
        .whereType<Map>()
        .map(VotacionAbierta.fromJson)
        .where((votacion) => votacion.id != 0)
        .toList();
  }

  /// Después de votar, la portada tiene que dejar de ofrecerlo.
  ///
  /// El dato vino del login y el login no se repite, así que quien acabe la
  /// papeleta lo dice aquí. Sin esto, la tarjeta «Votar ahora» seguiría en la
  /// portada después de haber votado hasta que la persona volviera a entrar.
  void yaVoto(int votacionId) {
    _abiertas = _abiertas
        .where((votacion) => votacion.id != votacionId)
        .toList();
  }

  void limpiar() {
    _abiertas = const [];
    _yaSeOfrecio = false;
  }
}
