import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';

void main() {
  final contexto = ContextoAcademico.instancia;

  setUp(() {
    contexto.limpiar();
    contexto.tomarDelLogin({
      'year_id': 6,
      'year': '2026',
      'periodo_id': 21,
      'numero_periodo': 3,
    });
  });

  Widget conBarra() => MaterialApp(
        home: Scaffold(
          body: BarraPlegable(
            titulo: 'Disciplina',
            child: ListView.builder(
              itemCount: 40,
              itemBuilder: (_, i) => SizedBox(
                height: 60,
                child: Text('fila $i'),
              ),
            ),
          ),
        ),
      );

  testWidgets('desplegada enseña el título y el periodo',
      (WidgetTester tester) async {
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();

    expect(find.text('Disciplina'), findsOneWidget);
    expect(find.text('2026 · Periodo 3'), findsOneWidget);
  });

  testWidgets('al desplazar se queda el título y la franja se esconde',
      (WidgetTester tester) async {
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();

    final desplegada = tester.getSize(find.byType(AppBar)).height;

    await tester.drag(find.text('fila 2'), const Offset(0, -400));
    await tester.pumpAndSettle();

    final plegada = tester.getSize(find.byType(AppBar)).height;

    expect(plegada, lessThan(desplegada));
    // Lo que queda es exactamente la altura del título: la franja del periodo
    // se ha ido entera.
    expect(plegada, kToolbarHeight);
    // Y el título sigue ahí, que es de lo que se trata.
    expect(find.text('Disciplina'), findsOneWidget);
  });

  testWidgets('volviendo arriba la franja vuelve',
      (WidgetTester tester) async {
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();

    final desplegada = tester.getSize(find.byType(AppBar)).height;

    await tester.drag(find.text('fila 2'), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.drag(find.text('fila 8'), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AppBar)).height, desplegada);
    expect(find.text('2026 · Periodo 3'), findsOneWidget);
  });
}
