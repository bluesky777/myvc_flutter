import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/SelectorDocente.dart';

void main() {
  final docentes = [
    DocenteModel(profesorId: 4, nombre: 'Ariolfo Gómez Pico'),
    DocenteModel(profesorId: 7, nombre: 'Marta Restrepo'),
  ];

  Future<void> montar(
    WidgetTester tester, {
    DocenteModel? elegido,
    required void Function(DocenteModel) alElegir,
    List<DocenteModel>? lista,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CampoDocente(
          docentes: lista ?? docentes,
          elegido: elegido,
          alElegir: alElegir,
        ),
      ),
    ));
  }

  testWidgets('sin nadie elegido invita a elegir', (tester) async {
    await montar(tester, alElegir: (_) {});

    expect(find.text('Elige el docente'), findsOneWidget);
    // Sin elegido no hay foto que enseñar.
    expect(find.byType(AvatarPersona), findsNothing);
  });

  testWidgets('el elegido sale con su foto en el campo', (tester) async {
    await montar(tester, elegido: docentes.first, alElegir: (_) {});

    expect(find.text('Ariolfo Gómez Pico'), findsOneWidget);
    expect(find.byType(AvatarPersona), findsOneWidget);
  });

  testWidgets('al tocarlo abre la hoja con todos y sus fotos', (tester) async {
    await montar(tester, alElegir: (_) {});

    await tester.tap(find.text('Elige el docente'));
    await tester.pumpAndSettle();

    expect(find.text('Docentes'), findsOneWidget);
    expect(find.text('Marta Restrepo'), findsOneWidget);
    // Una foto por docente de la lista.
    expect(find.byType(AvatarPersona), findsNWidgets(2));
  });

  testWidgets('elegir uno lo devuelve y cierra la hoja', (tester) async {
    DocenteModel? avisado;

    await montar(tester, alElegir: (d) => avisado = d);

    await tester.tap(find.text('Elige el docente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marta Restrepo'));
    await tester.pumpAndSettle();

    expect(avisado?.profesorId, 7);
    expect(find.text('Docentes'), findsNothing);
  });

  testWidgets('volver a tocar el que ya estaba no avisa de nada',
      (tester) async {
    // Recargar para quedarse igual es una espera que no lleva a ninguna parte.
    var veces = 0;

    await montar(
      tester,
      elegido: docentes.first,
      alElegir: (_) => veces++,
    );

    await tester.tap(find.text('Ariolfo Gómez Pico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ariolfo Gómez Pico').last);
    await tester.pumpAndSettle();

    expect(veces, 0);
  });

  testWidgets('sin docentes el campo no se puede abrir', (tester) async {
    await montar(tester, lista: [], alElegir: (_) {});

    await tester.tap(find.text('Elige el docente'));
    await tester.pumpAndSettle();

    expect(find.text('Docentes'), findsNothing);
  });
}
