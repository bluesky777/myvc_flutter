import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/BarraContexto.dart';

void main() {
  final contexto = ContextoAcademico.instancia;

  setUp(contexto.limpiar);

  group('la franja del periodo, debajo del título', () {
    setUp(() {
      contexto.tomarDelLogin({
        'year_id': 6,
        'year': '2026',
        'periodo_id': 21,
        'numero_periodo': 3,
      });
    });

    Widget conFranja() => MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Disciplina'),
              bottom: BarraContexto(),
            ),
            body: const SizedBox(),
          ),
        );

    testWidgets('el nombre de la pantalla y el periodo, cada uno en su renglón',
        (WidgetTester tester) async {
      // Juntos en un título de dos líneas obligaban a encoger el periodo
      // hasta que dejaba de leerse, y es el dato que más se mira.
      await tester.pumpWidget(conFranja());

      expect(find.text('Disciplina'), findsOneWidget);
      expect(find.text('2026 · Periodo 3'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('desde ahí se sigue cambiando de periodo',
        (WidgetTester tester) async {
      await tester.pumpWidget(conFranja());

      await tester.tap(find.text('2026 · Periodo 3'));
      await tester.pump();

      // Se comprueba que la hoja se abre y no qué trae: lo que trae sale de
      // GET /years, y en las pruebas no hay servidor que conteste.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('se actualiza sola cuando cambia el contexto',
        (WidgetTester tester) async {
      await tester.pumpWidget(conFranja());

      contexto.tomarDelLogin({
        'year_id': 5,
        'year': '2025',
        'periodo_id': 14,
        'numero_periodo': 1,
      });
      await tester.pump();

      expect(find.text('2025 · Periodo 1'), findsOneWidget);
    });

    testWidgets('va centrado, no pegado a la izquierda',
        (WidgetTester tester) async {
      await tester.pumpWidget(conFranja());

      final franja = tester.getRect(find.byType(BarraContexto));
      final texto = tester.getRect(find.text('2026 · Periodo 3'));

      // El icono de la izquierda y la flechita de la derecha se compensan casi
      // exactamente, así que el texto cae en el centro de la franja. Pegado a
      // la izquierda quedaría a más de trescientos píxeles de ahí.
      expect((texto.center.dx - franja.center.dx).abs(), lessThan(15));
    });
  });
}
