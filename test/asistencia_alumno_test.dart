import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AsistenciaPeriodoModel.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';

void main() {
  group('el recuento de faltas de un periodo', () {
    test('separa lo del colegio de lo de las clases', () {
      // Tal como lo devuelve Ausencia::deAlumnoYear: la fila del periodo con
      // los cuatro contadores colgando de `asistencia`.
      final periodo = AsistenciaPeriodoModel.fromJson({
        'id': 22,
        'numero': 2,
        'year_id': 3,
        'asistencia': {
          'cant_tardanzas_entrada': 2,
          'cant_ausencias_entrada': 1,
          'cant_tardanzas_clases': 0,
          'cant_ausencias_clases': 5,
        },
      });

      expect(periodo.id, 22);
      expect(periodo.numero, 2);
      expect(periodo.tardanzasInstitucion, 2);
      expect(periodo.ausenciasInstitucion, 1);
      expect(periodo.tardanzasClases, 0);
      expect(periodo.ausenciasClases, 5);
      expect(periodo.totalInstitucion, 3);
      expect(periodo.totalClases, 5);
      expect(periodo.sinNada, isFalse);
    });

    test('los contadores en texto se leen igual', () {
      // Un COUNT(*) puede llegar como cadena según el driver de PDO.
      final periodo = AsistenciaPeriodoModel.fromJson({
        'id': '22',
        'numero': '2',
        'asistencia': {
          'cant_tardanzas_entrada': '3',
          'cant_ausencias_entrada': '0',
          'cant_tardanzas_clases': '0',
          'cant_ausencias_clases': '0',
        },
      });

      expect(periodo.id, 22);
      expect(periodo.tardanzasInstitucion, 3);
      expect(periodo.totalInstitucion, 3);
    });

    test('un periodo sin el bloque de asistencia queda en cero, no roto', () {
      final periodo = AsistenciaPeriodoModel.fromJson({'id': 21, 'numero': 1});

      expect(periodo.totalInstitucion, 0);
      expect(periodo.totalClases, 0);
      expect(periodo.sinNada, isTrue);
    });
  });

  group('las faltas por materia que trae el boletín', () {
    final crudo = {
      'alumno_id': 31,
      'nombres': 'Dámaris',
      'periodos': [
        {
          'id': 22,
          'numero': 2,
          'asignaturas': [
            {
              'asignatura_id': 5,
              'materia': 'Matemáticas',
              'total_tardanzas': '1',
              'total_ausencias': 2,
              'ausencias': [
                {
                  'id': 700,
                  'tipo': 'tardanza',
                  'cantidad_tardanza': 1,
                  'fecha_hora': '2026-03-04 07:10:00',
                },
                {
                  'id': 701,
                  'tipo': 'ausencia',
                  'cantidad_ausencia': 1,
                  'fecha_hora': '2026-03-11 00:00:00',
                },
                {
                  'id': 702,
                  'tipo': 'ausencia',
                  'cantidad_ausencia': 1,
                  'fecha_hora': '2026-03-18 00:00:00',
                },
              ],
            },
            {
              'asignatura_id': 6,
              'materia': 'Sociales',
              'total_tardanzas': 0,
              'total_ausencias': 0,
              'ausencias': [],
            },
          ],
        },
      ],
    };

    test('se leen con su total y con el día de cada una', () {
      final boletin = NotasAlumnoModel.fromJson(crudo);
      final mate = boletin.periodos.first.asignaturas.first;

      expect(mate.tieneFaltas, isTrue);
      expect(mate.totalTardanzas, 1);
      expect(mate.totalAusencias, 2);
      expect(mate.faltas.length, 3);

      // Se separan por la columna `tipo`, que es lo único que las distingue
      // dentro de la misma lista.
      expect(mate.faltasDe(TipoFalta.tardanza).length, 1);
      expect(mate.faltasDe(TipoFalta.ausencia).length, 2);
    });

    test('las de un tipo salen de la más reciente a la más vieja', () {
      final boletin = NotasAlumnoModel.fromJson(crudo);
      final ausencias =
          boletin.periodos.first.asignaturas.first.faltasDe(TipoFalta.ausencia);

      expect(ausencias.first.fecha, DateTime(2026, 3, 18));
      expect(ausencias.last.fecha, DateTime(2026, 3, 11));
    });

    test('una materia sin faltas no dice que las tiene', () {
      final boletin = NotasAlumnoModel.fromJson(crudo);
      final sociales = boletin.periodos.first.asignaturas.last;

      expect(sociales.tieneFaltas, isFalse);
      expect(sociales.faltas, isEmpty);
    });

    test('un boletín viejo, sin la clave de faltas, no revienta', () {
      final asignatura = AsignaturaNotaModel.fromJson({
        'asignatura_id': 5,
        'materia': 'Matemáticas',
        'nota_asignatura': 87,
      });

      expect(asignatura.faltas, isEmpty);
      expect(asignatura.tieneFaltas, isFalse);
    });
  });

  group('las faltas que no dicen de qué día son', () {
    // Once de cada cien filas de ausencias no traen fecha_hora: se comprobó
    // contra la base del colegio, 5.068 de 46.457. Vienen de la planilla web.
    final asignatura = AsignaturaNotaModel.fromJson({
      'asignatura_id': 5,
      'materia': 'Ciencias Naturales',
      'total_ausencias': 3,
      'ausencias': [
        {'id': 1, 'tipo': 'ausencia', 'fecha_hora': null},
        {'id': 2, 'tipo': 'ausencia', 'fecha_hora': '2026-03-11 00:00:00'},
        {'id': 3, 'tipo': 'ausencia', 'fecha_hora': null},
      ],
    });

    test('se cuentan, porque pasaron', () {
      expect(asignatura.totalAusencias, 3);
      expect(asignatura.faltasDe(TipoFalta.ausencia).length, 3);
    });

    test('pero no se listan como día', () {
      final conDia = asignatura.faltasConDiaDe(TipoFalta.ausencia);

      expect(conDia.length, 1);
      expect(conDia.single.fecha, DateTime(2026, 3, 11));
    });

    test('y se dice cuántas son, para que no parezca que falta algo', () {
      expect(asignatura.faltasSinDia, 2);
    });
  });
}
