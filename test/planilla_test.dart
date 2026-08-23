import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Screens/PlanillaScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

void main() {
  final subunidad = SubunidadModel(
    id: 5,
    unidadId: 2,
    definicion: 'Quiz de fraccionarios',
    porcentaje: 20,
  );

  final unidad = UnidadModel(
    id: 2,
    definicion: 'Números racionales',
    porcentaje: 50,
    subunidades: [subunidad],
  );

  LibroDeNotas libroCon(List<double?> notas) {
    return LibroDeNotas(
      asignatura: AsignaturaModel.fromJson({
        'asignatura_id': 12,
        'grupo_id': 3,
        'materia': 'Matemáticas',
        'nombre_grupo': 'Tercero B',
        'abrev_grupo': '3B',
      }),
      unidades: [unidad],
      alumnos: [
        for (var i = 0; i < notas.length; i++)
          AlumnoDelLibro(
            alumnoId: 100 + i,
            nombres: 'Alumno',
            apellidos: 'Apellido$i',
            notas: {
              5: NotaDelLibro(id: 900 + i, subunidadId: 5, nota: notas[i]),
            },
          ),
      ],
    );
  }

  /// Un docente con el periodo abierto, que es el caso normal.
  void entraUnDocente({
    bool puedeEditar = true,
    int notaMinima = 60,
  }) {
    AuthService.limpiar();
    AuthService.user.tipo = 'Profesor';

    ContextoAcademico.instancia.tomarDelLogin({
      'year_id': 6,
      'periodo_id': 21,
      'numero_periodo': 3,
      'nota_minima_aceptada': notaMinima,
      'profes_pueden_editar_notas': puedeEditar ? 1 : 0,
      'profes_pueden_nivelar': puedeEditar ? 1 : 0,
    });
  }

  Future<void> montar(WidgetTester tester, LibroDeNotas libro) async {
    await tester.pumpWidget(MaterialApp(
      home: PlanillaScreen(
        libro: libro,
        unidad: unidad,
        subunidad: subunidad,
      ),
    ));
    await tester.pump();
  }

  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
  });

  testWidgets('lista a los alumnos con la nota que ya tienen', (tester) async {
    entraUnDocente();
    await montar(tester, libroCon([85, null, 40]));

    expect(find.text('Apellido0 Alumno'), findsOneWidget);
    expect(find.text('Apellido2 Alumno'), findsOneWidget);
    // Las notas llegan como decimales y se escriben sin el .0, que solo invita
    // a borrarlo antes de teclear.
    expect(find.widgetWithText(TextField, '85'), findsOneWidget);
    expect(find.widgetWithText(TextField, '40'), findsOneWidget);
  });

  testWidgets('al abrir no hay nada pendiente', (tester) async {
    entraUnDocente();
    await montar(tester, libroCon([85, 40]));

    expect(find.text('Todo guardado'), findsOneWidget);
  });

  testWidgets('escribir una nota la cuenta como pendiente', (tester) async {
    entraUnDocente();
    await montar(tester, libroCon([85, 40]));

    await tester.enterText(find.widgetWithText(TextField, '85'), '90');
    await tester.pump();

    expect(find.text('1 sin guardar'), findsOneWidget);
  });

  testWidgets('escribir la misma nota no cuenta como cambio', (tester) async {
    // Es la diferencia con el front web, que reescribe la columna entera aunque
    // no haya cambiado nada: ahí son treinta peticiones y aquí, cero.
    entraUnDocente();
    await montar(tester, libroCon([85, 40]));

    await tester.enterText(find.widgetWithText(TextField, '85'), '85');
    await tester.pump();

    expect(find.text('Todo guardado'), findsOneWidget);
  });

  testWidgets('«A todos» rellena la columna de una vez', (tester) async {
    entraUnDocente();
    await montar(tester, libroCon([85, null, 40]));

    // El primero de la pantalla es el de «A todos», encima de la lista.
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.text('Aplicar'));
    await tester.pump();

    expect(find.widgetWithText(TextField, '100'), findsNWidgets(4));
    // Las tres del grupo cambiaron: la de 85, la vacía y la de 40.
    expect(find.text('3 sin guardar'), findsOneWidget);
  });

  testWidgets('con el periodo cerrado se avisa y no se edita', (tester) async {
    entraUnDocente(puedeEditar: false);
    await montar(tester, libroCon([85, 40]));

    // Los campos se dejan en gris, no se esconden: uno que desaparece parece
    // un fallo de la app.
    expect(find.widgetWithText(TextField, '85'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, '85')).enabled,
      isFalse,
    );

    // Ni la barra de guardar ni la nota rápida tienen sentido si no se edita.
    expect(find.text('Aplicar'), findsNothing);
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets('una casilla sin fila en notas no se deja tocar', (tester) async {
    // No debería pasar —notas/detailed las crea al abrir el libro— pero si
    // pasa, más vale un campo apagado que uno que acepta lo que se pierde.
    entraUnDocente();

    await montar(
      tester,
      LibroDeNotas(
        asignatura: AsignaturaModel.fromJson({'asignatura_id': 12}),
        unidades: [unidad],
        alumnos: [
          const AlumnoDelLibro(
            alumnoId: 100,
            nombres: 'Alumno',
            apellidos: 'Sinfila',
            notas: {5: NotaDelLibro(id: 0, subunidadId: 5)},
          ),
        ],
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField).last).enabled,
      isFalse,
    );
  });
}
