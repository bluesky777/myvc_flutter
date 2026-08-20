import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/TituloContexto.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

void main() {
  final contexto = ContextoAcademico.instancia;

  setUp(contexto.limpiar);

  Widget conBarra() => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TituloContexto()),
          body: const SizedBox(),
        ),
      );

  testWidgets('la barra enseña el año y el periodo del usuario',
      (WidgetTester tester) async {
    contexto.tomarDelLogin({
      'year_id': 6,
      'year': '2026',
      'periodo_id': 21,
      'numero_periodo': 3,
    });

    await tester.pumpWidget(conBarra());

    expect(find.text('2026 · Periodo 3'), findsOneWidget);
    // La flechita es lo que dice que se puede tocar.
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('se actualiza sola cuando cambia el contexto',
      (WidgetTester tester) async {
    contexto.tomarDelLogin({
      'year_id': 6,
      'year': '2026',
      'periodo_id': 21,
      'numero_periodo': 3,
    });
    await tester.pumpWidget(conBarra());

    contexto.tomarDelLogin({
      'year_id': 5,
      'year': '2025',
      'periodo_id': 14,
      'numero_periodo': 1,
    });
    await tester.pump();

    expect(find.text('2025 · Periodo 1'), findsOneWidget);
    expect(find.text('2026 · Periodo 3'), findsNothing);
  });

  group('con el nombre de la pantalla', () {
    setUp(() {
      contexto.tomarDelLogin({
        'year_id': 6,
        'year': '2026',
        'periodo_id': 21,
        'numero_periodo': 3,
      });
    });

    testWidgets('salen los dos: dónde estoy y con qué periodo',
        (WidgetTester tester) async {
      // Sin el nombre, el inicio, las unidades y la disciplina llevaban
      // exactamente el mismo título y no había forma de saber en cuál se
      // estaba.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TituloContexto(titulo: 'Disciplina')),
          body: const SizedBox(),
        ),
      ));

      expect(find.text('Disciplina'), findsOneWidget);
      expect(find.text('2026 · Periodo 3'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('el periodo se sigue pudiendo cambiar desde ahí',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TituloContexto(titulo: 'Unidades')),
          body: const SizedBox(),
        ),
      ));

      await tester.tap(find.text('Unidades'));
      await tester.pump();

      // Se comprueba que la hoja se abre y no qué trae: lo que trae sale de
      // GET /years, y en las pruebas no hay servidor que conteste.
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  group('el título de dos líneas', () {
    testWidgets('sin subtítulo se queda en una', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TituloPantalla(titulo: 'Asistencias')),
          body: const SizedBox(),
        ),
      ));

      expect(find.text('Asistencias'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('un subtítulo en blanco cuenta como no tenerlo',
        (WidgetTester tester) async {
      // Es lo que pasa cuando el alumno todavía no ha llegado del servidor.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: TituloPantalla(titulo: 'Mis notas', subtitulo: '   '),
          ),
          body: const SizedBox(),
        ),
      ));

      expect(find.text('Mis notas'), findsOneWidget);
      expect(find.text('   '), findsNothing);
    });
  });
}
