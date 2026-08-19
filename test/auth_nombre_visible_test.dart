import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';

void main() {
  test('un Profesor se nombra por sus nombres', () {
    final u = UserAutenticado(
      tipo: 'Profesor',
      username: 'MARYELINE',
      nombres: 'MARYELINE GÓMEZ',
    );

    expect(u.nombreVisible, 'MARYELINE GÓMEZ');
  });

  test('un Usuario se nombra por su nombre de usuario', () {
    // Es lo que devuelve /login para tipo Usuario: nombres y apellidos vacíos.
    final u = UserAutenticado(
      tipo: 'Usuario',
      username: 'administrador',
      nombres: null,
    );

    expect(u.nombreVisible, 'administrador');
  });

  test('unos nombres en blanco no ganan al nombre de usuario', () {
    final u = UserAutenticado(username: 'coordinacion', nombres: '   ');
    expect(u.nombreVisible, 'coordinacion');
  });

  test('limpiar deja la sesión sin identidad', () {
    AuthService.setToken('61|loquesea');
    AuthService.user.id = 7;
    AuthService.user.tipo = 'Profesor';

    AuthService.limpiar();

    expect(AuthService.user.token, isNull);
    expect(AuthService.user.id, isNull);
    expect(AuthService.user.tipo, isNull);
    expect(AuthService.user.username, '');
  });
}
