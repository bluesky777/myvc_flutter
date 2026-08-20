import 'package:myvc_flutter/Models/OrdinalModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Una situación anotada a un alumno: una fila de `dis_procesos`.
///
/// En la plataforma se les llama «procesos» por dentro y «faltas» o
/// «situaciones» por fuera. Aquí se les llama situaciones, que es como las
/// nombra el manual de convivencia y como las ve el docente.
class SituacionModel {
  final int id;
  final int alumnoId;
  final int periodoId;
  final int yearId;

  /// El número de periodo, del 1 al 4. Lo añade la consulta del backend como
  /// `periodo_numero`; no es una columna de la tabla.
  final int numeroPeriodo;

  /// 1, 2 o 3. Cómo se llama cada uno lo dice `ConfigDisciplinaModel`.
  final int tipo;

  final String descripcion;
  final String? testigos;
  final String? descargo;

  /// El día en que pasó, no cuándo se registró. Puede no venir.
  final DateTime? fecha;

  /// El docente al que se le atribuye, que no tiene por qué ser quien la
  /// anotó. No es obligatorio.
  final int? profesorId;
  final String? profesorNombre;

  /// El usuario que la registró en el sistema, y cuándo. Es un `user_id`, no
  /// un `profesor_id`: para ponerle nombre hay que cruzarlo por `user_id`.
  final int? registradaPor;
  final DateTime? registradaEl;

  /// La situación que absorbió a esta, cuando de varias leves salió una grave.
  ///
  /// Mientras esto no sea nulo, el backend NO la cuenta en `perN_cant_tX`:
  /// ya se contó dentro de la que derivó de ella. Contar la lista en vez de
  /// leer el contador del backend duplicaría esas situaciones.
  final int? absorbidaPor;

  /// Los ids de los ordinales en que incurrió.
  ///
  /// Salen de `proceso_ordinales`, que es la tabla PIVOTE, y de su columna
  /// `ordinal_id` — NO de su `id`, que es el de la fila pivote. Son dos
  /// numeraciones distintas que solo coinciden por casualidad, y confundirlas
  /// deja la lista de ordinales vacía al abrir una situación ya guardada.
  final List<int> ordinalIds;

  SituacionModel({
    required this.id,
    this.alumnoId = 0,
    this.periodoId = 0,
    this.yearId = 0,
    this.numeroPeriodo = 0,
    this.tipo = 1,
    this.descripcion = '',
    this.testigos,
    this.descargo,
    this.fecha,
    this.profesorId,
    this.profesorNombre,
    this.registradaPor,
    this.registradaEl,
    this.absorbidaPor,
    this.ordinalIds = const [],
  });

  factory SituacionModel.fromJson(Map<String, dynamic> json) {
    return SituacionModel(
      id: enteroO(json['id']),
      alumnoId: enteroO(json['alumno_id']),
      periodoId: enteroO(json['periodo_id']),
      yearId: enteroO(json['year_id']),
      numeroPeriodo: enteroO(json['periodo_numero']),
      tipo: entero(json['tipo_situacion']) ?? 1,
      descripcion: '${json['descripcion'] ?? ''}'.trim(),
      testigos: texto(json['testigos']),
      descargo: texto(json['descargo']),
      fecha: _fecha(json['fecha_hora_aprox']),
      profesorId: entero(json['profesor_id']),
      profesorNombre: _nombreDocente(json['profesor_nombre']),
      registradaPor: entero(json['added_by']),
      registradaEl: _fecha(json['created_at']),
      absorbidaPor: entero(json['become_id']),
      ordinalIds: _ordinales(json['proceso_ordinales']),
    );
  }

  /// Una fecha de MySQL, que viene como 'Y-m-d H:i:s'.
  ///
  /// `DateTime.tryParse` la entiende: acepta el espacio donde el ISO lleva la
  /// T. Lo que no acepta es la cadena vacía ni el '0000-00-00' que dejaron
  /// algunas filas viejas, y para esas devuelve null, que es lo correcto: no
  /// se sabe qué día fue.
  static DateTime? _fecha(dynamic crudo) {
    final valor = texto(crudo);
    if (valor == null) return null;

    final fecha = DateTime.tryParse(valor);
    if (fecha == null || fecha.year < 1900) return null;

    return fecha;
  }

  /// El nombre del docente que arma el backend con CONCAT.
  ///
  /// Cuando la situación no tiene profesor, el LEFT JOIN no encuentra fila y
  /// CONCAT devuelve null; pero cuando lo tiene a medias —un profesor sin
  /// apellidos— devuelve un nombre con un espacio suelto al final. Se recorta,
  /// y si no queda nada es que no hay nombre.
  static String? _nombreDocente(dynamic crudo) {
    final nombre = texto(crudo)?.trim();
    return (nombre == null || nombre.isEmpty) ? null : nombre;
  }

  static List<int> _ordinales(dynamic crudos) {
    if (crudos is! List) return const [];

    final ids = <int>[];
    for (final crudo in crudos) {
      if (crudo is! Map) continue;

      // `ordinal_id`, no `id`. Ver el comentario del campo.
      final id = entero(crudo['ordinal_id']);
      if (id != null && id != 0) ids.add(id);
    }
    return ids;
  }

  /// Si esta situación ya fue absorbida por otra que derivó de ella.
  bool get absorbida => absorbidaPor != null;

  /// Los ordinales con su texto, cruzados contra el catálogo del año.
  ///
  /// La tabla pivote solo guarda ids: ni el número del ordinal ni su
  /// descripción viajan con la situación. El catálogo entero ya está en
  /// memoria desde que se abrió la pantalla, así que se cruza aquí en vez de
  /// pedirle otra consulta al backend.
  List<OrdinalModel> ordinalesDe(List<OrdinalModel> catalogo) {
    if (ordinalIds.isEmpty) return const [];

    final porId = {for (final ordinal in catalogo) ordinal.id: ordinal};

    final resueltos = <OrdinalModel>[];
    for (final id in ordinalIds) {
      final ordinal = porId[id];
      if (ordinal != null) resueltos.add(ordinal);
    }
    return resueltos;
  }

  @override
  String toString() =>
      '(SituacionModel) $id tipo $tipo - $descripcion';
}
