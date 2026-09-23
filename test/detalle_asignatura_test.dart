import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';

/// Una asignatura con el desglose tal como lo manda `notas/alumno`.
Map<String, dynamic> conDesglose() => jsonDecode(jsonEncode({
      'asignatura_id': 12,
      'materia': 'Matemáticas',
      'nota_asignatura': 45,
      'unidades': [
        {
          'unidad_id': 7,
          'definicion_unidad': 'Resuelve ecuaciones',
          'porcentaje_unidad': 60,
          'orden_unidad': 2,
          'subunidades': [
            {
              'subunidad_id': 71,
              'definicion_subunidad': 'Taller en clase',
              'orden_subunidad': 2,
              'nota': {'id': 900, 'nota': 48, 'desempenio': 'Alto'},
            },
            {
              'subunidad_id': 70,
              'definicion_subunidad': 'Quiz',
              'orden_subunidad': 1,
              'nota': null,
            },
          ],
        },
        {
          'unidad_id': 6,
          'definicion_unidad': 'Interpreta gráficas',
          'orden_unidad': 1,
          'subunidades': [],
        },
      ],
    })) as Map<String, dynamic>;

void main() {
  group('el desglose de una asignatura', () {
    test('se lee de la respuesta que la app ya descargaba', () {
      // Venía llegando desde el primer día y el parser lo tiraba: leía
      // `nota_asignatura` y nunca tocaba `unidades`.
      final a = AsignaturaNotaModel.fromJson(conDesglose());

      expect(a.unidades, hasLength(2));
      // `.last` y no `.first`: vienen ordenadas por `orden_unidad`, y la que
      // el docente puso primera es la que no tiene subunidades.
      expect(a.unidades.last.subunidades, hasLength(2));
    });

    test('unidades y subunidades salen en el orden del docente', () {
      // El backend no las devuelve ordenadas; el orden lo lleva cada fila.
      final a = AsignaturaNotaModel.fromJson(conDesglose());

      expect(a.unidades.map((u) => u.definicion),
          ['Interpreta gráficas', 'Resuelve ecuaciones']);
      expect(a.unidades.last.subunidades.map((s) => s.definicion),
          ['Quiz', 'Taller en clase']);
    });

    test('sin calificar NO es cero', () {
      // Lo único que esta pantalla no puede equivocar: un cero donde nadie ha
      // corregido le dice a una familia que su hijo perdió algo que ni
      // siquiera se ha revisado.
      final a = AsignaturaNotaModel.fromJson(conDesglose());
      final subs = a.unidades.last.subunidades;

      expect(subs.first.nota, isNull);
      expect(subs.first.tieneNota, isFalse);
      expect(subs.last.nota, 48);
      expect(subs.last.desempenio, 'Alto');
    });

    test('cuenta las notas puestas, que es lo que dice el aviso', () {
      // El push dice «hay N notas nuevas»; esto es lo que hay que poder
      // enseñar al tocarlo.
      final a = AsignaturaNotaModel.fromJson(conDesglose());

      expect(a.cuantasNotas, 1);
      expect(a.hayDesglose, isTrue);
    });

    test('una asignatura sin unidades no revienta ni finge tener desglose', () {
      // El docente no montó nada ese periodo. Es un caso normal, no un error.
      final a = AsignaturaNotaModel.fromJson({
        'asignatura_id': 12,
        'materia': 'Matemáticas',
      });

      expect(a.unidades, isEmpty);
      expect(a.hayDesglose, isFalse);
      expect(a.cuantasNotas, 0);
    });

    test('una unidad con cero subunidades no cuenta como desglose', () {
      // Se pinta con su «sin … todavía», pero la pantalla entera no puede
      // presentarse como si tuviera algo que enseñar.
      final a = AsignaturaNotaModel.fromJson({
        'asignatura_id': 12,
        'materia': 'Matemáticas',
        'unidades': [
          {'unidad_id': 6, 'definicion_unidad': 'Vacía', 'subunidades': []},
        ],
      });

      expect(a.unidades, hasLength(1));
      expect(a.hayDesglose, isFalse);
    });
  });
}
