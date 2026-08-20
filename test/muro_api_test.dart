import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';

void main() {
  group('los acudidos de un acudiente', () {
    test('se leen con su grupo y su paz y salvo', () {
      final acudido = AcudidoModel.fromJson({
        'alumno_id': '31',
        'nombres': 'Dámaris',
        'apellidos': 'Gómez Pico',
        'foto_nombre': 'user_2/damaris.jpg',
        'grupo_nombre': 'Séptimo A',
        'grupo_abrev': '7A',
        'pazysalvo': 0,
      });

      expect(acudido.alumnoId, 31);
      expect(acudido.nombreCompleto, 'Dámaris Gómez Pico');
      expect(acudido.grupoAbrev, '7A');
      expect(acudido.pazYSalvo, isFalse);
    });

    test('el grupo se lee como lo nombra el panel', () {
      // La consulta de acudidos de ChangesAsked/to-me devuelve `nombre_grupo`,
      // no `grupo_nombre`: leyendo solo el segundo, el grupo era null siempre.
      final acudido = AcudidoModel.fromJson({
        'alumno_id': 31,
        'nombres': 'Dámaris',
        'nombre_grupo': 'Séptimo A',
      });

      expect(acudido.grupo, 'Séptimo A');
    });

    test('sin el dato de tesorería se asume que está a paz y salvo', () {
      // Es lo que hace el front: el aviso rojo solo sale cuando llega un 0.
      final acudido = AcudidoModel.fromJson({'alumno_id': 4, 'nombres': 'X'});

      expect(acudido.pazYSalvo, isTrue);
    });
  });
}
