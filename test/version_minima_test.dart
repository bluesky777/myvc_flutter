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

    // Se mira el nombre de la ruta que sale y no se monta la pantalla: montar
    // '/login' o '/muro' de verdad pide los blocs y la sesión, y lo que se
    // comprueba aquí es la puerta, no lo que hay detrás. Que detrás está la
    // pantalla de actualizar lo fija la prueba de más abajo.
    test('con la versión corta, se desvía a actualizar', () {
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      for (final nombre in ['/muro', '/notas', '/usuarios', '/disciplina']) {
        expect(ruta(nombre).settings.name, '/actualizar',
            reason: '$nombre tenía que desviarse');
      }
    });

    test('el login se deja pasar, para quien tiene dos colegios', () {
      // Son dieciséis colegios y una sola app, y el número lo pone cada
      // colegio en su servidor. Sin esta salida, a quien le bloquee el primero
      // no le quedaría forma de llegar a la pantalla de entrar para usar el
      // segundo, que sí acepta su versión. No debilita nada: entrar vuelve a
      // leer el número, y si el colegio nuevo también lo exige, la puerta se
      // cierra otra vez en cuanto se sale del login.
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      expect(ruta('/login').settings.name, '/login');
      expect(ruta('/').settings.name, '/');
    });

    testWidgets('y lo que se monta al desviar es la pantalla de actualizar',
        (WidgetTester tester) async {
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      await tester.pumpWidget(MaterialApp(home: Builder(
        builder: (_) => Navigator(onGenerateRoute: (_) => ruta('/muro')),
      )));
      await tester.pump();

      expect(find.byType(ActualizarScreen), findsOneWidget);
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

    testWidgets('no deja seguir usando este colegio: ni «ahora no» ni «continuar»',
        (WidgetTester tester) async {
      // Es lo que la hace servir para algo: si con la versión vieja se puede
      // seguir entrando, el endpoint viejo sigue haciendo falta.
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      await tester.pumpWidget(const MaterialApp(home: ActualizarScreen()));
      await tester.pump();

      expect(find.textContaining('Ahora no'), findsNothing);
      expect(find.textContaining('Continuar'), findsNothing);
    });

    testWidgets('pero sí deja salir a otro colegio, que no es lo mismo',
        (WidgetTester tester) async {
      // La distinción es el fondo de esta pantalla: no se puede seguir usando
      // el colegio que bloquea —eso haría inútil el bloqueo— pero sí se puede
      // salir de él. Quien tiene sesión guardada del colegio atrasado ni
      // siquiera llega al login, así que sin este botón se queda encerrado por
      // un colegio que ni siquiera es el que quería usar. Y la tienda no le
      // sirve si la versión que ese colegio exige todavía no ha salido.
      VersionMinima.nuestra = 11;
      VersionMinima.tomarDe({'version_minima_app': 12});

      await tester.pumpWidget(const MaterialApp(home: ActualizarScreen()));
      await tester.pump();

      expect(find.textContaining('otro colegio'), findsOneWidget);
    });
  });
}
