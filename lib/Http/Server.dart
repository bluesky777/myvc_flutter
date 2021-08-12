import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';

class Server {
  //static String urlServer = 'https://lalvirtual.edu.co/8myvc/public';
  // static String urlServer = 'http://192.168.100.107';
  static String urlServer = 'http://192.168.18.215';

  static String urlApi = '$urlServer/api';
  static String urlImages = '$urlServer/images/perfil';

  Server();

  Uri _uri(direction) => Uri.parse('${Server.urlApi}$direction');

  Map<String, String> _encabezado () => {
    HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
  };

  Future credentials(String username, String password, servidor,
      {bool otro = false}) {

    print('$servidor - otro: $otro');
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
      HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
    });
    return response;
  }

  Future get(String direccion) {
    var url = _uri(direccion);
    var response = http.get(url, headers: {
      HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
    });
    return response;
  }

  Future put(String direccion, params) {
    var url = _uri(direccion);
    var response = http.put(url,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(params));
    return response;
  }

  Future post(String direccion, params) {
    var url = _uri(direccion);
    var response = http.post(url,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
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
