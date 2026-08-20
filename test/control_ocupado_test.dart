import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Widgets/ControlOcupado.dart';

void main() {
  /// Un contador como el de la pantalla: menos, número y más.
  Widget contador({
    required bool ocupado,
    required VoidCallback onMas,
    required VoidCallback onMenos,
    required int cuenta,
  }) {
    return ControlOcupado(
      ocupado: ocupado,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.remove), onPressed: onMenos),
          Text('$cuenta'),
          IconButton(icon: Icon(Icons.add), onPressed: onMas),
        ],
      ),
    );
  }

  group('mientras la petición está en curso', () {
    testWidgets('los botones dejan de responder', (WidgetTester tester) async {
      var toques = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: contador(
            ocupado: true,
            cuenta: 2,
            onMas: () => toques++,
            onMenos: () => toques++,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.add), warnIfMissed: false);
      await tester.tap(find.byIcon(Icons.remove), warnIfMissed: false);
      await tester.pump();

      expect(toques, 0, reason: 'dos toques seguidos serían dos filas en la BD');
    });

    testWidgets('se ve una rueda encima', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: contador(
            ocupado: true,
            cuenta: 2,
            onMas: () {},
            onMenos: () {},
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // El número sigue ahí debajo, difuminado, no desaparece.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('los controles de al lado siguen vivos',
        (WidgetTester tester) async {
      // Es lo que pidió Joseth: esperar por un alumno no puede congelar a los
      // otros treinta y nueve.
      var toquesDelOcupado = 0;
      var toquesDelLibre = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              contador(
                ocupado: true,
                cuenta: 1,
                onMas: () => toquesDelOcupado++,
                onMenos: () {},
              ),
              contador(
                ocupado: false,
                cuenta: 0,
                onMas: () => toquesDelLibre++,
                onMenos: () {},
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.add).first, warnIfMissed: false);
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();

      expect(toquesDelOcupado, 0);
      expect(toquesDelLibre, 1);
    });
  });

  group('cuando no hay nada en curso', () {
    testWidgets('el botón responde y no hay rueda',
        (WidgetTester tester) async {
      var toques = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: contador(
            ocupado: false,
            cuenta: 0,
            onMas: () => toques++,
            onMenos: () {},
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(toques, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
