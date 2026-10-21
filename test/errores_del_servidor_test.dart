import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';

/// Lo que ve la persona cuando el servidor falla o no se llega a él.
void main() {
  group('fraseDeFallo', () {
    test('lo que dijo el servidor va primero', () {
      expect(
        fraseDeFallo(403, '{"message":"Esta cuenta es sólo de portería."}'),
        'Esta cuenta es sólo de portería.',
      );
    });

    test('sin JSON, una frase por código y el número entre paréntesis', () {
      expect(fraseDeFallo(403, '<html>'), contains('permiso'));
      expect(fraseDeFallo(404), contains('(404)'));
      expect(fraseDeFallo(429), contains('Espera un minuto'));
      expect(fraseDeFallo(500), contains('(500)'));
      expect(fraseDeFallo(418), 'El servidor respondió 418.');
    });

    test('FalloDelServidor se pinta sin «Exception: » delante', () {
      final fallo = FalloDelServidor.de(http.Response('', 500));

      expect('$fallo', isNot(startsWith('Exception')));
      expect(fallo.codigo, 500);
    });
  });

  group('sin conexión', () {
    late String antes;

    setUp(() {
      antes = Server.urlApi;
      Server.urlApi = 'https://colegio.test/api';
      AuthService.user.token = 'tok';
    });

    tearDown(() {
      Server.urlApi = antes;
      AuthService.limpiar();
    });

    test('una caída de red llega como SinConexion, con frase legible',
        () async {
      final pedir = http.runWithClient(
        () => Server().get('/years'),
        () => MockClient((_) async =>
            throw http.ClientException('Failed host lookup: colegio.test')),
      );

      await expectLater(
        pedir,
        throwsA(
            isA<SinConexion>().having((e) => '$e', 'texto', SinConexion.frase)),
      );
    });

    test('sigue siendo un ClientException para quien ya lo miraba por tipo',
        () {
      expect(SinConexion(Exception('x')), isA<http.ClientException>());
    });
  });
}
