import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Quién tocó una nota, cuándo y qué había antes.
///
/// Cada `PUT notas/update/{id}` deja una fila en `bitacoras` con el valor
/// viejo y el nuevo, así que el historial no es una tabla aparte que haya que
/// mantener: es la auditoría que la plataforma ya escribía.
///
/// Se pide **solo cuando alguien lo abre**. No es un dato de la pantalla de
/// notas, es la respuesta a una pregunta concreta —«¿esta nota la cambié yo o
/// me la cambiaron?»— que se hace de vez en cuando.

/// Un cambio de la bitácora.
class CambioDeNota {
  final int id;
  final int? anterior;
  final int? nueva;
  final String quien;
  final DateTime? cuando;

  const CambioDeNota({
    required this.id,
    this.anterior,
    this.nueva,
    this.quien = '',
    this.cuando,
  });

  factory CambioDeNota.fromJson(Map<String, dynamic> json) {
    return CambioDeNota(
      id: enteroO(json['bit_id']),
      // Enteros, y **la bitácora no tiene la culpa**. Sus columnas se llaman
      // `..._value_int`, sí, pero es que `notas.nota` es `int` en el esquema:
      // los decimales no se pierden al registrarlos, es que **no existen en
      // ninguna parte** —ni en `notas`, ni en `notas_finales`, ni en los
      // porcentajes de unidades y subunidades—. Un 85,5 nunca fue un 85,5.
      //
      // Se dice así de claro porque el comentario anterior invitaba a
      // «arreglar» la bitácora para que guardara decimales, y eso no arreglaría
      // nada: el que se los come es la columna de la nota. Comprobado con el
      // backend el 23 de agosto de 2026.
      //
      // El historial dice quién y cuándo con precisión, y el cuánto con la del
      // entero; enseñar decimales que nunca se guardaron sería inventarlos.
      anterior: entero(json['old_value']),
      nueva: entero(json['new_value']),
      quien: '${json['creado_por'] ?? ''}'.trim(),
      cuando: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

/// El historial de una nota, con quién la creó.
class HistorialDeNota {
  final List<CambioDeNota> cambios;

  /// Quién creó la fila. Puede ser el sistema: las notas se materializan solas
  /// al abrir el libro por primera vez.
  final String creadaPor;

  /// Quién la tocó por última vez.
  final String modificadaPor;

  const HistorialDeNota({
    this.cambios = const [],
    this.creadaPor = '',
    this.modificadaPor = '',
  });

  bool get vacio => cambios.isEmpty;

  /// Lo que devuelve `historiales/nota-detalle`.
  ///
  /// Los cambios llegan en dos consultas unidas: los de un docente vienen con
  /// su nombre y apellidos, y los de cualquier otro usuario con su nombre de
  /// cuenta. Aquí da igual cuál sea, porque las dos ramas escriben en la misma
  /// columna.
  factory HistorialDeNota.fromJson(Map<String, dynamic> json) {
    final crudos = json['cambios'];
    final nota = json['nota'];

    final cambios = crudos is List
        ? (crudos
            .whereType<Map>()
            .map((c) => CambioDeNota.fromJson(Map<String, dynamic>.from(c)))
            .toList()
          // Del más reciente al más viejo: lo que interesa primero es el
          // último cambio, que es el que explica lo que se ve en pantalla.
          ..sort((a, b) => b.id.compareTo(a.id)))
        : <CambioDeNota>[];

    return HistorialDeNota(
      cambios: cambios,
      // Cuando la nota no existe, el backend devuelve una lista vacía en vez
      // de un objeto: por eso se comprueba el tipo antes de leerla.
      creadaPor: nota is Map ? '${nota['creado_por'] ?? ''}'.trim() : '',
      modificadaPor: nota is Map ? '${nota['modificado_por'] ?? ''}'.trim() : '',
    );
  }
}

/// Trae el historial de una nota.
///
/// `PUT historiales/nota-detalle {nota_id}`.
Future<HistorialDeNota> traerHistorialDeNota(
  Server server, {
  required int notaId,
}) async {
  final res = await server.put('/historiales/nota-detalle', {
    'nota_id': notaId,
  });

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) return const HistorialDeNota();

  return HistorialDeNota.fromJson(Map<String, dynamic>.from(cuerpo));
}

/// Borra una nota. Devuelve null si entró, o el motivo si no.
///
/// **Se vuelve a crear sola.** La fila de `notas` la materializa
/// `notas/detailed` al abrir el libro, así que borrar no deja al alumno sin
/// casilla: la deja con la nota por defecto de la subunidad. Es la forma de
/// deshacer «puse un 40 donde no había nada» sin dejar un cero que parezca una
/// nota de verdad.
///
/// Al borrar, el backend **recalcula la definitiva** de ese alumno —igual que
/// al actualizar una nota, respetando las manuales y las recuperadas—. Pero
/// aquí la app no puede seguirle la cuenta: para saber el promedio nuevo haría
/// falta saber que esa casilla ya no existe, y quien tiene el libro en memoria
/// sigue teniéndola. Por eso borrar es lo único de la pantalla que obliga a
/// recargar el libro.
Future<String?> borrarNota(Server server, {required int notaId}) async {
  try {
    final res = await server.delete('/notas/destroy/$notaId');

    if (res.statusCode == 400 || res.statusCode == 403) {
      return 'No tienes permiso para editar notas en este periodo.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo borrar la nota: $err';
  }
}
