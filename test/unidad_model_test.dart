import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';

void main() {
  group('una unidad del resumen de /asignaturas/listasignaturas', () {
    // Ahí cada unidad viene con sus subunidades y con cuántas notas lleva
    // puesta cada una, pero sin nota_default.
    final crudo = {
      'id': 12,
      'definicion': 'Trabajo en clase',
      'porcentaje': '40',
      'orden': 0,
      'porc_subunidades': 100,
      'subunidades': [
        {
          'id': 90,
          'definicion': 'Taller 1',
          'porcentaje': '60',
          'orden': 1,
          'cantNotas': 32,
        },
        {
          'id': 91,
          'definicion': 'Taller 2',
          'porcentaje': 40,
          'orden': 0,
          'cantNotas': 0,
        },
      ],
    };

    test('se lee con sus subunidades, ordenadas', () {
      final unidad = UnidadModel.fromJson(crudo);

      expect(unidad.id, 12);
      expect(unidad.definicion, 'Trabajo en clase');
      expect(unidad.porcentaje, 40);
      expect(unidad.subunidades.length, 2);
      // Por `orden`, no por como vengan.
      expect(unidad.subunidades.first.definicion, 'Taller 2');
    });

    test('sus subunidades cuadran cuando suman cien', () {
      final unidad = UnidadModel.fromJson(crudo);

      expect(unidad.porcentajeSubunidades, 100);
      expect(unidad.subunidadesCuadran, isTrue);
    });

    test('una unidad sin subunidades no cuadra: ahí no se pone ninguna nota',
        () {
      final unidad = UnidadModel.fromJson({
        'id': 13,
        'definicion': 'Vacía',
        'porcentaje': 60,
        'subunidades': [],
      });

      expect(unidad.subunidades, isEmpty);
      expect(unidad.subunidadesCuadran, isFalse);
    });

    test('tres tercios de 33,33 se dan por buenos', () {
      final unidad = UnidadModel.fromJson({
        'id': 14,
        'definicion': 'Tercios',
        'porcentaje': 100,
        'subunidades': [
          {'id': 1, 'porcentaje': '33.33', 'definicion': 'A'},
          {'id': 2, 'porcentaje': '33.33', 'definicion': 'B'},
          {'id': 3, 'porcentaje': '33.33', 'definicion': 'C'},
        ],
      });

      expect(unidad.subunidadesCuadran, isTrue,
          reason: 'suman 99,99 y eso es cien repartido en tres');
    });

    test('cuántas notas lleva cada subunidad se conserva', () {
      final unidad = UnidadModel.fromJson(crudo);
      final taller1 = unidad.subunidades.last;

      expect(taller1.definicion, 'Taller 1');
      expect(taller1.cantNotas, 32);
      expect(unidad.subunidades.first.cantNotas, 0);
    });
  });

  group('una unidad del detalle de /unidades/de-asignatura-periodo', () {
    // El detalle es un SELECT *: trae nota_default, que es lo que falta para
    // poder guardar, y no trae cantNotas.
    final crudo = {
      'id': 12,
      'definicion': 'Trabajo en clase',
      'porcentaje': 40,
      'periodo_id': 22,
      'asignatura_id': 1327,
      'orden': 0,
      'subunidades': [
        {
          'id': 90,
          'unidad_id': 12,
          'definicion': 'Taller 1',
          'porcentaje': 100,
          'nota_default': '70',
          'orden': 0,
        },
      ],
    };

    test('trae la nota por defecto de cada subunidad', () {
      final unidad = UnidadModel.fromJson(crudo);

      expect(unidad.asignaturaId, 1327);
      expect(unidad.periodoId, 22);
      expect(unidad.subunidades.first.notaDefault, 70);
      expect(unidad.subunidades.first.unidadId, 12);
    });

    test('sin cantNotas queda en null, que no es lo mismo que cero', () {
      final unidad = UnidadModel.fromJson(crudo);

      expect(unidad.subunidades.first.cantNotas, isNull,
          reason: 'null es «no se sabe»; cero sería «no tiene ninguna»');
    });

    test('se le puede pegar el recuento de notas del resumen', () {
      final unidad = UnidadModel.fromJson(crudo, notasPorSubunidad: {90: 32});

      expect(unidad.subunidades.first.cantNotas, 32);
    });
  });

  group('los porcentajes escritos', () {
    test('sin decimales cuando son redondos', () {
      expect(porcentajeEscrito(40), '40%');
      expect(porcentajeEscrito(33.3), '33.3%');
    });

    test('lo que no es número cuenta como cero', () {
      expect(decimalO(null), 0);
      expect(decimalO('33,33'), 33.33);
      expect(decimalO('nada'), 0);
    });
  });

  group('el orden que se manda al backend', () {
    test('es una lista de {id: posición}, como espera sortHash', () {
      expect(sortHashDe([12, 13, 14]), [
        {'12': 0},
        {'13': 1},
        {'14': 2},
      ]);
    });

    test('se mandan todas, no solo las que se movieron', () {
      // El orden guardado tiene que ser exactamente el que se está viendo: en
      // la base venía con huecos y con números repetidos.
      final orden = sortHashDe([13, 12]);

      expect(orden.length, 2);
      expect(orden.first, {'13': 0});
      expect(orden.last, {'12': 1});
    });
  });

  group('lo que hay en la papelera', () {
    test('una subunidad borrada se lee con la unidad de la que colgaba', () {
      // Otra consulta y otros nombres de columna: definicion_subunidad y
      // definicion_unidad, no definicion.
      final borrada = SubunidadBorrada.fromJson({
        'id': '90',
        'definicion_subunidad': 'Taller 1',
        'porcentaje': '60',
        'definicion_unidad': 'Trabajo en clase',
      });

      expect(borrada.id, 90);
      expect(borrada.definicion, 'Taller 1');
      expect(borrada.porcentaje, 60);
      expect(borrada.unidad, 'Trabajo en clase');
    });

    test('una papelera sin nada lo dice', () {
      expect(PapeleraUnidades().vacia, isTrue);
      expect(PapeleraUnidades().cuantas, 0);
    });

    test('cuenta los dos niveles juntos', () {
      final papelera = PapeleraUnidades(
        unidades: [UnidadModel(id: 1, definicion: 'X', porcentaje: 20)],
        subunidades: [
          SubunidadBorrada(
              id: 90, definicion: 'Y', porcentaje: 50, unidad: 'X'),
        ],
      );

      expect(papelera.vacia, isFalse);
      expect(papelera.cuantas, 2);
    });
  });
}
