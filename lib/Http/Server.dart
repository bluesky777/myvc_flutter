import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';

class Server {
  static String url = 'https://lalvirtual.edu.co/8myvc/public/api';

  Server();

  Uri _uri (direction) => Uri.parse('${Server.url}$direction');

  Future credentials (String username, String password) {

    var url = _uri('/login/credentials');
    var response = http
        .post(url, body: {'username': username, 'password': password});
    return response;
  }

  Future login () {
    var url = _uri('/login');
    var response = http
        .post(url, headers: {
      HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
    });
    return response;
  }

  Future get (String direccion) {
    var url = _uri(direccion);
    var response = http
        .get(url, headers: {
      HttpHeaders.authorizationHeader: 'Bearer ${AuthService.user.token}',
    });
    return response;
  }
}