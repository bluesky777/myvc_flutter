import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Screens/MisCompetenciasScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// Un servidor que contesta lo que se le dé, sin salir a la red.
///
/// Reparte por la dirección porque esta pantalla pide **tres** cosas al abrir
/// —las asignaturas, el catálogo del periodo y las escalas—, y lo que se prueba
/// aquí depende de las tres a la vez.
class ServidorFingido extends Server {
  ServidorFingido({
    this.asignaturas = const [],
    this.desempenos = const [],
    this.escalas = const [],
  });

  final List<Map<String, dynamic>> asignaturas;
  final List<Map<String, dynamic>> desempenos;
  final List<Map<String, dynamic>> escalas;

  @override
  Future get(String direccion) async {
    if (direccion.startsWith('/asignaturas/listasignaturas')) {
      return http.Response(jsonEncode(asignaturas), 200);
    }

    if (direccion.startsWith('/desempenos')) {
      // **Un sobre, no una lista**, que es la forma que devuelve
      // `DesempenosController::getPlantilla`.
      return http.Response(
        jsonEncode({'year_id': 9, 'desempenos': desempenos, 'grupos': []}),
        200,
      );
    }

    if (direccion.startsWith('/escalas')) {
      return http.Response(jsonEncode(escalas), 200);
    }

    return http.Response('[]', 200);
  }
}

/// Una asignatura del docente 7, con los dos ids que el backend aún no manda.
Map<String, dynamic> asignatura({
  required int id,
  required int grupoId,
  required String abrevGrupo,
  int? materiaId = 13,
  int? gradoId = 11,
  String materia = 'MATEMÁTICAS',
}) {
  return {
    'asignatura_id': id,
    'grupo_id': grupoId,
    'profesor_id': 7,
    'materia': materia,
    'alias_materia': '',
    'nombre_grupo': 'Sexto $abrevGrupo',
    'abrev_grupo': abrevGrupo,
    if (materiaId != null) 'materia_id': materiaId,
    if (gradoId != null) 'grado_id': gradoId,
    'unidades': [],
  };
}

Map<String, dynamic> desempeno({
  required int id,
  required String definicion,
  int? gradoId = 11,
  int materiaId = 13,
  String? tipo,
  int orden = 1,
}) {
  return {
    'id': id,
    'definicion': definicion,
    'tipo': tipo,
    'orden': orden,
    'materia_id': materiaId,
    'grado_id': gradoId,
    'periodo_id': 34,
  };
}

/// Entra como el docente 7, con el periodo abierto salvo que se diga otra cosa.
void entrarComoDocente({bool periodoAbierto = true}) {
  AuthService.limpiar();
  AuthService.user = UserAutenticado(
    username: 'ariolfo',
    tipo: 'Profesor',
    personaId: 7,
  );

  ContextoAcademico.instancia.tomarDelLogin({
    'year_id': 9,
    'periodo_id': 34,
    'modelo_evaluacion': 'competencias',
    'profes_pueden_editar_notas': periodoAbierto ? 1 : 0,
  });
}

Future<void> abrir(WidgetTester tester, ServidorFingido servidor) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(home: MisCompetenciasScreen(servidor: servidor)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
  });

  testWidgets('dos grupos del mismo grado son UNA clase, y lo dice',
      (tester) async {
    // **Es la decisión que ordena la pantalla.** El plan de área se escribe por
    // (materia, grado): 6.ºA y 6.ºB comparten la misma fila. Si esto saliera
    // como dos tarjetas, el docente editaría una y vería cambiar la otra.
    entrarComoDocente();

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [
          asignatura(id: 1, grupoId: 101, abrevGrupo: '6A'),
          asignatura(id: 2, grupoId: 102, abrevGrupo: '6B'),
        ],
        desempenos: [
          desempeno(id: 25, definicion: 'Interpreta gráficas de barras'),
        ],
      ),
    );

    expect(find.textContaining('MATEMÁTICAS'), findsOneWidget);
    expect(find.textContaining('vale para 6A y 6B'), findsOneWidget);
  });

  testWidgets('sin el nombre del grado, el grupo se nombra aunque sea uno',
      (tester) async {
    // `Profesor::asignaturas` no trae el nombre del grado, así que el título se
    // queda en «MATEMÁTICAS» a secas y dos clases de la misma materia en grados
    // distintos serían dos tarjetas idénticas. El grupo es lo que las separa.
    entrarComoDocente();

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [
          asignatura(id: 1, grupoId: 101, abrevGrupo: '6A'),
          asignatura(id: 2, grupoId: 201, abrevGrupo: '7A', gradoId: 12),
        ],
      ),
    );

    expect(find.textContaining('MATEMÁTICAS'), findsNWidgets(2));
    expect(find.textContaining('vale para 6A'), findsOneWidget);
    expect(find.textContaining('vale para 7A'), findsOneWidget);
  });

  testWidgets('las de «todos los grados» van en su bloque y sin botones',
      (tester) async {
    // Una fila con `grado_id` nulo alcanza a grados que este docente no da, así
    // que es del colegio y el servidor contesta 403 si la toca. El candado es
    // una cabecera y no un icono por fila: así se explica una vez y ninguna
    // fila de ese bloque invita al pulgar.
    entrarComoDocente();

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [asignatura(id: 1, grupoId: 101, abrevGrupo: '6A')],
        desempenos: [
          desempeno(id: 71, definicion: 'Del colegio', gradoId: null),
          desempeno(id: 25, definicion: 'De sexto'),
        ],
      ),
    );

    await tester.tap(find.textContaining('MATEMÁTICAS'));
    await tester.pumpAndSettle();

    expect(find.text('Del colegio · para todos los grados'), findsOneWidget);
    expect(find.text('Del colegio'), findsOneWidget);
    expect(find.text('De sexto'), findsOneWidget);

    // Una sola pareja de botones: la de la fila del grado. La del colegio no
    // lleva ninguno.
    expect(find.byTooltip('Corregir'), findsOneWidget);
    expect(find.byTooltip('Quitar'), findsOneWidget);
  });

  testWidgets('con el periodo cerrado no hay botones y el candado dice por qué',
      (tester) async {
    // Pintar «Añadir» y dejar que el 403 lo explique es lo que hace que un
    // candado parezca una avería.
    entrarComoDocente(periodoAbierto: false);

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [asignatura(id: 1, grupoId: 101, abrevGrupo: '6A')],
        desempenos: [desempeno(id: 25, definicion: 'De sexto')],
      ),
    );

    await tester.tap(find.textContaining('MATEMÁTICAS'));
    await tester.pumpAndSettle();

    expect(find.text('Añadir'), findsNothing);
    expect(find.byTooltip('Corregir'), findsNothing);
    expect(find.textContaining('periodo'), findsWidgets);
  });

  testWidgets('sin los dos ids, la pantalla lo DICE en vez de salir vacía',
      (tester) async {
    // **Es el caso de hoy en los dieciséis colegios**: `listasignaturas` no
    // manda `materia_id` ni `grado_id` todavía. Una lista vacía y «esto aún no
    // está en tu colegio» se leen igual y no son lo mismo.
    entrarComoDocente();

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [
          asignatura(
              id: 1,
              grupoId: 101,
              abrevGrupo: '6A',
              materiaId: null,
              gradoId: null),
          asignatura(
              id: 2,
              grupoId: 102,
              abrevGrupo: '6B',
              materiaId: null,
              gradoId: null),
        ],
      ),
    );

    expect(find.text('Esto todavía no está en tu colegio.'), findsOneWidget);
    expect(find.textContaining('Tus 2 asignaturas'), findsOneWidget);
  });

  testWidgets('si sólo unas se resuelven, se enseñan y se dice cuántas faltan',
      (tester) async {
    entrarComoDocente();

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [
          asignatura(id: 1, grupoId: 101, abrevGrupo: '6A'),
          asignatura(
              id: 2,
              grupoId: 102,
              abrevGrupo: '7A',
              materiaId: null,
              gradoId: null),
        ],
      ),
    );

    expect(find.textContaining('MATEMÁTICAS'), findsOneWidget);
    expect(
      find.textContaining('1 de tus asignaturas no se pudieron identificar'),
      findsOneWidget,
    );
  });

  testWidgets('una clase sin competencias lo dice, y no deja el hueco',
      (tester) async {
    entrarComoDocente();

    await abrir(
      tester,
      ServidorFingido(
        asignaturas: [asignatura(id: 1, grupoId: 101, abrevGrupo: '6A')],
      ),
    );

    expect(find.textContaining('sin escribir todavía'), findsOneWidget);

    await tester.tap(find.textContaining('MATEMÁTICAS'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nadie ha escrito competencias'),
      findsOneWidget,
    );
  });
}
