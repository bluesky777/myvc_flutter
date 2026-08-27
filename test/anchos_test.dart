import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';

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

void main() {
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
