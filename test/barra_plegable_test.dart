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
          itemBuilder: (_, i) => SizedBox(height: 60, child: Text('fila $i')),
        ),
      ),
    ),
  );

  testWidgets('el título y el periodo, en una sola fila', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();

    expect(find.text('Disciplina'), findsOneWidget);
    expect(find.text('2026 · Per 3'), findsOneWidget);
  });

  testWidgets('la barra no se pliega, porque ya no hay nada que plegar', (
    WidgetTester tester,
  ) async {
    // Antes eran dos franjas y la de abajo se escondía al desplazar. Ahora es
    // una, así que la altura tiene que ser la misma arriba del todo y a mitad
    // de lista: si cambiara, es que alguien devolvió el `expandedHeight`.
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();

    final arriba = tester.getSize(find.byType(AppBar)).height;
    expect(arriba, kToolbarHeight);

    await tester.drag(find.text('fila 2'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AppBar)).height, arriba);
  });

  testWidgets('el periodo sigue ahí después de desplazar', (
    WidgetTester tester,
  ) async {
    // Es el único control de la barra, y el motivo de que valga la pena
    // tenerla fija: se cambia de periodo sin volver arriba del todo.
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();

    await tester.drag(find.text('fila 2'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Disciplina'), findsOneWidget);
    expect(find.text('2026 · Per 3'), findsOneWidget);
  });
}
