import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/MiMatriculaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/MiRecorridoModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// Un servidor que apunta qué le piden y contesta lo que se le diga.
class ServidorQueApunta extends Server {
  ServidorQueApunta({this.cuerpo = '{}', this.codigo = 200});

  final String cuerpo;
  final int codigo;
  final List<String> pedidos = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);
    return http.Response(cuerpo, codigo);
  }
}

void main() {
  group('el interruptor de «Mi proceso»', () {
    test('apagado no pide nada al servidor', () async {
      // La ruta entró en `main` de 8myvc en el merge `74d5028`, **después** de
      // que se empujaran las nueve de estaciones. Mientras no esté desplegada,
      // llamarla sería un 404 con cara de fallo de la app.
      expect(Interruptores.miMatricula, isFalse);

      final servidor = ServidorQueApunta();
      expect(await traerMiRecorrido(servidor, 31), isNull);
      expect(servidor.pedidos, isEmpty);
    });

    test('son TRES interruptores distintos y ninguno vale por otro', () {
      // No es una comprobación de valores —hoy los tres están apagados— sino de
      // que sigan **existiendo por separado**: si alguien fundiera dos en uno,
      // este fichero deja de compilar y alguien tiene que venir a leer por qué.
      //
      // Y el porqué es que son tres despliegues distintos:
      //   estaciones            -> las nueve rutas del personal, YA en origin/main
      //   recorridoDeMatricula  -> requisitos/recorrido, YA en origin/main
      //   miMatricula           -> requisitos/mi-recorrido, entró en el merge
      //                            74d5028 y el 20 sep seguía SIN empujar
      //
      // Colgar ésta de las otras la encendería contra una ruta que todavía
      // puede dar 404, y un 404 en la app se lee como «esto está roto».
      // Una lista y no un `Set`: en un `Set` los tres `false` colapsan en uno
      // y la prueba dejaría de mirar tres cosas sin que nadie lo notara.
      final tres = <bool>[
        Interruptores.estaciones,
        Interruptores.recorridoDeMatricula,
        Interruptores.miMatricula,
      ];

      expect(tres, [false, false, false],
          reason: 'los tres esperan despliegue, cada uno el suyo');
    });
  });

  group('lo que manda `mi-recorrido`, leído sin fiarse del tipo', () {
    test('`cumplido` se LEE, no se deduce de un texto de estado', () {
      // El servidor lo calcula como `marca_id != null && cerrado_at != null` y
      // no desde `estado`, porque `estado` lo escriben tres pantallas con tres
      // vocabularios. Esta app ya se quemó con `falta` contra `Falta`: aquí se
      // lee el booleano y no se vuelve a deducir.
      final paso = PasoDeMiRecorrido.fromJson({
        'estacion': 2,
        'requisito': 'Tesorería',
        'cumplido': true,
        'devuelto': false,
        // Nótese que NO viene `estado`: la familia no lo recibe.
        'cerrado_at': '2026-09-20 09:14:00',
      });

      expect(paso.cumplido, isTrue);
      expect(paso.pendiente, isFalse);
    });

    test('un booleano que llega como 1, «1» o «true» se lee igual', () {
      for (final crudo in [true, 1, '1', 'true']) {
        final paso = PasoDeMiRecorrido.fromJson({
          'estacion': 1,
          'requisito': 'Documentos',
          'devuelto': crudo,
        });
        expect(paso.devuelto, isTrue, reason: 'con $crudo');
      }

      for (final crudo in [false, 0, '0', 'false']) {
        final paso = PasoDeMiRecorrido.fromJson({
          'estacion': 1,
          'requisito': 'Documentos',
          'devuelto': crudo,
        });
        expect(paso.devuelto, isFalse, reason: 'con $crudo');
      }
    });

    test('sin `cumplido` se da por NO cumplido, y eso no es simetría', () {
      // `bloquea` que falta se da por obligatorio —lo prudente— pero `cumplido`
      // que falta se da por pendiente. Al revés mandaría a una familia a su casa
      // creyendo que terminó.
      final paso = PasoDeMiRecorrido.fromJson({
        'estacion': 1,
        'requisito': 'Documentos',
      });

      expect(paso.cumplido, isFalse);
      expect(paso.devuelto, isFalse);
      expect(paso.pendiente, isTrue);
      expect(paso.bloquea, isTrue);
    });

    test('un paso sin nombre sale con su número, no en blanco', () {
      final paso = PasoDeMiRecorrido.fromJson({'estacion': 4});
      expect(paso.requisito, 'Paso 4');
    });

    test('`descripcion` es la del REQUISITO y la observación NO viaja', () {
      // Las dos tablas tienen una columna `descripcion`. Ésta es la del
      // requisito —qué le piden a la familia—; la interna viaja en la ruta del
      // personal con el alias `observacion` y aquí no existe. Si alguien las
      // confundiera, una madre leería una nota escrita entre docentes.
      final paso = PasoDeMiRecorrido.fromJson({
        'estacion': 3,
        'requisito': 'Documentos',
        'descripcion': 'Registro civil y fotocopia del documento',
        'observacion': 'la mamá discutió con la secretaria, ojo',
      });

      expect(paso.descripcion, 'Registro civil y fotocopia del documento');

      // Y la observación no tiene por dónde entrar: el modelo no la lee.
      expect(
        paso.toString().contains('discutió'),
        isFalse,
        reason: 'la observación interna no puede aparecer en esta pantalla',
      );
    });
  });

  group('el recorrido entero', () {
    MiRecorrido conPasos(List<Map<String, dynamic>> pasos, {int faltan = 0}) {
      return MiRecorrido.fromJson({
        'alumno': {'id': 31, 'nombres': 'Laura Sofía', 'apellidos': 'Mejía'},
        'pasos': pasos,
        'faltan': faltan,
        'completo': faltan == 0,
      });
    }

    test('lo devuelto se separa, porque es lo único que pide hacer algo', () {
      final recorrido = conPasos([
        {'estacion': 1, 'requisito': 'Tesorería', 'cumplido': true},
        {
          'estacion': 2,
          'requisito': 'Documentos',
          'devuelto': true,
          'motivo_devolucion': 'Falta el registro civil',
        },
        {'estacion': 3, 'requisito': 'Rectoría'},
      ], faltan: 2);

      expect(recorrido.devueltos.length, 1);
      expect(recorrido.devueltos.single.requisito, 'Documentos');
      expect(
        recorrido.devueltos.single.motivoDevolucion,
        'Falta el registro civil',
      );
      expect(recorrido.completo, isFalse);
    });

    test('`completo` viene del servidor y no se deduce de `faltan`', () {
      // Si algún día dejaran de coincidir, el que manda es el servidor: es el
      // que sabe contar los pasos de ese año.
      final raro = MiRecorrido.fromJson({
        'alumno': {'id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'pasos': const [],
        'faltan': 3,
        'completo': false,
      });

      expect(raro.faltan, 3);
      expect(raro.completo, isFalse);
    });

    test('sin la clave `completo` NO se da por completo', () {
      final sinClave = MiRecorrido.fromJson({
        'alumno': {'id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'pasos': const [],
      });

      expect(sinClave.completo, isFalse);
    });

    test('una respuesta rota no revienta: sale vacía', () {
      final rota = MiRecorrido.fromJson({'pasos': 'esto no es una lista'});

      expect(rota.pasos, isEmpty);
      expect(rota.alumno.nombreCompleto, '');
      expect(rota.completo, isFalse);
    });
  });

  group('el id, que en esta ruta no es opcional', () {
    test('con el interruptor apagado no llega ni a mirar el id', () async {
      // **Esta prueba dice lo que HOY se puede comprobar, y no finge más.**
      // `traerMiRecorrido` mira el interruptor antes que nada, así que la
      // comprobación del id —que existe y está escrita— es inalcanzable
      // mientras `miMatricula` sea un `const false`: el analizador la ve como
      // código muerto y ninguna prueba puede entrar ahí.
      //
      // El orden es el correcto y no se cambia para hacerla testeable: con el
      // interruptor apagado, un acudiente sin `personaId` tiene que ver «esto
      // todavía no está disponible» y no «no se sabe de quién es», que son dos
      // problemas distintos y solo uno es suyo.
      //
      // **Lo que hay que hacer el día que se encienda**: quitar este comentario
      // y escribir la prueba de que `traerMiRecorrido(servidor, 0)` lanza sin
      // llamar al servidor. El motivo de que el guard exista es que un `0`
      // daría 404 y el mensaje hablaría de un alumno que no existe — mentira
      // que manda a buscar el fallo al sitio equivocado.
      final servidor = ServidorQueApunta();

      expect(await traerMiRecorrido(servidor, 0), isNull);
      expect(servidor.pedidos, isEmpty);
    });
  });
}
