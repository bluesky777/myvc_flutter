// BANCO DE PRUEBAS DE LAYOUT — no entra en la app publicada.
//
// Abre una pantalla sola, con datos escritos a mano y sin red, para poder mirar
// cómo queda en un teléfono o en una tablet. Se lanza así:
//
//   flutter run -d emulator-5554 -t lib/main_lab.dart
//   flutter run -d chrome        -t lib/main_lab.dart      (más rápido para mirar)
//
// Existe porque decidir un layout de tablet obligaba, si no, a entrar con las
// credenciales de un colegio de verdad —que no están en el repositorio, y a
// propósito— y a mirar datos de alumnos reales para decidir un ancho.
//
// **Y desde el 19 sep 2026 hace algo más que layout.** «Mis competencias» está
// detrás de dos interruptores apagados y de un backend sin desplegar, así que
// **no hay forma de abrirla en la app**. Aquí sí, y con los casos que el colegio
// de desarrollo no puede enseñar: dos grupos en el mismo grado, una fila del
// colegio con su candado, y las frases por banda escritas para que se vea el
// previo de impresión.
//
// Lo mismo vale para «Frases del boletín» (19 sep 2026), que espera a que
// `53b50fa` se despliegue: aquí se abre, se escribe y se guarda contra un `PUT`
// simulado, con el periodo cerrado y con el caso que no se puede ver en ningún
// colegio sin crear la cuenta a propósito — sólo lectura **con** el periodo
// abierto.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/LineaDeBoletinModel.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Screens/FrasesDelGrupoScreen.dart';
import 'package:myvc_flutter/Screens/LibroAsignaturaScreen.dart';
import 'package:myvc_flutter/Screens/MisCompetenciasScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/TarjetaDeAsignatura.dart';

/// Un servidor que contesta siempre lo mismo, sin salir a la red.
class ServidorDeMentira extends Server {
  @override
  Future put(String direccion, params) async =>
      http.Response(jsonEncode(_libro), 200);

  @override
  Future get(String direccion) async => http.Response('{}', 200);
}

/// El servidor de «Mis competencias»: reparte por dirección y **acepta
/// escrituras**, para poder probar la hoja de escribir de verdad.
///
/// Las escrituras no persisten entre recargas —esto no es una base—, pero sí
/// contestan la fila que la pantalla espera, que es lo que hace falta para ver
/// si el flujo de escribir se siente bien.
class ServidorDeCompetencias extends Server {
  ServidorDeCompetencias({required this.asignaturas, required this.desempenos});

  final List<Map<String, dynamic>> asignaturas;
  final List<Map<String, dynamic>> desempenos;

  int _siguienteId = 900;

  @override
  Future get(String direccion) async {
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
      return http.Response(jsonEncode(_escalas), 200);
    }
    return http.Response('[]', 200);
  }

  @override
  Future post(String direccion, params) async {
    final cuerpo = Map<String, dynamic>.from(params as Map);
    cuerpo['id'] = _siguienteId++;
    cuerpo['orden'] = desempenos.length + 1;
    desempenos.add(cuerpo);
    return http.Response(jsonEncode(cuerpo), 200);
  }

  @override
  Future put(String direccion, params) async {
    final id = int.tryParse(direccion.split('/').last) ?? 0;
    final fila = desempenos.firstWhere(
      (d) => d['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    fila.addAll(Map<String, dynamic>.from(params as Map));
    return http.Response(jsonEncode(fila), 200);
  }

  @override
  Future delete(String direccion) async {
    final id = int.tryParse(direccion.split('/').last) ?? 0;
    desempenos.removeWhere((d) => d['id'] == id);
    return http.Response(jsonEncode({'id': id}), 200);
  }
}

/// El servidor de «Frases del boletín»: **un grupo por periodo, y escribe**.
///
/// El `PUT` se simula de verdad —reconoce las filas por su `id`, se lleva las
/// que no vuelven, cuenta lo que hizo— porque lo que hay que mirar aquí es
/// justo eso: que guardar diga qué pasó y que la pantalla se quede con las
/// filas nuevas ya con su id. Un servidor que contestara «OK» dejaría sin
/// probar la mitad interesante.
///
/// Lo que escriba no sobrevive a recargar: esto no es una base.
class ServidorDeFrases extends Server {
  ServidorDeFrases({
    required this.sobres,
    this.catalogo = const [],
    this.periodoDeLaSesion = 34,
  });

  /// El sobre de cada periodo, con la forma que manda el backend. Se muta.
  final Map<int, Map<String, dynamic>> sobres;

  final List<Map<String, dynamic>> catalogo;

  /// En qué periodo está la sesión, que es lo que contesta un `GET` sin
  /// `periodo_id` — igual que el de verdad.
  final int periodoDeLaSesion;

  int _siguienteId = 5000;

  int _periodoDe(String direccion) {
    final pedido = Uri.parse(direccion).queryParameters['periodo_id'];
    return int.tryParse(pedido ?? '') ?? periodoDeLaSesion;
  }

  @override
  Future get(String direccion) async {
    // Antes que `/frases` a secas, que es prefijo de ésta.
    if (direccion.startsWith('/frases_asignatura/grupo/')) {
      final periodo = _periodoDe(direccion);
      final sobre = sobres[periodo];

      if (sobre == null) {
        return http.Response(
          jsonEncode({'message': 'Ese periodo no es del año de la asignatura.'}),
          422,
        );
      }

      return http.Response(jsonEncode(_leido(sobre)), 200);
    }

    if (direccion.startsWith('/frases')) {
      return http.Response(jsonEncode(catalogo), 200);
    }

    if (direccion.startsWith('/years')) {
      return http.Response(jsonEncode(_years), 200);
    }

    return http.Response('[]', 200);
  }

  @override
  Future put(String direccion, params) async {
    if (!direccion.startsWith('/frases_asignatura/grupo/')) {
      return http.Response('{}', 200);
    }

    final cuerpo = Map<String, dynamic>.from(params as Map);
    final periodo =
        int.tryParse('${cuerpo['periodo_id'] ?? ''}') ?? periodoDeLaSesion;
    final sobre = sobres[periodo];

    if (sobre == null) {
      return http.Response(
        jsonEncode({'message': 'Ese periodo no es del año de la asignatura.'}),
        422,
      );
    }

    // Los dos 403 del contrato, que se distinguen sólo por el texto.
    if (sobre['puede_escribir'] != true) {
      return http.Response(
        jsonEncode({
          'message': sobre['periodo_abierto'] == true
              ? 'No tiene permiso para escribir las frases del boletín.'
              : 'El periodo está cerrado: no se puede escribir en él.',
        }),
        403,
      );
    }

    return http.Response(jsonEncode(_guardar(sobre, cuerpo)), 200);
  }

  Map<String, dynamic> _leido(Map<String, dynamic> sobre) {
    final alumnos = (sobre['alumnos'] as List).cast<Map<String, dynamic>>();
    final conFrases =
        alumnos.where((a) => (a['frases'] as List).isNotEmpty).length;

    return {
      ...sobre,
      'poblacion': {
        'alumnos': alumnos.length,
        'frases': alumnos.fold<int>(
            0, (suma, a) => suma + (a['frases'] as List).length),
        'alumnos_con_frases': conFrases,
        'alumnos_sin_frases': alumnos.length - conFrases,
        'frases_fuera_del_grupo': sobre['_de_fuera'] ?? 0,
      },
    };
  }

  Map<String, dynamic> _guardar(
    Map<String, dynamic> sobre,
    Map<String, dynamic> cuerpo,
  ) {
    var escritas = 0;
    var cambiadas = 0;
    var sinCambio = 0;
    var borradas = 0;
    var vacias = 0;
    var revisadas = 0;

    final alumnos = (sobre['alumnos'] as List).cast<Map<String, dynamic>>();
    final pedidos = (cuerpo['alumnos'] as List).cast<Map>();

    for (final pedido in pedidos) {
      final fila = alumnos.firstWhere(
        (a) => a['alumno_id'] == pedido['alumno_id'],
        orElse: () => <String, dynamic>{},
      );
      if (fila.isEmpty) continue;

      final antes = (fila['frases'] as List).cast<Map<String, dynamic>>();
      final despues = <Map<String, dynamic>>[];

      for (final entrada in (pedido['frases'] as List).cast<Map>()) {
        revisadas++;

        final fraseId = entrada['frase_id'];
        final texto = '${entrada['frase'] ?? ''}'.trim();

        // Sin frase del catálogo y sin texto no es una frase: no se escribe, y
        // si traía `id` esa fila se va con las que no vinieron.
        if (fraseId == null && texto.isEmpty) {
          vacias++;
          continue;
        }

        final previa = antes.firstWhere(
          (f) => entrada['id'] != null && f['id'] == entrada['id'],
          orElse: () => <String, dynamic>{},
        );

        if (previa.isEmpty) {
          escritas++;
          despues.add(_nuevaFila(fraseId, texto));
        } else if (previa['frase_id'] != fraseId ||
            '${previa['frase_escrita'] ?? ''}' != texto) {
          cambiadas++;
          despues.add({...previa, ..._nuevaFila(fraseId, texto), 'id': previa['id']});
        } else {
          sinCambio++;
          despues.add(previa);
        }
      }

      borradas += antes
          .where((f) => !despues.any((d) => d['id'] == f['id']))
          .length;

      fila['frases'] = despues;
    }

    return {
      ...sobre,
      'poblacion': {
        'alumnos_del_grupo': alumnos.length,
        'alumnos_revisados': pedidos.length,
        'frases_revisadas': revisadas,
        'escritas': escritas,
        'cambiadas': cambiadas,
        'sin_cambio': sinCambio,
        'borradas': borradas,
        'vacias': vacias,
      },
    };
  }

  Map<String, dynamic> _nuevaFila(dynamic fraseId, String texto) {
    final delCatalogo = catalogo.firstWhere(
      (f) => f['id'] == fraseId,
      orElse: () => const <String, dynamic>{},
    );

    return {
      'id': _siguienteId++,
      // `frase` es lo que imprime el boletín y `frase_escrita` lo que guarda la
      // fila: una del catálogo no guarda texto ninguno.
      'frase': fraseId == null ? texto : '${delCatalogo['frase'] ?? ''}',
      'frase_escrita': fraseId == null ? texto : null,
      'frase_id': fraseId,
      'tipo_frase': fraseId == null ? null : '${delCatalogo['tipo_frase'] ?? ''}',
    };
  }
}

/// Los cuatro periodos del año, para que salga el selector.
const _years = [
  {
    'id': 9,
    'year': '2026',
    'actual': 1,
    'periodos': [
      {'id': 34, 'numero': 1},
      {'id': 35, 'numero': 2},
      {'id': 36, 'numero': 3},
      {'id': 37, 'numero': 4},
    ],
  },
];

/// El catálogo del colegio, recortado: en producción pasa de cuatrocientas.
const _catalogoDeFrases = [
  {
    'id': 301,
    'frase': 'Demuestra interés y participa con agrado en las actividades.',
    'tipo_frase': 'Fortaleza',
  },
  {
    'id': 302,
    'frase': 'Se le dificulta terminar sus trabajos en el tiempo previsto.',
    'tipo_frase': 'Debilidad',
  },
  {
    'id': 303,
    'frase': 'Comparte con sus compañeros y respeta la palabra del otro.',
    'tipo_frase': 'Fortaleza',
  },
];

Map<String, dynamic> _alumnoConFrases(
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

/// El periodo 1: unos con frases, otros sin ninguna, y dos retirados con las
/// suyas — que es el renglón que sólo se puede ver aquí.
Map<String, dynamic> _sobreDelPeriodo1() => {
      'asignatura_id': 1,
      'grupo_id': 7,
      'year_id': 9,
      'periodo_id': 34,
      'periodo_abierto': true,
      'puede_escribir': true,
      '_de_fuera': 12,
      'alumnos': [
        _alumnoConFrases(101, 'Acosta Pérez', 'Ana', frases: [
          {
            'id': 4001,
            'frase': 'Demuestra interés y participa con agrado en las '
                'actividades.',
            'frase_escrita': null,
            'frase_id': 301,
            'tipo_frase': 'Fortaleza',
          },
          {
            'id': 4002,
            'frase': 'Le cuesta entregar a tiempo, aunque el trabajo está '
                'bien hecho.',
            'frase_escrita': 'Le cuesta entregar a tiempo, aunque el trabajo '
                'está bien hecho.',
            'frase_id': null,
            'tipo_frase': null,
          },
        ]),
        _alumnoConFrases(102, 'Bolaño Díaz', 'Luis'),
        _alumnoConFrases(103, 'Gómez Pico', 'Dámaris', frases: [
          {
            'id': 4003,
            'frase': 'Avanzó mucho en lectura este periodo.',
            'frase_escrita': 'Avanzó mucho en lectura este periodo.',
            'frase_id': null,
            'tipo_frase': null,
          },
        ]),
        _alumnoConFrases(104, 'Herrera Ruiz', 'Julián'),
        _alumnoConFrases(105, 'Ibarra Solano', 'Marcela'),
      ],
    };

/// El periodo 2, **cerrado**: se ve y no se toca.
Map<String, dynamic> _sobreDelPeriodo2() => {
      'asignatura_id': 1,
      'grupo_id': 7,
      'year_id': 9,
      'periodo_id': 35,
      'periodo_abierto': false,
      'puede_escribir': false,
      'alumnos': [
        _alumnoConFrases(101, 'Acosta Pérez', 'Ana'),
        _alumnoConFrases(102, 'Bolaño Díaz', 'Luis'),
        _alumnoConFrases(103, 'Gómez Pico', 'Dámaris'),
        _alumnoConFrases(104, 'Herrera Ruiz', 'Julián'),
        _alumnoConFrases(105, 'Ibarra Solano', 'Marcela'),
      ],
    };

/// El caso que no se puede ver en un colegio sin crear la cuenta a propósito:
/// **periodo abierto y aun así sólo lectura**, que es lo que le pasa a un
/// secretario sin `is_superuser`.
Map<String, dynamic> _sobreDeSoloLectura() => {
      ..._sobreDelPeriodo1(),
      'periodo_abierto': true,
      'puede_escribir': false,
    };

/// Las cuatro bandas **con sus frases escritas**.
///
/// Hoy ningún colegio las tiene —las 36 escalas vivas del colegio de desarrollo
/// tienen la descripción vacía—, así que sin esto el previo de impresión no se
/// pintaría y lo más nuevo de la pantalla no se podría mirar.
const _escalas = [
  {
    'id': 4,
    'desempenio': 'Superior',
    'porc_inicial': 91,
    'porc_final': 100,
    'descripcion': 'Excelencia en',
  },
  {
    'id': 3,
    'desempenio': 'Alto',
    'porc_inicial': 76,
    'porc_final': 90,
    'descripcion': 'Fortaleza en',
  },
  {
    'id': 2,
    'desempenio': 'Básico',
    'porc_inicial': 60,
    'porc_final': 75,
    'descripcion': 'Alcanza',
  },
  {
    'id': 1,
    'desempenio': 'Bajo',
    'porc_inicial': 0,
    'porc_final': 59,
    'descripcion': 'Dificultad en',
    'perdido': 1,
  },
];

Map<String, dynamic> _asignatura({
  required int id,
  required int grupoId,
  required String abrev,
  required String nombreGrupo,
  int? materiaId,
  int? gradoId,
  String materia = 'MATEMÁTICAS',
}) {
  return {
    'asignatura_id': id,
    'grupo_id': grupoId,
    'profesor_id': 7,
    'materia': materia,
    'alias_materia': '',
    'nombre_grupo': nombreGrupo,
    'abrev_grupo': abrev,
    if (materiaId != null) 'materia_id': materiaId,
    if (gradoId != null) 'grado_id': gradoId,
    'unidades': [],
  };
}

/// El caso que `simonbolivar` NO puede enseñar: dos grupos en el mismo grado.
///
/// Trece grupos y trece grados, uno por grado — así que probando contra ese
/// colegio el renglón «vale para 6A y 6B» no sale nunca y parece que sobra.
final _asignaturasCompletas = [
  _asignatura(
      id: 1,
      grupoId: 101,
      abrev: '6A',
      nombreGrupo: 'Sexto A',
      materiaId: 13,
      gradoId: 11),
  _asignatura(
      id: 2,
      grupoId: 102,
      abrev: '6B',
      nombreGrupo: 'Sexto B',
      materiaId: 13,
      gradoId: 11),
  // La misma materia en otro grado: dos tarjetas que se titulan igual, porque
  // el backend no manda el nombre del grado. Las separa el grupo.
  _asignatura(
      id: 3,
      grupoId: 201,
      abrev: '7A',
      nombreGrupo: 'Séptimo A',
      materiaId: 13,
      gradoId: 12),
  // Y una sin nada escrito todavía.
  _asignatura(
    id: 4,
    grupoId: 202,
    abrev: '7A',
    nombreGrupo: 'Séptimo A',
    materiaId: 20,
    gradoId: 12,
    materia: 'CIENCIAS NATURALES',
  ),
];

/// Lo que ven HOY los dieciséis colegios: las asignaturas llegan sin los dos
/// ids, porque `fe95da8` está escrito y sin desplegar.
final _asignaturasSinIds = [
  _asignatura(id: 1, grupoId: 101, abrev: '6A', nombreGrupo: 'Sexto A'),
  _asignatura(id: 2, grupoId: 102, abrev: '6B', nombreGrupo: 'Sexto B'),
];

List<Map<String, dynamic>> _catalogo() => [
      {
        'id': 71,
        'definicion': 'Participa con respeto en las actividades del área.',
        'tipo': 'Ser',
        'orden': 1,
        'materia_id': 13,
        'grado_id': null,
        'periodo_id': 34,
      },
      {
        'id': 25,
        'definicion': 'Interpreta gráficas de barras y las usa para comparar '
            'dos conjuntos de datos.',
        'tipo': 'Saber',
        'orden': 1,
        'materia_id': 13,
        'grado_id': 11,
        'periodo_id': 34,
      },
      {
        'id': 26,
        'definicion': 'Construye figuras planas a partir de sus medidas.',
        'tipo': null,
        'orden': 2,
        'materia_id': 13,
        'grado_id': 11,
        'periodo_id': 34,
      },
      {
        'id': 40,
        'definicion': 'Resuelve problemas con números racionales.',
        'tipo': null,
        'orden': 1,
        'materia_id': 13,
        'grado_id': 12,
        'periodo_id': 34,
      },
    ];

/// Cinco indicadores repartidos en dos unidades, que es el caso que se midió
/// mal en tablet: poco contenido y mucha pantalla.
final _libro = {
  'asignatura': {
    'asignatura_id': 1,
    'grupo_id': 7,
    'materia': 'Matemáticas',
    'alias_materia': 'Matemáticas',
    'nombre_grupo': 'Décimo B',
    'abrev_grupo': '10-B',
  },
  'unidades': [
    {
      'id': 10,
      'asignatura_id': 1,
      'periodo_id': 3,
      'definicion': 'Funciones y sus gráficas',
      'porcentaje': 60,
      'orden': 1,
      'subunidades': [
        {
          'id': 101,
          'unidad_id': 10,
          'definicion': 'Quiz de función lineal',
          'porcentaje': 20,
          'orden': 1,
        },
        {
          'id': 102,
          'unidad_id': 10,
          'definicion': 'Taller de pendiente y corte',
          'porcentaje': 20,
          'orden': 2,
        },
        {
          'id': 103,
          'unidad_id': 10,
          'definicion': 'Evaluación de la unidad',
          'porcentaje': 20,
          'orden': 3,
        },
      ],
    },
    {
      'id': 11,
      'asignatura_id': 1,
      'periodo_id': 3,
      'definicion': 'Sistemas de ecuaciones',
      'porcentaje': 40,
      'orden': 2,
      'subunidades': [
        {
          'id': 111,
          'unidad_id': 11,
          'definicion': 'Método de sustitución',
          'porcentaje': 20,
          'orden': 1,
        },
        {
          'id': 112,
          'unidad_id': 11,
          'definicion': 'Problemas de aplicación',
          'porcentaje': 20,
          'orden': 2,
        },
      ],
    },
  ],
  'alumnos': [
    for (var i = 0; i < 30; i++)
      {
        'alumno_id': 100 + i,
        'nombres': _nombres[i % _nombres.length],
        'apellidos': _apellidos[i % _apellidos.length],
        'estado': 'MATR',
        'notas': [
          {'subunidad_id': 101, 'nota': 70 + (i % 30), 'id': 900 + i},
        ],
      },
  ],
};

const _nombres = [
  'Ana',
  'Luis',
  'Dámaris',
  'Julián',
  'Marcela',
  'Andrés',
  'Valentina',
  'Santiago',
  'Camila',
  'Nicolás',
];

const _apellidos = [
  'Acosta Pérez',
  'Bolaño Díaz',
  'Gómez Pico',
  'Herrera Ruiz',
  'Ibarra Solano',
];

/// Deja la sesión como la de un docente, que es quien usa estas pantallas.
///
/// `personaId` es el 7 y las asignaturas de mentira llevan `profesor_id: 7`:
/// eso es lo que hace que la pantalla las dé por suyas y enseñe los botones.
/// Con otro número saldrían todas en sólo lectura, que también es un caso que
/// se puede mirar cambiando este 7.
void _entrarComoDocente({bool periodoAbierto = true}) {
  AuthService.user = UserAutenticado(
    username: 'lab',
    nombres: 'Banco de pruebas',
    tipo: 'Profesor',
    personaId: 7,
  );

  ContextoAcademico.instancia.tomarDelLogin({
    'year_id': 9,
    'periodo_id': 34,
    'numero_periodo': 1,
    'modelo_evaluacion': 'competencias',
    'desempeno_displayname': 'Competencia',
    'desempenos_displayname': 'Competencias',
    'genero_desempeno': 'F',
    'profes_pueden_editar_notas': periodoAbierto ? 1 : 0,
  });
}

void main() {
  _entrarComoDocente();

  runApp(const MaterialApp(
    title: 'Banco de pruebas',
    debugShowCheckedModeBanner: false,
    home: _Indice(),
  ));
}

/// Las dos formas de la tarjeta, una encima de otra.
///
/// No se abre `MisNotasScreen` entera porque sus competencias van detrás de un
/// `const false`: desde la pantalla, el caso «con líneas» es inalcanzable. Aquí
/// se monta el widget directamente, que es justo la pieza que hay que juzgar.
class _LasDosTarjetas extends StatelessWidget {
  const _LasDosTarjetas();

  AsignaturaNotaModel get _asignatura => AsignaturaNotaModel(
        asignaturaId: 1,
        materia: 'MATEMÁTICAS',
        docente: 'Ariolfo Gómez Restrepo',
        nota: 82,
        desempenio: 'Alto',
      );

  LineaDeBoletin _linea(String texto, String origen) =>
      LineaDeBoletin.fromJson({'texto': texto, 'origen': origen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(title: const Text('La tarjeta de la familia')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _rotulo('Hoy, en los dieciséis colegios'),
          TarjetaDeAsignatura(asignatura: _asignatura),
          const SizedBox(height: 24),
          _rotulo('Con el año por competencias'),
          TarjetaDeAsignatura(
            asignatura: _asignatura,
            lineas: [
              _linea(
                'Fortaleza en interpretar gráficas de barras y usarlas para '
                    'comparar dos conjuntos de datos.',
                'catalogo',
              ),
              _linea(
                'Fortaleza en construir figuras planas a partir de sus medidas.',
                'catalogo',
              ),
              _linea(
                'Le cuesta entregar a tiempo, aunque el trabajo está bien hecho.',
                'frase',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.black45,
          ),
        ),
      );
}

/// La portada del banco: qué pantalla y en qué estado.
class _Indice extends StatelessWidget {
  const _Indice();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banco de pruebas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sin red y sin cuenta. Nada de lo que se escriba aquí sale del '
            'teléfono ni sobrevive a recargar.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          _seccion('Mis competencias'),
          _boton(
            context,
            titulo: 'Como se verá cuando esté desplegado',
            detalle: 'Dos grupos en un grado, una fila del colegio con su '
                'candado, y las frases por banda escritas para ver el previo.',
            construir: () => MisCompetenciasScreen(
              servidor: ServidorDeCompetencias(
                asignaturas: _asignaturasCompletas,
                desempenos: _catalogo(),
              ),
            ),
          ),
          _boton(
            context,
            titulo: 'Con el periodo cerrado',
            detalle: 'Sin botones, y el candado diciendo por qué.',
            alPulsar: () => _entrarComoDocente(periodoAbierto: false),
            alVolver: () => _entrarComoDocente(),
            construir: () => MisCompetenciasScreen(
              servidor: ServidorDeCompetencias(
                asignaturas: _asignaturasCompletas,
                desempenos: _catalogo(),
              ),
            ),
          ),
          _boton(
            context,
            titulo: 'Como se ve HOY en los dieciséis colegios',
            detalle: 'Las asignaturas llegan sin materia_id ni grado_id, así '
                'que la pantalla lo dice en vez de salir vacía.',
            construir: () => MisCompetenciasScreen(
              servidor: ServidorDeCompetencias(
                asignaturas: _asignaturasSinIds,
                desempenos: const [],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _seccion('El boletín de la familia'),
          _boton(
            context,
            titulo: 'La tarjeta, con y sin competencias',
            detalle: 'Las dos una debajo de otra, para comparar dónde queda el '
                'nombre de la banda.',
            construir: () => const _LasDosTarjetas(),
          ),
          const SizedBox(height: 20),
          _seccion('Frases del boletín'),
          _boton(
            context,
            titulo: 'El grupo entero, y se puede elegir el periodo',
            detalle: 'Cinco alumnos, una frase del catálogo y dos a mano. El '
                'P2 está cerrado: el chip lo enseña sin salir de aquí.',
            construir: () => FrasesDelGrupoScreen(
              asignaturaId: 1,
              materia: 'Matemáticas',
              nombreGrupo: 'Décimo B',
              servidor: ServidorDeFrases(
                sobres: {34: _sobreDelPeriodo1(), 35: _sobreDelPeriodo2()},
                catalogo: _catalogoDeFrases,
              ),
            ),
          ),
          _boton(
            context,
            titulo: 'Sólo lectura CON el periodo abierto',
            detalle: 'Lo que le pasa a un secretario sin is_superuser. No se '
                'puede ver en un colegio sin crearle la cuenta a propósito.',
            construir: () => FrasesDelGrupoScreen(
              asignaturaId: 1,
              materia: 'Matemáticas',
              nombreGrupo: 'Décimo B',
              servidor: ServidorDeFrases(
                sobres: {34: _sobreDeSoloLectura()},
                catalogo: _catalogoDeFrases,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _seccion('Libro de notas'),
          _boton(
            context,
            titulo: 'La planilla y su lista',
            detalle: 'Treinta alumnos, cinco indicadores. El caso que se midió '
                'mal en tablet.',
            construir: () => LibroAsignaturaScreen(
              asignatura: AsignaturaModel.fromJson(
                Map<String, dynamic>.from(_libro['asignatura'] as Map),
              ),
              servidor: ServidorDeMentira(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.black45,
          ),
        ),
      );

  Widget _boton(
    BuildContext context, {
    required String titulo,
    required String detalle,
    required Widget Function() construir,
    VoidCallback? alPulsar,
    VoidCallback? alVolver,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(titulo, style: const TextStyle(fontSize: 14)),
        subtitle: Text(detalle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          alPulsar?.call();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => construir()),
          );
          alVolver?.call();
        },
      ),
    );
  }
}
