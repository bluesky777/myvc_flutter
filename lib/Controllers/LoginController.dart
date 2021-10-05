import 'dart:async';
import 'dart:convert';

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LoginBaseController {
  Future<String> login(
    String username,
    String password,
    bool isLocal,
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
    String servidorElegido,
  ) async {
    var completer = Completer<String>();

    print('Suerte: $username $password');
    // if (username != "username" || password != "password") {
    //   throw LoginException();
    // }

    if (isLocal) {
      bool hasHttp = servidorElegido.contains('http');
      servidorElegido = hasHttp ? servidorElegido : 'http://' + servidorElegido;
    }

    var server = Server();
    var response;

    try {
      response = await server.credentials(
        username,
        password,
        servidorElegido,
        otro: isLocal,
      );
    } on Exception {
      print('***** Error: ${Server.urlApi}');
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      //   content: Text('Error ${Server.urlApi}'),
      // ));
      completer.completeError("Error al loguear.");
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
        preferences.setString('customUri', servidorElegido);
      });
      completer.complete('Token recibido');
      //Navigator.pushNamed(context, '/panel');

    } else {
      completer.completeError("Error al loguear 2.");
      throw LoginException();
    }

    return completer.future;
  }

  @override
  Future<String> logout() async {
    return "";
  }
}

class LoginException implements Exception {}

class LoginUrlException implements Exception {}
