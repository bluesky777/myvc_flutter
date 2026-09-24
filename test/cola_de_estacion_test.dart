import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/ColaDeEstacionScreen.dart';
import 'package:myvc_flutter/Screens/SalteadoScreen.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// La cola de una estación y el que llega salteado —pantallas 02 y 08—.
///
/// ## Lo que aquí se comprueba es lo que NO falla cuando está mal
///
/// Las dos mitades de este fichero vigilan la misma clase de error. `getCola`
/// mandaba `atendidos_hoy` y `avisos` desde el primer día y la app **los
/// tiraba**: nada reventaba, no había ningún 500, no salía ningún renglón
/// rojo. Simplemente la cabecera enseñaba dos cifras en vez de tres y **el
/// salteado que el servidor calcula no se veía en la cola**. Un fallo que se
/// ve vacío no lo encuentra nadie mirando la pantalla; lo encuentra una prueba
/// que lee el contrato.
///
/// ## Y por eso las lecturas son funciones sueltas
///
/// `Interruptores.estaciones` es `const false`, así que todo lo que hay detrás
/// de la guarda —el `jsonDecode`, los avisos, la cabecera— es código que
/// **ninguna prueba alcanza llamando a las funciones que piden**. Por eso
/// [leerLaCola], [leerLosAvisos], [leerLasEstaciones] y [leerLaHuella] son
/// públicas: descubrir el día del despliegue que la cabecera se leía mal sería
/// descubrirlo con dieciséis colegios encima.

/// Un servidor que apunta qué le piden. Aquí lo que se comprueba es que **no
/// le pidan nada** mientras las nueve rutas no estén desplegadas.
class ServidorQueApunta extends Server {
  final List<String> pedidos = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  @override
  Future put(String direccion, params) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  @override
  Future post(String direccion, params) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }
}

/// La respuesta de `getCola` tal como la arma el controlador, con los nombres
/// de clave leídos de `EstacionesController.php` el 20 sep 2026.
String colaDelServidor() => jsonEncode({
      'nro': 2,
      'nombre': 'Documentos',
      'al_dia_at': '2026-09-20 08:40:00',
      'atendidos_hoy': 12,
      'cola': [
        {
          'alumno_id': 31,
          'nombres': 'Laura',
          'apellidos': 'Mejía',
          'documento': '1093',
          'grupo': '5A',
          'llego_at': '2026-09-20 08:31:00',
          'devuelto_antes': true,
          'avisos': [
            {'tipo': 'devuelto', 'texto': 'Ya estuvo aquí y se le devolvió.'},
          ],
          'notas_total': 2,
          'notas_pendientes': 1,
        },
        {
          'alumno_id': 44,
          'nombres': 'Andrés',
          'apellidos': 'Rojas',
          'llego_at': '2026-09-20 08:35:00',
          'devuelto_antes': false,
          'avisos': [
            {
              'tipo': 'salteado',
              'texto': 'Cerró una estación posterior sin pasar por ésta.',
            },
          ],
          'notas_total': 0,
          'notas_pendientes': 0,
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PendientesEstaciones.comoDeFabrica);

  group('la cola ya recibía tres cosas que se tiraban', () {
    test('la cabecera entera, y «atendidos hoy» es la que ya llegaba', () {
      // Es la primera de las tres cifras del diseño (§1, pantalla 02) y no
      // hace falta pedirle nada al servidor: la manda `getCola` desde el
      // primer día y esta capa se quedaba sólo con `cola`.
      final cola = leerLaCola(colaDelServidor());

      expect(cola.nro, 2);
      expect(cola.nombre, 'Documentos');
      expect(cola.alDiaAt, '2026-09-20 08:40:00');
      expect(cola.atendidosHoy, 12);
      expect(cola.fila.length, 2);
      expect(cola.fila.first.persona.nombreCompleto, 'Laura Mejía');
    });

    test('sin «atendidos_hoy» la cifra es null y NO un cero', () {
      // Cero es «hoy no ha pasado nadie todavía», que es una noticia del día;
      // null es «este servidor no lo dice». Pintar un cero que nadie contó es
      // mentir barato, y encima sobre la cifra que mide si el tapón es tuyo.
      final cola = leerLaCola(jsonEncode({'cola': []}));

      expect(cola.atendidosHoy, isNull);
      expect(cola.fila, isEmpty);
    });

    test('los avisos llegan con EL TEXTO DEL SERVIDOR, no con uno de la app',
        () {
      final cola = leerLaCola(colaDelServidor());

      expect(cola.fila.first.avisos.single.tipo, 'devuelto');
      expect(
        cola.fila.first.avisos.single.texto,
        'Ya estuvo aquí y se le devolvió.',
      );
      expect(
        cola.fila.last.avisos.single.texto,
        'Cerró una estación posterior sin pasar por ésta.',
      );
    });

    test('un aviso de un tipo que esta versión no conoce se pinta igual', () {
      // El vocabulario lo pone el servidor (§2.8). Descartar lo que no
      // reconocemos haría que un aviso nuevo desapareciera sin que nadie se
      // entere, que es peor que un icono genérico.
      final avisos = leerLosAvisos([
        {'tipo': 'lo_que_venga', 'texto': 'Trae el recibo sin firmar.'},
      ]);

      expect(avisos.single.texto, 'Trae el recibo sin firmar.');
      expect(avisos.single.tipo, 'lo_que_venga');
    });

    test('sin texto no hay aviso, y sin clave tampoco revienta', () {
      // Un chip vacío ocupa sitio en una tarjeta que se mira de pie y no dice
      // nada; y el texto no se puede suplir desde aquí sin inventarlo.
      expect(
          leerLosAvisos([
            {'tipo': 'salteado'},
            {'tipo': 'salteado', 'texto': '   '},
          ]),
          isEmpty);
      expect(leerLosAvisos(null), isEmpty);
      expect(leerLosAvisos('nada'), isEmpty);
      expect(leerLaCola(jsonEncode({'cola': 'nada'})).fila, isEmpty);
      expect(leerLaCola('no soy json').fila, isEmpty);
    });

    test('el salteado lo dice el aviso del servidor, no una regla de la app',
        () {
      final cola = leerLaCola(colaDelServidor());

      expect(dicenQueSeSaltoElOrden(cola.fila.last.avisos), isTrue);
      expect(dicenQueSeSaltoElOrden(cola.fila.first.avisos), isFalse);
      expect(dicenQueSeSaltoElOrden(const []), isFalse);
    });
  });

  group('«abierta» lo dice el servidor; la app lo deducía', () {
    test('las tres respuestas son tres, y no dos', () {
      // `true`, `false` y **«no lo dijo»**. Convertir el tercero en `false`
      // diría «no armaste el recorrido» a un colegio que sí lo armó, y con un
      // servidor anterior a `campana` lo diría siempre.
      expect(
        leerLasEstaciones(jsonEncode({
          'campana': {'abierta': true},
          'estaciones': [
            {'nro': 1, 'nombre': 'Recepción'},
          ],
        })).abierta,
        isTrue,
      );
      expect(
        leerLasEstaciones(jsonEncode({
          'campana': {'abierta': false},
          'estaciones': [],
        })).abierta,
        isFalse,
      );
      expect(
        leerLasEstaciones(jsonEncode({'estaciones': []})).abierta,
        isNull,
      );
    });

    test('el tinyint llega como venga de PDO', () {
      // El mismo campo llega int en una ruta y String en otra: es la razón de
      // ser de `JsonBackend`.
      for (final crudo in [1, '1', true, 'true']) {
        expect(
          leerLasEstaciones(jsonEncode({
            'campana': {'abierta': crudo},
          })).abierta,
          isTrue,
          reason: 'con $crudo',
        );
      }
      for (final crudo in [0, '0', false, 'false']) {
        expect(
          leerLasEstaciones(jsonEncode({
            'campana': {'abierta': crudo},
          })).abierta,
          isFalse,
          reason: 'con $crudo',
        );
      }
    });

    test('y la lista sigue viniendo entera', () {
      final leido = leerLasEstaciones(jsonEncode({
        'campana': {'abierta': true},
        'estaciones': [
          {'nro': 1, 'nombre': 'Recepción'},
          {'nro': 2, 'nombre': 'Documentos', 'esperando': 4},
        ],
      }));

      expect(leido.estaciones.length, 2);
      expect(leido.estaciones.last.esperando, 4);
    });
  });

  group('la huella son TRES cifras', () {
    test('y la de «notas» es la que se cae sola', () {
      // Sin `notas`, una nota escrita en el mismo segundo en que se cerró el
      // paso anterior es invisible: `ultimo_cambio` tiene precisión de segundo
      // y el conteo de la cola no se mueve porque una nota no cambia quién
      // espera. Con dos cifras esa nota no aparece nunca.
      final huella = leerLaHuella(jsonEncode({
        'por_estacion': {
          '2': {'n': 4, 'notas': 7, 'ultimo_cambio': '2026-09-20 08:40:00'},
        },
      }));

      expect(huella[2], contains('|7|'));
      expect(huella[2], '4|7|2026-09-20 08:40:00');
    });

    test('dos huellas que sólo se diferencian en las notas NO son iguales', () {
      String deNotas(int notas) => leerLaHuella(jsonEncode({
            'por_estacion': {
              '2': {
                'n': 4,
                'notas': notas,
                'ultimo_cambio': '2026-09-20 08:40:00',
              },
            },
          }))[2]!;

      expect(deNotas(7), isNot(deNotas(8)));
    });
  });

  group('con el interruptor apagado no se le pide nada al servidor', () {
    test('la cola entera y el recorrido del colegio callan', () async {
      final servidor = ServidorQueApunta();

      final cola = await traerLaColaEntera(servidor, 2);
      final recorrido = await traerLasEstacionesDelColegio(servidor);

      expect(servidor.pedidos, isEmpty);
      expect(cola.fila, isEmpty);
      // Y lo que se contesta tampoco se inventa: ni cero atendidos ni campaña
      // cerrada. No se sabe.
      expect(cola.atendidosHoy, isNull);
      expect(recorrido.abierta, isNull);
      expect(recorrido.estaciones, isEmpty);
    });

    test('la vista estrecha de siempre sigue contestando una lista', () async {
      // `traerLaCola` y `traerLasEstaciones` se quedan porque la pantalla 01 y
      // sus pruebas las llaman así. Que sigan callando es la mitad del trato.
      final servidor = ServidorQueApunta();

      expect(await traerLaCola(servidor, 2), isEmpty);
      expect(await traerLasEstaciones(servidor), isEmpty);
      expect(servidor.pedidos, isEmpty);
    });

    test('el interruptor sigue apagado, y así tiene que seguir', () {
      expect(Interruptores.estaciones, isFalse);
    });
  });

  group('los chips de una fila', () {
    EnLaCola conAvisos(List<AvisoDeLaCola> avisos, {bool devuelto = false}) => (
          persona: PersonaEnCola.fromJson({
            'alumno_id': 31,
            'nombres': 'Laura',
            'apellidos': 'Mejía',
            'devuelto_antes': devuelto,
          }),
          avisos: avisos,
        );

    test('el texto del chip es el del servidor, tal cual', () {
      final chips = losChipsDeLaFila(conAvisos([
        (
          tipo: 'salteado',
          texto: 'Cerró una estación posterior sin pasar por ésta.',
        ),
      ]));

      expect(chips.single.texto,
          'Cerró una estación posterior sin pasar por ésta.');
      expect(chips.single.grave, isTrue);
    });

    test('«devuelto» no sale dos veces aunque lo digan los dos', () {
      // `devuelto_antes` y el aviso de tipo `devuelto` cuentan lo mismo. Dos
      // chips seguidos con la misma noticia, en una tarjeta que se mira de
      // pie, es ruido que tapa el que sí es nuevo.
      final chips = losChipsDeLaFila(conAvisos(
        [(tipo: 'devuelto', texto: 'Ya estuvo aquí y se le devolvió.')],
        devuelto: true,
      ));

      expect(chips.length, 1);
      expect(chips.single.texto, 'Ya estuvo aquí y se le devolvió.');
    });

    test('sin avisos, el «devuelto una vez» de siempre sigue saliendo', () {
      // Es el respaldo para un servidor anterior a `avisos`: ahí sigue siendo
      // lo único que hay, y quitarlo dejaría la tarjeta muda.
      final chips = losChipsDeLaFila(conAvisos(const [], devuelto: true));

      expect(chips.single.texto, 'devuelto una vez');
    });

    test('quien viene en orden y sin nada que decir no lleva chips', () {
      expect(losChipsDeLaFila(conAvisos(const [])), isEmpty);
    });
  });

  group('la cabecera de la cola, en pantalla', () {
    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ColaDeEstacionScreen(
          estacion: const Estacion(nro: 2, nombre: 'Documentos'),
          servidor: ServidorQueApunta(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    /// El sondeo de veinte segundos sigue vivo si no se desmonta la pantalla,
    /// y una prueba que lo deje corriendo falla por un temporizador pendiente
    /// en vez de por lo que mira.
    Future<void> cerrar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }

    testWidgets('enseña las tres, y la que no existe sale como hueco',
        (tester) async {
      await montar(tester);

      expect(find.text('Atendidos hoy'), findsOneWidget);
      expect(find.text('Esperando'), findsOneWidget);
      expect(find.text('Espera media'), findsOneWidget);
      // El hueco dice qué falta y quién lo puede poner. Nunca «no disponible»,
      // que no se puede pedir ni decidir.
      expect(find.text('el servidor aún no la calcula'), findsOneWidget);
      expect(find.textContaining('no disponible'), findsNothing);

      await cerrar(tester);
    });

    testWidgets('sin respuesta del servidor no se inventa un cero',
        (tester) async {
      // Con el interruptor apagado no hay cifra que enseñar: raya y motivo.
      await montar(tester);

      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('tu colegio no lo manda'), findsOneWidget);

      await cerrar(tester);
    });
  });

  group('el que llega salteado, en pantalla', () {
    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SalteadoScreen(
          estacion: const Estacion(nro: 4, nombre: 'Tesorería'),
          persona: PersonaEnCola.fromJson({
            'alumno_id': 31,
            'nombres': 'Laura',
            'apellidos': 'Mejía',
          }),
          avisos: const [
            (
              tipo: 'salteado',
              texto: 'Cerró una estación posterior sin pasar por ésta.',
            ),
          ],
          servidor: ServidorQueApunta(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('la banda dice lo que dijo el servidor, con sus palabras',
        (tester) async {
      await montar(tester);

      expect(
        find.text('Cerró una estación posterior sin pasar por ésta.'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('«no lo atiendas» sólo si la FICHA dice que le falta un paso',
        (tester) async {
      // A esta pantalla se llega por el aviso de la cola, y ese aviso —el de
      // la primera estación— significa que quien está delante **sí** tiene que
      // ser atendido aquí. Pintarle «no lo atiendas» sería mandarlo a una fila
      // que no existe. Sin ficha (interruptor apagado) no hay paso que falte.
      await montar(tester);

      expect(find.text('No lo atiendas todavía'), findsNothing);
      expect(find.textContaining('Se saltó el orden'), findsOneWidget);
    });

    testWidgets('«atenderlo de todas formas» existe, apagado y con su motivo',
        (tester) async {
      // Un sistema que no puede saltarse su propia regla se salta por fuera,
      // en papel, y entonces no hay registro de nada. Por eso el botón se
      // dibuja en vez de negarse — y por eso dice qué le falta.
      await montar(tester);

      expect(find.text('Atenderlo de todas formas'), findsOneWidget);
      expect(
          find.textContaining('nombre de quien lo autorizó'), findsOneWidget);
      expect(find.textContaining('no disponible'), findsNothing);
    });

    testWidgets('no hay ni un chulo verde en toda la pantalla', (tester) async {
      // La ruta contesta `paso_escrito: false`: aquí no se cierra nada. Un
      // verde optimista cuesta que alguien jure que cerró un paso que sigue
      // abierto.
      await montar(tester);

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });
  });

  group('los interruptores de la 08', () {
    test('mandar está encendido y atender de todas formas sigue apagado', () {
      // `mandarAlQueLlegaSalteado` ya no espera a nada propio —pantalla escrita,
      // ruta en `main`, cotejada el 24 sep 2026—: sólo al despliegue, que es
      // `Interruptores.estaciones`. `atenderloDeTodasFormas` espera a algo que
      // no es un despliegue: una columna donde guardar el nombre de quien
      // autoriza el salto, que hoy no existe en el servidor.
      expect(PendientesEstaciones.mandarAlQueLlegaSalteado, isTrue);
      expect(PendientesEstaciones.atenderloDeTodasFormas, isFalse);
    });

    test('volver a fábrica alcanza también al nuevo', () {
      PendientesEstaciones.atenderloDeTodasFormas = true;

      PendientesEstaciones.comoDeFabrica();

      expect(PendientesEstaciones.atenderloDeTodasFormas, isFalse);
    });
  });
}
