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
      expect(fraseDeFallo(429), contains('espera un minuto'));
      expect(fraseDeFallo(500), contains('(500)'));
      expect(fraseDeFallo(418), 'El colegio no aceptó la petición (418).');
    });

    test('noSePudo dice qué no se pudo y por qué', () {
      expect(noSePudo('registrar la ausencia', 403),
          'No se pudo registrar la ausencia: no tienes permiso para esto (403).');
      expect(
        noSePudo('registrar la ausencia', 403,
            '{"message":"Las ausencias las pone coordinación."}'),
        'No se pudo registrar la ausencia: Las ausencias las pone coordinación.',
      );
      expect(noSePudo('guardar', 503), contains('mantenimiento'));
    });

    test('ningún código sale como un número suelto', () {
      for (final codigo in [400, 401, 403, 404, 405, 408, 409, 410, 413, 419,
          422, 423, 429, 418, 500, 502, 503, 504, 302]) {
        final frase = fraseDeFallo(codigo);
        expect(frase, isNot(contains('respondió')), reason: '$codigo');
        expect(frase, endsWith('($codigo).'), reason: '$codigo');
      }
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
