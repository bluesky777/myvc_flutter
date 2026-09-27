import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';

/// **Las respuestas DE VERDAD de `act/*`, leídas por los modelos de la app.**
///
/// Las de `test/fixtures/actividades/` no están escritas a mano: son lo que
/// contestó el backend de prueba (`8myvc`, rama `feat/actividades`, en el
/// 8092) el 26 sep 2026 al alumno y al acudiente de los tokens de prueba, con
/// los nombres de las personas y las rutas de sus fotos cambiados. Si el
/// servidor cambia una forma, se vuelve a volcar y esto lo dice.
dynamic _fixture(String nombre) => jsonDecode(
    File('test/fixtures/actividades/$nombre.json').readAsStringSync());

Map<String, dynamic> _mapa(String nombre) =>
    Map<String, dynamic>.from(_fixture(nombre) as Map);

void main() {
  group('la bandeja del alumno', () {
    final filas = (_fixture('bandeja_alumno') as List)
        .map((m) => ActEnBandeja.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    test('se leen las doce filas, con sus tres modos', () {
      expect(filas, hasLength(12));
      expect(filas.map((f) => f.modo).toSet(),
          {'tarea', 'cuestionario', 'encuesta'});
    });

    test('pendiente = abierta y sin enviar (pendiente o borrador)', () {
      final pendientes = filas.where((f) => f.pendiente).map((f) => f.id);
      // La 23 sin empezar, la 14 (tarea) sin entregar y la 13 en borrador.
      // La 10 está `vencida` y cerrada: no es pendiente, es de «hechas».
      expect(pendientes, [23, 14, 13]);
    });

    test('la calificada trae su nota y el creador, con foto', () {
      final f = filas.firstWhere((f) => f.id == 22);
      expect(f.esTarea, isTrue);
      expect(f.miEstado, 'calificada');
      expect(f.miNota, 42);
      expect(f.califica, isTrue);
      expect(f.creador.nombre, 'CARMEN ROSA DÍAZ LUNA');
      expect(f.creador.primerNombre, 'Carmen');
      expect(f.creador.fotoUrl, endsWith('/foto.jpg'));
      expect(f.porAlumno, isNull);
    });

    test('el cierre es hora de Colombia, leída como local', () {
      final f = filas.firstWhere((f) => f.id == 23);
      expect(f.cierraAt, DateTime(2026, 9, 27, 14));
      expect(filas.firstWhere((f) => f.id == 28).cierraAt, isNull);
    });

    test('la encuesta con seguimiento es anónima', () {
      expect(filas.firstWhere((f) => f.id == 10).anonima, isTrue);
      expect(filas.firstWhere((f) => f.id == 4).anonima, isFalse);
    });
  });

  group('la bandeja del acudiente', () {
    final filas = (_fixture('bandeja_acudiente') as List)
        .map((m) => ActEnBandeja.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    test('«una vez por hijo»: el mismo id, dos filas, un hijo cada una', () {
      final nueve = filas.where((f) => f.id == 9).toList();
      expect(nueve, hasLength(2));
      expect(nueve.map((f) => f.porAlumno!.alumnoId), [465, 590]);
      expect(nueve.first.porAlumno!.primerNombre, 'Lucía');
      expect(nueve.first.porAlumno!.iniciales, 'LP');
    });
  });

  group('responder', () {
    test('el cuestionario en borrador trae lo guardado y la nota máxima', () {
      final act =
          ActParaResponder.fromJson(_mapa('responder_cuestionario_borrador'));

      expect(act.modo, 'cuestionario');
      expect(act.notaMaxima, 50);
      expect(act.instrucciones, '');
      expect(act.preguntas.map((p) => p.id), [11, 12]);
      expect(act.preguntas.first.opciones.map((o) => o.definicion), ['4', '5']);
      // Sin `is_correct`: al que responde no le llegan las correctas.
      expect(act.preguntas.first.opciones.first.esCorrecta, isNull);
      expect(act.preguntas.first.condiciones, isEmpty);
      expect(act.borrador.map((r) => r.opcionIds), [
        [19],
        [21]
      ]);
      expect(act.intentosUsados, 0);
      expect(act.intentosMaximo, 1);
      expect(act.sinIntentos, isFalse);
      expect(act.entrega, isNull);
    });

    test('la tarea con preguntas trae lo que pide y la entrega hecha', () {
      final act =
          ActParaResponder.fromJson(_mapa('responder_tarea_con_preguntas'));

      expect(act.entrega!.texto, isTrue);
      expect(act.entrega!.foto, isFalse);
      expect(act.entrega!.enlace, isFalse);
      expect(act.miEntrega!.texto, 'dos respuesta 0');
      expect(act.miEntrega!.entregada, isTrue);
      expect(act.miEntrega!.entregadaAt, DateTime(2026, 9, 26, 21, 18, 55));
      expect(act.miEntrega!.calificada, isFalse);
      expect(act.preguntas.single.tipo, 'corta');
      expect(act.borrador.single.texto, 'dos respuesta 1');
      expect(act.sinIntentos, isTrue);
    });

    test('la tarea sin preguntas ni entrega: listas vacías, no null', () {
      final act = ActParaResponder.fromJson(_mapa('responder_tarea_sobre_50'));
      expect(act.preguntas, isEmpty);
      expect(act.borrador, isEmpty);
      expect(act.miEntrega, isNull);
      expect(act.notaMaxima, 50);
    });

    test('la del acudiente dice por qué hijo responde', () {
      final act =
          ActParaResponder.fromJson(_mapa('responder_encuesta_acudiente'));
      expect(act.porAlumno!.alumnoId, 465);
      expect(act.porAlumno!.primerNombre, 'Lucía');
      expect(act.preguntas.single.tipo, 'sino');
      expect(act.notaMaxima, isNull);
    });

    test('las instrucciones llegan como HTML y se leen como texto', () {
      expect(
          textoDeHtml('<p>Lee <b>bien</b>&nbsp;el texto</p><ul><li>uno</li>'
              '<li>dos</li></ul>'),
          'Lee bien el texto\n• uno\n• dos');
    });

    test('el orden manda sobre el orden de llegada', () {
      final j = _mapa('responder_cuestionario_borrador');
      j['preguntas'] = (j['preguntas'] as List).reversed.toList();
      expect(ActParaResponder.fromJson(j).preguntas.map((p) => p.id), [11, 12]);
    });
  });

  group('mis respuestas', () {
    test('la tarea calificada: 42 de 50, y 84 en la planilla', () {
      final m = MisRespuestasAct.fromJson(
          _mapa('mis_respuestas_tarea_calificada'));

      // La nota de la tarea viaja en la entrega, no arriba.
      expect(m.nota, isNull);
      expect(m.entrega!.nota, 42);
      expect(m.notaMaxima, 50);
      expect(m.notaPlanilla, 84);
      expect(m.entrega!.comentario, 'Muy bien los tres animales.');
      expect(m.entrega!.calificadaAt, DateTime(2026, 9, 26, 18, 29, 44));
      expect(m.respuestas, isEmpty);
      expect(m.compartidos, isNull);
    });

    test('el cuestionario trae lo mío, si acerté y las correctas', () {
      final m =
          MisRespuestasAct.fromJson(_mapa('mis_respuestas_cuestionario'));

      expect(m.nota, 100);
      expect(m.notaMaxima, 100);
      expect(m.notaPlanilla, isNull);
      expect(m.puntaje, 1);
      expect(m.puntajeMax, 1);
      expect(m.correctas, 1);
      final fila = m.respuestas.first;
      expect(fila.mia!.opcionIds, [48]);
      expect(fila.acerto, isTrue);
      expect(fila.pregunta.opciones.where((o) => o.esCorrecta == true).single.id,
          48);
    });

    test('la encuesta cerrada trae los resultados compartidos', () {
      final m = MisRespuestasAct.fromJson(
          _mapa('mis_respuestas_encuesta_compartida'));

      expect(m.notaMaxima, isNull);
      expect(m.respuestas.map((r) => r.pregunta.tipo), ['sino', 'parrafo']);
      expect(m.respuestas.last.mia!.texto, 'Ver los animales de la granja.');
      final c = m.compartidos!;
      expect(c.destinatarios, 5);
      expect(c.respondieron, 1);
      // Con menos de cinco respuestas no se enseñan cifras (§2.6).
      expect(c.preguntas.single.oculto, isTrue);
      expect(c.preguntas.single.barras, isEmpty);
      expect(c.preguntas.single.textos, isEmpty);
    });

    test('la del acudiente, del hijo por el que respondió', () {
      final m = MisRespuestasAct.fromJson(_mapa('mis_respuestas_acudiente'));
      expect(m.actividad.porAlumno!.alumnoId, 590);
      expect(m.enviadaAt, DateTime(2026, 9, 26, 17, 59, 30));
      expect(m.respuestas.single.mia!.opcionIds, [14]);
      expect(m.respuestas.single.acerto, isNull);
    });

    test('las barras compartidas marcan la mía y ordenan la escala', () {
      final r = ResultadoCompartido.fromJson({
        'tipo': 'escala',
        'enunciado': '¿Qué tal?',
        'respondida_por': 7,
        'oculto': false,
        'escala': [
          {'valor': 1, 'n': 1, 'mia': false},
          {'valor': 5, 'n': 4, 'mia': true},
          {'valor': 3, 'n': 2, 'mia': false},
        ],
        'promedio': '3.86',
      });

      expect(r.barras.map((b) => b.etiqueta), ['5', '3', '1']);
      expect(r.barras.first.mia, isTrue);
      expect(r.promedio, closeTo(3.86, 1e-9));

      final o = ResultadoCompartido.fromJson({
        'tipo': 'unica',
        'opciones': [
          {'opcion_id': 3, 'definicion': 'Sí', 'n': 5, 'mia': 1},
          {'opcion_id': null, 'definicion': null, 'n': 2},
        ],
      });
      expect(o.barras.map((b) => b.etiqueta), ['Sí', 'Otra']);
      expect(o.barras.first.mia, isTrue);
    });
  });

  group('la campana', () {
    test('del alumno: diez sin leer, el tope y la actividad de cada una', () {
      final a = AvisosAct.fromJson(_mapa('avisos_alumno'));

      expect(a.noLeidos, 10);
      expect(a.hastaId, 95);
      expect(a.avisos, hasLength(10));
      final primero = a.avisos.first;
      expect(primero.clase, 'nota_cambiada');
      expect(primero.actividadId, 22);
      expect(primero.modo, 'tarea');
      expect(primero.tituloActividad, 'T23 tarea planilla');
      expect(primero.alumnoId, 1130);
      expect(primero.leido, isFalse);
      expect(primero.creadoAt, DateTime(2026, 9, 26, 21, 51, 53));
    });

    test('del acudiente: el aviso trae de qué hijo es', () {
      final a = AvisosAct.fromJson(_mapa('avisos_acudiente'));
      expect(a.noLeidos, 0);
      final aviso = a.avisos.single;
      expect(aviso.alumnoId, 465);
      expect(aviso.alumnoNombre, 'LUCÍA');
      expect(aviso.leido, isTrue);
    });
  });

  group('lo que se manda', () {
    test('una respuesta viaja con todas sus claves, aunque vayan en null', () {
      expect(
          const RespuestaAct(preguntaId: 9, opcionIds: [14]).toJson(),
          {
            'pregunta_id': 9,
            'opcion_ids': [14],
            'texto': null,
            'valor': null,
            'fecha': null,
            'archivo_id': null,
          });
    });

    test('lo que vuelve del servidor se relee igual', () {
      final r = RespuestaAct.fromJson({
        'pregunta_id': '42',
        'opcion_ids': ['1', 2, null],
        'texto': 'hola',
        'valor': '3',
      });
      expect(r.preguntaId, 42);
      expect(r.opcionIds, [1, 2]);
      expect(r.valor, 3);
    });

    test('el resultado de enviar, con decimales y sin nota', () {
      final r = ResultadoDeEnvio.fromJson(
          {'nota': null, 'puntaje': '2.5', 'puntaje_max': 4, 'quedan_intentos': 1});
      expect(r.nota, isNull);
      expect(r.puntaje, 2.5);
      expect(r.puntajeMax, 4);
      expect(r.quedanIntentos, 1);
    });

    test('la chapa del archivo es su extensión', () {
      ArchivoAct a(String n) => ArchivoAct.fromJson({'id': 1, 'nombre_original': n});
      expect(a('informe.final.pdf').extension, 'PDF');
      expect(a('sin_punto').extension, 'ARCH');
      expect(a('raro.').extension, 'ARCH');
    });
  });
}
