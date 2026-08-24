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
