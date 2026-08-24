import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// El libro de notas de una asignatura en el periodo: sus unidades y sus
/// alumnos con la nota de cada casilla.
class LibroDeNotas {
  final AsignaturaModel asignatura;
  final List<UnidadModel> unidades;
  final List<AlumnoDelLibro> alumnos;

  const LibroDeNotas({
    required this.asignatura,
    this.unidades = const [],
    this.alumnos = const [],
  });

  /// Las subunidades de todas las unidades, en el orden en que se ponen las
  /// notas. Es la lista que se recorre para elegir indicador.
  List<SubunidadModel> get subunidades => [
        for (final unidad in unidades) ...unidad.subunidades,
      ];

  /// Cuántas notas hay puestas en esa casilla, contando solo las que alguien
  /// tocó. Sirve para decir «faltan 12» sin pedir nada más.
  int notasPuestasEn(int subunidadId) => alumnos
      .where((a) => a.notaDe(subunidadId)?.puesta ?? false)
      .length;

  /// El promedio automático de un alumno: sus notas ponderadas por el
  /// porcentaje de la subunidad dentro de la unidad y el de la unidad dentro
  /// del periodo.
  ///
  /// Se calcula aquí y no se espera al servidor porque en la ficha del alumno
  /// tiene que moverse **mientras se escribe**: la gracia de nivelar es ver a
  /// dónde llega el promedio antes de decidir la definitiva, y para eso no
  /// sirve un número que solo se refresca al recargar el libro.
  ///
  /// Es la misma cuenta que hace `notas/detailed` en SQL
  /// —`sum((u.porcentaje/100)*((s.porcentaje/100)*n.nota))`— y también la que
  /// hace el front web en `promedioTotal`. Las casillas sin nota **no suman**,
  /// igual que allí: en SQL un NULL no entra en el SUM.
  ///
  /// [sobrescritas] son las notas que el docente tiene escritas y todavía no
  /// ha guardado, por id de subunidad. Una clave presente con valor nulo es
  /// una casilla que se acaba de vaciar, y por eso se mira `containsKey` y no
  /// si el valor es nulo.
  double promedioDe(
    AlumnoDelLibro alumno, {
    Map<int, double?> sobrescritas = const {},
  }) {
    var suma = 0.0;

    for (final unidad in unidades) {
      for (final subunidad in unidad.subunidades) {
        final nota = sobrescritas.containsKey(subunidad.id)
            ? sobrescritas[subunidad.id]
            : alumno.notaDe(subunidad.id)?.nota;

        if (nota == null) continue;

        suma += (unidad.porcentaje / 100) * (subunidad.porcentaje / 100) * nota;
      }
    }

    return suma;
  }

  /// El mismo libro con las frases de un alumno cambiadas.
  LibroDeNotas conFrasesDe(int alumnoId, List<FraseDeAlumno> nuevas) {
    return LibroDeNotas(
      asignatura: asignatura,
      unidades: unidades,
      alumnos: [
        for (final alumno in alumnos)
          alumno.alumnoId == alumnoId ? alumno.conFrases(nuevas) : alumno,
      ],
    );
  }

  /// El mismo libro con la definitiva de un alumno cambiada.
  LibroDeNotas conNotaFinalDe(int alumnoId, NotaFinalDelLibro nueva) {
    return LibroDeNotas(
      asignatura: asignatura,
      unidades: unidades,
      alumnos: [
        for (final alumno in alumnos)
          alumno.alumnoId == alumnoId ? alumno.conNotaFinal(nueva) : alumno,
      ],
    );
  }

  /// El mismo libro con las notas que se acaban de guardar ya aplicadas.
  ///
  /// Existe para no volver a pedir `notas/detailed` al salir de una planilla:
  /// lo que quedó guardado se sabe —es lo que se mandó y el servidor aceptó—,
  /// y esa consulta es demasiado cara para gastarla en refrescar un número.
  LibroDeNotas conNotas(List<NotaPendiente> guardadas) {
    if (guardadas.isEmpty) return this;

    final porAlumno = <int, List<NotaPendiente>>{};
    for (final guardada in guardadas) {
      porAlumno.putIfAbsent(guardada.alumnoId, () => []).add(guardada);
    }

    return LibroDeNotas(
      asignatura: asignatura,
      unidades: unidades,
      alumnos: [
        for (final alumno in alumnos)
          porAlumno.containsKey(alumno.alumnoId)
              ? _alDia(alumno.con(porAlumno[alumno.alumnoId]!))
              : alumno,
      ],
    );
  }

  /// Un alumno cuyas notas acaban de cambiar, con su definitiva también al día.
  ///
  /// Es la otra mitad de lo que hizo el servidor: cada `notas/update` recalcula
  /// la definitiva del alumno. Sin esto, la pestaña «Por alumno» seguiría
  /// enseñando la de antes hasta la siguiente recarga. Ver
  /// [NotaFinalDelLibro.trasRecalcularse], que es donde están las reglas.
  ///
  /// El promedio se calcula contra `unidades`, que no cambian aquí, así que
  /// preguntárselo a este mismo libro da el mismo número que daría el nuevo.
  AlumnoDelLibro _alDia(AlumnoDelLibro alumno) {
    final definitiva = alumno.notaFinal;
    if (definitiva == null) return alumno;

    return alumno.conNotaFinal(
      definitiva.trasRecalcularse(promedioDe(alumno)),
    );
  }
}

/// Un alumno dentro del libro, con sus notas de esta asignatura.
class AlumnoDelLibro {
  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? fotoNombre;

  /// 'MATR', 'ASIS' o 'PREM'. El front pinta en cursiva a los asistentes y
  /// marca con un rótulo a los prematriculados: no son alumnos matriculados y
  /// conviene notarlo antes de ponerles una nota.
  final String? estado;

  /// Si tiene necesidades educativas especiales.
  final bool nee;

  final int ausenciasCount;
  final int tardanzasCount;

  /// Sus notas, por id de subunidad. Mapa y no lista porque la pantalla
  /// pregunta siempre por una casilla concreta.
  final Map<int, NotaDelLibro> notas;

  final NotaFinalDelLibro? notaFinal;

  /// Lo que se le dice al alumno en el boletín además de la nota, ya en esta
  /// respuesta: `notas/detailed` las trae por alumno, así que la ficha no pide
  /// nada aparte para enseñarlas.
  final List<FraseDeAlumno> frases;

  const AlumnoDelLibro({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.fotoNombre,
    this.estado,
    this.nee = false,
    this.ausenciasCount = 0,
    this.tardanzasCount = 0,
    this.notas = const {},
    this.notaFinal,
    this.frases = const [],
  });

  /// Como se lista: por apellidos, que es como los ordena el backend y como
  /// los llama el docente.
  String get nombreEnLista => '$apellidos $nombres'.trim();

  NotaDelLibro? notaDe(int subunidadId) => notas[subunidadId];

  /// El mismo alumno con esas notas cambiadas. Se busca la casilla por el id de
  /// la nota, no por el de la subunidad: es lo que trae [NotaPendiente] y lo
  /// que de verdad identifica la fila que se acaba de escribir.
  AlumnoDelLibro con(List<NotaPendiente> guardadas) {
    final nuevas = Map<int, NotaDelLibro>.from(notas);

    for (final guardada in guardadas) {
      for (final entrada in nuevas.entries) {
        if (entrada.value.id != guardada.notaId) continue;
        nuevas[entrada.key] = entrada.value.con(guardada.nota);
        break;
      }
    }

    return copiaCon(notas: nuevas);
  }

  /// El mismo alumno con otra definitiva. Se usa al volver de la ficha, donde
  /// se nivela y se marcan las dos banderas.
  AlumnoDelLibro conNotaFinal(NotaFinalDelLibro nueva) =>
      copiaCon(notaFinal: nueva);

  /// El mismo alumno con otras frases.
  AlumnoDelLibro conFrases(List<FraseDeAlumno> nuevas) =>
      copiaCon(frases: nuevas);

  AlumnoDelLibro copiaCon({
    Map<int, NotaDelLibro>? notas,
    NotaFinalDelLibro? notaFinal,
    List<FraseDeAlumno>? frases,
  }) {
    return AlumnoDelLibro(
      alumnoId: alumnoId,
      nombres: nombres,
      apellidos: apellidos,
      fotoNombre: fotoNombre,
      estado: estado,
      nee: nee,
      ausenciasCount: ausenciasCount,
      tardanzasCount: tardanzasCount,
      notas: notas ?? this.notas,
      notaFinal: notaFinal ?? this.notaFinal,
      frases: frases ?? this.frases,
    );
  }

  factory AlumnoDelLibro.fromJson(Map<String, dynamic> json) {
    final crudas = json['notas'];
    final notas = <int, NotaDelLibro>{};

    if (crudas is List) {
      for (final cruda in crudas.whereType<Map>()) {
        final nota = NotaDelLibro.fromJson(Map<String, dynamic>.from(cruda));
        if (nota.subunidadId != 0) notas[nota.subunidadId] = nota;
      }
    }

    final finalCruda = json['nota_final'];

    return AlumnoDelLibro(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: '${json['apellidos'] ?? ''}',
      // `Grupo::alumnos` ya resuelve la foto por defecto según el sexo, así que
      // esto nunca viene vacío por no tener foto propia.
      fotoNombre: texto(json['foto_nombre']),
      estado: texto(json['estado']),
      nee: entero(json['nee']) == 1,
      ausenciasCount: enteroO(json['ausencias_count']),
      tardanzasCount: enteroO(json['tardanzas_count']),
      notas: notas,
      notaFinal: finalCruda is Map
          ? NotaFinalDelLibro.fromJson(Map<String, dynamic>.from(finalCruda))
          : null,
      frases: frasesDeLista(json['frases']),
    );
  }
}

/// La nota de un alumno en una casilla.
class NotaDelLibro {
  /// El id de la fila de `notas`, que es lo que necesita `notas/update/{id}`.
  final int id;
  final int subunidadId;
  final double? nota;

  const NotaDelLibro({
    required this.id,
    required this.subunidadId,
    this.nota,
  });

  /// Si esta casilla tiene una nota puesta.
  ///
  /// La fila existe desde que alguien abrió el libro —`notas/detailed` las crea
  /// con la nota por defecto de la subunidad—, así que «tiene fila» no es lo
  /// mismo que «tiene nota». Lo que no se sabe es si el 0 lo puso el docente o
  /// es el valor de fábrica; por eso esto solo dice si hay número, y quien
  /// quiera contar lo pendiente que mire además la nota por defecto.
  bool get puesta => nota != null;

  NotaDelLibro con(double? nueva) =>
      NotaDelLibro(id: id, subunidadId: subunidadId, nota: nueva);

  factory NotaDelLibro.fromJson(Map<String, dynamic> json) {
    return NotaDelLibro(
      id: enteroO(json['id'] ?? json['nota_id']),
      subunidadId: enteroO(json['subunidad_id']),
      nota: _decimal(json['nota']),
    );
  }
}

/// La definitiva del alumno en la asignatura y el periodo.
///
/// Las dos banderas no son independientes, y quien las pinte tiene que saberlo:
/// el backend las cruza al escribir. Las transiciones están en
/// [trasCambiarLaNota], [trasAlternarManual] y [trasAlternarRecuperada], y son
/// el único sitio donde esas reglas viven del lado de la app.
class NotaFinalDelLibro {
  final int nfId;
  final double? nota;

  /// La que sale de las subunidades ponderadas, antes de nivelar.
  final double? automatica;

  /// Si la definitiva se puso a mano: entonces el recálculo no la pisa.
  final bool manual;

  /// Si viene de una recuperación. Es independiente de [manual].
  final bool recuperada;

  /// Si la nota guardada es más vieja que la última nota de subunidad.
  ///
  /// Solo dice algo cuando es manual: la automática se recalcula sola en cada
  /// `notas/detailed`. El backend lo resuelve comparando los dos `updated_at`,
  /// en la columna `nfinal_desactualizada`.
  final bool desactualizada;

  /// Quién la tocó por última vez, tal como lo devuelve el backend: el nombre
  /// de usuario, no el del docente.
  final String? actualizadaPor;

  const NotaFinalDelLibro({
    required this.nfId,
    this.nota,
    this.automatica,
    this.manual = false,
    this.recuperada = false,
    this.desactualizada = false,
    this.actualizadaPor,
  });

  /// Sin fila en `notas_finales` no hay nada que nivelar.
  ///
  /// No debería pasar —`notas/detailed` la crea al abrir el libro— pero si
  /// pasa, más vale un control apagado que uno que manda un `nf_id` de cero.
  bool get existe => nfId != 0;

  NotaFinalDelLibro copiaCon({
    double? nota,
    bool? manual,
    bool? recuperada,
    bool? desactualizada,
  }) {
    return NotaFinalDelLibro(
      nfId: nfId,
      nota: nota ?? this.nota,
      automatica: automatica,
      manual: manual ?? this.manual,
      recuperada: recuperada ?? this.recuperada,
      desactualizada: desactualizada ?? this.desactualizada,
      actualizadaPor: actualizadaPor,
    );
  }

  /// Cómo queda tras un `definitivas_periodos/update` que entró.
  ///
  /// **Manual, siempre.** El backend escribe `SET nota=?, manual=true` en la
  /// misma sentencia: no existe cambiar el número dejándola automática. Y con
  /// razón, porque si siguiera siendo automática el próximo `notas/detailed`
  /// la borraría y la volvería a calcular.
  ///
  /// Y deja de estar desactualizada: acaba de escribirse.
  NotaFinalDelLibro trasCambiarLaNota(double nueva) =>
      copiaCon(nota: nueva, manual: true, desactualizada: false);

  /// Cómo queda tras un `toggle-manual` que entró.
  ///
  /// Quitarle «manual» le quita también «recuperada», en la misma sentencia.
  /// Una recuperada que no fuera manual se perdería al primer recálculo.
  NotaFinalDelLibro trasAlternarManual(bool nuevo) =>
      copiaCon(manual: nuevo, recuperada: nuevo ? recuperada : false);

  /// Cómo queda tras un `toggle-recuperada` que entró.
  ///
  /// Marcarla la vuelve además manual, que es lo anterior visto al derecho.
  NotaFinalDelLibro trasAlternarRecuperada(bool nuevo) =>
      copiaCon(recuperada: nuevo, manual: nuevo ? true : manual);

  /// Cómo queda después de guardar una nota de subunidad.
  ///
  /// **`notas/update` recalcula la definitiva por su cuenta**, al final del
  /// método y fuera del `try`. Así que guardar una nota cambia dos cosas y no
  /// una, y si la app solo apuntara la primera, la pestaña «Por alumno» seguiría
  /// enseñando la definitiva de antes hasta la siguiente recarga.
  ///
  /// El backend respeta las manuales y las recuperadas —las salta— y a las
  /// demás les escribe el promedio **redondeado a entero**: la consulta lo
  /// castea a `DECIMAL(4,0)`. Aquí se hace lo mismo para que lo que se ve sea
  /// lo que hay guardado y no una aproximación parecida.
  NotaFinalDelLibro trasRecalcularse(double promedio) {
    if (manual || recuperada) return this;
    return copiaCon(nota: promedio.roundToDouble(), desactualizada: false);
  }

  factory NotaFinalDelLibro.fromJson(Map<String, dynamic> json) {
    return NotaFinalDelLibro(
      nfId: enteroO(json['nf_id']),
      nota: _decimal(json['nota_final']),
      automatica: _decimal(json['def_materia_auto']),
      manual: entero(json['manual']) == 1,
      recuperada: entero(json['recuperada']) == 1,
      // `IF(nf.updated_at > max(notas.updated_at), FALSE, TRUE)`: vale 1
      // cuando la definitiva guardada es más vieja que la última nota puesta.
      // Ojo con el caso sin notas, donde la comparación es contra NULL y sale
      // 1 igualmente; por eso quien la pinte solo la enseña si es manual, que
      // es el único caso en que decir algo tiene sentido.
      desactualizada: entero(json['nfinal_desactualizada']) == 1,
      actualizadaPor: texto(json['updated_by_username']),
    );
  }
}

/// Trae el libro de notas de una asignatura.
///
/// `PUT notas/detailed` con `{asignatura_id, profesor_id, con_asignaturas}`. El
/// periodo no se manda: el backend usa el del usuario, o sea el de la barra de
/// arriba.
///
/// **Es la consulta más cara del proyecto y hay que llamarla lo menos posible.**
/// Por cada subunidad hace un `INSERT … WHERE NOT EXISTS` por alumno, y después,
/// por cada alumno, va a buscar sus ausencias, sus tardanzas, sus frases y su
/// definitiva —recalculándola si no es manual—. Con doce subunidades y treinta
/// alumnos son cientos de consultas en una sola petición, contra un hosting
/// compartido. Se pide una vez por asignatura, se guarda en memoria mientras la
/// pantalla viva, y se vuelve a pedir solo tirando hacia abajo.
///
/// Y hay que llamarla al menos una vez, porque esos inserts son los que
/// **materializan** las filas de `notas`. Sin ellas no hay `nota.id` que
/// actualizar. `PUT notas/subunidad`, que sería más barato para una sola
/// casilla, intenta lo mismo con un SQL roto —ver `docs/notas.md` §6.1—, así
/// que no sirve de atajo.
Future<LibroDeNotas> traerLibroDe(
  Server server, {
  required int asignaturaId,
  int? profesorId,
}) async {
  final res = await server.put('/notas/detailed', {
    'asignatura_id': asignaturaId,
    if (profesorId != null) 'profesor_id': profesorId,
    'con_asignaturas': false,
  });

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió el libro de notas.');
  }

  final asignatura = cuerpo['asignatura'];
  final unidades = cuerpo['unidades'];
  final alumnos = cuerpo['alumnos'];

  return LibroDeNotas(
    asignatura: AsignaturaModel.fromJson(
      asignatura is Map
          ? Map<String, dynamic>.from(asignatura)
          : {'asignatura_id': asignaturaId},
    ),
    unidades: unidades is List
        ? (unidades
            .whereType<Map>()
            .map((u) => UnidadModel.fromJson(Map<String, dynamic>.from(u)))
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden)))
        : const [],
    alumnos: alumnos is List
        ? alumnos
            .whereType<Map>()
            .map((a) => AlumnoDelLibro.fromJson(Map<String, dynamic>.from(a)))
            .where((a) => a.alumnoId != 0)
            .toList()
        : const [],
  );
}

/// La definitiva de un alumno tal como quedó después de guardar un lote.
///
/// La calcula el mismo recalculador que la escribe, así que usarla es dejar de
/// tener dos verdades: hoy la app repinta la suya y el servidor la suya, y sólo
/// coinciden mientras nadie toque una nota manual o recuperada.
class DefinitivaDelLote {
  final int alumnoId;
  final int asignaturaId;
  final int periodoId;

  /// Null cuando el alumno todavía no tiene fila de definitiva. No es cero:
  /// «sin definitiva» y «definitiva de cero» se pintan distinto.
  final double? nota;

  final bool manual;
  final bool recuperada;

  const DefinitivaDelLote({
    required this.alumnoId,
    required this.asignaturaId,
    required this.periodoId,
    this.nota,
    this.manual = false,
    this.recuperada = false,
  });

  factory DefinitivaDelLote.fromJson(Map<String, dynamic> json) {
    return DefinitivaDelLote(
      alumnoId: enteroO(json['alumno_id']),
      asignaturaId: enteroO(json['asignatura_id']),
      periodoId: enteroO(json['periodo_id']),
      nota: _decimal(json['nota']),
      manual: _bandera(json['manual']),
      recuperada: _bandera(json['recuperada']),
    );
  }
}

/// Un sí o un no del servidor, venga como venga.
///
/// El resto del archivo lo resuelve con `entero(x) == 1`, y aquí no vale: los
/// listados se arman con `DB::select` y sus columnas llegan como número o como
/// cadena según decida PDO, pero **`notas/lote` construye su respuesta en PHP
/// con un `(bool)` delante**, así que `manual` llega como `true` de verdad y
/// `entero(true)` no es 1. Aceptar las tres formas es más barato que acordarse
/// de cuál es cuál.

bool _bandera(dynamic valor) {
  if (valor is bool) return valor;
  return entero(valor) == 1;
}

/// Una nota que el docente cambió y todavía no ha salido de la app.
class NotaPendiente {
  final int notaId;
  final int alumnoId;
  final double nota;

  const NotaPendiente({
    required this.notaId,
    required this.alumnoId,
    required this.nota,
  });
}

/// Cómo fue el guardado de un lote.
class ResultadoGuardado {
  final int guardadas;

  /// Las que no entraron, para dejarlas marcadas y poder reintentarlas sin que
  /// el docente vuelva a teclear nada.
  final List<NotaPendiente> fallidas;

  /// El primer motivo que dio el servidor, para explicarlo una vez y no treinta.
  final String? motivo;

  /// Las definitivas tal como quedaron, cuando el servidor las devuelve.
  ///
  /// Sólo llega por `notas/lote`: guardando de una en una nadie las dice, y la
  /// app se queda con la suya calculada. Vacía, entonces, no significa «no hay
  /// definitivas» sino «este camino no las trae».
  final List<DefinitivaDelLote> definitivas;

  const ResultadoGuardado({
    required this.guardadas,
    this.fallidas = const [],
    this.motivo,
    this.definitivas = const [],
  });

  bool get todoBien => fallidas.isEmpty;
}

/// Cuántas notas se mandan a la vez.
///
/// No hay endpoint de lote —`notas/update/{id}` es de una en una—, así que
/// guardar una columna son N peticiones. Treinta a la vez contra un hosting
/// compartido es la forma más rápida de que empiece a rechazarlas; de tres en
/// tres tarda casi lo mismo y no lo tumba.
const int _aLaVez = 3;

/// Guarda las notas que cambiaron, unas pocas a la vez.
///
/// Solo las que cambiaron: quien llama compara con lo que trajo el servidor
/// antes de armar la lista. En el caso «puse 100 a todos y ya estaban en 100»
/// eso son cero peticiones, donde el front web hace treinta.
///
/// No revienta con la primera que falle: las demás tienen que entrar igual, y
/// las que no vuelven en [ResultadoGuardado.fallidas] para reintentarlas.
Future<ResultadoGuardado> guardarNotas(
  Server server,
  List<NotaPendiente> cambios, {
  void Function(int hechas, int total)? avance,
  /// Por qué camino. Lo decide el interruptor, y se puede forzar **sólo desde
  /// las pruebas**: con una constante a secas, el camino nuevo no se podría
  /// probar hasta el día que se encienda, que es justo cuando ya no hay margen
  /// para descubrir que no funciona.
  bool? enLote,
}) async {
  if (cambios.isEmpty) return const ResultadoGuardado(guardadas: 0);

  if (enLote ?? Interruptores.notasLote) {
    return _guardarEnLote(server, cambios, avance: avance);
  }

  final fallidas = <NotaPendiente>[];
  var guardadas = 0;
  var siguiente = 0;
  String? motivo;

  Future<void> trabajador() async {
    while (true) {
      final indice = siguiente++;
      if (indice >= cambios.length) return;

      final cambio = cambios[indice];
      final fallo = await guardarNota(
        server,
        notaId: cambio.notaId,
        nota: cambio.nota,
      );

      if (fallo == null) {
        guardadas++;
      } else {
        fallidas.add(cambio);
        motivo ??= fallo;
      }

      avance?.call(guardadas + fallidas.length, cambios.length);
    }
  }

  // Sin `siguiente` compartido cada trabajador tendría su propio índice y se
  // pisarían. Vale con una variable normal: aquí no hay hilos, y entre el `++`
  // y el `await` no se cuela nadie.
  await Future.wait([
    for (var i = 0; i < _aLaVez && i < cambios.length; i++) trabajador(),
  ]);

  return ResultadoGuardado(
    guardadas: guardadas,
    fallidas: fallidas,
    motivo: motivo,
  );
}

/// Cuántas notas van en cada petición de `notas/lote`.
///
/// **El servidor corta en 200, y pasarse no recorta: aborta el lote entero con
/// un 422.** O sea que el troceo no es una optimización, es la condición para
/// que esto funcione — y el propio controlador dejó escrito que daba por hecha
/// una capacidad de partir en tandas que el cliente **no tenía**.
///
/// Cien y no doscientas, a propósito: deja margen para que alguien baje el tope
/// del servidor sin rompernos. Una columna de un grupo grande son cuarenta y
/// cinco notas, así que en la práctica sigue siendo una sola petición y el
/// margen no cuesta nada.
const int _porLote = 100;

/// Guarda todas las notas con `PUT notas/lote`, en tandas.
///
/// Devuelve lo mismo que el camino de una en una —incluidas las fallidas con su
/// motivo— para que la pantalla no tenga que saber por cuál de los dos fue.
Future<ResultadoGuardado> _guardarEnLote(
  Server server,
  List<NotaPendiente> cambios, {
  void Function(int hechas, int total)? avance,
}) async {
  final porId = {for (final cambio in cambios) cambio.notaId: cambio};

  var guardadas = 0;
  final fallidas = <NotaPendiente>[];
  final definitivas = <DefinitivaDelLote>[];
  String? motivo;
  var procesadas = 0;

  // En tandas y en fila, no a la vez: el lote existe para quitarle trabajo al
  // servidor, y mandarle tres tandas en paralelo sería devolvérselo por otro
  // lado. Con cien por tanda, una columna cabe en una.
  for (var desde = 0; desde < cambios.length; desde += _porLote) {
    final hasta =
        desde + _porLote < cambios.length ? desde + _porLote : cambios.length;
    final tanda = cambios.sublist(desde, hasta);

    try {
      final res = await server.put('/notas/lote', {
        'notas': [
          for (final cambio in tanda)
            {'id': cambio.notaId, 'nota': cambio.nota},
        ],
      });

      if (res.statusCode >= 300) {
        // Una tanda rechazada entera —el 422 del tope, un periodo cerrado, un
        // 404 si esto se encendió antes de tiempo— no puede llevarse por
        // delante lo que ya entró en las anteriores: sus notas se marcan como
        // fallidas y el docente las reintenta sin volver a teclear.
        fallidas.addAll(tanda);
        motivo ??= res.statusCode == 400 || res.statusCode == 403
            ? 'No tienes permiso para editar notas en este periodo.'
            : motivoDeRechazo(
                res.body,
                respaldo: 'El servidor respondió ${res.statusCode}.',
              );
        procesadas += tanda.length;
        avance?.call(procesadas, cambios.length);
        continue;
      }

      final cuerpo = jsonDecode(res.body);
      if (cuerpo is! Map) throw const FormatException('respuesta inesperada');

      guardadas += enteroO(cuerpo['guardadas']);

      for (final cruda in (cuerpo['fallidas'] as List? ?? const [])) {
        if (cruda is! Map) continue;
        // Sin id no se puede saber de quién era, así que no se puede marcar la
        // casilla; el motivo sí sirve y se conserva.
        final suya = porId[entero(cruda['id'])];
        if (suya != null) fallidas.add(suya);
        motivo ??= texto(cruda['motivo']);
      }

      for (final cruda in (cuerpo['definitivas'] as List? ?? const [])) {
        if (cruda is! Map) continue;
        definitivas
            .add(DefinitivaDelLote.fromJson(Map<String, dynamic>.from(cruda)));
      }
    } catch (err) {
      fallidas.addAll(tanda);
      motivo ??= 'No se pudo guardar: $err';
    }

    procesadas += tanda.length;
    avance?.call(procesadas, cambios.length);
  }

  return ResultadoGuardado(
    guardadas: guardadas,
    fallidas: fallidas,
    motivo: motivo,
    definitivas: definitivas,
  );
}

/// Guarda una nota. Devuelve null si entró, o el motivo si no.
///
/// `PUT notas/update/{id}`. Dos códigos significan cosas distintas y ninguno
/// es «petición mal hecha»:
///
/// - **400** es el permiso: el backend lo comprueba contra el periodo de esa
///   nota concreta y responde 400 cuando está cerrado. O sea, «no te dejan».
/// - **422 es la escala**, desde que se valida en el servidor. Y ahí el motivo
///   viaja en el cuerpo —«la nota 105 no cabe en la escala del año»—, que es lo
///   único que le dice al docente qué escribir en su lugar. Antes se tiraba y
///   se le enseñaba «El servidor respondió 422.», que no es un mensaje: es un
///   número y una llamada al colegio.
Future<String?> guardarNota(
  Server server, {
  required int notaId,
  required double nota,
}) async {
  try {
    final res = await server.put('/notas/update/$notaId', {'nota': nota});

    if (res.statusCode == 400 || res.statusCode == 403) {
      return 'No tienes permiso para editar notas en este periodo.';
    }
    if (res.statusCode == 422) {
      return motivoDeRechazo(
        res.body,
        respaldo: 'La nota no cabe en la escala del año.',
      );
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo guardar: $err';
  }
}

/// Cómo se escribe una nota dentro de un campo: sin decimales cuando es
/// redonda.
///
/// Las notas llegan como decimales del servidor —un 85 puede venir como
/// '85.0'—, y un campo que dice «85.0» invita a borrar el punto antes de
/// escribir encima.
String notaEscrita(double? nota) {
  if (nota == null) return '';
  return nota == nota.roundToDouble()
      ? nota.toStringAsFixed(0)
      : nota.toString();
}

/// Lo que hay escrito en un campo de nota, o null si está vacío.
///
/// También null cuando no se entiende lo tecleado, y entonces no se manda: es
/// mejor dejar la nota sin guardar y que se vea, que mandar un número
/// inventado. La coma se acepta como separador decimal porque es la que trae
/// el teclado en español.
double? notaLeida(String crudo) {
  final limpio = crudo.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  return double.tryParse(limpio);
}

/// Un decimal del backend, o null si no vino.
///
/// Aparte por lo de siempre: estas columnas salen de SQL a pelo y llegan como
/// número o como cadena según el driver. Y aquí la diferencia entre 0 y null
/// importa —una casilla sin nota no es un cero—, así que no vale [decimalO],
/// que devuelve 0 para lo que falta.
double? _decimal(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();

  final crudo = valor.toString().trim().replaceAll(',', '.');
  if (crudo.isEmpty) return null;
  return double.tryParse(crudo);
}
