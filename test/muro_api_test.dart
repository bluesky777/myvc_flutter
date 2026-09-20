import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/MuroEnMemoria.dart';
import 'package:myvc_flutter/Utils/VerificacionSesion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cuenta cuántas veces se le pregunta, que es justo lo que estas pruebas
/// miden: el problema no es lo que devuelve el muro, es cuántas veces se pide.
class ServidorQueCuenta extends Server {
  ServidorQueCuenta({this.codigo = 200, this.cuerpo});

  final int codigo;

  /// El cuerpo, cuando la prueba necesita uno concreto. Por defecto, un muro
  /// con un acudido, que es lo que basta para contar peticiones.
  final Map<String, dynamic>? cuerpo;

  int veces = 0;

  /// A qué direcciones se le preguntó, en orden.
  final List<String> direcciones = [];

  @override
  Future get(String direccion) async {
    veces++;
    direcciones.add(direccion);
    return http.Response(
      jsonEncode(cuerpo ??
          {
            'publicaciones': [],
            'alumnos': [
              {
                'alumno_id': 31,
                'nombres': 'Dámaris',
                'nombre_grupo': 'Séptimo A',
              },
            ],
          }),
      codigo,
    );
  }
}

void main() {
  group('los acudidos de un acudiente', () {
    test('se leen con su grupo y su paz y salvo', () {
      final acudido = AcudidoModel.fromJson({
        'alumno_id': '31',
        'nombres': 'Dámaris',
        'apellidos': 'Gómez Pico',
        'foto_nombre': 'user_2/damaris.jpg',
        'grupo_nombre': 'Séptimo A',
        'grupo_abrev': '7A',
        'pazysalvo': 0,
      });

      expect(acudido.alumnoId, 31);
      expect(acudido.nombreCompleto, 'Dámaris Gómez Pico');
      expect(acudido.grupoAbrev, '7A');
      expect(acudido.pazYSalvo, isFalse);
    });

    test('el grupo se lee como lo nombra el panel', () {
      // La consulta de acudidos de ChangesAsked/to-me devuelve `nombre_grupo`,
      // no `grupo_nombre`: leyendo solo el segundo, el grupo era null siempre.
      final acudido = AcudidoModel.fromJson({
        'alumno_id': 31,
        'nombres': 'Dámaris',
        'nombre_grupo': 'Séptimo A',
      });

      expect(acudido.grupo, 'Séptimo A');
    });

    test('sin el dato de tesorería se asume que está a paz y salvo', () {
      // Es lo que hace el front: el aviso rojo solo sale cuando llega un 0.
      final acudido = AcudidoModel.fromJson({'alumno_id': 4, 'nombres': 'X'});

      expect(acudido.pazYSalvo, isTrue);
    });
  });

  group('el muro no se pide cuatro veces seguidas', () {
    // La razón entera está en MuroEnMemoria: `GET ChangesAsked/to-me` recorre a
    // los acudidos uno a uno lanzando seis consultas por cada uno, y lo pedían
    // cuatro pantallas en la misma visita.
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MuroEnMemoria.instancia.limpiar();
    });

    test('la segunda pantalla se sirve de lo guardado', () async {
      final server = ServidorQueCuenta();

      await traerMuro(server);
      final segunda = await traerMuro(server);

      expect(server.veces, 1, reason: 'la segunda no debía preguntar');
      expect(segunda.acudidos.single.nombres, 'Dámaris');
    });

    test('refrescar pregunta siempre, aunque haya algo guardado', () async {
      // Es lo que hace la pantalla del muro y lo que hace deslizar para
      // recargar: si esto se rompe, el muro enseña publicaciones viejas.
      final server = ServidorQueCuenta();

      await traerMuro(server);
      await traerMuro(server, refrescar: true);

      expect(server.veces, 2);
    });

    test('pasados los cinco minutos se vuelve a preguntar', () async {
      final server = ServidorQueCuenta();

      await traerMuro(server);
      MuroEnMemoria.instancia.guardar(
        MuroEnMemoria.instancia.vigente()!,
        cuando: DateTime.now().subtract(MuroEnMemoria.vigencia * 2),
      );

      expect(MuroEnMemoria.instancia.vigente(), isNull);

      await traerMuro(server);
      expect(server.veces, 2);
    });

    test('cerrar sesión no deja los acudidos del anterior', () async {
      // Son los nombres y las fotos de los hijos de quien se va. En un teléfono
      // prestado, el siguiente no tiene por qué verlos.
      final server = ServidorQueCuenta();
      await traerMuro(server);

      MuroEnMemoria.instancia.limpiar();

      expect(MuroEnMemoria.instancia.vigente(), isNull);
      await traerMuro(server);
      expect(server.veces, 2);
    });

    test('un 401 tira el sello de la comprobación', () async {
      // Es lo que cierra sola la ventana que abre VerificacionSesion: el
      // próximo arranque sí pregunta, y sí manda al login.
      await VerificacionSesion.sellar();
      expect(await VerificacionSesion.hayQueComprobar(), isFalse);

      final server = ServidorQueCuenta(codigo: 401);

      await expectLater(traerMuro(server), throwsA(isA<Exception>()));
      expect(await VerificacionSesion.hayQueComprobar(), isTrue);
    });

    test('lo que falló no se queda guardado', () async {
      final server = ServidorQueCuenta(codigo: 500);

      await expectLater(traerMuro(server), throwsA(isA<Exception>()));

      expect(MuroEnMemoria.instancia.vigente(), isNull);
    });
  });

  group('las faltas del propio alumno', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MuroEnMemoria.instancia.limpiar();
    });

    test('vienen en la raíz, no dentro de cada alumno', () async {
      // La rama `Alumno` de ChangeAskedController::getToMe() devuelve
      // `'ausencias_periodo' => $ausencias` arriba del todo, mientras que la del
      // acudiente las cuelga de cada acudido. La app solo leía la segunda, así
      // que `asistenciaPropia` era siempre una lista vacía y MiAsistenciaScreen
      // le decía a cada alumno que no ha faltado nunca.
      final server = ServidorQueCuenta(cuerpo: {
        'publicaciones': [],
        'alumnos': [],
        'ausencias_periodo': [
          {
            'id': 7,
            'numero': 2,
            'asistencia': {
              'cant_tardanzas_entrada': 3,
              'cant_ausencias_entrada': 1,
              'cant_tardanzas_clases': 0,
              'cant_ausencias_clases': 4,
            },
          },
          {
            'id': 6,
            'numero': 1,
            // Sin ni una falta el backend manda el array de ceros, no un objeto.
            'asistencia': [],
          },
        ],
      });

      final muro = await traerMuro(server);

      expect(muro.asistenciaPropia, hasLength(2));
      // Ordenados por número de periodo, como los del acudiente.
      expect(muro.asistenciaPropia.first.numero, 1);
      expect(muro.asistenciaPropia.first.sinNada, isTrue);

      final segundo = muro.asistenciaPropia.last;
      expect(segundo.tardanzasInstitucion, 3);
      expect(segundo.ausenciasClases, 4);
      expect(segundo.totalInstitucion, 4);
    });

    test('un acudiente no trae la clave, y eso no es un fallo', () async {
      // A él las faltas le llegan por acudido. La lista vacía aquí es correcta.
      final server = ServidorQueCuenta();

      final muro = await traerMuro(server);

      expect(muro.asistenciaPropia, isEmpty);
    });
  });
  group('de qué endpoint sale el muro', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MuroEnMemoria.instancia.limpiar();
      HorarioDeHoy.instancia.limpiar();
    });

    test('apagado se pide al cajón de sastre del panel', () async {
      final servidor = ServidorQueCuenta();
      await traerMuro(servidor, refrescar: true);

      // El interruptor está apagado y así tiene que seguir mientras
      // `muro/app` no esté desplegado en los diecisiete.
      expect(Interruptores.muroApp, isFalse);
      expect(servidor.direcciones, ['/ChangesAsked/to-me']);
    });

    test('la respuesta nueva se lee con el mismo lector, clave por clave',
        () async {
      // **Es la prueba que hace barato encender el interruptor**: `muro/app`
      // devuelve un subconjunto de `to-me` con los mismos nombres, así que lo
      // que hay que comprobar no es la ruta sino que las cinco claves se
      // siguen leyendo igual. Si esto pasa, cambiar la dirección no puede
      // romper nada.
      final servidor = ServidorQueCuenta(cuerpo: {
        'publicaciones': [],
        'alumnos': [
          {
            'alumno_id': 31,
            'nombres': 'Dámaris',
            'apellidos': 'Gómez Pico',
            'nombre_grupo': 'Séptimo A',
            'grupo_abrev': '7A',
            'pazysalvo': 0,
            'ausencias_periodo': [
              {'periodo': 1, 'ausencias': 2, 'tardanzas': 1},
            ],
          },
        ],
        'horario_hoy': [],
        'horario_version_id': 12,
        'ausencias_periodo': [
          {'periodo': 1, 'ausencias': 3, 'tardanzas': 0},
        ],
      });

      final muro = await traerMuro(servidor, refrescar: true);

      expect(muro.acudidos.single.grupoAbrev, '7A');
      expect(muro.acudidos.single.pazYSalvo, isFalse);
      expect(muro.acudidos.single.asistencia, hasLength(1));
      expect(muro.asistenciaPropia, hasLength(1));
      // Con `horario_version_id` presente sí se sabe, aunque no haya clases.
      expect(HorarioDeHoy.instancia.seSabe, isTrue);
      expect(HorarioDeHoy.instancia.cuantas, 0);
    });

    test('a un Profesor le llegan las dos claves del horario y se sabe',
        () async {
      final servidor = ServidorQueCuenta(cuerpo: {
        'publicaciones': [],
        'horario_hoy': [],
        'horario_version_id': 7,
      });

      await traerMuro(servidor, refrescar: true);

      expect(HorarioDeHoy.instancia.seSabe, isTrue);
    });

    test('sin horario_version_id NO se sabe, y eso no es «no tienes clases»',
        () async {
      // La sesión del backend lo contó al revés al escribir `muro/app` —dijo
      // que `seSabe` volvería a valer true con cero clases, o sea el mensaje
      // falso de agosto— y lo corrigió. Aquí queda atado por si vuelve: sin la
      // clave, la app **no dice nada**, que es el fallo barato y silencioso.
      final servidor = ServidorQueCuenta(cuerpo: {
        'publicaciones': [],
        'horario_hoy': [],
      });

      await traerMuro(servidor, refrescar: true);

      expect(HorarioDeHoy.instancia.seSabe, isFalse);
    });

    test('a un Alumno no le llega horario_hoy, y eso no es un fallo', () async {
      // Igual que hoy en `to-me`. Dárselo sería una decisión de producto y una
      // ruta que se estrena para ahorrar peso no es donde se toma.
      final servidor = ServidorQueCuenta(cuerpo: {
        'publicaciones': [],
        'ausencias_periodo': [
          {'periodo': 1, 'ausencias': 3, 'tardanzas': 0},
        ],
      });

      final muro = await traerMuro(servidor, refrescar: true);

      expect(muro.asistenciaPropia, hasLength(1));
      expect(HorarioDeHoy.instancia.seSabe, isFalse);
    });
  });
}
