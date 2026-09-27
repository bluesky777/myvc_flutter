import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';

/// Una petición que le llegó al servidor de mentira.
class Pedido {
  Pedido(this.metodo, this.ruta, {this.cuerpo, this.nombre, this.campos, this.bytes});

  final String metodo;
  final String ruta;
  final dynamic cuerpo;
  final String? nombre;
  final Map<String, String>? campos;
  final List<int>? bytes;
}

/// Contesta lo que se le diga y apunta lo que se le pidió: aquí lo que se mide
/// es la ruta y el cuerpo, que son el contrato con `routes/api/act.php`.
class ServidorDeActividades extends Server {
  ServidorDeActividades({this.codigo = 200, this.cuerpo = const {}});

  final int codigo;

  /// Un `Map`/`List` se manda como JSON; un `String`, tal cual (HTML, basura).
  final Object cuerpo;

  final List<Pedido> pedidos = [];

  http.Response _responder() => http.Response.bytes(
        utf8.encode(cuerpo is String ? cuerpo as String : jsonEncode(cuerpo)),
        codigo,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  @override
  Future get(String direccion) async {
    pedidos.add(Pedido('GET', direccion));
    return _responder();
  }

  @override
  Future post(String direccion, params) async {
    pedidos.add(Pedido('POST', direccion, cuerpo: params));
    return _responder();
  }

  @override
  Future<http.Response> subirConCampos(String direccion, List<int> bytes,
      String nombreArchivo, Map<String, String> campos) async {
    pedidos.add(Pedido('SUBIR', direccion,
        nombre: nombreArchivo, campos: campos, bytes: bytes));
    return _responder();
  }
}

dynamic _fixture(String nombre) => jsonDecode(
    File('test/fixtures/actividades/$nombre.json').readAsStringSync());

const _dos = [
  RespuestaAct(preguntaId: 11, opcionIds: [19]),
  RespuestaAct(preguntaId: 12, texto: 'seis'),
];

void main() {
  group('las rutas', () {
    test('la bandeja pide la vista de responder', () async {
      final s = ServidorDeActividades(cuerpo: _fixture('bandeja_alumno'));

      final filas = await traerBandejaDeActividades(s);

      expect(s.pedidos.single.ruta, '/act/bandeja?vista=responder');
      expect(filas, hasLength(12));
    });

    test('una bandeja que no es lista es una bandeja vacía', () async {
      final s = ServidorDeActividades(cuerpo: {'raro': true});
      expect(await traerBandejaDeActividades(s), isEmpty);
    });

    test('responder: el alumno no manda alumno_id; el acudiente sí', () async {
      final s = ServidorDeActividades(
          cuerpo: _fixture('responder_encuesta_acudiente'));

      await traerParaResponder(s, 13);
      final act = await traerParaResponder(s, 11, alumnoId: 465);

      expect(s.pedidos.map((p) => p.ruta),
          ['/act/13/responder', '/act/11/responder?alumno_id=465']);
      expect(act.porAlumno!.alumnoId, 465);
    });

    test('mis respuestas, igual', () async {
      final s = ServidorDeActividades(
          cuerpo: _fixture('mis_respuestas_acudiente'));

      await traerMisRespuestas(s, 22);
      await traerMisRespuestas(s, 9, alumnoId: 590);

      expect(s.pedidos.map((p) => p.ruta),
          ['/act/22/mis-respuestas', '/act/9/mis-respuestas?alumno_id=590']);
    });

    test('la campana pide treinta, y marca leído hasta un id', () async {
      final s = ServidorDeActividades(cuerpo: _fixture('avisos_alumno'));

      final avisos = await traerAvisosDeActividades(s);
      await marcarAvisosLeidos(s, avisos.hastaId);

      expect(s.pedidos.first.ruta, '/act/avisos?limite=30');
      expect(s.pedidos.last.metodo, 'POST');
      expect(s.pedidos.last.ruta, '/act/avisos/leidos');
      expect(s.pedidos.last.cuerpo, {'hasta_id': 95});
    });

    test('el archivo vuelve en bytes, sin decodificar', () async {
      final s = ServidorDeActividades(cuerpo: 'JFIF…');
      final bytes = await traerArchivoDeActividad(s, 77);
      expect(s.pedidos.single.ruta, '/act/archivos/77');
      expect(utf8.decode(bytes), 'JFIF…');
    });
  });

  group('los cuerpos', () {
    test('el borrador lleva las respuestas; alumno_id sólo si lo hay',
        () async {
      final s = ServidorDeActividades(
          cuerpo: {'guardado_at': '2026-09-26 18:30:05'});

      final hora = await guardarBorradorDeActividad(s, 13, _dos);
      await guardarBorradorDeActividad(s, 11, _dos.take(1), alumnoId: 465);

      expect(hora, DateTime(2026, 9, 26, 18, 30, 5));
      expect(s.pedidos.first.ruta, '/act/13/borrador');
      expect(s.pedidos.first.cuerpo, {
        'respuestas': [
          {
            'pregunta_id': 11,
            'opcion_ids': [19],
            'texto': null,
            'valor': null,
            'fecha': null,
            'archivo_id': null,
          },
          {
            'pregunta_id': 12,
            'opcion_ids': <int>[],
            'texto': 'seis',
            'valor': null,
            'fecha': null,
            'archivo_id': null,
          },
        ],
      });
      expect(s.pedidos.last.cuerpo['alumno_id'], 465);
    });

    test('enviar devuelve la nota y los intentos que quedan', () async {
      final s = ServidorDeActividades(cuerpo: {
        'nota': 40,
        'puntaje': 8,
        'puntaje_max': 10,
        'quedan_intentos': 0,
      });

      final r = await enviarActividad(s, 13, _dos);

      expect(s.pedidos.single.ruta, '/act/13/enviar');
      expect((s.pedidos.single.cuerpo['respuestas'] as List), hasLength(2));
      expect(r.nota, 40);
      expect(r.quedanIntentos, 0);
    });

    test('entregar manda sólo lo que no es null', () async {
      final s = ServidorDeActividades(
          cuerpo: {'texto': 'hecho', 'entregada_at': '2026-09-26 19:00:00'});

      final e = await entregarTarea(s, 14, texto: 'hecho', fotoId: 5);

      expect(s.pedidos.single.ruta, '/act/14/entregar');
      // Un tipo que la tarea no pide es 422 aunque vaya vacío: por eso ni la
      // clave va.
      expect(s.pedidos.single.cuerpo, {'texto': 'hecho', 'foto_id': 5});
      expect(e.entregada, isTrue);
    });

    test('entregar con preguntas lleva las respuestas', () async {
      final s = ServidorDeActividades(cuerpo: {'entregada_at': null});

      await entregarTarea(s, 28,
          enlace: 'https://drive.google.com/x', respuestas: _dos.take(1));

      final cuerpo = s.pedidos.single.cuerpo as Map;
      expect(cuerpo.keys, ['enlace', 'respuestas']);
      expect((cuerpo['respuestas'] as List).single['pregunta_id'], 11);
    });
  });

  group('la subida', () {
    test('va con clase, alumno y pregunta como campos de texto', () async {
      final s = ServidorDeActividades(cuerpo: {
        'id': 31,
        'clase': 'archivo',
        'nombre_original': 'taller.pdf',
        'mime': 'application/pdf',
        'bytes': 3,
      });

      final a = await subirArchivoDeActividad(s, 7,
          clase: 'archivo',
          bytes: [1, 2, 3],
          nombre: 'taller.pdf',
          alumnoId: 465,
          preguntaId: 3);

      final p = s.pedidos.single;
      expect(p.ruta, '/act/7/archivo');
      expect(p.nombre, 'taller.pdf');
      expect(p.bytes, [1, 2, 3]);
      expect(p.campos, {'clase': 'archivo', 'alumno_id': '465', 'pregunta_id': '3'});
      expect(a.id, 31);
      expect(a.extension, 'PDF');
    });

    test('la foto del alumno sólo lleva la clase', () async {
      final s = ServidorDeActividades(cuerpo: {'id': 1, 'clase': 'foto'});
      await subirArchivoDeActividad(s, 7,
          clase: 'foto', bytes: [1], nombre: 'foto.jpg');
      expect(s.pedidos.single.campos, {'clase': 'foto'});
    });

    test('más de 5 MB no sale del teléfono: se pide un enlace', () async {
      final s = ServidorDeActividades();

      await expectLater(
        subirArchivoDeActividad(s, 7,
            clase: 'archivo',
            bytes: List.filled(topeDeArchivoAct + 1, 0),
            nombre: 'video.mp4'),
        throwsA(isA<MotivoDeActividad>().having(
            (m) => m.mensaje, 'mensaje', contains('pega un enlace'))),
      );
      expect(s.pedidos, isEmpty);
    });

    test('justo 5 MB sí sube', () async {
      final s = ServidorDeActividades(cuerpo: {'id': 2});
      await subirArchivoDeActividad(s, 7,
          clase: 'archivo',
          bytes: List.filled(topeDeArchivoAct, 0),
          nombre: 'grande.pdf');
      expect(s.pedidos, hasLength(1));
      expect(topeDeArchivoAct, 5 * 1024 * 1024);
    });

    test('de verdad: multipart con el archivo en «file» y pidiendo JSON',
        () async {
      // Lo de arriba sobrescribe `subirConCampos`; esto pasa por el `http`
      // de verdad hasta el cable, que es donde un campo mal puesto se ve.
      final antes = Server.urlApi;
      Server.urlApi = 'https://colegio.test/api';
      AuthService.user.token = 'tok';
      addTearDown(() {
        Server.urlApi = antes;
        AuthService.limpiar();
      });

      late http.Request visto;
      await http.runWithClient(
        () => subirArchivoDeActividad(Server(), 7,
            clase: 'foto', bytes: utf8.encode('JPEG'), nombre: 'cuaderno.jpg',
            alumnoId: 465),
        () => MockClient((req) async {
          visto = req;
          return http.Response('{"id": 9, "clase": "foto"}', 200);
        }),
      );

      expect(visto.method, 'POST');
      expect(visto.url.toString(), 'https://colegio.test/api/act/7/archivo');
      expect(visto.headers['Accept'], 'application/json');
      expect(visto.headers['Authorization'], 'Bearer tok');
      expect(visto.headers['content-type'], startsWith('multipart/form-data'));
      final cuerpo = utf8.decode(visto.bodyBytes);
      expect(cuerpo, contains('name="clase"\r\n\r\nfoto'));
      expect(cuerpo, contains('name="alumno_id"\r\n\r\n465'));
      expect(cuerpo, contains('name="file"; filename="cuaderno.jpg"'));
      expect(cuerpo, contains('JPEG'));
    });
  });

  group('cuando el servidor dice que no', () {
    test('el 409 de verdad trae su frase en `message`', () async {
      final s = ServidorDeActividades(codigo: 409, cuerpo: _fixture('error_409'));

      await expectLater(
        enviarActividad(s, 10, _dos),
        throwsA(isA<MotivoDeActividad>()
            .having((m) => m.status, 'status', 409)
            .having((m) => m.mensaje, 'mensaje', 'Esta actividad no está abierta.')),
      );
    });

    test('el 422 de enviar dice qué obligatorias faltan', () async {
      final s = ServidorDeActividades(codigo: 422, cuerpo: {
        'mensaje': 'Faltan preguntas obligatorias.',
        'faltan': [12, '14'],
      });

      await expectLater(
        enviarActividad(s, 13, _dos),
        throwsA(isA<MotivoDeActividad>()
            .having((m) => m.mensaje, 'mensaje', 'Faltan preguntas obligatorias.')
            .having((m) => m.faltan, 'faltan', [12, 14])),
      );
    });

    test('sin frase, una por código', () async {
      Future<String> frase(int codigo) async {
        try {
          await traerParaResponder(
              ServidorDeActividades(codigo: codigo, cuerpo: '<html>'), 1);
        } on MotivoDeActividad catch (m) {
          return m.mensaje;
        }
        return 'no falló';
      }

      expect(await frase(401), 'Tu sesión se cerró. Vuelve a entrar.');
      expect(await frase(403), 'Esta actividad no te toca.');
      expect(await frase(404), 'Esta actividad ya no existe.');
      expect(await frase(409), 'Esta actividad no está abierta.');
      expect(await frase(500),
          'No se pudo abrir la actividad: el servidor respondió 500.');
    });

    test('una traza entera no se le enseña al alumno', () async {
      final s = ServidorDeActividades(
          codigo: 500, cuerpo: {'message': 'SQLSTATE[42S22]\n#0 /app/…'});
      await expectLater(
        traerMisRespuestas(s, 1),
        throwsA(isA<MotivoDeActividad>().having((m) => m.mensaje, 'mensaje',
            'No se pudo traer tus respuestas: el servidor respondió 500.')),
      );
    });

    test('un 200 que no es JSON es una respuesta inesperada', () async {
      final s = ServidorDeActividades(cuerpo: '<!doctype html>');
      await expectLater(
        traerBandejaDeActividades(s),
        throwsA(isA<MotivoDeActividad>().having((m) => m.mensaje, 'mensaje',
            'No se pudo traer tus actividades: respuesta inesperada.')),
      );
    });
  });

  test('act/ pide JSON: sin la cabecera, un abort volvería como HTML', () {
    expect(Server.pideJson('/act/13/enviar'), isTrue);
    expect(Server.pideJson('/act/bandeja?vista=responder'), isTrue);
  });
}
