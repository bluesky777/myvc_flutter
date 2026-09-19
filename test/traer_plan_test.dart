import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Screens/MisCompetenciasScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// Un servidor que apunta lo que se le manda.
///
/// Lo que se prueba aquí es sobre todo **el cuerpo del `PUT`**, y no por gusto
/// de mirar JSON: copiar de otro año mandando el `periodo_id` del destino
/// contesta **200 con `copiados: 0`** —los ids de periodos son por año y
/// disjuntos—, que es indistinguible de «el año pasado no tenía nada». El
/// backend lo midió y lo dejó escrito; aquí se fija para que no vuelva.
class ServidorFingido extends Server {
  ServidorFingido({
    this.asignaturas = const [],
    this.desempenos = const [],
    this.years = const [],
    this.respuestaDeCopiar = const {},
    this.codigoDeCopiar = 200,
  });

  final List<Map<String, dynamic>> asignaturas;
  List<Map<String, dynamic>> desempenos;
  final List<Map<String, dynamic>> years;
  final Map<String, dynamic> respuestaDeCopiar;
  final int codigoDeCopiar;

  final List<Map<String, dynamic>> copias = [];
  final List<String> pedidos = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);

    if (direccion.startsWith('/asignaturas/listasignaturas')) {
      return http.Response(jsonEncode(asignaturas), 200);
    }
    if (direccion.startsWith('/desempenos')) {
      return http.Response(
        jsonEncode({'year_id': 9, 'desempenos': desempenos, 'grupos': []}),
        200,
      );
    }
    if (direccion.startsWith('/escalas')) {
      return http.Response('[]', 200);
    }
    if (direccion.startsWith('/years')) {
      return http.Response(jsonEncode(years), 200);
    }
    return http.Response('[]', 200);
  }

  @override
  Future put(String direccion, params) async {
    if (direccion == '/desempenos/copiar') {
      copias.add(Map<String, dynamic>.from(params as Map));
      return http.Response(jsonEncode(respuestaDeCopiar), codigoDeCopiar);
    }
    return http.Response('{}', 200);
  }
}

Map<String, dynamic> asignatura({int id = 1, int grupoId = 101}) => {
      'asignatura_id': id,
      'grupo_id': grupoId,
      'profesor_id': 7,
      'materia': 'MATEMÁTICAS',
      'alias_materia': '',
      'nombre_grupo': 'Sexto A',
      'abrev_grupo': '6A',
      'materia_id': 13,
      'grado_id': 11,
      'unidades': [],
    };

Map<String, dynamic> desempeno({int id = 25, String definicion = 'Una'}) => {
      'id': id,
      'definicion': definicion,
      'tipo': null,
      'orden': 1,
      'materia_id': 13,
      'grado_id': 11,
      'periodo_id': 34,
    };

const dosAnios = [
  {
    'id': 9,
    'year': '2026',
    'actual': 1,
    'periodos': [
      {'id': 34, 'numero': 1},
      {'id': 35, 'numero': 2},
    ],
  },
  {
    'id': 8,
    'year': '2025',
    'actual': 0,
    'periodos': [
      {'id': 24, 'numero': 1},
      {'id': 25, 'numero': 2},
    ],
  },
];

Map<String, dynamic> copia({
  int revisados = 0,
  int copiados = 0,
  int duplicados = 0,
  int sinCatalogo = 0,
}) {
  return {
    'revisados': revisados,
    'copiados': copiados,
    'saltados_por_duplicado': duplicados,
    'saltadas_sin_catalogo': sinCatalogo,
  };
}

void entrarComoDocente({bool periodoAbierto = true}) {
  AuthService.limpiar();
  AuthService.user = UserAutenticado(
    username: 'ariolfo',
    tipo: 'Profesor',
    personaId: 7,
  );

  ContextoAcademico.instancia.tomarDelLogin({
    'year_id': 9,
    // Con el año puesto, la barra de arriba rotula «2026 · Periodo 1». Sin él
    // diría «Periodo 1» a secas y chocaría con la lista de la hoja, que es un
    // choque de la prueba y no de la pantalla.
    'year': '2026',
    'periodo_id': 34,
    'numero_periodo': 1,
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

  // La tarjeta se abre para llegar a los botones.
  await tester.tap(find.textContaining('MATEMÁTICAS'));
  await tester.pumpAndSettle();
}

Future<void> traerDe(WidgetTester tester, String cual) async {
  await tester.tap(find.text('Traer de…'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(cual));
  await tester.pumpAndSettle();
}

/// Los avisos se cuentan con [findsWidgets] y no con `findsOneWidget`.
///
/// **Salen dos, y no es de esta pantalla**: `ScaffoldMessenger` enseña el
/// `SnackBar` en **cada** `Scaffold` registrado, y `PantallaConMenu` añade el
/// suyo alrededor del de la pantalla. Son dos idénticos, uno encima de otro, y
/// le pasa a todas las pantallas con menú. Medido con una sonda el 19 sep 2026:
/// la pantalla se construye una sola vez y los `Scaffold` son dos.
void main() {
  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
    entrarComoDocente();
  });

  testWidgets(
      'de otro periodo: viaja tipo grado y su periodo, y el destino '
      'es el de la sesión', (tester) async {
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(revisados: 2, copiados: 2),
    );

    await abrir(tester, servidor);
    await traerDe(tester, 'Periodo 2');

    expect(servidor.copias, hasLength(1));
    expect(servidor.copias.last, {
      'destino': {'materia_id': 13, 'grado_id': 11, 'periodo_id': 34},
      'origen': {'tipo': 'grado', 'periodo_id': 35},
    });
  });

  testWidgets('de otro año: viaja tipo year y NO viaja el periodo',
      (tester) async {
    // Mandarlo sería el fallo que el backend midió: los ids de periodos son
    // por año, así que el del destino no casa ninguna fila del año de origen
    // y la respuesta es 200 con copiados 0, que parece «no había nada».
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(revisados: 3, copiados: 3),
    );

    await abrir(tester, servidor);
    await traerDe(tester, '2025');

    expect(servidor.copias.last, {
      'destino': {'materia_id': 13, 'grado_id': 11, 'periodo_id': 34},
      'origen': {'tipo': 'year', 'year_id': 8},
    });
    expect(
      (servidor.copias.last['origen'] as Map).containsKey('periodo_id'),
      isFalse,
      reason: 'el periodo del destino es de otro año y daría 0 en silencio',
    );
  });

  testWidgets('el periodo en el que se está no se ofrece como origen',
      (tester) async {
    // Copiar un grupo sobre sí mismo es un 422, y con razón: daría «revisados
    // N, copiados 0», un 200 que parece que funcionó.
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
    );

    await abrir(tester, servidor);
    await tester.tap(find.text('Traer de…'));
    await tester.pumpAndSettle();

    expect(find.text('Periodo 2'), findsOneWidget);
    expect(find.text('Periodo 1'), findsNothing);
    // Y el año en el que se está tampoco.
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
  });

  testWidgets('«no había nada» y «ya las tenías» no se dicen igual',
      (tester) async {
    final vacio = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(sinCatalogo: 1),
    );

    await abrir(tester, vacio);
    await traerDe(tester, 'Periodo 2');

    expect(find.text('En Periodo 2 no hay nada escrito.'), findsWidgets);
  });

  testWidgets('ya estaban todas: lo dice, y no dice que no se copió',
      (tester) async {
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(revisados: 4, duplicados: 4),
    );

    await abrir(tester, servidor);
    await traerDe(tester, 'Periodo 2');

    expect(find.text('Ya tenías las 4. No se añadió ninguna.'), findsWidgets);
  });

  testWidgets('se trajeron unas y otras ya estaban: salen las dos cifras',
      (tester) async {
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(revisados: 5, copiados: 3, duplicados: 2),
    );

    await abrir(tester, servidor);
    await traerDe(tester, 'Periodo 2');

    expect(
      find.text('Se trajeron 3 de Periodo 2 · 2 ya estaban.'),
      findsWidgets,
    );
  });

  testWidgets('sólo se relee el catálogo si de verdad entró alguna',
      (tester) async {
    // La respuesta trae contadores y no filas, así que hay que releer — pero
    // un «ya las tenías todas» no cambió nada que repintar.
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(revisados: 4, duplicados: 4),
    );

    await abrir(tester, servidor);
    final antes = servidor.pedidos.where((p) => p.startsWith('/desempenos'));
    await traerDe(tester, 'Periodo 2');
    final despues = servidor.pedidos.where((p) => p.startsWith('/desempenos'));

    expect(despues.length, antes.length);
  });

  testWidgets('si entró alguna, se relee', (tester) async {
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      respuestaDeCopiar: copia(revisados: 2, copiados: 2),
    );

    await abrir(tester, servidor);
    final antes =
        servidor.pedidos.where((p) => p.startsWith('/desempenos')).length;
    await traerDe(tester, 'Periodo 2');
    final despues =
        servidor.pedidos.where((p) => p.startsWith('/desempenos')).length;

    expect(despues, antes + 1);
  });

  testWidgets('un 422 se enseña con el texto del servidor', (tester) async {
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      years: dosAnios,
      codigoDeCopiar: 422,
      respuestaDeCopiar: const {
        'message': 'El año de origen no tiene un periodo número 1.',
      },
    );

    await abrir(tester, servidor);
    await traerDe(tester, '2025');

    expect(
      find.textContaining('El año de origen no tiene un periodo número 1.'),
      findsWidgets,
    );
  });

  testWidgets('con el periodo cerrado no hay botón de traer', (tester) async {
    entrarComoDocente(periodoAbierto: false);

    await abrir(
      tester,
      ServidorFingido(asignaturas: [asignatura()], years: dosAnios),
    );

    expect(find.text('Traer de…'), findsNothing);
    expect(find.text('Añadir'), findsNothing);
  });

  testWidgets('sin años que ofrecer, la hoja lo dice en vez de salir vacía',
      (tester) async {
    await abrir(
      tester,
      ServidorFingido(asignaturas: [asignatura()], years: const []),
    );

    await tester.tap(find.text('Traer de…'));
    await tester.pumpAndSettle();

    expect(
      find.text('No hay otro periodo ni otro año de donde traer.'),
      findsOneWidget,
    );
  });

  testWidgets('los años se piden al abrir la hoja, no al abrir la pantalla',
      (tester) async {
    // La mayoría de las visitas no copian nada, y GET /years es una petición
    // que no hace falta pagar por si acaso.
    final servidor = ServidorFingido(
      asignaturas: [asignatura()],
      desempenos: [desempeno()],
      years: dosAnios,
    );

    await abrir(tester, servidor);
    expect(servidor.pedidos.any((p) => p.startsWith('/years')), isFalse);

    await tester.tap(find.text('Traer de…'));
    await tester.pumpAndSettle();

    expect(servidor.pedidos.any((p) => p.startsWith('/years')), isTrue);
  });
}
