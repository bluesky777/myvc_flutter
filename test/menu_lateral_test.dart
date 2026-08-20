import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';

void main() {
  setUp(AuthService.limpiar);

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: MenuLateral()));
    await tester.pump();
  }

  group('el nombre en la cabecera', () {
    testWidgets('el de quien tiene ficha con nombres',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(
        username: 'agomez',
        nombres: 'Ariolfo Gómez',
        tipo: 'Profesor',
      );

      await montar(tester);

      expect(find.text('Ariolfo Gómez'), findsOneWidget);
      expect(find.text('agomez'), findsOneWidget);
    });

    testWidgets('el nombre de usuario cuando no hay ficha con nombres',
        (WidgetTester tester) async {
      // Es el caso del administrador: tipo Usuario, sin nombres. Antes le
      // decía «Sin identificar» a alguien que está perfectamente identificado.
      AuthService.user = UserAutenticado(
        username: 'administrador',
        tipo: 'Usuario',
      );

      await montar(tester);

      expect(find.text('administrador'), findsWidgets);
      expect(find.text('Sin identificar'), findsNothing);
    });

    testWidgets('unos nombres en blanco cuentan como no tenerlos',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'agomez', nombres: '   ');

      await montar(tester);

      expect(find.text('agomez'), findsWidgets);
    });
  });

  group('el logo', () {
    testWidgets('es el fondo de la cabecera, no una fila del menú',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'administrador');

      await montar(tester);

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.fit, BoxFit.cover,
          reason: 'un fondo llena su hueco; una fila no');
    });
  });

  group('las opciones según quién entra', () {
    testWidgets('un docente ve Asistencias y Unidades',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'x', tipo: 'Profesor');

      await montar(tester);

      expect(find.text('Publicaciones'), findsOneWidget);
      expect(find.text('Asistencias'), findsOneWidget);
      expect(find.text('Unidades'), findsOneWidget);
      expect(find.text('Mis notas'), findsNothing);
    });

    testWidgets('un alumno ve Mis notas y Asistencia',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'x', tipo: 'Alumno');

      await montar(tester);

      expect(find.text('Mis notas'), findsOneWidget);
      expect(find.text('Asistencia'), findsOneWidget);
      expect(find.text('Unidades'), findsNothing);
      expect(find.text('Asistencias'), findsNothing);
    });
  });
}
