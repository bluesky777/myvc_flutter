
import 'package:flutter/cupertino.dart';

class AlumnoModel extends ChangeNotifier {
  String nombres;
  String? apellidos;
  String sexo;
  bool? is_active;
  bool is_expanded;
  List<AlumnoModel> alumnos = [];

  AlumnoModel({
    required this.nombres, this.apellidos, required this.sexo, this.is_active, this.is_expanded=false
  });

  @override
  String toString() {
    return '$nombres - $sexo';
  }

}

List<AlumnoModel> alumnos = [
  AlumnoModel(nombres: "Joseth David", sexo: "M"),
  AlumnoModel(nombres: "Jeiran", sexo: "M"),
  AlumnoModel(nombres: "Marcela", sexo: "M"),
  AlumnoModel(nombres: "Joseth David", sexo: "M"),
  AlumnoModel(nombres: "Jeiran", sexo: "M"),
  AlumnoModel(nombres: "Marcela", sexo: "M"),
  AlumnoModel(nombres: "Joseth David", sexo: "M"),
  AlumnoModel(nombres: "Jeiran", sexo: "M"),
  AlumnoModel(nombres: "Marcela", sexo: "M"),
  AlumnoModel(nombres: "Joseth David", sexo: "M"),
  AlumnoModel(nombres: "Jeiran", sexo: "M"),
  AlumnoModel(nombres: "Marcela", sexo: "M"),
];