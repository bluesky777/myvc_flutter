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
}
