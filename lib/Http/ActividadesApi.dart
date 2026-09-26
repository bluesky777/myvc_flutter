/// El cliente de `act/*` del lado de quien responde: la bandeja, responder,
/// el borrador, enviar, subir la foto o el archivo, entregar la tarea y «mis
/// respuestas».
///
/// **Sin endpoints nuevos** (contrato, tanda 6): son las mismas rutas que usa
/// la web, en `8myvc/routes/api/act.php`, leídas el 26 sep 2026 en la rama
/// `feat/actividades` del backend. Donde el backend difiere del contrato manda
/// el backend, y hay dos diferencias que tocan aquí:
///
/// - `GET act/archivos/{id}` contesta `application/octet-stream` y no el tipo
///   real (por un `Access-Control-Allow-Origin` que el nginx del docker añade a
///   las imágenes). El tipo real va en `ArchivoAct.mime`.
/// - «Mis respuestas» con `alumno_id` sólo lo manda el **acudiente**: el
///   servidor lo mira con `tipo === 'Acudiente'`.
///
/// Los errores salen como [MotivoDeActividad], con la frase del servidor si la
/// hay. Ojo, que el servidor dice las cosas de dos maneras: `abort(…)` llega
/// como `{message}` y los 422 con cuerpo como `{mensaje, faltan|hijos}`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// El tope de un archivo, igual que `EntregasController::TOPE_BYTES`.
const int topeDeArchivoAct = 5 * 1024 * 1024;

/// Algo de actividades que no salió, con una frase que se puede enseñar.
class MotivoDeActividad implements Exception {
  final String mensaje;
  final int? status;

  /// Las preguntas obligatorias que faltan (422 de enviar o entregar).
  final List<int> faltan;

  const MotivoDeActividad(this.mensaje, {this.status, this.faltan = const []});

  @override
  String toString() => mensaje;
}

MotivoDeActividad _motivo(dynamic res, String accion) {
  String? frase;
  var faltan = const <int>[];
  try {
    final leido = jsonDecode(res.body);
    if (leido is Map) {
      final crudo = '${leido['mensaje'] ?? leido['message'] ?? ''}'.trim();
      if (crudo.isNotEmpty && crudo.length <= 200 && !crudo.contains('\n')) {
        frase = crudo;
      }
      if (leido['faltan'] is List) {
        faltan =
            (leido['faltan'] as List).map(entero).whereType<int>().toList();
      }
    }
  } catch (_) {}

  final int status = res.statusCode;
  frase ??= switch (status) {
    401 => 'Tu sesión se cerró. Vuelve a entrar.',
    403 => 'Esta actividad no te toca.',
    404 => 'Esta actividad ya no existe.',
    409 => 'Esta actividad no está abierta.',
    _ => 'No se pudo $accion: el servidor respondió $status.',
  };
  return MotivoDeActividad(frase, status: status, faltan: faltan);
}

dynamic _json(dynamic res, String accion) {
  if (res.statusCode >= 300) throw _motivo(res, accion);
  try {
    return jsonDecode(res.body);
  } catch (_) {
    throw MotivoDeActividad('No se pudo $accion: respuesta inesperada.');
  }
}

Map<String, dynamic> _mapaDe(dynamic res, String accion) {
  final leido = _json(res, accion);
  if (leido is Map) return Map<String, dynamic>.from(leido);
  throw MotivoDeActividad('No se pudo $accion: respuesta inesperada.');
}

String _conAlumno(String ruta, int? alumnoId) =>
    alumnoId == null ? ruta : '$ruta?alumno_id=$alumnoId';

/// `GET act/bandeja?vista=responder`: lo que me toca, abierto o cerrado.
Future<List<ActEnBandeja>> traerBandejaDeActividades(Server server) async {
  final res = await server.get('/act/bandeja?vista=responder');
  final leido = _json(res, 'traer tus actividades');
  if (leido is! List) return const [];
  return leido
      .whereType<Map>()
      .map((m) => ActEnBandeja.fromJson(Map<String, dynamic>.from(m)))
      .toList();
}

/// `GET act/{id}/responder?alumno_id=`.
Future<ActParaResponder> traerParaResponder(Server server, int id,
    {int? alumnoId}) async {
  final res = await server.get(_conAlumno('/act/$id/responder', alumnoId));
  return ActParaResponder.fromJson(_mapaDe(res, 'abrir la actividad'));
}

Map<String, dynamic> _cuerpo(
        int? alumnoId, Iterable<RespuestaAct> respuestas) =>
    {
      if (alumnoId != null) 'alumno_id': alumnoId,
      'respuestas': respuestas.map((r) => r.toJson()).toList(),
    };

/// `POST act/{id}/borrador` → la hora a la que quedó guardado.
Future<DateTime?> guardarBorradorDeActividad(
    Server server, int id, Iterable<RespuestaAct> respuestas,
    {int? alumnoId}) async {
  final res =
      await server.post('/act/$id/borrador', _cuerpo(alumnoId, respuestas));
  return horaDeActividad(_mapaDe(res, 'guardar el borrador')['guardado_at']);
}

/// `POST act/{id}/enviar`. Un 422 con `faltan` vuelve en
/// [MotivoDeActividad.faltan].
Future<ResultadoDeEnvio> enviarActividad(
    Server server, int id, Iterable<RespuestaAct> respuestas,
    {int? alumnoId}) async {
  final res =
      await server.post('/act/$id/enviar', _cuerpo(alumnoId, respuestas));
  return ResultadoDeEnvio.fromJson(_mapaDe(res, 'enviar tus respuestas'));
}

/// `POST act/{id}/archivo`, multipart. [clase] es `foto` o `archivo`.
///
/// La foto tiene que llegar ya reducida (el servidor corta por encima de
/// 1600 px de lado largo) y nada puede pasar de [topeDeArchivoAct].
Future<ArchivoAct> subirArchivoDeActividad(
  Server server,
  int id, {
  required String clase,
  required List<int> bytes,
  required String nombre,
  int? alumnoId,
  int? preguntaId,
}) async {
  if (bytes.length > topeDeArchivoAct) {
    throw const MotivoDeActividad('El archivo pasa de 5 MB: pega un enlace');
  }
  final res = await server.subirConCampos('/act/$id/archivo', bytes, nombre, {
    'clase': clase,
    if (alumnoId != null) 'alumno_id': '$alumnoId',
    if (preguntaId != null) 'pregunta_id': '$preguntaId',
  });
  return ArchivoAct.fromJson(_mapaDe(res, 'subir el archivo'));
}

/// `POST act/{id}/entregar`. Sólo se mandan los campos que no son null: un
/// tipo que la tarea no pide es 422 aunque vaya vacío.
Future<EntregaAct> entregarTarea(
  Server server,
  int id, {
  int? alumnoId,
  String? texto,
  String? enlace,
  int? fotoId,
  int? archivoId,
  Iterable<RespuestaAct>? respuestas,
}) async {
  final res = await server.post('/act/$id/entregar', {
    if (alumnoId != null) 'alumno_id': alumnoId,
    if (texto != null) 'texto': texto,
    if (enlace != null) 'enlace': enlace,
    if (fotoId != null) 'foto_id': fotoId,
    if (archivoId != null) 'archivo_id': archivoId,
    if (respuestas != null)
      'respuestas': respuestas.map((r) => r.toJson()).toList(),
  });
  return EntregaAct.fromJson(_mapaDe(res, 'entregar la tarea'));
}

/// `GET act/{id}/mis-respuestas?alumno_id=`. El `alumno_id` sólo lo manda el
/// acudiente, por el hijo del que habla.
Future<MisRespuestasAct> traerMisRespuestas(Server server, int id,
    {int? alumnoId}) async {
  final res = await server.get(_conAlumno('/act/$id/mis-respuestas', alumnoId));
  return MisRespuestasAct.fromJson(_mapaDe(res, 'traer tus respuestas'));
}

/// `GET act/archivos/{id}`: los bytes de una foto o un archivo entregado.
///
/// No es una URL que se le pueda dar a `Image.network`: lleva el token.
Future<Uint8List> traerArchivoDeActividad(Server server, int archivoId) async {
  final res = await server.get('/act/archivos/$archivoId');
  if (res.statusCode >= 300) throw _motivo(res, 'abrir el archivo');
  return res.bodyBytes as Uint8List;
}
