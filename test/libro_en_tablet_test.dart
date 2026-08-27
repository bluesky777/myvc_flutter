import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Screens/LibroAsignaturaScreen.dart';
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

  group('el libro de una asignatura en tablet', () {
    testWidgets('el contenido no se estira a lo ancho de la pantalla',
        (tester) async {
      // **Lo que esto protege, medido en un Pixel Tablet y no supuesto:** a
      // pantalla completa el nombre de un alumno quedaba a 1.900 px de su nota,
      // y el lápiz de un indicador a esa misma distancia de su título. Son
      // filas de dos extremos, y estiradas obligan al ojo a cruzar la pantalla
      // para emparejar las dos mitades.
      await abrirEn(tester, const Size(1729, 1080));

      final ancho = tester.getSize(find.byType(TabBarView)).width;

      expect(ancho, Anchos.ficha);
      expect(ancho, lessThan(1729));
    });

    testWidgets('en un teléfono sigue ocupando todo', (tester) async {
      await abrirEn(tester, const Size(400, 800));

      expect(tester.getSize(find.byType(TabBarView)).width, 400);
    });

    testWidgets('el tope envuelve las dos pestañas, no una', (tester) async {
      // Son la misma matriz leída por sus dos lados. Si cada pestaña pusiera su
      // propio tope, cambiar de pestaña movería el contenido de sitio.
      await abrirEn(tester, const Size(1729, 1080));

      expect(
        find.descendant(
          of: find.byType(ColumnaDeFicha),
          matching: find.byType(TabBarView),
        ),
        findsOneWidget,
      );
    });
  });
}
