import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/VerificacionSesion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que se prueba aquí no es una pantalla: es cuántas veces la app le pide a
/// un hosting compartido una consulta que no necesita. `GET /years` trae todos
/// los años y luego uno por sus periodos, y la app solo mira el código de
/// estado. Ver VerificacionSesion.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cuándo hay que volver a preguntarle al servidor', () {
    test('la primera vez, siempre', () async {
      expect(await VerificacionSesion.hayQueComprobar(), isTrue);
    });

    test('recién sellada, no', () async {
      await VerificacionSesion.sellar();

      expect(await VerificacionSesion.hayQueComprobar(), isFalse);
    });

    test('dentro de las seis horas, no', () async {
      final ahora = DateTime(2026, 9, 2, 13, 0);
      await VerificacionSesion.sellar(
        cuando: ahora.subtract(const Duration(hours: 5, minutes: 59)),
      );

      expect(await VerificacionSesion.hayQueComprobar(ahora: ahora), isFalse);
    });

    test('pasadas las seis horas, sí', () async {
      final ahora = DateTime(2026, 9, 2, 13, 0);
      await VerificacionSesion.sellar(
        cuando: ahora.subtract(const Duration(hours: 6, minutes: 1)),
      );

      expect(await VerificacionSesion.hayQueComprobar(ahora: ahora), isTrue);
    });

    test('un sello del futuro no vale', () async {
      // El reloj del teléfono se movió hacia atrás. Ante la duda se pregunta,
      // que es el lado seguro: lo contrario sería fiarse durante horas de un
      // sello que no se sabe de cuándo es.
      final ahora = DateTime(2026, 9, 2, 13, 0);
      await VerificacionSesion.sellar(
        cuando: ahora.add(const Duration(days: 1)),
      );

      expect(await VerificacionSesion.hayQueComprobar(ahora: ahora), isTrue);
    });

    test('olvidar hace que se vuelva a preguntar', () async {
      // Es lo que llaman cerrar sesión y el 401 del muro. Sin esto, quien entre
      // después en el mismo teléfono heredaría seis horas de «ya se comprobó»
      // que no le corresponden.
      await VerificacionSesion.sellar();
      await VerificacionSesion.olvidar();

      expect(await VerificacionSesion.hayQueComprobar(), isTrue);
    });

    test('un sello ilegible se trata como si no lo hubiera', () async {
      // Una versión anterior de la app, o un disco a medias.
      SharedPreferences.setMockInitialValues({
        VerificacionSesion.clave: 'ayer por la tarde',
      });

      expect(await VerificacionSesion.hayQueComprobar(), isTrue);
    });
  });
}
