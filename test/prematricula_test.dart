import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/PrematriculaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Widgets/TarjetaDePrematricula.dart';

class ServidorQueContesta extends Server {
  ServidorQueContesta({this.cuerpo = '{}', this.codigo = 200});

  final String cuerpo;
  final int codigo;
  final List<({String direccion, dynamic params})> pedidos = [];

  @override
  Future put(String direccion, params) async {
    pedidos.add((direccion: direccion, params: params));
    return http.Response(cuerpo, codigo);
  }
}

/// Lo que manda `ChangesAsked/to-me` a un acudiente con la prematrícula abierta.
Map<String, dynamic> muroConPrematricula({
  bool faltaPago = false,
  String? estado,
  List<Map<String, dynamic>>? grupos,
}) =>
    {
      'alumnos': [
        {
          'alumno_id': 31,
          'nombres': 'Laura Sofía',
          'apellidos': 'Mejía',
          'nombre_grupo': '7A',
          'prematricula': estado == null
              ? {'estado': null}
              : {'estado': estado, 'nombre_grupo': '8A'},
          'falta_pago_renovacion': faltaPago,
        },
      ],
      'grados_sig': grupos ??
          [
            {'id': 80, 'nombre': '8A', 'abrev': '8A'},
            {'id': 81, 'nombre': '8B', 'abrev': '8B'},
          ],
    };

void main() {
  group('leer la prematrícula del muro', () {
    test('sin prematricula ni grados_sig, el colegio no la abrió', () {
      expect(
        leerPrematricula({
          'alumnos': [
            {'alumno_id': 31, 'nombres': 'Laura'},
          ],
          'grados_sig': [],
        }),
        isNull,
      );
    });

    test('abierta: los hijos, su estado y los grupos del año siguiente', () {
      final pre = leerPrematricula(muroConPrematricula(estado: 'PREA'))!;
      expect(pre.grupos.map((g) => g.nombre), ['8A', '8B']);
      expect(pre.hijos.single.comoQuedo, 'Prematriculado en');
      expect(pre.hijos.single.grupoSiguiente, '8A');
      expect(pre.hijos.single.primerNombre, 'Laura');
    });

    test('falta_pago_renovacion llega como venga de PDO', () {
      final pre = leerPrematricula(muroConPrematricula(faltaPago: true))!;
      expect(pre.hijos.single.faltaPago, isTrue);
      expect(pre.hijos.single.comoQuedo, isNull);
    });
  });

  group('PUT matriculas/prematricular', () {
    test('manda PREA con el alumno y el grupo', () async {
      final servidor = ServidorQueContesta();
      final salida = await prematricular(servidor, alumnoId: 31, grupoId: 80);

      expect(salida.resultado, ResultadoPrematricula.hecho);
      expect(servidor.pedidos.single.direccion, '/matriculas/prematricular');
      expect(servidor.pedidos.single.params,
          {'alumno_id': 31, 'grupo_id': 80, 'estado': 'PREA'});
    });

    test('el 409 es el pago que falta, con la frase del servidor', () async {
      final salida = await prematricular(
        ServidorQueContesta(
          codigo: 409,
          cuerpo: jsonEncode({
            'message': 'Para prematricular, primero tesorería tiene que '
                'registrar el pago del formulario de renovación.',
          }),
        ),
        alumnoId: 31,
        grupoId: 80,
      );
      expect(salida.resultado, ResultadoPrematricula.faltaPago);
      expect(salida.mensaje, startsWith('Para prematricular'));
    });

    test('el 404 quedó guardado: el servidor no la encontró al releer',
        () async {
      final salida = await prematricular(
        ServidorQueContesta(codigo: 404),
        alumnoId: 31,
        grupoId: 80,
      );
      expect(salida.resultado, ResultadoPrematricula.hecho);
    });

    test('la ruta pide JSON, para que el 409 no llegue en HTML', () {
      expect(Server.pideJson('/matriculas/prematricular'), isTrue);
    });
  });

  group('la tarjeta', () {
    Future<void> montar(
      WidgetTester tester,
      Map<String, dynamic> muro, {
      Server? servidor,
      VoidCallback? alCambiar,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TarjetaDePrematricula(
                prematricula: leerPrematricula(muro)!,
                anio: 2027,
                alCambiar: alCambiar ?? () {},
                servidor: servidor,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('sin pago, lo dice y no ofrece el botón', (tester) async {
      await montar(tester, muroConPrematricula(faltaPago: true));

      expect(find.text('Prematrícula 2027'), findsOneWidget);
      expect(find.textContaining('primero tesorería'), findsOneWidget);
      expect(find.textContaining('Prematricular a'), findsNothing);
    });

    testWidgets('ya prematriculado: el sello con el grupo', (tester) async {
      await montar(tester, muroConPrematricula(estado: 'PREA'));

      expect(find.text('Prematriculado en 8A'), findsOneWidget);
      expect(find.textContaining('acércate a secretaría'), findsOneWidget);
    });

    testWidgets('sin grupos del año siguiente, lo dice', (tester) async {
      await montar(tester, muroConPrematricula(grupos: []));

      expect(find.textContaining('todavía no ha abierto los grupos de 2027'),
          findsOneWidget);
    });

    testWidgets('elegir grupo, confirmar y recargar', (tester) async {
      final servidor = ServidorQueContesta();
      var recargas = 0;
      await montar(
        tester,
        muroConPrematricula(),
        servidor: servidor,
        alCambiar: () => recargas++,
      );

      final boton = find.widgetWithText(FilledButton, 'Prematricular a Laura');
      expect(tester.widget<FilledButton>(boton).onPressed, isNull,
          reason: 'sin grupo elegido no se enciende');

      await tester.tap(find.text('Elegir el grupo para 2027'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8B'));
      await tester.pumpAndSettle();

      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('¿Prematricular a Laura en 8B?'), findsOneWidget);

      await tester.tap(find.text('Sí, prematricular'));
      await tester.pumpAndSettle();

      expect(servidor.pedidos.single.params['grupo_id'], 81);
      expect(recargas, 1);
    });

    testWidgets('el 409 en vivo cambia el renglón al aviso del pago',
        (tester) async {
      await montar(
        tester,
        muroConPrematricula(),
        servidor: ServidorQueContesta(codigo: 409),
      );

      await tester.tap(find.text('Elegir el grupo para 2027'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8A'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(FilledButton, 'Prematricular a Laura'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, prematricular'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Prematricular a'), findsNothing);
      expect(find.textContaining('primero tesorería'), findsWidgets);
    });
  });
}
