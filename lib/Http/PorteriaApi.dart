import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PorteriaModel.dart';

/// La portería: `routes/api/tardanzas.php` del backend, `PorteriaController`.
///
/// Todas contestan JSON —`/porteria/` está en [Server.rutasQueContestanJson]—,
/// así que el error trae la frase del servidor en `message` y se enseña tal
/// cual: «Ese alumno no está matriculado este año» dice más que un 422.

/// Los alumnos del año actual, y las tardanzas y novedades que ya hay hoy.
/// `GET porteria/alumnos`.
Future<ListaDePorteria> traerPorteria(Server server) async {
  final http.Response res = await server.get('/porteria/alumnos');

  if (res.statusCode != 200) {
    throw Exception(_frase(res, 'traer los alumnos'));
  }

  final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;

  return ListaDePorteria(
    alumnos: [
      for (final a in (cuerpo['alumnos'] as List? ?? const []))
        AlumnoDePorteria.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
    tardanzasHoy: [
      for (final t in (cuerpo['tardanzas_hoy'] as List? ?? const []))
        TardanzaDeHoy.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
    novedadesHoy: [
      for (final n in (cuerpo['novedades_hoy'] as List? ?? const []))
        NovedadDeHoy.fromJson(Map<String, dynamic>.from(n as Map)),
    ],
  );
}

/// Pone la tardanza de hoy. Va [codigo] (lo que leyó la cámara) o [alumnoId]
/// (lo que se eligió en el buscador). `POST porteria/tardanza`.
///
/// Si ya tenía tardanza hoy el servidor no pone otra: devuelve la que hay, con
/// `ya_tenia`.
Future<ResultadoDelCarne> ponerTardanza(
  Server server, {
  String? codigo,
  int? alumnoId,
}) async {
  try {
    final http.Response res = await server.post('/porteria/tardanza', {
      if (codigo != null) 'codigo': codigo,
      if (alumnoId != null) 'alumno_id': alumnoId,
    });

    final otro = _sinAlumno(res, codigo, 'poner la tardanza');
    if (otro != null) return otro;

    final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;

    return ResultadoDelCarne.puesta(
      AlumnoDePorteria.fromJson(Map<String, dynamic>.from(cuerpo['alumno'] as Map)),
      TardanzaDeHoy.fromJson(Map<String, dynamic>.from(cuerpo['tardanza'] as Map)),
      cuerpo['ya_tenia'] == true,
      novedades: _novedades(cuerpo),
      uniforme: ConteoUniforme.fromJson(cuerpo['uniforme']),
    );
  } catch (err) {
    return ResultadoDelCarne.mal('No se pudo poner la tardanza: $err');
  }
}

/// «Sólo novedad»: lee el carné (o el alumno del buscador) SIN poner
/// tardanza. `POST porteria/leer`, con los mismos [codigo] o [alumnoId] y los
/// mismos 404 y 410 que [ponerTardanza], así que «¿De quién es este carné?»
/// sirve igual.
Future<ResultadoDelCarne> leerCarne(
  Server server, {
  String? codigo,
  int? alumnoId,
}) async {
  try {
    final http.Response res = await server.post('/porteria/leer', {
      if (codigo != null) 'codigo': codigo,
      if (alumnoId != null) 'alumno_id': alumnoId,
    });

    final otro = _sinAlumno(res, codigo, 'leer el carné');
    if (otro != null) return otro;

    final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;
    final tardanza = cuerpo['tardanza'];

    return ResultadoDelCarne.leido(
      AlumnoDePorteria.fromJson(Map<String, dynamic>.from(cuerpo['alumno'] as Map)),
      tardanza: tardanza is Map
          ? TardanzaDeHoy.fromJson(Map<String, dynamic>.from(tardanza))
          : null,
      novedades: _novedades(cuerpo) ?? const [],
      uniforme: ConteoUniforme.fromJson(cuerpo['uniforme']),
    );
  } catch (err) {
    return ResultadoDelCarne.mal('No se pudo leer el carné: $err');
  }
}

/// Las novedades de hoy del alumno que vienen en la respuesta; null si no
/// vienen.
List<NovedadDeHoy>? _novedades(Map<String, dynamic> cuerpo) {
  final lista = cuerpo['novedades'];
  if (lista is! List) return null;
  return [
    for (final n in lista) NovedadDeHoy.fromJson(Map<String, dynamic>.from(n as Map)),
  ];
}

/// Lo que no trae alumno: el carné que no es de nadie (404 con
/// `desconocido`), el anulado (410) y cualquier otro error. Null si es un 200.
ResultadoDelCarne? _sinAlumno(http.Response res, String? codigo, String accion) {
  if (res.statusCode == 404 && _campo(res, 'desconocido') == true) {
    return ResultadoDelCarne.desconocido(codigo ?? '');
  }
  if (res.statusCode == 410) {
    return ResultadoDelCarne.anulado(codigo ?? '');
  }
  if (res.statusCode != 200) {
    return ResultadoDelCarne.mal(_frase(res, accion));
  }
  return null;
}

/// Anota la novedad de uniforme de hoy, llegue tarde o no.
/// `POST porteria/novedad`. [motivos] son claves de [MotivoDeNovedad], al
/// menos una (sin ninguna el servidor contesta 422).
Future<NovedadGuardada> guardarNovedad(
  Server server, {
  required int alumnoId,
  required List<String> motivos,
  String? descripcion,
}) async {
  try {
    final http.Response res = await server.post('/porteria/novedad', {
      'alumno_id': alumnoId,
      'motivos': motivos,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
    });

    if (res.statusCode != 200) {
      return NovedadGuardada(error: _frase(res, 'guardar la novedad'));
    }

    final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;

    return NovedadGuardada(
      novedad: NovedadDeHoy.fromJson(
          Map<String, dynamic>.from(cuerpo['novedad'] as Map)),
      uniforme: ConteoUniforme.fromJson(cuerpo['uniforme']),
    );
  } catch (err) {
    return NovedadGuardada(error: 'No se pudo guardar la novedad: $err');
  }
}

/// «Deshacer» la novedad: sólo una de entrada y de hoy.
/// `DELETE porteria/novedad/{id}`, que devuelve el conteo ya sin ella.
Future<NovedadQuitada> quitarNovedad(Server server, int id) async {
  try {
    final http.Response res = await server.delete('/porteria/novedad/$id');
    if (res.statusCode != 200) {
      return NovedadQuitada(error: _frase(res, 'quitar la novedad'));
    }
    return NovedadQuitada(
        uniforme: ConteoUniforme.fromJson(_campo(res, 'uniforme')));
  } catch (err) {
    return NovedadQuitada(error: 'No se pudo quitar la novedad: $err');
  }
}

/// «Deshacer»: quita una tardanza de entrada de hoy.
/// `DELETE porteria/tardanza/{id}`. Devuelve null si salió bien, o la frase.
Future<String?> quitarTardanza(Server server, int id) async {
  try {
    final http.Response res = await server.delete('/porteria/tardanza/$id');
    return res.statusCode == 200 ? null : _frase(res, 'quitar la tardanza');
  } catch (err) {
    return 'No se pudo quitar la tardanza: $err';
  }
}

/// «¿De quién es este carné?»: guarda el código para que la próxima vez se lea
/// solo. `POST porteria/vincular`. Devuelve null si salió bien, o la frase.
Future<String?> vincularCarne(
  Server server, {
  required String codigo,
  required int alumnoId,
}) async {
  try {
    final http.Response res = await server.post('/porteria/vincular', {
      'codigo': codigo,
      'alumno_id': alumnoId,
    });
    return res.statusCode == 200 ? null : _frase(res, 'guardar el carné');
  } catch (err) {
    return 'No se pudo guardar el carné: $err';
  }
}

/// El carné de la app: el del alumno, o el de cada hijo del acudiente.
/// `GET porteria/mis-carnets`.
Future<List<CarneDeAlumno>> misCarnes(Server server) async {
  final http.Response res = await server.get('/porteria/mis-carnets');

  if (res.statusCode != 200) {
    throw Exception(_frase(res, 'traer el carné'));
  }

  return [
    for (final c in (jsonDecode(res.body) as List))
      CarneDeAlumno.fromJson(Map<String, dynamic>.from(c as Map)),
  ];
}

dynamic _campo(http.Response res, String campo) {
  try {
    final cuerpo = jsonDecode(res.body);
    return cuerpo is Map ? cuerpo[campo] : null;
  } catch (_) {
    return null;
  }
}

/// La frase del servidor si la trae; si no, una que diga qué no se pudo.
String _frase(http.Response res, String accion) {
  final mensaje = _campo(res, 'message');
  if (mensaje is String && mensaje.trim().isNotEmpty) return mensaje;
  return noSePudo(accion, res.statusCode);
}
