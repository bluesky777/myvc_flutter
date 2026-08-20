import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';

void main() {
  UserAutenticado con({
    String? tipo,
    Set<String> roles = const {},
    bool superuser = false,
  }) {
    return UserAutenticado(
      tipo: tipo,
      roles: roles.map((r) => r.toLowerCase()).toSet(),
      isSuperuser: superuser,
    );
  }

  group('quién es quién', () {
    test('el tipo manda aunque no haya roles', () {
      expect(con(tipo: 'Alumno').esAlumno, isTrue);
      expect(con(tipo: 'Acudiente').esAcudiente, isTrue);
      expect(con(tipo: 'Profesor').esDocente, isTrue);
    });

    test('el rol vale aunque el tipo sea Usuario', () {
      expect(con(tipo: 'Usuario', roles: {'profesor'}).esDocente, isTrue);
    });

    test('da igual cómo esté escrito el rol en la tabla', () {
      // En la base conviven 'Admin' con 'admin' y 'Profesor' con 'profesor'.
      expect(con(roles: {'Admin'}).esAdmin, isTrue);
      expect(con(roles: {'admin'}).esAdmin, isTrue);
    });
  });

  group('quién puede comentar', () {
    test('los del colegio, sí', () {
      expect(con(tipo: 'Profesor').puedeComentar, isTrue);
      expect(con(roles: {'secretario'}).puedeComentar, isTrue);
      expect(con(roles: {'tesorero'}).puedeComentar, isTrue);
      expect(con(roles: {'rector'}).puedeComentar, isTrue);
      expect(con(superuser: true).puedeComentar, isTrue);
    });

    test('los coordinadores, con el apellido que lleven', () {
      expect(con(roles: {'Coord disciplinario'}).puedeComentar, isTrue);
      expect(con(roles: {'Coord académico'}).puedeComentar, isTrue);
    });

    test('los alumnos y los acudientes, no', () {
      expect(con(tipo: 'Alumno').puedeComentar, isFalse);
      expect(con(tipo: 'Acudiente').puedeComentar, isFalse);
    });

    test('un alumno que además tuviera un rol del colegio, tampoco', () {
      // El tipo pesa más que el rol: la cuenta cuelga de la ficha del alumno.
      expect(con(tipo: 'Alumno', roles: {'secretario'}).puedeComentar, isFalse);
    });

    test('un usuario sin nada, no', () {
      expect(con(tipo: 'Usuario').puedeComentar, isFalse);
    });
  });
}
