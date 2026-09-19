import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/LineaDeBoletinModel.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Widgets/TarjetaDeAsignatura.dart';

AsignaturaNotaModel _matematicas({double? nota = 82, String? banda = 'Alto'}) {
  return AsignaturaNotaModel(
    asignaturaId: 1,
    materia: 'MATEMÁTICAS',
    docente: 'Ariolfo Gómez',
    nota: nota,
    desempenio: banda,
  );
}

LineaDeBoletin _delCatalogo(String texto, {String? icono}) {
  return LineaDeBoletin.fromJson({
    'desempeno_id': 25,
    'texto': texto,
    'origen': 'catalogo',
    'nivel': 'Alto',
    'escala_id': 3,
    'orden': 1,
    if (icono != null) 'icono_infantil': icono,
  });
}

LineaDeBoletin _aMano(String texto) {
  return LineaDeBoletin.fromJson({
    'frase_asignatura_id': 900,
    'texto': texto,
    'origen': 'frase',
  });
}

Future<void> montar(
  WidgetTester tester, {
  required AsignaturaNotaModel asignatura,
  List<LineaDeBoletin> lineas = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TarjetaDeAsignatura(asignatura: asignatura, lineas: lineas),
        ),
      ),
    ),
  );
}

void main() {
  group('sin competencias — la tarjeta de siempre', () {
    testWidgets('la banda va debajo del docente, no junto a la nota',
        (tester) async {
      // **Es el caso de todos los colegios hoy**, y esta prueba está aquí para
      // que mover el rótulo no le cambie la pantalla a nadie que no haya
      // estrenado el modelo.
      await montar(tester, asignatura: _matematicas());

      expect(find.text('MATEMÁTICAS'), findsOneWidget);
      expect(find.text('Alto'), findsOneWidget);

      // Debajo del nombre del docente: comparten columna, y esa columna está a
      // la izquierda de la nota.
      final xBanda = tester.getTopLeft(find.text('Alto')).dx;
      final xDocente = tester.getTopLeft(find.text('Ariolfo Gómez')).dx;
      final xNota = tester.getTopLeft(find.text('82')).dx;

      expect(xBanda, xDocente);
      expect(xBanda, lessThan(xNota));
    });

    testWidgets('sin banda no se pinta nada donde iría', (tester) async {
      await montar(tester, asignatura: _matematicas(banda: null));

      expect(find.text('Alto'), findsNothing);
      expect(find.text('MATEMÁTICAS'), findsOneWidget);
    });
  });

  group('con competencias', () {
    testWidgets('la banda sube junto a la nota y sale UNA sola vez',
        (tester) async {
      // Cada línea llega con la banda montada delante, así que «Alto» aparecería
      // una vez como rótulo y tres veces disfrazada de prefijo.
      await montar(
        tester,
        asignatura: _matematicas(),
        lineas: [
          _delCatalogo('Fortaleza en interpretar gráficas de barras.'),
          _delCatalogo('Fortaleza en construir figuras planas.'),
        ],
      );

      expect(find.text('Alto'), findsOneWidget);

      final xBanda = tester.getTopLeft(find.text('Alto')).dx;
      final xDocente = tester.getTopLeft(find.text('Ariolfo Gómez')).dx;

      expect(xBanda, greaterThan(xDocente),
          reason: 'la banda tiene que estar en la columna de la nota');
    });

    testWidgets('salen TODAS, sin plegar y sin botón de abrir', (tester) async {
      // Decisión de Joseth, 19 sep 2026: como el papel. Lo que se pliega en un
      // teléfono no lo abre nadie.
      final textos = [
        'Fortaleza en interpretar gráficas de barras.',
        'Fortaleza en construir figuras planas.',
        'Fortaleza en resolver problemas con racionales.',
        'Fortaleza en comparar dos conjuntos de datos.',
      ];

      await montar(
        tester,
        asignatura: _matematicas(),
        lineas: textos.map(_delCatalogo).toList(),
      );

      for (final texto in textos) {
        expect(find.text(texto), findsOneWidget);
      }

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.textContaining('competencias'), findsNothing);
    });

    testWidgets('el texto se pinta TAL CUAL, sin añadirle nada',
        (tester) async {
      // El prefijo lo monta el servidor. Rearmarlo aquí sería un segundo sitio
      // donde vive la misma regla.
      const crudo = 'Dificultad en  entregar   a tiempo.';

      await montar(
        tester,
        asignatura: _matematicas(banda: 'Bajo'),
        lineas: [_delCatalogo(crudo)],
      );

      expect(find.text(crudo), findsOneWidget);
    });

    testWidgets('las escritas a mano van al final', (tester) async {
      await montar(
        tester,
        asignatura: _matematicas(),
        lineas: [
          _aMano('Le cuesta entregar a tiempo, aunque el trabajo está bien.'),
          _delCatalogo('Fortaleza en interpretar gráficas.'),
        ],
      );

      final yCatalogo =
          tester.getTopLeft(find.text('Fortaleza en interpretar gráficas.')).dy;
      final yMano = tester
          .getTopLeft(find.textContaining('Le cuesta entregar a tiempo'))
          .dy;

      expect(yCatalogo, lessThan(yMano),
          reason: 'la del catálogo va antes que la escrita sobre ese alumno');
    });

    testWidgets('el icono acompaña al texto y nunca lo sustituye',
        (tester) async {
      // D17: el nivel viaja en TEXTO siempre. Un boletín de Jardín con cinco
      // caritas y ni una palabra no se puede leer en voz alta.
      await montar(
        tester,
        asignatura: _matematicas(),
        lineas: [_delCatalogo('Fortaleza en contar hasta diez.', icono: '🙂')],
      );

      expect(find.text('Fortaleza en contar hasta diez.'), findsOneWidget);
      expect(find.text('🙂'), findsOneWidget);
    });

    testWidgets('una asignatura sin nota sigue enseñando sus competencias',
        (tester) async {
      // El nivel sale vacío cuando no hay definitiva, y eso no es motivo para
      // esconder el plan de área: el papel lo imprime igual.
      await montar(
        tester,
        asignatura: _matematicas(nota: null, banda: null),
        lineas: [_delCatalogo('Interpreta gráficas de barras.')],
      );

      expect(find.text('Interpreta gráficas de barras.'), findsOneWidget);
    });
  });
}
