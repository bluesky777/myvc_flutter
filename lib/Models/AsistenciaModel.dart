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
  String? createdAt;
  int entrada;
  String? fechaHora;
  int periodoId;
  String tipo;

  AsistenciaModel({
    required this.id,
    required this.alumnoId,
    this.asignaturaId,
    this.createdBy,
    this.createdAt,
    required this.entrada,
    this.fechaHora,
    required this.periodoId,
    required this.tipo,
  });

  factory AsistenciaModel.fromJson(Map<String, dynamic> parsedJson) {
    return AsistenciaModel(
      id: parsedJson['id'],
      alumnoId: parsedJson['alumno_id'],
      asignaturaId: parsedJson['asignatura_id'],
      createdBy: parsedJson['created_by'],
      createdAt: parsedJson['created_at'].toString(),
      entrada: parsedJson['entrada'],
      fechaHora: parsedJson['fecha_hora'].toString(),
      periodoId: parsedJson['periodo_id'],
      tipo: parsedJson['created_at'].toString(),
    );
  }

  @override
  String toString() {
    return '(GrupoModel) $entrada - $alumnoId';
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "alumno_id": alumnoId,
        "asignatura_id": asignaturaId,
        "created_by": createdBy,
        "created_at": createdAt,
        "entrada": entrada,
        "fechaHora": fechaHora,
        "periodoId": periodoId,
        "tipo": tipo,
      };
}
