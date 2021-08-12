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
  bool isToday;


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
    this.isToday=false,
  });


  factory AsistenciaModel.fromJson(Map<String, dynamic> parsedJson) {
    bool hoyTemp = false;

    if (parsedJson['created_at'] != null){
      DateTime createdAtTemp = DateTime.parse(parsedJson['created_at']);
      DateTime date = DateTime(createdAtTemp.year, createdAtTemp.month, createdAtTemp.day);
      DateTime hoyTime = DateTime.now();
      DateTime hoy = DateTime(hoyTime.year, hoyTime.month, hoyTime.day);
      hoyTemp = hoy == date;
      if (hoy == date) print('Tiene hoy!');
    }
  
    return AsistenciaModel(
      id: parsedJson['id'],
      alumnoId: parsedJson['alumno_id'],
      asignaturaId: parsedJson['asignatura_id'],
      createdBy: parsedJson['created_by'] == null ? null : parsedJson['created_by'],
      createdAt: parsedJson['created_at'] == null ? null : DateTime.parse(parsedJson['created_at'].toString()),
      entrada: parsedJson['entrada'],
      fechaHora: parsedJson['fecha_hora'].toString(),
      periodoId: parsedJson['periodo_id'],
      tipo: parsedJson['tipo'] == null ? null : parsedJson['tipo'].toString(),
      isToday: hoyTemp,
    );
  }

  @override
  String toString() {
    return '(AsistenciaModel) id: $id - entrada: $entrada - isToday $isToday - alumnoId: $alumnoId - createdAt $createdAt';
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
