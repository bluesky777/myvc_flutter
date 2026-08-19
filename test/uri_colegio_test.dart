import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';

void main() {
  group('dos colegios iguales', () {
    test('lo son también para un Set', () {
      // == compara por nombre; si el hash no hace lo mismo, el Set guarda dos.
      final unos = UriColegio(nombre: 'Fortul', uri: 'https://coaf.com');
      final otros = UriColegio(nombre: 'Fortul', uri: 'https://coaf.com');

      expect(unos == otros, isTrue);
      expect(unos.hashCode, otros.hashCode);
      expect({unos, otros}.length, 1);
    });

    test('sirven como la misma clave de un Map', () {
      final mapa = <UriColegio, int>{};
      mapa[UriColegio(nombre: 'Saravena')] = 1;
      mapa[UriColegio(nombre: 'Saravena')] = 2;

      expect(mapa.length, 1);
      expect(mapa[UriColegio(nombre: 'Saravena')], 2);
    });

    test('colegios distintos siguen siendo distintos', () {
      expect(UriColegio(nombre: 'Fortul') == UriColegio(nombre: 'Saravena'),
          isFalse);
    });
  });
}
