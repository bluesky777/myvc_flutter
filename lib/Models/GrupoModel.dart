// To parse this JSON data, do
//
//     final grupoModel = grupoModelFromJson(jsonString);

import 'dart:convert';


List<GrupoModel> grupoModelFromJson(String str) => List<GrupoModel>.from(json.decode(str).map((x) => GrupoModel.fromJson(x)));

String grupoModelToJson(List<GrupoModel> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));


class GrupoModel {
  GrupoModel({
    required this.id,
    required this.nombre,
    required this.abrev,
    required this.orden,
    required this.nombresTitular,
    this.apellidosTitular,
  });

  int id;
  String nombre;
  String abrev;
  int orden;
  String nombresTitular;
  String? apellidosTitular;


  factory GrupoModel.fromRawJson(String str) => GrupoModel.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  String toString() => '(GrupoModel) $nombre';


  factory GrupoModel.fromJson(Map<String, dynamic> json) => GrupoModel(
    id: json["id"],
    nombre: json["nombre"],
    abrev: json["abrev"],
    orden: json["orden"],
    nombresTitular: json["nombres_titular"],
    apellidosTitular: json["apellidos_titular"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "nombre": nombre,
    "abrev": abrev,
    "orden": orden,
    "nombres_titular": nombresTitular,
    "apellidos_titular": apellidosTitular,
  };
}
