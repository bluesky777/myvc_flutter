import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/AsistenciaPeriodoModel.dart';
import 'package:myvc_flutter/Models/PublicacionModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Lo que trae el muro: las publicaciones y, si quien mira es acudiente, sus
/// acudidos.
class MuroCargado {
  final List<PublicacionModel> publicaciones;
  final List<AcudidoModel> acudidos;

  /// Las faltas del propio alumno, cuando quien mira es un alumno.
  ///
  /// Viene en la misma respuesta porque es el único sitio del que un alumno
  /// puede sacarlas: todas las rutas de ausencias están cerradas para alumnos y
  /// acudientes por el middleware ExigirPersonal.
  final List<AsistenciaPeriodoModel> asistenciaPropia;

  MuroCargado({
    required this.publicaciones,
    required this.acudidos,
    this.asistenciaPropia = const [],
  });
}

/// Un alumno a cargo de un acudiente, tal como lo devuelve el muro.
class AcudidoModel {
  final int alumnoId;
  final String nombres;
  final String? apellidos;
  final String? fotoNombre;
  final String? grupo;
  final String? grupoAbrev;

  /// Si está a paz y salvo en tesorería. Cuando no lo está, sus notas van
  /// bloqueadas y hay que decírselo.
  final bool pazYSalvo;

  /// Las faltas del acudido, periodo a periodo.
  final List<AsistenciaPeriodoModel> asistencia;

  AcudidoModel({
    required this.alumnoId,
    required this.nombres,
    this.apellidos,
    this.fotoNombre,
    this.grupo,
    this.grupoAbrev,
    this.pazYSalvo = true,
    this.asistencia = const [],
  });

  String get nombreCompleto => '$nombres ${apellidos ?? ''}'.trim();

  factory AcudidoModel.fromJson(Map<String, dynamic> json) {
    return AcudidoModel(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: texto(json['apellidos']),
      fotoNombre: texto(json['foto_nombre']),
      // `nombre_grupo` primero: así lo llama la consulta de acudidos de
      // ChangesAsked/to-me —`g.nombre as nombre_grupo`—, que es de donde sale
      // esta lista. Leyendo solo `grupo_nombre`, que es como lo llaman otros
      // endpoints, el grupo salía siempre vacío y el cuadro de elegir acudido
      // ponía «Sin grupo» debajo de todos.
      grupo: texto(json['nombre_grupo'] ?? json['grupo_nombre']),
      grupoAbrev: texto(json['grupo_abrev'] ?? json['abrev_grupo']),
      // Viene como 1/0, y a veces sin venir: sin dato se asume que sí, que es
      // lo que hace el front —el aviso rojo solo sale cuando hay un 0—.
      pazYSalvo: entero(json['pazysalvo']) != 0,
      asistencia: asistenciaPorPeriodo(json['ausencias_periodo']),
    );
  }
}

/// Trae el muro del colegio.
///
/// Sale de `GET ChangesAsked/to-me`, que es de donde lo saca también el panel
/// del front web. No es un endpoint del muro: es el cajón de sastre del panel y
/// según el rol trae además historial de sesiones, intentos de login fallidos y
/// solicitudes de cambio, nada de lo cual mira esta app. Se usa igualmente
/// porque no hay otro —`publicaciones/ultimas` es el de la pantalla de login,
/// sin sesión— y el backend no se puede tocar por ahora. El día que se pueda,
/// aquí hay que apuntar a un endpoint que traiga solo esto.
Future<MuroCargado> traerMuro(Server server) async {
  final res = await server.get('/ChangesAsked/to-me');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    return MuroCargado(publicaciones: const [], acudidos: const []);
  }

  // Las clases de hoy viajan en este mismo cajón y no le cuestan una petición
  // a nadie. Se guardan aquí, al leer el muro, para que la pantalla de notas
  // las tenga sin volver a preguntar. Ver HorarioDeHoy.
  HorarioDeHoy.instancia.tomar(_clasesDeHoy(cuerpo['horario_hoy']));

  return MuroCargado(
    publicaciones: _publicaciones(cuerpo['publicaciones']),
    acudidos: leerAcudidos(cuerpo['alumnos']),
  );
}

/// Las asignaturas que el docente dicta hoy, tal como las manda
/// `ChangeAskedController::asignaturas_dia`: cada una con sus unidades y las
/// subunidades de cada unidad.
///
/// Lista vacía cuando la clave no viene, que es lo que pasa con un alumno o un
/// acudiente: no dictan nada, y eso no es un fallo.
List<AsignaturaConUnidades> _clasesDeHoy(dynamic crudas) {
  if (crudas is! List) return const [];

  return crudas.whereType<Map>().map((cruda) {
    final mapa = Map<String, dynamic>.from(cruda);
    final unidades = mapa['unidades'];

    return AsignaturaConUnidades(
      asignatura: AsignaturaModel.fromJson(mapa),
      unidades: unidades is List
          ? (unidades
              .whereType<Map>()
              .map((u) => UnidadModel.fromJson(Map<String, dynamic>.from(u)))
              .toList()
            ..sort((a, b) => a.orden.compareTo(b.orden)))
          : const [],
    );
  }).where((clase) => clase.asignatura.id != 0).toList();
}

List<PublicacionModel> _publicaciones(dynamic crudas) {
  if (crudas is! List) return const [];

  final leidas = <PublicacionModel>[];
  for (final cruda in crudas) {
    if (cruda is! Map) continue;

    // Las eliminadas siguen viniendo, con su deleted_at: el front las pinta
    // tachadas para que su dueño pueda restaurarlas. Aquí no se enseñan.
    if (cruda['deleted_at'] != null) continue;

    final publicacion =
        PublicacionModel.fromJson(Map<String, dynamic>.from(cruda));
    if (publicacion.tieneAlgo) leidas.add(publicacion);
  }
  return leidas;
}

/// Los acudidos que vienen en la clave `alumnos` de `ChangesAsked/to-me`.
///
/// Público porque de ese mismo cajón cuelgan también las faltas de cada
/// acudido, que es lo que lee AsistenciaAlumnoApi: leerlos dos veces con dos
/// criterios distintos era pedir que un día discreparan.
///
/// Ojo: la clave `alumnos` solo trae acudidos cuando quien pregunta es
/// acudiente. Para un alumno el backend mete ahí su propia prematrícula del año
/// siguiente, que no es un acudido de nadie. Por eso quien llama decide, por el
/// rol, si esta lista significa algo.
List<AcudidoModel> leerAcudidos(dynamic crudos) {
  if (crudos is! List) return const [];

  return crudos
      .whereType<Map>()
      .map((a) => AcudidoModel.fromJson(Map<String, dynamic>.from(a)))
      .where((a) => a.alumnoId != 0)
      .toList();
}
