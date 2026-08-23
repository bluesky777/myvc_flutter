import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';
import 'package:myvc_flutter/Widgets/SelectorFrases.dart';

const catalogo = [
  FraseDelCatalogo(
    id: 1,
    frase: 'Demuestra interés en la asignación',
    tipo: 'Fortaleza',
  ),
  FraseDelCatalogo(
    id: 2,
    frase: 'Le cuesta entregar a tiempo',
    tipo: 'Debilidad',
  ),
];

void main() {
  /// Monta un botón que abre la hoja y guarda lo que devuelva.
  Future<FraseElegida?> abrirYElegir(
    WidgetTester tester,
    List<FraseDelCatalogo> frases,
    Future<void> Function(WidgetTester) queHace,
  ) async {
    FraseElegida? elegida;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              elegida = await pedirFrase(context, frases);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await queHace(tester);
    await tester.pumpAndSettle();

    return elegida;
  }

  testWidgets('la hoja enseña el catálogo con su tipo',
      (WidgetTester tester) async {
    await abrirYElegir(tester, catalogo, (t) async {
      expect(find.text('Demuestra interés en la asignación'), findsOneWidget);
      expect(find.text('Fortaleza'), findsOneWidget);
      expect(find.text('Le cuesta entregar a tiempo'), findsOneWidget);
    });
  });

  testWidgets('elegir una del catálogo devuelve su id, no su texto',
      (WidgetTester tester) async {
    // El backend las distingue por la URL: el id va en la ruta. Devolver el
    // texto crearía una frase suelta en vez de apuntar a la del colegio.
    final elegida = await abrirYElegir(tester, catalogo, (t) async {
      await t.tap(find.text('Le cuesta entregar a tiempo'));
    });

    expect(elegida?.esDelCatalogo, isTrue);
    expect(elegida?.fraseId, 2);
    expect(elegida?.texto, isNull);
  });

  testWidgets('el buscador filtra sin acentos', (WidgetTester tester) async {
    await abrirYElegir(tester, catalogo, (t) async {
      await t.enterText(find.byType(TextField).first, 'interes');
      await t.pumpAndSettle();

      expect(find.text('Demuestra interés en la asignación'), findsOneWidget);
      expect(find.text('Le cuesta entregar a tiempo'), findsNothing);
    });
  });

  testWidgets('lo que no dice ninguna frase lo explica, no deja el hueco',
      (WidgetTester tester) async {
    await abrirYElegir(tester, catalogo, (t) async {
      await t.enterText(find.byType(TextField).first, 'zzz');
      await t.pumpAndSettle();

      expect(find.text('Ninguna frase dice eso.'), findsOneWidget);
    });
  });

  testWidgets('se puede escribir una a mano', (WidgetTester tester) async {
    final elegida = await abrirYElegir(tester, catalogo, (t) async {
      await t.enterText(find.byType(TextField).last, '  Mejoró mucho  ');
      await t.pumpAndSettle();
      await t.tap(find.text('Poner'));
    });

    expect(elegida?.esDelCatalogo, isFalse);
    // Sin los espacios de los lados: van a un boletín.
    expect(elegida?.texto, 'Mejoró mucho');
  });

  testWidgets('sin escribir nada no se puede poner una a mano',
      (WidgetTester tester) async {
    await abrirYElegir(tester, catalogo, (t) async {
      final boton = t.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
    });
  });

  testWidgets('un año sin catálogo lo dice y deja escribir igual',
      (WidgetTester tester) async {
    // Que el colegio no haya cargado frases no es motivo para no poder poner
    // ninguna: el texto libre sigue estando.
    await abrirYElegir(tester, const [], (t) async {
      expect(
        find.textContaining('Este año no tiene frases cargadas'),
        findsOneWidget,
      );
      expect(find.text('Poner'), findsOneWidget);
    });
  });
}
