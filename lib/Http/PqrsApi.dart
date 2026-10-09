import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PqrsModel.dart';
import 'package:myvc_flutter/Utils/ElegirParaActividad.dart';

/// Las PQRS del acudiente: `routes/api/pqrs.php` del backend,
/// `MisPqrsController` (Joseth, 9 oct 2026). Ver `docs/pqrs.md`.
///
/// Todas contestan JSON —`/mis-pqrs` está en [Server.rutasQueContestanJson]—,
/// así que el error trae la frase del servidor en `message` y se enseña tal
/// cual: «Ese alumno no es acudido de quien radica» dice más que un 422.

/// Las suyas, sus acudidos y el catálogo de tipos. `GET mis-pqrs`.
Future<ListaDePqrs> traerMisPqrs(Server server) async {
  final http.Response res = await server.get('/mis-pqrs');
  if (res.statusCode != 200) throw Exception(_frase(res, 'traer tus PQRS'));
  return ListaDePqrs.fromJson(Map<String, dynamic>.from(jsonDecode(res.body) as Map));
}

/// Una, con el hilo, la respuesta y los adjuntos. `GET mis-pqrs/{id}`.
Future<DetallePqrs> traerPqrs(Server server, int id) async {
  final http.Response res = await server.get('/mis-pqrs/$id');
  if (res.statusCode != 200) throw Exception(_frase(res, 'abrir la PQRS'));
  return DetallePqrs.fromJson(Map<String, dynamic>.from(jsonDecode(res.body) as Map));
}

/// Radica. Con [adjunto] va como `multipart/form-data` (el fichero en `file`);
/// sin él, JSON. `POST mis-pqrs`. Devuelve el detalle, con el radicado y el
/// día que vence, o lanza con la frase del servidor.
Future<DetallePqrs> radicarPqrs(
  Server server, {
  required String tipo,
  required String clase,
  required String asunto,
  required String descripcion,
  int? alumnoId,
  ElegidoParaSubir? adjunto,
}) async {
  final campos = <String, String>{
    'tipo': tipo,
    'clase': clase,
    'asunto': asunto,
    'descripcion': descripcion,
    if (alumnoId != null) 'alumno_id': '$alumnoId',
  };
  final http.Response res = adjunto == null
      ? await server.post('/mis-pqrs', campos)
      : await server.subirConCampos('/mis-pqrs', adjunto.bytes, adjunto.nombre, campos);
  if (res.statusCode != 200) throw Exception(_frase(res, 'radicar'));
  return DetallePqrs.fromJson(Map<String, dynamic>.from(jsonDecode(res.body) as Map));
}

/// La encuesta de cierre: de 1 a 5 y un comentario. Contestarla la cierra.
/// `POST mis-pqrs/{id}/encuesta`.
Future<DetallePqrs> contestarEncuestaPqrs(Server server, int id,
    {required int satisfaccion, String? comentario}) async {
  final http.Response res = await server.post('/mis-pqrs/$id/encuesta', {
    'satisfaccion': satisfaccion,
    if (comentario != null && comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
  });
  if (res.statusCode != 200) throw Exception(_frase(res, 'enviar la encuesta'));
  return DetallePqrs.fromJson(Map<String, dynamic>.from(jsonDecode(res.body) as Map));
}

/// Los bytes de un adjunto. No es una URL para `Image.network`: lleva el
/// token. `GET mis-pqrs/adjuntos/{id}`.
Future<Uint8List> traerAdjuntoDePqrs(Server server, int adjuntoId) async {
  final http.Response res = await server.get('/mis-pqrs/adjuntos/$adjuntoId');
  if (res.statusCode != 200) throw Exception(_frase(res, 'abrir el adjunto'));
  return res.bodyBytes;
}

/// La frase del servidor si la trae; si no, una que diga qué no se pudo.
String _frase(http.Response res, String accion) {
  try {
    final cuerpo = jsonDecode(res.body);
    final mensaje = cuerpo is Map ? cuerpo['message'] : null;
    if (mensaje is String && mensaje.trim().isNotEmpty) return mensaje;
  } catch (_) {
    // Sin JSON: un 500 o un servidor sin `mis-pqrs` todavía.
  }
  if (res.statusCode == 404) return 'Este colegio todavía no tiene las PQRS en la app.';
  return 'No se pudo $accion (HTTP ${res.statusCode}).';
}
