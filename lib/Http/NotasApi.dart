import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';

/// Por qué no se pueden ver unas notas.
///
/// Son dos bloqueos distintos y el colegio los aplica por razones distintas,
/// así que el mensaje tampoco puede ser el mismo.
enum MotivoBloqueo {
  /// Un administrador cerró el año para alumnos y acudientes.
  colegio,

  /// El alumno no está a paz y salvo en tesorería.
  tesoreria,
}

class NotasBloqueadas implements Exception {
  final MotivoBloqueo motivo;
  final String mensaje;

  NotasBloqueadas(this.motivo, this.mensaje);

  @override
  String toString() => mensaje;
}

/// Trae el boletín de un alumno.
///
/// `GET notas/alumno/{alumno_id}/{grupo_id}`. El año no va en la petición: el
/// backend usa el del usuario, que es el que se elige en la barra de arriba.
///
/// Ojo con las tres formas de responder, que no son la misma:
///
///  - Bloqueado por el colegio: devuelve una CADENA suelta, no un objeto, con
///    el texto 'Sistema bloqueado. No puedes ver las notas'.
///  - Acudiente de un alumno que no está a paz y salvo: devuelve un objeto con
///    la clave `msg`.
///  - Todo bien: devuelve una lista de un solo elemento con el boletín.
///
/// Tratar las dos primeras como «error de red» habría enseñado «no se pudo
/// conectar» a un padre cuya única deuda es con la tesorería.
Future<NotasAlumnoModel> traerNotasDe(
  Server server, {
  required int alumnoId,
  int? grupoId,
}) async {
  final res = await server.get('/notas/alumno/$alumnoId/${grupoId ?? ''}');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);

  if (cuerpo is String) {
    throw NotasBloqueadas(MotivoBloqueo.colegio, cuerpo);
  }

  if (cuerpo is Map && cuerpo['msg'] != null) {
    throw NotasBloqueadas(MotivoBloqueo.tesoreria, '${cuerpo['msg']}');
  }

  final datos = cuerpo is List && cuerpo.isNotEmpty ? cuerpo.first : cuerpo;

  if (datos is! Map) {
    throw Exception('El servidor no devolvió el boletín del alumno.');
  }

  return NotasAlumnoModel.fromJson(Map<String, dynamic>.from(datos));
}

/// profesor_id -> nombre completo, para poner nombre al titular del grupo.
///
/// El boletín trae `titular_id` y no su nombre. /contratos es de donde lo saca
/// el resto de la app. Si falla, la pantalla sigue: se queda sin el nombre,
/// que es un adorno, no el dato.
Future<Map<int, String>> traerDocentesPorProfesor(Server server) async {
  try {
    final res = await server.get('/contratos');
    final lista = jsonDecode(res.body) as List;

    final mapa = <int, String>{};
    for (final contrato in lista) {
      if (contrato is! Map) continue;

      final id = int.tryParse('${contrato['profesor_id']}');
      final nombre = contrato['nombre_completo'];
      if (id != null && nombre != null) mapa[id] = '$nombre'.trim();
    }
    return mapa;
  } catch (_) {
    return {};
  }
}

/// user_id -> nombre completo, para ponerle nombre a quien registró algo.
///
/// Las tablas de la plataforma guardan `added_by` y `created_by` como
/// `user_id`, que NO es el `profesor_id`: son dos numeraciones y cruzarlas por
/// la equivocada pone el nombre de otro docente. /contratos trae los dos, así
/// que aquí se indexa por el que hace falta.
///
/// Mapa vacío si falla: el nombre de quien registró es un dato de apoyo, no la
/// falta en sí, y quedarse sin él no puede tumbar la pantalla.
Future<Map<int, String>> traerNombresPorUsuario(Server server) async {
  try {
    final res = await server.get('/contratos');
    final lista = jsonDecode(res.body) as List;

    final mapa = <int, String>{};
    for (final contrato in lista) {
      if (contrato is! Map) continue;

      final id = int.tryParse('${contrato['user_id']}');
      final nombre = contrato['nombre_completo'];
      if (id != null && nombre != null) mapa[id] = '$nombre'.trim();
    }
    return mapa;
  } catch (_) {
    return {};
  }
}
