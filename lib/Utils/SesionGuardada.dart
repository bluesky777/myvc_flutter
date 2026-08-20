import 'package:myvc_flutter/Utils/PreferenciasSesion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La sesión que sobrevive a cerrar la app y, en la web, a recargar la página.
///
/// Hace falta porque el token y la dirección del colegio viven en estáticos —
/// `AuthService.user.token` y `Server.urlServer`— y un F5 rearranca la app
/// entera. Lo que se veía era esto: al recargar en cualquier pantalla que no
/// fuera el login, las peticiones salían contra `/api` del dominio de la app y
/// con `Authorization: Bearer null`, y el servidor contestaba 404 a todo.
///
/// **Qué se guarda.** El token, a qué servidor apunta, y la respuesta de
/// `POST /login` tal cual vino: quién es el usuario, sus roles y con qué año y
/// periodo trabaja.
///
/// Se guarda esa respuesta en vez de volver a pedirla al arrancar porque
/// `POST /login` está limitado a **cinco llamadas por minuto y por IP**. En un
/// colegio todos salen por la misma IP: si cada recarga de página gastara una,
/// el sexto que recargara se quedaría sin entrar, y el mensaje que vería sería
/// «demasiados intentos» sin haber tecleado nada. Que el token siga valiendo se
/// comprueba con una petición normal —`GET /years`, que exige token y no está
/// limitada—.
///
/// **Manda la casilla de recordar.** En un equipo compartido —el de la entrada
/// del colegio— el docente la desmarca, y entonces tampoco se guarda el token:
/// sería la misma fuga que se cuidó con el usuario y la contraseña, pero peor,
/// porque el siguiente entraría sin teclear nada. Ver [PreferenciasSesion].
class SesionGuardada {
  static const String claveToken = 'sesionToken';
  static const String claveServidor = 'sesionServidor';
  static const String claveServidorLocal = 'sesionServidorLocal';
  static const String claveUsuario = 'sesionUsuario';

  final String token;
  final String servidor;

  /// La respuesta de `POST /login`, tal como llegó el día que se entró.
  final String usuario;

  /// Si el servidor se escribió a mano —el 'Otro' del login—, que se traduce
  /// en otras rutas para la API y las imágenes.
  final bool local;

  SesionGuardada({
    required this.token,
    required this.servidor,
    required this.usuario,
    required this.local,
  });

  /// Guarda la sesión, salvo que este equipo no deba recordar nada.
  static Future<void> guardar({
    required String token,
    required String servidor,
    required String usuario,
    required bool local,
  }) async {
    if (!await PreferenciasSesion.guardarDatos()) {
      await borrar();
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(claveToken, token);
    await preferences.setString(claveServidor, servidor);
    await preferences.setString(claveUsuario, usuario);
    await preferences.setBool(claveServidorLocal, local);
  }

  /// La sesión guardada, o null si no hay ninguna que valga.
  static Future<SesionGuardada?> leer() async {
    final preferences = await SharedPreferences.getInstance();

    final token = preferences.getString(claveToken);
    final servidor = preferences.getString(claveServidor);
    final usuario = preferences.getString(claveUsuario);

    // Las tres o ninguna. Sin token no hay sesión; sin servidor no hay a quién
    // preguntar; sin el usuario, la app arrancaría sin saber quién entró ni con
    // qué periodo, que es medio funcionar y se ve peor que no funcionar.
    if (token == null || token.isEmpty) return null;
    if (servidor == null || servidor.isEmpty) return null;
    if (usuario == null || usuario.isEmpty) return null;

    return SesionGuardada(
      token: token,
      servidor: servidor,
      usuario: usuario,
      local: preferences.getBool(claveServidorLocal) ?? false,
    );
  }

  /// Pone al día quién es el usuario, sin tocar el token.
  ///
  /// Hace falta porque el año y el periodo se cambian estando dentro —la barra
  /// de arriba—, y el backend los guarda en la fila del usuario. Sin esto, lo
  /// guardado seguiría diciendo el periodo viejo y al recargar la app volvería
  /// a ese, discrepando de lo que el servidor tiene apuntado.
  ///
  /// No crea una sesión donde no la había: si el equipo no recuerda nada, esto
  /// tampoco puede ser la puerta de atrás por la que se guarde.
  static Future<void> actualizarUsuario(String usuario) async {
    final preferences = await SharedPreferences.getInstance();

    if (preferences.getString(claveToken) == null) return;

    await preferences.setString(claveUsuario, usuario);
  }

  static Future<void> borrar() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(claveToken);
    await preferences.remove(claveServidor);
    await preferences.remove(claveUsuario);
    await preferences.remove(claveServidorLocal);
  }
}
