
import 'dart:convert';

import 'package:flutter/material.dart';

List<UserModel> userModelFromJson(String str) => List<UserModel>.from(
    json.decode(str).map((x) => UserModel.fromJson(x)));

class UserModel extends ChangeNotifier {
  int userId;
  String username;
  String sexo;
  int? isActive;
  int year;
  int periodo;
  String? imageNombre;


  UserModel({
    required this.userId,
    required this.username,
    required this.sexo,
    this.isActive,
    required this.year,
    required this.periodo,
    this.imageNombre,
  });


  factory UserModel.fromJson(Map<String, dynamic> parsedJson) {

    return UserModel(
      userId: parsedJson['user_id'],
      username: parsedJson['username'].toString(),
      sexo: parsedJson['sexo'].toString(),
      year: parsedJson['year'],
      periodo: parsedJson['periodo'],
      imageNombre: parsedJson['image_nombre'] == null
          ? null
          : parsedJson['image_nombre'].toString(),
    );
  }

  @override
  String toString() {
    return '(GrupoModel) $username - $userId';
  }

  Map<String, dynamic> toJson() => {
    "userId": userId,
    "username": username,
    "imageNombre": imageNombre,
    "sexo": sexo,
    "year": year,
    "periodo": periodo,
  };
}
