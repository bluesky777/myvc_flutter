import 'dart:convert';


List<AsistenciaModel> alumnoModelFromJson(String str) =>
    List<AsistenciaModel>.from(
        json.decode(str).map((x) => AsistenciaModel.fromJson(x)));

class AsistenciaModel {
  int id;
  int alumnoId;
  int? asignaturaId;
  int? createdBy;
  DateTime? createdAt;
  int entrada;
  String? fechaHora;
  int periodoId;
  String? tipo;

  /// El día de la tardanza, sacado de `fecha_hora`.
  ///
  /// Antes esto se miraba con `created_at`, que es cuándo se grabó la fila, no
  /// de qué día es la tardanza. Al registrar una de un día pasado, la fila se
  /// creaba hoy y la pantalla la pintaba como de hoy: de ahí la impresión de
  /// que la fecha elegida se ignoraba.
  final DateTime? fecha;


  AsistenciaModel({
    required this.id,
    required this.alumnoId,
    this.asignaturaId,
    this.createdBy,
    this.createdAt,
    required this.entrada,
    this.fechaHora,
    required this.periodoId,
    this.tipo,
    this.fecha,
  });

  /// Si esta tardanza es del día dado, comparando solo año, mes y día.
  bool esDelDia(DateTime dia) {
    if (fecha == null) return false;
    return fecha!.year == dia.year &&
        fecha!.month == dia.month &&
        fecha!.day == dia.day;
  }


  factory AsistenciaModel.fromJson(Map<String, dynamic> parsedJson) {
    final crudo = parsedJson['fecha_hora'];

    return AsistenciaModel(
      fecha: crudo == null ? null : DateTime.tryParse(crudo.toString()),
      id: parsedJson['id'],
      alumnoId: parsedJson['alumno_id'],
      asignaturaId: parsedJson['asignatura_id'],
      createdBy: parsedJson['created_by'] == null ? null : parsedJson['created_by'],
      createdAt: parsedJson['created_at'] == null ? null : DateTime.parse(parsedJson['created_at'].toString()),
      entrada: parsedJson['entrada'],
      fechaHora: parsedJson['fecha_hora'].toString(),
      periodoId: parsedJson['periodo_id'],
      tipo: parsedJson['tipo'] == null ? null : parsedJson['tipo'].toString(),
    );
  }

  @override
  String toString() {
    return '(AsistenciaModel) id: $id - entrada: $entrada - fecha: $fecha - alumnoId: $alumnoId';
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "alumno_id": alumnoId,
        "asignatura_id": asignaturaId,
        "created_by": createdBy,
        "created_at": createdAt == null ? null : createdAt!.toIso8601String(),
        "entrada": entrada,
        "fechaHora": fechaHora,
        "periodoId": periodoId,
        "tipo": tipo,
      };
}
