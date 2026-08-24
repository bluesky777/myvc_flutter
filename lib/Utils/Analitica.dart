import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:myvc_flutter/Utils/PreferenciasAnalitica.dart';

/// La analítica de uso, y el único sitio que habla con Firebase Analytics.
///
/// Existe por dos razones, y la segunda es la que importa:
///
/// 1. Para que apagarla, o cambiarla de proveedor, sea tocar un archivo.
/// 2. Para que **la regla de qué se puede mandar viva en un solo lugar**. La
///    regla es: a Analytics no va nada que identifique a una persona —ni
///    nombres, ni documentos, ni `alumno_id`, ni una nota, ni el nombre de un
///    grupo—. Son menores, los términos de Google lo prohíben, y ninguna de las
///    preguntas que motivan esto necesita saber quién. Ver docs/analitica.md.
///
/// Todo lo de aquí es *fire and forget* y no se espera: una métrica no puede
/// hacer esperar a un docente que está pasando notas, y menos aún tumbarle la
/// pantalla si Google no contesta.
class Analitica {
  Analitica._();

  /// Si hay una instancia viva a la que mandarle eventos.
  ///
  /// Nula mientras no se llame a [arrancar], y **nula siempre en web y en las
  /// pruebas**, donde no hay un Firebase en pie detrás: ver [arrancar]. Todo lo
  /// demás de esta clase se apoya en esto, no en [disponible].
  static FirebaseAnalytics? _analytics;

  /// Dónde se intenta medir.
  ///
  /// Solo Android. En Firebase hay registrada una sola app —la de Android, con
  /// su `google-services.json`—, y `Firebase.initializeApp()` sin opciones
  /// explícitas no encuentra proyecto en la web: reventaría al arrancar en un
  /// sitio donde hoy la app funciona. Cuando se registre la app web y se genere
  /// `firebase_options.dart`, esto se amplía; hasta entonces, en web la
  /// analítica es un no-op silencioso y la app se comporta igual que siempre.
  ///
  /// Ojo: esto dice **dónde se quiere** medir, no si se está midiendo. Lo
  /// segundo lo dice `_analytics`, que solo deja de ser nulo si [arrancar] pudo
  /// de verdad. En `flutter test` esto vale `true` —el entorno de pruebas se
  /// presenta como Android— y aun así no se mide nada, que es lo correcto.
  static bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Si el dueño de este teléfono no la ha apagado.
  ///
  /// Se lee del disco al arrancar y se conserva aquí para que consultarla no
  /// sea `async`: los sitios que cuentan algo —el `initState` de una pantalla,
  /// el guardado de una columna de notas— no pueden esperar a `SharedPreferences`
  /// solo para decidir si mandan un evento.
  ///
  /// Arranca en `true` para que el valor de partida no dependa de que el disco
  /// conteste a tiempo; si estaba apagada, [aplicarPreferencia] lo corrige unos
  /// milisegundos después, y de todas formas el propio SDK ya tiene guardado
  /// del arranque anterior que la recogida está apagada.
  static bool _activa = true;

  /// Si ahora mismo se está midiendo. Es lo que pinta el interruptor.
  static bool get activa => _activa;

  /// Enciende la analítica. Se llama una vez, después de `Firebase.initializeApp`.
  ///
  /// Si Firebase no está en pie, se queda apagada y no dice nada. El `try` no
  /// es de adorno: `FirebaseAnalytics.instance` lanza `[core/no-app]` en cuanto
  /// se toca sin haber inicializado, y eso pasa en las pruebas y pasaría en un
  /// arranque donde `initializeApp` fallara. Que el motivo de que la app no
  /// abra sea la analítica es justo lo que no puede ocurrir.
  static void arrancar() {
    if (!disponible) return;
    try {
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {
      _analytics = null;
    }
  }

  /// Lee del disco si este teléfono quiere aparecer, y se lo dice al SDK.
  ///
  /// Se llama al arrancar, justo después de [arrancar]. Se hace en dos pasos
  /// —encender y luego aplicar— porque leer el disco es `async` y el arranque
  /// no debe esperar a esto para seguir montando la app.
  static Future<void> aplicarPreferencia() async {
    _activa = await PreferenciasAnalitica.activa();
    _intentarSiempre(
      () => _analytics?.setAnalyticsCollectionEnabled(_activa),
    );
  }

  /// Enciende o apaga las estadísticas en este dispositivo, y lo recuerda.
  ///
  /// Apagarlas es de verdad: `setAnalyticsCollectionEnabled(false)` corta la
  /// recogida en el propio SDK y **el SDK lo recuerda entre arranques**, así
  /// que no queda un hueco entre que la app abre y esta preferencia se lee.
  static Future<void> cambiar(bool valor) async {
    _activa = valor;
    await PreferenciasAnalitica.setActiva(valor);
    _intentarSiempre(() => _analytics?.setAnalyticsCollectionEnabled(valor));
  }

  /// El observador que registra los cambios de pantalla.
  ///
  /// Devuelve una lista para poder pegarla tal cual en `navigatorObservers` sin
  /// un condicional en `main`: vacía cuando no hay analítica.
  ///
  /// **Se crea una sola vez.** Esto se lee dentro del `build` de `MyApp`, y un
  /// observador nuevo en cada reconstrucción haría que el `Navigator` tuviera
  /// que soltar el viejo y enganchar el nuevo, perdiendo de paso lo que el
  /// observador sabe de la pantalla anterior — que es justo con lo que arma el
  /// `screen_view`.
  ///
  /// **Solo ve las rutas que tienen nombre.** Las que se abren con un `push`
  /// directo hay que darles `settings: RouteSettings(name: …)` o saldrían como
  /// huecos — y son justo las que más interesan. Ver docs/analitica.md → «Una
  /// trampa del código».
  static List<NavigatorObserver>? _observadores;

  static List<NavigatorObserver> get observadores {
    final instancia = _analytics;
    if (instancia == null) return const [];
    return _observadores ??= [FirebaseAnalyticsObserver(analytics: instancia)];
  }

  /// Quién está usando la app, en las dos únicas dimensiones que se guardan.
  ///
  /// - [rol] separa «los docentes no la usan» de «los acudientes no la usan»,
  ///   que son dos problemas distintos.
  /// - [servidor] es de qué colegio de los dieciséis se trata. Se guarda solo
  ///   el **host**: la URL completa no añade nada y arrastra rutas.
  ///
  /// Ninguna de las dos identifica a una persona, y no se añade una tercera:
  /// en un colegio pequeño, cruzar rol con grupo o con asignatura deja a
  /// alguien solo en una casilla.
  static void sesion({required String rol, required String servidor}) {
    _intentar(() async {
      await _analytics?.setUserProperty(name: 'rol', value: rol);
      await _analytics?.setUserProperty(
        name: 'colegio',
        value: _host(servidor),
      );
    });
  }

  /// Al cerrar sesión: olvidar quién era.
  ///
  /// Sin esto, el teléfono prestado o el del colegio seguiría contando sus
  /// pantallas bajo el rol del usuario anterior. Es el mismo cuidado que ya se
  /// tiene con el token en `AuthService.limpiar()`.
  static void olvidar() {
    _intentar(() async {
      await _analytics?.setUserProperty(name: 'rol', value: null);
      await _analytics?.setUserProperty(name: 'colegio', value: null);
    });
  }

  /// Una pantalla que no llegó por una ruta con nombre.
  static void pantalla(String nombre) {
    _intentar(() => _analytics?.logScreenView(screenName: nombre));
  }

  /// Un evento con sus parámetros.
  ///
  /// Los parámetros son **cantidades y nombres de pantalla**, nunca un dato de
  /// una persona: «se guardaron 28 notas» contesta lo mismo que «Ana guardó 28
  /// notas» y no arrastra a nadie.
  static void evento(String nombre, {Map<String, Object>? datos}) {
    _intentar(() => _analytics?.logEvent(name: nombre, parameters: datos));
  }

  /// Envuelve el `onRefresh` de un `RefreshIndicator` para contarlo.
  ///
  /// Tirar hacia abajo es lo que hace alguien que no se fía de lo que está
  /// viendo, y saber en qué pantalla pasa dice dónde el dato llega tarde o
  /// parece equivocado. Se envuelve en vez de poner la línea en cada sitio para
  /// que el nombre de la pantalla se escriba **una vez y al lado del uso**, y
  /// para que no haya diez formas ligeramente distintas de contar lo mismo.
  ///
  /// Devuelve la recarga tal cual: no la espera, no la cambia y no la puede
  /// romper.
  static Future<void> Function() refresco(
    String pantalla,
    Future<void> Function() recargar,
  ) {
    return () {
      evento('refresco_manual', datos: {'pantalla': pantalla});
      return recargar();
    };
  }

  /// El host de una URL de colegio, o la cadena tal cual si no se puede leer.
  static String _host(String servidor) {
    final leida = Uri.tryParse(servidor);
    final host = leida?.host;
    return (host == null || host.isEmpty) ? servidor : host;
  }

  /// Manda algo, si hay a quién y si este teléfono quiere aparecer.
  ///
  /// La comprobación de [_activa] es un cinturón sobre el tirante: apagar ya
  /// corta la recogida dentro del SDK. Está porque el interruptor tiene que ser
  /// creíble, y que ni siquiera se construya el evento es más fácil de afirmar
  /// —y de leer aquí— que fiarse de lo que hace Google por dentro.
  static void _intentar(Future<void>? Function() accion) {
    if (!_activa) return;
    _intentarSiempre(accion);
  }

  /// Ejecuta sin esperar y sin dejar que un fallo suba.
  ///
  /// Que Google no conteste, o que el paquete cambie de idea sobre qué acepta,
  /// no puede ser nunca la razón de que una pantalla se caiga.
  ///
  /// No mira [_activa] a propósito: por aquí pasa justamente la llamada que
  /// **apaga** la recogida, y filtrarla por la preferencia que acaba de
  /// cambiar la dejaría sin efecto.
  static void _intentarSiempre(Future<void>? Function() accion) {
    if (_analytics == null) return;
    try {
      accion()?.catchError((_) {});
    } catch (_) {
      // Una métrica perdida no es un fallo de la app.
    }
  }
}
