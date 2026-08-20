import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Lo que un alumno lleva faltado en un periodo.
///
/// Son cuatro cuentas, y la separación importa: llegar tarde al colegio no es
/// lo mismo que llegar tarde a una clase, ni faltar un día entero es lo mismo
/// que faltar a una asignatura. El backend las cuenta por separado —entrada=1
/// para lo de la institución, entrada=0 para lo de clase— y así se enseñan.
class AsistenciaPeriodoModel {
  final int id;
  final int numero;

  final int tardanzasInstitucion;
  final int ausenciasInstitucion;
  final int tardanzasClases;
  final int ausenciasClases;

  AsistenciaPeriodoModel({
    required this.id,
    required this.numero,
    this.tardanzasInstitucion = 0,
    this.ausenciasInstitucion = 0,
    this.tardanzasClases = 0,
    this.ausenciasClases = 0,
  });

  int get totalInstitucion => tardanzasInstitucion + ausenciasInstitucion;

  int get totalClases => tardanzasClases + ausenciasClases;

  bool get sinNada => totalInstitucion == 0 && totalClases == 0;

  factory AsistenciaPeriodoModel.fromJson(Map<String, dynamic> json) {
    // Las cuentas vienen anidadas en `asistencia`, que unas veces es un objeto
    // con los cuatro totales y otras —cuando el alumno no tiene ni una falta—
    // el array de ceros que devuelve el backend por su cuenta.
    final crudas = json['asistencia'];
    final cuentas = crudas is Map ? Map<String, dynamic>.from(crudas) : {};

    return AsistenciaPeriodoModel(
      id: enteroO(json['id']),
      numero: enteroO(json['numero']),
      tardanzasInstitucion: enteroO(cuentas['cant_tardanzas_entrada']),
      ausenciasInstitucion: enteroO(cuentas['cant_ausencias_entrada']),
      tardanzasClases: enteroO(cuentas['cant_tardanzas_clases']),
      ausenciasClases: enteroO(cuentas['cant_ausencias_clases']),
    );
  }
}

/// Lee la lista de periodos con sus cuentas, venga de donde venga.
List<AsistenciaPeriodoModel> asistenciaPorPeriodo(dynamic crudos) {
  if (crudos is! List) return const [];

  return crudos
      .whereType<Map>()
      .map((p) => AsistenciaPeriodoModel.fromJson(Map<String, dynamic>.from(p)))
      .toList()
    ..sort((a, b) => a.numero.compareTo(b.numero));
}
