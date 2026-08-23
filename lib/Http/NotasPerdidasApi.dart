import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Lo que un docente lleva perdido, por grupo, asignatura y alumno.
///
/// Una sola llamada —`PUT notas-perdidas/profesor-grupos`— trae el árbol
/// entero: grupo → asignatura → alumno → notas. **Todo el filtrado que ofrece
/// la pantalla sale de esa respuesta**, sin volver al servidor: el backend ya
/// dejó fuera las notas que aprueban, comparándolas con la
/// `nota_minima_aceptada` del colegio.
///
/// No es barata —recorre todos los grupos del año por cada asignatura del
/// docente y por cada alumno— así que se pide al abrir y se refresca solo
/// tirando hacia abajo.

/// Un grupo con las asignaturas del docente en las que alguien lleva perdido.
class GrupoConPerdidas {
  final int grupoId;
  final String nombre;
  final String abrev;
  final String nombreGrado;
  final List<AsignaturaConPerdidas> asignaturas;

  const GrupoConPerdidas({
    required this.grupoId,
    required this.nombre,
    this.abrev = '',
    this.nombreGrado = '',
    this.asignaturas = const [],
  });

  int get cuantosAlumnos =>
      asignaturas.fold<int>(0, (acc, a) => acc + a.alumnos.length);

  int get cuantasNotas =>
      asignaturas.fold<int>(0, (acc, a) => acc + a.cuantasNotas);

  factory GrupoConPerdidas.fromJson(Map<String, dynamic> json) {
    final crudas = json['asignaturas'];

    return GrupoConPerdidas(
      grupoId: enteroO(json['grupo_id']),
      nombre: '${json['nombre'] ?? ''}',
      abrev: '${json['abrev'] ?? ''}',
      nombreGrado: '${json['nombre_grado'] ?? ''}',
      asignaturas: crudas is List
          ? crudas
              .whereType<Map>()
              .map((a) =>
                  AsignaturaConPerdidas.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
    );
  }

  GrupoConPerdidas con(List<AsignaturaConPerdidas> nuevas) => GrupoConPerdidas(
        grupoId: grupoId,
        nombre: nombre,
        abrev: abrev,
        nombreGrado: nombreGrado,
        asignaturas: nuevas,
      );
}

/// Una asignatura del docente, con los alumnos que llevan algo perdido.
class AsignaturaConPerdidas {
  final int asignaturaId;
  final String materia;
  final String alias;
  final List<AlumnoConPerdidas> alumnos;

  const AsignaturaConPerdidas({
    required this.asignaturaId,
    required this.materia,
    this.alias = '',
    this.alumnos = const [],
  });

  /// Cómo se rotula: el alias si el colegio le puso uno, y si no la materia.
  String get comoSeLlama => alias.trim().isEmpty ? materia : alias;

  int get cuantasNotas =>
      alumnos.fold<int>(0, (acc, a) => acc + a.notas.length);

  factory AsignaturaConPerdidas.fromJson(Map<String, dynamic> json) {
    final crudos = json['alumnos'];

    return AsignaturaConPerdidas(
      asignaturaId: enteroO(json['asignatura_id']),
      materia: '${json['materia'] ?? ''}',
      alias: '${json['alias'] ?? ''}',
      alumnos: crudos is List
          ? crudos
              .whereType<Map>()
              .map((a) => AlumnoConPerdidas.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
    );
  }

  AsignaturaConPerdidas con(List<AlumnoConPerdidas> nuevos) =>
      AsignaturaConPerdidas(
        asignaturaId: asignaturaId,
        materia: materia,
        alias: alias,
        alumnos: nuevos,
      );
}

/// Un alumno con las notas que lleva por debajo de la mínima.
class AlumnoConPerdidas {
  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? fotoNombre;
  final bool nee;
  final List<NotaPerdida> notas;

  const AlumnoConPerdidas({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.fotoNombre,
    this.nee = false,
    this.notas = const [],
  });

  String get nombreEnLista => '$apellidos $nombres'.trim();

  factory AlumnoConPerdidas.fromJson(Map<String, dynamic> json) {
    final crudas = json['notas'];

    // La foto no viene en la fila del alumno —esa consulta solo trae
    // `foto_id`—, sino dentro de `userData`, que además resuelve el archivo por
    // defecto según el sexo. Y cuando el alumno no tiene cuenta de usuario, el
    // backend devuelve ahí `{"": null}` en vez de un objeto vacío: por eso se
    // comprueba que sea un mapa antes de leerlo.
    final datosUsuario = json['userData'];
    final foto = datosUsuario is Map ? texto(datosUsuario['foto_nombre']) : null;

    return AlumnoConPerdidas(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: '${json['apellidos'] ?? ''}',
      fotoNombre: foto,
      nee: entero(json['nee']) == 1,
      notas: crudas is List
          ? (crudas
              .whereType<Map>()
              .map((n) => NotaPerdida.fromJson(Map<String, dynamic>.from(n)))
              .toList()
            ..sort(NotaPerdida.porOrden))
          : const [],
    );
  }

  AlumnoConPerdidas con(List<NotaPerdida> nuevas) => AlumnoConPerdidas(
        alumnoId: alumnoId,
        nombres: nombres,
        apellidos: apellidos,
        fotoNombre: fotoNombre,
        nee: nee,
        notas: nuevas,
      );
}

/// Una nota perdida, con dónde vive: su subunidad, su unidad y su periodo.
class NotaPerdida {
  final int notaId;
  final double? nota;
  final int subunidadId;
  final String definSubunidad;
  final String definUnidad;
  final double porcSubunidad;
  final double porcUnidad;
  final int numeroPeriodo;
  final int ordenUnidad;
  final int ordenSubunidad;

  const NotaPerdida({
    required this.notaId,
    this.nota,
    this.subunidadId = 0,
    this.definSubunidad = '',
    this.definUnidad = '',
    this.porcSubunidad = 0,
    this.porcUnidad = 0,
    this.numeroPeriodo = 0,
    this.ordenUnidad = 0,
    this.ordenSubunidad = 0,
  });

  /// Como se leen: por unidad y dentro de ella por subunidad, que es el orden
  /// en que se pusieron y en que el docente las tiene en la cabeza.
  static int porOrden(NotaPerdida a, NotaPerdida b) {
    final periodo = a.numeroPeriodo.compareTo(b.numeroPeriodo);
    if (periodo != 0) return periodo;

    final unidad = a.ordenUnidad.compareTo(b.ordenUnidad);
    if (unidad != 0) return unidad;

    return a.ordenSubunidad.compareTo(b.ordenSubunidad);
  }

  factory NotaPerdida.fromJson(Map<String, dynamic> json) {
    return NotaPerdida(
      notaId: enteroO(json['nota_id']),
      nota: _decimal(json['nota']),
      subunidadId: enteroO(json['subunidad_id']),
      definSubunidad: '${json['defin_subunidad'] ?? ''}',
      definUnidad: '${json['defin_unidad'] ?? ''}',
      porcSubunidad: _decimal(json['porc_subunidad']) ?? 0,
      porcUnidad: _decimal(json['porc_unidad']) ?? 0,
      numeroPeriodo: enteroO(json['numero_periodo']),
      ordenUnidad: enteroO(json['orden_unidad']),
      ordenSubunidad: enteroO(json['orden_subunidad']),
    );
  }
}

/// Todos los periodos del año, para pedirlos de una vez.
///
/// El backend traduce este número a `p.numero <= :periodo`, así que un 10 —que
/// ningún colegio tiene— significa «todos». Es lo mismo que manda el front web
/// cuando un administrativo elige un docente; para el docente que entra a lo
/// suyo, en cambio, allí se manda el periodo actual y se pierde de vista lo de
/// los periodos anteriores. Aquí se trae el año entero para todos y se estrecha
/// con los chips, que es gratis: ya está en memoria.
const int todosLosPeriodos = 10;

/// Trae el árbol de notas perdidas de un docente.
Future<List<GrupoConPerdidas>> traerNotasPerdidas(
  Server server, {
  required int profesorId,
  int periodoACalcular = todosLosPeriodos,
}) async {
  final res = await server.put('/notas-perdidas/profesor-grupos', {
    'profesor_id': profesorId,
    'periodo_a_calcular': periodoACalcular,
  });

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! List) return const [];

  return cuerpo
      .whereType<Map>()
      .map((g) => GrupoConPerdidas.fromJson(Map<String, dynamic>.from(g)))
      .toList();
}

/// El mismo árbol con solo las notas de un periodo.
///
/// El corte va de abajo arriba: se quedan las notas de ese periodo, y con ellas
/// se caen los alumnos que no tienen ninguna, las asignaturas que se quedan sin
/// alumnos y los grupos que se quedan sin asignaturas. Sin eso, filtrar
/// enseñaría una lista de grupos vacíos, que es peor que no filtrar.
///
/// Con [numeroPeriodo] nulo devuelve el árbol tal cual.
List<GrupoConPerdidas> soloDelPeriodo(
  List<GrupoConPerdidas> grupos,
  int? numeroPeriodo,
) {
  if (numeroPeriodo == null) return grupos;

  final resultado = <GrupoConPerdidas>[];

  for (final grupo in grupos) {
    final asignaturas = <AsignaturaConPerdidas>[];

    for (final asignatura in grupo.asignaturas) {
      final alumnos = <AlumnoConPerdidas>[];

      for (final alumno in asignatura.alumnos) {
        final notas = alumno.notas
            .where((n) => n.numeroPeriodo == numeroPeriodo)
            .toList();

        if (notas.isNotEmpty) alumnos.add(alumno.con(notas));
      }

      if (alumnos.isNotEmpty) asignaturas.add(asignatura.con(alumnos));
    }

    if (asignaturas.isNotEmpty) resultado.add(grupo.con(asignaturas));
  }

  return resultado;
}

/// Los números de periodo que aparecen en el árbol, ordenados.
///
/// Para no ofrecer un chip de un periodo en el que no hay nada perdido: un
/// filtro que siempre deja la lista vacía no es un filtro, es una trampa.
List<int> periodosConPerdidas(List<GrupoConPerdidas> grupos) {
  final numeros = <int>{};

  for (final grupo in grupos) {
    for (final asignatura in grupo.asignaturas) {
      for (final alumno in asignatura.alumnos) {
        for (final nota in alumno.notas) {
          if (nota.numeroPeriodo > 0) numeros.add(nota.numeroPeriodo);
        }
      }
    }
  }

  return numeros.toList()..sort();
}

/// Un decimal del backend, o null si no vino. Ver el de [LibroNotasApi]: aquí
/// también importa que una casilla sin nota no se lea como un cero.
double? _decimal(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();

  final crudo = valor.toString().trim().replaceAll(',', '.');
  if (crudo.isEmpty) return null;
  return double.tryParse(crudo);
}
