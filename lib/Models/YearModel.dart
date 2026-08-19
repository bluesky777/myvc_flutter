import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Un año lectivo con sus periodos, tal como los devuelve `GET /years`.
class YearModel {
  final int id;
  final String year;
  final bool actual;
  final List<PeriodoModel> periodos;

  YearModel({
    required this.id,
    required this.year,
    required this.actual,
    required this.periodos,
  });

  factory YearModel.fromJson(Map<String, dynamic> json) {
    final crudos = (json['periodos'] as List?) ?? [];

    final periodos = crudos
        .map((p) => PeriodoModel.fromJson(p as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));

    return YearModel(
      id: entero(json['id']) ?? 0,
      year: '${json['year']}',
      // El backend manda 1/0, no true/false.
      actual: entero(json['actual']) == 1,
      periodos: periodos,
    );
  }

  @override
  String toString() => year;
}

class PeriodoModel {
  final int id;
  final int numero;

  PeriodoModel({required this.id, required this.numero});

  factory PeriodoModel.fromJson(Map<String, dynamic> json) {
    return PeriodoModel(
      id: entero(json['id']) ?? 0,
      numero: entero(json['numero']) ?? 0,
    );
  }
}
