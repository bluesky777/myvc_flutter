import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';

/// Una tardanza tal como la devuelve /asistencias/detailed.
Map<String, dynamic> tardanza({
  required int id,
  required String fechaHora,
  String creadaEl = '2026-08-19 15:08:56',
}) {
  return {
    'id': id,
    'asignatura_id': null,
    'alumno_id': 1,
    'periodo_id': 31,
    'cantidad_ausencia': null,
    'cantidad_tardanza': null,
    'entrada': 1,
    'fecha_hora': fechaHora,
    'uploaded': null,
    'created_by': 1,
    'created_at': creadaEl,
    'tipo': 'tardanza',
  };
}

void main() {
  test('el día de la tardanza sale de fecha_hora, no de cuándo se grabó', () {
    // Registrada hoy (19) pero para el día 10: es lo que pasa al elegir fecha.
    final t = AsistenciaModel.fromJson(
      tardanza(id: 1, fechaHora: '2026-08-10 00:00:00'),
    );

    expect(t.esDelDia(DateTime(2026, 8, 10)), isTrue);

    // El 19 es cuando se grabó la fila. Mirar eso era el fallo: la pantalla
    // pintaba la tardanza como de hoy y parecía que la fecha elegida se perdía.
    expect(t.esDelDia(DateTime(2026, 8, 19)), isFalse);
  });

  test('fecha_hora nulo no cuenta para ningún día', () {
    final t = AsistenciaModel.fromJson(tardanza(id: 2, fechaHora: '')
      ..['fecha_hora'] = null);

    expect(t.fecha, isNull);
    expect(t.esDelDia(DateTime(2026, 8, 10)), isFalse);
  });

  test('el alumno solo cuenta las tardanzas del día elegido', () {
    final alumno = AlumnoModel.fromJson({
      'alumno_id': 1,
      'nombres': 'Ana',
      'apellidos': 'Pérez',
      'sexo': 'F',
      'foto_nombre': null,
      'ausencias_total': {'cant_tardanzas_entrada': 3},
      'tardanzas': [
        tardanza(id: 1, fechaHora: '2026-08-10 07:40:00'),
        tardanza(id: 2, fechaHora: '2026-08-10 07:55:00'),
        tardanza(id: 3, fechaHora: '2026-08-19 07:30:00'),
      ],
    });

    expect(alumno.tardanzasDelDia(DateTime(2026, 8, 10)).length, 2);
    expect(alumno.tardanzasDelDia(DateTime(2026, 8, 19)).length, 1);
    expect(alumno.tardanzasDelDia(DateTime(2026, 8, 11)), isEmpty);

    expect(alumno.tieneTardanzaEn(DateTime(2026, 8, 10)), isTrue);
    expect(alumno.tieneTardanzaEn(DateTime(2026, 8, 11)), isFalse);
  });

  test('la hora no altera el día', () {
    final nocturna = AsistenciaModel.fromJson(
      tardanza(id: 4, fechaHora: '2026-08-10 23:59:59'),
    );

    expect(nocturna.esDelDia(DateTime(2026, 8, 10)), isTrue);
    expect(nocturna.esDelDia(DateTime(2026, 8, 11)), isFalse);
  });
}
