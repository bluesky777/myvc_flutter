import 'dart:async';
import 'dart:convert';

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/PreferenciasSesion.dart';
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

      // La respuesta de /login trae el contexto del usuario y antes se
      // descartaba, así que la app nunca supo con qué cuenta estaba abierta.
      // Sin ese dato el menú no podía mostrarlo, y usar la sesión de otro
      // docente no se notaba por ningún lado.
      try {
        final Map<String, dynamic> datos = jsonDecode(res.body);

        final nombre = [datos['nombres'], datos['apellidos']]
            .where((parte) => parte != null && '$parte'.trim().isNotEmpty)
            .join(' ');

        AuthService.user.username = '${datos['username'] ?? username}';
        AuthService.user.nombres = nombre.isEmpty ? null : nombre;
        AuthService.user.sexo = '${datos['sexo'] ?? 'M'}';
      } catch (err) {
        // El contexto es un extra: si no llega, la sesión sigue siendo válida.
        AuthService.user.username = username;
        print('No se pudo leer el contexto del usuario: $err');
      }

      final preferences = await SharedPreferences.getInstance();

      if (await PreferenciasSesion.guardarDatos()) {
        await preferences.setString(PreferenciasSesion.claveUsername, username);
        await preferences.setString(PreferenciasSesion.clavePassword, password);
      } else {
        // El equipo es compartido: no queda rastro para el docente siguiente.
        await preferences.remove(PreferenciasSesion.claveUsername);
        await preferences.remove(PreferenciasSesion.clavePassword);
      }
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
    AuthService.limpiar();

    // Manda la casilla: si este dispositivo es de uno, cerrar sesión no tiene
    // por qué hacerle reescribir las credenciales. En el equipo compartido se
    // desmarca, y entonces no queda nada para el docente siguiente.
    if (!await PreferenciasSesion.guardarDatos()) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(PreferenciasSesion.claveUsername);
      await preferences.remove(PreferenciasSesion.clavePassword);
    }

    return "";
  }
}

class LoginException implements Exception {}

class LoginUrlException implements Exception {}
