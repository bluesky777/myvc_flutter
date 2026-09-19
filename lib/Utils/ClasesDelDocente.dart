/// El alcance del docente en el plan de área: qué clases tiene y dónde escribe.
///
/// **Por qué existe este fichero.** El plan de área por competencias se escribe
/// por **(materia, grado, periodo)** y no por asignatura —`desempenos_por_
/// defecto`, ver `docs/competencias.md` §1—. Un docente con «6.ºA Matemáticas»
/// y «6.ºB Matemáticas» tiene DOS asignaturas y **una sola fila** de
/// competencias: una pantalla que liste asignaturas le enseña las mismas cuatro
/// competencias dos veces, y al editar una la otra cambia sola. Así que las
/// asignaturas se colapsan en pares (materia, grado) **diciendo a qué grupos
/// alcanza cada clase**, que es lo que el docente necesita leer para no dudar
/// de si lo que escribe sale en el boletín de un grupo o de tres.
///
/// Aquí no hay widgets ni peticiones: sólo la regla.
library;

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Utils/ConfiguracionColegio.dart';

/// El permiso de colegio que abre el plan de área entero.
///
/// Es `Autoriza::PERMISO_PLANTILLA_NOTAS`, sembrado por la migración
/// `2026_09_05_300000_create_permiso_can_edit_plantilla_notas`, que **no se lo
/// da a ningún rol**: el día del despliegue la pantalla es de los superusuarios
/// de cada colegio, y repartirlo es una fila desde la pantalla de roles.
const String permisoPlantillaNotas = 'can_edit_plantilla_notas';

/// Una clase del docente: una materia en un grado, con todos sus grupos.
///
/// Es la unidad en la que se escribe el plan de área, y por eso la pantalla
/// lista esto y no asignaturas.
class ClaseDelDocente {
  const ClaseDelDocente({
    required this.materiaId,
    required this.gradoId,
    required this.materia,
    this.aliasMateria,
    this.grado,
    this.gruposIds = const [],
    this.gruposAbrev = const [],
    this.asignaturaIds = const [],
    this.esMia = false,
  });

  /// La fila **del colegio**: una materia para «todos los grados».
  ///
  /// No sale nunca de [clasesDelDocente] —una asignatura vive en un grupo, y
  /// ese grupo tiene grado—: se construye cuando hay que preguntarle a
  /// [puedeEscribirEn] por las filas de `grado_id IS NULL` que escribió
  /// coordinación. La respuesta, salvo para el colegio, es que no; el porqué
  /// está en [puedeEscribirEn].
  const ClaseDelDocente.todosLosGrados({
    required this.materiaId,
    required this.materia,
    this.aliasMateria,
  })  : gradoId = null,
        grado = null,
        gruposIds = const [],
        gruposAbrev = const [],
        asignaturaIds = const [],
        esMia = false;

  final int materiaId;

  /// Nulo sólo en la fila del colegio. Ver [ClaseDelDocente.todosLosGrados].
  final int? gradoId;

  final String materia;

  /// Cómo abrevia el colegio la materia, cuando la abrevia.
  final String? aliasMateria;

  /// El nombre del grado —«Sexto», «6.º»—, **que esta ruta no trae**: el SELECT
  /// de `Profesor::asignaturas` junta `grados` sólo para el
  /// `nivel_educativo_id`. Queda nulo hasta que alguien lo cruce con
  /// `GET /grupos`, y la pantalla sabe vivir sin él.
  final String? grado;

  /// A qué grupos alcanza esta clase. **Es lo que hay que enseñar**: sin ellos
  /// el docente ve «Matemáticas · Sexto» y no sabe si eso toca a su 6.ºA, a su
  /// 6.ºB o a los dos, y lo que escriba sale en los boletines de todos.
  final List<int> gruposIds;
  final List<String> gruposAbrev;

  /// Las asignaturas que se colapsaron aquí. Para navegar de vuelta.
  final List<int> asignaturaIds;

  /// Si esta clase es de **quien está mirando**, que no es lo mismo que estar
  /// en la lista que tiene delante.
  ///
  /// `GET asignaturas/listasignaturas/{profesor_id}` deja a un administrativo
  /// abrir las asignaturas **de otro**, y ésas no son suyas: es la rama 2 del
  /// permiso, y sin esto la pantalla le pintaría botones que el servidor va a
  /// contestar con 403. Lo decide [clasesDelDocente] comparando `profesor_id`
  /// con la **ficha** de quien mira; ver allí, que la comparación tiene trampa.
  final bool esMia;

  /// Cómo se nombra la materia: el alias cuando lo hay.
  String get nombreMateria {
    final alias = aliasMateria?.trim() ?? '';
    return alias.isEmpty ? materia : alias;
  }
}

/// Lo que sale de agrupar las asignaturas de un docente: las clases, y cuántas
/// asignaturas se quedaron fuera.
class ClasesYRestos {
  const ClasesYRestos({required this.clases, required this.sinResolver});

  /// Las clases, ya ordenadas por grado y por materia.
  final List<ClaseDelDocente> clases;

  /// Cuántas asignaturas se descartaron por no traer `materia_id` o `grado_id`.
  ///
  /// **No es un contador de errores: es lo que la pantalla tiene que decir.**
  /// Hoy el backend no manda esos dos ids en ningún colegio —están escritos en
  /// `Profesor::asignaturas` desde el 19 sep 2026, `fe95da8`, **sin fundir a
  /// `main` y sin desplegar**—, así que contra el servidor de hoy [clases] sale
  /// **vacía** y todas las asignaturas se cuentan aquí. Una lista vacía y un
  /// «tu colegio todavía no tiene esto» **se leen igual en la pantalla y no son
  /// lo mismo**: lo primero parece que el docente no da clase, o que la app se
  /// rompió. Por eso se cuentan aparte y la pantalla lo explica.
  ///
  /// Y no desaparece el día del despliegue: una asignatura cuya materia o cuyo
  /// grupo se borró en medio del año vuelve a caer aquí, y callarla sería
  /// perderla de la pantalla sin decirlo.
  final int sinResolver;

  bool get hayClases => clases.isNotEmpty;

  /// Si no se pudo resolver **nada** habiendo asignaturas: el caso exacto del
  /// backend sin desplegar, y el que la pantalla nombra de otra manera.
  bool get todoSinResolver => clases.isEmpty && sinResolver > 0;
}

/// Agrupa las asignaturas del docente en clases, por (materia, grado).
///
/// Dos grupos de la misma materia y el mismo grado son **una** clase con dos
/// grupos; dos grados distintos son dos clases aunque la materia sea la misma.
/// Los grupos se acumulan en el orden en que vienen —que es el del backend,
/// `order by g.orden, a.orden`— y no se repiten.
///
/// Las asignaturas sin `materia_id` o sin `grado_id` **se descartan y se
/// cuentan** en [ClasesYRestos.sinResolver]; el porqué está escrito allí.
///
/// [ClaseDelDocente.esMia] sale de comparar `profesor_id` con
/// `AuthService.user.personaId`, **que es el id de la ficha y no el de la
/// cuenta**: para un `Profesor` es `profesores.id`, que es con lo que casa
/// `asignaturas.profesor_id`, pero para un `Usuario` administrativo es
/// `users.id`, un número que casaría con la ficha de **otra persona**. Por eso
/// se exige además `tipo == 'Profesor'`, igual que hace el backend, y no basta
/// con el rol. Es la misma línea que en `Autoriza::puedeEscribirDesempenos`.
///
/// El orden es por grado y luego por materia, con las cadenas normalizadas
/// —minúsculas, sin tildes, la ñ después de la n y los números comparados como
/// números, para que «10.º» vaya después de «2.º» y no antes—. Como el nombre
/// del grado no viene en esta ruta, el desempate cae en la práctica en
/// `grado_id`, o sea el orden en que el colegio creó los grados.
ClasesYRestos clasesDelDocente(List<AsignaturaModel> asignaturas) {
  final usuario = AuthService.user;
  final fichaPropia = usuario.tipo == 'Profesor' ? usuario.personaId : null;

  final porPar = <String, _Acumulador>{};
  var sinResolver = 0;

  for (final asignatura in asignaturas) {
    final materiaId = asignatura.materiaId;
    final gradoId = asignatura.gradoId;

    if (materiaId == null || gradoId == null) {
      sinResolver++;
      continue;
    }

    final acumulador = porPar.putIfAbsent(
      '$materiaId·$gradoId',
      () => _Acumulador(materiaId: materiaId, gradoId: gradoId),
    );

    acumulador.sumar(
      asignatura,
      esMia: fichaPropia != null && asignatura.profesorId == fichaPropia,
    );
  }

  final clases = porPar.values.map((a) => a.clase()).toList()
    ..sort((a, b) {
      final porGrado = _clave(a.grado ?? '').compareTo(_clave(b.grado ?? ''));
      if (porGrado != 0) return porGrado;

      final porGradoId = (a.gradoId ?? 0).compareTo(b.gradoId ?? 0);
      if (porGradoId != 0) return porGradoId;

      final porMateria =
          _clave(a.nombreMateria).compareTo(_clave(b.nombreMateria));
      if (porMateria != 0) return porMateria;

      return a.materiaId.compareTo(b.materiaId);
    });

  return ClasesYRestos(clases: clases, sinResolver: sinResolver);
}

/// Por qué **no** se puede escribir. Son dos candados distintos, y por eso se
/// devuelve cuál: uno se abre solo el lunes que viene y el otro no se abre
/// nunca sin que alguien haga algo.
enum MotivoSinEscritura {
  /// El periodo está cerrado para los docentes.
  periodoCerrado,

  /// Esa materia en ese grado no es suya —o es una fila del colegio, que
  /// alcanza a grados que no da—.
  noEsMia,
}

/// Si se puede escribir el plan de área de una clase, y si no, por qué no.
class PermisoDeEscritura {
  const PermisoDeEscritura._({
    required this.explicacion,
    this.motivo,
    this.porElColegio = false,
  });

  /// Sí, por el permiso de colegio o por ser superusuario.
  const PermisoDeEscritura.porElColegio()
      : this._(
          porElColegio: true,
          explicacion: 'Escribes el plan de área de cualquier materia y grado,'
              ' con el periodo abierto o cerrado.',
        );

  /// Sí, por ser una clase suya y estar el periodo abierto.
  const PermisoDeEscritura.porSerSuya()
      : this._(explicacion: 'Es tu clase y el periodo está abierto.');

  const PermisoDeEscritura.periodoCerrado()
      : this._(
          motivo: MotivoSinEscritura.periodoCerrado,
          explicacion: 'Este periodo está cerrado: mientras lo esté, el plan de'
              ' área de tu clase no se puede cambiar.',
        );

  const PermisoDeEscritura.delColegio()
      : this._(
          motivo: MotivoSinEscritura.noEsMia,
          explicacion: 'Esto vale para todos los grados: lo escribe'
              ' coordinación.',
        );

  const PermisoDeEscritura.noEsSuya()
      : this._(
          motivo: MotivoSinEscritura.noEsMia,
          explicacion: 'Esa materia en ese grado no es tuya: la escribe quien'
              ' la da, o coordinación.',
        );

  /// Nulo cuando sí se puede.
  final MotivoSinEscritura? motivo;

  /// Por qué rama entró. **Distingue quién paga el periodo cerrado** —el
  /// colegio no—, que es lo mismo que mira `DesempenosController` antes de
  /// exigir el periodo abierto.
  final bool porElColegio;

  /// La frase del candado. La pantalla la pinta tal cual en vez de un botón que
  /// va a dar 403; cuando [puede] es verdad explica por qué sí, y no se enseña.
  final String explicacion;

  bool get puede => motivo == null;
}

/// Si quien está mirando puede escribir el plan de área de [clase].
///
/// > **ESTO ES UNA COPIA DE UNA REGLA QUE VIVE EN EL BACKEND.** El original es
/// > `8myvc/app/Support/Autoriza.php::puedeEscribirDesempenos` (línea 640), que
/// > se apoya en `puedeEditarPlantillaNotas` (línea 576), más el periodo
/// > abierto que añade `DesempenosController::exigirEscrituraDelPlan` (línea
/// > 654). Leído sobre `main` en **`ebbae74`**. **Si allí cambia, hay que
/// > cambiarlo aquí**: no hay ningún endpoint que conteste «¿puedo?», y ése es
/// > el precio conocido de no haberlo estrenado —discutido y aceptado en
/// > `docs/competencias.md` §5.1, «Por qué se cayó la ruta»—. Lo que decide de
/// > verdad sigue siendo el servidor; esto sólo evita pintar un botón que va a
/// > contestar 403, así que equivocarse aquí no abre nada: estrecha de más o
/// > enseña un botón que después falla.
///
/// Verdad si se cumple **una** de las dos ramas:
///
///  1. **el colegio** — `can_edit_plantilla_notas` en `perms`, o superusuario:
///     escribe en cualquier (materia, grado), y **el periodo cerrado no le
///     afecta**. Es a propósito: el coordinador cierra las notas *para*
///     congelar las notas, y sigue teniendo que poder montar el plan de área.
///  2. **el docente** — da esa materia en ese grado y en este año, o sea
///     [ClaseDelDocente.esMia]; y **además el periodo tiene que estar abierto**
///     —`profes_pueden_editar_notas`—, que es lo que decide en toda esta API
///     quién escribe en un periodo.
///
/// Las dos piezas que no son de estilo, y están copiadas del original:
///
/// **`gradoId == null` sólo pasa por la rama 1.** Una fila de «todos los
/// grados» alcanza a grados que el docente no da, así que dejársela editar
/// sería darle por la puerta de atrás el alcance que el permiso le niega por la
/// de delante. Por eso el corte va **antes** de mirar si la clase es suya.
///
/// **La rama 2 mira la ficha y no la cuenta**, y no es defensivo; el porqué
/// está en [clasesDelDocente], que es quien calcula [ClaseDelDocente.esMia].
///
/// [config] es la del colegio —`ContextoAcademico.instancia.config`—, y de ahí
/// sale `profesPuedenEditarNotas`, **la bandera del periodo de la barra de
/// arriba**. Ojo con eso: el backend comprueba la bandera **del periodo de la
/// fila que se escribe**, así que una pantalla que deje copiar el plan a otro
/// periodo estaría mirando la bandera equivocada y tendría que traerse la del
/// periodo destino. No se usa `ConfiguracionColegio.puedeEditarNotas`, que es
/// la regla de las **notas** —con su superusuario y su `tipo == 'Profesor'`
/// dentro— y aquí las dos ramas se deciden por separado.
PermisoDeEscritura puedeEscribirEn(
  ClaseDelDocente clase, {
  required ConfiguracionColegio config,
}) {
  final usuario = AuthService.user;

  // Rama 1. El periodo no se mira, y eso es la mitad de la decisión.
  if (usuario.isSuperuser || usuario.tienePermiso(permisoPlantillaNotas)) {
    return const PermisoDeEscritura.porElColegio();
  }

  // «Todos los grados» es sólo del colegio, y el corte va aquí arriba.
  if (clase.gradoId == null) {
    return const PermisoDeEscritura.delColegio();
  }

  if (!clase.esMia) {
    return const PermisoDeEscritura.noEsSuya();
  }

  // Y sólo ahora el periodo: al revés, quien no da la materia recibiría «el
  // periodo está cerrado», que es verdad y no es su problema.
  if (!config.profesPuedenEditarNotas) {
    return const PermisoDeEscritura.periodoCerrado();
  }

  return const PermisoDeEscritura.porSerSuya();
}

/// Lo que se va acumulando de cada par (materia, grado) mientras se recorre.
class _Acumulador {
  _Acumulador({required this.materiaId, required this.gradoId});

  final int materiaId;
  final int gradoId;

  String materia = '';
  String? aliasMateria;
  bool esMia = false;

  final List<int> gruposIds = [];
  final List<String> gruposAbrev = [];
  final List<int> asignaturaIds = [];

  void sumar(AsignaturaModel asignatura, {required bool esMia}) {
    // El primero que traiga nombre manda: dos asignaturas del mismo par tienen
    // la misma materia, pero una puede venir con el alias vacío.
    if (materia.isEmpty) materia = asignatura.materia;
    if ((aliasMateria ?? '').isEmpty && asignatura.aliasMateria.isNotEmpty) {
      aliasMateria = asignatura.aliasMateria;
    }

    // Con `any` y no con `every`, que es lo que hace el `EXISTS` del backend:
    // basta una asignatura suya en ese par para que la clase sea suya.
    this.esMia = this.esMia || esMia;

    asignaturaIds.add(asignatura.id);

    if (!gruposIds.contains(asignatura.grupoId)) {
      gruposIds.add(asignatura.grupoId);
      gruposAbrev.add(asignatura.abrevGrupo);
    }
  }

  ClaseDelDocente clase() => ClaseDelDocente(
        materiaId: materiaId,
        gradoId: gradoId,
        materia: materia,
        aliasMateria: aliasMateria,
        gruposIds: List.unmodifiable(gruposIds),
        gruposAbrev: List.unmodifiable(gruposAbrev),
        asignaturaIds: List.unmodifiable(asignaturaIds),
        esMia: esMia,
      );
}

/// Las letras que el español ordena aparte.
const Map<String, String> _equivalencias = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  // La ñ va después de toda la n y antes de la o: '~' es mayor que cualquier
  // letra, así que 'n~' cae justo donde el español la pone.
  'ñ': 'n~',
};

/// La cadena con la que se compara: minúsculas, sin tildes y con los números
/// rellenos a la izquierda.
///
/// Sin lo último «10.º» iría antes que «2.º», que es lo que hace un `compareTo`
/// a secas y lo que el docente lee como un fallo.
String _clave(String texto) {
  final buffer = StringBuffer();

  for (final caracter in texto.trim().toLowerCase().split('')) {
    buffer.write(_equivalencias[caracter] ?? caracter);
  }

  return buffer.toString().replaceAllMapped(
        RegExp(r'\d+'),
        (coincidencia) => coincidencia[0]!.padLeft(6, '0'),
      );
}
