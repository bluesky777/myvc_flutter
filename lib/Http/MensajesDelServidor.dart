import 'dart:convert';

/// Lo que el servidor dijo cuando rechazó algo, si se le puede enseñar a una
/// persona.
///
/// Laravel corta con `abort(422, $motivo)` y eso llega como
/// `{"message": "..."}`. Ese texto es el único que sabe **por qué** se rechazó
/// —«la nota 105 no cabe en la escala del año», y no «HTTP 422»—, así que
/// tirarlo y enseñar el número es perder la mitad de la respuesta.
///
/// Escrita originalmente por la sesión de la pantalla de cuentas dentro de
/// `UsuariosApi`; vive aquí porque en cuanto la escala de notas pasó a
/// validarse en el servidor hizo falta en tres sitios más, y dos copias de
/// esto acaban divergiendo justo en los recortes de abajo, que son los que
/// importan.
///
/// Devuelve null —y entonces quien llama pone su propio texto— cuando:
///
/// - el cuerpo no es JSON: sin `Accept: application/json` el servidor puede
///   contestar su página de error en HTML;
/// - no trae `message`;
/// - o lo que trae no cabe en un aviso. Ese último corte no es cosmético: un
///   volcado de excepción con su traza dentro es JSON perfectamente válido, y
///   enseñárselo a un docente en un `SnackBar` no le dice nada y sí enseña de
///   más.
String? loQueDijoElServidor(dynamic cuerpo) {
  if (cuerpo is! String || cuerpo.trim().isEmpty) return null;

  try {
    final leido = jsonDecode(cuerpo);
    if (leido is! Map) return null;

    final mensaje = '${leido['message'] ?? ''}'.trim();

    if (mensaje.isEmpty || mensaje.length > 160) return null;
    if (mensaje.contains('\n')) return null;

    return mensaje;
  } catch (_) {
    return null;
  }
}

/// Qué decirle a quien guardaba una nota y el servidor no la aceptó.
///
/// **El 422 es la escala.** Desde que se valida en el servidor,
/// `PUT notas/update` y la definitiva manual contestan 422 —donde antes daban
/// 200— con el motivo dentro; en `notas/lote` el mismo texto vuelve dentro de
/// `fallidas[].motivo`. Los tres caminos dicen lo mismo y por eso lo traduce un
/// solo sitio.
///
/// El [respaldo] es para cuando el servidor corta sin explicarse: es raro, pero
/// dejar al docente con un número suelto delante es exactamente lo que esta
/// función existe para evitar.
String motivoDeRechazo(dynamic cuerpo, {required String respaldo}) {
  return loQueDijoElServidor(cuerpo) ?? respaldo;
}

/// Qué decirle a la persona cuando el servidor contesta con un fallo.
///
/// Lo que escribió el servidor, si vino en JSON y se puede enseñar. Si no, una
/// frase por código en vez de «El servidor respondió 403.», que no dice si es
/// cosa de permisos, del colegio o de la red. El número va siempre entre
/// paréntesis: es lo que se lee en la captura que manda el colegio.
///
/// El 401 casi nunca llega a verse: Server lo manda a SesionCaducada, que
/// devuelve al login. Está por si se pinta antes de que la pantalla se vaya.
String fraseDeFallo(int codigo, [dynamic cuerpo]) {
  final dijo = loQueDijoElServidor(cuerpo);
  if (dijo != null) return dijo;

  final que = queSignificaElCodigo(codigo);
  return '${que[0].toUpperCase()}${que.substring(1)}.';
}

/// Lo mismo que [fraseDeFallo], diciendo además qué era lo que no se pudo:
/// «No se pudo registrar la ausencia: no tienes permiso para esto (403).».
///
/// Si el servidor se explicó, va su frase tal cual, que ya dice qué pasó.
String noSePudo(String accion, int codigo, [dynamic cuerpo]) {
  final dijo = loQueDijoElServidor(cuerpo);
  if (dijo != null) return 'No se pudo $accion: $dijo';

  return 'No se pudo $accion: ${queSignificaElCodigo(codigo)}.';
}

/// Qué quiere decir un código cuando el servidor no lo explica, en minúscula y
/// sin punto, para que quepa detrás de «No se pudo …:».
///
/// Los de aquí son los que contesta 8myvc: `abort(403)` de `Autoriza`, el 404
/// de una ruta que el colegio no tiene desplegada, el 409 y el 423 de las
/// votaciones, el 410 de un carné vencido, el 419 de la sesión de Laravel y el
/// 503 del modo mantenimiento durante un despliegue.
String queSignificaElCodigo(int codigo) {
  switch (codigo) {
    case 400:
      return 'el servidor no aceptó los datos que se enviaron (400)';
    case 401:
      return 'tu sesión venció; vuelve a entrar (401)';
    case 403:
      return 'no tienes permiso para esto (403)';
    case 404:
      return 'el colegio no tiene esto disponible, o ya no existe (404)';
    case 405:
      return 'el colegio todavía no tiene esta función (405)';
    case 408:
      return 'el servidor tardó demasiado en contestar; inténtalo de nuevo '
          '(408)';
    case 409:
      return 'choca con algo que ya estaba registrado (409)';
    case 410:
      return 'eso ya no existe o ya venció (410)';
    case 413:
      return 'lo que se envió es demasiado grande (413)';
    case 419:
      return 'la sesión de la página caducó; vuelve a intentarlo (419)';
    case 422:
      return 'el servidor no aceptó los datos; revisa lo que escribiste (422)';
    case 423:
      return 'está cerrado por ahora (423)';
    case 429:
      return 'demasiadas peticiones seguidas; espera un minuto y vuelve a '
          'intentarlo (429)';
    case 502:
    case 504:
      return 'el servidor del colegio no contestó a tiempo; inténtalo en un '
          'rato ($codigo)';
    case 503:
      return 'el servidor del colegio está en mantenimiento; inténtalo en '
          'unos minutos (503)';
  }
  if (codigo >= 500) {
    return 'el servidor del colegio tuvo un problema; inténtalo en un rato '
        '($codigo)';
  }
  if (codigo >= 400) return 'el colegio no aceptó la petición ($codigo)';
  return 'el servidor contestó algo que la app no esperaba ($codigo)';
}

/// Un fallo del servidor, para lanzarlo desde la capa de datos.
///
/// Su texto es [fraseDeFallo] **sin el «Exception: » delante**, que es lo que
/// se veía en las pantallas que pintan `'$err'` tal cual.
class FalloDelServidor implements Exception {
  final int codigo;
  final String mensaje;

  FalloDelServidor(this.codigo, [dynamic cuerpo])
      : mensaje = fraseDeFallo(codigo, cuerpo);

  /// Desde una respuesta de `http`, o de los servidores de mentira.
  factory FalloDelServidor.de(dynamic res) =>
      FalloDelServidor(res.statusCode as int, res.body);

  @override
  String toString() => mensaje;
}
