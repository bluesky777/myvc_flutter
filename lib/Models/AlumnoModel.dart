
import 'package:flutter/cupertino.dart';

class AlumnoModel extends ChangeNotifier {
  int id;
  String nombres;
  String? apellidos;
  String sexo;
  bool? isActive;
  bool isExpanded;
  List<AlumnoModel> alumnos = [];

  AlumnoModel({
    required this.id, required this.nombres, this.apellidos, required this.sexo, this.isActive, this.isExpanded=false
  });

  factory AlumnoModel.fromJson(Map<String, dynamic> parsedJson) {
    return AlumnoModel(
      id: parsedJson['id'],
      nombres: parsedJson['nombres'].toString(),
      apellidos: parsedJson['apellidos'].toString(),
      sexo: parsedJson['sexo'].toString(),
    );
  }

  @override
  String toString() {
    return '(GrupoModel) $nombres';
  }

}
