import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/TituloContexto.dart';

void main() {
  final contexto = ContextoAcademico.instancia;

  setUp(contexto.limpiar);

  Widget conBarra() => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TituloContexto()),
          body: const SizedBox(),
        ),
      );

  testWidgets('la barra enseña el año y el periodo del usuario',
      (WidgetTester tester) async {
    contexto.tomarDelLogin({
      'year_id': 6,
      'year': '2026',
      'periodo_id': 21,
      'numero_periodo': 3,
    });

    await tester.pumpWidget(conBarra());

    expect(find.text('2026 · Periodo 3'), findsOneWidget);
    // La flechita es lo que dice que se puede tocar.
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('se actualiza sola cuando cambia el contexto',
      (WidgetTester tester) async {
    contexto.tomarDelLogin({
      'year_id': 6,
      'year': '2026',
      'periodo_id': 21,
      'numero_periodo': 3,
    });
    await tester.pumpWidget(conBarra());

    contexto.tomarDelLogin({
      'year_id': 5,
      'year': '2025',
      'periodo_id': 14,
      'numero_periodo': 1,
    });
    await tester.pump();

    expect(find.text('2025 · Periodo 1'), findsOneWidget);
    expect(find.text('2026 · Periodo 3'), findsNothing);
  });
}
