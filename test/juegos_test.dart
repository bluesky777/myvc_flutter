import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/JuegosApi.dart';
import 'package:myvc_flutter/Http/Server.dart';

class ServidorDeJuegos extends Server {
  ServidorDeJuegos({this.cuerpo = '{}', this.codigo = 200});

  final String cuerpo;
  final int codigo;
  final List<String> pedidos = [];

  http.Response _contesta(String metodo, String direccion) {
    pedidos.add('$metodo $direccion');
    return http.Response(cuerpo, codigo);
  }

  @override
  Future get(String direccion) async => _contesta('GET', direccion);

  @override
  Future post(String direccion, params) async => _contesta('POST', direccion);

  @override
  Future put(String direccion, params) async => _contesta('PUT', direccion);

  @override
  Future delete(String direccion) async => _contesta('DELETE', direccion);
}

void main() {
  group('la lista y la dirección', () {
    test('los ocho de la web, y sólo Destello vive fuera del colegio', () {
      expect(juegos3D.map((j) => j.id), [
        'carrera',
        'laboratorio',
        'celula',
        'colombia',
        'geometria',
        'escape',
        'cajas',
        'destello',
      ]);
      expect(
        juegos3D.where((j) => j.url != null).map((j) => j.id),
        ['destello'],
      );
    });

    test('u, colegio en #rrggbb y docente sólo para el personal', () {
      const juego = Juego3D(
        id: 'carrera',
        emoji: '',
        titulo: '',
        materia: '',
        texto: '',
        color: Color(0xFF000000),
      );
      expect(
        direccionDelJuego(juego,
            userId: 77, color: const Color(0xFF2E3192), docente: false),
        'carrera/index.html?u=77&colegio=%232e3192',
      );
      expect(
        direccionDelJuego(juego,
            userId: 77, color: const Color(0xFF2E3192), docente: true),
        endsWith('&docente=1'),
      );
    });
  });

  group('el puente: sólo rutas juegos/…', () {
    test('la misma regla que la web', () {
      expect(rutaDeJuegoPermitida('juegos/salas'), isTrue);
      expect(rutaDeJuegoPermitida('juegos/salas/12?x=1'), isTrue);
      expect(rutaDeJuegoPermitida('notas/alumno/3'), isFalse);
      expect(rutaDeJuegoPermitida('juegos/../notas'), isFalse);
      expect(rutaDeJuegoPermitida('/juegos/salas'), isFalse);
    });

    test('una ruta ajena se contesta 400 sin llamar al servidor', () async {
      final servidor = ServidorDeJuegos();
      final r = await llamarPorElJuego(servidor,
          metodo: 'GET', ruta: 'ingles/progreso');
      expect(r.ok, isFalse);
      expect(r.estado, 400);
      expect(servidor.pedidos, isEmpty);
    });

    test('la petición sale con la barra y las fotos vuelven como URL',
        () async {
      Server.urlImages = 'https://colegio.test/images/perfil';
      final servidor = ServidorDeJuegos(
        cuerpo: jsonEncode([
          {'nombre': 'Ana', 'foto': 'user_2/Ana B.jpg', 'docente_foto': null},
          {'nombre': 'Beto', 'foto': 'default_male.png'},
        ]),
      );
      final r =
          await llamarPorElJuego(servidor, metodo: 'get', ruta: 'juegos/salas');

      expect(servidor.pedidos, ['GET /juegos/salas']);
      expect(r.ok, isTrue);
      final filas = r.datos as List;
      expect((filas[0] as Map)['foto'],
          'https://colegio.test/images/perfil/user_2/Ana%20B.jpg');
      expect((filas[0] as Map)['docente_foto'], isNull);
      expect((filas[1] as Map)['foto'], isNull);
    });

    test('un error del servidor llega con su estado y su frase', () async {
      final r = await llamarPorElJuego(
        ServidorDeJuegos(
          codigo: 410,
          cuerpo: jsonEncode({'message': 'La sala ya terminó.'}),
        ),
        metodo: 'GET',
        ruta: 'juegos/salas/9',
      );
      expect(r.ok, isFalse);
      expect(r.estado, 410);
      expect(r.error, 'La sala ya terminó.');
    });
  });
}
