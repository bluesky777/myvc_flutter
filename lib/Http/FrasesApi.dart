import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';

/// Las frases del boletín: lo que el docente le dice al alumno además de la
/// nota.
///
/// Dos tablas y conviene no confundirlas. `frases` es **el catálogo del año**,
/// que escribe el colegio; `frases_asignatura` es **lo que se le pone a un
/// alumno concreto** en una asignatura y un periodo, y puede apuntar al
/// catálogo o llevar su propio texto.
///
/// Las que ya tiene un alumno no hay que pedirlas: vienen dentro de
/// `notas/detailed`, en `alumno.frases`. Este archivo es para el catálogo y
/// para escribir.

/// El catálogo del año.
///
/// `GET frases`, que devuelve las del año del usuario y ya. Se pide una vez, al
/// abrir la hoja de elegir, y se guarda en memoria mientras la pantalla viva:
/// son cuatrocientas filas y no cambian mientras alguien pone notas.
Future<List<FraseDelCatalogo>> traerCatalogoDeFrases(Server server) async {
  final res = await server.get('/frases');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! List) return const [];

  return cuerpo
      .whereType<Map>()
      .map((f) => FraseDelCatalogo.fromJson(Map<String, dynamic>.from(f)))
      .where((f) => f.id != 0)
      .toList();
}

/// Lo que devuelve poner o quitar una frase.
class ResultadoDeFrases {
  const ResultadoDeFrases({this.frases, this.motivo});

  /// Cómo quedó la lista del alumno. Null cuando falló.
  final List<FraseDeAlumno>? frases;

  /// Por qué no se pudo, o null si entró.
  final String? motivo;

  bool get entro => motivo == null;
}

/// Le pone una frase a un alumno.
///
/// Una de dos: la del catálogo, pasando [fraseId], o una escrita a mano,
/// pasando [texto]. El backend las distingue por la URL —el id va en la ruta,
/// no en el cuerpo— y **si viene id ignora el texto**, así que mandar los dos
/// no sirve de nada.
///
/// **El periodo no se manda y no se puede elegir**: `FrasesAsignaturaController`
/// escribe siempre `periodo_id = $user->periodo_id`, o sea el de la barra de
/// arriba. Poner una frase de otro periodo desde aquí es imposible, y por eso
/// la pantalla no lo ofrece.
///
/// Devuelve **la lista entera del alumno ya recalculada**, que es lo que
/// contesta el backend: con eso se repinta sin volver a preguntar.
Future<ResultadoDeFrases> ponerFrase(
  Server server, {
  required int alumnoId,
  required int asignaturaId,
  int? fraseId,
  String? texto,
}) async {
  final ruta = fraseId != null
      ? '/frases_asignatura/store/$fraseId'
      : '/frases_asignatura/store';

  try {
    final res = await server.post(ruta, {
      'alumno_id': alumnoId,
      'asignatura_id': asignaturaId,
      if (fraseId == null) 'frase': texto ?? '',
    });

    if (res.statusCode == 400 || res.statusCode == 403) {
      return const ResultadoDeFrases(
        motivo: 'No tienes permiso para escribir en este periodo.',
      );
    }
    if (res.statusCode >= 300) {
      return ResultadoDeFrases(
        motivo: 'El servidor respondió ${res.statusCode}.',
      );
    }

    return ResultadoDeFrases(frases: frasesDeLista(jsonDecode(res.body)));
  } catch (err) {
    return ResultadoDeFrases(motivo: 'No se pudo poner la frase: $err');
  }
}

/// Le quita una frase a un alumno.
///
/// El id es el de la fila de `frases_asignatura`, no el del catálogo:
/// confundirlos borraría otra frase de otro alumno. Devuelve null si entró, o
/// el motivo si no.
///
/// A diferencia de poner, esto **no devuelve la lista nueva** —contesta la fila
/// borrada—, así que quien llama la quita de la suya.
Future<String?> quitarFrase(Server server, {required int id}) async {
  try {
    final res = await server.delete('/frases_asignatura/destroy/$id');

    if (res.statusCode == 400 || res.statusCode == 403) {
      return 'No tienes permiso para escribir en este periodo.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo quitar la frase: $err';
  }
}
