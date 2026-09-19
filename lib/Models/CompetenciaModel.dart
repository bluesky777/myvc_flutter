import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Una competencia del plan de área: **una frase, y no lleva nota**.
///
/// El modelo es plano y cabe entero en una tabla —`desempenos_por_defecto`:
/// `id · year_id · materia_id · grado_id NULL · periodo_id · tipo NULL ·
/// definicion · orden`—, y no hay ninguna otra. No hay copia por asignatura que
/// sembrar ni casilla que marcar por alumno: el nivel lo **deriva el boletín**
/// de la definitiva de esa asignatura en ese periodo. El contrato es
/// `8myvc/docs/migracion/39-el-modelo-plano-por-competencias.md` §1, y en la app
/// está contado en `docs/competencias.md`.
///
/// El año no viaja en ningún sitio porque no se elige: `getPlantilla` filtra por
/// `d.year_id = $user->year_id`, o sea el año del token.
///
/// Llega de `GET desempenos` y también de `POST desempenos` y
/// `PUT desempenos/{id}`, que contestan **la fila entera ya guardada** y no un
/// acuse: por eso quien crea o edita puede repintar sin volver a preguntar.
class Competencia {
  const Competencia({
    required this.id,
    required this.definicion,
    required this.materiaId,
    required this.periodoId,
    this.tipo,
    this.orden = 0,
    this.gradoId,
  });

  final int id;

  /// La frase que se imprime en el boletín, delante del prefijo de la banda.
  ///
  /// El servidor la exige no vacía y de hasta 2000 caracteres
  /// (`DesempenosController::MAXIMO`); pasarse es un 422 con el número dentro.
  final String definicion;

  /// La marca opcional: «Saber», «Cognitivo», «Actitudinal»… o nada.
  ///
  /// **Es texto libre, no un enum, y nunca hubo un mínimo de tres.** En el
  /// esquema es un `varchar(60)` anulable que nace vacío, y `tipo()` en el
  /// controlador convierte a null tanto el campo ausente como la cadena vacía.
  /// Se escribe aquí porque el mockup del que viene la pantalla pintaba una
  /// Saber, una Hacer y una Ser, y se leía como un trío obligatorio que el
  /// backend no pide (`docs/competencias.md` §3.3, decisión 3).
  final String? tipo;

  /// La posición dentro de su grupo (materia · grado · periodo).
  ///
  /// **La pone el servidor y la app no la manda nunca**: al crear, `postPlantilla`
  /// calcula `MAX(orden) + 1` del grupo si el cuerpo no trae `orden`. Ver
  /// [competenciasDeLista] para por qué tampoco se reordena al pintar.
  final int orden;

  /// El grado al que alcanza la fila, o null cuando vale para todos.
  final int? gradoId;

  final int materiaId;
  final int periodoId;

  /// Si la fila es del colegio, o sea de las que el docente ve y no toca.
  ///
  /// `grado_id IS NULL` significa «todos los grados», y eso **alcanza a grados
  /// que ese docente no da**: dejársela editar sería darle por la puerta de
  /// atrás el alcance que el permiso le niega por la de delante. Por eso
  /// `Autoriza::puedeEscribirDesempenos` con `$gradoId === null` sólo pasa por
  /// la rama del colegio (`can_edit_plantilla_notas`), y un docente que intente
  /// escribirla recibe un 403 —§3 del contrato del backend—.
  ///
  /// La pantalla lo usa para agrupar, no para poner un candadito por fila: las
  /// del colegio van bajo su propio rótulo y sin botones, que es la única forma
  /// de que el candado se explique una vez y nadie pulse con el pulgar algo que
  /// va a contestar 403.
  bool get esDelColegio => gradoId == null;

  /// La misma fila con otro texto y otra marca, sin volver a preguntar.
  ///
  /// Es para el hueco que deja `PUT desempenos/{id}`: contesta la fila entera,
  /// así que lo normal es quedarse con lo que contestó. Esto es el respaldo para
  /// cuando ese cuerpo no se puede leer — se sabe qué se mandó y que el servidor
  /// dijo que sí, y repintar con eso es más honrado que dejar en pantalla el
  /// texto viejo.
  ///
  /// Los dos van obligatorios **y [tipo] puede ser null**: null aquí es «sin
  /// marca», no «déjala como estaba», que es exactamente lo que significa en el
  /// cuerpo del `PUT`.
  Competencia con({required String definicion, required String? tipo}) {
    return Competencia(
      id: id,
      definicion: definicion,
      tipo: tipo,
      orden: orden,
      gradoId: gradoId,
      materiaId: materiaId,
      periodoId: periodoId,
    );
  }

  factory Competencia.fromJson(Map<String, dynamic> json) {
    return Competencia(
      id: enteroO(json['id']),
      definicion: '${json['definicion'] ?? ''}',
      // `texto` y no `as String?`: deja en null tanto la marca que no vino como
      // la cadena vacía, que son lo mismo para quien la pinta.
      tipo: texto(json['tipo']),
      orden: enteroO(json['orden']),
      // `entero` sin respaldo, porque aquí el null **significa** algo: es
      // «todos los grados» y no un dato que falte. Ver [esDelColegio].
      gradoId: entero(json['grado_id']),
      materiaId: enteroO(json['materia_id']),
      periodoId: enteroO(json['periodo_id']),
    );
  }
}

/// Las competencias de una lista cruda del backend, **en el orden en que
/// vinieron**.
///
/// **Esto no ordena nada, y es a propósito.** El orden lo hace el servidor y los
/// tres sitios que lo tocan coinciden: `getPlantilla` —la que se lee aquí—
/// ordena por `d.materia_id, d.grado_id, d.periodo_id, d.orden, d.id`, y en
/// MySQL un `ORDER BY` ascendente pone los `NULL` **delante**, así que las filas
/// de «todos los grados» llegan arriba de las del grado; el boletín consigue lo
/// mismo con `ORDER BY grado_id IS NOT NULL, orden, id`. Reordenar aquí —por
/// `orden` a secas, que es lo que sale solo— rompería esa coincidencia y el
/// papel saldría en un orden distinto del de la pantalla.
///
/// Se salta lo que no sea un objeto y las filas sin `id` legible: una fila así
/// no se puede ni editar ni borrar, y pintarla es ofrecer botones que van a
/// fallar. Es lo mismo que hace `frasesDeLista`.
List<Competencia> competenciasDeLista(dynamic crudas) {
  if (crudas is! List) return const [];

  return crudas
      .whereType<Map>()
      .map((c) => Competencia.fromJson(Map<String, dynamic>.from(c)))
      .where((c) => c.id != 0)
      .toList();
}
