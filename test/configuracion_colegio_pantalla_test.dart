import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';

YearDelColegio yearDePrueba([Map<String, dynamic> extra = const {}]) {
  return YearDelColegio.fromJson({
    'id': 7,
    'year': '2026',
    'nombre_colegio': 'Mi Cole Virtual',
    'actual': 1,
    'nota_minima_aceptada': '60',
    'alumnos_can_see_notas': 1,
    'solo_escalas_valorativas': 0,
    'show_materias_todas': 0,
    'unidad_displayname': 'Logro',
    'subunidad_displayname': 'Indicador',
    'periodos': [
      {
        'id': 22,
        'numero': 2,
        'actual': 1,
        'fecha_inicio': '2026-04-01',
        'fecha_fin': '2026-06-15',
        'profes_pueden_editar_notas': 0,
        'profes_pueden_nivelar': 1,
      },
      {
        'id': 11,
        'numero': 1,
        'actual': 0,
        'profes_pueden_editar_notas': 1,
        'profes_pueden_nivelar': 1,
      },
    ],
    'escalas': [
      {
        'id': 1,
        'desempenio': 'BAJO',
        'porc_inicial': 0,
        'porc_final': '59',
        'perdido': 1,
      },
      {
        'id': 2,
        'desempenio': 'SUPERIOR',
        'porc_inicial': 91,
        'porc_final': 100,
        'perdido': 0,
      },
    ],
    ...extra,
  });
}

void main() {
  group('leer la configuración del colegio', () {
    test('los periodos salen en orden y las escalas de mayor a menor', () {
      final year = yearDePrueba();

      expect(year.periodos.map((p) => p.numero), [1, 2]);
      // Una escala se lee de arriba abajo, y así la imprime el boletín.
      expect(year.escalas.map((e) => e.desempenio), ['SUPERIOR', 'BAJO']);
    });

    test('los 0/1 llegan como número o como cadena, según el driver', () {
      final year = yearDePrueba({'alumnos_can_see_notas': '0'});

      expect(year.alumnosPuedenVerNotas, isFalse);
      expect(year.notaMinimaAceptada, 60);
      expect(year.escalas.first.porcFinal, 100);
    });

    test('lo que no viene no es un «no», y un año pelado no revienta', () {
      // Para un año viejo puede faltar la columna entera, y suponer que no se
      // puede haría que la pantalla mintiera sobre el colegio.
      final year = YearDelColegio.fromJson({'id': 1, 'year': '2020'});

      expect(year.alumnosPuedenVerNotas, isTrue);
      expect(year.alumnosVenNumeros, isTrue);
      expect(year.periodos, isEmpty);
      expect(year.escalas, isEmpty);
      expect(year.unidad, 'Unidad');
    });

    test('un periodo sin sus banderas se supone abierto', () {
      final year = yearDePrueba({
        'periodos': [
          {'id': 5, 'numero': 1},
        ],
      });

      expect(year.periodos.single.puedenEditarNotas, isTrue);
      expect(year.periodos.single.puedenNivelar, isTrue);
      expect(year.periodos.single.inicio, isNull);
    });

    test('los nombres del colegio ganan a los de por defecto', () {
      final year = yearDePrueba();

      expect(year.unidad, 'Logro');
      expect(year.subunidad, 'Indicador');
    });

    test('un nombre vacío no borra el de por defecto', () {
      final year = yearDePrueba({'unidad_displayname': '   '});

      expect(year.unidad, 'Unidad');
    });

    test('la escala dice su rango como se lee', () {
      expect(yearDePrueba().escalas.first.rango, '91 a 100');
      expect(yearDePrueba().escalas.last.perdido, isTrue);
    });
  });

  group('la columna que dice lo contrario que el interruptor', () {
    test('«solo escalas valorativas» en 1 es «no ven números»', () {
      // El backend guarda si se OCULTAN los números; la pantalla pregunta si se
      // VEN, que es como se piensa el ajuste. La vuelta se da una sola vez, al
      // leer, y tiene esta prueba para que nadie la «arregle».
      expect(yearDePrueba({'solo_escalas_valorativas': 1}).alumnosVenNumeros,
          isFalse);
      expect(yearDePrueba({'solo_escalas_valorativas': 0}).alumnosVenNumeros,
          isTrue);
    });
  });

  group('mover un ajuste sin volver a pedir el colegio', () {
    test('el interruptor cambiado deja lo demás como estaba', () {
      final year = yearDePrueba();
      final despues = year.copiaCon(alumnosPuedenVerNotas: false);

      expect(despues.alumnosPuedenVerNotas, isFalse);
      expect(despues.alumnosVenNumeros, year.alumnosVenNumeros);
      expect(despues.periodos.length, 2);
      expect(despues.escalas.length, 2);
      // Y el de antes no cambia.
      expect(year.alumnosPuedenVerNotas, isTrue);
    });

    test('cambiar un periodo cambia solo ese', () {
      final year = yearDePrueba();
      final periodo1 = year.periodos.firstWhere((p) => p.numero == 1);

      final despues = year.cambiandoPeriodo(
        periodo1.id,
        (p) => p.copiaCon(puedenEditarNotas: false),
      );

      expect(
        despues.periodos.firstWhere((p) => p.numero == 1).puedenEditarNotas,
        isFalse,
      );
      expect(
        despues.periodos.firstWhere((p) => p.numero == 2).puedenNivelar,
        isTrue,
      );
    });

    test('dos interruptores del mismo periodo a la vez no se pisan', () {
      // Se pueden tocar los dos mientras el primero sigue en vuelo. Con un
      // periodo capturado antes de la petición, el segundo en responder
      // escribiría encima con los valores de antes.
      final year = yearDePrueba();
      final periodo1 = year.periodos.firstWhere((p) => p.numero == 1);

      final tras1 = year.cambiandoPeriodo(
        periodo1.id,
        (p) => p.copiaCon(puedenEditarNotas: false),
      );
      final tras2 = tras1.cambiandoPeriodo(
        periodo1.id,
        (p) => p.copiaCon(puedenNivelar: false),
      );

      final quedo = tras2.periodos.firstWhere((p) => p.numero == 1);
      expect(quedo.puedenEditarNotas, isFalse);
      expect(quedo.puedenNivelar, isFalse);
    });

    test('hacer actual un periodo apaga los demás', () {
      // El backend recorre los del año poniéndolos en 0 antes de encender el
      // elegido. Si la app solo encendiera el nuevo, quedarían dos marcados.
      final year = yearDePrueba();
      expect(year.periodos.firstWhere((p) => p.numero == 2).actual, isTrue);

      final despues = year.conActual(11);

      expect(despues.periodos.firstWhere((p) => p.numero == 1).actual, isTrue);
      expect(despues.periodos.firstWhere((p) => p.numero == 2).actual, isFalse);
    });
  });
}
