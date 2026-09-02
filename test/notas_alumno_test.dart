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

    test('con decimales se pinta entera, como el boletín', () {
      // Desde que la definitiva es DECIMAL(7,4) puede valer 43,75, y el papel
      // que se firma imprime la nota de una materia entera. Antes esto daba
      // «87.5», cuando el decimal no podía llegar.
      expect(con('87.5').notaEscrita, '88');
      expect(con('43.75').notaEscrita, '44');
      expect(con('43.2').notaEscrita, '43');
    });

    test('una coma decimal también se entiende', () {
      // Según cómo lo serialice el servidor puede llegar con coma.
      expect(con('87,5').notaEscrita, '88');
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
    test('divide entre todas, y la que no tiene nota baja el promedio', () {
      // Como el boletín, que es el papel que se firma: 80 + 90 + 0 entre TRES.
      // Promediando sólo las que tienen nota daría 85, y ese era el número de
      // antes. Decisión de Joseth del 28 ago 2026.
      final periodo = PeriodoNotasModel.fromJson({
        'id': 1,
        'numero': 1,
        'asignaturas': [
          {'asignatura_id': 1, 'materia': 'A', 'nota_asignatura': 80},
          {'asignatura_id': 2, 'materia': 'B', 'nota_asignatura': 90},
          {'asignatura_id': 3, 'materia': 'C', 'nota_asignatura': null},
        ],
      });

      expect(periodo.promedio, closeTo(56.67, 0.01));
    });

    test('la asignatura sin definitiva cuenta igual que un cero', () {
      // Es el caso que trajo la decisión: el servidor dejó de sembrar la
      // definitiva inventada, así que donde antes llegaba un 0 ahora llega
      // null. El promedio no puede cambiar por eso.
      Map<String, dynamic> conNota(dynamic nota) => {
            'id': 1,
            'numero': 1,
            'asignaturas': [
              {'asignatura_id': 1, 'materia': 'A', 'nota_asignatura': 90},
              {'asignatura_id': 2, 'materia': 'B', 'nota_asignatura': nota},
            ],
          };

      expect(
        PeriodoNotasModel.fromJson(conNota(null)).promedio,
        PeriodoNotasModel.fromJson(conNota(0)).promedio,
      );
      expect(PeriodoNotasModel.fromJson(conNota(null)).promedio, 45);
    });

    test('sin ninguna nota el promedio es cero, no «no hay»', () {
      final periodo = PeriodoNotasModel.fromJson({
        'id': 1,
        'numero': 1,
        'asignaturas': [
          {'asignatura_id': 1, 'materia': 'A', 'nota_asignatura': null},
        ],
      });

      expect(periodo.promedio, 0);
    });

    test('sin asignaturas no hay promedio que dar', () {
      // Distinto de lo anterior: aquí no hay nada que promediar, y eso no es
      // promediar ceros. Es el único null que queda.
      final periodo = PeriodoNotasModel.fromJson({
        'id': 1,
        'numero': 1,
        'asignaturas': [],
      });

      expect(periodo.promedio, isNull);
    });
  });
}
