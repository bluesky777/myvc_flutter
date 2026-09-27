import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Screens/MisRespuestasActividadScreen.dart';

import 'actividades_backend_de_mentira.dart';

/// «Mis respuestas»: la nota «N de nota_maxima» con su planilla al lado, lo
/// mío en cada pregunta y la marca «tú» en los resultados compartidos.
void main() {
  setUp(() => entrarComo('Alumno'));
  tearDown(AuthService.limpiar);

  Future<void> montar(WidgetTester tester, Widget pantalla) async {
    enTelefono(tester);
    await tester.pumpWidget(MaterialApp(home: pantalla));
    await tester.pumpAndSettle();
  }

  ActEnBandeja filaDe(String fixture) => ActEnBandeja.fromJson(
      Map<String, dynamic>.from(objetoAct(fixture)['actividad'] as Map));

  group('la nota', () {
    testWidgets('la tarea calificada: 42 de 50, = 84 en la planilla',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/22/mis-respuestas',
            fixtureAct('mis_respuestas_tarea_calificada'));
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_tarea_calificada')));

        expect(find.text('Mis respuestas'), findsOneWidget);
        expect(find.text('Tu nota: 42 de 50 · = 84 en la planilla'),
            findsOneWidget);
        // El anillo: la nota grande y «de 50» debajo.
        expect(find.text('42'), findsOneWidget);
        expect(find.text('de 50'), findsOneWidget);
        expect(find.text('Calificada'), findsOneWidget);
        expect(find.textContaining('Muy bien los tres animales.'),
            findsOneWidget);
      });
    });

    testWidgets('si la planilla dice lo mismo, no se repite', (tester) async {
      final datos = objetoAct('mis_respuestas_tarea_calificada')
        ..['nota_maxima'] = 100
        ..['nota_planilla'] = 42;
      final backend = BackendDeActividades()
        ..cuando('GET /act/22/mis-respuestas', datos);
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_tarea_calificada')));

        expect(find.text('Tu nota: 42 de 100'), findsOneWidget);
        expect(find.textContaining('en la planilla'), findsNothing);
      });
    });

    testWidgets('el cuestionario: su nota, las correctas y lo mío',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/24/mis-respuestas',
            fixtureAct('mis_respuestas_cuestionario'));
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_cuestionario')));

        expect(find.text('Tu nota: 100 de 100'), findsOneWidget);
        // «1 de 1» correctas y «1 de 1» puntos.
        expect(find.text('1 de 1'), findsNWidgets(2));
        expect(find.text('correctas'), findsOneWidget);
        // `mia` es la opción 48, «22», y acertó.
        expect(find.text('Tu respuesta: 22', findRichText: true),
            findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });
    });

    testWidgets('sin nota todavía, lo dice', (tester) async {
      final datos = objetoAct('mis_respuestas_cuestionario')
        ..['nota'] = null
        ..['nota_planilla'] = null;
      final backend = BackendDeActividades()
        ..cuando('GET /act/24/mis-respuestas', datos);
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_cuestionario')));

        expect(find.textContaining('Tu nota:'), findsNothing);
        expect(
            find.text('La nota y las respuestas correctas se ven cuando el '
                'cuestionario cierre.'),
            findsOneWidget);
      });
    });
  });

  group('la encuesta', () {
    testWidgets('lo mío, con el nombre de la opción', (tester) async {
      entrarComo('Acudiente');
      final backend = BackendDeActividades()
        ..cuando('GET /act/9/mis-respuestas?alumno_id=590',
            fixtureAct('mis_respuestas_acudiente'));
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_acudiente')));

        // El acudiente ve de qué hijo es, y se pide con su alumno_id.
        expect(find.text('Respuestas · Ana'), findsOneWidget);
        expect(find.text('Tarde (5:00 p. m.)'), findsOneWidget);
      });
    });

    testWidgets('el alumno no manda alumno_id aunque se lo pasen',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/9/mis-respuestas',
            fixtureAct('mis_respuestas_acudiente'));
      await backend.con(() async {
        await montar(
            tester,
            const MisRespuestasActividadScreen.porId(
                actividadId: 9, alumnoId: 590, paraQuien: 'Ana'));

        expect(backend.rutasPedidas, ['GET /act/9/mis-respuestas']);
        expect(find.text('Mis respuestas'), findsOneWidget);
      });
    });

    testWidgets('los compartidos con pocas respuestas no enseñan cifras',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/4/mis-respuestas',
            fixtureAct('mis_respuestas_encuesta_compartida'));
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_encuesta_compartida')));

        expect(find.text('Resultados del grupo'), findsOneWidget);
        expect(
            find.text('Muy pocas respuestas para enseñarlas sin que se sepa de '
                'quién son.'),
            findsOneWidget);

        await tester.tap(find.descendant(
            of: find.byType(SegmentedButton<bool>),
            matching: find.text('Mis respuestas')));
        await tester.pumpAndSettle();
        expect(find.text('Sí'), findsOneWidget);
        expect(find.text('Ver los animales de la granja.'), findsOneWidget);
      });
    });

    testWidgets('en las barras, la mía lleva «tú»', (tester) async {
      final datos = objetoAct('mis_respuestas_encuesta_compartida');
      final compartidos = Map<String, dynamic>.from(datos['compartidos'] as Map);
      compartidos['participacion'] = {'destinatarios': 30, 'respondieron': 12};
      compartidos['preguntas'] = [
        {
          'pregunta_id': 1,
          'tipo': 'sino',
          'enunciado': '¿Te gustó la salida pedagógica?',
          'respondida_por': 12,
          'oculto': false,
          'opciones': [
            {'opcion_id': 1, 'definicion': 'Sí', 'n': 9, 'mia': true},
            {'opcion_id': 2, 'definicion': 'No', 'n': 3, 'mia': false},
          ],
        }
      ];
      datos['compartidos'] = compartidos;
      final backend = BackendDeActividades()
        ..cuando('GET /act/4/mis-respuestas', datos);
      await backend.con(() async {
        await montar(tester,
            MisRespuestasActividadScreen(
                fila: filaDe('mis_respuestas_encuesta_compartida')));

        expect(find.text('tú'), findsOneWidget);
        expect(find.text('75 %'), findsOneWidget);
        expect(find.text('25 %'), findsOneWidget);
      });
    });
  });

  group('lo que no está', () {
    testWidgets('409 con la actividad abierta: todavía no la respondió',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/23/mis-respuestas', fixtureAct('error_409'),
            codigo: 409);
      await backend.con(() async {
        await montar(
            tester,
            MisRespuestasActividadScreen(
                fila: ActEnBandeja.fromJson(const {
              'id': 23,
              'modo': 'encuesta',
              'estado': 'abierta',
            })));

        expect(find.text('Todavía no has respondido esta actividad.'),
            findsOneWidget);
      });
    });

    testWidgets('409 con la actividad cerrada: cerró sin respuesta',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/10/mis-respuestas', fixtureAct('error_409'),
            codigo: 409);
      await backend.con(() async {
        await montar(
            tester,
            MisRespuestasActividadScreen(
                fila: ActEnBandeja.fromJson(const {
              'id': 10,
              'modo': 'encuesta',
              'estado': 'cerrada',
            })));

        expect(find.text('Esta actividad cerró sin que la respondieras.'),
            findsOneWidget);
      });
    });
  });
}
