import 'dart:convert';

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LoginBaseController {
  Future<String> login(
    String username,
    String password,
    bool isLocal,
    String textoUri,
    String servidorElegido,
  );
  Future<String> logout();
}

class LoginController implements LoginBaseController {
  @override
  Future<String> login(
    String username,
    String password,
    bool isLocal,
    String textoUri,
    String servidorElegido,
  ) async {
    print('Suerte: $username $password');
    // if (username != "username" || password != "password") {
    //   throw LoginException();
    // }

    if (isLocal) {
      bool hasHttp = textoUri.contains('http');
      textoUri = hasHttp ? textoUri : 'http://' + textoUri;
    }

    var server = Server();
    var response;
    String servidorUri = isLocal ? textoUri : servidorElegido;

    try {
      response = await server.credentials(
        username,
        password,
        servidorUri,
        otro: isLocal,
      );
    } on Exception {
      // print('***** Error: ${Server.urlApi}');
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      //   content: Text('Error ${Server.urlApi}'),
      // ));
      throw LoginUrlException();
    }

    Map<String, dynamic> parsed = jsonDecode(response.body);

    if (response.statusCode == 200) {
      AuthService.setToken(parsed['el_token']);
      var res = await server.login();
      print('res login $res');

      SharedPreferences.getInstance().then((SharedPreferences preferences) {
        preferences.setString('username', username);
        preferences.setString('password', password);
        preferences.setString('customUri', servidorUri);
      });

      //Navigator.pushNamed(context, '/panel');

    } else {
      throw LoginException();
    }

    return "un token recibido";
  }

  @override
  Future<String> logout() async {
    return "";
  }
}

class LoginException implements Exception {}

class LoginUrlException implements Exception {}
