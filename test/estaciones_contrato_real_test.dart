import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Models/MiRecorridoModel.dart';
import 'package:myvc_flutter/Models/NotaDeEstacionModel.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// **Las respuestas DE VERDAD de las diez rutas, leídas por los lectores de la app.**
///
/// Las de `test/fixtures/estaciones/` no están escritas a mano: son el volcado de
/// `8myvc` en `main` (después de `d3dcd48`) contra una base de tests propia, con un
/// recorrido de tres estaciones, dos alumnos, un paso cerrado, uno devuelto, dos
/// notas y un código de hoja. Sólo se les quitó la traza de los errores, que en
/// producción no viaja (`APP_DEBUG=false`).
///
/// Las demás pruebas de las estaciones leen el JSON **del contrato**, escrito en el
/// `.md`; éstas leen **lo que el servidor contesta**. Con ellas salieron, el 24 sep
/// 2026, la huella como lista, el `?estacion=` que la app no mandaba, la estación 0
/// perdida en `si_no`, el `devolver_a` que era un objeto y la firma de secretaría en
/// blanco. Si el servidor cambia una forma, se revuelca y esto lo dice.
Map<String, dynamic> _fixture(String nombre) => jsonDecode(
      File('test/fixtures/estaciones/$nombre.json').readAsStringSync(),
    ) as Map<String, dynamic>;

dynamic _cuerpoDe(String nombre) => _fixture(nombre)['body'];

http.Response _respuesta(String nombre) {
  final f = _fixture(nombre);
  return http.Response.bytes(
    utf8.encode(jsonEncode(f['body'])),
    f['status'] as int,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('lecturas', () {
    test('GET estaciones: el recorrido y la campaña', () {
      final leidas = leerLasEstaciones(_cuerpoDe('index'));
      expect(leidas.abierta, isTrue);
      expect(leidas.estaciones.map((e) => e.nro), [1, 2, 3]);
      expect(leidas.estaciones[1].nombre, 'Documentos');

      final vacio = leerLasEstaciones(_cuerpoDe('index_vacio'));
      expect(vacio.abierta, isFalse);
      expect(vacio.estaciones, isEmpty);
    });

    test('GET estaciones/{nro}/cola: quién espera y su globo', () {
      final cola = leerLaCola(_cuerpoDe('cola_2'));
      expect(cola.nro, 2);
      expect(cola.atendidosHoy, 0);
      // Irene cerró la 1; Clara fue devuelta en la 1 y no llega a la 2.
      expect(cola.fila, hasLength(1));
      expect(cola.fila.first.persona.notasTotal, 2);
      expect(cola.fila.first.persona.notasPendientes, 2);
    });

    test('GET estaciones/huella: las tres cifras por estación', () {
      final huella = leerLaHuella(_cuerpoDe('huella'));
      expect(huella.keys, containsAll([1, 2, 3]));
      expect(huella[2], startsWith('1|2|'));
    });

    test('la huella de un servidor viejo, numerado desde 0, llega como LISTA',
        () {
      // Lo que contestaba `main` antes de `d3dcd48` con las estaciones 0 y 1.
      final huella = leerLaHuella({
        'por_estacion': [
          {'n': 1, 'notas': 0, 'ultimo_cambio': '2026-09-24 08:00:00'},
          {'n': 0, 'notas': 0, 'ultimo_cambio': null},
        ],
      });
      expect(huella.keys, [0, 1]);
      expect(huella[0], '1|0|2026-09-24 08:00:00');
    });

    test('la ficha desde una estación dice a dónde devolver (si_no)', () {
      final ficha = FichaDeEstacion.fromJson(
        Map<String, dynamic>.from(_cuerpoDe('alumno_ana_e3') as Map),
      );
      expect(ficha.persona.nombres, 'Irene');
      expect(ficha.leFalta?.nro, 2);
      expect(ficha.leFalta?.nombre, 'Documentos');
      // La firma de quien cerró, aunque no tenga ficha de profesor.
      expect(ficha.pasos.first.cerradoPor, 'users_684');
      expect(ficha.acudiente, 'Hugo Prieto Melo');
    });

    test('«devuélvase a la estación 0» no se pierde', () {
      final crudo = Map<String, dynamic>.from(_cuerpoDe('alumno_ana_e3') as Map);
      crudo['si_no'] = {'devolver_a_nro': 0, 'donde': 'Recepción'};
      final ficha = FichaDeEstacion.fromJson(crudo);
      expect(ficha.leFalta?.nro, 0);
      expect(ficha.leFalta?.nombre, 'Recepción');
    });

    test('sin ?estacion= el servidor no opina, y la app tampoco', () {
      final ficha = FichaDeEstacion.fromJson(
        Map<String, dynamic>.from(_cuerpoDe('alumno_beto') as Map),
      );
      expect(ficha.leFalta, isNull);
    });

    test('las notas de la ficha: la reservada llega sin texto', () {
      final notas = notasDeLaFicha(_cuerpoDe('alumno_ana_e3'));
      expect(notas[2]!.single.texto, 'Trae la EPS nueva');
      expect(notas[2]!.single.pendiente, isTrue);
      expect(notas[2]!.single.de, 'users_1');
      expect(notas[3]!.single.reservada, isTrue);
      expect(notas[3]!.single.texto, isNull);
    });

    test('GET estaciones/codigo/{codigo}: la misma ficha, con su código', () {
      final ficha = FichaDeEstacion.fromJson(
        Map<String, dynamic>.from(_cuerpoDe('codigo') as Map),
      );
      expect(ficha.codigo, '2027-ABCDE');
      expect(ficha.pasos, hasLength(3));
    });

    test('GET requisitos/recorrido: el devuelto con su motivo, no la observación',
        () {
      final recorrido = RecorridoDeMatricula.fromJson(_cuerpoDe('recorrido_beto'));
      expect(recorrido.pasos.first.estado, EstadoDelPaso.devuelto);
      expect(recorrido.pasos.first.motivo, 'Falta el registro civil');
      // Era un objeto `{estacion, requisito}` y se leía como número.
      expect(recorrido.devolverALaEstacion, 1);
    });

    test('GET requisitos/mi-recorrido: lo que ve la familia', () {
      final mio = MiRecorrido.fromJson(
        Map<String, dynamic>.from(_cuerpoDe('mi_recorrido_beto') as Map),
      );
      expect(mio.alumno.nombres, 'Clara');
      expect(mio.pasos, hasLength(3));
      expect(mio.faltan, mio.pasos.where((p) => !p.cumplido).length);
      expect(mio.completo, isFalse);
    });
  });

  group('escrituras', () {
    test('PUT marcar cumple: firma, hora y a dónde pasa', () {
      final marcado = leerElPasoMarcado(_cuerpoDe('marcar_cumple'));
      expect(marcado.fallo, isNull);
      expect(marcado.resultado, 'Cumple');
      expect(marcado.cerradoPor, 'users_684');
      expect(marcado.cerradoAt, isNotNull);
      expect(marcado.siguienteNro, 2);
      expect(marcado.siguienteDonde, 'Documentos');
      expect(marcado.recorrido, isNotNull);
    });

    test('PUT marcar devuelto: sin hora de cierre y con el motivo en la ficha',
        () {
      final marcado = leerElPasoMarcado(_cuerpoDe('marcar_devuelto'));
      expect(marcado.resultado, 'Devuelto');
      expect(marcado.cerradoAt, isNull);
      expect(marcado.recorrido!.pasos.first.motivo, 'Falta el registro civil');
    });

    test('los motivos del servidor llegan a la pantalla tal cual', () {
      expect(
        motivoDeUnaEscritura(_respuesta('resuelta_ajena'), accion: 'resolverla'),
        startsWith('Esta nota puede darla por resuelta quien la escribió'),
      );
      expect(
        motivoDeUnaEscritura(
          _respuesta('marcar_devuelto_sin_motivo'),
          accion: 'devolver',
        ),
        'Para devolver hace falta escribir el motivo: lo lee la familia.',
      );
      expect(
        motivoDeUnaEscritura(_respuesta('nota_vacia'), accion: 'dejar la nota'),
        'Una nota sin texto no es una nota.',
      );
      expect(
        loQueDijoElServidor(_respuesta('codigo_409').body),
        startsWith('Ese formulario todavía no está atado'),
      );
      expect(motivoDeUnaEscritura(_respuesta('resuelta'), accion: 'x'), isNull);
      expect(motivoDeUnaEscritura(_respuesta('enviar_a'), accion: 'x'), isNull);
      expect(motivoDeUnaEscritura(_respuesta('nota'), accion: 'x'), isNull);
    });
  });

  test('las rutas de las estaciones piden JSON; las demás no cambian', () {
    // Sin `Accept: application/json` los motivos de arriba llegaban en HTML.
    expect(Server.pideJson('/estaciones/2/cola'), isTrue);
    expect(Server.pideJson('/estaciones/nota/5/resuelta'), isTrue);
    expect(Server.pideJson('/requisitos/recorrido/12'), isTrue);
    expect(Server.pideJson('/requisitos/mi-recorrido/12'), isTrue);
    expect(Server.pideJson('/notas/lote'), isFalse);
    expect(Server.pideJson('/requisitos/alumno'), isFalse);
  });
}
