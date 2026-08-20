import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';
import 'package:myvc_flutter/Screens/RouteGenerator.dart';

void main() {
  group('una ruta que no existe', () {
    testWidgets('lo dice, en vez de llevar calladamente al panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: RouteGenerator.generateRoute,
        // Igual que main.dart, y por lo mismo: sin esto Flutter monta además
        // la ruta '/' por debajo —parte la ruta por tramos—, que es el login y
        // aquí no viene a cuento.
        onGenerateInitialRoutes: (ruta) => [
          RouteGenerator.generateRoute(RouteSettings(name: ruta)),
        ],
        initialRoute: '/panle-mal-escrito',
      ));
      await tester.pump();

      expect(find.text('Ruta desconocida'), findsOneWidget);
      expect(
        find.textContaining('/panle-mal-escrito'),
        findsOneWidget,
        reason: 'el nombre equivocado tiene que salir, que es lo que se busca',
      );
      expect(find.byType(PanelScreen), findsNothing);
    });
  });
}
