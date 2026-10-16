import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Widgets/DecisionDeMatricula.dart';

/// El recorrido tiene tres estaciones; Laura (31) está prematriculada en 8A.
class ServidorDeLaCampana extends Server {
  ServidorDeLaCampana({this.estado = 'PREA', this.contestaAlEscribir});

  final String estado;
  final http.Response? contestaAlEscribir;
  final List<({String direccion, dynamic params})> escrituras = [];

  @override
  Future get(String direccion) async {
    if (direccion == '/estaciones') {
      return http.Response(
        jsonEncode({
          'campana': {'year_id': 9, 'year': 2027, 'abierta': true},
          'estaciones': [
            {'nro': 1, 'nombre': 'Recepción'},
            {'nro': 2, 'nombre': 'Documentos'},
            {'nro': 3, 'nombre': 'Rectoría'},
          ],
        }),
        200,
      );
    }
    if (direccion == '/estaciones/alumnos') {
      return http.Response(
        jsonEncode({
          'year': 2027,
          'year_id': 9,
          'grupos': [
            {'id': 80, 'nombre': 'Octavo A', 'abrev': '8A'},
          ],
          'alumnos': [
            {'alumno_id': 31, 'grupo_id': 80, 'estado': estado},
          ],
          'anterior': null,
        }),
        200,
      );
    }
    return http.Response('{}', 404);
  }

  @override
  Future post(String direccion, params) async {
    escrituras.add((direccion: direccion, params: params));
    return contestaAlEscribir ?? http.Response('{}', 200);
  }

  @override
  Future put(String direccion, params) async {
    escrituras.add((direccion: direccion, params: params));
    return contestaAlEscribir ?? http.Response('{}', 200);
  }
}

const laura = PersonaEnCola(id: 31, nombres: 'Laura', apellidos: 'Mejía');

Future<void> montar(WidgetTester tester, int nro, Server servidor) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DecisionDeMatricula(
            estacion: Estacion(nro: nro, nombre: 'Estación $nro'),
            persona: laura,
            servidor: servidor,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('la lista del año: grupo por abreviatura y estado por alumno', () {
    final m = leerLasMatriculasDeLaCampana(jsonEncode({
      'grupos': [
        {'id': 80, 'nombre': 'Octavo A', 'abrev': '8A'},
      ],
      'alumnos': [
        {'alumno_id': 31, 'grupo_id': 80, 'estado': 'MATR'},
        {'alumno_id': 32, 'grupo_id': null, 'estado': 'PREA'},
      ],
    }));
    expect(m.keys, [31]);
    expect(m[31]!.grupo, '8A');
    expect(m[31]!.estado, 'MATR');
  });

  testWidgets('en una estación que no es la última no pinta nada',
      (tester) async {
    await montar(tester, 2, ServidorDeLaCampana());
    expect(find.textContaining('Matricular'), findsNothing);
  });

  testWidgets('en la última: matricular con su grupo y el año de la campaña',
      (tester) async {
    final servidor = ServidorDeLaCampana();
    await montar(tester, 3, servidor);

    expect(find.text('8A - 2027 · Prematriculado'), findsOneWidget);
    await tester.tap(find.text('Matricular en 8A - 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, matricular'));
    await tester.pumpAndSettle();

    expect(servidor.escrituras.single.direccion, '/matriculas/matricularuno');
    expect(servidor.escrituras.single.params,
        {'alumno_id': 31, 'grupo_id': 80, 'year_id': 9});
    expect(find.text('Matriculado en 8A - 2027.'), findsOneWidget);
  });

  testWidgets('ya matriculado: el botón se apaga y lo dice', (tester) async {
    await montar(tester, 3, ServidorDeLaCampana(estado: 'MATR'));

    final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ya está matriculado en 8A - 2027'));
    expect(boton.onPressed, isNull);
  });

  testWidgets('asistente es prematricular con ASIS, y el 404 entró',
      (tester) async {
    final servidor =
        ServidorDeLaCampana(contestaAlEscribir: http.Response('{}', 404));
    await montar(tester, 3, servidor);

    await tester.tap(find.text('Poner como asistente'));
    await tester.pumpAndSettle();

    expect(servidor.escrituras.single.params,
        {'alumno_id': 31, 'grupo_id': 80, 'estado': 'ASIS'});
    expect(find.text('Queda como asistente.'), findsOneWidget);
  });

  testWidgets('sin permiso, se enseña la frase del servidor', (tester) async {
    await montar(
      tester,
      3,
      ServidorDeLaCampana(
        contestaAlEscribir: http.Response(
            jsonEncode({'message': 'No tiene permisos para editar'}), 400),
      ),
    );

    await tester.tap(find.text('Matricular en 8A - 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, matricular'));
    await tester.pumpAndSettle();

    expect(find.text('No tiene permisos para editar'), findsOneWidget);
  });
}
