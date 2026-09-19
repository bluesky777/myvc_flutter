import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';

/// Las frases del boletín: lo que el docente le dice al alumno además de la
/// nota.
///
/// Dos tablas y conviene no confundirlas. `frases` es **el catálogo del año**,
/// que escribe el colegio; `frases_asignatura` es **lo que se le pone a un
/// alumno concreto** en una asignatura y un periodo, y puede apuntar al
/// catálogo o llevar su propio texto.
///
/// Las que ya tiene un alumno no hay que pedirlas: vienen dentro de
/// `notas/detailed`, en `alumno.frases`. Este archivo es para el catálogo y
/// para escribir.
///
/// ## Dos caminos que conviven, y el que corre hoy es el viejo
///
/// Escribir frases se puede de dos maneras, y que estén las dos no es
/// indecisión:
///
///  - **de una en una** —[ponerFrase] y [quitarFrase], o sea
///    `POST frases_asignatura/store` y `DELETE frases_asignatura/destroy`—, que
///    es lo que corre hoy en los dieciséis colegios y lo que usa la ficha de un
///    alumno;
///  - **el grupo entero** —[traerFrasesDelGrupo] y [guardarFrasesDelGrupo], o
///    sea `GET` y `PUT frases_asignatura/grupo/{asignatura_id}`—, que arregla
///    las dos cosas que la de arriba no sabe hacer: **elegir el periodo** y no
///    gastar una petición por frase. Medido por el front sobre «Transición» de
///    2018 —18 matriculados, 7 asignaturas—, un periodo entero pasa de **322
///    peticiones a 14**.
///
/// **Las dos del grupo están en `main` de `8myvc` (`53b50fa`) y todavía sin
/// desplegar**, así que el camino viejo es el que corre y no se toca: una
/// pantalla que llame a las nuevas antes de tiempo se lleva un 404 del
/// servidor, no una frase guardada. Y cuando estén arriba, las de una en una
/// siguen teniendo sentido donde se usan hoy —la ficha de **un** alumno, que no
/// necesita el grupo— así que esto no es un puente a medio cruzar sino dos
/// granos distintos para dos pantallas distintas.

/// El catálogo del año.
///
/// `GET frases`, que devuelve las del año del usuario y ya. Se pide una vez, al
/// abrir la hoja de elegir, y se guarda en memoria mientras la pantalla viva:
/// son cuatrocientas filas y no cambian mientras alguien pone notas.
Future<List<FraseDelCatalogo>> traerCatalogoDeFrases(Server server) async {
  final res = await server.get('/frases');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! List) return const [];

  return cuerpo
      .whereType<Map>()
      .map((f) => FraseDelCatalogo.fromJson(Map<String, dynamic>.from(f)))
      .where((f) => f.id != 0)
      .toList();
}

/// Lo que devuelve poner o quitar una frase.
class ResultadoDeFrases {
  const ResultadoDeFrases({this.frases, this.motivo});

  /// Cómo quedó la lista del alumno. Null cuando falló.
  final List<FraseDeAlumno>? frases;

  /// Por qué no se pudo, o null si entró.
  final String? motivo;

  bool get entro => motivo == null;
}

/// Le pone una frase a un alumno.
///
/// Una de dos: la del catálogo, pasando [fraseId], o una escrita a mano,
/// pasando [texto]. El backend las distingue por la URL —el id va en la ruta,
/// no en el cuerpo— y **si viene id ignora el texto**, así que mandar los dos
/// no sirve de nada.
///
/// **El periodo no se manda y no se puede elegir**: `FrasesAsignaturaController`
/// escribe siempre `periodo_id = $user->periodo_id`, o sea el de la barra de
/// arriba. Poner una frase de otro periodo desde aquí es imposible, y por eso
/// la pantalla no lo ofrece.
///
/// Devuelve **la lista entera del alumno ya recalculada**, que es lo que
/// contesta el backend: con eso se repinta sin volver a preguntar.
Future<ResultadoDeFrases> ponerFrase(
  Server server, {
  required int alumnoId,
  required int asignaturaId,
  int? fraseId,
  String? texto,
}) async {
  final ruta = fraseId != null
      ? '/frases_asignatura/store/$fraseId'
      : '/frases_asignatura/store';

  try {
    final res = await server.post(ruta, {
      'alumno_id': alumnoId,
      'asignatura_id': asignaturaId,
      if (fraseId == null) 'frase': texto ?? '',
    });

    if (res.statusCode == 400 || res.statusCode == 403) {
      return const ResultadoDeFrases(
        motivo: 'No tienes permiso para escribir en este periodo.',
      );
    }
    if (res.statusCode >= 300) {
      return ResultadoDeFrases(
        motivo: 'El servidor respondió ${res.statusCode}.',
      );
    }

    return ResultadoDeFrases(frases: frasesDeLista(jsonDecode(res.body)));
  } catch (err) {
    return ResultadoDeFrases(motivo: 'No se pudo poner la frase: $err');
  }
}

/// Le quita una frase a un alumno.
///
/// El id es el de la fila de `frases_asignatura`, no el del catálogo:
/// confundirlos borraría otra frase de otro alumno. Devuelve null si entró, o
/// el motivo si no.
///
/// A diferencia de poner, esto **no devuelve la lista nueva** —contesta la fila
/// borrada—, así que quien llama la quita de la suya.
Future<String?> quitarFrase(Server server, {required int id}) async {
  try {
    final res = await server.delete('/frases_asignatura/destroy/$id');

    if (res.statusCode == 400 || res.statusCode == 403) {
      return 'No tienes permiso para escribir en este periodo.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo quitar la frase: $err';
  }
}

// ── El grupo entero ──────────────────────────────────────────────────────────

/// Las frases de **todo el grupo** de una asignatura, en una petición.
///
/// `GET frases_asignatura/grupo/{asignatura_id}`, con `periodo_id` opcional en
/// la query: **sin él manda el periodo de la sesión**, que es lo único que saben
/// hacer las de una en una. Cuál le tocó viene en la respuesta
/// ([FrasesDelGrupo.periodoId]), que es lo que permite avisar de que fue el que
/// no era.
///
/// Devuelve los alumnos matriculados hoy —los tres estados de `Grupo::alumnos()`:
/// `MATR`, `ASIS`, `PREM`—, **cada uno con las suyas y los que no tienen
/// ninguna con la lista vacía**, así que la pantalla se pinta con esto y ya. Y
/// trae la población de lo leído, con el renglón incómodo dentro:
/// [PoblacionLeida.frasesFueraDelGrupo].
///
/// **Lo que hay que mirar antes de pintar el botón de guardar es
/// [FrasesDelGrupo.puedeEscribir], no [FrasesDelGrupo.periodoAbierto]**: el
/// primero es lo que el `PUT` le contestará a quien está mirando y el segundo es
/// la columna del periodo: `permiteEditarNotas` sólo mira esa columna cuando
/// quien llama es docente, así que un superusuario escribe con el periodo
/// cerrado y un docente no —y un secretario sin `is_superuser` lee este `GET` y
/// no escribe nunca—.
///
/// **Lanza si el servidor no contesta 200**, como [traerCatalogoDeFrases] y por
/// lo mismo: esto se pide al abrir la pantalla y sin ello no hay pantalla, así
/// que quien llama ya tiene un `try` alrededor de la carga y un sitio donde
/// pintar el fallo. Los códigos que se esperan son **403** —esa asignatura no es
/// suya, y no es administrativo—, **404** —no existe— y **422** —el `periodo_id`
/// no es del año de la asignatura, o la sesión no tiene periodo activo—; el
/// texto de todos ésos lo escribe el servidor y se enseña tal cual.
Future<LecturaDeFrasesDelGrupo> traerFrasesDelGrupo(
  Server server, {
  required int asignaturaId,
  int? periodoId,
}) async {
  final ruta = periodoId == null
      ? '/frases_asignatura/grupo/$asignaturaId'
      : '/frases_asignatura/grupo/$asignaturaId?periodo_id=$periodoId';

  final res = await server.get(ruta);

  if (res.statusCode >= 300) {
    throw Exception(_porQueDijoQueNo(
      res,
      respaldo: 'No se pudieron traer las frases del grupo.',
    ));
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor contestó algo que no se entiende.');
  }

  return LecturaDeFrasesDelGrupo.fromJson(Map<String, dynamic>.from(cuerpo));
}

/// Lo que devuelve guardar el grupo entero.
///
/// **El grupo releído y la población de lo escrito**, que es lo que contesta un
/// guardado en esta casa en vez de un «OK»: [poblacion] dice qué pasó —incluido
/// que no cambiara nada, que no es lo mismo que no haberse guardado— y [grupo]
/// trae las filas nuevas **ya con su `id`**, así que no hace falta volver a
/// pedir nada para el guardado siguiente.
class ResultadoDeGuardarFrases {
  const ResultadoDeGuardarFrases({this.grupo, this.poblacion, this.motivo});

  /// El grupo entero releído. Null cuando falló.
  final FrasesDelGrupo? grupo;

  /// Lo que escribió. Null cuando falló.
  final PoblacionGuardada? poblacion;

  /// Por qué no se pudo, o null si entró.
  final String? motivo;

  bool get entro => motivo == null;
}

/// Guarda las frases de los alumnos que se le nombren, en un `PUT`.
///
/// `PUT frases_asignatura/grupo/{asignatura_id}`, con `periodo_id` opcional en
/// el cuerpo —el servidor lo lee con `Request::input`, así que da igual que
/// viaje ahí y no en la query— y **el periodo destino es el que manda**: es lo
/// que arregla la limitación de [ponerFrase], que escribe siempre en el de la
/// sesión.
///
/// ## Es declarativo, pero sólo para quien viene nombrado
///
/// Cada [FrasesDeUnAlumno] trae **la lista completa** de ese alumno y lo que no
/// venga en ella se borra. Pero **un alumno que no está en [alumnos] no se
/// mira**, así que guardar de a uno —o por páginas— no le puede borrar nada a
/// nadie: lo único que se borra por omisión es dentro de la lista de un alumno
/// que sí vino.
///
/// Y por eso `frases: []` y no mandar la clave son cosas distintas —«quítaselas
/// todas» y un 422— y aquí no se pueden confundir: [FrasesDeUnAlumno.frases] es
/// obligatorio y no admite null, de modo que la única forma de no tocar a un
/// alumno es **no construir el suyo**. Ver [cuerpoDeGuardarFrasesDelGrupo].
///
/// ## Lo que puede contestar que no
///
/// **403 son dos cosas con el mismo número** y el texto del servidor es lo único
/// que las separa: «No tiene permiso para escribir las frases del boletín» —un
/// docente al que no le toca— y «El periodo está cerrado: no se puede escribir
/// en él». La primera no se arregla; la segunda se le pide al coordinador. Las
/// dos se saben **antes** con [FrasesDelGrupo.puedeEscribir] del `GET`, que es
/// la razón de que ese campo exista.
///
/// **422 es el cuerpo**: un alumno que no está matriculado en ese grupo, un `id`
/// de frase que no es suya, una frase repetida, un `frase_id` que no está vivo
/// en el catálogo, o `alumnos` mal formado.
///
/// **Y no hay guardado a medias**: el periodo cerrado corta la petición entera
/// antes de mirar el cuerpo, y lo que se escribe va en una transacción. Un
/// [ResultadoDeGuardarFrases.motivo] quiere decir que no se guardó nada.
Future<ResultadoDeGuardarFrases> guardarFrasesDelGrupo(
  Server server, {
  required int asignaturaId,
  required List<FrasesDeUnAlumno> alumnos,
  int? periodoId,
}) async {
  assert(alumnos.isNotEmpty,
      'Un guardado sin alumnos es un 422: para no tocar a nadie, no se guarda.');
  assert(alumnos.map((a) => a.alumnoId).toSet().length == alumnos.length,
      'Un alumno dos veces en el mismo cuerpo es un 422: la última lista '
      'ganaría en silencio.');

  try {
    final res = await server.put(
      '/frases_asignatura/grupo/$asignaturaId',
      cuerpoDeGuardarFrasesDelGrupo(alumnos: alumnos, periodoId: periodoId),
    );

    if (res.statusCode >= 300) {
      return ResultadoDeGuardarFrases(
        motivo: _porQueDijoQueNo(
          res,
          respaldo: 'No se pudieron guardar las frases.',
        ),
      );
    }

    final cuerpo = jsonDecode(res.body);
    if (cuerpo is! Map) {
      return ResultadoDeGuardarFrases(
        motivo: 'El servidor contestó algo que no se entiende.',
      );
    }

    final leido = Map<String, dynamic>.from(cuerpo);

    return ResultadoDeGuardarFrases(
      grupo: FrasesDelGrupo.fromJson(leido),
      poblacion: PoblacionGuardada.fromJson(leido['poblacion']),
    );
  } catch (err) {
    return ResultadoDeGuardarFrases(
      motivo: 'No se pudieron guardar las frases: $err',
    );
  }
}

/// El cuerpo que viaja en [guardarFrasesDelGrupo].
///
/// Está aparte y es público **para poder mirarlo sin un servidor delante**: es
/// el sitio donde `frases: []` —«quítaselas todas»— y no mandar la clave —un
/// 422— se separan, y eso es una prueba, no un comentario. La clave `frases` sale
/// siempre porque [FrasesDeUnAlumno.frases] no puede faltar, y un alumno que no
/// se quiere tocar sencillamente no tiene entrada aquí dentro.
///
/// `periodo_id` sólo viaja si se pidió uno: mandarlo en null no es lo mismo
/// —`Request::input('periodo_id')` lo leería como ausente igual, pero dejarlo
/// fuera es lo que dice de verdad «el de la sesión»—.
Map<String, dynamic> cuerpoDeGuardarFrasesDelGrupo({
  required List<FrasesDeUnAlumno> alumnos,
  int? periodoId,
}) {
  return {
    if (periodoId != null) 'periodo_id': periodoId,
    'alumnos': alumnos.map((a) => a.paraElCuerpo()).toList(),
  };
}

/// Lo que dijo el servidor al rechazar, si se le puede enseñar a una persona.
///
/// Sólo se repite el suyo en los tres códigos en que lo escribe esta familia
/// —403, 404 y 422—; un 500 trae un volcado de Laravel, que no le dice nada a un
/// docente. El recorte de [loQueDijoElServidor] —160 caracteres y sin saltos de
/// línea— es la otra mitad de esa red.
String _porQueDijoQueNo(dynamic res, {required String respaldo}) {
  final int codigo = res.statusCode;

  if (codigo == 403 || codigo == 404 || codigo == 422) {
    return motivoDeRechazo(res.body, respaldo: respaldo);
  }

  return '$respaldo El servidor respondió $codigo.';
}
