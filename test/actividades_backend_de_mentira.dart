import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';

/// El backend de mentira de las pruebas de pantalla de actividades.
///
/// Las pantallas se crean su propio `Server()`, así que no se les puede pasar
/// uno de mentira como en `actividades_api_test.dart`: se cambia el cliente de
/// `http` con [http.runWithClient], que es lo que usa `Server` por debajo. Así
/// pasa todo —cabeceras, JSON, multipart— por el código de verdad.
///
/// Las rutas se escriben como las ve el cliente: `GET /act/bandeja?vista=…`.
class BackendDeActividades {
  final Map<String, http.Response Function(http.Request)> _rutas = {};

  /// Todo lo que se pidió, en orden.
  final List<http.Request> pedidos = [];

  /// Contesta [cuerpo] (un `Map`/`List` en JSON, o un `String` tal cual).
  void cuando(String metodoYRuta, Object cuerpo, {int codigo = 200}) =>
      _rutas[metodoYRuta] = (_) => respuesta(cuerpo, codigo: codigo);

  /// Contesta lo que diga [atender], que ve la petición.
  void cuandoCon(
          String metodoYRuta, http.Response Function(http.Request) atender) =>
      _rutas[metodoYRuta] = atender;

  static http.Response respuesta(Object cuerpo, {int codigo = 200}) =>
      http.Response.bytes(
        cuerpo is List<int>
            ? cuerpo
            : utf8.encode(cuerpo is String ? cuerpo : jsonEncode(cuerpo)),
        codigo,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static const _base = 'https://colegio.test/api';

  String _clave(http.BaseRequest r) =>
      '${r.method} ${r.url.toString().substring(_base.length)}';

  /// Las rutas pedidas, como `GET /act/…`.
  List<String> get rutasPedidas => pedidos.map(_clave).toList();

  /// El cuerpo JSON de la última petición a [metodoYRuta].
  dynamic cuerpoDe(String metodoYRuta) =>
      jsonDecode(pedidos.lastWhere((p) => _clave(p) == metodoYRuta).body);

  late final http.Client cliente = MockClient((req) async {
    pedidos.add(req);
    final atender = _rutas[_clave(req)];
    if (atender == null) {
      return respuesta({'message': 'Sin ruta de mentira: ${_clave(req)}'},
          codigo: 404);
    }
    return atender(req);
  });

  /// Corre [cuerpo] con este backend detrás de `Server`.
  Future<void> con(Future<void> Function() cuerpo) async {
    final antes = Server.urlApi;
    Server.urlApi = _base;
    try {
      await http.runWithClient(cuerpo, () => cliente);
    } finally {
      Server.urlApi = antes;
    }
  }
}

/// Un fixture de `test/fixtures/actividades/`, ya decodificado.
dynamic fixtureAct(String nombre) => jsonDecode(
    File('test/fixtures/actividades/$nombre.json').readAsStringSync());

/// Una copia modificable de un fixture que es un objeto.
Map<String, dynamic> objetoAct(String nombre) =>
    Map<String, dynamic>.from(fixtureAct(nombre) as Map);

/// El alumno o el acudiente de la sesión.
void entrarComo(String tipo, {String nombres = 'TOMÁS ANDRÉS'}) {
  AuthService.user = UserAutenticado(username: 'prueba', tipo: tipo)
    ..nombres = nombres
    ..token = 'tok';
}

/// Un teléfono: las pantallas de actividades están pensadas para él.
void enTelefono(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Una pregunta como la manda `Formas`, con lo mínimo.
Map<String, dynamic> preguntaAct(
  int id,
  String tipo,
  String enunciado, {
  int? orden,
  bool obligatoria = false,
  List<Map<String, dynamic>> opciones = const [],
  List<List<Map<String, dynamic>>> condiciones = const [],
}) =>
    {
      'id': id,
      'orden': orden ?? id,
      'tipo': tipo,
      'enunciado': enunciado,
      'obligatoria': obligatoria,
      'puntos': 1,
      'opcion_otra': false,
      'aleatorias': false,
      'opciones': opciones,
      'condiciones': condiciones,
    };
