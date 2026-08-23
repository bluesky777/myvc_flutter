import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';

void main() {
  final horario = HorarioDeHoy.instancia;

  AsignaturaConUnidades clase(int id, String abrev) {
    return AsignaturaConUnidades(
      asignatura: AsignaturaModel.fromJson({
        'asignatura_id': id,
        'grupo_id': 3,
        'materia': 'Matemáticas',
        'abrev_grupo': abrev,
      }),
    );
  }

  setUp(horario.limpiar);

  test('mientras no se lea el muro no se sabe nada', () {
    // No saberlo no es lo mismo que no haber clases: con lo primero el filtro
    // no se ofrece, y con lo segundo se ofrece y se explica.
    expect(horario.seSabe, isFalse);
    expect(horario.clases, isEmpty);
  });

  test('sin clases hoy sí se sabe, y son cero', () {
    horario.tomar(const []);

    expect(horario.seSabe, isTrue);
    expect(horario.cuantas, 0);
    expect(horario.asignaturaIds, isEmpty);
  });

  test('con clases se guardan sus ids, que es con lo que se filtra', () {
    horario.tomar([clase(12, '3B'), clase(19, '4A')]);

    expect(horario.seSabe, isTrue);
    expect(horario.cuantas, 2);
    expect(horario.asignaturaIds, {12, 19});
  });

  test('cerrar sesión se lleva las clases del que se va', () {
    // Igual que el token y el periodo: el docente siguiente no tiene por qué
    // ver en el muro cuántas clases tenía el anterior.
    horario.tomar([clase(12, '3B')]);
    horario.limpiar();

    expect(horario.seSabe, isFalse);
    expect(horario.cuantas, 0);
  });
}
