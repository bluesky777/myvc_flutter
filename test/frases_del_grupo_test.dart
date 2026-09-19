import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Screens/FrasesDelGrupoScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// Un servidor que contesta el sobre que se le dé y **apunta lo que recibe**.
///
/// Lo que más se prueba aquí no es lo que se pinta sino **lo que viaja**: el
/// contrato del `PUT` es declarativo por alumno, así que un alumno de más en el
/// cuerpo es un alumno al que se le pudieron borrar frases sin que nada
/// fallara. Por eso [cuerpos] guarda cada petición tal cual salió.
class ServidorFingido extends Server {
  ServidorFingido({
    required this.sobre,
    this.porPeriodo = const {},
    this.catalogo = const [],
    this.years = const [],
    this.respuestaDelPut,
    this.codigoDelPut = 200,
  });

  /// Lo que contesta el `GET` sin `periodo_id`.
  final Map<String, dynamic> sobre;

  /// Y lo que contesta cuando se le pide uno concreto.
  final Map<int, Map<String, dynamic>> porPeriodo;

  final List<Map<String, dynamic>> catalogo;
  final List<Map<String, dynamic>> years;

  /// Lo que devuelve el `PUT`. Null es «el mismo sobre, sin población».
  final Map<String, dynamic>? respuestaDelPut;
  final int codigoDelPut;

  /// Cada cuerpo que se le mandó, en orden.
  final List<Map<String, dynamic>> cuerpos = [];

  /// Cada dirección que se le pidió, en orden.
  final List<String> pedidos = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);

    // Antes que `/frases` a secas, que es prefijo de ésta.
    if (direccion.startsWith('/frases_asignatura/grupo/')) {
      final pedido = Uri.parse(direccion).queryParameters['periodo_id'];
      final periodo = int.tryParse(pedido ?? '');

      return http.Response(
        jsonEncode(periodo == null ? sobre : (porPeriodo[periodo] ?? sobre)),
        200,
      );
    }

    if (direccion.startsWith('/frases')) {
      return http.Response(jsonEncode(catalogo), 200);
    }

    if (direccion.startsWith('/years')) {
      return http.Response(jsonEncode(years), 200);
    }

    return http.Response('[]', 200);
  }

  @override
  Future put(String direccion, params) async {
    cuerpos.add(Map<String, dynamic>.from(params as Map));

    return http.Response(
      jsonEncode(respuestaDelPut ?? {...sobre, 'poblacion': const {}}),
      codigoDelPut,
    );
  }
}

Map<String, dynamic> alumno(
  int id,
  String apellidos,
  String nombres, {
  List<Map<String, dynamic>> frases = const [],
}) {
  return {
    'alumno_id': id,
    'matricula_id': 900 + id,
    'nombres': nombres,
    'apellidos': apellidos,
    'frases': frases,
  };
}

Map<String, dynamic> fraseAMano(int id, String texto) => {
      'id': id,
      'frase': texto,
      'frase_escrita': texto,
      'frase_id': null,
      'tipo_frase': null,
    };

Map<String, dynamic> fraseDelCatalogo(int id, int fraseId, String texto) => {
      'id': id,
      'frase': texto,
      // Null a propósito: una del catálogo no guarda texto en su fila.
      'frase_escrita': null,
      'frase_id': fraseId,
      'tipo_frase': 'Fortaleza',
    };

Map<String, dynamic> sobre({
  int periodoId = 34,
  bool periodoAbierto = true,
  bool puedeEscribir = true,
  List<Map<String, dynamic>> alumnos = const [],
  int? deFuera,
}) {
  return {
    'asignatura_id': 1,
    'grupo_id': 7,
    'year_id': 9,
    'periodo_id': periodoId,
    'periodo_abierto': periodoAbierto,
    'puede_escribir': puedeEscribir,
    'alumnos': alumnos,
    'poblacion': {
      'alumnos': alumnos.length,
      'frases': 0,
      'alumnos_con_frases': 0,
      'alumnos_sin_frases': alumnos.length,
      if (deFuera != null) 'frases_fuera_del_grupo': deFuera,
    },
  };
}

const losCuatroPeriodos = [
  {
    'id': 9,
    'year': '2026',
    'actual': 1,
    'periodos': [
      {'id': 34, 'numero': 1},
      {'id': 35, 'numero': 2},
    ],
  },
];

void entrarComoDocente() {
  AuthService.limpiar();
  AuthService.user = UserAutenticado(
    username: 'ariolfo',
    tipo: 'Profesor',
    personaId: 7,
  );

  ContextoAcademico.instancia.tomarDelLogin({
    'year_id': 9,
    'periodo_id': 34,
    'numero_periodo': 1,
    'profes_pueden_editar_notas': 1,
  });
}

Future<void> abrir(WidgetTester tester, ServidorFingido servidor) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(MaterialApp(
    home: FrasesDelGrupoScreen(
      asignaturaId: 1,
      materia: 'Matemáticas',
      nombreGrupo: 'Décimo B',
      servidor: servidor,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Los alumnos que viajaron en el último cuerpo.
List<int> alumnosDe(ServidorFingido servidor) {
  final ultimo = servidor.cuerpos.last;
  return (ultimo['alumnos'] as List)
      .map((a) => (a as Map)['alumno_id'] as int)
      .toList();
}

/// Las frases que viajaron para un alumno.
List<Map> frasesDe(ServidorFingido servidor, int alumnoId) {
  final ultimo = servidor.cuerpos.last;
  final suyo = (ultimo['alumnos'] as List)
      .cast<Map>()
      .firstWhere((a) => a['alumno_id'] == alumnoId);

  return (suyo['frases'] as List).cast<Map>();
}

void main() {
  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
    entrarComoDocente();
  });

  testWidgets('el grupo entero se pinta, y los que no tienen frases también',
      (tester) async {
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(alumnos: [
          alumno(101, 'Acosta Pérez', 'Ana',
              frases: [fraseAMano(4001, 'Avanzó mucho en lectura.')]),
          alumno(102, 'Bolaño Díaz', 'Luis'),
        ]),
      ),
    );

    expect(find.text('Acosta Pérez Ana'), findsOneWidget);
    expect(find.text('Bolaño Díaz Luis'), findsOneWidget);
    expect(find.text('Avanzó mucho en lectura.'), findsOneWidget);
    expect(find.text('Sin frases en este periodo.'), findsOneWidget);
  });

  testWidgets(
      'sin puede_escribir no hay botón de guardar AUNQUE el periodo '
      'esté abierto', (tester) async {
    // Es el secretario sin `is_superuser`: lee cualquier grupo y no escribe
    // ninguno. Pintar contra el periodo le daría una pantalla que le miente.
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(
          periodoAbierto: true,
          puedeEscribir: false,
          alumnos: [alumno(101, 'Acosta Pérez', 'Ana')],
        ),
      ),
    );

    expect(find.text('Guardar'), findsNothing);
    expect(find.text('Escribir'), findsNothing);
    expect(
      find.text('Tu cuenta puede ver estas frases pero no escribirlas.'),
      findsOneWidget,
    );
  });

  testWidgets('con puede_escribir SÍ hay botón aunque el periodo esté cerrado',
      (tester) async {
    // El otro lado del mismo error: un superusuario escribe con el periodo
    // cerrado, y pintar contra el periodo le quitaría algo que puede hacer.
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(
          periodoAbierto: false,
          puedeEscribir: true,
          alumnos: [alumno(101, 'Acosta Pérez', 'Ana')],
        ),
      ),
    );

    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Escribir'), findsOneWidget);
  });

  testWidgets('el periodo cerrado dice que lo está, y no habla de la cuenta',
      (tester) async {
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(
          periodoAbierto: false,
          puedeEscribir: false,
          alumnos: [alumno(101, 'Acosta Pérez', 'Ana')],
        ),
      ),
    );

    expect(
      find.textContaining('Este periodo está cerrado'),
      findsOneWidget,
    );
  });

  testWidgets('sólo viaja el alumno que se tocó', (tester) async {
    // La propiedad que hace seguro guardar por partes: un alumno que no viene
    // en el cuerpo no se mira, así que a los demás no se les puede borrar nada.
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [
        alumno(101, 'Acosta Pérez', 'Ana'),
        alumno(102, 'Bolaño Díaz', 'Luis'),
        alumno(103, 'Gómez Pico', 'Dámaris',
            frases: [fraseAMano(4003, 'Participa con agrado.')]),
      ]),
    );

    await abrir(tester, servidor);

    await tester.tap(find.text('Escribir').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mejoró mucho.');
    await tester.pumpAndSettle();

    expect(find.text('1 alumno sin guardar'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(servidor.cuerpos, hasLength(1));
    expect(alumnosDe(servidor), [101]);
  });

  testWidgets('una casilla vacía sin id no se manda y no cuenta como cambio',
      (tester) async {
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
    );

    await abrir(tester, servidor);

    await tester.tap(find.text('Escribir'));
    await tester.pumpAndSettle();

    // Se pulsó «Escribir» y no se escribió: no hay nada que guardar.
    expect(find.text('Todo guardado'), findsOneWidget);
  });

  testWidgets('vaciar una frase que ya existía la manda vacía CON su id',
      (tester) async {
    // Que es como se borra: el servidor cuenta la entrada en `vacias` y se
    // lleva la fila con las que no vinieron.
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [
        alumno(101, 'Acosta Pérez', 'Ana',
            frases: [fraseAMano(4001, 'Avanzó mucho en lectura.')]),
      ]),
    );

    await abrir(tester, servidor);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(frasesDe(servidor, 101), [
      {'id': 4001, 'frase': ''},
    ]);
  });

  testWidgets('una del catálogo vuelve con su frase_id y sin texto',
      (tester) async {
    // Si viajara con el texto dejaría de seguir al catálogo: el boletín lo
    // resuelve con un IFNULL contra lo que el colegio tenga escrito hoy.
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [
        alumno(101, 'Acosta Pérez', 'Ana', frases: [
          fraseDelCatalogo(4001, 301, 'Demuestra interés en las actividades.'),
        ]),
        alumno(102, 'Bolaño Díaz', 'Luis'),
      ]),
    );

    await abrir(tester, servidor);

    // Se toca al otro, para que el de la frase del catálogo no viaje… y se
    // comprueba justo eso.
    await tester.tap(find.text('Escribir').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Va bien.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(alumnosDe(servidor), [102]);

    // Y ahora se le quita la del catálogo al 101: viaja su lista, ya vacía.
    await tester.tap(find.byTooltip('Quitar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(alumnosDe(servidor), [101]);
    expect(frasesDe(servidor, 101), isEmpty);
  });

  testWidgets('el texto de una frase del catálogo no se puede editar',
      (tester) async {
    // Corregirlo aquí sería corregírselo a todo el colegio: la fila no guarda
    // texto, apunta al catálogo.
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(alumnos: [
          alumno(101, 'Acosta Pérez', 'Ana', frases: [
            fraseDelCatalogo(4001, 301, 'Demuestra interés.'),
          ]),
        ]),
      ),
    );

    expect(find.text('Demuestra interés.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('las frases de alumnos que ya no están en el grupo se dicen',
      (tester) async {
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(
          alumnos: [alumno(101, 'Acosta Pérez', 'Ana')],
          deFuera: 12,
        ),
      ),
    );

    expect(
      find.textContaining('12 frases de alumnos que ya no están en el grupo'),
      findsOneWidget,
    );
  });

  testWidgets('un cero de frases de fuera no saca el aviso, y un null tampoco',
      (tester) async {
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')], deFuera: 0),
      ),
    );

    expect(find.textContaining('ya no están en el grupo'), findsNothing);
  });

  testWidgets('cambiar de periodo vuelve a preguntar, y trae SU permiso',
      (tester) async {
    // Es la trampa de A4 —el backend mira la bandera del periodo destino— y
    // aquí no existe: el permiso viene en la respuesta de ese periodo.
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
      porPeriodo: {
        35: sobre(
          periodoId: 35,
          periodoAbierto: false,
          puedeEscribir: false,
          alumnos: [alumno(101, 'Acosta Pérez', 'Ana')],
        ),
      },
      years: losCuatroPeriodos,
    );

    await abrir(tester, servidor);

    expect(find.text('Guardar'), findsOneWidget);

    await tester.tap(find.text('P2'));
    await tester.pumpAndSettle();

    expect(
      servidor.pedidos.last,
      '/frases_asignatura/grupo/1?periodo_id=35',
    );
    expect(find.text('Guardar'), findsNothing);
    expect(find.textContaining('Este periodo está cerrado'), findsOneWidget);
  });

  testWidgets('el periodo que viaja al guardar es el que dijo el GET',
      (tester) async {
    // No el de la sesión: si alguien la cambió desde otra pantalla, omitirlo
    // escribiría en un periodo distinto del que se está mirando.
    final servidor = ServidorFingido(
      sobre:
          sobre(periodoId: 34, alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
    );

    await abrir(tester, servidor);

    await tester.tap(find.text('Escribir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Va bien.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(servidor.cuerpos.last['periodo_id'], 34);
  });

  testWidgets('«se guardó y no cambió nada» se dice, y no se calla',
      (tester) async {
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
      respuestaDelPut: {
        ...sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
        'poblacion': const {
          'alumnos_del_grupo': 1,
          'alumnos_revisados': 1,
          'frases_revisadas': 1,
          'escritas': 0,
          'cambiadas': 0,
          'sin_cambio': 1,
          'borradas': 0,
          'vacias': 0,
        },
      },
    );

    await abrir(tester, servidor);

    await tester.tap(find.text('Escribir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Va bien.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Se guardó y no cambió nada.'), findsOneWidget);
  });

  testWidgets('lo que el PUT devuelve se repinta, con las filas ya con su id',
      (tester) async {
    final servidor = ServidorFingido(
      sobre: sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
      respuestaDelPut: {
        ...sobre(alumnos: [
          alumno(101, 'Acosta Pérez', 'Ana',
              frases: [fraseAMano(7777, 'Va bien.')]),
        ]),
        'poblacion': const {
          'alumnos_revisados': 1,
          'escritas': 1,
        },
      },
    );

    await abrir(tester, servidor);

    await tester.tap(find.text('Escribir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Va bien.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('1 nuevas.'), findsOneWidget);
    expect(find.text('Todo guardado'), findsOneWidget);

    // Y ahora vaciar esa casilla manda el id que trajo la respuesta, sin
    // haber vuelto a pedir nada.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(frasesDe(servidor, 101), [
      {'id': 7777, 'frase': ''},
    ]);
  });

  testWidgets('un fallo al traer el grupo se dice y se puede reintentar',
      (tester) async {
    await abrir(tester, _ServidorQueFalla());

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets('sin años no hay chips, y la pantalla funciona igual',
      (tester) async {
    // `cargarYears` va en su propio try: sin periodos que ofrecer se trabaja
    // en el de la sesión, que es el caso de siempre.
    await abrir(
      tester,
      ServidorFingido(
        sobre: sobre(alumnos: [alumno(101, 'Acosta Pérez', 'Ana')]),
      ),
    );

    expect(find.text('P1'), findsNothing);
    expect(find.text('Acosta Pérez Ana'), findsOneWidget);
  });
}

class _ServidorQueFalla extends ServidorFingido {
  _ServidorQueFalla() : super(sobre: const {});

  @override
  Future get(String direccion) async {
    if (direccion.startsWith('/frases_asignatura/grupo/')) {
      return http.Response(
        jsonEncode({'message': 'No tiene permiso para ver este grupo.'}),
        403,
      );
    }
    return http.Response('[]', 200);
  }
}
