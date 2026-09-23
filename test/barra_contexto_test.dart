import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/BarraContexto.dart';

void main() {
  final contexto = ContextoAcademico.instancia;

  setUp(contexto.limpiar);

  group('el periodo, a la derecha de la barra', () {
    setUp(() {
      contexto.tomarDelLogin({
        'year_id': 6,
        'year': '2026',
        'periodo_id': 21,
        'numero_periodo': 3,
      });
    });

    Widget conBarra() => MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Disciplina'),
              actions: [BarraContexto()],
            ),
            body: const SizedBox(),
          ),
        );

    testWidgets('el nombre de la pantalla y el periodo, en la misma fila',
        (WidgetTester tester) async {
      await tester.pumpWidget(conBarra());

      expect(find.text('Disciplina'), findsOneWidget);
      expect(find.text('2026 · Per 3'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('«Periodo» va abreviado, que el sitio lo necesita el título',
        (WidgetTester tester) async {
      // Escrito entero se comía el ancho de una palabra larga del título, y
      // «Periodo» no dice nada que el número de al lado no diga.
      await tester.pumpWidget(conBarra());

      expect(find.text('2026 · Periodo 3'), findsNothing);
    });

    testWidgets('desde ahí se sigue cambiando de periodo',
        (WidgetTester tester) async {
      await tester.pumpWidget(conBarra());

      await tester.tap(find.text('2026 · Per 3'));
      await tester.pump();

      // Se comprueba que la hoja se abre y no qué trae: lo que trae sale de
      // GET /years, y en las pruebas no hay servidor que conteste.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('se actualiza sola cuando cambia el contexto',
        (WidgetTester tester) async {
      await tester.pumpWidget(conBarra());

      contexto.tomarDelLogin({
        'year_id': 5,
        'year': '2025',
        'periodo_id': 14,
        'numero_periodo': 1,
      });
      await tester.pump();

      expect(find.text('2025 · Per 1'), findsOneWidget);
    });

    testWidgets('una sola barra: el periodo no ocupa un renglón propio',
        (WidgetTester tester) async {
      // Lo que se fue: una segunda franja debajo del título. La comprobación
      // que lo dice sin ambigüedad es la altura — dos franjas medían el doble—
      // y que el periodo caiga a la derecha del título y no debajo.
      await tester.pumpWidget(conBarra());

      final barra = tester.getRect(find.byType(AppBar));
      final titulo = tester.getRect(find.text('Disciplina'));
      final periodo = tester.getRect(find.text('2026 · Per 3'));

      expect(barra.height, lessThanOrEqualTo(kToolbarHeight));
      expect(periodo.left, greaterThan(titulo.right));
      // En la misma fila: los centros verticales caen casi en la misma línea.
      expect((periodo.center.dy - titulo.center.dy).abs(), lessThan(4));
    });
  });
}
