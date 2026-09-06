import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';

/// La animación del menú, la de siempre.
///
/// Estas pruebas miden dónde queda el contenido con el menú abierto. Están
/// aquí porque la migración a flutter_zoom_drawer 3 cambió `Style1` por
/// `style1` creyendo que era la misma cosa con otra mayúscula, y era otro
/// estilo: el contenido dejó de deslizarse y de encogerse, y se quedó girando
/// sobre su esquina. Nadie lo vio en dos semanas porque ninguna prueba miraba
/// la animación. Ahora una la mira.
void main() {
  setUp(AuthService.limpiar);

  const contenido = Key('contenido');

  /// Un teléfono de 400x800, y una pantalla vacía con el menú detrás.
  Future<ZoomDrawerController> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AuthService.user = UserAutenticado(username: 'agomez', tipo: 'Profesor');

    final controller = ZoomDrawerController();
    await tester.pumpWidget(MaterialApp(
      home: PantallaConMenu(
        controller: controller,
        pantalla: Scaffold(key: contenido, body: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    return controller;
  }

  testWidgets('cerrado, el contenido ocupa toda la pantalla',
      (WidgetTester tester) async {
    await montar(tester);

    expect(tester.getRect(find.byKey(contenido)),
        const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('abierto, el contenido se desliza, se encoge y se inclina',
      (WidgetTester tester) async {
    final controller = await montar(tester);

    controller.open!();
    await tester.pumpAndSettle();

    final arribaIzquierda = tester.getTopLeft(find.byKey(contenido));
    final arribaDerecha = tester.getTopRight(find.byKey(contenido));

    // Se desliza: la esquina de arriba a la izquierda ya no está en el borde.
    // Con el estilo equivocado se quedaba en (0, 0), porque el contenido solo
    // giraba sobre ella.
    expect(arribaIzquierda.dx, greaterThan(200),
        reason: 'el contenido no se deslizó a la derecha');

    // Se encoge: el borde de arriba mide un 80 % de los 400 px.
    final ancho = (arribaDerecha - arribaIzquierda).distance;
    expect(ancho, closeTo(320, 1), reason: 'el contenido no se encogió');

    // Se inclina: el borde de arriba sube hacia la derecha, como en la
    // captura de antes de la migración.
    expect(arribaDerecha.dy, lessThan(arribaIzquierda.dy - 30),
        reason: 'el contenido no se inclinó');
  });

  testWidgets('el menú va de lado a lado detrás, y no se mueve',
      (WidgetTester tester) async {
    final controller = await montar(tester);

    controller.open!();
    // A mitad de la animación: si el menú se deslizara con el contenido,
    // aquí estaría a medio camino.
    await tester.pump(const Duration(milliseconds: 125));

    expect(tester.getTopLeft(find.byType(MenuLateral)), Offset.zero,
        reason: 'el menú se está deslizando');

    await tester.pumpAndSettle();

    // Con el ancho que trae el paquete, unos 250 px, el fondo azul del menú
    // no cubría todo lo que la inclinación deja ver.
    expect(tester.getSize(find.byType(MenuLateral)), const Size(400, 800));
  });

  testWidgets('tocar el contenido con el menú abierto lo cierra',
      (WidgetTester tester) async {
    final controller = await montar(tester);

    controller.open!();
    await tester.pumpAndSettle();

    // Un punto del contenido que sigue dentro de la pantalla después de
    // deslizarlo: el centro de verdad queda fuera del borde derecho.
    final caja = tester.renderObject<RenderBox>(find.byKey(contenido));
    await tester.tapAt(caja.localToGlobal(const Offset(50, 400)));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(contenido)),
        const Rect.fromLTWH(0, 0, 400, 800));
  });
}
