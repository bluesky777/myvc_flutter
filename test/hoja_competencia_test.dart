import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';
import 'package:myvc_flutter/Widgets/HojaCompetencia.dart';

/// Cuatro bandas con sus frases escritas, como las tendría un colegio que
/// estrene los prefijos.
const _conFrases = [
  EscalaDeValoracion(
    id: 4,
    desempenio: 'Superior',
    porcInicial: 91,
    porcFinal: 100,
    descripcion: 'Excelencia en',
  ),
  EscalaDeValoracion(
    id: 3,
    desempenio: 'Alto',
    porcInicial: 76,
    porcFinal: 90,
    descripcion: 'Fortaleza en',
  ),
  EscalaDeValoracion(
    id: 1,
    desempenio: 'Bajo',
    porcInicial: 0,
    porcFinal: 59,
    descripcion: 'Dificultad en',
    perdido: true,
  ),
];

/// Las mismas sin frase, que es el caso de TODOS los colegios hoy.
const _sinFrases = [
  EscalaDeValoracion(id: 4, desempenio: 'Superior', porcInicial: 91),
  EscalaDeValoracion(id: 3, desempenio: 'Alto', porcInicial: 76),
];

Future<CompetenciaEscrita?> abrir(
  WidgetTester tester, {
  required List<EscalaDeValoracion> escalas,
  String definicionInicial = '',
  String? tipoInicial,
  List<String> marcasUsadas = const [],
}) async {
  CompetenciaEscrita? devuelto;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              devuelto = await pedirCompetencia(
                context,
                titulo: 'MATEMÁTICAS · Sexto',
                escalas: escalas,
                definicionInicial: definicionInicial,
                tipoInicial: tipoInicial,
                marcasUsadas: marcasUsadas,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();

  return devuelto;
}

void main() {
  group('el previo de impresión', () {
    testWidgets('con frases, enseña una línea por banda mientras se escribe',
        (tester) async {
      await abrir(tester, escalas: _conFrases);

      // Sin texto no hay nada que previsualizar.
      expect(find.text('Se imprimirá:'), findsNothing);

      await tester.enterText(
        find.byType(TextField).first,
        'interpretar gráficas de barras',
      );
      await tester.pump();

      expect(find.text('Se imprimirá:'), findsOneWidget);

      // Las tres, y ésta es la razón de ser de la pantalla: una frase puede
      // encajar detrás de «Fortaleza en» y ser absurda detrás de «Dificultad
      // en». Con una sola de ejemplo, eso no se ve al escribir.
      expect(
        find.text('· Excelencia en interpretar gráficas de barras'),
        findsOneWidget,
      );
      expect(
        find.text('· Fortaleza en interpretar gráficas de barras'),
        findsOneWidget,
      );
      expect(
        find.text('· Dificultad en interpretar gráficas de barras'),
        findsOneWidget,
      );
    });

    testWidgets('sin frases, el bloque no se pinta', (tester) async {
      // Es el caso de todos los colegios hoy: las escalas vivas tienen la
      // descripción vacía. Un marco rotulado y vacío se lee como que falta algo.
      await abrir(tester, escalas: _sinFrases);

      await tester.enterText(find.byType(TextField).first, 'lo que sea');
      await tester.pump();

      expect(find.text('Se imprimirá:'), findsNothing);
    });

    testWidgets('borrar el texto se lleva el previo', (tester) async {
      await abrir(tester, escalas: _conFrases);

      await tester.enterText(find.byType(TextField).first, 'algo');
      await tester.pump();
      expect(find.text('Se imprimirá:'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(find.text('Se imprimirá:'), findsNothing);
    });
  });

  group('lo que devuelve', () {
    testWidgets('sin texto no se puede guardar', (tester) async {
      await abrir(tester, escalas: _conFrases);

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
    });

    testWidgets('el texto recortado y la marca en null cuando está vacía',
        (tester) async {
      // Null y no cadena vacía: el backend convierte el vacío en null, así que
      // mandar '' sería pedirle que deshaga algo que la app podía no haber
      // hecho.
      CompetenciaEscrita? devuelto;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  devuelto = await pedirCompetencia(
                    context,
                    titulo: 'x',
                    escalas: _conFrases,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        '  resolver problemas  ',
      );
      await tester.pump();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(devuelto, isNotNull);
      expect(devuelto!.definicion, 'resolver problemas');
      expect(devuelto!.tipo, isNull);
    });

    testWidgets('cancelar no devuelve nada', (tester) async {
      await abrir(tester, escalas: _conFrases, definicionInicial: 'ya escrita');

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Guardar'), findsNothing);
    });
  });

  group('la marca', () {
    testWidgets('es UN campo opcional y no tres', (tester) async {
      // El mockup del front pintaba una Saber, una Hacer y una Ser, y tres
      // filas con tres marcas distintas se leen como un trío obligatorio.
      // Medido en el backend: `tipo` es varchar(60) anulable y texto libre, y
      // nunca hubo ningún mínimo.
      await abrir(tester, escalas: _conFrases, marcasUsadas: ['Saber', 'Ser']);

      expect(find.text('Marca (opcional)'), findsOneWidget);
      expect(find.text('Saber'), findsNothing);
      expect(find.text('Hacer'), findsNothing);
    });

    testWidgets('la que ya tenía sale puesta al corregir', (tester) async {
      await abrir(
        tester,
        escalas: _conFrases,
        definicionInicial: 'construir figuras',
        tipoInicial: 'Hacer',
      );

      expect(find.text('construir figuras'), findsOneWidget);
      expect(find.text('Hacer'), findsOneWidget);
    });
  });
}
