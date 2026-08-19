import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';

void main() {
  group('la URL de la foto', () {
    test('escapa los espacios, que en una URL no valen', () {
      // Así vienen de la tabla images: con carpeta y con espacios.
      expect(
        Server.urlFoto('user_2/P Ariolfo.JPG'),
        '${Server.urlImages}/user_2/P%20Ariolfo.JPG',
      );
    });

    test('no escapa las barras: son la ruta, no parte del nombre', () {
      expect(
        Server.urlFoto('user_2/foto.png'),
        contains('/user_2/foto.png'),
      );
    });

    test('sin foto no hay URL que pedir', () {
      expect(Server.urlFoto(null), '');
      expect(Server.urlFoto(''), '');
      expect(Server.urlFoto('   '), '');
    });
  });

  group('el avatar', () {
    testWidgets('sin foto muestra las iniciales', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AvatarPersona(nombre: 'ARIOLFO GÓMEZ PICO'),
        ),
      ));

      // Las dos primeras palabras, no las tres.
      expect(find.text('AG'), findsOneWidget);
    });

    testWidgets('un nombre de una sola palabra da una sola letra',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AvatarPersona(nombre: 'Dámaris')),
      ));

      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('sin nombre queda el icono, y no un hueco',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AvatarPersona(nombre: '  ')),
      ));

      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
