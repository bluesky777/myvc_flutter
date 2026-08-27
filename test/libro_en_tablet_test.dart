import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Screens/LibroAsignaturaScreen.dart';
import 'package:myvc_flutter/Screens/PlanillaScreen.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';

/// Un servidor que devuelve siempre el mismo libro, sin salir a la red.
class ServidorFingido extends Server {
  @override
  Future put(String direccion, params) async =>
      http.Response(jsonEncode(_libro), 200);
}

final _libro = {
  'asignatura': {
    'asignatura_id': 1,
    'materia': 'Matemáticas',
    'nombre_grupo': 'Décimo B',
  },
  'unidades': [
    {
      'id': 10,
      'definicion': 'Funciones y sus gráficas',
      'porcentaje': 60,
      'orden': 1,
      'subunidades': [
        {
          'id': 101,
          'unidad_id': 10,
          'definicion': 'Quiz de función lineal',
          'porcentaje': 20,
          'orden': 1,
        },
      ],
    },
  ],
  'alumnos': [
    {
      'alumno_id': 100,
      'nombres': 'Ana',
      'apellidos': 'Acosta Pérez',
      'estado': 'MATR',
      'notas': [],
    },
  ],
};

Future<void> abrirEn(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: LibroAsignaturaScreen(
      asignatura: AsignaturaModel.fromJson(
        Map<String, dynamic>.from(_libro['asignatura'] as Map),
      ),
      servidor: ServidorFingido(),
    ),
  ));

  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthService.limpiar();
    AuthService.user = UserAutenticado(username: 'p', tipo: 'Profesor');
  });

  group('el ancho del contenido', () {
    testWidgets('nada se estira a lo ancho entero de la pantalla',
        (tester) async {
      // **Lo que esto protege, medido en un Pixel Tablet y no supuesto:** a
      // pantalla completa el nombre de un alumno quedaba a 1.900 px de su nota,
      // y el lápiz de un indicador a esa misma distancia de su título. Son
      // filas de dos extremos, y estiradas obligan al ojo a cruzar la pantalla
      // para emparejar las dos mitades.
      await abrirEn(tester, const Size(1729, 1080));

      for (final columna in tester.widgetList(find.byType(ColumnaDeFicha))) {
        final ancho = tester.getSize(find.byWidget(columna)).width;
        expect(ancho, lessThanOrEqualTo(Anchos.ficha));
      }
    });

    testWidgets('en un teléfono ocupa todo y no hay dos columnas',
        (tester) async {
      // La mitad del frente de tablets: nada de esto puede tocar la pantalla
      // que usa todo el mundo.
      await abrirEn(tester, const Size(400, 800));

      expect(tester.getSize(find.byType(TabBarView)).width, 400);
      expect(find.byType(PlanillaScreen), findsNothing);
    });
  });

  group('maestro-detalle', () {
    testWidgets('en tablet la lista y la planilla caben a la vez',
        (tester) async {
      await abrirEn(tester, const Size(1729, 1080));

      // Antes de elegir no hay planilla montada, y lo dice en su sitio.
      expect(find.byType(PlanillaScreen), findsNothing);
      expect(find.textContaining('Elige en la lista'), findsOneWidget);

      await tester.tap(find.textContaining('Quiz de función lineal'));
      await tester.pumpAndSettle();

      // Y ahora la planilla está **dentro** de esta pantalla, no empujada
      // encima: es el punto entero del maestro-detalle.
      expect(find.byType(PlanillaScreen), findsOneWidget);
      expect(find.text('Matemáticas'), findsOneWidget);
    });

    testWidgets('la lista mide lo suyo y el resto es para la planilla',
        (tester) async {
      await abrirEn(tester, const Size(1729, 1080));
      await tester.tap(find.textContaining('Quiz de función lineal'));
      await tester.pumpAndSettle();

      final maestro = tester.getSize(
        find.ancestor(
          of: find.textContaining('Quiz de función lineal'),
          matching: find.byType(SizedBox),
        ).last,
      );

      expect(maestro.width, Anchos.maestro);
    });

    testWidgets('la planilla encajada no trae su propia barra',
        (tester) async {
      // Dos AppBar apiladas —la de la asignatura y la del indicador— serían dos
      // títulos diciendo casi lo mismo y una franja menos de sitio para las
      // treinta notas. El título del indicador lo pone la cabecera encajada.
      await abrirEn(tester, const Size(1729, 1080));
      await tester.tap(find.textContaining('Quiz de función lineal'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('en un teléfono tocar sigue abriendo la planilla aparte',
        (tester) async {
      await abrirEn(tester, const Size(400, 800));

      await tester.tap(find.textContaining('Quiz de función lineal'));
      await tester.pumpAndSettle();

      // Empujada encima, con su barra propia: la de la asignatura ya no está.
      expect(find.byType(PlanillaScreen), findsOneWidget);
      expect(find.text('Matemáticas'), findsNothing);
    });
  });
}
