import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';

void main() {
  group('el motivo con el que el servidor rechaza una nota', () {
    test('es el que se le enseña al docente, no el número', () {
      // El caso que motivó esto: la escala pasó a validarse en el servidor y
      // `PUT notas/update` contesta 422 donde antes daba 200. Antes el docente
      // veía «El servidor respondió 422.», que no dice qué escribir en su
      // lugar.
      final cuerpo = jsonEncode({
        'message': 'La nota 105 no cabe en la escala del año (0 a 100).',
      });

      expect(
        motivoDeRechazo(cuerpo, respaldo: 'no debería usarse'),
        'La nota 105 no cabe en la escala del año (0 a 100).',
      );
    });

    test('si el servidor corta sin explicarse, se usa el respaldo', () {
      expect(
        motivoDeRechazo('', respaldo: 'La nota no cabe en la escala del año.'),
        'La nota no cabe en la escala del año.',
      );
      expect(
        motivoDeRechazo(jsonEncode({'error': 'x'}),
            respaldo: 'La nota no cabe en la escala del año.'),
        'La nota no cabe en la escala del año.',
      );
    });

    test('una página de error en HTML no acaba en un aviso', () {
      // Sin `Accept: application/json` el servidor puede contestar su página de
      // error. Volcarla en un SnackBar no informa de nada.
      expect(loQueDijoElServidor('<!DOCTYPE html><html>...'), isNull);
    });

    test('un volcado de excepción tampoco, aunque sea JSON válido', () {
      // Es el recorte que más importa: esto valida como JSON y trae `message`,
      // así que sin los cortes de largo y de saltos de línea se le enseñaría la
      // traza entera a un docente.
      final traza = jsonEncode({
        'message': 'SQLSTATE[42S22]: Column not found: 1054\n'
            '#0 /var/www/vendor/laravel/framework/src/Illuminate/Database.php(760)\n'
            '#1 /var/www/app/Http/Controllers/NotasController.php(412)',
      });

      expect(loQueDijoElServidor(traza), isNull);
    });

    test('un mensaje larguísimo se descarta, aunque venga en una línea', () {
      final largo = jsonEncode({'message': 'x' * 200});

      expect(loQueDijoElServidor(largo), isNull);
    });

    test('un cuerpo que no es texto no revienta', () {
      expect(loQueDijoElServidor(null), isNull);
      expect(loQueDijoElServidor(42), isNull);
      expect(loQueDijoElServidor({'message': 'ya decodificado'}), isNull);
    });
  });
}
