import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

void main() {
  final contexto = ContextoAcademico.instancia;

  setUp(contexto.limpiar);

  group('lo que se lee en la barra', () {
    test('el año y el periodo, cuando hay los dos', () {
      contexto.tomarDelLogin({
        'year_id': 6,
        'year': '2026',
        'periodo_id': 21,
        'numero_periodo': 3,
      });

      expect(contexto.titulo, '2026 · Periodo 3');
      expect(contexto.hayContexto, isTrue);
    });

    test('los números llegan a veces como cadenas', () {
      // Vienen de SQL a pelo, como el resto: el driver decide el tipo.
      contexto.tomarDelLogin({
        'year_id': '6',
        'year': '2026',
        'periodo_id': '21',
        'numero_periodo': '3',
      });

      expect(contexto.yearId, 6);
      expect(contexto.periodoId, 21);
      expect(contexto.titulo, '2026 · Periodo 3');
    });

    test('sin periodo se dice, no se deja en blanco', () {
      contexto.tomarDelLogin({'year_id': 6, 'year': '2026'});

      expect(contexto.titulo, '2026');
      expect(contexto.hayContexto, isFalse);
    });

    test('sin nada tampoco se inventa un año', () {
      expect(contexto.titulo, 'Sin periodo');
    });
  });

  group('cerrar sesión', () {
    test('se lleva el periodo del que se va', () {
      // Igual que el token: el contexto del docente anterior no puede quedarse
      // puesto para el siguiente.
      contexto.tomarDelLogin({
        'year_id': 6,
        'year': '2026',
        'periodo_id': 21,
        'numero_periodo': 3,
      });

      contexto.limpiar();

      expect(contexto.hayContexto, isFalse);
      expect(contexto.year, isNull);
      expect(contexto.years, isEmpty);
    });
  });

  group('avisa a quien escuche', () {
    test('cuando entra un contexto nuevo', () {
      var avisos = 0;
      void escucha() => avisos++;

      contexto.addListener(escucha);
      contexto.tomarDelLogin({'year_id': 6, 'year': '2026'});
      contexto.removeListener(escucha);

      expect(avisos, 1);
    });
  });
}
