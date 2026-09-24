import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/NotaDeEstacionModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// La capa de datos de las cuatro rutas que faltaban del día de matrículas.
///
/// **Lo que aquí se comprueba dos veces es el silencio.** Las nueve rutas
/// `estaciones/*` están en `main` de `8myvc` y **no desplegadas en ningún
/// colegio**: cada llamada que se escapara sería un 404 por apertura de la app,
/// multiplicado por dieciséis colegios sobre un hosting de un núcleo. Su
/// hermana `estaciones_test.dart` ya vigila las lecturas viejas; esto vigila
/// las nuevas, y las escrituras, que son las que además escriben.
///
/// **Y lo que se comprueba con más cuidado todavía es lo que no se puede
/// probar de otra manera.** `Interruptores.estaciones` es `const false`, así
/// que todo lo que hay detrás de la guarda es código que ninguna prueba
/// alcanza: por eso las reglas que importan —el motivo obligatorio, el 403 con
/// su texto dentro, la lectura de la respuesta— viven en funciones sueltas que
/// sí se pueden llamar. Descubrir el día del despliegue que el motivo del
/// permiso no llegaba a la pantalla sería descubrirlo tarde.

/// Un servidor que apunta qué le piden, y contesta lo que se le diga.
class ServidorQueApunta extends Server {
  ServidorQueApunta({this.contesta});

  /// Qué devolver para cada dirección. Sin esto, un 200 vacío.
  final http.Response Function(String direccion)? contesta;

  final List<String> pedidos = [];
  final List<dynamic> cuerposEnviados = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);
    return _respuesta(direccion);
  }

  @override
  Future put(String direccion, params) async {
    pedidos.add(direccion);
    cuerposEnviados.add(params);
    return _respuesta(direccion);
  }

  @override
  Future post(String direccion, params) async {
    pedidos.add(direccion);
    cuerposEnviados.add(params);
    return _respuesta(direccion);
  }

  http.Response _respuesta(String direccion) =>
      contesta?.call(direccion) ?? http.Response('{}', 200);
}

/// Una respuesta como la que manda Laravel cuando corta con `abort(…, '…')` y
/// la petición sí pide JSON.
http.Response corta(int codigo, String mensaje) =>
    http.Response(jsonEncode({'message': mensaje}), codigo);

void main() {
  setUp(PendientesEstaciones.comoDeFabrica);

  group('las nueve rutas no están desplegadas, y las nuevas tampoco llaman',
      () {
    test('ninguna de las cinco le pide NADA al servidor', () async {
      // El mismo silencio que vigila `estaciones_test.dart` para las lecturas
      // viejas. Aquí pesa más: tres de éstas escriben.
      final servidor = ServidorQueApunta();

      await marcarElPaso(
        servidor,
        nroEstacion: 2,
        personaId: 31,
        resultado: ResultadoDelPaso.cumple,
      );
      await mandarALaEstacionQueFalta(
        servidor,
        desdeLaEstacion: 4,
        haciaLaEstacion: 1,
        personaId: 31,
      );
      await darPorResueltaLaNota(servidor, notaId: 105);
      await traerLaFichaPorCodigo(servidor, '2027-4K7M2');
      await traerLasNotasDeLaFicha(servidor, 31);

      expect(servidor.pedidos, isEmpty);
    });

    test('las escrituras contestan el motivo, no un fallo de red', () async {
      final servidor = ServidorQueApunta();

      final cerrado = await marcarElPaso(
        servidor,
        nroEstacion: 2,
        personaId: 31,
        resultado: ResultadoDelPaso.cumple,
      );
      final enviado = await mandarALaEstacionQueFalta(
        servidor,
        desdeLaEstacion: 4,
        haciaLaEstacion: 1,
        personaId: 31,
      );
      final resuelta = await darPorResueltaLaNota(servidor, notaId: 105);

      for (final motivo in [cerrado.fallo, enviado, resuelta]) {
        expect(motivo, isNotNull);
        // Nunca «no disponible»: quien lee esto es personal del colegio, y lo
        // que le sirve es saber que falta un despliegue.
        expect(motivo, isNot(contains('no disponible')));
      }

      // Y no se finge que se cerró algo: la ficha no vuelve.
      expect(cerrado.recorrido, isNull);
      expect(cerrado.cerradoPor, isNull);
    });

    test('las lecturas contestan vacío en vez de reventar', () async {
      final servidor = ServidorQueApunta();

      expect(await traerLaFichaPorCodigo(servidor, '2027-4K7M2'), isNull);
      expect(await traerLasNotasDeLaFicha(servidor, 31), isEmpty);
    });

    test('un código en blanco no se pregunta', () async {
      // La misma regla que `letrasMinimasParaBuscar`: el servidor contestaría
      // 422 para decir lo que ya se sabe aquí.
      final servidor = ServidorQueApunta();

      expect(await traerLaFichaPorCodigo(servidor, '   '), isNull);
      expect(servidor.pedidos, isEmpty);
    });

    test('el interruptor sigue apagado, y así tiene que seguir', () {
      expect(Interruptores.estaciones, isFalse);
    });
  });

  group('los interruptores que faltaban', () {
    test('los dos nuevos, encendidos: sólo esperan al despliegue', () {
      // `mandarAlQueLlegaSalteado` espera a la pantalla 08; `buscarPorElCodigo`
      // espera a que se despliegue `GET estaciones/codigo/{codigo}`, que NO es
      // lo mismo que el escáner: aquél es una decisión sobre los permisos de
      // las tiendas y está contestada.
      // Encendidos el 24 sep 2026: pantalla escrita y ruta en `main`. Lo que
      // queda debajo es el despliegue, o sea `Interruptores.estaciones`.
      expect(PendientesEstaciones.mandarAlQueLlegaSalteado, isTrue);
      expect(PendientesEstaciones.buscarPorElCodigo, isTrue);
    });

    test('volver a fábrica alcanza también a los nuevos', () {
      // Si `comoDeFabrica` se desincroniza de lo que hay escrito arriba, las
      // pruebas dejan de comprobar la app que se publica. Es la misma prueba
      // que `estaciones_test.dart` hace con los cinco de antes, estirada a los
      // dos que entran ahora.
      PendientesEstaciones.mandarAlQueLlegaSalteado = false;
      PendientesEstaciones.buscarPorElCodigo = false;

      PendientesEstaciones.comoDeFabrica();

      expect(PendientesEstaciones.mandarAlQueLlegaSalteado, isTrue);
      expect(PendientesEstaciones.buscarPorElCodigo, isTrue);
      // Y los de antes siguen donde estaban.
      expect(PendientesEstaciones.marcarElPaso, isTrue);
      expect(PendientesEstaciones.resolverUnaNota, isTrue);
    });
  });

  group('las notas que viajan dentro de la ficha', () {
    test('una reservada que no te toca leer llega SIN texto y existiendo', () {
      // Esconder que una nota existe es peor que esconder su contenido: quien
      // ve el globo y no puede abrirlo sabe a quién preguntarle; quien no ve
      // nada, no pregunta. El servidor manda `texto: null` y la nota entera.
      final nota = NotaDeEstacion.fromJson({
        'id': 105,
        'texto': null,
        'reservada': true,
        'pendiente': true,
        'resuelta': false,
        'de': 'Nancy Ariza',
        'cuando': '2026-09-20 08:12:00',
        'puedo_resolverla': false,
      });

      expect(nota.id, 105);
      expect(nota.texto, isNull);
      expect(nota.elTextoNoEsParaTi, isTrue);
      expect(nota.de, 'Nancy Ariza');
    });

    test('quien sí puede leerla recibe el texto', () {
      final nota = NotaDeEstacion.fromJson({
        'id': 106,
        'texto': 'Tiene saldo pendiente de la pensión de agosto',
        'reservada': true,
        'puedo_resolverla': true,
      });

      expect(nota.texto, contains('saldo pendiente'));
      expect(nota.elTextoNoEsParaTi, isFalse);
    });

    test('pendiente y reservada se leen vengan como vengan de PDO', () {
      // `notas_estacion.pendiente` y `.reservada` son tinyint y el listado sale
      // de `DB::select`: el mismo campo llega int en una ruta y String en otra.
      for (final crudo in [1, '1', true, 'true']) {
        final nota = NotaDeEstacion.fromJson({'id': 1, 'pendiente': crudo});
        expect(nota.pendiente, isTrue, reason: 'con $crudo');
      }
      for (final crudo in [0, '0', false, 'false', null]) {
        final nota = NotaDeEstacion.fromJson({'id': 1, 'pendiente': crudo});
        expect(nota.pendiente, isFalse, reason: 'con $crudo');
      }
    });

    test('una pendiente ya resuelta deja de estorbar', () {
      final viva = NotaDeEstacion.fromJson(
          {'id': 1, 'pendiente': true, 'resuelta': false});
      final apagada = NotaDeEstacion.fromJson(
          {'id': 2, 'pendiente': true, 'resuelta': true});
      final constancia = NotaDeEstacion.fromJson(
          {'id': 3, 'pendiente': false, 'resuelta': false});

      expect(viva.sinResolver, isTrue);
      expect(apagada.sinResolver, isFalse);
      expect(constancia.sinResolver, isFalse);
    });

    test('el botón lo enciende el SERVIDOR, no el rol que adivine la app', () {
      // `puedo_resolverla` lo calcula `Autoriza::puedeResolverNotaDeEstacion`.
      // La app es una sola para dieciséis colegios y no sabe los roles de quien
      // mira: deducirlo aquí sería encender un botón que luego contesta 403, o
      // apagárselo a quien sí puede.
      final mia = NotaDeEstacion.fromJson(
          {'id': 1, 'pendiente': true, 'puedo_resolverla': true});
      final ajena = NotaDeEstacion.fromJson(
          {'id': 2, 'pendiente': true, 'puedo_resolverla': false});

      expect(mia.puedeDarsePorResuelta, isTrue);
      expect(ajena.puedeDarsePorResuelta, isFalse);
      // Y una ya resuelta no se resuelve dos veces, aunque puedas.
      final hecha = NotaDeEstacion.fromJson({
        'id': 3,
        'pendiente': true,
        'resuelta': true,
        'puedo_resolverla': true,
      });
      expect(hecha.puedeDarsePorResuelta, isFalse);
    });

    test('la ficha trae las notas de TODAS las estaciones, no las de la tuya',
        () {
      // Es la razón de ser del módulo: el tesorero deja la nota el lunes en la
      // 5 y la estación 2 la atiende el sábado. Quien atiende Documentos tiene
      // que verla antes de mandar a la familia a hacer cuatro colas.
      final porEstacion = notasDeLaFicha({
        'pasos': [
          {'nro': 1, 'nombre': 'Recepción'},
          {
            'nro': 2,
            'nombre': 'Documentos',
            'notas_detalle': [
              {'id': 10, 'texto': 'Falta el registro civil', 'pendiente': 1},
            ],
          },
          {
            'nro': 5,
            'nombre': 'Tesorería',
            'notas_detalle': [
              {'id': 11, 'texto': null, 'reservada': 1, 'pendiente': 1},
              {'id': 12, 'texto': 'Llamó la mamá', 'pendiente': 0},
            ],
          },
        ],
      });

      expect(porEstacion.keys.toSet(), {2, 5});
      // La 1 no aparece porque no tiene notas, no porque se haya perdido.
      expect(porEstacion[1], isNull);
      expect(porEstacion[5]!.length, 2);
      expect(porEstacion[5]!.first.elTextoNoEsParaTi, isTrue);
    });

    test('la estación 0 es una clave válida y no un hueco', () {
      // `orden` tiene defecto 0: un colegio que no haya numerado sus pasos los
      // tiene todos en la estación 0, que es lo que hay hoy en la copia de
      // desarrollo.
      final porEstacion = notasDeLaFicha({
        'pasos': [
          {
            'nro': 0,
            'notas_detalle': [
              {'id': 1, 'texto': 'Sin numerar'},
            ],
          },
        ],
      });

      expect(porEstacion.containsKey(0), isTrue);
      expect(porEstacion[0]!.single.texto, 'Sin numerar');
    });

    test('una ficha sin «notas_detalle» no revienta: no tiene notas', () {
      // Un servidor anterior a esto contesta la ficha sin esa clave, y eso no
      // es un error que deba tumbar la pantalla.
      expect(
        notasDeLaFicha({
          'pasos': [
            {
              'nro': 1,
              'notas': {'total': 0}
            }
          ]
        }),
        isEmpty,
      );
      expect(notasDeLaFicha(null), isEmpty);
      expect(notasDeLaFicha({'pasos': 'nada'}), isEmpty);
      expect(notasDelPaso({'nro': 1}), isEmpty);
    });

    test('todas juntas conservan el orden en que se escribieron', () {
      // El servidor las manda ordenadas por `created_at, id`. Reordenarlas por
      // estación rompería la historia que cuentan.
      final todas = todasLasNotas({
        'pasos': [
          {
            'nro': 1,
            'notas_detalle': [
              {'id': 1, 'cuando': '2026-09-19 10:00:00'},
            ],
          },
          {
            'nro': 5,
            'notas_detalle': [
              {'id': 2, 'cuando': '2026-09-19 11:00:00'},
              {'id': 3, 'cuando': '2026-09-20 07:30:00'},
            ],
          },
        ],
      });

      expect(todas.map((n) => n.id).toList(), [1, 2, 3]);
    });
  });

  group('cerrar un paso: lo que se exige antes y lo que vuelve después', () {
    test('devolver sin motivo escrito no sale de la app', () {
      // El servidor contesta 422 con lo mismo; adelantarlo aquí ahorra una ida
      // y vuelta y, sobre todo, deja la regla dicha en un sitio: lo que se
      // escribe lo lee la familia, tal cual, en su celular.
      final falta = loQueLeFaltaAlCierre(ResultadoDelPaso.devuelto, '   ');

      expect(falta, isNotNull);
      expect(falta, contains('lo lee la familia'));
    });

    test('con motivo, o cuando no se devuelve, no falta nada', () {
      expect(
        loQueLeFaltaAlCierre(ResultadoDelPaso.devuelto, 'Falta el registro'),
        isNull,
      );
      expect(loQueLeFaltaAlCierre(ResultadoDelPaso.cumple, ''), isNull);
      expect(loQueLeFaltaAlCierre(ResultadoDelPaso.observado, ''), isNull);
    });

    test('las tres palabras son las que espera el servidor, en minúscula', () {
      // `EstacionesController::RESULTADOS` las compara con `mb_strtolower` y
      // contesta 422 a cualquier otra cosa.
      expect(
        ResultadoDelPaso.values.map((r) => r.comoLoEsperaElServidor).toList(),
        ['cumple', 'observado', 'devuelto'],
      );
    });

    test('la respuesta trae la ficha entera y a dónde pasa la familia', () {
      // `putMarcar` no contesta «vale»: contesta el recorrido recalculado y la
      // estación siguiente. Tirarlo obligaría a pedir la ficha otra vez justo
      // después de escribirla.
      final quedo = leerElPasoMarcado(jsonEncode({
        'guardado': true,
        'estacion': 2,
        'resultado': 'Cumple',
        'cerrado_por': 'Nancy Ariza',
        'cerrado_at': '2026-09-20 08:15:00',
        'siguiente': {'nro': 5, 'donde': 'Tesorería'},
        'recorrido': {
          'persona': {'id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
          'pasos': [
            {'nro': 2, 'nombre': 'Documentos', 'estado': 'Cumple'},
            {'nro': 5, 'nombre': 'Tesorería', 'estado': 'Falta'},
          ],
        },
      }));

      expect(quedo.fallo, isNull);
      expect(quedo.resultado, 'Cumple');
      expect(quedo.cerradoPor, 'Nancy Ariza');
      expect(quedo.cerradoAt, '2026-09-20 08:15:00');
      expect(quedo.siguienteNro, 5);
      expect(quedo.siguienteDonde, 'Tesorería');
      expect(quedo.recorrido, isNotNull);
      expect(quedo.recorrido!.pasos.length, 2);
    });

    test('devolver vuelve SIN hora de cierre, y eso no es un fallo', () {
      // Devolver reabre el paso: el servidor limpia `cerrado_at` para que la
      // cola de esta estación siga viendo a esa persona y la de la siguiente
      // no. Pintar un chulo verde aquí sería mentir.
      final quedo = leerElPasoMarcado(jsonEncode({
        'guardado': true,
        'resultado': 'Devuelto',
        'cerrado_por': 'Nancy Ariza',
        'cerrado_at': null,
        'siguiente': null,
      }));

      expect(quedo.fallo, isNull);
      expect(quedo.resultado, 'Devuelto');
      expect(quedo.cerradoAt, isNull);
      expect(quedo.siguienteNro, isNull);
      expect(quedo.siguienteDonde, isNull);
    });

    test('una respuesta que no se entiende NO se cuenta como fallo', () {
      // El estado era 2xx: el paso se cerró. Decir que no se cerró sería peor
      // que quedarse sin los renglones de después.
      for (final cuerpo in ['', 'no soy json', null]) {
        final quedo = leerElPasoMarcado(cuerpo);
        expect(quedo.fallo, isNull, reason: 'con «$cuerpo»');
        expect(quedo.recorrido, isNull);
      }
    });
  });

  group('el 403 de la única de las nueve con candado dentro', () {
    test('gana el motivo que escribió el servidor, tal cual', () {
      // `putNotaResuelta` es la única con `Autoriza::exigir` dentro, y su 403
      // trae el criterio escrito. Esa frase es lo que convierte un botón muerto
      // en una instrucción; escribirla en la app la dejaría envejecer sola.
      const suyo = 'Esta nota puede darla por resuelta quien la escribió, o '
          'Secretaría, Rectoría o un administrador.';

      final motivo = motivoDeUnaEscritura(
        corta(403, suyo),
        accion: 'dar esa nota por resuelta',
        sinPermiso: 'El servidor no te deja dar esa nota por resuelta.',
      );

      expect(motivo, suyo);
    });

    test('sin JSON cae al respaldo, y el respaldo NO nombra a nadie', () {
      // Sin `Accept: application/json` Laravel contesta su página de error en
      // HTML. El respaldo no puede inventarse la regla: quién puede resolver
      // cambia con el despliegue —los ids de los roles no son los mismos en los
      // dieciséis colegios y la regla ya se ensanchó a los superusuarios—.
      final motivo = motivoDeUnaEscritura(
        http.Response('<!DOCTYPE html><title>403</title>', 403),
        accion: 'dar esa nota por resuelta',
        sinPermiso: 'El servidor no te deja dar esa nota por resuelta.',
      );

      expect(motivo, 'El servidor no te deja dar esa nota por resuelta.');
      for (final rol in ['Secretar', 'Rector', 'administrador']) {
        expect(motivo, isNot(contains(rol)));
      }
    });

    test('el 404 de estas rutas es una frase, no un número', () {
      // «Esa nota no existe», «esa estación no existe en el recorrido de este
      // año», «ese alumno no existe»: tres cosas distintas que un «respondió
      // 404» borraría.
      expect(
        motivoDeUnaEscritura(corta(404, 'Esa nota no existe.'),
            accion: 'dar esa nota por resuelta'),
        'Esa nota no existe.',
      );
      expect(
        motivoDeUnaEscritura(
            corta(404, 'Esa estación no existe en el recorrido de este año.'),
            accion: 'cerrar ese paso'),
        contains('no existe en el recorrido'),
      );
    });

    test('el 422 del motivo llega entero a la pantalla', () {
      expect(
        motivoDeUnaEscritura(
          corta(
              422,
              'Para devolver hace falta escribir el motivo: lo lee la '
              'familia.'),
          accion: 'cerrar ese paso',
        ),
        contains('lo lee la familia'),
      );
    });

    test('un 500 no le enseña sus tripas a un docente', () {
      // Un volcado de excepción es JSON perfectamente válido. A partir de 500
      // ni se mira: ahí no hay un motivo escrito para nadie.
      final motivo = motivoDeUnaEscritura(
        corta(500, 'SQLSTATE[42S22]: Column not found: 1054 Unknown column'),
        accion: 'cerrar ese paso',
      );

      expect(motivo, 'El servidor respondió 500.');
      expect(motivo, isNot(contains('SQLSTATE')));
    });

    test('un mensaje larguísimo tampoco se enseña', () {
      // El recorte de `loQueDijoElServidor` es lo que separa un motivo de una
      // traza. Sin él, esto saldría en un SnackBar.
      final motivo = motivoDeUnaEscritura(
        corta(422, 'x' * 300),
        accion: 'cerrar ese paso',
        porElCuerpo: 'El servidor no aceptó cerrar ese paso.',
      );

      expect(motivo, 'El servidor no aceptó cerrar ese paso.');
    });

    test('cuando entra, no hay motivo que enseñar', () {
      expect(
        motivoDeUnaEscritura(http.Response('{"resuelta":true}', 200),
            accion: 'dar esa nota por resuelta'),
        isNull,
      );
    });
  });
}
