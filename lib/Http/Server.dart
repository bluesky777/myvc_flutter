import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';

class Server {
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

  Map<String, String> _encabezado () => {
    'Authorization': 'Bearer ${AuthService.user.token}',
  };

  Future credentials(String username, String password, servidor,
      {bool otro = false}) {

    Server.urlServer = servidor;
    if (otro){ // quiere decir que es local
      Server.urlApi = '$servidor/api';
      Server.urlImages = '$servidor/images/perfil';
    }else{ // En internet tengo los servidores en estas carpetas
      Server.urlApi = '$servidor/8myvc/public/api';
      Server.urlImages = '$servidor/8myvc/public/images/perfil';
    }


    var url = _uri('/login/credentials');
    var response =
        http.post(url, body: {'username': username, 'password': password});
    return response;
  }

  Future login() {
    var url = _uri('/login');
    var response = http.post(url, headers: {
      'Authorization': 'Bearer ${AuthService.user.token}',
    });
    return response;
  }

  Future get(String direccion) {
    var url = _uri(direccion);
    var response = http.get(url, headers: {
      'Authorization': 'Bearer ${AuthService.user.token}',
    });
    return response;
  }

  Future put(String direccion, params) {
    var url = _uri(direccion);
    var response = http.put(url,
        headers: {
          'Authorization': 'Bearer ${AuthService.user.token}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(params));
    return response;
  }

  Future post(String direccion, params) {
    var url = _uri(direccion);
    var response = http.post(url,
        headers: {
          'Authorization': 'Bearer ${AuthService.user.token}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(params));
    return response;
  }

  Future delete(String direccion) {
    var url = _uri(direccion);
    var response = http.delete(url,
        headers: _encabezado(),);
    return response;
  }
}
