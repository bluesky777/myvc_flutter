class GrupoModel {
  int id;
  String nombre;
  String abrev;
  int orden;
  String nombres_titular;
  List<GrupoModel>? grupos;
  bool is_expanded;

  GrupoModel({
    required this.id,
    required this.nombre,
    required this.abrev,
    required this.nombres_titular,
    required this.orden,
    this.is_expanded=false
  });

  factory GrupoModel.fromJson(Map<String, dynamic> parsedJson) {
    return GrupoModel(
      id: parsedJson['id'],
      nombre: parsedJson['nombre'].toString(),
      abrev: parsedJson['abrev'].toString(),
      nombres_titular: parsedJson['nombres_titular'].toString(),
      orden: parsedJson['orden'],
    );
  }
}
