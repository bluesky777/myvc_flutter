import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/ClienteApp.dart';

class Server {
  /// Qué hacer cuando una petición que llevaba token vuelve con 401.
  ///
  /// Un 401 es siempre lo mismo: no hay token, venció o lo revocaron. Antes
  /// cada pantalla lo enseñaba como un error suyo —«No se pudo abrir la
  /// disciplina. El servidor respondió 401.»— y reintentar no servía de nada:
  /// el token que dura 24 h fijas seguía muerto hasta cerrar sesión a mano. Lo
  /// monta main.dart con [SesionCaducada.notar]; aquí es un gancho y no una
  /// llamada directa para que Server no dependa del login, y en las pruebas,
  /// que no lo montan, no pasa nada.
  ///
  /// Recibe el token con el que salió la petición, no el de ahora: una
  /// respuesta que llega después de que se entrara con otra cuenta no puede
  /// echar a la cuenta nueva.
  static void Function(String? tokenUsado)? alCaducarSesion;

  /// Las rutas cuyo 401 no es una sesión caducada.
  ///
  /// `login/logout` responde 401 si el token ya estaba muerto, y quien la
  /// llama ya está saliendo: avisar ahí sería salir dos veces a la vez.
  static const List<String> _sin401Global = ['/login/logout'];

  Future<T> _vigilando<T>(
      String direccion, String? tokenUsado, Future<T> peticion) async {
    final T res;
    try {
      res = await peticion;
    } on http.ClientException catch (err) {
      throw SinConexion(err);
    } catch (err) {
      // `SocketException` y `HandshakeException` son de `dart:io`, que no se
      // puede importar en una app que también compila a web: por su nombre.
      if (SinConexion.loParece(err)) throw SinConexion(err);
      rethrow;
    }
    if (res is http.BaseResponse &&
        res.statusCode == 401 &&
        tokenUsado != null &&
        !_sin401Global.contains(direccion)) {
      alCaducarSesion?.call(tokenUsado);
    }
    return res;
  }

  /// El servidor del colegio. Lo fija el login, que es quien sabe cuál es.
  ///
  /// Vacío mientras nadie haya entrado: antes aquí había una IP de una red
  /// local —192.168.18.215— commiteada, con otras dos comentadas encima. Iba
  /// cambiando de casa en casa y de commit en commit, y a cualquiera que
  /// clonara el proyecto le apuntaba a una máquina que no es la suya.
  ///
  /// Para desarrollar contra un servidor propio sin volver a commitear una
  /// dirección:
  ///
  ///   flutter run -d chrome --dart-define=SERVIDOR=http://192.168.1.5
  static String urlServer =
      const String.fromEnvironment('SERVIDOR', defaultValue: '');

  static String urlApi = '$urlServer/api';
  static String urlImages = '$urlServer/images/perfil';

  Server();

  /// La URL de una foto de perfil, con el nombre escapado.
  ///
  /// Los nombres vienen de la tabla images tal como se subieron, con carpeta y
  /// con espacios —'user_2/P Ariolfo.JPG'—, y un espacio en una URL no es
  /// válido. Se escapa tramo a tramo para no tocar las barras.
  ///
  /// Cadena vacía si no hay foto: quien la pinte decide qué poner en su lugar.
  static String urlFoto(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return '';

    final ruta = nombre.split('/').map(Uri.encodeComponent).join('/');
    return '${Server.urlImages}/$ruta';
  }

  Uri _uri(String direction) => Uri.parse('${Server.urlApi}$direction');

  /// Las rutas a las que se les pide `Accept: application/json`.
  ///
  /// Sin esa cabecera, un `abort(403, '…')` de Laravel vuelve como página HTML
  /// y **el motivo que escribió el servidor se pierde**: «esta nota puede darla
  /// por resuelta quien la escribió…», «ese formulario todavía no está atado a
  /// ningún alumno», «para devolver hace falta escribir el motivo». Medido el
  /// 24 sep 2026 contra las diez rutas de las estaciones.
  ///
  /// **No va para todas las rutas, a propósito**: la cabecera también cambia la
  /// validación —sin ella un 422 de Laravel es una redirección 302— y las
  /// pantallas viejas no se han mirado con el 422 delante. Se ensancha ruta a
  /// ruta, con la pantalla probada.
  ///
  /// Se decide aquí, por el prefijo, y no con un parámetro nuevo en [get]/[put]/
  /// [post]: esos tres los sobrescriben los servidores de mentira de las
  /// pruebas, y un parámetro nuevo los rompería todos.
  static const List<String> rutasQueContestanJson = [
    '/estaciones',
    // La portería (9 oct 2026): sus 404, 409, 410 y 422 traen la frase que se
    // enseña —«Ese carné ya es de…»— y el 404 de un carné sin dueño trae
    // `{desconocido: true}`, que es lo que abre «¿De quién es?».
    '/porteria/',
    '/requisitos/recorrido/',
    '/requisitos/mi-recorrido/',
    // «Mi perfil», que entraron con su pantalla el 24 sep 2026 y nunca
    // tuvieron un cliente viejo que dependiera del HTML. La contraseña corta con `abort(400, 'Contraseña antigua es incorrecta')` y la firma
    // con un 403 que dice quién puede pedirla: sin la cabecera, las dos
    // frases llegaban como HTML.
    '/perfiles/cambiarpassword/',
    '/firmas-del-titular/',
    '/myimages/store',
    '/images-users/cambiar-imagen-perfil/',
    // Las actividades nuevas (`routes/api/act.php`), que nacieron con esta
    // cabecera en la web: sus 422 traen `{mensaje, faltan}` o
    // `{mensaje, hijos}`, y la pantalla de responder salta a la pregunta que
    // falta con eso. Sin la cabecera, un `abort(409, …)` volvería como HTML.
    '/act/',
    // PQRS del acudiente (9 oct 2026): sus 404, 409 y 422 traen la frase que
    // se enseña («Ya contestaste la encuesta»). Sin barra al final: también
    // es `GET /mis-pqrs` a secas.
    '/mis-pqrs',
    // El estado de cuenta de la familia (`routes/api/cartera.php`). En un
    // colegio sin el módulo `ExigirModulo` responde 404, y el 403 de quien no
    // es acudiente trae su frase: las dos se leen mejor en JSON.
    '/mi-cuenta',
    // La prematrícula de la familia (16 oct 2026): su 409 es «primero
    // tesorería tiene que registrar el pago», y en HTML se perdía.
    '/matriculas/prematricular',
    // Matricular desde la última estación: su «No tiene permisos para editar»
    // es un abort(400) que en HTML se perdía.
    '/matriculas/matricularuno',
  ];

  static bool pideJson(String direccion) =>
      rutasQueContestanJson.any(direccion.startsWith);

  Map<String, String> _conAccept(String direccion, Map<String, String> h) =>
      pideJson(direccion) ? {...h, 'Accept': 'application/json'} : h;

  /// Las cabeceras de [ClienteApp] delante de las de cada petición. Todas las
  /// peticiones de aquí pasan por esto, el login incluido.
  Map<String, String> _deLaApp(Map<String, String> h) =>
      {...ClienteApp.cabeceras, ...h};

  Map<String, String> _encabezado () => {
    'Authorization': 'Bearer ${AuthService.user.token}',
  };

  /// A qué servidor habla la app.
  ///
  /// Estaba metido dentro de credentials(), o sea que solo se sabía apuntar a
  /// un colegio mientras alguien escribía su usuario y su clave. Al recargar la
  /// página en la web eso se pierde —los estáticos viven en memoria— y las
  /// peticiones salían contra `/api` del propio dominio de la app, que
  /// contestaba 404. Ahora es un paso aparte y lo usan los dos: el login y el
  /// arranque que recupera la sesión guardada.
  ///
  /// `otro` quiere decir que es un servidor local, escrito a mano. Los colegios
  /// en internet tienen la plataforma colgando de /8myvc/public.
  static void apuntarA(String servidor, {bool otro = false}) {
    Server.urlServer = servidor;

    if (otro) {
      Server.urlApi = '$servidor/api';
      Server.urlImages = '$servidor/images/perfil';
    } else {
      Server.urlApi = '$servidor/8myvc/public/api';
      Server.urlImages = '$servidor/8myvc/public/images/perfil';
    }
  }

  Future credentials(String username, String password, servidor,
      {bool otro = false}) {

    Server.apuntarA(servidor, otro: otro);


    var url = _uri('/login/credentials');
    var response =
        http.post(url,
        headers: _deLaApp({}),
        body: {'username': username, 'password': password});
    return response;
  }

  Future login() {
    final token = AuthService.user.token;
    var url = _uri('/login');
    var response = http.post(url, headers: _deLaApp({
      'Authorization': 'Bearer $token',
    }));
    return _vigilando('/login', token, response);
  }

  Future get(String direccion) {
    final token = AuthService.user.token;
    var url = _uri(direccion);
    var response = http.get(url, headers: _deLaApp(_conAccept(direccion, {
      'Authorization': 'Bearer $token',
    })));
    return _vigilando(direccion, token, response);
  }

  Future put(String direccion, params) {
    final token = AuthService.user.token;
    var url = _uri(direccion);
    var response = http.put(url,
        headers: _deLaApp(_conAccept(direccion, {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        })),
        body: jsonEncode(params));
    return _vigilando(direccion, token, response);
  }

  Future post(String direccion, params) {
    final token = AuthService.user.token;
    var url = _uri(direccion);
    var response = http.post(url,
        headers: _deLaApp(_conAccept(direccion, {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        })),
        body: jsonEncode(params));
    return _vigilando(direccion, token, response);
  }

  /// Sube un archivo como `multipart/form-data`, en el campo `file`.
  ///
  /// Es el nombre que leen todas las subidas del servidor
  /// —`SafeUpload::archivoRecibido('file')`—. Recibe bytes y no una ruta
  /// porque en la web no hay ruta: el selector de imágenes solo da el
  /// contenido.
  ///
  /// Devuelve un `http.Response` como los demás, ya leído entero, para que
  /// quien llama lo trate igual que un `post`.
  Future<http.Response> subir(
      String direccion, List<int> bytes, String nombreArchivo) async {
    final token = AuthService.user.token;
    final peticion = http.MultipartRequest('POST', _uri(direccion))
      ..headers.addAll(_deLaApp(_conAccept(direccion, _encabezado())))
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: nombreArchivo));

    return _vigilando(direccion, token,
        http.Response.fromStream(await peticion.send()));
  }

  /// Como [subir], con campos de texto al lado del archivo.
  ///
  /// Aparte y no un parámetro nuevo de [subir] por lo mismo que
  /// [rutasQueContestanJson]: los servidores de mentira de las pruebas
  /// sobrescriben estos métodos, y cambiarle la firma a uno los rompe todos.
  /// Lo usa `act/{id}/archivo`, que necesita `clase` y, a veces, `alumno_id`
  /// y `pregunta_id`.
  Future<http.Response> subirConCampos(String direccion, List<int> bytes,
      String nombreArchivo, Map<String, String> campos) async {
    final token = AuthService.user.token;
    final peticion = http.MultipartRequest('POST', _uri(direccion))
      ..headers.addAll(_deLaApp(_conAccept(direccion, _encabezado())))
      ..fields.addAll(campos)
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: nombreArchivo));

    return _vigilando(direccion, token,
        http.Response.fromStream(await peticion.send()));
  }

  Future delete(String direccion) {
    final token = AuthService.user.token;
    var url = _uri(direccion);
    var response = http.delete(url,
        headers: _deLaApp(_encabezado()),);
    return _vigilando(direccion, token, response);
  }
}

/// Una petición que no llegó al colegio: sin señal, sin datos, o el servidor
/// no contesta.
///
/// Antes llegaba a la pantalla tal cual —«ClientException: Failed to fetch»,
/// «SocketException: Failed host lookup…»— por las pantallas que pintan
/// `'$err'`. Su texto es la frase que se enseña, sin «Exception: » delante.
///
/// Sigue siendo un [http.ClientException], así que quien ya lo reconocía por
/// el tipo —`pareceFaltaDeSenal` en la hoja— lo sigue reconociendo.
class SinConexion extends http.ClientException {
  SinConexion(Object causa)
      : super('No se pudo conectar con el colegio. Revisa tu conexión a '
            'internet y vuelve a intentarlo. ($causa)');

  static const String frase = 'No se pudo conectar con el colegio. Revisa tu '
      'conexión a internet y vuelve a intentarlo.';

  static bool loParece(Object err) {
    final dicho = '$err';
    return dicho.contains('SocketException') ||
        dicho.contains('HandshakeException') ||
        dicho.contains('Failed host lookup') ||
        dicho.contains('Connection refused') ||
        dicho.contains('Connection closed');
  }

  @override
  String toString() => frase;
}
