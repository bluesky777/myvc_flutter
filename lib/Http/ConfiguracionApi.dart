import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';

/// Cómo está configurado el colegio, y los siete ajustes que se pueden mover
/// desde el teléfono.
///
/// **Una sola petición lo trae todo.** `GET years/colegio` devuelve los años
/// con sus periodos y sus escalas de valoración dentro, así que no hacen falta
/// las tres consultas que el plan suponía: los `GET periodos/show/{year}` y
/// `GET escalas` sobran.
///
/// Los cambios son un `PUT` diminuto por interruptor, y se mandan al tocarlos.
/// Un botón «Guardar» general aquí solo añadiría un paso y la duda de si quedó
/// guardado.
///
/// **La restricción a administradores es de la app, no del servidor.** Todas
/// estas rutas llevan `auth.personal`, que solo cierra la puerta a alumnos y
/// acudientes: un docente podría llamarlas. Es alcance, no permiso, y conviene
/// decirlo así.

/// Trae los años del colegio con su configuración, sus periodos y sus escalas.
Future<List<YearDelColegio>> traerColegio(Server server) async {
  final res = await server.get('/years/colegio');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió la configuración del colegio.');
  }

  final years = cuerpo['years'];
  if (years is! List) return const [];

  return years
      .whereType<Map>()
      .map((y) => YearDelColegio.fromJson(Map<String, dynamic>.from(y)))
      .where((y) => y.id != 0)
      .toList()
    // El más reciente primero: es el que se mira.
    ..sort((a, b) => b.year.compareTo(a.year));
}

/// Si alumnos y acudientes pueden ver sus notas. Null si entró, o el motivo.
Future<String?> cambiarAlumnosPuedenVerNotas(
  Server server, {
  required int yearId,
  required bool pueden,
}) {
  return _put(
    server,
    ruta: '/years/alumnos-can-see-notas',
    cuerpo: {'year_id': yearId, 'can': pueden},
    accion: 'cambiar si los alumnos ven sus notas',
  );
}

/// Si los alumnos ven números en sus notas o solo el desempeño.
///
/// **La columna del backend dice lo contrario que este parámetro.** Se llama
/// `solo_escalas_valorativas` y en 1 significa «sin números», así que aquí se
/// invierte: la pantalla pregunta si los ven, que es como se piensa el ajuste,
/// y lo que viaja es lo que el backend espera.
Future<String?> cambiarAlumnosVenNumeros(
  Server server, {
  required int yearId,
  required bool ven,
}) {
  return _put(
    server,
    ruta: '/years/toggle-solo-valorativas',
    cuerpo: {'year_id': yearId, 'can': !ven},
    accion: 'cambiar si se ven los números',
  );
}

/// Si al docente se le enseñan todas sus materias ignorando el horario.
Future<String?> cambiarMostrarTodasLasMaterias(
  Server server, {
  required int yearId,
  required bool mostrar,
}) {
  return _put(
    server,
    ruta: '/years/mostrar-todas-materias',
    cuerpo: {'year_id': yearId, 'can': mostrar},
    accion: 'cambiar el filtro de materias',
  );
}

/// Si los docentes pueden editar notas en ese periodo. Es el cierre del
/// periodo.
Future<String?> cambiarPuedenEditarNotas(
  Server server, {
  required int periodoId,
  required bool pueden,
}) {
  return _put(
    server,
    ruta: '/periodos/toggle-profes-pueden-editar-notas',
    // Como 1 y 0 y no como true/false: el backend lo asigna tal cual a una
    // columna tinyint, sin castear, al revés que los de `years`, que sí hacen
    // `(bool)`.
    cuerpo: {'periodo_id': periodoId, 'pueden': pueden ? 1 : 0},
    accion: 'abrir o cerrar la edición de notas',
  );
}

/// Si los docentes pueden nivelar las definitivas de ese periodo.
Future<String?> cambiarPuedenNivelar(
  Server server, {
  required int periodoId,
  required bool pueden,
}) {
  return _put(
    server,
    ruta: '/periodos/toggle-profes-pueden-nivelar',
    cuerpo: {'periodo_id': periodoId, 'pueden': pueden ? 1 : 0},
    accion: 'abrir o cerrar la nivelación',
  );
}

/// Cambia la fecha de inicio o la de fin de un periodo.
Future<String?> cambiarFechaDelPeriodo(
  Server server, {
  required int periodoId,
  required DateTime fecha,
  required bool esElInicio,
}) {
  return _put(
    server,
    ruta: esElInicio
        ? '/periodos/cambiar-fecha-inicio'
        : '/periodos/cambiar-fecha-fin',
    // Solo el día: el backend hace `Carbon::parse` de lo que reciba, y una
    // hora dentro de la fecha de un periodo no significa nada.
    cuerpo: {
      'periodo_id': periodoId,
      'fecha': fecha.toIso8601String().split('T').first,
    },
    accion: 'cambiar la fecha del periodo',
  );
}

/// Pone ese periodo como el actual **del colegio**.
///
/// No confundir con `periodos/useractive`, que es en qué periodo está mirando
/// una persona. Esto cambia el periodo de todos, y de él cuelgan las notas que
/// se escriben, los boletines y los informes.
///
/// El backend apaga los demás periodos del año antes de encender este, así que
/// quien lo llame tiene que reflejar las dos mitades: ver
/// [YearDelColegio.conActual].
Future<String?> establecerPeriodoActual(
  Server server, {
  required int periodoId,
}) {
  return _put(
    server,
    ruta: '/periodos/establecer-actual/$periodoId',
    cuerpo: const {},
    accion: 'cambiar el periodo del colegio',
  );
}

Future<String?> _put(
  Server server, {
  required String ruta,
  required Map<String, dynamic> cuerpo,
  required String accion,
}) async {
  try {
    final res = await server.put(ruta, cuerpo);

    if (res.statusCode == 400 || res.statusCode == 401 ||
        res.statusCode == 403) {
      return 'No tienes permiso para $accion.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}
