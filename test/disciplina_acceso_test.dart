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
    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: MenuLateral()));
      await tester.pump();
    }

    testWidgets('la ve el personal del colegio', (tester) async {
      AuthService.user = UserAutenticado(username: 'agomez', tipo: 'Profesor');

      await montar(tester);

      expect(find.text('Disciplina'), findsOneWidget);
    });

    testWidgets('no la ven los alumnos ni los acudientes', (tester) async {
      // Y no es solo por pudor: todas las rutas de disciplina del backend
      // llevan `auth.personal` y les responderían 403.
      AuthService.user = UserAutenticado(username: 'ana', tipo: 'Alumno');
      await montar(tester);
      expect(find.text('Disciplina'), findsNothing);

      AuthService.user = UserAutenticado(username: 'papa', tipo: 'Acudiente');
      await montar(tester);
      expect(find.text('Disciplina'), findsNothing);
    });
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
