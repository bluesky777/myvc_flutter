import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// La fecha de la falta es el día en que el alumno no entró, y viaja al backend
/// en la columna fecha_hora. Aquí se fija su formato y la regla de la hora.
void main() {
  test('el formato es el datetime de MySQL, sin la T de ISO', () {
    expect(
      fechaHoraParaServidor(DateTime(2026, 3, 7, 9, 5, 4)),
      '2026-03-07 09:05:04',
    );
  });

  test('la falta de hoy lleva la hora real', () {
    final ahora = DateTime(2026, 8, 19, 7, 42, 13);

    expect(
      faltaDelDiaParaServidor(DateTime(2026, 8, 19), ahora: ahora),
      '2026-08-19 07:42:13',
    );
  });

  test('la falta de un día pasado va a las 00:00, que es lo que se sabe', () {
    final ahora = DateTime(2026, 8, 19, 7, 42, 13);

    expect(
      faltaDelDiaParaServidor(DateTime(2026, 8, 12), ahora: ahora),
      '2026-08-12 00:00:00',
    );
  });

  test('la hora del día elegido no se cuela cuando no es hoy', () {
    final ahora = DateTime(2026, 8, 19, 7, 42, 13);

    // El date picker devuelve el día con la hora de cuando se abrió.
    expect(
      faltaDelDiaParaServidor(DateTime(2026, 8, 12, 23, 30), ahora: ahora),
      '2026-08-12 00:00:00',
    );
  });

  test('el mismo día se compara sin mirar la hora', () {
    expect(
      esElMismoDia(DateTime(2026, 8, 19, 0, 1), DateTime(2026, 8, 19, 23, 59)),
      isTrue,
    );
    expect(
      esElMismoDia(DateTime(2026, 8, 19, 23, 59), DateTime(2026, 8, 20, 0, 1)),
      isFalse,
    );
  });

  test('el día se lee dd/mm/aaaa, y sin fecha queda una raya', () {
    expect(formatoDia(DateTime(2026, 1, 5)), '05/01/2026');
    expect(formatoDia(null), '—');
  });

  test('el día con hora se lee en el reloj de doce', () {
    expect(
        formatoDiaYHora(DateTime(2026, 1, 5, 7, 4)), '05/01/2026 - 7:04 a. m.');
    expect(formatoDiaYHora(DateTime(2026, 8, 19, 19, 34)),
        '19/08/2026 - 7:34 p. m.');
    expect(formatoDiaYHora(null), '—');
  });

  group('la hora en el reloj de doce', () {
    test('la mañana es a. m. y la tarde p. m.', () {
      expect(formatoHora12(DateTime(2026, 8, 19, 7, 5)), '7:05 a. m.');
      expect(formatoHora12(DateTime(2026, 8, 19, 15, 40)), '3:40 p. m.');
    });

    test('las doce de la noche y las doce del día no se confunden', () {
      // Es donde falla el módulo a secas: las dos caerían en 0.
      expect(formatoHora12(DateTime(2026, 8, 19, 0, 0)), '12:00 a. m.');
      expect(formatoHora12(DateTime(2026, 8, 19, 12, 0)), '12:00 p. m.');
    });

    test('y de vuelta a las 24 del servidor', () {
      expect(hora24DesdeDoce(hora12: 12, esTarde: false), 0);
      expect(hora24DesdeDoce(hora12: 12, esTarde: true), 12);
      expect(hora24DesdeDoce(hora12: 7, esTarde: false), 7);
      expect(hora24DesdeDoce(hora12: 7, esTarde: true), 19);
    });

    test('lo que va al servidor sigue en 24 horas', () {
      // La columna datetime de MySQL no entiende de a. m. ni p. m.
      expect(
        fechaHoraParaServidor(DateTime(2026, 8, 19, 19, 34, 5)),
        '2026-08-19 19:34:05',
      );
    });
  });

  test('la hora que guardó el backend se lee tal cual, sin correrla', () {
    // created_at llega con una Z al final, así que Dart la lee como UTC. El
    // backend guardó ahí la hora de Bogotá: pasarla a local la correría cinco
    // horas y la falta parecería registrada por la tarde en vez de por la
    // mañana.
    final registrada = DateTime.parse('2026-08-19T07:34:49.000000Z');

    expect(formatoDiaYHora(registrada), '19/08/2026 - 7:34 a. m.');
  });

  _pruebasDelMuro();
}

void _pruebasDelMuro() {
  group('cuánto hace que se publicó', () {
    final ahora = DateTime(2026, 8, 19, 19, 30);

    test('lo de hace un instante', () {
      expect(hace(DateTime(2026, 8, 19, 19, 30), ahora: ahora), 'ahora mismo');
      expect(hace(DateTime(2026, 8, 19, 19, 29, 30), ahora: ahora),
          'ahora mismo');
    });

    test('minutos y horas, en singular cuando toca', () {
      expect(hace(DateTime(2026, 8, 19, 19, 29), ahora: ahora), 'hace 1 minuto');
      expect(hace(DateTime(2026, 8, 19, 19, 10), ahora: ahora),
          'hace 20 minutos');
      expect(hace(DateTime(2026, 8, 19, 18, 30), ahora: ahora), 'hace 1 hora');
      expect(hace(DateTime(2026, 8, 19, 14, 30), ahora: ahora), 'hace 5 horas');
    });

    test('ayer se dice ayer', () {
      expect(hace(DateTime(2026, 8, 18, 19, 0), ahora: ahora), 'ayer');
    });

    test('pasada la semana ya se pone la fecha', () {
      expect(hace(DateTime(2026, 8, 15), ahora: ahora), 'hace 4 días');
      expect(hace(DateTime(2026, 8, 1), ahora: ahora), '01/08/2026');
    });

    test('una fecha futura es un reloj mal puesto, no un error en pantalla', () {
      expect(hace(DateTime(2026, 8, 20), ahora: ahora), 'ahora mismo');
    });

    test('sin fecha no se inventa nada', () {
      expect(hace(null), '');
    });
  });
}
