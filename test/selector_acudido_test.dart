import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Widgets/SelectorAcudido.dart';

void main() {
  AcudidoModel acudido(int id, String nombre, {String? grupo, bool paz = true}) {
    return AcudidoModel(
      alumnoId: id,
      nombres: nombre,
      grupo: grupo,
      pazYSalvo: paz,
    );
  }

  Future<AcudidoModel?> abrir(
      WidgetTester tester, List<AcudidoModel> acudidos) async {
    AcudidoModel? elegido;
    var abierto = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                abierto = true;
                elegido = await pedirAcudido(context, acudidos);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(abierto, isTrue);
    return elegido;
  }

  testWidgets('con un solo acudido no pregunta nada',
      (WidgetTester tester) async {
    // A un padre con un solo hijo, elegirlo cada vez le sobra.
    final uno = [acudido(1, 'Dámaris')];

    final elegido = await abrir(tester, uno);

    expect(elegido, same(uno.first));
    expect(find.text('¿De quién?'), findsNothing);
  });

  testWidgets('con varios los enseña con su grupo',
      (WidgetTester tester) async {
    await abrir(tester, [
      acudido(1, 'Dámaris', grupo: 'Séptimo A'),
      acudido(2, 'Ariolfo', grupo: 'Noveno B'),
    ]);

    expect(find.text('Dámaris'), findsOneWidget);
    expect(find.text('Séptimo A'), findsOneWidget);
    expect(find.text('Noveno B'), findsOneWidget);
  });

  testWidgets('el que no está a paz y salvo se marca con un candado',
      (WidgetTester tester) async {
    await abrir(tester, [
      acudido(1, 'Dámaris', paz: true),
      acudido(2, 'Ariolfo', paz: false),
    ]);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('sin acudidos no hay nada que preguntar',
      (WidgetTester tester) async {
    final elegido = await abrir(tester, []);

    expect(elegido, isNull);
  });
}
