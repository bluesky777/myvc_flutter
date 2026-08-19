import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Widgets/SelectorDia.dart';

/// Una pantalla mínima que abre el cuadro y enseña lo que devolvió.
Widget _pantalla(DateTime inicial, void Function(DateTime?) alVolver) {
  return MaterialApp(
    // Lo mismo que monta main.dart: el calendario tiene que salir en español.
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => alVolver(await pedirDiaDeFalta(context, inicial)),
          child: Text('Cambiar'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('el cuadro trae el día y la hora que ya tenía la falta',
      (WidgetTester tester) async {
    await tester.pumpWidget(_pantalla(DateTime(2026, 8, 12, 7, 30), (_) {}));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    // El calendario abre en el mes de la falta —y en español—, y la hora sale
    // en sus dos campos, en el reloj de doce. Se buscan por el campo y no por
    // el texto suelto: en el calendario de agosto también hay un 30.
    expect(find.text('agosto de 2026'), findsOneWidget);
    expect(find.widgetWithText(TextField, '7'), findsOneWidget);
    expect(find.widgetWithText(TextField, '30'), findsOneWidget);
  });

  testWidgets('Guardar devuelve el día del calendario y la hora tecleada',
      (WidgetTester tester) async {
    DateTime? elegido;

    await tester.pumpWidget(
      _pantalla(DateTime(2026, 8, 12, 7, 30, 45), (d) => elegido = d),
    );
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    // Un día del calendario y, sin salir del cuadro, otros minutos.
    await tester.tap(find.text('3'));
    await tester.enterText(find.widgetWithText(TextField, '30'), '05');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(elegido, DateTime(2026, 8, 3, 7, 5, 45));
  });

  testWidgets('Cancelar no devuelve nada', (WidgetTester tester) async {
    DateTime? elegido = DateTime(2000);

    await tester.pumpWidget(
      _pantalla(DateTime(2026, 8, 12, 7, 30), (d) => elegido = d),
    );
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(elegido, isNull);
  });

  testWidgets('una hora imposible no se puede guardar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_pantalla(DateTime(2026, 8, 12, 7, 30), (_) {}));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '7'), '99');
    await tester.pumpAndSettle();

    final guardar = tester.widget<TextButton>(
      find.ancestor(of: find.text('Guardar'), matching: find.byType(TextButton)),
    );
    expect(guardar.onPressed, isNull);
  });

  testWidgets('una falta de la tarde llega marcada como p. m.',
      (WidgetTester tester) async {
    await tester.pumpWidget(_pantalla(DateTime(2026, 8, 12, 14, 5), (_) {}));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    // Las 14:05 se leen como las 2:05 de la tarde.
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '05'), findsOneWidget);

    final segmentado = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segmentado.selected, {true});
  });

  testWidgets('pasar a p. m. devuelve la hora corrida doce horas',
      (WidgetTester tester) async {
    DateTime? elegido;

    await tester.pumpWidget(
      _pantalla(DateTime(2026, 8, 12, 7, 30), (d) => elegido = d),
    );
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('p. m.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(elegido, DateTime(2026, 8, 12, 19, 30));
  });

  testWidgets('las 12 a. m. son las cero, no las doce del día',
      (WidgetTester tester) async {
    DateTime? elegido;

    // Una falta guardada a las 00:00, que es como se guardan las de días
    // pasados: tiene que llegar como 12 a. m. y volver a salir como las cero.
    await tester.pumpWidget(
      _pantalla(DateTime(2026, 8, 12, 0, 0), (d) => elegido = d),
    );
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '12'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(elegido, DateTime(2026, 8, 12, 0, 0));
  });

  testWidgets('la hora 0 no existe en el reloj de doce',
      (WidgetTester tester) async {
    await tester.pumpWidget(_pantalla(DateTime(2026, 8, 12, 7, 30), (_) {}));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '7'), '0');
    await tester.pumpAndSettle();

    final guardar = tester.widget<TextButton>(
      find.ancestor(of: find.text('Guardar'), matching: find.byType(TextButton)),
    );
    expect(guardar.onPressed, isNull);
  });
}
