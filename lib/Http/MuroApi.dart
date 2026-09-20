import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/AsistenciaPeriodoModel.dart';
import 'package:myvc_flutter/Models/PublicacionModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Utils/MuroEnMemoria.dart';
import 'package:myvc_flutter/Utils/VerificacionSesion.dart';

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
/// solicitudes de cambio, nada de lo cual mira esta app. Se usó porque no había
/// otro —`publicaciones/ultimas` es el de la pantalla de login, sin sesión—.
///
/// **Ya hay otro**: `GET muro/app`, escrito el 19 sep 2026 y **sin fundir**.
/// Trae las mismas cinco claves con los mismos nombres y sin el calendario, que
/// es el 99 % de lo que se manda y el 0 % de lo que esta app lee. Por eso
/// cambiar de uno a otro **no toca ni una línea de lo que se lee aquí abajo**:
/// sólo la dirección, detrás de [Interruptores.muroApp].
///
/// Y por eso el camino viejo se queda escrito y funcionando. `app/` es una
/// copia por colegio: hasta que la ruta nueva esté en los diecisiete, encender
/// el interruptor sería gastar un 404 por apertura antes de caer aquí, que es
/// justo la carga que se quiere quitar.
///
/// Ver [docs/backend-pendiente.md](../../docs/backend-pendiente.md) §5.
///
/// **`refrescar` decide si se pregunta o se sirve lo guardado.** Por defecto
/// vale lo de [MuroEnMemoria], que es lo que quieren las tres pantallas que
/// piden el muro solo para saber qué acudidos hay —Mis notas, Mi disciplina y
/// Mi asistencia—. La pantalla del muro pide `refrescar: true` siempre: es la
/// que enseña las publicaciones y no puede enseñarlas viejas.
Future<MuroCargado> traerMuro(Server server, {bool refrescar = false}) async {
  if (!refrescar) {
    final guardado = MuroEnMemoria.instancia.vigente();
    if (guardado != null) return guardado;
  }

  final res = await server.get(
    Interruptores.muroApp ? '/muro/app' : '/ChangesAsked/to-me',
  );

  // El token dejó de valer —le cambiaron la clave, le desactivaron la cuenta—.
  // Se tira el sello de la comprobación para que el próximo arranque sí le
  // pregunte al servidor y mande al login en vez de seguir con una sesión
  // muerta. Es lo que cierra la ventana que abre VerificacionSesion, y por eso
  // va aquí: el muro es la primera petición de casi cualquier arranque.
  if (res.statusCode == 401 || res.statusCode == 403) {
    await VerificacionSesion.olvidar();
  }

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
  // Y con ellas `horario_version_id`, que es lo que dice si el colegio tiene
  // horario publicado. Sin ese segundo dato, `horario_hoy: []` significaba dos
  // cosas a la vez y la app elegía la equivocada. Ver HorarioDeHoy.tomar.
  HorarioDeHoy.instancia.tomar(
    _clasesDeHoy(cuerpo['horario_hoy']),
    versionOficial: entero(cuerpo['horario_version_id']),
  );

  final cargado = MuroCargado(
    publicaciones: _publicaciones(cuerpo['publicaciones']),
    acudidos: leerAcudidos(cuerpo['alumnos']),
    // En la raíz y no dentro de cada alumno, que es la diferencia que hacía
    // que esto no se leyera. Para un acudiente las faltas vienen colgadas de
    // cada acudido —`$alumnos[$i]->ausencias_periodo`— y eso sí se leía; para
    // un alumno vienen sueltas arriba, `'ausencias_periodo' => $ausencias` en
    // la rama `Alumno` de `ChangeAskedController::getToMe()`. Nadie las
    // recogía, así que `asistenciaPropia` era siempre una lista vacía y
    // MiAsistenciaScreen le enseñaba a cada alumno que no ha faltado nunca.
    //
    // El mismo lector que los acudidos, y no uno parecido: las dos ramas del
    // backend llaman a `Ausencia::deAlumnoYear`, o sea que es exactamente la
    // misma forma leída en dos sitios.
    asistenciaPropia: asistenciaPorPeriodo(cuerpo['ausencias_periodo']),
  );

  // Solo se guarda lo que costó una petición. La respuesta que no se entiende
  // —el `cuerpo is! Map` de arriba— se devuelve pero no se cachea: sería
  // guardar cinco minutos de pantalla vacía por un error de una vez.
  MuroEnMemoria.instancia.guardar(cargado);

  return cargado;
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
