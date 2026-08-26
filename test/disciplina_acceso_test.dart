import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

void main() {
  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
  });

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

  group('quién ve el colegio entero', () {
    test('el superusuario y los administradores', () {
      expect(con(superuser: true).esEspecial, isTrue);
      expect(con(roles: {'Admin'}).esEspecial, isTrue);
    });

    test('la coordinación, se apellide como se apellide', () {
      // En la tabla aparecen con apellido y cada colegio tiene los suyos.
      expect(con(roles: {'Coord disciplinario'}).esEspecial, isTrue);
      expect(con(roles: {'Coord académico'}).esEspecial, isTrue);
      expect(con(roles: {'coordinador de convivencia'}).esEspecial, isTrue);
    });

    test('un docente a secas, no: ve solo lo suyo', () {
      expect(con(tipo: 'Profesor').esEspecial, isFalse);
      expect(con(tipo: 'Profesor', roles: {'profesor'}).esEspecial, isFalse);
    });

    test('ni el rector ni la secretaría por serlo', () {
      // Comentar el muro sí lo pueden; ver la disciplina de todos los grados
      // es otra cosa y la decide el colegio dando el rol de coordinación.
      expect(con(roles: {'rector'}).esEspecial, isFalse);
      expect(con(roles: {'secretario'}).esEspecial, isFalse);
    });
  });

  group('la opción del menú', () {
    /// Monta el menú y apunta a qué ruta manda lo que se toque.
    ///
    /// Desde que existe `/mi-disciplina` **el texto ya no distingue**: alumnos,
    /// acudientes y personal ven los tres la palabra «Disciplina», y lo que
    /// separa a unos de otros es la ruta que hay detrás. Comprobar el texto
    /// aquí sería volver a la prueba que pasaba por el motivo equivocado.
    Future<List<String?>> montar(WidgetTester tester) async {
      // El lienzo alto, por lo mismo que en menu_lateral_test: un `ListView` no
      // construye lo que no se ve, y la opción que no cabe falla con la cara de
      // una opción que no está puesta.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final visitadas = <String?>[];

      await tester.pumpWidget(MaterialApp(
        home: MenuLateral(),
        onGenerateRoute: (settings) {
          visitadas.add(settings.name);
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ));
      await tester.pump();

      return visitadas;
    }

    testWidgets('la del personal la ve el personal del colegio',
        (tester) async {
      AuthService.user = UserAutenticado(username: 'agomez', tipo: 'Profesor');

      final visitadas = await montar(tester);
      expect(find.text('Disciplina'), findsOneWidget);

      await tester.tap(find.text('Disciplina'));
      await tester.pumpAndSettle();

      expect(visitadas, contains('/disciplina'));
    });

    // Una prueba por tipo y no un bucle dentro de una: tocar la opción navega,
    // y un segundo `pumpWidget` sobre el mismo tester reaprovecha el árbol —el
    // Navigator se queda donde lo dejó la vuelta anterior y el menú ya no está
    // montado—. La segunda vuelta fallaba diciendo que la opción no existe.
    for (final tipo in ['Alumno', 'Acudiente']) {
      testWidgets('la del personal no la alcanza un ${tipo.toLowerCase()}',
          (tester) async {
        // Las rutas de disciplina que escriben llevan `auth.personal` y les
        // responderían 403. La única que no lo lleva es `mis-fichas`, que es a
        // donde va la suya.
        AuthService.user = UserAutenticado(username: 'x', tipo: tipo);

        final visitadas = await montar(tester);
        await tester.tap(find.text('Disciplina'));
        await tester.pumpAndSettle();

        expect(visitadas, contains('/mi-disciplina'));
        expect(visitadas, isNot(contains('/disciplina')));
      });
    }
  });

  group('el periodo por su número', () {
    test('el del usuario se responde sin haber traído los años', () {
      // Es el caso normal, y no debería depender de una segunda petición.
      ContextoAcademico.instancia
          .tomarDelLogin({'year_id': 9, 'periodo_id': 71, 'numero_periodo': 3});

      expect(ContextoAcademico.instancia.periodoIdDe(3), 71);
      expect(ContextoAcademico.instancia.periodoIdDe(1), isNull);
    });

    test('los demás salen de los periodos del año', () {
      final contexto = ContextoAcademico.instancia;

      contexto
          .tomarDelLogin({'year_id': 9, 'periodo_id': 71, 'numero_periodo': 3});
      contexto.years = [
        YearModel(
          id: 9,
          year: '2026',
          actual: true,
          periodos: [
            PeriodoModel(id: 69, numero: 1),
            PeriodoModel(id: 70, numero: 2),
            PeriodoModel(id: 71, numero: 3),
            PeriodoModel(id: 72, numero: 4),
          ],
        ),
        // Otro año, con periodos que se llaman igual y son otros.
        YearModel(
          id: 8,
          year: '2025',
          actual: false,
          periodos: [PeriodoModel(id: 50, numero: 1)],
        ),
      ];

      expect(contexto.periodoIdDe(1), 69);
      expect(contexto.periodoIdDe(4), 72);
      // Un periodo que ese año no tiene.
      expect(contexto.periodoIdDe(5), isNull);
    });
  });
}
