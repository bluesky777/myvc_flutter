import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Models/OrdinalModel.dart';
import 'package:myvc_flutter/Widgets/SelectorGrupo.dart';
import 'package:myvc_flutter/Widgets/SelectorOrdinales.dart';

void main() {
  group('el selector de grupo', () {
    final grupos = [
      GrupoModel(
          id: 1,
          nombre: '6-A',
          abrev: '6A',
          orden: 1,
          nombreGrado: 'Sexto',
          nombresTitular: 'Ariolfo',
          apellidosTitular: 'Gómez'),
      GrupoModel(id: 2, nombre: '10-B', abrev: '10B', orden: 2, nombreGrado: 'Décimo'),
    ];

    testWidgets('avisa del grupo elegido', (tester) async {
      GrupoModel? elegido;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoGrupo(
            grupos: grupos,
            elegido: grupos.first,
            alElegir: (grupo) => elegido = grupo,
          ),
        ),
      ));

      // El campo enseña el grupo con su grado detrás.
      expect(find.text('6-A · Sexto'), findsOneWidget);

      await tester.tap(find.text('6-A · Sexto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10-B · Décimo'));
      await tester.pumpAndSettle();

      expect(elegido?.id, 2);
    });

    testWidgets('volver a tocar el que ya estaba no recarga nada',
        (tester) async {
      var avisos = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoGrupo(
            grupos: grupos,
            elegido: grupos.first,
            alElegir: (_) => avisos++,
          ),
        ),
      ));

      await tester.tap(find.text('6-A · Sexto'));
      await tester.pumpAndSettle();

      // El de la hoja, no el del campo.
      await tester.tap(find.text('6-A · Sexto').last);
      await tester.pumpAndSettle();

      expect(avisos, 0,
          reason: 'traer cuarenta alumnos para quedarse igual es una espera '
              'que no lleva a ninguna parte');
    });

    testWidgets('sin grupos no se puede abrir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoGrupo(grupos: const [], elegido: null, alElegir: (_) {}),
        ),
      ));

      expect(find.text('No hay grupos que mirar'), findsOneWidget);

      await tester.tap(find.text('No hay grupos que mirar'));
      await tester.pumpAndSettle();

      expect(find.text('Grupos'), findsNothing);
    });
  });

  group('el selector de ordinales', () {
    final catalogo = [
      OrdinalModel(
          id: 41,
          tipo: 'Tipo I',
          ordinal: '3',
          descripcion: 'No portar el uniforme completo'),
      OrdinalModel(
          id: 44,
          tipo: 'Tipo II',
          ordinal: '1',
          descripcion: 'Agresión física a un compañero'),
      OrdinalModel(
          id: 47, tipo: 'Tipo III', ordinal: '2', descripcion: 'Porte de armas'),
    ];

    Future<List<int>?> montar(
      WidgetTester tester, {
      List<int> elegidos = const [],
    }) async {
      List<int>? avisado;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoOrdinales(
            catalogo: catalogo,
            elegidos: elegidos,
            alCambiar: (nuevos) => avisado = nuevos,
          ),
        ),
      ));

      return avisado;
    }

    testWidgets('busca por texto y devuelve lo marcado', (tester) async {
      List<int>? avisado;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoOrdinales(
            catalogo: catalogo,
            elegidos: const [],
            alCambiar: (nuevos) => avisado = nuevos,
          ),
        ),
      ));

      await tester.tap(find.text('Elige los ordinales'));
      await tester.pumpAndSettle();

      // Sin acentos: quien busca «agresión» escribe «agresion».
      await tester.enterText(find.byType(TextField), 'agresion');
      await tester.pumpAndSettle();

      expect(find.text('Tipo II - 1'), findsOneWidget);
      expect(find.text('Tipo I - 3'), findsNothing);

      await tester.tap(find.text('Agresión física a un compañero'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(avisado, [44]);
    });

    testWidgets('cerrar sin aceptar no toca lo que ya estaba', (tester) async {
      // Es la diferencia con el front web, donde marcar un ordinal lo guarda
      // en ese instante aunque después se cancele el formulario.
      List<int>? avisado;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoOrdinales(
            catalogo: catalogo,
            elegidos: const [41],
            alCambiar: (nuevos) => avisado = nuevos,
          ),
        ),
      ));

      await tester.tap(find.text('Tipo I - 3'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Porte de armas'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(avisado, isNull);
    });

    testWidgets('los elegidos salen como chips con su número', (tester) async {
      await montar(tester, elegidos: const [41, 47]);

      // El número y no la descripción: cuatro descripciones enteras taparían
      // el resto del formulario.
      expect(find.text('Tipo I - 3'), findsOneWidget);
      expect(find.text('Tipo III - 2'), findsOneWidget);
      expect(find.text('Porte de armas'), findsNothing);
    });

    testWidgets('un catálogo vacío lo dice y no abre nada', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CampoOrdinales(
            catalogo: const [],
            elegidos: const [],
            alCambiar: (_) {},
          ),
        ),
      ));

      expect(find.text('No hay ordinales que elegir'), findsOneWidget);
      expect(find.text('Este año no tiene ordinales cargados'), findsOneWidget);
    });
  });
}
