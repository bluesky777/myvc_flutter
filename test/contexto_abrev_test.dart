import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:shared_preferences/shared_preferences.dart';

String cuerpoDeYears(List<Map<String, dynamic>> anios) => jsonEncode([
      for (final a in anios)
        {
          'id': a['id'],
          'year': a['year'],
          'actual': a['actual'] ?? 0,
          'abrev_colegio': a['abrev_colegio'],
          'logo': a['logo'],
          'periodos': [
            {'id': 1, 'numero': 1},
          ],
        },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final contexto = ContextoAcademico.instancia;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    contexto.limpiar();
  });

  group('las siglas del colegio', () {
    test('salen del login si vienen ahí', () {
      contexto.tomarDelLogin(
          {'year_id': 6, 'year': '2026', 'abrev_colegio': 'LAL'});

      expect(contexto.abrevColegio, 'LAL');
    });

    test('un login sin la columna las deja vacías, no las inventa', () {
      contexto.tomarDelLogin({'year_id': 6, 'year': '2026'});

      expect(contexto.abrevColegio, '');
    });

    test('lo que llegue vacío después NO borra lo que ya había', () {
      // El caso feo: el login las trae, `/years` llega luego con la columna
      // vacía y la barra pasaría de decir «LAL» a decir «Inicio» a mitad de
      // sesión. Un rótulo que empeora solo no lo reporta nadie.
      contexto.tomarDelLogin(
          {'year_id': 6, 'year': '2026', 'abrev_colegio': 'LAL'});
      contexto
          .tomarDelLogin({'year_id': 6, 'year': '2026', 'abrev_colegio': '  '});

      expect(contexto.abrevColegio, 'LAL');
    });

    test('salen del cuerpo de /years, que es el que seguro las trae', () {
      contexto.tomarDelLogin({'year_id': 6, 'year': '2026'});

      contexto.tomarSenasDelColegio(cuerpoDeYears([
        {'id': 6, 'year': '2026', 'abrev_colegio': 'LAL'},
      ]));

      expect(contexto.abrevColegio, 'LAL');
    });

    test('si el año en curso no las trae, vale cualquier otro', () {
      // Son del colegio, no del año. Quedarse sin ellas porque justo el año en
      // curso tenga la columna vacía sería perderlas por nada.
      contexto.tomarDelLogin({'year_id': 6, 'year': '2026'});

      contexto.tomarSenasDelColegio(cuerpoDeYears([
        {'id': 6, 'year': '2026', 'abrev_colegio': null},
        {'id': 5, 'year': '2025', 'abrev_colegio': 'LAL'},
      ]));

      expect(contexto.abrevColegio, 'LAL');
    });

    test('un /years que no se entiende no tumba nada', () {
      // Lo llama la comprobación del token en el arranque en frío: si esto
      // lanzara, no arrancaría la app por unas siglas.
      expect(() => contexto.tomarSenasDelColegio('esto no es json'),
          returnsNormally);
      expect(() => contexto.tomarSenasDelColegio('{}'), returnsNormally);
      expect(contexto.abrevColegio, '');
    });

    test('se recuerdan entre arranques', () async {
      // `/years` no se pide en cada arranque —es el N+1 que VerificacionSesion
      // espacia—, así que sin guardarlas la barra abriría sin siglas cada
      // mañana y las estrenaría a media sesión.
      contexto.tomarSenasDelColegio(cuerpoDeYears([
        {'id': 6, 'year': '2026', 'abrev_colegio': 'LAL'},
      ]));
      await Future<void>.delayed(Duration.zero);

      contexto.limpiar();
      SharedPreferences.setMockInitialValues({
        ContextoAcademico.claveAbrev: 'LAL',
      });
      await contexto.recordarSenasDelColegio();

      expect(contexto.abrevColegio, 'LAL');
    });

    test('el logo sale del mismo /years, y por separado de la sigla', () {
      // Un año puede traer la sigla y no el logo. Quedarse sin logo por eso
      // sería perderlo por nada, así que cada seña se busca aparte.
      contexto.tomarDelLogin({'year_id': 6, 'year': '2026'});

      contexto.tomarSenasDelColegio(
        cuerpoDeYears([
          {'id': 6, 'year': '2026', 'abrev_colegio': 'LAL', 'logo': null},
          {
            'id': 5,
            'year': '2025',
            'abrev_colegio': null,
            'logo': 'user_1/e.png'
          },
        ]),
      );

      expect(contexto.abrevColegio, 'LAL');
      expect(contexto.logoColegio, 'user_1/e.png');
    });

    test('un colegio sin logo deja el logo vacío, no inventa ninguno', () {
      contexto.tomarSenasDelColegio(
        cuerpoDeYears([
          {'id': 6, 'year': '2026', 'abrev_colegio': 'LAL'},
        ]),
      );

      expect(contexto.abrevColegio, 'LAL');
      expect(contexto.logoColegio, '');
    });

    test('limpiar sí las borra: son del colegio del que se acaba de salir', () {
      contexto.tomarDelLogin(
          {'year_id': 6, 'year': '2026', 'abrev_colegio': 'LAL'});
      contexto.limpiar();

      expect(contexto.abrevColegio, '');
      expect(contexto.logoColegio, '');
    });
  });
}
