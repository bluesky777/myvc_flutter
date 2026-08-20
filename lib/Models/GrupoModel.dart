// To parse this JSON data, do
//
//     final grupoModel = grupoModelFromJson(jsonString);

import 'dart:convert';

import 'package:myvc_flutter/Utils/JsonBackend.dart';

List<GrupoModel> grupoModelFromJson(String str) {
  return List<GrupoModel>.from(
      json.decode(str).map((x) => GrupoModel.fromJson(x)));
}

String grupoModelToJson(List<GrupoModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class GrupoModel {
  GrupoModel({
    required this.id,
    required this.nombre,
    required this.abrev,
    required this.orden,
    this.nombresTitular,
    this.apellidosTitular,
    this.titularId,
    this.nombreGrado,
  });

  int id;
  String nombre;
  String abrev;
  int orden;
  String? nombresTitular;
  String? apellidosTitular;

  /// El docente titular del grupo, por su `profesor_id`.
  ///
  /// Hace falta para saber qué grupos le tocan a un docente: los de las
  /// asignaturas que da, más aquel del que es titular aunque no le dé ninguna
  /// clase. Sin esto, un titular de preescolar sin asignaturas propias no
  /// vería su propio grupo.
  int? titularId;

  /// «Décimo», «Once»… El nombre largo del grado, para desambiguar dos grupos
  /// que se llaman igual de abreviado.
  String? nombreGrado;

  factory GrupoModel.fromRawJson(String str) =>
      GrupoModel.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  @override
  String toString() => '(GrupoModel) $nombre';

  /// El titular con nombre y apellidos, o null si el grupo no tiene.
  String? get nombreTitular {
    final completo = '${nombresTitular ?? ''} ${apellidosTitular ?? ''}'.trim();
    return completo.isEmpty ? null : completo;
  }

  // Se lee con las ayudas de JsonBackend y no con `json["id"]` a secas: estos
  // listados los arma el backend con SQL a pelo, así que el tipo de cada
  // columna lo decide el driver de PDO y un id puede llegar como cadena.
  factory GrupoModel.fromJson(Map<String, dynamic> json) => GrupoModel(
        id: enteroO(json["id"]),
        nombre: '${json["nombre"] ?? ''}',
        abrev: '${json["abrev"] ?? ''}',
        orden: enteroO(json["orden"]),
        nombresTitular: texto(json["nombres_titular"]),
        apellidosTitular: texto(json["apellidos_titular"]),
        titularId: entero(json["titular_id"]),
        nombreGrado: texto(json["nombre_grado"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "nombre": nombre,
        "abrev": abrev,
        "orden": orden,
        "nombres_titular": nombresTitular,
        "apellidos_titular": apellidosTitular,
        "titular_id": titularId,
        "nombre_grado": nombreGrado,
      };
}
