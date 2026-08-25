import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Models/ConfigDisciplinaModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Models/OrdinalModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// Lo que hace falta para abrir la pantalla de disciplina, en una sola
/// respuesta: `PUT grupos/con-disciplina`.
///
/// Son cuatro cosas que no cambian mientras dure la sesión —el catálogo del
/// manual, los nombres que el colegio le da a cada tipo, los grupos del año y
/// las descripciones ya escritas—, así que se piden una vez al entrar y no
/// cada vez que se cambia de grupo.
class DatosDisciplina {
  final List<GrupoModel> grupos;
  final ConfigDisciplinaModel config;
  final List<OrdinalModel> ordinales;

  /// Las descripciones de situaciones ya escritas este año y el anterior, para
  /// sugerirlas al teclear. El colegio repite mucho las mismas.
  final List<String> descripciones;

  DatosDisciplina({
    this.grupos = const [],
    ConfigDisciplinaModel? config,
    this.ordinales = const [],
    this.descripciones = const [],
  }) : config = config ?? ConfigDisciplinaModel();
}

/// Lo que devuelve una escritura de disciplina.
///
/// El backend contesta a crear, editar y borrar con **el alumno entero
/// recalculado**, contadores incluidos. Por eso esto no es un `String?` como
/// las escrituras de unidades: se aprovecha la respuesta para refrescar la
/// fila en vez de volver a pedir el grupo de cuarenta alumnos.
class GuardadoSituacion {
  final AlumnoDisciplinaModel? alumno;
  final String? error;

  const GuardadoSituacion.bien(AlumnoDisciplinaModel this.alumno)
      : error = null;

  const GuardadoSituacion.mal(String this.error) : alumno = null;

  bool get correcto => error == null;
}

/// Los grupos, el catálogo del manual y la configuración del año.
Future<DatosDisciplina> traerDatosDeDisciplina(Server server) async {
  final res = await server.put('/grupos/con-disciplina', {});

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió los datos de disciplina.');
  }

  return DatosDisciplina(
    grupos: _lista(cuerpo['grupos'], GrupoModel.fromJson)
      ..sort((a, b) => a.orden.compareTo(b.orden)),
    config: cuerpo['config'] is Map
        ? ConfigDisciplinaModel.fromJson(
            Map<String, dynamic>.from(cuerpo['config'] as Map))
        : ConfigDisciplinaModel(),
    ordinales: _lista(cuerpo['ordinales'], OrdinalModel.fromJson),
    descripciones: _descripciones(cuerpo['descripciones_typeahead']),
  );
}

/// La ficha de disciplina del propio alumno, o la de un acudido.
///
/// `GET disciplina/mis-fichas/{alumno_id?}`, con la guarda `boletin.propio` en
/// modo `sin-paz-y-salvo`: retener el boletín de quien debe es una cosa y
/// esconderle a una familia la situación disciplinaria de su hijo es otra.
///
/// **El id no es opcional para un acudiente.** Sin él, el backend sólo sabe de
/// quién hablar si quien pregunta es el propio alumno; a un acudiente le
/// responde **400**. Por eso [MiDisciplinaScreen] le pregunta de qué acudido
/// antes de llamar, igual que hacen «Mis notas» y «Asistencia».
///
/// El año lo decide el backend **a partir del alumno y no de quien pregunta**,
/// que es lo único que hace que esto sirva para un acudiente cuyo año de
/// usuario no tiene por qué ser el del acudido.
///
/// `config` puede venir null —esa lectura no crea la fila del año a propósito,
/// porque una lectura que escribe deja de ser de sólo lectura— y entonces valen
/// los valores por defecto de [ConfigDisciplinaModel], que son los nombres
/// genéricos de los tres tipos.
Future<MiFichaDisciplina> traerMisFichas(
  Server server, {
  int? alumnoId,
}) async {
  final ruta = alumnoId == null
      ? '/disciplina/mis-fichas'
      : '/disciplina/mis-fichas/$alumnoId';

  final res = await server.get(ruta);

  if (res.statusCode >= 300) {
    throw Exception(mensajeDeFallo(res.statusCode, 'ver la ficha'));
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map || cuerpo['alumno'] is! Map) {
    throw Exception('El servidor no devolvió la ficha.');
  }

  return MiFichaDisciplina(
    alumno: AlumnoDisciplinaModel.fromJson(
      Map<String, dynamic>.from(cuerpo['alumno'] as Map),
    ),
    datos: DatosDisciplina(
      config: cuerpo['config'] is Map
          ? ConfigDisciplinaModel.fromJson(
              Map<String, dynamic>.from(cuerpo['config'] as Map))
          : ConfigDisciplinaModel(),
      ordinales: _lista(cuerpo['ordinales'], OrdinalModel.fromJson),
    ),
  );
}

/// La ficha propia y lo que hace falta para pintarla.
///
/// Sin `grupos` ni `descripciones_typeahead`: eso es del editor, y aquí no se
/// escribe nada.
class MiFichaDisciplina {
  final AlumnoDisciplinaModel alumno;
  final DatosDisciplina datos;

  const MiFichaDisciplina({required this.alumno, required this.datos});
}

/// Los alumnos del grupo con su año entero de disciplina.
///
/// `PUT disciplina/alumnos {grupo_id, year_id}`. Vienen ya ordenados por
/// apellidos desde el backend y con los cuatro periodos de cada uno, así que
/// cambiar de periodo en la barra de arriba no obliga a pedirlo otra vez.
Future<List<AlumnoDisciplinaModel>> traerAlumnosConDisciplina(
  Server server, {
  required int grupoId,
  required int yearId,
}) async {
  final res = await server.put('/disciplina/alumnos', {
    'grupo_id': grupoId,
    'year_id': yearId,
  });

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  final crudos = cuerpo is Map ? cuerpo['alumnos'] : cuerpo;

  return _lista(crudos, AlumnoDisciplinaModel.fromJson);
}

/// Crea una situación. `POST disciplina/store`.
///
/// Los ordinales viajan DENTRO, en `selected_ordinales`, y el backend los
/// inserta en la tabla pivote de una vez. Al editar no es así: ver
/// [actualizarSituacion].
Future<GuardadoSituacion> crearSituacion(
  Server server, {
  required int alumnoId,
  required int periodoId,
  required int yearId,
  required int tipo,
  required String descripcion,
  DateTime? fecha,
  String? testigos,
  String? descargo,
  int? profesorId,
  List<int> ordinalIds = const [],
  bool derivaDeTardanzas = false,
  List<int> derivaDe = const [],
}) {
  return _guardar(
    () => server.post('/disciplina/store', {
      'year_id': yearId,
      'alumno_id': alumnoId,
      'periodo_id': periodoId,
      'tipo_situacion': tipo,
      'descripcion': descripcion,
      'testigos': testigos,
      'descargo': descargo,
      'fecha_hora_aprox': _fecha(fecha),
      'profesor': _profesor(profesorId),
      'deriva_de_tardanzas': derivaDeTardanzas ? 1 : 0,
      'selected_ordinales': [
        for (final id in ordinalIds) {'id': id}
      ],
      // Las situaciones que esta se lleva por delante: el backend les pone
      // `become_id` apuntando a la recién creada, y con eso dejan de contar
      // por separado. Aquí basta el id.
      'dependencias': [
        for (final id in derivaDe) {'id': id}
      ],
    }),
    'crear la situación',
  );
}

/// Guarda los cambios de una situación. `PUT disciplina/update`.
///
/// **Este endpoint NO toca los ordinales.** Lee `proceso_ordinales` del cuerpo
/// y no hace nada con ellos: la tabla pivote solo se mueve con
/// [asignarOrdinal] y [quitarOrdinal], que hay que llamar al marcar y al
/// desmarcar. Mandarlos aquí y esperar que se guarden es perderlos en
/// silencio.
///
/// Y `dependencias` va SIEMPRE, aunque esté vacía. El backend hace
/// `count($dependencias)` sin comprobar antes que sea un array, y en PHP 8.3
/// `count(null)` es un TypeError: omitir la clave no guarda nada y devuelve un
/// 500. Es la diferencia entre este método y el de crear, que sí lo protege.
///
/// Tampoco toca `deriva_de_tardanzas`: su UPDATE no nombra esa columna, así
/// que eso solo se fija al crear. Ver [crearSituacion].
Future<GuardadoSituacion> actualizarSituacion(
  Server server, {
  required int situacionId,
  required int alumnoId,
  required int yearId,
  required int tipo,
  required String descripcion,
  DateTime? fecha,
  String? testigos,
  String? descargo,
  int? profesorId,
  List<int> enlazar = const [],
  List<int> desenlazar = const [],
}) {
  return _guardar(
    () => server.put('/disciplina/update', {
      'id': situacionId,
      'alumno_id': alumnoId,
      'year_id': yearId,
      'tipo_situacion': tipo,
      'descripcion': descripcion,
      'testigos': testigos,
      'descargo': descargo,
      'fecha_hora_aprox': _fecha(fecha),
      'profesor': _profesor(profesorId),
      'dependencias': dependenciasParaElBackend(enlazar, desenlazar),
    }),
    'guardar la situación',
  );
}

/// Las situaciones que esta se lleva o suelta, como las lee el backend.
///
/// **Lo que decide es que la clave `asignado` ESTÉ, no lo que valga.** El
/// backend hace `array_key_exists('asignado', ...)`: si está, engancha; si no
/// está, suelta. Mandar `asignado: false` para soltar hace justo lo contrario,
/// y mandar `asignado: null` también, porque en PHP una clave con null existe.
/// Por eso las que se sueltan viajan con el id a secas.
///
/// Y solo van las que cambian. Soltar una que nunca estuvo enganchada aquí le
/// borraría el `become_id` que tuviera con otra situación.
List<Map<String, dynamic>> dependenciasParaElBackend(
  List<int> enlazar,
  List<int> desenlazar,
) {
  return [
    for (final id in enlazar) {'id': id, 'asignado': true},
    for (final id in desenlazar) {'id': id},
  ];
}

/// Borra una situación. `PUT disciplina/destroy` — PUT, no DELETE, y con el id
/// en el cuerpo.
///
/// Es borrado blando: la fila queda con su `deleted_at` y se restaura desde la
/// web. El `alumno_id` no sobra aunque la situación ya sepa de quién es: el
/// backend lo usa para devolver el alumno recalculado.
///
/// Ojo: recalcula con el año del USUARIO, no con el que se le mande. Mirando
/// un año que no es el de la barra de arriba, lo que vuelve son los datos del
/// otro año. Por eso la pantalla que borra trabaja siempre en el año actual.
Future<GuardadoSituacion> borrarSituacion(
  Server server, {
  required int situacionId,
  required int alumnoId,
}) {
  return _guardar(
    () => server.put('/disciplina/destroy', {
      'proceso_id': situacionId,
      'alumno_id': alumnoId,
    }),
    'borrar la situación',
  );
}

/// Añade un ordinal a una situación ya guardada. `POST disciplina/asignar-ordinal`.
///
/// `id` es el del ORDINAL, no el de la fila pivote. El par asignar/quitar no
/// usa el mismo verbo —este es POST y el otro PUT— aunque sea la misma
/// operación al revés; es del backend y cambiarlo aquí da un 405.
Future<String?> asignarOrdinal(
  Server server, {
  required int situacionId,
  required int ordinalId,
}) {
  return _escribir(
    () => server.post('/disciplina/asignar-ordinal', {
      'id': ordinalId,
      'proceso_id': situacionId,
    }),
    'asignar el ordinal',
  );
}

/// Quita un ordinal de una situación. `PUT disciplina/quitar-ordinal`.
Future<String?> quitarOrdinal(
  Server server, {
  required int situacionId,
  required int ordinalId,
}) {
  return _escribir(
    () => server.put('/disciplina/quitar-ordinal', {
      'id': ordinalId,
      'proceso_id': situacionId,
    }),
    'quitar el ordinal',
  );
}

/// La fecha como la espera la columna datetime, o null si no hay.
///
/// Se manda a las 00:00: de `fecha_hora_aprox` el backend solo lee los diez
/// primeros caracteres para pintar `fecha_corta`, así que la hora no es un
/// dato aquí — al contrario que en una tardanza, donde sí lo es.
String? _fecha(DateTime? fecha) {
  if (fecha == null) return null;
  return fechaHoraParaServidor(DateTime(fecha.year, fecha.month, fecha.day));
}

/// El docente, envuelto como lo lee el backend: `Request::input('profesor')['profesor_id']`.
///
/// Un id suelto no le vale — buscaría la clave dentro de un entero y guardaría
/// null sin avisar—, y null es válido: el docente es opcional.
Map<String, int>? _profesor(int? profesorId) =>
    profesorId == null ? null : {'profesor_id': profesorId};

/// Lo común a las tres escrituras que devuelven el alumno recalculado.
Future<GuardadoSituacion> _guardar(
  Future Function() peticion,
  String accion,
) async {
  try {
    final res = await peticion();

    if (res.statusCode >= 300) {
      return GuardadoSituacion.mal(mensajeDeFallo(res.statusCode, accion));
    }

    final cuerpo = jsonDecode(res.body);
    if (cuerpo is! Map) {
      return GuardadoSituacion.mal(
          'Se guardó, pero el servidor no devolvió al alumno.');
    }

    return GuardadoSituacion.bien(
      AlumnoDisciplinaModel.fromJson(Map<String, dynamic>.from(cuerpo)),
    );
  } catch (err) {
    return GuardadoSituacion.mal('No se pudo $accion: $err');
  }
}

/// Lo común a las escrituras que no devuelven nada que mirar.
Future<String?> _escribir(Future Function() peticion, String accion) async {
  try {
    final res = await peticion();
    if (res.statusCode >= 300) return mensajeDeFallo(res.statusCode, accion);
    return null;
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}

List<T> _lista<T>(dynamic crudas, T Function(Map<String, dynamic>) construir) {
  if (crudas is! List) return <T>[];

  final resultado = <T>[];
  for (final cruda in crudas) {
    if (cruda is! Map) continue;
    resultado.add(construir(Map<String, dynamic>.from(cruda)));
  }
  return resultado;
}

/// Las descripciones sugeridas, sin repetidas ni vacías.
///
/// El backend hace un `SELECT distinct(descripcion)` de dos años, pero
/// «Llegó tarde» y «llegó tarde » son distintas para SQL y la misma para
/// quien escribe. Se limpian aquí y se ordenan para que la lista no baile.
List<String> _descripciones(dynamic crudas) {
  if (crudas is! List) return const [];

  final vistas = <String, String>{};
  for (final cruda in crudas) {
    final valor = cruda is Map ? cruda['descripcion'] : cruda;
    final texto = '${valor ?? ''}'.trim();
    if (texto.isEmpty) continue;

    vistas.putIfAbsent(texto.toLowerCase(), () => texto);
  }

  return vistas.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
