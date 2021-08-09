import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';

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
  List<AsistenciaModel>? tardanzasEntrada;
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
    this.ausenciasTotal,
  });

  bool tieneTardanzaHoy (DateTime today) {
    bool tiene = false;
    if (tardanzasEntrada != null){
      if(tardanzasEntrada!.length > 0){
        print('tardanzasEntrada!.length ${tardanzasEntrada!.length}');
        for (int i=0; i < tardanzasEntrada!.length; i++){
          print(tardanzasEntrada![i].toJson());
          if (tardanzasEntrada![i].createdAt != null){
            DateTime dateTime = tardanzasEntrada![i].createdAt as DateTime;
            DateTime date = DateTime(dateTime.year, dateTime.month, dateTime.day);
            if(date == today){
              print('Uno iguallllll');
              tiene = true;
            }
          }
        }
      }
    }

    return tiene;
  }

  factory AlumnoModel.fromJson(Map<String, dynamic> parsedJson) {
    List<AsistenciaModel> listTempTardanzasEntrada = [];

    if (parsedJson['tardanzas'] != null) {
      List tardanzas = parsedJson['tardanzas'] as List;
      listTempTardanzasEntrada =
          tardanzas.map((e) => AsistenciaModel.fromJson(e)).toList();
    }

    return AlumnoModel(
      id: parsedJson['alumno_id'],
      nombres: parsedJson['nombres'].toString(),
      apellidos: parsedJson['apellidos'].toString(),
      sexo: parsedJson['sexo'].toString(),
      fotoNombre: parsedJson['foto_nombre'] == null
          ? null
          : parsedJson['foto_nombre'].toString(),
      tardanzasEntrada: listTempTardanzasEntrada,
      ausenciasTotal: Map<String, int>.from(parsedJson['ausencias_total']),
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
        "ausencias_total": ausenciasTotal,
      };
}
