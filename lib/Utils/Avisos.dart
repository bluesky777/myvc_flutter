import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/AvisosGuardados.dart';
import 'package:myvc_flutter/Utils/Navegador.dart';
import 'package:myvc_flutter/Utils/PreferenciasAvisos.dart';

/// Los avisos push, de punta a punta en la app.
///
/// El plan entero está en `docs/notificaciones.md`; aquí va lo que hay que
/// tener en la cabeza para tocar este archivo.
///
/// ## El teléfono no sabe de quién es cada tema
///
/// Un tema es `a_` + HMAC con el secreto del colegio, y **lo compone el
/// servidor**. Esta clase pide la lista hecha, se apunta a lo que corresponda y
/// no deriva nada. Si la app supiera componer el nombre habría dos sitios donde
/// escribirlo mal, y uno de ellos **no da error**: apuntarse a un tema que no
/// existe es válido en FCM, así que el aviso se perdería en silencio.
///
/// ## Nada antes del permiso
///
/// No se pide el identificador de FCM ni se toca un tema hasta que la persona
/// concede el permiso. No es prudencia: el formulario de seguridad de datos de
/// Play declara ese identificador como **opcional**, y sería mentira si la app
/// lo obtuviera igual. Ver `docs/seguridad-datos-play.md`.
///
/// ## Solo Android, hoy
///
/// Por lo mismo que la analítica: en Firebase hay registrada una sola app, la
/// de Android con su `google-services.json`. iOS necesita además una clave de
/// APNs, que necesita cuenta de Apple de pago. Ver `docs/publicacion-app-store.md`.
class Avisos {
  Avisos._();

  /// Dónde se reciben avisos.
  ///
  /// Dice **dónde se quiere**, no si se está recibiendo. Lo segundo depende del
  /// permiso y de que el colegio tenga puestas sus credenciales de Firebase.
  /// En `flutter test` esto vale `true` —el entorno se presenta como Android— y
  /// aun así no se suscribe nada, porque [_arrancado] sigue en `false`.
  static bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// El canal de Android donde caen los avisos.
  ///
  /// Tiene que existir **antes** de que llegue el primero: en Android 8 y
  /// arriba una notificación sin canal no se muestra. El mismo identificador va
  /// declarado en `AndroidManifest.xml` como
  /// `com.google.firebase.messaging.default_notification_channel_id`, que es lo
  /// que usa el sistema cuando el aviso llega con la app cerrada y no hay Dart
  /// corriendo para elegirlo. Los dos tienen que decir lo mismo.
  static const String canalId = 'avisos_colegio';
  static const String canalNombre = 'Avisos del colegio';
  static const String canalDescripcion =
      'Notas, asistencia y convivencia de tus acudidos.';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _arrancado = false;

  /// Prepara el canal y engancha los tres caminos por los que llega un aviso.
  ///
  /// Se llama una vez al arrancar, después de `Firebase.initializeApp()`. **No
  /// pide permiso ni se suscribe a nada**: solo deja montado lo que hace falta
  /// para que un aviso que llegue se vea y se pueda tocar.
  ///
  /// Si algo de esto falla, la app arranca igual. Enterarse de una nota nueva
  /// no puede ser el motivo de no poder entrar.
  static Future<void> arrancar() async {
    if (!disponible || _arrancado) return;

    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        ),
        onDidReceiveNotificationResponse: (respuesta) {
          final crudo = respuesta.payload;
          if (crudo == null || crudo.isEmpty) return;
          try {
            _abrirPantalla(Map<String, dynamic>.from(jsonDecode(crudo) as Map));
          } catch (_) {
            // Un payload que no se entiende abre la app y ya. Peor sería no
            // abrir nada.
          }
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            canalId,
            canalNombre,
            description: canalDescripcion,
            importance: Importance.defaultImportance,
          ));

      // Con la app abierta, FCM no pinta nada: el bloque `notification` que
      // manda el servidor solo lo dibuja el sistema cuando la app está en
      // segundo plano o cerrada. En primer plano hay que dibujarlo aquí, o el
      // aviso llega y no se ve.
      FirebaseMessaging.onMessage.listen(_pintarEnPrimerPlano);

      // Tocado con la app viva pero en segundo plano.
      FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
        _abrirPantalla(_datosDe(mensaje));
      });

      // Y tocado con la app cerrada: el mensaje que la abrió. Va con un
      // `postFrame` porque en este momento el navegador todavía no existe.
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _abrirPantalla(_datosDe(inicial));
        });
      }

      _arrancado = true;
    } catch (err) {
      debugPrint('No se pudieron preparar los avisos: $err');
    }
  }

  /// ¿Está concedido el permiso de notificaciones? Sin preguntar nada.
  static Future<bool> hayPermiso() async {
    if (!disponible) return false;

    try {
      final ajustes =
          await FirebaseMessaging.instance.getNotificationSettings();
      return ajustes.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  /// Pide el permiso y devuelve si quedó concedido.
  ///
  /// **Quien llama elige el momento.** Desde Android 13 este diálogo sale una
  /// sola vez: si se pregunta a bocajarro al abrir por primera vez, mucha gente
  /// dice que no y el sistema no vuelve a preguntar nunca. Por eso se pide
  /// después de entrar y con una frase delante que explique para qué.
  static Future<bool> pedirPermiso() async {
    if (!disponible) return false;

    try {
      final ajustes = await FirebaseMessaging.instance.requestPermission();
      return ajustes.authorizationStatus == AuthorizationStatus.authorized;
    } catch (err) {
      debugPrint('No se pudo pedir el permiso de avisos: $err');
      return false;
    }
  }

  /// Trae los temas del servidor y deja el teléfono apuntado a lo que toca.
  ///
  /// Se llama al entrar y en cada arranque con sesión recuperada. Es **la única
  /// petición al colegio** de todo este frente, y por eso se guarda lo que
  /// devuelve: los interruptores de la pantalla de avisos se resuelven después
  /// con lo guardado y no vuelven a molestar al servidor.
  ///
  /// Que no haya red, o que el colegio conteste 503 porque le falta el secreto,
  /// no es un error que enseñar a nadie: quien acaba de entrar quiere ver el
  /// muro, no un cartel sobre notificaciones.
  ///
  /// Con [forzar] en `false` —los arranques— se salta la petición si el
  /// catálogo se trajo hace menos de una semana. Ver
  /// [AvisosGuardados.cadaCuanto]: lo que cambia la lista pasa un par de veces
  /// al año, y preguntarlo en cada arranque serían cientos de peticiones
  /// diarias para recibir lo mismo. Las suscripciones **sí** se repasan
  /// siempre, que eso no cuesta nada al colegio.
  static Future<void> sincronizar(Server server, {bool forzar = true}) async {
    if (!disponible || !await hayPermiso()) return;

    if (!forzar && await AvisosGuardados.catalogoAlDia()) {
      await reconciliar();
      return;
    }

    try {
      final res = await server.get('/notificaciones/temas');
      if (res.statusCode >= 300) return;

      // Se comprueba que se entiende antes de guardarlo, para no dejar en el
      // teléfono un catálogo que la pantalla de ajustes no va a poder leer.
      TemasDeNotificacion.deCuerpo(res.body);
      await AvisosGuardados.guardarCatalogo(res.body);
    } catch (err) {
      debugPrint('No se pudieron traer los temas de avisos: $err');
    }

    await reconciliar();
  }

  /// Pone las suscripciones de acuerdo con el catálogo y las preferencias.
  ///
  /// El método central, y el único que habla con Firebase de temas. Calcula a
  /// qué debería estar apuntado este teléfono, lo compara con lo que tiene
  /// anotado y **solo mueve la diferencia**: nada de soltarlo todo y volver a
  /// cogerlo, que sería una ventana en la que los avisos no llegan.
  ///
  /// Sirve para las tres cosas que cambian el resultado —entrar, tocar un
  /// interruptor, y que el colegio añada un acudido— sin escribirlo tres veces.
  static Future<void> reconciliar() async {
    if (!disponible || !await hayPermiso()) return;

    final catalogo = await AvisosGuardados.catalogo();
    if (catalogo == null) return;

    final cambio = calcularCambio(
      catalogo: catalogo,
      encendidos: await PreferenciasAvisos.encendidos(),
      anotados: await AvisosGuardados.suscritos(),
    );

    for (final tema in cambio.soltar) {
      await _soltar(tema);
    }

    for (final tema in cambio.coger) {
      await _coger(tema);
    }

    await AvisosGuardados.guardarSuscritos(cambio.quedan);
  }

  /// Guarda la preferencia y la aplica, sin tocar el servidor.
  static Future<void> cambiarPreferencia(TipoDeAviso tipo, bool quiere) async {
    await PreferenciasAvisos.setQuiere(tipo, quiere);
    await reconciliar();
  }

  /// Al cerrar sesión: soltar **todos** los temas, encendidos o no.
  ///
  /// Si se soltaran solo los encendidos, el teléfono prestado seguiría apuntado
  /// a los que la persona anterior había apagado — y bastaría con que la
  /// siguiente los encendiera para empezar a recibir avisos de un alumno que no
  /// es el suyo.
  ///
  /// Se sueltan por lo **anotado** y no por el catálogo, y no es un atajo: aquí
  /// el token ya está muerto o a punto, así que preguntarle al servidor de qué
  /// hay que desapuntarse no es una opción. Por eso existe
  /// [AvisosGuardados.suscritos].
  ///
  /// **Las preferencias no se borran**: son del teléfono, no de la cuenta. Ver
  /// [PreferenciasAvisos.olvidar].
  static Future<void> soltarTodo() async {
    if (!disponible) return;

    for (final tema in await AvisosGuardados.suscritos()) {
      await _soltar(tema);
    }

    await AvisosGuardados.olvidar();
  }

  static Future<void> _coger(String tema) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(tema);
    } catch (err) {
      debugPrint('No se pudo apuntar al tema: $err');
    }
  }

  static Future<void> _soltar(String tema) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(tema);
    } catch (err) {
      debugPrint('No se pudo soltar el tema: $err');
    }
  }

  static Future<void> _pintarEnPrimerPlano(RemoteMessage mensaje) async {
    final aviso = mensaje.notification;
    if (aviso == null) return;
    final datos = _datosDe(mensaje);

    try {
      await _local.show(
        // El identificador del aviso, que es también su agrupación: con uno
        // fijo por pantalla —y por asignatura—, tres avisos seguidos de lo
        // mismo reemplazan el anterior en vez de apilar tres carteles iguales.
        id: Object.hash(_abridorDe(datos), datos['asignatura']),
        title: aviso.title,
        body: aviso.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            canalId,
            canalNombre,
            channelDescription: canalDescripcion,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        payload: jsonEncode(datos),
      );
    } catch (err) {
      debugPrint('No se pudo pintar el aviso: $err');
    }
  }

  /// La ruta que abre un aviso, según lo que manda el servidor en `data`.
  ///
  /// El servidor pone `pantalla` con uno de estos cinco valores —ver
  /// `EnviarNotificaciones.php`—. Lo que no reconozca abre el muro, que es la
  /// pantalla de inicio: un aviso de una versión más nueva del servidor tiene
  /// que abrir *algo*, no quedarse quieto.
  ///
  /// El `alumno_id` que a veces viene **no se usa todavía**: las pantallas del
  /// acudiente no reciben argumentos, resuelven el acudido por dentro. Cuando
  /// los reciban, el dato ya está llegando.
  @visibleForTesting
  static String abridorDe(Map<String, dynamic> datos) => _abridorDe(datos);

  static String _abridorDe(Map<String, dynamic> datos) {
    switch ('${datos['pantalla'] ?? ''}') {
      case 'notas':
        return '/mis-notas';
      case 'asistencia':
        return '/mi-asistencia';
      case 'disciplina':
        return '/mi-disciplina';
      case 'matricula':
        return '/mi-matricula';
      default:
        return '/muro';
    }
  }

  /// Qué hay que mover para que las suscripciones digan lo que deberían.
  ///
  /// La cuenta entera, sin tocar Firebase ni el disco, que es lo que la hace
  /// probable. Lo de fuera es aplicarla.
  ///
  /// Tres cosas salen de aquí y las tres importan:
  ///
  ///  - **Solo se mueve la diferencia.** Nada de soltarlo todo y volver a
  ///    cogerlo: sería una ventana, corta pero real, en la que los avisos no
  ///    llegan.
  ///  - **Lo anotado que ya no está en el catálogo se suelta.** No es solo un
  ///    tipo apagado: es el acudido cuya matrícula terminó. El servidor deja de
  ///    mandarlo y aquí es donde el teléfono lo suelta — si no, el acudiente de
  ///    quien se fue hace tres años seguiría recibiendo sus avisos.
  ///  - **[quedan] es lo querido, no lo anotado más lo nuevo.** Es lo que se
  ///    guarda, y por eso un tema que se soltó desaparece del apunte.
  static CambioDeTemas calcularCambio({
    required TemasDeNotificacion catalogo,
    required List<TipoDeAviso> encendidos,
    required Set<String> anotados,
  }) {
    final queridos = <String>{
      ...catalogo.temasDe(encendidos),
      // Los del colegio —muro y avisos— siguen apagados: ver
      // PendientesNotificaciones.temasDelColegio.
      if (PendientesNotificaciones.temasDelColegio)
        ...catalogo.delColegio.values,
    };

    return CambioDeTemas(
      coger: queridos.difference(anotados),
      soltar: anotados.difference(queridos),
      quedan: queridos,
    );
  }

  static void _abrirPantalla(Map<String, dynamic> datos) {
    final navegador = navegadorDeLaApp.currentState;
    if (navegador == null) return;

    // `pushNamedAndRemoveUntil` y no `pushNamed`: el aviso es un punto de
    // entrada, no un paso más. Con `push` a secas, tocar tres avisos seguidos
    // dejaría tres pantallas apiladas y el botón de atrás recorriéndolas.
    navegador.pushNamedAndRemoveUntil(
      _abridorDe(datos),
      (_) => false,
      arguments: _abridorDe(datos) == '/mis-notas'
          ? AvisoDeNotas.deDatos(datos)
          : null,
    );
  }

  /// Los `data` del mensaje, con la asignatura puesta si el aviso es de una.
  ///
  /// El servidor agrupa los avisos de notas **por alumno y asignatura** —uno
  /// por materia— y dice cuál en el texto («… en Sociales.»), pero no en
  /// `data`. Mientras no la mande ahí, se saca del texto; si algún día la
  /// manda, gana la suya. Un texto que no tenga esa forma deja el aviso sin
  /// asignatura, y entonces abre «Mis notas» entera, que es lo que toca
  /// cuando el aviso habla de varias.
  static Map<String, dynamic> _datosDe(RemoteMessage mensaje) {
    final datos = Map<String, dynamic>.from(mensaje.data);
    if (datos['pantalla'] == 'notas' &&
        '${datos['asignatura'] ?? ''}'.trim().isEmpty) {
      final sacada = asignaturaDelTexto(mensaje.notification?.body);
      if (sacada != null) datos['asignatura'] = sacada;
    }
    return datos;
  }

  /// La asignatura de un texto como «Laura tiene 2 notas nuevas en Sociales.»
  ///
  /// El formato es el de `EnviarNotificaciones::avisosDeNotas`.
  @visibleForTesting
  static String? asignaturaDelTexto(String? cuerpo) {
    if (cuerpo == null) return null;
    final hallado =
        RegExp(r'notas? nuevas? en (.+?)\.?\s*$').firstMatch(cuerpo.trim());
    final nombre = hallado?.group(1)?.trim();
    return nombre == null || nombre.isEmpty ? null : nombre;
  }
}

/// El resultado de [Avisos.calcularCambio].
class CambioDeTemas {
  const CambioDeTemas({
    required this.coger,
    required this.soltar,
    required this.quedan,
  });

  /// A los que hay que apuntarse ahora.
  final Set<String> coger;

  /// De los que hay que desapuntarse ahora.
  final Set<String> soltar;

  /// A los que queda apuntado el teléfono cuando esto se aplique. Es lo que se
  /// anota, y lo único con lo que se podrán soltar al cerrar sesión.
  final Set<String> quedan;
}

/// Lo que un aviso de notas le dice a «Mis notas»: de quién y de qué materia.
///
/// Cualquiera de los dos puede faltar, y entonces la pantalla hace lo de
/// siempre con lo que falte: preguntar el acudido, o quedarse en la lista.
class AvisoDeNotas {
  const AvisoDeNotas({this.alumnoId, this.asignatura});

  final int? alumnoId;
  final String? asignatura;

  factory AvisoDeNotas.deDatos(Map<String, dynamic> datos) {
    final nombre = '${datos['asignatura'] ?? ''}'.trim();
    return AvisoDeNotas(
      alumnoId: int.tryParse('${datos['alumno_id'] ?? ''}'),
      asignatura: nombre.isEmpty ? null : nombre,
    );
  }

  /// Si [materia] o [alias] es la asignatura del aviso.
  ///
  /// El servidor la nombra por el alias si lo hay, y si no por la materia.
  bool esDe({required String materia, String? alias}) {
    final buscada = asignatura?.trim().toLowerCase();
    if (buscada == null) return false;
    return materia.trim().toLowerCase() == buscada ||
        (alias ?? '').trim().toLowerCase() == buscada;
  }
}
