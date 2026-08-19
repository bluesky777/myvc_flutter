import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/YearModel.dart';

/// Un año tal como lo devuelve GET /years.
Map<String, dynamic> year({
  required int id,
  required dynamic anio,
  required dynamic actual,
  required List<Map<String, dynamic>> periodos,
}) {
  return {
    'id': id,
    'year': anio,
    'actual': actual,
    'nombre_colegio': 'Simón Bolívar',
    'periodos': periodos,
  };
}

void main() {
  test('actual llega como 1/0, no como booleano', () {
    final vigente = YearModel.fromJson(year(
      id: 8,
      anio: 2025,
      actual: 1,
      periodos: [
        {'id': 30, 'numero': 1},
      ],
    ));

    final viejo = YearModel.fromJson(year(
      id: 7,
      anio: 2024,
      actual: 0,
      periodos: [
        {'id': 20, 'numero': 1},
      ],
    ));

    expect(vigente.actual, isTrue);
    expect(viejo.actual, isFalse);
    expect(vigente.year, '2025');
  });

  test('los periodos quedan ordenados por número', () {
    final y = YearModel.fromJson(year(
      id: 8,
      anio: 2025,
      actual: 1,
      periodos: [
        {'id': 33, 'numero': 4},
        {'id': 30, 'numero': 1},
        {'id': 32, 'numero': 3},
        {'id': 31, 'numero': 2},
      ],
    ));

    expect(y.periodos.map((p) => p.numero).toList(), [1, 2, 3, 4]);
    expect(y.periodos.first.id, 30);
  });

  test('los numéricos que llegan como texto no rompen el orden', () {
    // Según la columna y el driver, unas veces son int y otras string.
    final y = YearModel.fromJson(year(
      id: 8,
      anio: '2025',
      actual: '1',
      periodos: [
        {'id': '31', 'numero': '2'},
        {'id': '30', 'numero': '1'},
      ],
    ));

    expect(y.actual, isTrue);
    expect(y.periodos.map((p) => p.numero).toList(), [1, 2]);
    expect(y.periodos.first.id, 30);
  });

  test('un año sin periodos no revienta', () {
    final y = YearModel.fromJson({'id': 3, 'year': 2020, 'actual': 0});
    expect(y.periodos, isEmpty);
  });
}
