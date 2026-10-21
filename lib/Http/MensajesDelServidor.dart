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

  if (codigo == 401) return 'Tu sesión venció. Vuelve a entrar (401).';
  if (codigo == 403) return 'No tienes permiso para esto (403).';
  if (codigo == 404) return 'El colegio no tiene esto disponible (404).';
  if (codigo == 429) {
    return 'Demasiadas peticiones seguidas. Espera un minuto y vuelve a '
        'intentarlo (429).';
  }
  if (codigo >= 500) {
    return 'El servidor del colegio tuvo un problema. Inténtalo en un rato '
        '($codigo).';
  }
  return 'El servidor respondió $codigo.';
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
