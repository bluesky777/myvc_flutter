import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

List<AlumnoModel> alumnoModelFromJson(String str) => List<AlumnoModel>.from(
    json.decode(str).map((x) => AlumnoModel.fromJson(x)));

class AlumnoModel extends ChangeNotifier {
  int id;
  String nombres;
  String? apellidos;
  String sexo;
  int? isActive;
  bool isExpanded;
  String? fotoNombre;

  List<AlumnoModel> alumnos = [];

  /// Las tardanzas a la institución: llegó tarde al colegio (entrada=1).
  List<AsistenciaModel>? tardanzasEntrada;

  /// Las ausencias a la institución: no vino al colegio ese día (entrada=1).
  /// Son otra fila de la misma tabla, con tipo 'ausencia' en vez de 'tardanza'.
  List<AsistenciaModel>? ausenciasEntrada;

  Map<String, int>? ausenciasTotal;

  AlumnoModel({
    required this.id,
    required this.nombres,
    this.apellidos,
    required this.sexo,
    this.isActive,
    this.isExpanded = false,
    this.fotoNombre,
    this.tardanzasEntrada,
    this.ausenciasEntrada,
    this.ausenciasTotal,
  });

  /// Las tardanzas a la institución registradas para el día dado.
  List<AsistenciaModel> tardanzasDelDia(DateTime dia) =>
      _delDia(tardanzasEntrada, dia);

  /// Las ausencias a la institución registradas para el día dado.
  List<AsistenciaModel> ausenciasDelDia(DateTime dia) =>
      _delDia(ausenciasEntrada, dia);

  bool tieneTardanzaEn(DateTime dia) => tardanzasDelDia(dia).isNotEmpty;

  bool tieneAusenciaEn(DateTime dia) => ausenciasDelDia(dia).isNotEmpty;

  List<AsistenciaModel> _delDia(List<AsistenciaModel>? faltas, DateTime dia) {
    if (faltas == null) return [];
    return faltas.where((f) => f.esDelDia(dia)).toList();
  }

  /// Las faltas a la institución que vengan bajo esa clave.
  ///
  /// /asistencias/detailed las separa ya filtradas por entrada=1: 'tardanzas'
  /// son las de llegar tarde y 'ausencias' las de no venir. Las de clase van
  /// aparte, en 'tardanzas_clase' y 'ausencias_clase', y aquí no se miran.
  static List<AsistenciaModel> _faltas(Map<String, dynamic> json, String clave) {
    final crudas = json[clave];
    if (crudas is! List) return [];

    final faltas = <AsistenciaModel>[];
    for (final cruda in crudas) {
      if (cruda is! Map) continue;
      faltas.add(AsistenciaModel.fromJson(Map<String, dynamic>.from(cruda)));
    }
    return faltas;
  }

  factory AlumnoModel.fromJson(Map<String, dynamic> parsedJson) {

    return AlumnoModel(
      id: enteroO(parsedJson['alumno_id']),
      nombres: '${parsedJson['nombres'] ?? ''}',
      apellidos: texto(parsedJson['apellidos']),
      sexo: '${parsedJson['sexo'] ?? ''}',
      fotoNombre: texto(parsedJson['foto_nombre']),
      tardanzasEntrada: _faltas(parsedJson, 'tardanzas'),
      ausenciasEntrada: _faltas(parsedJson, 'ausencias'),
      ausenciasTotal: mapaDeEnteros(parsedJson['ausencias_total']),
    );
  }

  @override
  String toString() {
    return '(GrupoModel) $nombres';
  }

  Map<String, dynamic> toJson() => {
        "alumno_id": id,
        "nombre": nombres,
        "apellidos": apellidos,
        "foto_nombre": fotoNombre,
        "sexo": sexo,
        "tardanzas": tardanzasEntrada,
        "ausencias": ausenciasEntrada,
        "ausencias_total": ausenciasTotal,
      };
}
