import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:myvc_flutter/Screens/ActividadesScreen.dart';
import 'package:myvc_flutter/Screens/RouteGenerator.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los temas `actividad` —el del alumno y el de la persona, `usuario`— y a
/// dónde lleva el push de una actividad.
///
/// [Interruptores.actividades] es `const`: lo que se pruebe encendido sólo
/// corre con `flutter test --dart-define=ACTIVIDADES=true`, y lo apagado sin
/// él. Las dos tandas tienen que salir verdes.
const _soloEncendido = Interruptores.actividades
    ? false
    : 'sólo con --dart-define=ACTIVIDADES=true';
const _soloApagado = Interruptores.actividades
    ? 'sólo sin --dart-define=ACTIVIDADES=true'
    : false;

/// El catálogo de verdad de `GET notificaciones/temas` del acudiente de dos
/// hijos (8myvc `feat/actividades`, 26 sep 2026), con los nombres y los
/// hashes cambiados.
TemasDeNotificacion _catalogo() => TemasDeNotificacion.deCuerpo(
    File('test/fixtures/actividades/temas_acudiente.json').readAsStringSync());

const _deLucia = 'a_1111aaaa_actividad';
const _deAna = 'a_2222bbbb_actividad';
const _deLaPersona = 'u_5555eeee_actividad';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PendientesNotificaciones.temasDelColegio = false;
  });

  group('el catálogo', () {
    test('trae el tema de actividad de cada hijo y el de la persona', () {
      final c = _catalogo();

      expect(c.alumnos.map((a) => a.temas['actividad']), [_deLucia, _deAna]);
      expect(c.delUsuario, {'actividad': _deLaPersona});
    });

    test('un servidor sin la tanda 5 no manda `usuario`: queda vacío', () {
      final c = TemasDeNotificacion.deCuerpo(
          '{"alumnos": [], "colegio": {"colegio_muro": "c_1"}}');
      expect(c.delUsuario, isEmpty);
    });
  });

  group('apagado, como va a los colegios', () {
    test('no se apunta a ningún tema de actividad', () {
      final cambio = Avisos.calcularCambio(
        catalogo: _catalogo(),
        encendidos: TipoDeAviso.values,
        anotados: const {},
      );

      expect(cambio.coger.where((t) => t.endsWith('_actividad')), isEmpty);
      // Los otros cinco tipos, de los dos hijos, sí.
      expect(cambio.coger, hasLength(10));
    }, skip: _soloApagado);

    test('y si el teléfono ya estaba apuntado, se da de baja', () {
      // Una versión de prueba con el módulo encendido dejó el teléfono
      // apuntado: la de la tienda, apagada, lo suelta.
      final catalogo = _catalogo();
      final cambio = Avisos.calcularCambio(
        catalogo: catalogo,
        encendidos: TipoDeAviso.values,
        anotados: {
          ...catalogo.temasDe(TipoDeAviso.values),
          _deLucia,
          _deAna,
          _deLaPersona,
        },
      );

      expect(cambio.soltar, {_deLucia, _deAna, _deLaPersona});
      expect(cambio.coger, isEmpty);
    }, skip: _soloApagado);

    test('el push de una actividad cae al muro', () {
      expect(Avisos.abridorDe({'pantalla': 'actividad', 'actividad_id': '22'}),
          '/muro');
    }, skip: _soloApagado);
  });

  group('encendido', () {
    test('se apunta al de cada hijo y al de la persona', () {
      final cambio = Avisos.calcularCambio(
        catalogo: _catalogo(),
        encendidos: TipoDeAviso.values,
        anotados: const {},
      );

      expect(cambio.coger, containsAll([_deLucia, _deAna, _deLaPersona]));
      expect(cambio.coger, hasLength(13));
    }, skip: _soloEncendido);

    test('apagar «Actividades» suelta los tres, y nada más', () {
      final catalogo = _catalogo();
      final cambio = Avisos.calcularCambio(
        catalogo: catalogo,
        encendidos: TipoDeAviso.values
            .where((t) => t != TipoDeAviso.actividad)
            .toList(),
        anotados: catalogo.temasDe(TipoDeAviso.values).toSet(),
      );

      expect(cambio.soltar, {_deLucia, _deAna, _deLaPersona});
      expect(cambio.coger, isEmpty);
    }, skip: _soloEncendido);

    test('el push de una actividad abre «Actividades», también en plural', () {
      expect(Avisos.abridorDe({'pantalla': 'actividad', 'actividad_id': '22'}),
          '/actividades');
      expect(Avisos.abridorDe({'pantalla': 'actividades'}), '/actividades');
    }, skip: _soloEncendido);
  });

  group('lo que trae el push', () {
    test('de un alumno: la actividad, la clase y el alumno', () {
      // FCM manda todo como texto.
      final a = AvisoDeActividad.deDatos({
        'pantalla': 'actividad',
        'actividad_id': '28',
        'clase': 'publicada',
        'alumno_id': '1130',
      })!;

      expect(a.actividadId, 28);
      expect(a.alumnoId, 1130);
      expect(a.clase, 'publicada');
      expect(a.esDeLoHecho, isFalse);
      expect(a.nombreAlumno, isNull);
    });

    test('el del tema de la persona no trae alumno', () {
      // La encuesta que se le pide AL acudiente llega por su tema propio.
      final a = AvisoDeActividad.deDatos({
        'pantalla': 'actividad',
        'actividad_id': '11',
        'clase': 'recordatorio',
      })!;

      expect(a.alumnoId, isNull);
    });

    test('la nota y los resultados son «de lo hecho»', () {
      for (final clase in ['calificada', 'nota_cambiada', 'resultados']) {
        expect(
            AvisoDeActividad.deDatos({'actividad_id': 1, 'clase': clase})!
                .esDeLoHecho,
            isTrue,
            reason: clase);
      }
      expect(
          AvisoDeActividad.deDatos({'actividad_id': 1, 'clase': 'por_cerrar'})!
              .esDeLoHecho,
          isFalse);
    });

    test('sin actividad_id no hay a cuál ir; una clase en blanco es null', () {
      expect(AvisoDeActividad.deDatos({'pantalla': 'actividad'}), isNull);
      expect(AvisoDeActividad.deDatos({'actividad_id': 'x'}), isNull);
      expect(AvisoDeActividad.deDatos({'actividad_id': '3', 'clase': ' '})!
          .clase, isNull);
    });
  });

  testWidgets('la ruta /actividades le pasa el aviso a la pantalla',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final contexto = tester.element(find.byType(SizedBox));
    const aviso = AvisoDeActividad(actividadId: 9, alumnoId: 590);

    final ruta = RouteGenerator.generateRoute(
            const RouteSettings(name: '/actividades', arguments: aviso))
        as MaterialPageRoute;
    final pantalla = ruta.builder(contexto) as ActividadesScreen;
    expect(pantalla.aviso, same(aviso));

    // Desde el menú, sin aviso.
    final sinAviso = RouteGenerator.generateRoute(
        const RouteSettings(name: '/actividades')) as MaterialPageRoute;
    expect((sinAviso.builder(contexto) as ActividadesScreen).aviso, isNull);
  });
}
