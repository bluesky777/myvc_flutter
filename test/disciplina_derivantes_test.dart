import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Models/SituacionModel.dart';

void main() {
  /// Un alumno con leves sueltas en tres periodos y una grave en el segundo.
  AlumnoDisciplinaModel alumno() => AlumnoDisciplinaModel.fromJson({
        'alumno_id': 300,
        'nombres': 'Ana',
        'apellidos': 'Acosta',
        'periodo1': [
          {'id': 11, 'tipo_situacion': 1, 'periodo_numero': 1, 'descripcion': 'A'},
          {'id': 12, 'tipo_situacion': 1, 'periodo_numero': 1, 'descripcion': 'B'},
          // Esta ya cuelga de otra: no se puede volver a enganchar.
          {
            'id': 13,
            'tipo_situacion': 1,
            'periodo_numero': 1,
            'descripcion': 'C',
            'become_id': 99,
          },
        ],
        'periodo2': [
          {'id': 21, 'tipo_situacion': 1, 'periodo_numero': 2, 'descripcion': 'D'},
          {'id': 22, 'tipo_situacion': 2, 'periodo_numero': 2, 'descripcion': 'Grave'},
        ],
        'periodo3': [
          {'id': 31, 'tipo_situacion': 1, 'periodo_numero': 3, 'descripcion': 'E'},
        ],
      });

  group('de qué puede derivar una situación', () {
    test('una de tipo 2 se alimenta de las de tipo 1', () {
      final candidatas = alumno().candidatasParaDerivar(
        tipo: 2,
        periodo: 2,
        reiniciaPorPeriodo: false,
      );

      // Las leves del 1 y del 2. La 13 no, que ya cuelga de otra; la 22
      // tampoco, que es del mismo tipo que la nueva; la 31 tampoco, que es de
      // un periodo posterior.
      expect(candidatas.map((s) => s.id), [11, 12, 21]);
    });

    test('una de tipo 3 se alimenta de las de tipo 2', () {
      final candidatas = alumno().candidatasParaDerivar(
        tipo: 3,
        periodo: 4,
        reiniciaPorPeriodo: false,
      );

      expect(candidatas.map((s) => s.id), [22]);
    });

    test('una de tipo 1 no deriva de ninguna situación', () {
      // Viene de las tardanzas, que no son situaciones y no se enganchan una
      // a una: para eso está el sí o no de `deriva_de_tardanzas`.
      expect(
        alumno().candidatasParaDerivar(
            tipo: 1, periodo: 3, reiniciaPorPeriodo: false),
        isEmpty,
      );
    });

    test('con la cuenta reiniciándose cada periodo, solo valen las de ese', () {
      final candidatas = alumno().candidatasParaDerivar(
        tipo: 2,
        periodo: 2,
        reiniciaPorPeriodo: true,
      );

      expect(candidatas.map((s) => s.id), [21]);
    });

    test('nunca ofrece las de periodos que aún no han llegado', () {
      final candidatas = alumno().candidatasParaDerivar(
        tipo: 2,
        periodo: 1,
        reiniciaPorPeriodo: false,
      );

      expect(candidatas.map((s) => s.id), [11, 12]);
    });

    test('las que ya cuelgan de la que se edita sí salen', () {
      // Salen, y salen marcadas: son justo las que esa situación se llevó, y
      // si no aparecieran, editarla las soltaría sin querer.
      final conSuyas = AlumnoDisciplinaModel.fromJson({
        'alumno_id': 1,
        'periodo1': [
          {
            'id': 11,
            'tipo_situacion': 1,
            'periodo_numero': 1,
            'become_id': 500,
          },
          {'id': 12, 'tipo_situacion': 1, 'periodo_numero': 1},
          {
            'id': 13,
            'tipo_situacion': 1,
            'periodo_numero': 1,
            'become_id': 777,
          },
        ],
      });

      final candidatas = conSuyas.candidatasParaDerivar(
        tipo: 2,
        periodo: 1,
        reiniciaPorPeriodo: false,
        excluyendo: 500,
        absorbidasPor: 500,
      );

      expect(candidatas.map((s) => s.id), [11, 12]);
    });
  });

  group('las que cuelgan de una situación', () {
    test('se encuentran mirando todo el año', () {
      final conCadena = AlumnoDisciplinaModel.fromJson({
        'alumno_id': 1,
        'periodo1': [
          {'id': 11, 'tipo_situacion': 1, 'become_id': 500},
          {'id': 12, 'tipo_situacion': 1},
        ],
        'periodo2': [
          {'id': 21, 'tipo_situacion': 1, 'become_id': 500},
          {'id': 500, 'tipo_situacion': 2},
        ],
      });

      expect(conCadena.absorbidasPor(500).map((s) => s.id), [11, 21]);
      expect(conCadena.absorbidasPor(999), isEmpty);
    });
  });

  group('lo que se le manda al backend para enganchar y soltar', () {
    test('engancha con la clave puesta y suelta con el id a secas', () {
      final cuerpo = dependenciasParaElBackend([11, 12], [21]);

      expect(cuerpo, [
        {'id': 11, 'asignado': true},
        {'id': 12, 'asignado': true},
        {'id': 21},
      ]);
    });

    test('la que se suelta NO lleva la clave, ni siquiera en falso', () {
      // El backend mira `array_key_exists('asignado', ...)`, no lo que valga:
      // con la clave puesta engancha. Mandar `asignado: false` para soltar
      // haría justo lo contrario, y `asignado: null` también, porque en PHP
      // una clave con null existe igual.
      final soltada = dependenciasParaElBackend(const [], [21]).single;

      expect(soltada.containsKey('asignado'), isFalse);
      expect(soltada, {'id': 21});
    });

    test('sin cambios va vacío, no nulo', () {
      // Vacío tiene que llegar igual: el update hace count() sobre esto sin
      // comprobar que sea un array, y en PHP 8.3 count(null) es un 500.
      expect(dependenciasParaElBackend(const [], const []), isEmpty);
    });
  });

  group('el sí o no de las tardanzas', () {
    test('se lee de deriva_de_tardanzas', () {
      final porTardanzas = SituacionModel.fromJson({
        'id': 1,
        'tipo_situacion': 1,
        'deriva_de_tardanzas': 1,
      });
      final normal = SituacionModel.fromJson({'id': 2, 'tipo_situacion': 1});

      expect(porTardanzas.derivaDeTardanzas, isTrue);
      expect(normal.derivaDeTardanzas, isFalse);
    });
  });
}
