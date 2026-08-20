import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Las unidades de una asignatura en el periodo, y en qué estado están.
///
/// `detallado` dice de dónde salieron. El listado de asignaturas ya trae las
/// unidades con sus subunidades y con cuántas notas lleva cada una, que es
/// bastante para pintarlas, pero NO trae `nota_default`. Para editar hace falta
/// el detalle, y hasta que se pida esto vale para mirar y no para guardar.
class AsignaturaConUnidades {
  final AsignaturaModel asignatura;
  final List<UnidadModel> unidades;
  final bool detallado;

  AsignaturaConUnidades({
    required this.asignatura,
    this.unidades = const [],
    this.detallado = false,
  });

  AsignaturaConUnidades con({
    List<UnidadModel>? unidades,
    bool? detallado,
  }) {
    return AsignaturaConUnidades(
      asignatura: asignatura,
      unidades: unidades ?? this.unidades,
      detallado: detallado ?? this.detallado,
    );
  }

  /// Cuánto suman las unidades. Tiene que dar 100.
  double get porcentaje =>
      unidades.fold<double>(0, (acc, u) => acc + u.porcentaje);

  bool get cuadra => unidades.isNotEmpty && (porcentaje - 100).abs() < 0.5;

  /// Si alguna unidad tiene sus subunidades mal repartidas.
  bool get subunidadesIncorrectas => unidades.any((u) => !u.subunidadesCuadran);

  /// Si alguna subunidad no tiene ninguna nota puesta todavía.
  ///
  /// No es un error: al empezar el periodo están todas así. Es el aviso que da
  /// la plataforma web para que el docente vea de un vistazo lo que le falta.
  bool get faltanNotas => unidades
      .any((u) => u.subunidades.any((s) => s.cantNotas != null && s.cantNotas == 0));

  /// Cuántas notas tiene cada subunidad, para no perder ese dato al recargar
  /// el detalle, que no lo trae.
  Map<int, int> get notasPorSubunidad {
    final mapa = <int, int>{};
    for (final unidad in unidades) {
      for (final subunidad in unidad.subunidades) {
        if (subunidad.cantNotas != null) mapa[subunidad.id] = subunidad.cantNotas!;
      }
    }
    return mapa;
  }
}

/// Las asignaturas de un docente con sus unidades del periodo en curso.
///
/// `GET asignaturas/listasignaturas[/{profesor_id}]`. Sin id resuelve el
/// docente desde el token, que es el caso normal; con id lo mira un
/// administrativo, y eso solo lo deja pasar el backend a quien no es alumno ni
/// acudiente.
///
/// El periodo no se pide: el backend usa el del usuario, o sea el de la barra
/// de arriba. Es la misma regla que en el resto de la app y por eso cambiar de
/// periodo ahí recarga esta pantalla.
Future<List<AsignaturaConUnidades>> traerAsignaturasConUnidades(
  Server server, {
  int? profesorId,
}) async {
  final ruta = profesorId == null
      ? '/asignaturas/listasignaturas'
      : '/asignaturas/listasignaturas/$profesorId';

  final res = await server.get(ruta);

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  final crudas = (cuerpo is Map ? cuerpo['asignaturas'] : cuerpo) as List? ?? [];

  return crudas.whereType<Map>().map((cruda) {
    final mapa = Map<String, dynamic>.from(cruda);

    return AsignaturaConUnidades(
      asignatura: AsignaturaModel.fromJson(mapa),
      unidades: _unidadesDelResumen(mapa['unidades']),
    );
  }).toList();
}

/// Las unidades tal como vienen dentro del listado de asignaturas.
///
/// El resumen las mete en `unidades.items`, cada una con sus subunidades y con
/// `cantNotas`: cuántas notas lleva puestas esa casilla. Es lo único de todo
/// esto que no vuelve a aparecer en el detalle, y por eso se guarda.
List<UnidadModel> _unidadesDelResumen(dynamic resumen) {
  if (resumen is! Map) return const [];

  final crudas = resumen['items'];
  if (crudas is! List) return const [];

  return crudas
      .whereType<Map>()
      .map((u) => UnidadModel.fromJson(Map<String, dynamic>.from(u)))
      .toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
}

/// Las unidades de una asignatura, con todos sus campos.
///
/// `GET unidades/de-asignatura-periodo/{asignatura_id}/{periodo_id}`, el mismo
/// que abre el editor del front web. Hay que saber que esta lectura ESCRIBE, y
/// no por descuido:
///
///  - Si la asignatura no tiene ninguna unidad en el periodo, el backend crea
///    las del año —`unidades_por_defecto` con sus subunidades— y devuelve esas.
///    Es como el colegio siembra el periodo: abrir la pantalla es lo que las
///    pone.
///  - Y renumera el `orden` de unidades y subunidades de 0 en adelante, porque
///    la plataforma dejaba órdenes repetidos.
///
/// Devuelve cadena vacía cuando no hay unidades y el año tampoco tiene
/// plantilla; ahí no hay nada que leer y se responde con una lista vacía.
Future<List<UnidadModel>> traerUnidadesDe(
  Server server, {
  required int asignaturaId,
  required int periodoId,
  Map<int, int> notasPorSubunidad = const {},
}) async {
  final res =
      await server.get('/unidades/de-asignatura-periodo/$asignaturaId/$periodoId');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! List) return const [];

  return cuerpo
      .whereType<Map>()
      .map((u) => UnidadModel.fromJson(
            Map<String, dynamic>.from(u),
            notasPorSubunidad: notasPorSubunidad,
          ))
      .toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
}

/// Los docentes del colegio, para cuando quien mira no es uno de ellos.
///
/// De /contratos, que es de donde saca los nombres el resto de la app.
Future<List<DocenteModel>> traerDocentesDelColegio(Server server) async {
  final res = await server.get('/contratos');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final crudos = jsonDecode(res.body) as List;

  final docentes = <DocenteModel>[];
  for (final crudo in crudos) {
    if (crudo is! Map) continue;

    final id = int.tryParse('${crudo['profesor_id']}');
    if (id == null) continue;

    docentes.add(DocenteModel(
      profesorId: id,
      nombre: '${crudo['nombre_completo'] ?? 'Docente $id'}'.trim(),
      fotoNombre: crudo['foto_nombre']?.toString(),
    ));
  }

  return docentes..sort((a, b) => a.nombre.compareTo(b.nombre));
}

/// Crea una unidad en el periodo en el que está el usuario.
///
/// `POST unidades`. El periodo no se manda ni se puede elegir: el backend usa
/// el del usuario. Por eso la pantalla enseña arriba con cuál está trabajando.
Future<String?> crearUnidad(
  Server server, {
  required int asignaturaId,
  required String definicion,
  required double porcentaje,
}) async {
  return _guardar(
    () => server.post('/unidades', {
      'asignatura_id': asignaturaId,
      'definicion': definicion,
      'porcentaje': porcentaje,
    }),
    'crear la unidad',
  );
}

/// `PUT unidades/update/{id}`.
///
/// Los tres datos del periodo van aparte del cuerpo que se guarda: con ellos el
/// backend recalcula la definitiva de la asignatura, porque cambiar cuánto pesa
/// una unidad cambia la nota de todos los alumnos del grupo. Sin ellos guarda
/// el porcentaje nuevo y deja las notas calculadas con el viejo.
Future<String?> actualizarUnidad(
  Server server, {
  required int id,
  required String definicion,
  required double porcentaje,
  required int asignaturaId,
  required int periodoId,
  required int numeroPeriodo,
}) async {
  return _guardar(
    () => server.put('/unidades/update/$id', {
      'definicion': definicion,
      'porcentaje': porcentaje,
      'asignatura_id': asignaturaId,
      'periodo_id': periodoId,
      'num_periodo': numeroPeriodo,
    }),
    'guardar la unidad',
  );
}

/// `DELETE unidades/destroy/{id}`, con lo del recálculo en la dirección.
///
/// Un DELETE no lleva cuerpo, y el backend lee `asignatura_id` con
/// `Request::input`, que mira también la query. Ahí van, entonces: si no
/// viajaran, la unidad desaparecería y las definitivas se quedarían calculadas
/// como si siguiera estando.
///
/// Es borrado blando: la unidad queda en la papelera del colegio, con sus
/// subunidades y sus notas, y desde la plataforma web se puede restaurar.
Future<String?> borrarUnidad(
  Server server, {
  required int id,
  required int asignaturaId,
  required int periodoId,
  required int numeroPeriodo,
}) async {
  return _guardar(
    () => server.delete('/unidades/destroy/$id'
        '?asignatura_id=$asignaturaId'
        '&periodo_id=$periodoId'
        '&num_periodo=$numeroPeriodo'),
    'borrar la unidad',
  );
}

/// `POST subunidades`. El orden lo pone el backend al final de la unidad.
Future<String?> crearSubunidad(
  Server server, {
  required int unidadId,
  required String definicion,
  required double porcentaje,
  required double notaDefault,
}) async {
  return _guardar(
    () => server.post('/subunidades', {
      'unidad_id': unidadId,
      'definicion': definicion,
      'porcentaje': porcentaje,
      'nota_default': notaDefault,
    }),
    'crear la subunidad',
  );
}

/// `PUT subunidades/update/{id}`.
///
/// `nota_default` va siempre, aunque no se haya tocado: el backend la reescribe
/// con lo que reciba y la deja en 0 si no recibe nada.
Future<String?> actualizarSubunidad(
  Server server, {
  required int id,
  required String definicion,
  required double porcentaje,
  required double notaDefault,
  required int asignaturaId,
  required int periodoId,
  required int numeroPeriodo,
}) async {
  return _guardar(
    () => server.put('/subunidades/update/$id', {
      'definicion': definicion,
      'porcentaje': porcentaje,
      'nota_default': notaDefault,
      'asignatura_id': asignaturaId,
      'periodo_id': periodoId,
      'num_periodo': numeroPeriodo,
    }),
    'guardar la subunidad',
  );
}

/// `DELETE subunidades/destroy/{id}`, con el recálculo en la dirección.
///
/// Se lleva por delante las notas que colgaban de ella —quedan en la papelera
/// con la subunidad—, así que la pantalla avisa de cuántas son antes.
Future<String?> borrarSubunidad(
  Server server, {
  required int id,
  required int asignaturaId,
  required int periodoId,
  required int numeroPeriodo,
}) async {
  return _guardar(
    () => server.delete('/subunidades/destroy/$id'
        '?asignatura_id=$asignaturaId'
        '&periodo_id=$periodoId'
        '&num_periodo=$numeroPeriodo'),
    'borrar la subunidad',
  );
}

/// Lo que se borró de una asignatura en el periodo y todavía se puede volver.
///
/// El borrado de la plataforma es blando: una unidad borrada sigue en la tabla
/// con su `deleted_at`, con sus subunidades y con las notas que colgaban de
/// ellas. Hasta ahora eso solo se veía desde la web; con esto se ve y se
/// deshace aquí, que es donde se borró.
class PapeleraUnidades {
  /// Unidades borradas enteras, con las subunidades que tenían.
  final List<UnidadModel> unidades;

  /// Subunidades borradas sueltas, de unidades que siguen vivas.
  final List<SubunidadBorrada> subunidades;

  PapeleraUnidades({this.unidades = const [], this.subunidades = const []});

  bool get vacia => unidades.isEmpty && subunidades.isEmpty;

  int get cuantas => unidades.length + subunidades.length;
}

/// Una subunidad borrada, con el nombre de la unidad de la que colgaba.
///
/// Viene de una consulta distinta y con otros nombres de columna
/// —`definicion_subunidad`, `definicion_unidad`—, así que no es un
/// SubunidadModel: fingir que lo es obligaría a que ese modelo entendiera dos
/// formas de llamarse a todo.
class SubunidadBorrada {
  final int id;
  final String definicion;
  final double porcentaje;
  final String unidad;

  SubunidadBorrada({
    required this.id,
    required this.definicion,
    required this.porcentaje,
    required this.unidad,
  });

  factory SubunidadBorrada.fromJson(Map<String, dynamic> json) {
    return SubunidadBorrada(
      id: enteroO(json['id']),
      definicion: '${json['definicion_subunidad'] ?? json['definicion'] ?? ''}',
      porcentaje: decimalO(json['porcentaje']),
      unidad: '${json['definicion_unidad'] ?? ''}',
    );
  }
}

/// La papelera de una asignatura en el periodo del usuario.
///
/// Son dos endpoints, uno por nivel: `PUT unidades/eliminadas/{asignatura_id}`
/// y `PUT subunidades/eliminadas/{asignatura_id}`. Ninguno de los dos recibe el
/// periodo; los dos usan el del usuario.
Future<PapeleraUnidades> traerPapelera(
  Server server, {
  required int asignaturaId,
}) async {
  final resUnidades = await server.put('/unidades/eliminadas/$asignaturaId', {});
  final resSubunidades =
      await server.put('/subunidades/eliminadas/$asignaturaId', {});

  if (resUnidades.statusCode >= 300 || resSubunidades.statusCode >= 300) {
    throw Exception('El servidor respondió ${resUnidades.statusCode}.');
  }

  final unidades = jsonDecode(resUnidades.body);
  final subunidades = jsonDecode(resSubunidades.body);

  return PapeleraUnidades(
    unidades: unidades is Map && unidades['unidades_eliminadas'] is List
        ? (unidades['unidades_eliminadas'] as List)
            .whereType<Map>()
            .map((u) => UnidadModel.fromJson(Map<String, dynamic>.from(u)))
            .toList()
        : const [],
    subunidades: subunidades is Map && subunidades['subunidades'] is List
        ? (subunidades['subunidades'] as List)
            .whereType<Map>()
            .map((s) => SubunidadBorrada.fromJson(Map<String, dynamic>.from(s)))
            .toList()
        : const [],
  );
}

/// `PUT unidades/restore/{id}`. Vuelve con sus subunidades y sus notas.
Future<String?> restaurarUnidad(Server server, {required int id}) {
  return _guardar(
    () => server.put('/unidades/restore/$id', {}),
    'restaurar la unidad',
  );
}

/// `PUT subunidades/restore/{id}`.
Future<String?> restaurarSubunidad(Server server, {required int id}) {
  return _guardar(
    () => server.put('/subunidades/restore/$id', {}),
    'restaurar la subunidad',
  );
}

/// Guarda el orden de las unidades, tal como quedan en la lista.
///
/// `PUT unidades/update-orden`. El backend espera `sortHash`: una lista de
/// objetos de un solo par, `{id: orden}`, que es como se lo manda el arrastrar
/// y soltar del front web. Se mandan todas y no solo las dos que cambiaron:
/// así el orden que queda guardado es exactamente el que se está viendo,
/// aunque el de la base viniera con huecos o repetido, que es lo que había.
Future<String?> reordenarUnidades(
  Server server, {
  required List<int> idsEnOrden,
}) {
  return _guardar(
    () => server.put('/unidades/update-orden', {'sortHash': _sortHash(idsEnOrden)}),
    'cambiar el orden de las unidades',
  );
}

/// `PUT subunidades/update-orden`, con el mismo `sortHash`.
///
/// Solo dentro de una unidad. Mover una subunidad a otra unidad es otro
/// endpoint —`update-orden-varias`— y otra forma de manejarlo.
Future<String?> reordenarSubunidades(
  Server server, {
  required List<int> idsEnOrden,
}) {
  return _guardar(
    () => server.put(
        '/subunidades/update-orden', {'sortHash': _sortHash(idsEnOrden)}),
    'cambiar el orden de las subunidades',
  );
}

/// La lista de ids convertida en lo que espera el backend.
List<Map<String, int>> sortHashDe(List<int> idsEnOrden) => _sortHash(idsEnOrden);

List<Map<String, int>> _sortHash(List<int> idsEnOrden) {
  final orden = <Map<String, int>>[];
  for (var i = 0; i < idsEnOrden.length; i++) {
    orden.add({'${idsEnOrden[i]}': i});
  }
  return orden;
}

/// Lo común a todas las escrituras: null si se guardó, o qué pasó.
///
/// El 400 es el caso que más se da y no es una avería: es el colegio, que tiene
/// cerrada la edición de notas del periodo. [mensajeDeFallo] ya lo dice con
/// esas palabras y se reutiliza para no tener dos redacciones de lo mismo.
Future<String?> _guardar(Future Function() peticion, String accion) async {
  try {
    final res = await peticion();
    if (res.statusCode >= 300) return mensajeDeFallo(res.statusCode, accion);
    return null;
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}
