import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Screens/ActividadesScreen.dart';
import 'package:myvc_flutter/Screens/AvisosDeActividadesScreen.dart';
import 'package:myvc_flutter/Screens/MisRespuestasActividadScreen.dart';
import 'package:myvc_flutter/Screens/ResponderActividadScreen.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';

import 'actividades_backend_de_mentira.dart';

/// La bandeja —pendientes y hechas, el selector de hijo—, la campana y a
/// dónde lleva un aviso, contra las respuestas de verdad de `act/*`.
void main() {
  setUp(AuthService.limpiar);
  tearDown(AuthService.limpiar);

  BackendDeActividades delAlumno() => BackendDeActividades()
    ..cuando('GET /act/bandeja?vista=responder', fixtureAct('bandeja_alumno'))
    ..cuando('GET /act/avisos?limite=30', fixtureAct('avisos_alumno'));

  BackendDeActividades delAcudiente() => BackendDeActividades()
    ..cuando(
        'GET /act/bandeja?vista=responder', fixtureAct('bandeja_acudiente'))
    ..cuando('GET /act/avisos?limite=30', fixtureAct('avisos_acudiente'));

  Future<void> montar(WidgetTester tester, {AvisoDeActividad? aviso}) async {
    enTelefono(tester);
    await tester.pumpWidget(
        MaterialApp(home: ActividadesScreen(aviso: aviso)));
    await tester.pumpAndSettle();
  }

  group('la bandeja del alumno', () {
    testWidgets('abre en pendientes, con cuántas son', (tester) async {
      entrarComo('Alumno');
      final backend = delAlumno();
      await backend.con(() async {
        await montar(tester);

        expect(find.text('Pendientes · 3'), findsOneWidget);
        expect(find.text('Prueba T5 avisos'), findsOneWidget);
        expect(find.text('T3 tarea sobre 50'), findsOneWidget);
        expect(find.text('T3 escala 50'), findsOneWidget);
        // Lo ya hecho no sale aquí.
        expect(find.text('T23 tarea planilla'), findsNothing);
      });
    });

    testWidgets('en «Hechas» está lo enviado y lo que cerró sin respuesta',
        (tester) async {
      entrarComo('Alumno');
      final backend = delAlumno();
      await backend.con(() async {
        await montar(tester);
        await tester.tap(find.text('Hechas'));
        await tester.pumpAndSettle();

        expect(find.text('ENTREGADAS Y RESPONDIDAS'), findsOneWidget);
        expect(find.text('T23 tarea planilla'), findsOneWidget);
        expect(find.text('Prueba T5 avisos'), findsNothing);
        await tester.scrollUntilVisible(
            find.text('CERRARON SIN RESPUESTA'), 200,
            scrollable: find.descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable)));
        expect(find.text('T3 encuesta 4 grupos'), findsOneWidget);
      });
    });

    testWidgets('tocar una pendiente abre responder', (tester) async {
      entrarComo('Alumno');
      final backend = delAlumno()
        ..cuando('GET /act/13/responder',
            fixtureAct('responder_cuestionario_borrador'));
      await backend.con(() async {
        await montar(tester);
        await tester.tap(find.text('T3 escala 50'));
        await tester.pumpAndSettle();

        expect(find.byType(ResponderActividadScreen), findsOneWidget);
      });
    });

    testWidgets('un error se enseña con su frase y se puede reintentar',
        (tester) async {
      entrarComo('Alumno');
      final backend = BackendDeActividades()
        ..cuando('GET /act/bandeja?vista=responder',
            {'message': 'No autenticado.'},
            codigo: 401);
      await backend.con(() async {
        await montar(tester);
        expect(find.text('No autenticado.'), findsOneWidget);

        backend.cuando(
            'GET /act/bandeja?vista=responder', fixtureAct('bandeja_alumno'));
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Pendientes · 3'), findsOneWidget);
      });
    });
  });

  group('el acudiente con dos hijos', () {
    testWidgets('elige hijo: cada uno ve sólo sus filas', (tester) async {
      entrarComo('Acudiente');
      final backend = delAcudiente();
      await backend.con(() async {
        await montar(tester);

        expect(find.text('Eres acudiente oficial de:'), findsOneWidget);
        expect(find.text('Lucía'), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        // Arranca con el primero: Lucía tiene una encuesta por responder.
        expect(find.text('Pendientes · 1'), findsOneWidget);
        expect(find.text('T3 acudientes de Décimo'), findsOneWidget);

        await tester.tap(find.text('Ana'));
        await tester.pumpAndSettle();
        expect(find.text('No tienes actividades pendientes.'), findsOneWidget);

        await tester.tap(find.text('Hechas'));
        await tester.pumpAndSettle();
        // La encuesta «una vez por hijo» sale una sola vez: la de Ana.
        expect(find.text('Integración: horario de reunión de padres'),
            findsOneWidget);
        expect(find.text('T3 coord'), findsNothing);
      });
    });

    testWidgets('un alumno no ve el selector aunque lleguen filas raras',
        (tester) async {
      entrarComo('Alumno');
      final backend = delAcudiente();
      await backend.con(() async {
        await montar(tester);
        expect(find.text('Eres acudiente oficial de:'), findsNothing);
      });
    });
  });

  group('la campana', () {
    testWidgets('dice cuántos sin leer; abrirla los marca y abre el elegido',
        (tester) async {
      entrarComo('Alumno');
      // Como el servidor: después de marcarlos, ya no hay sin leer.
      var marcados = false;
      final backend = delAlumno()
        ..cuandoCon('GET /act/avisos?limite=30', (_) {
          final avisos = objetoAct('avisos_alumno');
          if (marcados) avisos['no_leidos'] = 0;
          return BackendDeActividades.respuesta(avisos);
        })
        ..cuandoCon('POST /act/avisos/leidos', (_) {
          marcados = true;
          return BackendDeActividades.respuesta({'ok': true});
        })
        ..cuando('GET /act/22/mis-respuestas',
            fixtureAct('mis_respuestas_tarea_calificada'));
      await backend.con(() async {
        await montar(tester);
        expect(find.text('10'), findsOneWidget);

        await tester.tap(find.byTooltip('Avisos'));
        await tester.pumpAndSettle();

        expect(find.byType(AvisosDeActividadesScreen), findsOneWidget);
        expect(find.text('Cambió la nota de «T23 tarea planilla».'),
            findsOneWidget);
        // Los que ya traía la bandeja no se vuelven a pedir.
        expect(backend.rutasPedidas.where((r) => r.startsWith('GET /act/avisos')),
            hasLength(1));
        expect(backend.cuerpoDe('POST /act/avisos/leidos'), {'hasta_id': 95});

        await tester.tap(find.text('Cambió la nota de «T23 tarea planilla».'));
        await tester.pumpAndSettle();

        // La tarea calificada se abre en «mis respuestas».
        expect(find.byType(MisRespuestasActividadScreen), findsOneWidget);
        expect(backend.rutasPedidas, contains('GET /act/22/mis-respuestas'));

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('10'), findsNothing);
      });
    });

    testWidgets('sin la tanda 5 (404), no hay campana', (tester) async {
      entrarComo('Alumno');
      final backend = BackendDeActividades()
        ..cuando(
            'GET /act/bandeja?vista=responder', fixtureAct('bandeja_alumno'));
      await backend.con(() async {
        await montar(tester);
        expect(find.byTooltip('Avisos'), findsNothing);
        expect(find.text('Pendientes · 3'), findsOneWidget);
      });
    });
  });

  group('un aviso abre su actividad', () {
    testWidgets('el del alumno, por su id', (tester) async {
      entrarComo('Alumno');
      final backend = delAlumno()
        ..cuando('GET /act/13/responder',
            fixtureAct('responder_cuestionario_borrador'));
      await backend.con(() async {
        await montar(tester,
            aviso: AvisoDeActividad.deDatos({
              'pantalla': 'actividad',
              'actividad_id': '13',
              'clase': 'recordatorio',
              'alumno_id': '1130',
            }));

        expect(find.byType(ResponderActividadScreen), findsOneWidget);
        expect(backend.rutasPedidas, contains('GET /act/13/responder'));
      });
    });

    testWidgets('el del acudiente abre la fila de ESE hijo', (tester) async {
      entrarComo('Acudiente');
      final backend = delAcudiente()
        ..cuando('GET /act/9/mis-respuestas?alumno_id=590',
            fixtureAct('mis_respuestas_acudiente'));
      await backend.con(() async {
        await montar(tester,
            aviso: const AvisoDeActividad(
                actividadId: 9, alumnoId: 590, clase: 'resultados'));

        // La 9 está dos veces —una por hijo—: tiene que ser la de Ana.
        expect(find.text('Respuestas · Ana'), findsOneWidget);
        expect(backend.rutasPedidas,
            contains('GET /act/9/mis-respuestas?alumno_id=590'));
      });
    });

    testWidgets(
        'la nota de una tarea del hijo, que no está en su lista, '
        'la abre en «mis respuestas» del hijo', (tester) async {
      entrarComo('Acudiente');
      final backend = delAcudiente()
        ..cuando('GET /act/22/mis-respuestas?alumno_id=465',
            fixtureAct('mis_respuestas_tarea_calificada'));
      await backend.con(() async {
        await montar(tester,
            aviso: AvisoDeActividad.deDatos({
              'pantalla': 'actividad',
              'actividad_id': '22',
              'clase': 'calificada',
              'alumno_id': '465',
            }));

        expect(find.text('Respuestas · Lucía'), findsOneWidget);
        expect(find.text('Tu nota: 42 de 50 · = 84 en la planilla'),
            findsOneWidget);
      });
    });

    testWidgets('una tarea nueva del hijo: la responde él desde su cuenta',
        (tester) async {
      entrarComo('Acudiente');
      final backend = delAcudiente();
      await backend.con(() async {
        await montar(tester,
            aviso: AvisoDeActividad.deDatos({
              'pantalla': 'actividad',
              'actividad_id': '28',
              'clase': 'publicada',
              'alumno_id': '465',
            }));

        // `findsWidgets`: el aviso sale en cada Scaffold de la cáscara (el
        // del menú, detrás, también); en pantalla se ve uno.
        expect(find.text('Lucía la responde desde su propia cuenta.'),
            findsWidgets);
        expect(find.byType(MisRespuestasActividadScreen), findsNothing);
      });
    });

    testWidgets('el alumno con un aviso de algo que ya no está',
        (tester) async {
      entrarComo('Alumno');
      final backend = delAlumno();
      await backend.con(() async {
        await montar(tester,
            aviso: const AvisoDeActividad(actividadId: 999, clase: 'publicada'));
        expect(find.text('Esa actividad ya no está en tu lista.'),
            findsWidgets);
      });
    });
  });
}
