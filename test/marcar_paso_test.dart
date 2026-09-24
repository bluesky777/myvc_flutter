import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/DevolverConMotivoScreen.dart';
import 'package:myvc_flutter/Screens/MarcarPasoScreen.dart';
import 'package:myvc_flutter/Screens/PasoCerradoScreen.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// Las tres pantallas que cierran un paso: la 05, la 06 y la 07.
///
/// ## Lo que se comprueba aquí y no se puede comprobar de otra manera
///
/// `Interruptores.estaciones` es `const false`, así que **ninguna de estas
/// pantallas puede llegar al servidor** y todo lo que hay detrás de esa guarda
/// es inalcanzable desde una prueba. Por eso las reglas que deciden algo viven
/// en funciones sueltas —[repartirElTexto], [conLaFrase],
/// [laSiguienteDelRecorrido], [elAvisoParaLaFamilia]— y se prueban llamándolas.
///
/// **Y tres de esas reglas son trampas del contrato de verdad, medidas el 20
/// sep 2026 en `EstacionesController::putMarcar` y `::escribirElPaso`.**
/// Equivocarse en cualquiera de las tres **no falla**: se pierde en silencio, y
/// se descubre semanas después en el celular de una familia. De ahí que tengan
/// grupo propio y el porqué escrito al lado.
class ServidorQueApunta extends Server {
  final List<String> pedidos = [];
  final List<dynamic> cuerposEnviados = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  @override
  Future put(String direccion, params) async {
    pedidos.add(direccion);
    cuerposEnviados.add(params);
    return http.Response('{}', 200);
  }

  @override
  Future post(String direccion, params) async {
    pedidos.add(direccion);
    cuerposEnviados.add(params);
    return http.Response('{}', 200);
  }
}

/// La estación que se atiende en casi todas estas pruebas.
const laEstacion = Estacion(nro: 2, nombre: 'Documentos', esperando: 3);

/// Una ficha como la que devuelve `GET estaciones/alumno/{id}`.
///
/// Tres pasos: la 1 cerrada, la 2 —la que se atiende— abierta con un requisito,
/// y la 3 sin empezar. Es el caso de la mañana: alguien que ya pasó por
/// recepción y llega a documentos.
FichaDeEstacion laFicha({
  List<PasoDelRecorrido>? pasos,
  String nombres = 'Laura',
}) {
  return FichaDeEstacion(
    persona: PersonaEnCola(
      id: 31,
      nombres: nombres,
      apellidos: 'Mejía Cruz',
      grupo: '5A',
      documento: '1090234567',
    ),
    pasos: pasos ??
        const [
          PasoDelRecorrido(
            nro: 1,
            nombre: 'Recepción',
            estado: EstadoDelPaso.cumplido,
          ),
          PasoDelRecorrido(
            nro: 2,
            nombre: 'Documentos',
            estado: EstadoDelPaso.pendiente,
            requisitos: [
              Requisito(
                id: 7,
                nombre: 'Registro civil',
                estado: EstadoDelPaso.pendiente,
              ),
            ],
          ),
          PasoDelRecorrido(
            nro: 3,
            nombre: 'Tesorería',
            estado: EstadoDelPaso.pendiente,
          ),
        ],
  );
}

/// Monta una pantalla encima de otra, para que `Navigator.pop` tenga a dónde ir.
///
/// **No usa `pumpAndSettle`** y eso no es un descuido: la 07 tiene una cuenta
/// atrás con `Timer.periodic`, y `pumpAndSettle` la correría entera antes de
/// que la prueba pudiera mirar nada. Aquí se avanza el reloj a mano, que es lo
/// único que deja comprobar los ocho segundos.
Future<void> montar(
  WidgetTester tester,
  Widget pantalla, {
  void Function(bool?)? alVolver,
}) async {
  // Alta a propósito: estas tres pantallas son listas, y en una ventana de
  // 600 px el bloque de la consecuencia —que es la mitad del diseño de la 05—
  // ni se construye, así que una prueba sobre él no comprobaría nada.
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final llave = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: llave,
      home: const Scaffold(body: Center(child: Text('la cola'))),
    ),
  );

  unawaited(
    llave.currentState!
        .push(MaterialPageRoute<bool>(builder: (_) => pantalla))
        .then((valor) => alVolver?.call(valor)),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Si un botón está encendido, buscado por lo que dice.
bool encendido<T extends ButtonStyleButton>(WidgetTester tester, String texto) {
  return tester.widget<T>(find.widgetWithText(T, texto)).onPressed != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PendientesEstaciones.comoDeFabrica);

  // -------------------------------------------------------------------------
  group('las tres trampas del contrato, medidas en el controlador', () {
    test('TRAMPA 1 · el motivo SOLO viaja cuando se devuelve', () {
      // `escribirElPaso` mete `motivo_devolucion=?` únicamente en la rama de
      // `devuelto`. En la otra escribe `motivo_devolucion=NULL`, así que un
      // motivo mandado con `cumple` no es que se ignore: **borra el que
      // hubiera** y no se guarda en ninguna parte.
      final devolviendo = repartirElTexto(
        ResultadoDelPaso.devuelto,
        'Falta la firma del acudiente',
      );

      expect(devolviendo.motivo, 'Falta la firma del acudiente');
      expect(devolviendo.observacion, isNull);
    });

    test('TRAMPA 1 · con cumple u observado, el texto NO va en motivo', () {
      for (final resultado in [
        ResultadoDelPaso.cumple,
        ResultadoDelPaso.observado,
      ]) {
        final reparto = repartirElTexto(resultado, 'Trajo la copia ampliada');

        // Lo que importa es esto: el motivo se queda vacío SIEMPRE que no se
        // devuelva. Mandarlo aquí sería tirar el texto y borrar de paso el
        // motivo de una devolución anterior.
        expect(reparto.motivo, '', reason: '$resultado no puede mandar motivo');
        expect(reparto.observacion, 'Trajo la copia ampliada');
      }
    });

    test('TRAMPA 2 · una observación vacía NO se manda, porque borraría', () {
      // El controlador decide con `Request::has('observacion')`: mandar cadena
      // vacía es `descripcion=''` y perder lo que otra estación dejó escrito.
      // Null es «no la toques», y es lo que tiene que salir de una casilla en
      // blanco —o con espacios, que es lo que deja un teclado de teléfono—.
      for (final escrito in ['', '   ', '\n ']) {
        expect(
          repartirElTexto(ResultadoDelPaso.cumple, escrito).observacion,
          isNull,
          reason: 'una casilla «$escrito» no puede borrar la observación',
        );
        expect(
          repartirElTexto(ResultadoDelPaso.observado, escrito).observacion,
          isNull,
        );
      }

      // Y en cuanto hay algo escrito, se manda recortado.
      expect(
        repartirElTexto(ResultadoDelPaso.cumple, '  falta el sello  ')
            .observacion,
        'falta el sello',
      );
    });

    test('TRAMPA 2 · al devolver, la observación va en null', () {
      // La 06 no tiene casilla de observación. Mandar una vacía «por si acaso»
      // borraría la del paso, que es la trampa 2 entrando por la puerta de
      // atrás.
      expect(
        repartirElTexto(ResultadoDelPaso.devuelto, 'No se lee la copia')
            .observacion,
        isNull,
      );
    });

    testWidgets('TRAMPA 3 · tras un devuelto no hay chulo verde',
        (tester) async {
      // Devolver **reabre** el paso: el servidor limpia `cerrado_at` y
      // `cerrado_por` para que la cola de esta estación siga viendo a esa
      // persona. Pintar un cumplido sería pintar lo contrario de lo que pasó.
      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.devuelto,
          escrito: 'Falta la firma',
          servidor: ServidorQueApunta(),
        ),
      );

      expect(find.text('Cumple'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // Y se dice con palabras, no sólo con el rojo.
      expect(find.text('Devuelto'), findsWidgets);
      expect(find.textContaining('Vuelve contigo'), findsOneWidget);
      expect(find.textContaining('Devolver reabre el paso'), findsOneWidget);
    });

    test('TRAMPA 3 · y tampoco lo habrá cuando el servidor conteste', () {
      // Lo de arriba mira la pantalla durante la cuenta atrás, que es hasta
      // donde llega una prueba con `Interruptores.estaciones` en `const
      // false`. Lo que pasa **después** de que el servidor conteste vive en
      // [comoSeVeElCierre], suelta justamente para poder mirarlo aquí.
      final devuelto = comoSeVeElCierre(ResultadoDelPaso.devuelto);

      expect(devuelto.icono, isNot(Icons.check_circle));
      expect(devuelto.color, PaletaEstaciones.rojo);
      expect(devuelto.palabra, 'Devuelto');
      expect(devuelto.explicacion, contains('sigue debiéndose'));

      // Y los otros dos sí cierran, que es la otra mitad de la regla.
      expect(
          comoSeVeElCierre(ResultadoDelPaso.cumple).icono, Icons.check_circle);
      expect(comoSeVeElCierre(ResultadoDelPaso.cumple).color,
          PaletaEstaciones.verde);

      // Ninguno se distingue sólo por el color: los tres traen palabra.
      for (final resultado in ResultadoDelPaso.values) {
        expect(comoSeVeElCierre(resultado).palabra.trim(), isNotEmpty);
      }
    });

    testWidgets('TRAMPA 3 · un devuelto NO manda a la estación siguiente',
        (tester) async {
      // `putMarcar` contesta `siguiente` siempre, calculado hacia adelante,
      // también cuando se devuelve. Pintarlo mandaría a la familia a la
      // estación 3 cuando lo que tiene que hacer es volver a la 2.
      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.devuelto,
          escrito: 'Falta la firma',
          recorridoDelColegio: const [
            Estacion(nro: 3, nombre: 'Tesorería', esperando: 4),
          ],
          servidor: ServidorQueApunta(),
        ),
      );

      expect(find.textContaining('Tesorería'), findsNothing);
      expect(find.textContaining('Pasa a'), findsNothing);
      expect(find.textContaining('Estación 2 · Documentos'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  group('el silencio: las nueve rutas no están desplegadas', () {
    testWidgets('la 05 no le pide nada al servidor', (tester) async {
      final servidor = ServidorQueApunta();

      await montar(
        tester,
        MarcarPasoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: servidor,
        ),
      );

      expect(servidor.pedidos, isEmpty);
    });

    testWidgets('la 06 no le pide nada al servidor', (tester) async {
      final servidor = ServidorQueApunta();

      await montar(
        tester,
        DevolverConMotivoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: servidor,
        ),
      );

      expect(servidor.pedidos, isEmpty);
    });

    testWidgets('la 07 no escribe nada, ni cuando se acaba la cuenta',
        (tester) async {
      final servidor = ServidorQueApunta();

      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.cumple,
          servidor: servidor,
        ),
      );

      // Los ocho segundos enteros, más uno de propina.
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();

      expect(servidor.pedidos, isEmpty);
      expect(servidor.cuerposEnviados, isEmpty);
      expect(Interruptores.estaciones, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('05 · la consecuencia se enseña ANTES de confirmar', () {
    testWidgets('sin elegir salida, el botón no se enciende', (tester) async {
      PendientesEstaciones.marcarElPaso = true;

      await montar(
        tester,
        MarcarPasoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      // Ninguna de las tres puede ser la de por defecto: una salida por
      // defecto es una salida que se pulsa sin leer.
      expect(encendido<FilledButton>(tester, 'Confirmar'), isFalse);
      expect(find.textContaining('Elige arriba cómo quedó'), findsOneWidget);
    });

    testWidgets(
        'al elegir cumple sale a dónde pasa y qué le llega a la familia',
        (tester) async {
      PendientesEstaciones.marcarElPaso = true;

      await montar(
        tester,
        MarcarPasoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.tap(find.text('Cumple'));
      await tester.pumpAndSettle();

      // A qué estación pasa, con su número —que es el del cartel impreso—.
      expect(
          find.textContaining('Pasa a Estación 3 · Tesorería'), findsWidgets);
      // El texto exacto que le va a llegar a la familia.
      expect(find.text('Laura pasó a Estación 3 · Tesorería.'), findsOneWidget);
      // Y qué se da por cumplido, que es lo que de verdad se escribe.
      expect(find.textContaining('Registro civil'), findsOneWidget);
      expect(encendido<FilledButton>(tester, 'Confirmar: cumple'), isTrue);
    });

    testWidgets('con el push apagado, no se promete un aviso que no sale',
        (tester) async {
      // Rectificado por Joseth el 20 sep 2026: el push inmediato NO entra, y
      // esta app no tiene `firebase_messaging`. Enseñar el texto y callar que
      // no sale dejaría a quien atiende confiando en un aviso que no existe.
      PendientesEstaciones.marcarElPaso = true;

      await montar(
        tester,
        MarcarPasoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.tap(find.text('Cumple'));
      await tester.pumpAndSettle();

      expect(find.textContaining('NO sale solo: díselo tú'), findsOneWidget);
    });

    testWidgets('apagado dice POR QUÉ, y ya no dice que falten pantallas',
        (tester) async {
      // Encendido de fábrica desde el 24 sep 2026; el camino apagado sigue
      // existiendo y se prueba apagándolo a mano.
      PendientesEstaciones.marcarElPaso = false;
      await montar(
        tester,
        MarcarPasoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.tap(find.text('Cumple'));
      await tester.pumpAndSettle();

      // El motivo cambió: las tres pantallas están escritas, lo que falta es
      // el despliegue de las nueve rutas.
      expect(find.textContaining('desplegadas en todos los colegios'),
          findsOneWidget);
      // Y nunca «no disponible», que no se puede pedir ni arreglar.
      expect(find.textContaining('no disponible'), findsNothing);
      expect(encendido<FilledButton>(tester, 'Confirmar: cumple'), isFalse);
    });

    testWidgets('devolver lleva a escribir el motivo, no a devolver',
        (tester) async {
      PendientesEstaciones.marcarElPaso = true;

      await montar(
        tester,
        MarcarPasoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.tap(find.text('Devolver'));
      await tester.pumpAndSettle();

      // Dos veces: en la tarjeta de la salida y en el bloque de la
      // consecuencia. Es la frase que hay que leer dos veces.
      expect(find.textContaining('El paso NO se cierra'), findsWidgets);
      expect(
        encendido<FilledButton>(tester, 'Escribir el motivo y devolver'),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('06 · el botón no se enciende sin motivo escrito', () {
    testWidgets('arriba, en rojo, dice quién lo lee', (tester) async {
      await montar(
        tester,
        DevolverConMotivoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      expect(
        find.text('Lo que escribas aquí lo lee la familia'),
        findsOneWidget,
      );
      expect(find.textContaining('Tal cual, en su celular'), findsOneWidget);
    });

    testWidgets('sin texto está apagado; con una frase de un toque, encendido',
        (tester) async {
      PendientesEstaciones.devolverConMotivo = true;

      await montar(
        tester,
        DevolverConMotivoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      expect(encendido<FilledButton>(tester, 'Devolver a la familia'), isFalse);
      expect(
        find.text('Para devolver hace falta escribir el motivo: lo lee la '
            'familia.'),
        findsOneWidget,
      );

      // Un motivo de un toque es un motivo que sí se escribe.
      await tester.tap(find.text('Falta la firma'));
      await tester.pumpAndSettle();

      expect(encendido<FilledButton>(tester, 'Devolver a la familia'), isTrue);
    });

    testWidgets('las tres de siempre son botones, no un desplegable',
        (tester) async {
      // Un desplegable de motivos cerrados hace que el día que el caso no esté
      // en la lista se elija el más parecido, y la familia recibe una mentira.
      await montar(
        tester,
        DevolverConMotivoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      expect(find.byType(DropdownButton<String>), findsNothing);
      for (final frase in lasTresFrasesDeSiempre) {
        expect(find.widgetWithText(OutlinedButton, frase), findsOneWidget);
      }
      // Y la casilla libre sigue ahí: las frases rellenan, no sustituyen.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('lo escrito se ve como lo va a ver la familia', (tester) async {
      await montar(
        tester,
        DevolverConMotivoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Trae el registro civil');
      await tester.pumpAndSettle();

      expect(find.text('Trae el registro civil'), findsWidgets);
      // El aviso del celular NO lleva el motivo dentro: se lee abriendo la app.
      expect(
        find.text('Laura no pasó Estación 2 · Documentos. Tiene que volver: '
            'abre la app para ver qué falta.'),
        findsOneWidget,
      );
    });

    testWidgets('apagado por el pendiente, sigue apagado y dice por qué',
        (tester) async {
      // Encendido de fábrica desde el 24 sep 2026; el camino apagado sigue
      // existiendo y se prueba apagándolo a mano.
      PendientesEstaciones.devolverConMotivo = false;
      await montar(
        tester,
        DevolverConMotivoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Falta la firma');
      await tester.pumpAndSettle();

      expect(encendido<FilledButton>(tester, 'Devolver a la familia'), isFalse);
      expect(
        find.textContaining('desplegadas en todos los colegios'),
        findsOneWidget,
      );
    });

    group('conLaFrase: añade, no reemplaza', () {
      test('sobre una casilla vacía, la frase sola', () {
        expect(conLaFrase('', 'Falta la firma'), 'Falta la firma');
        expect(conLaFrase('   ', 'Falta la firma'), 'Falta la firma');
      });

      test('sobre algo escrito, se encadena sin dos puntos seguidos', () {
        expect(
          conLaFrase('Falta el certificado', 'Falta la firma'),
          'Falta el certificado. Falta la firma',
        );
        expect(
          conLaFrase('Falta el certificado.', 'Falta la firma'),
          'Falta el certificado. Falta la firma',
        );
      });

      test('dos toques a la misma frase no la repiten', () {
        // Quien atiende está de pie y con prisa, y un «Falta la firma. Falta
        // la firma» lo lee la familia tal cual.
        final una = conLaFrase('', 'Falta la firma');
        expect(conLaFrase(una, 'Falta la firma'), una);
      });
    });
  });

  // -------------------------------------------------------------------------
  group('07 · el deshacer de ocho segundos', () {
    testWidgets('mientras cuenta, la marca NO ha salido y se dice',
        (tester) async {
      // §2.6: reloj naranja = marcado aquí, el servidor no lo sabe. Un verde
      // optimista ahorra un icono y cuesta que alguien jure que marcó a un
      // alumno que no está marcado.
      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.cumple,
          servidor: ServidorQueApunta(),
        ),
      );

      expect(find.text('Marcado aquí'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.textContaining('Todavía no ha salido del teléfono'),
          findsOneWidget);
      expect(find.text('Deshacer ($segundosParaDeshacer)'), findsOneWidget);
    });

    testWidgets('la cuenta baja de verdad', (tester) async {
      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.cumple,
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Deshacer (5)'), findsOneWidget);

      // Y se deja acabar para no dejar el reloj suelto.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
    });

    testWidgets('deshacer cierra la pantalla y contesta que no se escribió',
        (tester) async {
      final servidor = ServidorQueApunta();
      bool? loQueContesto;
      var contesto = false;

      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.cumple,
          servidor: servidor,
        ),
        alVolver: (valor) {
          contesto = true;
          loQueContesto = valor;
        },
      );

      await tester.tap(find.text('Deshacer ($segundosParaDeshacer)'));
      await tester.pumpAndSettle();

      // Volvió a la cola, nada salió del teléfono, y la ficha de atrás se
      // entera de que **no hay nada que recargar**.
      expect(find.text('la cola'), findsOneWidget);
      expect(servidor.pedidos, isEmpty);
      expect(contesto, isTrue);
      expect(loQueContesto, isFalse);
    });

    testWidgets('pasados los ocho segundos se manda solo', (tester) async {
      // Con el interruptor apagado lo que contesta la capa de datos es el
      // motivo escrito, y la pantalla lo enseña **diciendo que no quedó nada**:
      // un «algo salió mal» dejaría a quien atiende sin saber si el paso está
      // cerrado, y con una fila delante eso se resuelve marcando otra vez.
      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.cumple,
          servidor: ServidorQueApunta(),
        ),
      );

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.text('No se guardó'), findsOneWidget);
      expect(
        find.textContaining('Las estaciones todavía no están disponibles'),
        findsOneWidget,
      );
      expect(find.textContaining('No quedó escrito nada'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('el destructivo va separado del principal, y los dos a 56',
        (tester) async {
      await montar(
        tester,
        PasoCerradoScreen(
          estacion: laEstacion,
          ficha: laFicha(),
          resultado: ResultadoDelPaso.cumple,
          servidor: ServidorQueApunta(),
        ),
      );

      final mandar =
          tester.getRect(find.widgetWithText(FilledButton, 'Mandarlo ya'));
      final deshacer = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Deshacer ($segundosParaDeshacer)'),
      );

      expect(mandar.height, PaletaEstaciones.alturaDeBoton);
      expect(deshacer.height, PaletaEstaciones.alturaDeBoton);
      // Separados: entre uno y otro hay aire, no un borde compartido.
      expect(deshacer.top - mandar.bottom, greaterThanOrEqualTo(8));

      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
    });
  });

  // -------------------------------------------------------------------------
  group('las reglas sueltas, que son las que deciden', () {
    test('laSiguienteDelRecorrido salta lo cumplido y mira hacia adelante', () {
      const pasos = [
        PasoDelRecorrido(
            nro: 1, nombre: 'Recepción', estado: EstadoDelPaso.cumplido),
        PasoDelRecorrido(
            nro: 2, nombre: 'Documentos', estado: EstadoDelPaso.pendiente),
        PasoDelRecorrido(
            nro: 3, nombre: 'Tesorería', estado: EstadoDelPaso.cumplido),
        PasoDelRecorrido(
            nro: 4, nombre: 'Orientación', estado: EstadoDelPaso.pendiente),
      ];

      // Desde la 2, la 3 ya está cerrada: la siguiente es la 4.
      expect(laSiguienteDelRecorrido(pasos, 2)?.nro, 4);
      // Y desde la 4 no queda ninguna.
      expect(laSiguienteDelRecorrido(pasos, 4), isNull);
      // Nunca mira hacia atrás, aunque la 1 estuviera abierta: eso es la 08.
      expect(laSiguienteDelRecorrido(pasos, 3)?.nro, 4);
    });

    test('un paso devuelto más adelante SÍ cuenta como siguiente', () {
      // Devolver reabre —`cerrado_at` vuelve a null—, así que `cerrada()` del
      // servidor lo vuelve a dar por abierto. Esta función tiene que contestar
      // igual o la pantalla diría una estación distinta de la que dice el
      // servidor un segundo después.
      const pasos = [
        PasoDelRecorrido(
            nro: 1, nombre: 'Recepción', estado: EstadoDelPaso.cumplido),
        PasoDelRecorrido(
            nro: 2, nombre: 'Documentos', estado: EstadoDelPaso.cumplido),
        PasoDelRecorrido(
            nro: 3, nombre: 'Tesorería', estado: EstadoDelPaso.devuelto),
      ];

      expect(laSiguienteDelRecorrido(pasos, 1)?.nro, 3);
    });

    test('el aviso de la familia NUNCA lleva el motivo dentro', () {
      // `notificaciones.md`: una notificación se lee en una pantalla
      // bloqueada, con gente al lado. El nombre sí; el contenido, no.
      final aviso = elAvisoParaLaFamilia(
        nombres: 'Laura',
        resultado: ResultadoDelPaso.devuelto,
        estacionActual: 'Estación 2 · Documentos',
      );

      expect(aviso.contains('Laura'), isTrue);
      expect(aviso.toLowerCase().contains('firma'), isFalse);
      expect(aviso.toLowerCase().contains('certificado'), isFalse);
      expect(aviso, contains('abre la app'));
    });

    test('el aviso de que pasó dice a dónde, con el número del cartel', () {
      expect(
        elAvisoParaLaFamilia(
          nombres: 'Laura Sofía',
          resultado: ResultadoDelPaso.cumple,
          estacionActual: 'Estación 2 · Documentos',
          estacionSiguiente: 'Estación 3 · Tesorería',
        ),
        'Laura pasó a Estación 3 · Tesorería.',
      );
    });

    test('sin siguiente, se dice que terminó', () {
      expect(
        elAvisoParaLaFamilia(
          nombres: 'Laura',
          resultado: ResultadoDelPaso.observado,
          estacionActual: 'Estación 5 · Rectoría',
        ),
        'Laura terminó el recorrido de matrícula.',
      );
    });

    test('el nombre de pila es el primero, y sin nombre no queda un hueco', () {
      expect(elNombreDePila('Laura Sofía Mejía'), 'Laura');
      expect(elNombreDePila('  Laura  '), 'Laura');
      // Una orden de inscripción del modo «nuevos» nace sin nombres.
      expect(elNombreDePila(''), 'Tu hijo o tu hija');
    });

    test('la estación se nombra con el número primero', () {
      // El patio tiene carteles con números, no con nombres.
      expect(comoSeLlamaLaEstacion(3, 'Tesorería'), 'Estación 3 · Tesorería');
    });
  });
}
