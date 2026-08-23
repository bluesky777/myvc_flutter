import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// El libro de notas de una asignatura en el periodo: sus unidades y sus
/// alumnos con la nota de cada casilla.
class LibroDeNotas {
  final AsignaturaModel asignatura;
  final List<UnidadModel> unidades;
  final List<AlumnoDelLibro> alumnos;

  const LibroDeNotas({
    required this.asignatura,
    this.unidades = const [],
    this.alumnos = const [],
  });

  /// Las subunidades de todas las unidades, en el orden en que se ponen las
  /// notas. Es la lista que se recorre para elegir indicador.
  List<SubunidadModel> get subunidades => [
        for (final unidad in unidades) ...unidad.subunidades,
      ];

  /// Cuántas notas hay puestas en esa casilla, contando solo las que alguien
  /// tocó. Sirve para decir «faltan 12» sin pedir nada más.
  int notasPuestasEn(int subunidadId) => alumnos
      .where((a) => a.notaDe(subunidadId)?.puesta ?? false)
      .length;

  /// El mismo libro con las notas que se acaban de guardar ya aplicadas.
  ///
  /// Existe para no volver a pedir `notas/detailed` al salir de una planilla:
  /// lo que quedó guardado se sabe —es lo que se mandó y el servidor aceptó—,
  /// y esa consulta es demasiado cara para gastarla en refrescar un número.
  LibroDeNotas conNotas(List<NotaPendiente> guardadas) {
    if (guardadas.isEmpty) return this;

    final porAlumno = <int, List<NotaPendiente>>{};
    for (final guardada in guardadas) {
      porAlumno.putIfAbsent(guardada.alumnoId, () => []).add(guardada);
    }

    return LibroDeNotas(
      asignatura: asignatura,
      unidades: unidades,
      alumnos: [
        for (final alumno in alumnos)
          porAlumno.containsKey(alumno.alumnoId)
              ? alumno.con(porAlumno[alumno.alumnoId]!)
              : alumno,
      ],
    );
  }
}

/// Un alumno dentro del libro, con sus notas de esta asignatura.
class AlumnoDelLibro {
  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? fotoNombre;

  /// 'MATR', 'ASIS' o 'PREM'. El front pinta en cursiva a los asistentes y
  /// marca con un rótulo a los prematriculados: no son alumnos matriculados y
  /// conviene notarlo antes de ponerles una nota.
  final String? estado;

  /// Si tiene necesidades educativas especiales.
  final bool nee;

  final int ausenciasCount;
  final int tardanzasCount;

  /// Sus notas, por id de subunidad. Mapa y no lista porque la pantalla
  /// pregunta siempre por una casilla concreta.
  final Map<int, NotaDelLibro> notas;

  final NotaFinalDelLibro? notaFinal;

  const AlumnoDelLibro({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.fotoNombre,
    this.estado,
    this.nee = false,
    this.ausenciasCount = 0,
    this.tardanzasCount = 0,
    this.notas = const {},
    this.notaFinal,
  });

  /// Como se lista: por apellidos, que es como los ordena el backend y como
  /// los llama el docente.
  String get nombreEnLista => '$apellidos $nombres'.trim();

  NotaDelLibro? notaDe(int subunidadId) => notas[subunidadId];

  /// El mismo alumno con esas notas cambiadas. Se busca la casilla por el id de
  /// la nota, no por el de la subunidad: es lo que trae [NotaPendiente] y lo
  /// que de verdad identifica la fila que se acaba de escribir.
  AlumnoDelLibro con(List<NotaPendiente> guardadas) {
    final nuevas = Map<int, NotaDelLibro>.from(notas);

    for (final guardada in guardadas) {
      for (final entrada in nuevas.entries) {
        if (entrada.value.id != guardada.notaId) continue;
        nuevas[entrada.key] = entrada.value.con(guardada.nota);
        break;
      }
    }

    return AlumnoDelLibro(
      alumnoId: alumnoId,
      nombres: nombres,
      apellidos: apellidos,
      fotoNombre: fotoNombre,
      estado: estado,
      nee: nee,
      ausenciasCount: ausenciasCount,
      tardanzasCount: tardanzasCount,
      notas: nuevas,
      notaFinal: notaFinal,
    );
  }

  factory AlumnoDelLibro.fromJson(Map<String, dynamic> json) {
    final crudas = json['notas'];
    final notas = <int, NotaDelLibro>{};

    if (crudas is List) {
      for (final cruda in crudas.whereType<Map>()) {
        final nota = NotaDelLibro.fromJson(Map<String, dynamic>.from(cruda));
        if (nota.subunidadId != 0) notas[nota.subunidadId] = nota;
      }
    }

    final finalCruda = json['nota_final'];

    return AlumnoDelLibro(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: '${json['apellidos'] ?? ''}',
      // `Grupo::alumnos` ya resuelve la foto por defecto según el sexo, así que
      // esto nunca viene vacío por no tener foto propia.
      fotoNombre: texto(json['foto_nombre']),
      estado: texto(json['estado']),
      nee: entero(json['nee']) == 1,
      ausenciasCount: enteroO(json['ausencias_count']),
      tardanzasCount: enteroO(json['tardanzas_count']),
      notas: notas,
      notaFinal: finalCruda is Map
          ? NotaFinalDelLibro.fromJson(Map<String, dynamic>.from(finalCruda))
          : null,
    );
  }
}

/// La nota de un alumno en una casilla.
class NotaDelLibro {
  /// El id de la fila de `notas`, que es lo que necesita `notas/update/{id}`.
  final int id;
  final int subunidadId;
  final double? nota;

  const NotaDelLibro({
    required this.id,
    required this.subunidadId,
    this.nota,
  });

  /// Si esta casilla tiene una nota puesta.
  ///
  /// La fila existe desde que alguien abrió el libro —`notas/detailed` las crea
  /// con la nota por defecto de la subunidad—, así que «tiene fila» no es lo
  /// mismo que «tiene nota». Lo que no se sabe es si el 0 lo puso el docente o
  /// es el valor de fábrica; por eso esto solo dice si hay número, y quien
  /// quiera contar lo pendiente que mire además la nota por defecto.
  bool get puesta => nota != null;

  NotaDelLibro con(double? nueva) =>
      NotaDelLibro(id: id, subunidadId: subunidadId, nota: nueva);

  factory NotaDelLibro.fromJson(Map<String, dynamic> json) {
    return NotaDelLibro(
      id: enteroO(json['id'] ?? json['nota_id']),
      subunidadId: enteroO(json['subunidad_id']),
      nota: _decimal(json['nota']),
    );
  }
}

/// La definitiva del alumno en la asignatura y el periodo.
class NotaFinalDelLibro {
  final int nfId;
  final double? nota;

  /// La que sale de las subunidades ponderadas, antes de nivelar.
  final double? automatica;

  /// Si la definitiva se puso a mano: entonces el recálculo no la pisa.
  final bool manual;

  /// Si viene de una recuperación. Es independiente de [manual].
  final bool recuperada;

  const NotaFinalDelLibro({
    required this.nfId,
    this.nota,
    this.automatica,
    this.manual = false,
    this.recuperada = false,
  });

  factory NotaFinalDelLibro.fromJson(Map<String, dynamic> json) {
    return NotaFinalDelLibro(
      nfId: enteroO(json['nf_id']),
      nota: _decimal(json['nota_final']),
      automatica: _decimal(json['def_materia_auto']),
      manual: entero(json['manual']) == 1,
      recuperada: entero(json['recuperada']) == 1,
    );
  }
}

/// Trae el libro de notas de una asignatura.
///
/// `PUT notas/detailed` con `{asignatura_id, profesor_id, con_asignaturas}`. El
/// periodo no se manda: el backend usa el del usuario, o sea el de la barra de
/// arriba.
///
/// **Es la consulta más cara del proyecto y hay que llamarla lo menos posible.**
/// Por cada subunidad hace un `INSERT … WHERE NOT EXISTS` por alumno, y después,
/// por cada alumno, va a buscar sus ausencias, sus tardanzas, sus frases y su
/// definitiva —recalculándola si no es manual—. Con doce subunidades y treinta
/// alumnos son cientos de consultas en una sola petición, contra un hosting
/// compartido. Se pide una vez por asignatura, se guarda en memoria mientras la
/// pantalla viva, y se vuelve a pedir solo tirando hacia abajo.
///
/// Y hay que llamarla al menos una vez, porque esos inserts son los que
/// **materializan** las filas de `notas`. Sin ellas no hay `nota.id` que
/// actualizar. `PUT notas/subunidad`, que sería más barato para una sola
/// casilla, intenta lo mismo con un SQL roto —ver `docs/notas.md` §6.1—, así
/// que no sirve de atajo.
Future<LibroDeNotas> traerLibroDe(
  Server server, {
  required int asignaturaId,
  int? profesorId,
}) async {
  final res = await server.put('/notas/detailed', {
    'asignatura_id': asignaturaId,
    if (profesorId != null) 'profesor_id': profesorId,
    'con_asignaturas': false,
  });

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió el libro de notas.');
  }

  final asignatura = cuerpo['asignatura'];
  final unidades = cuerpo['unidades'];
  final alumnos = cuerpo['alumnos'];

  return LibroDeNotas(
    asignatura: AsignaturaModel.fromJson(
      asignatura is Map
          ? Map<String, dynamic>.from(asignatura)
          : {'asignatura_id': asignaturaId},
    ),
    unidades: unidades is List
        ? (unidades
            .whereType<Map>()
            .map((u) => UnidadModel.fromJson(Map<String, dynamic>.from(u)))
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden)))
        : const [],
    alumnos: alumnos is List
        ? alumnos
            .whereType<Map>()
            .map((a) => AlumnoDelLibro.fromJson(Map<String, dynamic>.from(a)))
            .where((a) => a.alumnoId != 0)
            .toList()
        : const [],
  );
}

/// Una nota que el docente cambió y todavía no ha salido de la app.
class NotaPendiente {
  final int notaId;
  final int alumnoId;
  final double nota;

  const NotaPendiente({
    required this.notaId,
    required this.alumnoId,
    required this.nota,
  });
}

/// Cómo fue el guardado de un lote.
class ResultadoGuardado {
  final int guardadas;

  /// Las que no entraron, para dejarlas marcadas y poder reintentarlas sin que
  /// el docente vuelva a teclear nada.
  final List<NotaPendiente> fallidas;

  /// El primer motivo que dio el servidor, para explicarlo una vez y no treinta.
  final String? motivo;

  const ResultadoGuardado({
    required this.guardadas,
    this.fallidas = const [],
    this.motivo,
  });

  bool get todoBien => fallidas.isEmpty;
}

/// Cuántas notas se mandan a la vez.
///
/// No hay endpoint de lote —`notas/update/{id}` es de una en una—, así que
/// guardar una columna son N peticiones. Treinta a la vez contra un hosting
/// compartido es la forma más rápida de que empiece a rechazarlas; de tres en
/// tres tarda casi lo mismo y no lo tumba.
const int _aLaVez = 3;

/// Guarda las notas que cambiaron, unas pocas a la vez.
///
/// Solo las que cambiaron: quien llama compara con lo que trajo el servidor
/// antes de armar la lista. En el caso «puse 100 a todos y ya estaban en 100»
/// eso son cero peticiones, donde el front web hace treinta.
///
/// No revienta con la primera que falle: las demás tienen que entrar igual, y
/// las que no vuelven en [ResultadoGuardado.fallidas] para reintentarlas.
Future<ResultadoGuardado> guardarNotas(
  Server server,
  List<NotaPendiente> cambios, {
  void Function(int hechas, int total)? avance,
}) async {
  if (cambios.isEmpty) return const ResultadoGuardado(guardadas: 0);

  final fallidas = <NotaPendiente>[];
  var guardadas = 0;
  var siguiente = 0;
  String? motivo;

  Future<void> trabajador() async {
    while (true) {
      final indice = siguiente++;
      if (indice >= cambios.length) return;

      final cambio = cambios[indice];
      final fallo = await guardarNota(
        server,
        notaId: cambio.notaId,
        nota: cambio.nota,
      );

      if (fallo == null) {
        guardadas++;
      } else {
        fallidas.add(cambio);
        motivo ??= fallo;
      }

      avance?.call(guardadas + fallidas.length, cambios.length);
    }
  }

  // Sin `siguiente` compartido cada trabajador tendría su propio índice y se
  // pisarían. Vale con una variable normal: aquí no hay hilos, y entre el `++`
  // y el `await` no se cuela nadie.
  await Future.wait([
    for (var i = 0; i < _aLaVez && i < cambios.length; i++) trabajador(),
  ]);

  return ResultadoGuardado(
    guardadas: guardadas,
    fallidas: fallidas,
    motivo: motivo,
  );
}

/// Guarda una nota. Devuelve null si entró, o el motivo si no.
///
/// `PUT notas/update/{id}`. El backend comprueba el permiso contra el periodo
/// de esa nota concreta y responde 400 cuando el periodo está cerrado, así que
/// ese código no es «petición mal hecha»: es «no te dejan».
Future<String?> guardarNota(
  Server server, {
  required int notaId,
  required double nota,
}) async {
  try {
    final res = await server.put('/notas/update/$notaId', {'nota': nota});

    if (res.statusCode == 400 || res.statusCode == 403) {
      return 'No tienes permiso para editar notas en este periodo.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo guardar: $err';
  }
}

/// Un decimal del backend, o null si no vino.
///
/// Aparte por lo de siempre: estas columnas salen de SQL a pelo y llegan como
/// número o como cadena según el driver. Y aquí la diferencia entre 0 y null
/// importa —una casilla sin nota no es un cero—, así que no vale [decimalO],
/// que devuelve 0 para lo que falta.
double? _decimal(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();

  final crudo = valor.toString().trim().replaceAll(',', '.');
  if (crudo.isEmpty) return null;
  return double.tryParse(crudo);
}
