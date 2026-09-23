import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Un año lectivo con sus periodos, tal como los devuelve `GET /years`.
class YearModel {
  final int id;
  final String year;
  final bool actual;
  final List<PeriodoModel> periodos;

  /// Las siglas del colegio, tal como las escribió él: `CASB`.
  ///
  /// Columna `years.abrev_colegio`, y llega porque `GET /years` selecciona
  /// `y.*`. Estuvo llegando y tirándose desde siempre; la recoge la barra de
  /// arriba, que necesita un rótulo corto y prefiere el del colegio al que
  /// pueda calcular la app. Vacía si ese colegio nunca la rellenó — es una
  /// columna que admite nulo.
  final String abrevColegio;

  /// El archivo del logo del colegio, relativo a las imágenes del servidor.
  ///
  /// Sale del `LEFT JOIN images` que `GET /years` ya hace sobre `y.logo_id`, y
  /// llega como `i.nombre` — la ruta que entiende `Server.urlFoto`. Vacío en el
  /// colegio que no le puso logo: la columna admite nulo.
  final String logo;

  YearModel({
    required this.id,
    required this.year,
    required this.actual,
    required this.periodos,
    this.abrevColegio = '',
    this.logo = '',
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
      abrevColegio: '${json['abrev_colegio'] ?? ''}'.trim(),
      logo: '${json['logo'] ?? ''}'.trim(),
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
