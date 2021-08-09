import 'dart:convert';

import 'package:flutter/cupertino.dart';

List<AsistenciaModel> alumnoModelFromJson(String str) =>
    List<AsistenciaModel>.from(
        json.decode(str).map((x) => AsistenciaModel.fromJson(x)));

class AsistenciaModel {
  int id;
  int alumnoId;
  int? asignaturaId;
  int? createdBy;
  DateTime? createdAt;
  int entrada;
  String? fechaHora;
  int periodoId;
  String? tipo;


  AsistenciaModel({
    required this.id,
    required this.alumnoId,
    this.asignaturaId,
    this.createdBy,
    this.createdAt,
    required this.entrada,
    this.fechaHora,
    required this.periodoId,
    this.tipo,
  });

  factory AsistenciaModel.fromJson(Map<String, dynamic> parsedJson) {
    print('fromJson ${parsedJson}');
    return AsistenciaModel(
      id: parsedJson['id'],
      alumnoId: parsedJson['alumno_id'],
      asignaturaId: parsedJson['asignatura_id'],
      createdBy: parsedJson['created_by'],
      createdAt: parsedJson['created_at'] == null ? null : DateTime.parse(parsedJson['created_at'].toString()),
      entrada: parsedJson['entrada'],
      fechaHora: parsedJson['fecha_hora'].toString(),
      periodoId: parsedJson['periodo_id'],
      tipo: parsedJson['tipo'] == null ? null : parsedJson['tipo'].toString(),
    );
  }

  @override
  String toString() {
    return '(AsistenciaModel) id: $id - entrada: $entrada - alumnoId: $alumnoId - createdAt $createdAt';
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "alumno_id": alumnoId,
        "asignatura_id": asignaturaId,
        "created_by": createdBy,
        "created_at": createdAt == null ? null : createdAt!.toIso8601String(),
        "entrada": entrada,
        "fechaHora": fechaHora,
        "periodoId": periodoId,
        "tipo": tipo,
      };
}
