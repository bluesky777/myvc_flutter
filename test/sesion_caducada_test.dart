import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';

/// El 401 de cualquier petición con token avisa a [Server.alCaducarSesion].
///
/// Lo que haga el aviso —tirar la sesión, volver al login— es de
/// SesionCaducada; aquí se prueba que Server lo dispara cuando toca y solo
/// entonces.
void main() {
  late List<String?> avisos;
  late String antes;

  setUp(() {
    avisos = [];
    antes = Server.urlApi;
    Server.urlApi = 'https://colegio.test/api';
    AuthService.user.token = 'tok';
    Server.alCaducarSesion = avisos.add;
  });

  tearDown(() {
    Server.urlApi = antes;
    Server.alCaducarSesion = null;
    AuthService.limpiar();
  });

  Future<T> con<T>(int codigo, Future<T> Function() pedir) =>
      http.runWithClient(
          pedir,
          () => MockClient((_) async {
                return http.Response('{"error":"Token ha expirado."}', codigo);
              }));

  test('un 401 en get, put, post, delete y subir avisa con el token usado',
      () async {
    await con(401, () => Server().get('/years'));
    await con(401, () => Server().put('/grupos/con-disciplina', {}));
    await con(401, () => Server().post('/notas/lote', {}));
    await con(401, () => Server().delete('/muro/1'));
    await con(401, () => Server().subir('/perfil/foto', [1, 2], 'a.jpg'));

    expect(avisos, ['tok', 'tok', 'tok', 'tok', 'tok']);
  });

  test('la respuesta llega igual a quien la pidió', () async {
    final res = await con(401, () => Server().get('/years'));

    expect(res.statusCode, 401);
  });

  test('403, 400 y 500 no son una sesión caducada', () async {
    await con(403, () => Server().get('/years'));
    await con(400, () => Server().get('/years'));
    await con(500, () => Server().get('/years'));

    expect(avisos, isEmpty);
  });

  test('sin token no hay sesión que cerrar', () async {
    AuthService.limpiar();

    await con(401, () => Server().get('/years'));

    expect(avisos, isEmpty);
  });

  test('el 401 de login/logout no avisa: quien lo llama ya está saliendo',
      () async {
    await con(401, () => Server().put('/login/logout', {}));

    expect(avisos, isEmpty);
  });
}
