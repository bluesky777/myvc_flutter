import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/EstacionesScreen.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un servidor que apunta qué le piden y no contesta nada útil.
///
/// Sirve para lo contrario de lo habitual: aquí lo que se comprueba es que
/// **no le pidan nada** mientras las ocho rutas no existan.
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.limpiar();
    PendientesEstaciones.comoDeFabrica();
    SharedPreferences.setMockInitialValues({});
  });

  group('el estado de un paso, que llega como texto libre', () {
    test('«falta» y «Falta» son lo mismo, y eso no es una precaución', () {
      // Es un hecho medido en el backend el 20 sep 2026:
      // `requisitos_alumno.estado` es un varchar sin lista cerrada, el valor
      // por defecto de la tabla es 'Falta' con mayúscula y
      // `AlumnosController:899` inserta "falta" en minúscula. Las dos formas de
      // nacer una fila ya no se ponen de acuerdo, así que comparar tal cual
      // sería leer mal a la mitad de las filas.
      expect(EstadoDelPaso.deTexto('falta'), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto('Falta'), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto('  FALTA  '), EstadoDelPaso.pendiente);
    });

    test('una palabra que esta versión no conoce NO rompe la pantalla', () {
      // docs/estaciones.md §2.8: una sola app para dieciséis colegios, y una
      // versión vieja convive meses. Un tipo de paso desconocido se pinta con
      // el control genérico en vez de romperse.
      expect(EstadoDelPaso.deTexto('en_veremos'), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto(null), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto(''), EstadoDelPaso.pendiente);
    });

    test('los que sí se conocen se leen', () {
      expect(EstadoDelPaso.deTexto('cumple'), EstadoDelPaso.cumplido);
      expect(EstadoDelPaso.deTexto('Observado'), EstadoDelPaso.observado);
      expect(EstadoDelPaso.deTexto('DEVUELTO'), EstadoDelPaso.devuelto);
    });

    test('ninguno se distingue solo por el color: todos traen palabra e icono',
        () {
      // Es por el sol del patio y por quien no distingue el rojo del verde,
      // que en un claustro de cincuenta docentes es uno o dos.
      for (final estado in EstadoDelPaso.values) {
        expect(estado.palabra.trim(), isNotEmpty);
        expect(estado.icono, isNotNull);
      }
      // Y las cuatro palabras son distintas entre sí, que es lo que las hace
      // servir de algo.
      final palabras = EstadoDelPaso.values.map((e) => e.palabra).toSet();
      expect(palabras.length, EstadoDelPaso.values.length);
    });
  });

  group('lo que manda el servidor, leído sin fiarse del tipo', () {
    test('un tinyint que llega como «1», 1 o true se lee igual', () {
      // `DB::select` devuelve lo que PDO decida: el mismo campo llega int en
      // una ruta y String en otra.
      for (final crudo in [1, '1', true, 'true']) {
        final paso = PasoDelRecorrido.fromJson({
          'nro': 2,
          'nombre': 'Documentos',
          'estado': 'falta',
          'obligatorio': crudo,
        });
        expect(paso.obligatorio, isTrue, reason: 'con $crudo');
      }
      expect(
        PasoDelRecorrido.fromJson({'nro': 2, 'obligatorio': 0}).obligatorio,
        isFalse,
      );
    });

    test('una estación sin nombre no sale en blanco: sale con su número', () {
      final estacion = Estacion.fromJson({'nro': '3'});
      expect(estacion.nro, 3);
      expect(estacion.nombre, 'Estación 3');
    });

    test('un aspirante se distingue de un alumno por de dónde sale su id', () {
      final alumno = PersonaEnCola.fromJson({
        'alumno_id': 31,
        'nombres': 'Laura Sofía',
        'apellidos': 'Mejía Ariza',
      });
      final aspirante = PersonaEnCola.fromJson({
        'aspirante_id': 77,
        'nombres': 'Mariana',
        'apellidos': 'Castillo',
      });

      expect(alumno.id, 31);
      expect(alumno.esAspirante, isFalse);
      expect(aspirante.id, 77);
      expect(aspirante.esAspirante, isTrue);
    });
  });

  group('el globo de notas', () {
    test('el número cuenta las reservadas, y eso es a propósito', () {
      // Esconder que una nota existe es peor que esconder su contenido: quien
      // ve el globo y no puede abrirlo sabe a quién preguntarle; quien no ve
      // nada, no pregunta.
      final notas = NotasDelPaso.fromJson({
        'total': 3,
        'pendientes': 1,
        'reservadas': 2,
      });

      expect(notas.total, 3);
      expect(notas.reservadas, 2);
      expect(notas.hayAlgo, isTrue);
      expect(notas.algoSinResolver, isTrue);
    });

    test('ámbar solo si algo está sin resolver; si no, pizarra', () {
      const soloEscritas = NotasDelPaso(total: 2, pendientes: 0);
      const conPendiente = NotasDelPaso(total: 2, pendientes: 1);

      expect(soloEscritas.algoSinResolver, isFalse);
      expect(conPendiente.algoSinResolver, isTrue);
    });

    test('el número nunca va solo: hay la misma frase en palabras', () {
      const notas = NotasDelPaso(total: 2, pendientes: 1);
      expect(notas.enPalabras('Tesorería'),
          '2 notas en Tesorería, una sin resolver');

      const una = NotasDelPaso(total: 1, pendientes: 0);
      expect(una.enPalabras('Recepción'), '1 nota en Recepción');
    });

    test('la ficha suma las notas de TODAS las estaciones, no solo la tuya',
        () {
      // Es la razón de ser de §2.10: el tesorero deja la nota el lunes en la 5
      // y la estación 2 la atiende el sábado. Si esto sumara solo el paso
      // propio, quien atiende Documentos mandaría a la familia a hacer cuatro
      // colas sin enterarse.
      final ficha = FichaDeEstacion.fromJson({
        'persona': {'alumno_id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'pasos': [
          {
            'nro': 1,
            'nombre': 'Recepción',
            'estado': 'cumple',
            'notas': {'total': 1, 'pendientes': 0}
          },
          {'nro': 2, 'nombre': 'Documentos', 'estado': 'falta'},
          {
            'nro': 5,
            'nombre': 'Tesorería',
            'estado': 'falta',
            'notas': {'total': 2, 'pendientes': 1, 'reservadas': 1}
          },
        ],
      });

      final todas = ficha.notasDeTodoElRecorrido;
      expect(todas.total, 3);
      expect(todas.pendientes, 1);
      expect(todas.reservadas, 1);
    });
  });

  group('los requisitos de un paso', () {
    test('solo los obligatorios apagan el botón de cerrar', () {
      final paso = PasoDelRecorrido.fromJson({
        'nro': 2,
        'nombre': 'Documentos',
        'estado': 'falta',
        'requisitos': [
          {'id': 1, 'requisito': 'Registro civil', 'estado': 'cumple'},
          {
            'id': 2,
            'requisito': 'Carné de vacunas',
            'estado': 'falta',
            'obligatorio': 0
          },
        ],
      });

      expect(paso.requisitos.length, 2);
      // El opcional está sin cumplir y aun así no cuenta.
      expect(paso.obligatoriosQueFaltan, 0);
    });

    test('un obligatorio sin cumplir sí cuenta', () {
      final paso = PasoDelRecorrido.fromJson({
        'nro': 2,
        'requisitos': [
          {'id': 1, 'requisito': 'Certificado de notas', 'estado': 'falta'},
        ],
      });
      expect(paso.obligatoriosQueFaltan, 1);
    });
  });

  group('las ocho rutas no existen, y la app no las llama', () {
    test('el interruptor viene apagado, y así tiene que seguir', () {
      // Las ocho rutas `estaciones/*` no están en NINGÚN colegio. Encender esto
      // antes del despliegue gasta un 404 por apertura sobre un hosting de un
      // núcleo, que es justo la carga que este proyecto lleva un año evitando.
      // Ver docs/backend-pendiente.md §8.
      expect(Interruptores.estaciones, isFalse);
    });

    test('con el interruptor apagado no se le pide NADA al servidor', () async {
      final servidor = ServidorQueApunta();

      await traerLasEstaciones(servidor);
      await traerLaCola(servidor, 2);
      await traerLaHuella(servidor);
      await traerLaFicha(servidor, 31);

      // Lo que se comprueba es el silencio: ni un 404.
      expect(servidor.pedidos, isEmpty);
    });

    test('y contestan vacío en vez de reventar', () async {
      final servidor = ServidorQueApunta();

      expect(await traerLasEstaciones(servidor), isEmpty);
      expect(await traerLaCola(servidor, 2), isEmpty);
      expect(await traerLaHuella(servidor), isEmpty);
      expect(await traerLaFicha(servidor, 31), isNull);
    });

    test('dejar una nota contesta el motivo, no un fallo de red', () async {
      final servidor = ServidorQueApunta();
      final fallo = await dejarUnaNota(
        servidor,
        nroEstacion: 5,
        personaId: 31,
        texto: 'Tiene saldo pendiente',
      );

      expect(fallo, isNotNull);
      expect(servidor.pedidos, isEmpty);
    });
  });

  group('los pendientes de estas pantallas', () {
    test('todos apagados hoy, y cada uno espera a algo distinto', () {
      expect(PendientesEstaciones.marcarElPaso, isFalse);
      expect(PendientesEstaciones.devolverConMotivo, isFalse);
      expect(PendientesEstaciones.escanearElCodigo, isFalse);
      expect(PendientesEstaciones.pushInmediato, isFalse);
      expect(PendientesEstaciones.resolverUnaNota, isFalse);
    });

    test('volver a fábrica mueve los dos sentidos', () {
      // Si `comoDeFabrica` se desincroniza de los valores escritos, las pruebas
      // dejan de comprobar la app que se publica.
      PendientesEstaciones.marcarElPaso = true;
      PendientesEstaciones.pushInmediato = true;

      PendientesEstaciones.comoDeFabrica();

      expect(PendientesEstaciones.marcarElPaso, isFalse);
      expect(PendientesEstaciones.pushInmediato, isFalse);
    });
  });

  group('la pantalla de elegir estación', () {
    Future<void> montar(WidgetTester tester) async {
      AuthService.user = UserAutenticado(
        username: 'nancy.ariza',
        tipo: 'Profesor',
        id: 12,
      );

      await tester.pumpWidget(
        MaterialApp(home: EstacionesScreen(servidor: ServidorQueApunta())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin recorrido dice qué falta y dónde se arregla',
        (tester) async {
      // Una lista vacía y «esto todavía no existe» se leen igual y no son lo
      // mismo. Aquí se dice la tercera, que es la que le sirve al colegio:
      // «no armaste el recorrido, se arma en la web».
      await montar(tester);

      expect(find.textContaining('no armó el recorrido'), findsOneWidget);
      expect(find.textContaining('pantalla de requisitos'), findsOneWidget);
      // Nunca «no disponible»: quien lo lee es quien puede arreglarlo.
      expect(find.textContaining('no disponible'), findsNothing);
    });

    testWidgets('lleva el mismo nombre que el menú', (tester) async {
      // El título tiene que ser la misma palabra que la entrada del menú: si el
      // menú dice «Estaciones», la pantalla dice «Estaciones».
      await montar(tester);
      expect(find.text('Estaciones'), findsOneWidget);
    });
  });

  group('la paleta', () {
    test('el morado de texto sobre claro no es el de marca, y hace falta', () {
      // El primario sobre blanco se queda en 3,9:1 y no llega al 4,5:1 que pide
      // el texto normal. No es un tono decorativo: es el que hace legible.
      expect(
        PaletaEstaciones.primarioOscuro,
        isNot(equals(PaletaEstaciones.primario)),
      );
    });

    test('los botones que deciden algo se tocan de pie, con guantes', () {
      expect(PaletaEstaciones.alturaDeBoton, greaterThanOrEqualTo(56));
    });
  });
}
