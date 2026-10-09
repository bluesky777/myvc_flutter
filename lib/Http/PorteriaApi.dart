import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PorteriaModel.dart';

/// La portería: `routes/api/tardanzas.php` del backend, `PorteriaController`.
///
/// Todas contestan JSON —`/porteria/` está en [Server.rutasQueContestanJson]—,
/// así que el error trae la frase del servidor en `message` y se enseña tal
/// cual: «Ese alumno no está matriculado este año» dice más que un 422.

/// Los alumnos del año actual y las tardanzas que ya hay hoy.
/// `GET porteria/alumnos`.
Future<ListaDePorteria> traerPorteria(Server server) async {
  final http.Response res = await server.get('/porteria/alumnos');

  if (res.statusCode != 200) {
    throw Exception(_frase(res, 'traer los alumnos'));
  }

  final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;

  return ListaDePorteria(
    alumnos: [
      for (final a in (cuerpo['alumnos'] as List? ?? const []))
        AlumnoDePorteria.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
    tardanzasHoy: [
      for (final t in (cuerpo['tardanzas_hoy'] as List? ?? const []))
        TardanzaDeHoy.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
  );
}

/// Pone la tardanza de hoy. Va [codigo] (lo que leyó la cámara) o [alumnoId]
/// (lo que se eligió en el buscador). `POST porteria/tardanza`.
///
/// Si ya tenía tardanza hoy el servidor no pone otra: devuelve la que hay, con
/// `ya_tenia`.
Future<ResultadoTardanza> ponerTardanza(
  Server server, {
  String? codigo,
  int? alumnoId,
}) async {
  try {
    final http.Response res = await server.post('/porteria/tardanza', {
      if (codigo != null) 'codigo': codigo,
      if (alumnoId != null) 'alumno_id': alumnoId,
    });

    if (res.statusCode == 404 && _campo(res, 'desconocido') == true) {
      return ResultadoTardanza.desconocido(codigo ?? '');
    }
    if (res.statusCode == 410) {
      return ResultadoTardanza.anulado(codigo ?? '');
    }
    if (res.statusCode != 200) {
      return ResultadoTardanza.mal(_frase(res, 'poner la tardanza'));
    }

    final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;

    return ResultadoTardanza.puesta(
      AlumnoDePorteria.fromJson(Map<String, dynamic>.from(cuerpo['alumno'] as Map)),
      TardanzaDeHoy.fromJson(Map<String, dynamic>.from(cuerpo['tardanza'] as Map)),
      cuerpo['ya_tenia'] == true,
    );
  } catch (err) {
    return ResultadoTardanza.mal('No se pudo poner la tardanza: $err');
  }
}

/// «Deshacer»: quita una tardanza de entrada de hoy.
/// `DELETE porteria/tardanza/{id}`. Devuelve null si salió bien, o la frase.
Future<String?> quitarTardanza(Server server, int id) async {
  try {
    final http.Response res = await server.delete('/porteria/tardanza/$id');
    return res.statusCode == 200 ? null : _frase(res, 'quitar la tardanza');
  } catch (err) {
    return 'No se pudo quitar la tardanza: $err';
  }
}

/// «¿De quién es este carné?»: guarda el código para que la próxima vez se lea
/// solo. `POST porteria/vincular`. Devuelve null si salió bien, o la frase.
Future<String?> vincularCarne(
  Server server, {
  required String codigo,
  required int alumnoId,
}) async {
  try {
    final http.Response res = await server.post('/porteria/vincular', {
      'codigo': codigo,
      'alumno_id': alumnoId,
    });
    return res.statusCode == 200 ? null : _frase(res, 'guardar el carné');
  } catch (err) {
    return 'No se pudo guardar el carné: $err';
  }
}

/// El carné de la app: el del alumno, o el de cada hijo del acudiente.
/// `GET porteria/mis-carnets`.
Future<List<CarneDeAlumno>> misCarnes(Server server) async {
  final http.Response res = await server.get('/porteria/mis-carnets');

  if (res.statusCode != 200) {
    throw Exception(_frase(res, 'traer el carné'));
  }

  return [
    for (final c in (jsonDecode(res.body) as List))
      CarneDeAlumno.fromJson(Map<String, dynamic>.from(c as Map)),
  ];
}

dynamic _campo(http.Response res, String campo) {
  try {
    final cuerpo = jsonDecode(res.body);
    return cuerpo is Map ? cuerpo[campo] : null;
  } catch (_) {
    return null;
  }
}

/// La frase del servidor si la trae; si no, una que diga qué no se pudo.
String _frase(http.Response res, String accion) {
  final mensaje = _campo(res, 'message');
  if (mensaje is String && mensaje.trim().isNotEmpty) return mensaje;
  return 'No se pudo $accion (HTTP ${res.statusCode}).';
}
