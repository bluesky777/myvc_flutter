class GrupoModel {
  int id;
  String nombre;
  String abrev;
  int orden;
  String nombresTitular;
  List<GrupoModel>? grupos;
  bool isExpanded;

  GrupoModel({
    required this.id,
    required this.nombre,
    required this.abrev,
    required this.nombresTitular,
    required this.orden,
    this.isExpanded=false
  });

  factory GrupoModel.fromJson(Map<String, dynamic> parsedJson) {
    return GrupoModel(
      id: parsedJson['id'],
      nombre: parsedJson['nombre'].toString(),
      abrev: parsedJson['abrev'].toString(),
      nombresTitular: parsedJson['nombres_titular'].toString(),
      orden: parsedJson['orden'],
    );
  }

  @override
  String toString() {
    return '(GrupoModel) $nombre';
  }
}
