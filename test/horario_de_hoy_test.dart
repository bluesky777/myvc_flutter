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

  test('con horario publicado y sin clases hoy, se sabe y son cero', () {
    horario.tomar(const [], versionOficial: 7);

    expect(horario.seSabe, isTrue);
    expect(horario.cuantas, 0);
    expect(horario.asignaturaIds, isEmpty);
  });

  test('con clases se guardan sus ids, que es con lo que se filtra', () {
    horario.tomar([clase(12, '3B'), clase(19, '4A')], versionOficial: 7);

    expect(horario.seSabe, isTrue);
    expect(horario.cuantas, 2);
    expect(horario.asignaturaIds, {12, 19});
  });

  test('sin horario publicado NO se sabe, aunque lleguen clases', () {
    // El fallo que esta prueba fija, y que estuvo vivo meses: el backend manda
    // `horario_hoy` SIEMPRE, así que un `[]` significaba a la vez «este colegio
    // no ha puesto su horario» y «hoy no tienes clases». La app elegía la
    // segunda y le decía a todos los docentes, todos los días, «Hoy no tienes
    // clases». Con `horario_version_id` en null eso vuelve a ser «no se sabe».
    //
    // Se mandan clases a propósito: aunque vinieran, sin horario publicado no
    // hay nada en qué apoyarse y la respuesta honesta sigue siendo «no se sabe».
    horario.tomar([clase(12, '3B')], versionOficial: null);

    expect(horario.seSabe, isFalse);
    expect(horario.cuantas, 0);
    expect(horario.asignaturaIds, isEmpty);
  });

  test('un servidor sin desplegar cuenta como «no se sabe»', () {
    // La clave no viaja hasta que 8myvc despliegue `dff8361`, así que
    // `entero(cuerpo['horario_version_id'])` da null en los dieciséis colegios
    // hoy. Eso NO es una concesión: un servidor que no manda la señal es
    // exactamente uno del que no se sabe si hay horario, y así el mensaje falso
    // desaparece sin esperar al despliegue.
    horario.tomar(const [], versionOficial: null);

    expect(horario.seSabe, isFalse);
  });

  test('cerrar sesión se lleva las clases del que se va', () {
    // Igual que el token y el periodo: el docente siguiente no tiene por qué
    // ver en el muro cuántas clases tenía el anterior.
    horario.tomar([clase(12, '3B')], versionOficial: 7);
    horario.limpiar();

    expect(horario.seSabe, isFalse);
    expect(horario.cuantas, 0);
  });
}
