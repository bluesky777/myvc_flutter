import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';

void main() {
  test('se lee la carga real de /asignaturas/listasignaturas', () {
    final a = AsignaturaModel.fromJson({
      'asignatura_id': 1327,
      'grupo_id': 105,
      'profesor_id': 7,
      'creditos': 2,
      'orden': 1,
      'materia': 'EDUCACION ARTÍSTICA',
      'alias_materia': 'ART',
      'nombre_grupo': 'Once',
      'abrev_grupo': '11',
    });

    expect(a.id, 1327);
    expect(a.grupoId, 105);
    expect(a.profesorId, 7);
    expect(a.materia, 'EDUCACION ARTÍSTICA');
    expect(a.abrevGrupo, '11');
  });

  test('los numéricos en texto no rompen nada', () {
    final a = AsignaturaModel.fromJson({
      'asignatura_id': '1327',
      'grupo_id': '105',
      'profesor_id': '7',
      'materia': 'MATEMÁTICAS',
      'alias_materia': 'MAT',
      'nombre_grupo': 'Once',
      'abrev_grupo': '11',
    });

    expect(a.id, 1327);
    expect(a.grupoId, 105);
    expect(a.profesorId, 7);
  });

  test('una asignatura sin profesor asignado no revienta', () {
    // /asignaturas devuelve muchas con profesor_id en null.
    final a = AsignaturaModel.fromJson({
      'asignatura_id': 1196,
      'grupo_id': 93,
      'profesor_id': null,
      'materia': 'SIN ASIGNAR',
    });

    expect(a.profesorId, isNull);
    expect(a.aliasMateria, '');
    expect(a.abrevGrupo, '');
  });
}
