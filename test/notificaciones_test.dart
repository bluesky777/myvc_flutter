import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/PreferenciasAvisos.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServidorFingido extends Server {
  ServidorFingido(this.respuesta);

  final http.Response respuesta;
  final List<String> rutas = [];

  @override
  Future get(String direccion) async {
    rutas.add(direccion);
    return respuesta;
  }
}

http.Response conTemas() {
  return http.Response(
    jsonEncode({
      'alumnos': [
        {
          'alumno_id': 31,
          'nombre': 'Dámaris Gómez Pico',
          'temas': {
            'notas': 'a_ab12_notas',
            'asistencia': 'a_ab12_asistencia',
            'disciplina': 'a_ab12_disciplina',
          },
        },
        {
          // Como lo devuelve PDO en el backend: el id, texto.
          'alumno_id': '44',
          'nombre': 'Luis Bolaño Díaz',
          'temas': {
            'notas': 'a_cd34_notas',
            'asistencia': 'a_cd34_asistencia',
            'disciplina': 'a_cd34_disciplina',
          },
        },
      ],
      'colegio': ['colegio_muro', 'colegio_avisos'],
    }),
    200,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PendientesNotificaciones.temasDelColegio = false;
  });

  group('los temas que devuelve el servidor', () {
    test('se leen tal cual, sin derivar nada aquí', () async {
      // **La app no compone los nombres a propósito.** El del alumno es `a_` +
      // HMAC con el secreto del colegio; si se derivara aquí habría dos sitios
      // donde escribirlo mal, y uno no da error: suscribirse a un tema que no
      // existe es válido en FCM, así que el aviso se perdería en silencio.
      final servidor = ServidorFingido(conTemas());

      final temas = await traerTemas(servidor);

      expect(servidor.rutas, ['/notificaciones/temas']);
      expect(temas.alumnos, hasLength(2));
      expect(temas.alumnos.first.temas['notas'], 'a_ab12_notas');
    });

    test('un id que llega como texto se lee igual', () async {
      // Los listados del backend se arman con SQL a pelo y los tipos los decide
      // PDO. Es la trampa que este repo ya tiene catalogada.
      final temas = await traerTemas(ServidorFingido(conTemas()));

      expect(temas.alumnos.last.alumnoId, 44);
    });

    test('los del colegio en la forma vieja: lista de literales', () async {
      // Lo que devuelven los quince HOY. Esos literales son el mismo tema para
      // todos los colegios, que era el fallo: se leen para no romper la lectura
      // y nadie se suscribe, porque el interruptor está apagado.
      final temas = await traerTemas(ServidorFingido(conTemas()));

      expect(temas.delColegio, {
        'colegio_muro': 'colegio_muro',
        'colegio_avisos': 'colegio_avisos',
      });
      expect(PendientesNotificaciones.temasDelColegio, isFalse);
    });

    test('los del colegio en la forma nueva: nombre lógico → tema', () async {
      // Lo que devolverán cuando se despliegue `b369020`. **Las dos formas
      // están vivas a la vez mientras dura un despliegue**, y esto no lleva
      // interruptor a propósito: se lee de la respuesta tal como venga, así que
      // vale antes y después y no hay nada que acordarse de encender.
      final servidor = ServidorFingido(http.Response(
        jsonEncode({
          'alumnos': [],
          'colegio': {
            'colegio_muro': 'c_1a2b3c4d5e6f708192a3b4c5d6e7f809',
            'colegio_avisos': 'c_9f8e7d6c5b4a39281706f5e4d3c2b1a0',
          },
        }),
        200,
      ));

      final temas = await traerTemas(servidor);

      // La clave sigue siendo el nombre lógico, que es lo estable y con lo que
      // se etiqueta la preferencia; el valor es el tema de verdad.
      expect(temas.delColegio['colegio_muro'],
          'c_1a2b3c4d5e6f708192a3b4c5d6e7f809');
      expect(temas.delColegio.keys, ['colegio_muro', 'colegio_avisos']);
    });

    test('los dos temas del colegio no son el mismo', () async {
      // Lo que se rompía: derivados del mismo secreto pero de nombres lógicos
      // distintos, así que tienen que salir distintos.
      final servidor = ServidorFingido(http.Response(
        jsonEncode({
          'alumnos': [],
          'colegio': {'colegio_muro': 'c_aaaa', 'colegio_avisos': 'c_bbbb'},
        }),
        200,
      ));

      final temas = await traerTemas(servidor);

      expect(temas.delColegio.values.toSet(), hasLength(2));
    });

    test('un cuerpo que no es el esperado se dice, no se adivina', () async {
      final servidor = ServidorFingido(http.Response('[]', 200));

      expect(() => traerTemas(servidor), throwsA(isA<Exception>()));
    });

    test('un 503 es el colegio sin configurar, y lo explica el servidor',
        () async {
      // El backend contesta 503 cuando le falta el secreto con el que deriva
      // los temas: sin él, los quince colegios compartirían el tema del alumno
      // 345. Es 503 y no 500 porque no es un fallo del código.
      final servidor = ServidorFingido(http.Response('', 503));

      expect(() => traerTemas(servidor), throwsA(isA<Exception>()));
    });
  });

  group('a qué temas hay que apuntarse', () {
    test('solo los de los tipos encendidos', () async {
      final temas = await traerTemas(ServidorFingido(conTemas()));

      final dosAlumnosUnTipo = temas.temasDe([TipoDeAviso.notas]);

      expect(dosAlumnosUnTipo, ['a_ab12_notas', 'a_cd34_notas']);
    });

    test('al cerrar sesión hay que soltarlos TODOS, no solo los encendidos',
        () async {
      // Si se soltaran solo los encendidos, el teléfono prestado seguiría
      // apuntado a los que la persona anterior había apagado — y bastaría con
      // que la siguiente los encendiera para recibir avisos de un alumno que no
      // es el suyo.
      final temas = await traerTemas(ServidorFingido(conTemas()));

      expect(temas.temasDe(TipoDeAviso.values), hasLength(6));
    });
  });

  group('las preferencias de este teléfono', () {
    test('vienen todas encendidas', () async {
      // Quien instala la app de su colegio quiere enterarse de las notas de su
      // hijo. El interruptor está para el que no, no para buscarlo el día uno.
      expect(await PreferenciasAvisos.encendidos(), TipoDeAviso.values);
    });

    test('apagar una deja las otras', () async {
      await PreferenciasAvisos.setQuiere(TipoDeAviso.disciplina, false);

      expect(await PreferenciasAvisos.quiere(TipoDeAviso.disciplina), isFalse);
      expect(await PreferenciasAvisos.quiere(TipoDeAviso.notas), isTrue);
      expect(
        await PreferenciasAvisos.encendidos(),
        [TipoDeAviso.notas, TipoDeAviso.asistencia],
      );
    });

    test('una clave por tipo, para poder añadir un cuarto sin migrar nada', () {
      expect(PreferenciasAvisos.claveDe(TipoDeAviso.notas), 'avisos_notas');
      expect(
        TipoDeAviso.values.map(PreferenciasAvisos.claveDe).toSet(),
        hasLength(TipoDeAviso.values.length),
      );
    });

    test('la clave del servidor no se traduce: viaja dentro del tema', () {
      // El rótulo es nuestro porque lo lee una familia; la clave es del
      // servidor y cambiarla rompería el nombre del tema.
      expect(TipoDeAviso.notas.clave, 'notas');
      expect(TipoDeAviso.asistencia.clave, 'asistencia');
      expect(TipoDeAviso.disciplina.clave, 'disciplina');
    });
  });
}
