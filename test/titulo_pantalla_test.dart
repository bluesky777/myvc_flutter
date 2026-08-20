import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

void main() {
  group('el título de dos líneas', () {
    testWidgets('sin subtítulo se queda en una', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TituloPantalla(titulo: 'Asistencias')),
          body: const SizedBox(),
        ),
      ));

      expect(find.text('Asistencias'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('un subtítulo en blanco cuenta como no tenerlo',
        (WidgetTester tester) async {
      // Es lo que pasa cuando el alumno todavía no ha llegado del servidor.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: TituloPantalla(titulo: 'Mis notas', subtitulo: '   '),
          ),
          body: const SizedBox(),
        ),
      ));

      expect(find.text('Mis notas'), findsOneWidget);
      expect(find.text('   '), findsNothing);
    });
  });
}
