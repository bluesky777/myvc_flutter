import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Utils/PreferenciasSesion.dart';
import 'package:myvc_flutter/Utils/SesionGuardada.dart';
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
      tomarUsuarioDe(jsonDecode(res.body), usernameDeRespaldo: username);
    } catch (err) {
      // El contexto es un extra: si no llega, la sesión sigue siendo válida.
      AuthService.user.username = username;
      debugPrint('No se pudo leer el contexto del usuario: $err');
    }

    await SesionGuardada.guardar(
      token: '$token',
      servidor: servidorElegido,
      // El cuerpo tal cual: al arrancar se relee con el mismo código que lo
      // acaba de leer aquí, así que no hay dos formas de entenderlo.
      usuario: res.body,
      local: isLocal,
    );

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

  /// Vuelve a abrir la sesión guardada, si la hay y si sigue valiendo.
  ///
  /// Se llama al arrancar, antes de pintar nada. Apunta al servidor del
  /// colegio, pone el token y le pregunta al servidor quién es —`POST /login`,
  /// la misma llamada que hace la app nada más entrar—, que de paso devuelve el
  /// año y el periodo del usuario.
  ///
  /// Devuelve false si no había sesión o si el servidor ya no la acepta —token
  /// caducado, clave cambiada, cuenta desactivada—, y entonces deja todo
  /// limpio para que la app arranque en el login. Un fallo de red no cuenta
  /// como sesión inválida, pero tampoco se puede seguir sin saber quién es el
  /// usuario, así que también manda al login: es lo único honesto cuando no se
  /// puede comprobar.
  Future<bool> restaurar() async {
    final guardada = await SesionGuardada.leer();
    if (guardada == null) return false;

    Server.apuntarA(guardada.servidor, otro: guardada.local);
    AuthService.setToken(guardada.token);

    try {
      tomarUsuarioDe(jsonDecode(guardada.usuario));
    } catch (err) {
      // Lo guardado no se entiende: es de una versión anterior de la app o
      // quedó a medias. Se tira y se entra a mano, que es un mal menor.
      debugPrint('La sesión guardada no se pudo leer: $err');
      await _tirarLaSesion();
      return false;
    }

    return _tokenSigueValiendo();
  }

  /// Si el servidor todavía acepta el token guardado.
  ///
  /// Se pregunta con `GET /years` y no con `POST /login`, aunque este último
  /// sería lo natural: el login está limitado a cinco por minuto y por IP, y en
  /// un colegio todos salen por la misma. Con cada recarga gastando una, el
  /// sexto en recargar se quedaría fuera sin haber tecleado nada. /years exige
  /// token igual, no está limitada, y devuelve poco.
  ///
  /// Un 401 o un 403 son un no: el token caducó, o le cambiaron la clave, o
  /// desactivaron la cuenta. Cualquier otro fallo —sin red, servidor caído, un
  /// 500— no dice nada sobre el token, así que la sesión se queda y se sigue
  /// con lo guardado; ya fallará lo que tenga que fallar, con su mensaje.
  Future<bool> _tokenSigueValiendo() async {
    try {
      final res = await Server().get('/years');

      if (res.statusCode == 401 || res.statusCode == 403) {
        await _tirarLaSesion();
        return false;
      }

      return true;
    } catch (err) {
      debugPrint('No se pudo comprobar la sesión guardada: $err');
      return true;
    }
  }

  Future<void> _tirarLaSesion() async {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
    HorarioDeHoy.instancia.limpiar();
    await SesionGuardada.borrar();
  }

  /// Llena el usuario y el contexto con lo que devuelve `POST /login`.
  ///
  /// Lo comparten entrar y recuperar la sesión: son el mismo dato leído en dos
  /// momentos, y tenerlo escrito dos veces era la forma de que un día se
  /// leyeran distinto.
  static void tomarUsuarioDe(dynamic cuerpo, {String? usernameDeRespaldo}) {
    final datos = Map<String, dynamic>.from(cuerpo as Map);

    final nombre = [datos['nombres'], datos['apellidos']]
        .where((parte) => parte != null && '$parte'.trim().isNotEmpty)
        .join(' ');

    AuthService.user.id = entero(datos['user_id']);
    AuthService.user.personaId = entero(datos['persona_id']);
    AuthService.user.tipo = texto(datos['tipo']);
    AuthService.user.username = '${datos['username'] ?? usernameDeRespaldo ?? ''}';
    AuthService.user.nombres = nombre.isEmpty ? null : nombre;
    AuthService.user.sexo = '${datos['sexo'] ?? 'M'}';
    AuthService.user.isSuperuser = entero(datos['is_superuser']) == 1;
    AuthService.user.roles = _rolesDe(datos['roles']);

    // El año y el periodo con los que entra. De aquí cuelga todo lo demás.
    ContextoAcademico.instancia.tomarDelLogin(datos);
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
    // Y el token del disco, o el próximo arranque entraría solo con la sesión
    // de quien acaba de salir.
    await SesionGuardada.borrar();
    // El año y el periodo son de quien entró: no pueden quedarse puestos para
    // el docente siguiente, que es lo mismo que ya se cuida con el token. Y con
    // ellos las clases de hoy, que si no le dirían al siguiente cuántas clases
    // tenía el anterior.
    ContextoAcademico.instancia.limpiar();
    HorarioDeHoy.instancia.limpiar();

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
