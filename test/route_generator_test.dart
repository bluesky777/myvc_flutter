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
