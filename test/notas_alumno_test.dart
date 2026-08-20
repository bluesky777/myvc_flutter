import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';

void main() {
  group('el boletín de un alumno', () {
    final crudo = {
      'alumno_id': '31',
      'nombres': 'Dámaris',
      'apellidos': 'Gómez Pico',
      'foto_nombre': 'user_2/damaris.jpg',
      'grupo_id': '9',
      'nombre_grupo': 'Séptimo A',
      'abrev_grupo': '7A',
      'titular_id': '4',
      'pazysalvo': 1,
      'deuda': '150000',
      'periodos': [
        {
          'id': 22,
          'numero': 2,
          'asignaturas': [
            {
              'asignatura_id': 5,
              'materia': 'Matemáticas',
              'alias_materia': 'Mate',
              'area_nombre': 'Ciencias',
              'profesor_id': 4,
              'nombres_profesor': 'Ariolfo',
              'apellidos_profesor': 'Gómez',
              'foto_nombre': 'user_2/ariolfo.jpg',
              'nota_asignatura': '87',
              'desempenio': 'Alto',
              'recuperada': 0,
            },
          ],
        },
        {'id': 21, 'numero': 1, 'asignaturas': []},
      ],
    };

    test('se lee con su grupo y su titular', () {
      final boletin = NotasAlumnoModel.fromJson(crudo);

      expect(boletin.alumnoId, 31);
      expect(boletin.nombreCompleto, 'Dámaris Gómez Pico');
      expect(boletin.grupo, 'Séptimo A');
      // El nombre del titular no viene: solo su id. Se resuelve aparte.
      expect(boletin.titularId, 4);
      expect(boletin.pazYSalvo, isTrue);
    });

    test('los periodos salen ordenados por número', () {
      final boletin = NotasAlumnoModel.fromJson(crudo);

      expect(boletin.periodos.map((p) => p.numero), [1, 2]);
    });

    test('la asignatura trae al docente y su foto', () {
      final boletin = NotasAlumnoModel.fromJson(crudo);
      final mate = boletin.periodos.last.asignaturas.first;

      expect(mate.materia, 'Matemáticas');
      expect(mate.docente, 'Ariolfo Gómez');
      expect(mate.fotoDocente, 'user_2/ariolfo.jpg');
      expect(mate.nota, 87);
      expect(mate.desempenio, 'Alto');
    });
  });

  group('cómo se escribe una nota', () {
    AsignaturaNotaModel con(dynamic nota) => AsignaturaNotaModel.fromJson({
          'asignatura_id': 1,
          'materia': 'X',
          'nota_asignatura': nota,
        });

    test('sin decimales cuando es redonda', () {
      expect(con(87).notaEscrita, '87');
      expect(con('87.0').notaEscrita, '87');
    });

    test('con un decimal cuando lo tiene', () {
      expect(con('87.5').notaEscrita, '87.5');
    });

    test('una coma decimal también se entiende', () {
      // Según cómo lo serialice el servidor puede llegar con coma.
      expect(con('87,5').notaEscrita, '87.5');
    });

    test('sin nota se pone una raya, no un cero', () {
      // Un cero es una nota; «sin poner» no lo es, y confundirlos asusta a
      // quien mira.
      final sinNota = con(null);
      expect(sinNota.tieneNota, isFalse);
      expect(sinNota.notaEscrita, '—');
    });
  });

  group('el promedio del periodo', () {
    test('solo cuenta lo que ya tiene nota', () {
      final periodo = PeriodoNotasModel.fromJson({
        'id': 1,
        'numero': 1,
        'asignaturas': [
          {'asignatura_id': 1, 'materia': 'A', 'nota_asignatura': 80},
          {'asignatura_id': 2, 'materia': 'B', 'nota_asignatura': 90},
          {'asignatura_id': 3, 'materia': 'C', 'nota_asignatura': null},
        ],
      });

      expect(periodo.promedio, 85);
    });

    test('sin ninguna nota no hay promedio que dar', () {
      final periodo = PeriodoNotasModel.fromJson({
        'id': 1,
        'numero': 1,
        'asignaturas': [
          {'asignatura_id': 1, 'materia': 'A', 'nota_asignatura': null},
        ],
      });

      expect(periodo.promedio, isNull);
    });
  });
}
