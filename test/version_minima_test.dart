import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Screens/ActualizarScreen.dart';
import 'package:myvc_flutter/Screens/RouteGenerator.dart';
import 'package:myvc_flutter/Utils/VersionMinima.dart';

void main() {
  setUp(() {
    VersionMinima.limpiar();
    VersionMinima.nuestra = null;
    VersionMinima.paquete = null;
  });

  group('cuándo se queda corta', () {
    test('cuando el colegio pide una más nueva', () {
      expect(VersionMinima.esCorta(exigida: 12, nuestra: 11), isTrue);
    });

    test('la justa vale, y las de más arriba también', () {
      expect(VersionMinima.esCorta(exigida: 12, nuestra: 12), isFalse);
      expect(VersionMinima.esCorta(exigida: 12, nuestra: 40), isFalse);
    });
  });

  // Estas cuatro son el contrato, no casos raros: mientras el campo no se
  // entienda, la app entra. Un .env mal puesto en un colegio no puede dejar a
  // ese colegio entero fuera de la app. Ver docs/backend-pendiente.md §4.
  group('ante la duda, se entra', () {
    test('si el servidor no dice nada', () {
      expect(VersionMinima.esCorta(exigida: null, nuestra: 3), isFalse);
    });

    test('si lo que dice no es un entero positivo', () {
      expect(VersionMinima.esCorta(exigida: 0, nuestra: 3), isFalse);
      expect(VersionMinima.esCorta(exigida: -5, nuestra: 3), isFalse);
    });

    test('si no se sabe la versión propia', () {
      // Pasa en la web y en las pruebas, donde no hay paquete instalado que
      // preguntar.
      expect(VersionMinima.esCorta(exigida: 99, nuestra: null), isFalse);
      expect(VersionMinima.esCorta(exigida: 99, nuestra: 0), isFalse);
    });

    test('un campo con basura dentro no bloquea a nadie', () {
      VersionMinima.nuestra = 3;

      VersionMinima.tomarDe({'version_minima_app': 'la última'});
      expect(VersionMinima.bloquea, isFalse);

      VersionMinima.tomarDe({'otra_cosa': 12});
      expect(VersionMinima.bloquea, isFalse);

      VersionMinima.tomarDe('no es un mapa');
      expect(VersionMinima.bloquea, isFalse);

      VersionMinima.tomarDe(null);
      expect(VersionMinima.bloquea, isFalse);
    });
  });

  group('un número altísimo sí bloquea', () {
    test('porque desde aquí no se distingue de un colegio exigente', () {
      // Es deliberado: adivinar cuál es un dedazo sería lo contrario de lo que
      // hace fiable esta comprobación. La defensa contra el dedazo está en el
      // servidor, que sube ese número una vez por retirada.
      VersionMinima.nuestra = 3;
      VersionMinima.tomarDe({'version_minima_app': 999999999});

      expect(VersionMinima.bloquea, isTrue);
    });
  });

  group('el número del servidor', () {
    test('se lee aunque llegue como cadena, que lo decide PDO', () {
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': '12'});

      expect(VersionMinima.exigida, 12);
      expect(VersionMinima.bloquea, isTrue);
    });

    test('cerrar sesión lo olvida: es del colegio, no del teléfono', () {
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});
      expect(VersionMinima.bloquea, isTrue);

      VersionMinima.limpiar();

      expect(VersionMinima.exigida, isNull);
      expect(VersionMinima.bloquea, isFalse);
    });
  });

  group('la puerta', () {
    Route<dynamic> ruta(String nombre) =>
        RouteGenerator.generateRoute(RouteSettings(name: nombre));

    testWidgets('con la versión corta, cualquier ruta lleva a actualizar',
        (WidgetTester tester) async {
      // La comprobación vive en el router y no en cada pantalla: una puerta
      // que se mira en veinte sitios es una puerta que un día se queda sin
      // mirar en uno.
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      for (final nombre in ['/muro', '/notas', '/usuarios', '/login', '/']) {
        await tester.pumpWidget(MaterialApp(home: Builder(
          builder: (_) => Navigator(
            onGenerateRoute: (_) => ruta(nombre),
          ),
        )));
        await tester.pump();

        expect(find.byType(ActualizarScreen), findsOneWidget,
            reason: '$nombre tenía que llevar a la pantalla de actualizar');
      }
    });

    testWidgets('con la versión al día no estorba', (WidgetTester tester) async {
      VersionMinima.nuestra = 12;
      VersionMinima.tomarDe({'version_minima_app': 12});

      // Se pide una ruta que no existe a propósito: lo que se comprueba es
      // que la puerta deja pasar, y la pantalla de «ruta desconocida» se monta
      // sin necesitar sesión ni blocs detrás.
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: RouteGenerator.generateRoute,
        onGenerateInitialRoutes: (r) =>
            [RouteGenerator.generateRoute(RouteSettings(name: r))],
        initialRoute: '/una-que-no-existe',
      ));
      await tester.pump();

      expect(find.byType(ActualizarScreen), findsNothing);
      expect(find.text('Ruta desconocida'), findsOneWidget);
    });
  });

  group('la pantalla de actualizar', () {
    testWidgets('dice que no es culpa de quien la ve, y los dos números',
        (WidgetTester tester) async {
      // Los números no son adorno: sin ellos, «no me deja entrar» no se puede
      // diagnosticar por teléfono desde secretaría.
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      await tester.pumpWidget(const MaterialApp(home: ActualizarScreen()));
      await tester.pump();

      expect(find.textContaining('Hay que actualizar'), findsOneWidget);
      expect(find.textContaining('No es un fallo tuyo'), findsOneWidget);
      expect(find.textContaining('versión 11'), findsOneWidget);
      expect(find.textContaining('la 12'), findsOneWidget);
    });

    testWidgets('no tiene salida: ni «ahora no» ni «continuar»',
        (WidgetTester tester) async {
      // Es lo que la hace servir para algo: si con la versión vieja se puede
      // seguir entrando, el endpoint viejo sigue haciendo falta.
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      await tester.pumpWidget(const MaterialApp(home: ActualizarScreen()));
      await tester.pump();

      expect(find.textContaining('Ahora no'), findsNothing);
      expect(find.textContaining('Continuar'), findsNothing);
      expect(find.textContaining('Cerrar'), findsNothing);
    });
  });
}
