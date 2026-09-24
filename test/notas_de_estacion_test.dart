import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Models/NotaDeEstacionModel.dart';
import 'package:myvc_flutter/Screens/CodigoDeLaHojaScreen.dart';
import 'package:myvc_flutter/Screens/NotasDeEstacionScreen.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las notas entre estaciones (pantalla 12) y el código tecleado (la 03).
///
/// **Las dos en el mismo archivo a propósito**: son las dos pantallas que
/// escribió esta sesión, y partirlas en dos ficheros no las probaría mejor.
///
/// Lo que aquí se vigila es de tres clases:
///
/// 1. **Que no se llame al servidor con el interruptor apagado.** Las nueve
///    rutas `estaciones/*` están en `main` de `8myvc` y sin desplegar: una
///    llamada por apertura son dieciséis colegios gastando un 404 sobre un
///    hosting de un núcleo.
/// 2. **Que lo apagado diga POR QUÉ lo está**, nunca «no disponible» —que no se
///    puede ni pedir ni arreglar—.
/// 3. **Las cuatro reglas de §2.10**, que son las que impiden que esto se
///    convierta en un chat: quién puede resolver lo dice el servidor, la nota
///    reservada cuenta y no se lee, y la familia no ve nada de esto.

/// Un servidor que apunta qué le piden y no contesta nada útil.
///
/// Aquí sirve para lo contrario de lo habitual: lo que se comprueba es que
/// **no le pidan nada**.
class ServidorQueApunta extends Server {
  final List<String> pedidos = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  @override
  Future post(String direccion, params) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  @override
  Future put(String direccion, params) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }
}

NotaDeEstacion unaNota({
  int id = 1,
  String? texto = 'Trae el saldo de junio pendiente',
  bool reservada = false,
  bool pendiente = false,
  bool resuelta = false,
  String? de = 'Tesorería',
  String? cuando = '2026-09-16 08:14:00',
  bool puedoResolverla = false,
}) =>
    NotaDeEstacion(
      id: id,
      texto: texto,
      reservada: reservada,
      pendiente: pendiente,
      resuelta: resuelta,
      de: de,
      cuando: cuando,
      puedoResolverla: puedoResolverla,
    );

Widget laPantallaDeNotas({
  required Server servidor,
  Map<int, List<NotaDeEstacion>>? notas,
}) =>
    MaterialApp(
      home: NotasDeEstacionScreen(
        personaId: 41,
        nombre: 'Laura Mejía',
        pasos: const [],
        nroDeMiEstacion: 2,
        notasYaTraidas: notas,
        servidor: servidor,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.limpiar();
    PendientesEstaciones.comoDeFabrica();
    SharedPreferences.setMockInitialValues({});
  });

  group('las cuentas del globo, que son las que se leen con sol en la cara',
      () {
    test('el número nunca va solo: al lado van las mismas palabras', () {
      final notas = [
        unaNota(id: 1),
        unaNota(id: 2, pendiente: true),
      ];

      expect(loQueDicenLasNotas('Tesorería', notas),
          '2 notas en Tesorería, una sin resolver');
      expect(algoSinResolverEn(notas), isTrue);
    });

    test('pizarra cuando solo hay algo escrito, ámbar cuando algo pide algo',
        () {
      expect(algoSinResolverEn([unaNota()]), isFalse);
      expect(algoSinResolverEn([unaNota(pendiente: true)]), isTrue);
      // Una pendiente ya resuelta deja de pintar ámbar: es lo que apaga el
      // globo, y por eso hacía falta la novena ruta.
      expect(
        algoSinResolverEn([unaNota(pendiente: true, resuelta: true)]),
        isFalse,
      );
    });

    test('las reservadas cuentan para el número', () {
      // Regla 4: **esconder que una nota existe es peor que esconder su
      // contenido**. Quien ve el globo y no puede abrirlo sabe a quién
      // preguntarle; quien no ve nada, no pregunta.
      final cuentas = contarLasNotas([
        unaNota(id: 1),
        unaNota(id: 2, reservada: true, texto: null),
      ]);

      expect(cuentas.total, 2);
      expect(cuentas.reservadas, 1);
      expect(
          loQueDicenLasNotas('Orientación', [
            unaNota(id: 1),
            unaNota(id: 2, reservada: true, texto: null),
          ]),
          contains('2 notas'));
    });

    test('el resumen de toda la ficha nombra lo que no se puede leer', () {
      final resumen = elResumenDeLasNotas({
        2: [unaNota(id: 1)],
        5: [
          unaNota(id: 2, pendiente: true),
          unaNota(id: 3, reservada: true, texto: null),
        ],
      });

      expect(resumen, contains('3 notas'));
      expect(resumen, contains('en 2 estaciones'));
      expect(resumen, contains('una sin resolver'));
      expect(resumen, contains('reservada'));
    });

    test('sin notas no hay frase que enseñar', () {
      expect(elResumenDeLasNotas(const {}), '');
      expect(elResumenDeLasNotas({2: const []}), '');
    });
  });

  group('con el interruptor apagado no se le pregunta nada al servidor', () {
    testWidgets('abrir las notas no gasta ni una llamada', (tester) async {
      final servidor = ServidorQueApunta();

      await tester.pumpWidget(laPantallaDeNotas(servidor: servidor));
      await tester.pumpAndSettle();

      expect(servidor.pedidos, isEmpty);
    });

    testWidgets('y lo apagado dice por qué, no «no disponible»',
        (tester) async {
      await tester.pumpWidget(laPantallaDeNotas(servidor: ServidorQueApunta()));
      await tester.pumpAndSettle();

      expect(find.text('Las notas todavía no se leen aquí'), findsOneWidget);
      expect(find.textContaining('servidor del colegio'), findsWidgets);
      expect(find.textContaining('no disponible'), findsNothing);

      // Y **no** se dice que no hay notas: una lista vacía y «esto todavía no
      // existe» se leen igual y no son lo mismo.
      expect(find.textContaining('Nadie ha dejado nada escrito'), findsNothing);
    });

    testWidgets('dejar una nota está apagado y con su motivo', (tester) async {
      await tester.pumpWidget(laPantallaDeNotas(servidor: ServidorQueApunta()));
      await tester.pumpAndSettle();

      expect(find.text('Dejar una nota'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Dejar la nota'), findsNothing);
      expect(find.textContaining('Está escrita y probada'), findsOneWidget);
    });
  });

  group('lo que la familia no ve, y la nota que no se lee', () {
    testWidgets('se dice antes de leer nada que esto es entre el personal',
        (tester) async {
      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          2: [unaNota()]
        },
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Esto lo escribe y lo lee el personal. La familia no lo ve nunca.',
        ),
        findsOneWidget,
      );
      // Regla 3, dicha donde alguien se podría equivocar: encima de la casilla.
      expect(
        find.textContaining('no va aquí: va en su casilla'),
        findsOneWidget,
      );
    });

    testWidgets('la reservada sale con candado, cuenta y no enseña su texto',
        (tester) async {
      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          5: [
            unaNota(id: 1, texto: 'Saldo de junio'),
            unaNota(
              id: 2,
              reservada: true,
              texto: null,
              de: 'Orientación',
            ),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Saldo de junio'), findsOneWidget);
      expect(find.text('Reservada'), findsOneWidget);
      expect(
        find.textContaining('El texto de esta nota no te toca leerlo'),
        findsOneWidget,
      );
      // Y se dice a quién preguntarle, que es para lo que sirve saber que
      // existe.
      expect(find.textContaining('Orientación'), findsWidgets);
      expect(find.textContaining('2 notas'), findsWidgets);
    });

    testWidgets('cada estado lleva icono Y palabra, nunca solo el color',
        (tester) async {
      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          2: [
            unaNota(id: 1, pendiente: true),
            unaNota(id: 2, pendiente: true, resuelta: true),
            unaNota(id: 3),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sin resolver'), findsOneWidget);
      expect(find.text('Resuelta'), findsOneWidget);
      expect(find.text('Solo constancia'), findsOneWidget);
    });

    testWidgets('el globo se pinta con la silueta de bocadillo',
        (tester) async {
      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          2: [unaNota(pendiente: true)]
        },
      ));
      await tester.pumpAndSettle();

      final globo = tester.widget<GloboDeNotas>(find.byType(GloboDeNotas));
      expect(globo.cuantas, 1);
      expect(globo.algoSinResolver, isTrue);
    });
  });

  group('resolver una nota: el permiso lo calcula el servidor, no la app', () {
    testWidgets('sin la ruta desplegada, el botón está apagado con su motivo',
        (tester) async {
      // Encendido de fábrica desde el 24 sep 2026; el camino apagado sigue
      // existiendo y se prueba apagándolo a mano.
      PendientesEstaciones.resolverUnaNota = false;
      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          2: [unaNota(pendiente: true, puedoResolverla: true)]
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Darla por resuelta'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Darla por resuelta'),
        findsNothing,
      );
      expect(
        find.textContaining('lo que apaga el globo ámbar'),
        findsOneWidget,
      );
    });

    testWidgets('a quien no le toca, el botón se ve apagado y NO escondido',
        (tester) async {
      PendientesEstaciones.resolverUnaNota = true;

      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          5: [unaNota(pendiente: true, de: 'Tesorería', puedoResolverla: false)]
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Darla por resuelta'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Darla por resuelta'),
        findsNothing,
      );
      expect(find.textContaining('La escribió Tesorería'), findsOneWidget);
    });

    testWidgets('y la app NO escribe la lista de quién puede', (tester) async {
      // Los ids de los roles no son los mismos en los dieciséis colegios y la
      // regla ya se ensanchó una vez —a los superusuarios, el 20 sep 2026—. Una
      // lista de roles escrita aquí envejecería en silencio: quien la escribe
      // con sus palabras es el 403 del servidor, y eso es lo que se pinta.
      PendientesEstaciones.resolverUnaNota = true;

      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          5: [unaNota(pendiente: true, puedoResolverla: false)]
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Secretar'), findsNothing);
      expect(find.textContaining('Rector'), findsNothing);
      expect(find.textContaining('administrador'), findsNothing);
    });

    testWidgets('a quien sí le toca, el botón se enciende', (tester) async {
      PendientesEstaciones.resolverUnaNota = true;

      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          2: [unaNota(pendiente: true, puedoResolverla: true)]
        },
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Darla por resuelta'),
        findsOneWidget,
      );
    });

    testWidgets('una ya resuelta no se resuelve dos veces', (tester) async {
      PendientesEstaciones.resolverUnaNota = true;

      await tester.pumpWidget(laPantallaDeNotas(
        servidor: ServidorQueApunta(),
        notas: {
          2: [unaNota(pendiente: true, resuelta: true, puedoResolverla: true)]
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Darla por resuelta'), findsNothing);
      expect(find.text('Resuelta'), findsOneWidget);
    });

    testWidgets('lo que conteste el servidor se pinta tal cual',
        (tester) async {
      // **Es lo único que se puede comprobar hoy de ese camino**, y es lo que
      // importa: con `Interruptores.estaciones` en `const false` la escritura
      // vuelve con su frase antes de salir del teléfono, y la pantalla la
      // enseña sin tocarla. El día del despliegue, la frase que llegue por ahí
      // será el 403 con el criterio escrito dentro —«esta nota puede darla por
      // resuelta quien la escribió, o…»—, que es lo que convierte un botón
      // muerto en una instrucción.
      PendientesEstaciones.resolverUnaNota = true;
      final servidor = ServidorQueApunta();

      await tester.pumpWidget(laPantallaDeNotas(
        servidor: servidor,
        notas: {
          2: [unaNota(pendiente: true, puedoResolverla: true)]
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Darla por resuelta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Las estaciones todavía no están disponibles.'),
        findsOneWidget,
      );
      // Y ni con el botón encendido se llama al servidor mientras el módulo
      // esté apagado.
      expect(servidor.pedidos, isEmpty);
    });
  });

  group('el código de la hoja, tecleado y sin cámara (pantalla 03)', () {
    testWidgets('no se llama al servidor, y se dice por qué está apagado',
        (tester) async {
      final servidor = ServidorQueApunta();

      await tester.pumpWidget(
        MaterialApp(home: CodigoDeLaHojaScreen(servidor: servidor)),
      );
      await tester.pumpAndSettle();

      expect(servidor.pedidos, isEmpty);
      expect(
        find.text('Buscar por el código todavía no está encendido'),
        findsOneWidget,
      );
      expect(find.textContaining('no disponible'), findsNothing);

      // El campo no se puede teclear y el botón no se puede tocar: apagados a
      // la vista, que es distinto de escondidos.
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('y se dice que la cámara falta a propósito', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CodigoDeLaHojaScreen(servidor: ServidorQueApunta())),
      );
      await tester.pumpAndSettle();

      // Quien abre esto esperando escanear tiene que saber que no es un olvido:
      // pedir la cámara cambia los permisos en las dos tiendas y puede dejar la
      // app fuera de las tablets sin cámara, que son las del patio.
      expect(find.textContaining('no hay escáner a propósito'), findsOneWidget);
      expect(find.textContaining('tablets sin cámara'), findsOneWidget);
    });

    testWidgets(
        'se ofrece el código del papel viejo, que el servidor contempla',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CodigoDeLaHojaScreen(servidor: ServidorQueApunta())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('el del papel viejo'), findsWidgets);
    });

    test('el código se manda como está impreso, sin arreglarlo', () {
      // Mayúsculas y espacios sí: es lo que hace el teclado del teléfono. Los
      // guiones no se tocan — el servidor compara contra `codigo` y
      // `codigo_anterior` tal cual, y un código «arreglado» por la app sería un
      // 404 que nadie sabría explicar.
      expect(elCodigoTecleado('  2027-4k7m2 '), '2027-4K7M2');
      expect(elCodigoTecleado('20274K7M2'), '20274K7M2');
      expect(elCodigoTecleado('   '), '');
    });

    test('un 409 escrito no se confunde con quedarse sin señal', () {
      // El 409 es «este papel todavía no es de nadie» y trae escrito qué hacer;
      // pintarlo como una avería mandaría a alguien a buscar señal cuando lo
      // que falta es una firma en secretaría.
      expect(
        pareceFaltaDeSenal(
          Exception('Ese formulario todavía no está atado a ningún alumno.'),
        ),
        isFalse,
      );
      expect(pareceFaltaDeSenal(http.ClientException('fallo de red')), isTrue);
      expect(
        pareceFaltaDeSenal(
          Exception('SocketException: Failed host lookup: micolegio.edu.co'),
        ),
        isTrue,
      );
    });

    test('el recorrido que llegue se pinta con lo que mande el servidor', () {
      // §2.8: ni un nombre ni un número cableados. Si el colegio llama
      // «Tesorería» a su paso 5, eso es lo que se lee.
      final ficha = FichaDeEstacion.fromJson({
        'alumno': {'id': 41, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'codigo': '2027-4K7M2',
        'pasos': [
          {'nro': 5, 'nombre': 'Tesorería', 'estado': 'Falta'},
        ],
      });

      expect(ficha.codigo, '2027-4K7M2');
      expect(ficha.pasos.single.nombre, 'Tesorería');
      expect(ficha.pasos.single.estado, EstadoDelPaso.pendiente);
    });
  });
}
