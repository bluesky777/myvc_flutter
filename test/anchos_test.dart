import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';

/// Mide [Anchos.bandaDeLogin] en una pantalla del tamaño que se le diga.
Future<double> bandaEn(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late double medida;

  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      medida = Anchos.bandaDeLogin(context);
      return const SizedBox();
    }),
  ));

  return medida;
}

/// Mide cuánto acaba ocupando lo que se mete en una [ColumnaDeFicha].
Future<double> fichaEn(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ColumnaDeFicha(
        child: ListView(children: const [SizedBox(height: 20)]),
      ),
    ),
  ));

  return tester.getSize(find.byType(ListView)).width;
}

void main() {
  group('la columna de una ficha', () {
    testWidgets('en un teléfono ocupa todo, o sea que no hace nada',
        (tester) async {
      // Lo que la hace segura de meter en una pantalla que ya funciona: la
      // pantalla es más estrecha que el tope, así que no llega a apretar.
      expect(await fichaEn(tester, const Size(400, 800)), 400);
    });

    testWidgets('en una tablet se queda en el tope', (tester) async {
      // Los tres contadores son Expanded y se reparten lo que haya: a pantalla
      // completa cada uno mediría medio palmo.
      expect(await fichaEn(tester, const Size(1729, 1080)), Anchos.ficha);
    });

    testWidgets('una ficha respira más que un formulario', (tester) async {
      // No es el mismo número a propósito: una ficha lleva bloques dentro y un
      // formulario un renglón que el ojo sigue de punta a punta. Si alguien los
      // unifica, esto se pone en rojo y le obliga a leer el porqué.
      expect(Anchos.ficha, greaterThan(Anchos.formulario));
    });
  });

  group('la banda del login', () {
    testWidgets('en un teléfono es el 80% de siempre', (tester) async {
      // Lo que había antes de que existiera el tope. En un teléfono no cambia
      // nada, y ésa es la mitad del asunto: esto no puede tocar la pantalla que
      // usa todo el mundo.
      expect(await bandaEn(tester, const Size(400, 800)), 320);
    });

    testWidgets('en un teléfono grande sigue siendo proporcional',
        (tester) async {
      expect(await bandaEn(tester, const Size(500, 900)), 400);
    });

    testWidgets('en una tablet deja de crecer', (tester) async {
      // Un Pixel Tablet en horizontal. Sin tope, el campo de usuario mediría
      // 1.383 px: el icono queda a un palmo del texto y el renglón no se lee.
      expect(await bandaEn(tester, const Size(1729, 1080)), Anchos.formulario);
    });

    testWidgets('el tope no depende de la orientación', (tester) async {
      // La misma tablet de pie. Que gire no puede cambiar cuánto mide un campo
      // de texto, porque lo que lo limita es el ojo y no la pantalla.
      expect(await bandaEn(tester, const Size(1080, 1729)), Anchos.formulario);
    });

    testWidgets('nunca se pasa del ancho de la pantalla', (tester) async {
      // Un teléfono pequeño y viejo: aquí manda la proporción, no el tope, y el
      // control tiene que seguir cabiendo con su margen a los lados.
      final banda = await bandaEn(tester, const Size(320, 480));

      expect(banda, lessThan(320));
      expect(banda, 256);
    });
  });
}
