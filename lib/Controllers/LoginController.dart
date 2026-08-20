import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
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
    if (isLocal) {
      bool hasHttp = servidorElegido.contains('http');
      servidorElegido = hasHttp ? servidorElegido : 'http://$servidorElegido';
    }

    var server = Server();
    http.Response response;

    try {
      response = await server.credentials(
        username,
        password,
        servidorElegido,
        otro: isLocal,
      );
    } catch (err) {
      // Ni siquiera hubo respuesta: la dirección no existe, no responde, o el
      // navegador la bloqueó. Se nombra la URL, que casi siempre es el fallo.
      throw LoginException(
        'No se pudo conectar con ${Server.urlApi}\n'
        'Revisa la dirección del servidor.',
      );
    }

    final parsed = _cuerpoJson(response);

    if (response.statusCode != 200) {
      throw LoginException(_mensajeDeError(response, parsed));
    }

    final token = parsed == null ? null : parsed['el_token'];
    if (token == null) {
      throw LoginException(
        'El servidor respondió correctamente pero sin token.\n${Server.urlApi}',
      );
    }

    AuthService.setToken('$token');
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

      AuthService.user.id = entero(datos['user_id']);
      AuthService.user.personaId = entero(datos['persona_id']);
      AuthService.user.tipo = texto(datos['tipo']);
      AuthService.user.username = '${datos['username'] ?? username}';
      AuthService.user.nombres = nombre.isEmpty ? null : nombre;
      AuthService.user.sexo = '${datos['sexo'] ?? 'M'}';
      AuthService.user.isSuperuser = entero(datos['is_superuser']) == 1;
      AuthService.user.roles = _rolesDe(datos['roles']);

      // El año y el periodo con los que entra. De aquí cuelga todo lo demás.
      ContextoAcademico.instancia.tomarDelLogin(datos);
    } catch (err) {
      // El contexto es un extra: si no llega, la sesión sigue siendo válida.
      AuthService.user.username = username;
      debugPrint('No se pudo leer el contexto del usuario: $err');
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

    return 'Token recibido';
  }

  /// El cuerpo como mapa, o null si no vino JSON —una página de error de nginx,
  /// por ejemplo—. Antes eso reventaba en jsonDecode antes de poder explicarlo.
  Map<String, dynamic>? _cuerpoJson(dynamic response) {
    try {
      final decodificado = jsonDecode(response.body);
      return decodificado is Map<String, dynamic> ? decodificado : null;
    } catch (_) {
      return null;
    }
  }

  String _mensajeDeError(dynamic response, Map<String, dynamic>? parsed) {
    final codigo = response.statusCode;
    final error = parsed == null ? null : parsed['error'];

    if (error == 'invalid_credentials') {
      return 'Usuario o contraseña incorrectos.';
    }
    if (error == 'too_many_attempts') {
      final segundos = parsed!['segundos'];
      return segundos == null
          ? 'Demasiados intentos fallidos. Espera un momento.'
          : 'Demasiados intentos fallidos. Espera $segundos segundos.';
    }
    if (error != null) {
      return 'El servidor rechazó el ingreso: $error (HTTP $codigo).';
    }
    if (parsed == null) {
      return 'Respuesta inesperada del servidor (HTTP $codigo).\n'
          '¿Es esta la dirección correcta?\n${Server.urlApi}';
    }
    return 'El servidor respondió HTTP $codigo.';
  }

  @override
  Future<String> logout() async {
    AuthService.limpiar();
    // El año y el periodo son de quien entró: no pueden quedarse puestos para
    // el docente siguiente, que es lo mismo que ya se cuida con el token.
    ContextoAcademico.instancia.limpiar();

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

class LoginException implements Exception {
  final String mensaje;

  LoginException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Los nombres de los roles que manda /login, en minúsculas.
///
/// Vienen como filas de la tabla `roles`, cada una con su `name`. Se normalizan
/// aquí para no tener que recordar en cada comparación si el colegio escribió
/// 'Admin' o 'admin'.
Set<String> _rolesDe(dynamic crudos) {
  if (crudos is! List) return {};

  final nombres = <String>{};
  for (final rol in crudos) {
    final nombre = rol is Map ? rol['name'] : rol;
    if (nombre == null) continue;

    final limpio = nombre.toString().trim().toLowerCase();
    if (limpio.isNotEmpty) nombres.add(limpio);
  }
  return nombres;
}
