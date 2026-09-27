import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Screens/ResponderActividadScreen.dart';

import 'actividades_backend_de_mentira.dart';

/// Responder una por pantalla: la condicionada que aparece y desaparece, el
/// borrador que se guarda solo, enviar, y lo que pasa cuando el servidor dice
/// que no (409 cerrada, 422 falta una).
///
/// La encuesta de mentira: «¿Vas a ir?» (sí/no); si es sí, «¿Con quién
/// vas?»; y siempre «¿Algo más?».
Map<String, dynamic> _salida({bool terceraObligatoria = false}) => {
      'id': 50,
      'modo': 'encuesta',
      'titulo': 'Salida al museo',
      'instrucciones': null,
      'estado': 'abierta',
      'cierra_at': null,
      'anonimato': 'nombre',
      'por_alumno': null,
      'entrega': null,
      'nota_maxima': null,
      'intentos': {'usados': 0, 'maximo': 1},
      'preguntas': [
        preguntaAct(1, 'sino', '¿Vas a ir?', opciones: [
          {'id': 1, 'definicion': 'Sí'},
          {'id': 2, 'definicion': 'No'},
        ]),
        preguntaAct(2, 'corta', '¿Con quién vas?', condiciones: [
          [
            {'depende_de_id': 1, 'operador': 'es', 'opcion_id': 1}
          ]
        ]),
        preguntaAct(3, 'parrafo', '¿Algo más?',
            obligatoria: terceraObligatoria),
      ],
      'borrador': [],
      'mi_entrega': null,
    };

ActEnBandeja _fila(int id, String modo, {Map<String, dynamic>? porAlumno}) =>
    ActEnBandeja.fromJson({
      'id': id,
      'modo': modo,
      'titulo': 'x',
      'estado': 'abierta',
      'mi_estado': 'pendiente',
      'por_alumno': porAlumno,
    });

void main() {
  setUp(() => entrarComo('Alumno'));
  tearDown(AuthService.limpiar);

  Future<void> montar(WidgetTester tester, ActEnBandeja fila) async {
    enTelefono(tester);
    await tester.pumpWidget(
        MaterialApp(home: ResponderActividadScreen(fila: fila)));
    await tester.pumpAndSettle();
  }

  /// Deja correr la espera del borrador (1,2 s) y lo que venga detrás.
  Future<void> esperarBorrador(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  }

  BackendDeActividades conSalida({bool terceraObligatoria = false}) =>
      BackendDeActividades()
        ..cuando('GET /act/50/responder',
            _salida(terceraObligatoria: terceraObligatoria))
        ..cuando('POST /act/50/borrador',
            {'guardado_at': '2026-09-26 18:30:05'});

  group('una por pantalla', () {
    testWidgets('la condicionada aparece con «sí» y desaparece con «no»',
        (tester) async {
      final backend = conSalida();
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        expect(find.textContaining('¿Vas a ir?'), findsOneWidget);
        expect(find.text('Siguiente'), findsOneWidget);

        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        // Con «no», la segunda no está: se salta a la tercera, que es la
        // última y ya dice «Enviar».
        expect(find.textContaining('¿Algo más?'), findsOneWidget);
        expect(find.textContaining('¿Con quién vas?'), findsNothing);
        expect(find.text('Enviar'), findsOneWidget);

        await tester.tap(find.text('Atrás'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sí'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        expect(find.textContaining('¿Con quién vas?'), findsOneWidget);
        expect(find.text('Siguiente'), findsOneWidget);
        await esperarBorrador(tester);
      });
    });

    testWidgets('lo respondido en una que se ocultó no se envía',
        (tester) async {
      final backend = conSalida()
        ..cuando('POST /act/50/enviar', {'quedan_intentos': 0});
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));

        await tester.tap(find.text('Sí'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Con mi abuela');
        await tester.pump();

        // Se arrepiente: vuelve y dice que no va.
        await tester.tap(find.text('Atrás'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar'));
        await tester.pumpAndSettle();

        final enviadas = backend.cuerpoDe('POST /act/50/enviar')['respuestas']
            as List;
        expect(enviadas.map((r) => r['pregunta_id']), [1]);
        expect(enviadas.single['opcion_ids'], [2]);
        expect(find.text('¡Gracias, Tomás!'), findsOneWidget);
        expect(find.text('Tus respuestas llegaron.'), findsOneWidget);
      });
    });

    testWidgets('una obligatoria sin responder no deja seguir',
        (tester) async {
      final backend = conSalida(terceraObligatoria: true);
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        final enviar = tester.widget<ButtonStyleButton>(find.ancestor(
            of: find.text('Enviar'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
        expect(enviar.onPressed, isNull);
        await esperarBorrador(tester);
      });
    });
  });

  group('el borrador', () {
    testWidgets('se guarda solo, con lo respondido', (tester) async {
      final backend = conSalida();
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        expect(find.text('se guarda sola'), findsOneWidget);

        await tester.tap(find.text('Sí'));
        await tester.pump(const Duration(milliseconds: 600));
        // Todavía no: espera a que deje de tocar.
        expect(backend.rutasPedidas, isNot(contains('POST /act/50/borrador')));
        await esperarBorrador(tester);

        expect(backend.cuerpoDe('POST /act/50/borrador'), {
          'respuestas': [
            {
              'pregunta_id': 1,
              'opcion_ids': [1],
              'texto': null,
              'valor': null,
              'fecha': null,
              'archivo_id': null,
            }
          ],
        });
        expect(find.text('guardado'), findsOneWidget);
      });
    });

    testWidgets('si no se pudo guardar lo dice, y reintenta', (tester) async {
      final backend = conSalida()
        ..cuando('POST /act/50/borrador', {'message': 'Error'}, codigo: 500);
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        await tester.tap(find.text('Sí'));
        await esperarBorrador(tester);

        expect(find.text('no se pudo guardar, se reintenta'), findsOneWidget);

        backend.cuando('POST /act/50/borrador',
            {'guardado_at': '2026-09-26 18:31:00'});
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('guardado'), findsOneWidget);
      });
    });

    testWidgets('al volver se sigue donde se quedó', (tester) async {
      // El cuestionario de verdad, con las dos respondidas en el borrador:
      // abre en la última, lista para enviar.
      final backend = BackendDeActividades()
        ..cuando('GET /act/13/responder',
            fixtureAct('responder_cuestionario_borrador'))
        ..cuando('POST /act/13/enviar', {
          'nota': 50,
          'puntaje': 10,
          'puntaje_max': 10,
          'quedan_intentos': 0,
        });
      await backend.con(() async {
        await montar(tester, _fila(13, 'cuestionario'));

        expect(find.textContaining('3+3'), findsOneWidget);
        expect(find.text('Enviar'), findsOneWidget);

        await tester.tap(find.text('Enviar'));
        await tester.pumpAndSettle();

        final enviadas =
            backend.cuerpoDe('POST /act/13/enviar')['respuestas'] as List;
        expect(enviadas.map((r) => r['opcion_ids']), [
          [19],
          [21]
        ]);
        expect(find.text('Tu nota: 50 de 50.'), findsOneWidget);
      });
    });
  });

  group('cuando el servidor dice que no', () {
    testWidgets('409: la actividad cerró mientras respondía', (tester) async {
      final backend = conSalida()
        ..cuando('POST /act/50/enviar', fixtureAct('error_409'), codigo: 409);
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar'));
        await tester.pumpAndSettle();

        expect(find.text('Esta actividad no está abierta.'), findsOneWidget);
        // Se queda en la pregunta, con lo escrito.
        expect(find.textContaining('¿Algo más?'), findsOneWidget);
        expect(find.text('Enviar'), findsOneWidget);
      });
    });

    testWidgets('abrirla ya cerrada (409) lo dice en vez de las preguntas',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/50/responder', fixtureAct('error_409'),
            codigo: 409);
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        expect(find.text('Esta actividad no está abierta.'), findsOneWidget);
      });
    });

    testWidgets('422: salta a la obligatoria que falta', (tester) async {
      final backend = conSalida()
        ..cuando(
            'POST /act/50/enviar',
            {
              'mensaje': 'Falta una pregunta obligatoria.',
              'faltan': [1],
            },
            codigo: 422);
      await backend.con(() async {
        await montar(tester, _fila(50, 'encuesta'));
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar'));
        await tester.pumpAndSettle();

        expect(find.text('Falta una pregunta obligatoria.'), findsOneWidget);
        expect(find.textContaining('¿Vas a ir?'), findsOneWidget);
      });
    });
  });

  testWidgets('el acudiente responde por su hijo, y lo dice', (tester) async {
    entrarComo('Acudiente', nombres: 'MARTA');
    final fila = _fila(11, 'encuesta',
        porAlumno: {'alumno_id': 465, 'nombre': 'LUCÍA MARTA PÉREZ ORTIZ'});
    final backend = BackendDeActividades()
      ..cuando('GET /act/11/responder?alumno_id=465',
          fixtureAct('responder_encuesta_acudiente'))
      ..cuando('POST /act/11/borrador', {'guardado_at': null})
      ..cuando('POST /act/11/enviar', {'quedan_intentos': 0});
    await backend.con(() async {
      await montar(tester, fila);
      expect(find.textContaining('Por Lucía'), findsOneWidget);

      await tester.tap(find.text('Sí'));
      await esperarBorrador(tester);
      expect(backend.cuerpoDe('POST /act/11/borrador')['alumno_id'], 465);

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(backend.cuerpoDe('POST /act/11/enviar')['alumno_id'], 465);
      expect(find.text('Quedó respondida por Lucía.'), findsOneWidget);
    });
  });
}
