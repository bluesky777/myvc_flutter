import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/ConfiguracionColegio.dart';
import 'package:myvc_flutter/Utils/SesionGuardada.dart';
import 'package:myvc_flutter/Utils/VersionMinima.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El año y el periodo con los que trabaja el usuario ahora mismo.
///
/// Todo lo que la app pide al servidor cuelga de esta elección: las faltas son
/// las del periodo, las notas son las del periodo, y el listado de grupos es el
/// del año. El backend no la recibe en cada petición —la lee de la fila del
/// usuario—, así que cambiarla es escribir en el servidor y no solo en la app.
///
/// Y ojo con cómo la guarda el backend: en `users` solo hay `periodo_id`. El
/// año sale de a qué año pertenece ese periodo, de modo que cambiar de año es,
/// por debajo, elegir un periodo del año nuevo. Eso lo resuelve
/// `PUT years/useractive/{id}`, que busca el periodo del mismo número en el año
/// destino y, si no existe, se queda con el último.
class ContextoAcademico extends ChangeNotifier {
  ContextoAcademico._();

  static final ContextoAcademico instancia = ContextoAcademico._();

  int? yearId;
  String? year;
  int? periodoId;
  int? numeroPeriodo;

  /// Cómo está configurado el colegio, según la misma respuesta de /login.
  ///
  /// Va aquí y no en un sitio propio porque dos de esos ajustes son del
  /// periodo —si los docentes pueden editar notas y si pueden nivelar—, así
  /// que cambian con él. Colgados de aquí se releen en [refrescar] junto con
  /// todo lo demás y no hay forma de que se queden con los del periodo
  /// anterior; sueltos, habría que acordarse de releerlos.
  ConfiguracionColegio config = const ConfiguracionColegio.vacia();

  /// Los años del colegio con sus periodos, para el cuadro de cambio.
  List<YearModel> years = [];

  /// Las siglas del colegio —`LAL`, `CASB`—, que es lo que cabe en la barra.
  ///
  /// **Se llena de dos sitios y por eso no es `final`.** De la respuesta de
  /// `/login`, si la trae, que es lo que la deja puesta desde el primer
  /// arranque; y de `GET /years`, que seguro la trae —selecciona `y.*`— pero
  /// solo se pide cuando alguien abre el selector de periodo, porque es la
  /// consulta cara. Lo segundo no pisa lo primero con vacío: ver [_guardar].
  ///
  /// Vacía mientras no llegue de ninguno de los dos, y también en el colegio
  /// que nunca rellenó esa columna. Quien la use decide el respaldo, y el de la
  /// barra es no poner siglas: **calcularlas del nombre salía mal**. El nombre
  /// que la app tiene antes de entrar viene de `listado_colegios.php`, y ahí no
  /// hay nombres de colegio sino sitios —«Libertad Tame», «Arauca», «Fortul»—,
  /// así que el Liceo Adventista Libertad salía `LT`. Una sigla equivocada es
  /// peor que ninguna: se lee como un dato, no como un hueco.
  String abrevColegio = '';

  /// El archivo del logo del colegio, para la barra de arriba.
  ///
  /// Mismo origen y mismas reglas que [abrevColegio]: llega en `GET /years`, se
  /// guarda en disco y lo vacío nunca pisa a lo lleno. Vacío también es una
  /// respuesta — hay colegios sin logo, y la barra se pinta igual sin él.
  String logoColegio = '';

  /// Dónde se recuerda entre arranques.
  ///
  /// Se guarda porque la única fuente segura es `GET /years`, y esa consulta no
  /// se hace en cada arranque a propósito —es el N+1 que `VerificacionSesion`
  /// existe para espaciar—. Sin recordarla, la barra abriría sin siglas cada
  /// mañana y las estrenaría a media sesión, cuando algo pidiera los años.
  static const String claveAbrev = 'colegio_abrev';
  static const String claveLogo = 'colegio_logo';

  bool get hayContexto => yearId != null && periodoId != null;

  /// El año y el periodo escritos enteros: «2026 · Periodo 3».
  String get titulo {
    if (year == null && numeroPeriodo == null) return 'Sin periodo';
    if (numeroPeriodo == null) return '$year';
    if (year == null) return 'Periodo $numeroPeriodo';
    return '$year · Periodo $numeroPeriodo';
  }

  /// Lo mismo abreviado, que es lo que se lee en la barra: «2026 · Per 3».
  ///
  /// Existe desde que el año y el periodo dejaron de tener franja propia y
  /// pasaron a compartir fila con el nombre de la pantalla. Ahí «Periodo»
  /// gastaba cuatro letras en decir algo que el número de al lado ya dice, y
  /// las gastaba **contra el título**, que es lo que se recorta primero.
  String get tituloCorto {
    if (year == null && numeroPeriodo == null) return 'Sin periodo';
    if (numeroPeriodo == null) return '$year';
    if (year == null) return 'Per $numeroPeriodo';
    return '$year · Per $numeroPeriodo';
  }

  /// Los periodos del año en curso, cuando los años ya se trajeron.
  ///
  /// Vacío mientras nadie haya llamado a [cargarYears]: la barra de arriba los
  /// pide al abrirse, pero una pantalla que los necesite antes tiene que
  /// pedirlos ella.
  List<PeriodoModel> get periodosDelYear {
    for (final anio in years) {
      if (anio.id == yearId) return anio.periodos;
    }
    return const [];
  }

  /// El id del periodo que hace el número dado, dentro del año en curso.
  ///
  /// Hace falta donde se trabaja con los cuatro periodos a la vez —disciplina
  /// enseña el año entero— y no solo con el de la barra: para crear algo en el
  /// periodo 2 hay que mandarle al backend su `periodo_id`, y el número no le
  /// vale.
  ///
  /// Cuando se pregunta justo por el periodo en el que está el usuario se
  /// responde con el suyo aunque los años no se hayan traído todavía, que es
  /// el caso más común y el que no debería depender de una segunda petición.
  int? periodoIdDe(int numero) {
    if (numero == numeroPeriodo && periodoId != null) return periodoId;

    for (final periodo in periodosDelYear) {
      if (periodo.numero == numero) return periodo.id;
    }
    return null;
  }

  /// Lo que vino en la respuesta de /login.
  void tomarDelLogin(Map<String, dynamic> datos) {
    yearId = _entero(datos['year_id']);
    year = datos['year']?.toString();
    periodoId = _entero(datos['periodo_id']);
    numeroPeriodo = _entero(datos['numero_periodo']);
    config = ConfiguracionColegio.deLogin(datos);
    _guardar(claveAbrev, datos['abrev_colegio']);
    notifyListeners();
  }

  /// Saca las siglas del colegio del cuerpo de `GET /years`, venga de donde venga.
  ///
  /// **Público y suelto del resto a propósito.** La app pide `/years` en dos
  /// sitios y solo uno construye el contexto: el otro es
  /// `LoginController._tokenSigueValiendo()`, que lo llama para comprobar el
  /// token y **tira la respuesta mirándole solo el código de estado**. Esa
  /// respuesta ya trae `abrev_colegio` —el endpoint selecciona `y.*`—, así que
  /// leerla ahí son las siglas **gratis, sin una petición más**, en el arranque
  /// en frío, que es justo cuando hacen falta.
  ///
  /// Se queda con las del año en curso; si ése no las trae, con las de
  /// cualquier año que las tenga. Son del colegio y no del año, así que da
  /// igual de cuál se lean — lo que no da igual es quedarse sin ellas porque el
  /// año en curso tenga la columna vacía.
  ///
  /// Nunca falla: un cuerpo que no se entienda es un `/years` de una versión
  /// que no conocemos, y eso no puede tumbar ni el arranque ni la comprobación
  /// del token.
  void tomarSenasDelColegio(String cuerpo) {
    try {
      final crudos = jsonDecode(cuerpo);
      if (crudos is! List) return;

      final anios = crudos
          .whereType<Map>()
          .map((y) => YearModel.fromJson(Map<String, dynamic>.from(y)))
          .toList();

      // El año en curso primero; si a ése le falta algo, cualquier otro que lo
      // tenga. Y **las dos señas por separado**: un año puede traer la sigla y
      // no el logo, y quedarse sin logo por eso sería perderlo por nada.
      final porOrden = [...anios.where((y) => y.id == yearId), ...anios];

      _guardar(
        claveAbrev,
        porOrden.map((y) => y.abrevColegio).firstWhere(
              (v) => v.isNotEmpty,
              orElse: () => '',
            ),
      );
      _guardar(
        claveLogo,
        porOrden.map((y) => y.logo).firstWhere(
              (v) => v.isNotEmpty,
              orElse: () => '',
            ),
      );
      notifyListeners();
    } catch (_) {
      // Sin siglas, y sin ruido.
    }
  }

  /// Guarda las siglas **solo si traen algo**.
  ///
  /// Sin esta comprobación, `/years` llegando después del login con la columna
  /// vacía borraría las que el login ya había puesto, y la barra pasaría de
  /// decir `LAL` a decir `Inicio` a mitad de sesión — un rótulo que empeora
  /// solo, que es de los fallos que nadie reporta porque parece un parpadeo.
  /// Guarda una seña **solo si trae algo**.
  ///
  /// Sin esta comprobación, `/years` llegando después del login con la columna
  /// vacía borraría lo que el login ya había puesto, y la barra pasaría de
  /// decir `LAL` a decir `Inicio` a mitad de sesión — un rótulo que empeora
  /// solo, que es de los fallos que nadie reporta porque parece un parpadeo.
  void _guardar(String clave, dynamic crudo) {
    final valor = '${crudo ?? ''}'.trim();
    if (valor.isEmpty) return;

    if (clave == claveAbrev) {
      if (valor == abrevColegio) return;
      abrevColegio = valor;
    } else {
      if (valor == logoColegio) return;
      logoColegio = valor;
    }

    // Al disco sin esperar: que la próxima apertura ya abra con ellas.
    SharedPreferences.getInstance()
        .then((p) => p.setString(clave, valor))
        .catchError((_) => false);
  }

  /// Recupera las señas guardadas la última vez. Se llama al arrancar.
  Future<void> recordarSenasDelColegio() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _guardar(claveAbrev, preferences.getString(claveAbrev));
      _guardar(claveLogo, preferences.getString(claveLogo));
      if (abrevColegio.isNotEmpty || logoColegio.isNotEmpty) notifyListeners();
    } catch (_) {
      // Sin señas guardadas, que es como el primer arranque.
    }
  }

  /// Deja el contexto como recién arrancada la app.
  void limpiar() {
    yearId = null;
    year = null;
    periodoId = null;
    numeroPeriodo = null;
    years = [];
    abrevColegio = '';
    logoColegio = '';
    SharedPreferences.getInstance().then((p) async {
      await p.remove(claveAbrev);
      await p.remove(claveLogo);
    }).catchError((_) {});
    config = const ConfiguracionColegio.vacia();
    notifyListeners();
  }

  /// Trae los años con sus periodos, si no se han traído ya.
  ///
  /// Es lo que llena el selector de año de [BarraContexto].
  ///
  /// **Un año sin periodos se descarta, y para la app es como si no
  /// existiera.** No es un capricho: aquí se trabaja en año *y* periodo —esta
  /// clase guarda `periodoId` y casi todas las pantallas lo mandan—, y
  /// `PUT years/useractive/{id}` mueve al usuario al periodo del mismo número
  /// en el año destino, o al último si no lo tiene. Con cero periodos no hay
  /// dónde caer: elegir ese año dejaría la app en un estado que ninguna
  /// pantalla sabe pintar.
  ///
  /// **Lo que cuesta es que el descarte es mudo**, y conviene saberlo antes de
  /// diagnosticar. El caso real es un colegio que crea el año siguiente en la
  /// plataforma web y todavía no le ha puesto los periodos: en la web el año
  /// aparece, en la app **no**, y no sale ningún error —simplemente no está en
  /// la lista—. «No me sale el año nuevo» se contesta mirando aquí, y se
  /// arregla creándole los periodos, no tocando la app.
  ///
  /// El mismo filtro está en [FaltasAlumnoScreen], que sí lo dice en voz alta
  /// cuando se queda sin ninguno: «El colegio no tiene años con periodos». Aquí
  /// no hay dónde decirlo sin inventarse un aviso en una barra que es de otra
  /// cosa, así que queda escrito.
  ///
  /// Lo levantó la sesión del backend el 2 de septiembre de 2026, mirando qué
  /// hacía Flutter con las respuestas de `years`: es la clase de filtro de
  /// cliente que hace que un dato del servidor no aparezca sin que nadie vea un
  /// fallo.
  Future<void> cargarYears(Server server, {bool forzar = false}) async {
    if (years.isNotEmpty && !forzar) return;

    final res = await server.get('/years');
    if (res.statusCode >= 300) {
      throw Exception('El servidor respondió ${res.statusCode}.');
    }

    tomarSenasDelColegio(res.body);

    final crudos = jsonDecode(res.body) as List;
    years = crudos
        .map((y) => YearModel.fromJson(y as Map<String, dynamic>))
        .where((y) => y.periodos.isNotEmpty)
        .toList()
      ..sort((a, b) => b.year.compareTo(a.year));

    notifyListeners();
  }

  /// Cambia el año del usuario.
  ///
  /// `PUT years/useractive/{id}`, que es exactamente lo que llama el front web
  /// desde su barra de arriba. El backend no guarda el año en ninguna parte:
  /// mueve al usuario al periodo del mismo número en el año destino y, si ese
  /// año no lo tiene, al último. O sea que el periodo cambia también, y no
  /// siempre al que uno esperaría: por eso después se relee, en vez de dar por
  /// hecho cuál quedó.
  Future<String?> cambiarYear(Server server, YearModel yearNuevo) async {
    return _cambiar(
      server,
      ruta: '/years/useractive/${yearNuevo.id}',
      accion: 'cambiar de año',
    );
  }

  /// Cambia el periodo del usuario.
  ///
  /// `PUT periodos/useractive/{id}`, el otro de la barra del front.
  Future<String?> cambiarPeriodo(Server server, PeriodoModel periodoNuevo) {
    return _cambiar(
      server,
      ruta: '/periodos/useractive/${periodoNuevo.id}',
      accion: 'cambiar de periodo',
    );
  }

  Future<String?> _cambiar(
    Server server, {
    required String ruta,
    required String accion,
  }) async {
    try {
      final res = await server.put(ruta, {});
      if (res.statusCode >= 300) return _mensaje(res.statusCode, accion);

      return await refrescar(server);
    } catch (err) {
      return 'No se pudo $accion: $err';
    }
  }

  /// Vuelve a leer del servidor con qué año y periodo quedó el usuario.
  ///
  /// Es la misma llamada que hace la app al entrar —`POST /login` con el
  /// token—, que devuelve el contexto ya resuelto. El front web consigue lo
  /// mismo recargando la página entera después de cambiar; aquí basta con
  /// releer, y así lo que se pinta arriba es lo que de verdad quedó guardado y
  /// no lo que la app supuso.
  Future<String?> refrescar(Server server) async {
    try {
      final res = await server.login();
      if (res.statusCode >= 300) {
        return 'Se cambió, pero no se pudo releer el periodo'
            ' (HTTP ${res.statusCode}).';
      }

      final datos = jsonDecode(res.body);
      if (datos is! Map) return 'Se cambió, pero el servidor no dijo con qué.';

      tomarDelLogin(Map<String, dynamic>.from(datos));

      // La misma respuesta trae la versión mínima, y esta es la única llamada
      // a /login que hace la app ya estando dentro: es donde se entera de que
      // el colegio subió el número sin tener que salir y volver a entrar.
      VersionMinima.tomarDe(datos);

      // La sesión guardada tiene una copia de esta misma respuesta, y acaba de
      // quedarse vieja: el periodo es otro. Sin esto, recargar la página
      // devolvería al usuario al periodo anterior.
      await SesionGuardada.actualizarUsuario(res.body);

      return null;
    } catch (err) {
      return 'Se cambió, pero no se pudo releer el periodo: $err';
    }
  }

  String _mensaje(int codigo, String accion) {
    if (codigo == 400 || codigo == 401 || codigo == 403) {
      return 'No tienes permiso para $accion.';
    }
    return 'No se pudo $accion (HTTP $codigo).';
  }

  static int? _entero(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString().trim());
  }
}
