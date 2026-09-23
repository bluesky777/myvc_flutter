/// Lo que el módulo de votaciones del colegio manda a la app.
///
/// **Todo lo de aquí está leído campo por campo del `return` de su
/// controlador**, no del nombre de la ruta: `VtVotacionesController`,
/// `VtCandidatosController`, `VtVotosController` y `VtResultadosController` de
/// `8myvc`, tal como quedaron con el rediseño del 22 de septiembre de 2026
/// (`8myvc/docs/migracion/11-votaciones.md` §8). El porqué de cada decisión de
/// lectura está en `docs/votaciones.md`.
///
/// Los enteros se leen con [enteroO] y no con `as int` por lo mismo que en
/// `EstacionModel`: la mitad de estas respuestas sale de `DB::select`, y ahí el
/// tipo de cada columna lo decide PDO. `vt_votaciones` tiene además los
/// interruptores como `tinyint(1)`, que llegan **0 o 1 y no `true`/`false`**.
library;

import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Una elección abierta en la que este usuario todavía tiene algo que votar.
///
/// **Sale del login y no de una petición.** `App\Services\VotacionesPendientes`
/// se la cuelga al contexto del usuario en `POST /api/login` y en
/// `GET /api/auth/me`, y sólo cuelga las que están **abiertas y sin completar**:
/// la clave `votaciones` no aparece cuando no hay ninguna, que es contrato
/// escrito en el docblock de ese servicio —*«el frontend comprueba la existencia
/// de la clave, no su longitud»*—.
class VotacionAbierta {
  const VotacionAbierta({
    required this.id,
    required this.nombre,
    this.fechaInicio,
    this.fechaFin,
    this.bloqueada = false,
    this.enAccion = true,
    this.completos = false,
    this.conteoPublicado = false,
  });

  final int id;
  final String nombre;

  /// **Son columnas `date`, no `datetime`.** El backend compara
  /// `Reloj::ahora()->toDateString()` contra ellas, o sea que **el día entero
  /// cuenta y los dos extremos entran**: una elección con `fecha_fin` hoy se
  /// vota hoy hasta la noche (`VtVotacion::exigirUrnaAbierta`).
  ///
  /// Nulas significan «sin ventana», que no es lo mismo que «empieza y acaba
  /// hoy». Por eso son `DateTime?` y no una fecha inventada.
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  /// `locked`: la urna pausada. Votar contesta **423**.
  final bool bloqueada;

  /// `in_action`: la urna abierta ahora. Desde el rediseño **también es un
  /// candado** —votar con esto apagado contesta 423—, y eso contradice a
  /// propósito lo que el §2.1 de la 11 había decidido en agosto. Está anotado
  /// allí como decisión sin cerrar, así que la app no da por hecho que se queda:
  /// lo que niega de verdad es `votos/store`, y su mensaje es el que se enseña.
  final bool enAccion;

  /// Si a esta persona ya no le falta ningún cargo. Lo calcula el servidor
  /// (`VtVotacion::verificarVotosCompletos`), por cargos distintos.
  final bool completos;

  /// `can_see_results`. **No decide si se puede entrar a los resultados**, sólo
  /// si el conteo viaja; y al personal del colegio le viaja igual, encendido o
  /// apagado. La pantalla de resultados lee `conteo_visible` de su propia
  /// respuesta y no esto. Ver [Escrutinio].
  final bool conteoPublicado;

  factory VotacionAbierta.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};

    return VotacionAbierta(
      id: enteroO(mapa['id']),
      nombre: '${mapa['nombre'] ?? 'Votación'}'.trim(),
      fechaInicio: soloElDia(mapa['fecha_inicio']),
      fechaFin: soloElDia(mapa['fecha_fin']),
      bloqueada: enteroO(mapa['locked']) == 1,
      enAccion: enteroO(mapa['in_action']) == 1,
      completos: siONo(mapa['completos']) ?? false,
      conteoPublicado: enteroO(mapa['can_see_results']) == 1,
    );
  }

  /// Si esta urna acepta un voto ahora mismo, con lo que se sabe desde aquí.
  ///
  /// **Es una comprobación optimista y tiene que serlo**: el servidor mira
  /// además el censo, el estamento y `solo_en_mesa`, y lo hace con su reloj.
  /// Esto sirve para no ofrecer un botón que va a dar 423 seguro.
  bool get pareceAbierta => enAccion && !bloqueada;

  /// Qué decirle a quien mira la tarjeta sobre cuándo cierra.
  ///
  /// **No hay cuenta atrás de horas y no puede haberla**: `fecha_fin` es un
  /// `date`, así que lo más fino que el contrato permite decir es el día.
  /// Escribir «faltan 2 h 15 m» sería inventarse una precisión que el servidor
  /// no tiene — y el día que el reloj del teléfono vaya adelantado, mentir.
  String cuandoCierra({DateTime? ahora}) {
    final fin = fechaFin;
    if (fin == null) return 'Sin fecha de cierre';

    final hoy = ahora ?? DateTime.now();
    final dias = DateTime(fin.year, fin.month, fin.day)
        .difference(DateTime(hoy.year, hoy.month, hoy.day))
        .inDays;

    if (dias < 0) return 'Cerró el ${formatoDia(fin)}';
    if (dias == 0) return 'Cierra hoy';
    if (dias == 1) return 'Cierra mañana';
    return 'Cierra en $dias días';
  }
}

/// Un cargo de la papeleta, con sus candidatos y si esta persona ya lo votó.
///
/// La fila es `vt_aspiraciones` tal cual —de ahí que el nombre del cargo venga
/// en una clave llamada `aspiracion`—, más dos cosas que `getConaspiraciones`
/// le cuelga: `candidatos` y `votado`.
class CargoDeLaPapeleta {
  const CargoDeLaPapeleta({
    required this.id,
    required this.nombre,
    required this.abrev,
    required this.votacionId,
    required this.votado,
    required this.candidatos,
  });

  final int id;

  /// La clave del servidor es `aspiracion`. Aquí se llama nombre porque es lo
  /// que se pinta: «Personero», «Contralor».
  final String nombre;

  /// **Nunca es obligatoria y nunca es nula**: sin escribirla el backend deja la
  /// cadena vacía, y no inventa un `PER` a partir del nombre a propósito —dos
  /// cargos que empiecen igual darían la misma abreviatura—.
  final String abrev;

  /// De dónde sacar el `votacion_id` para `votos/store`: `getConaspiraciones`
  /// devuelve **la lista de cargos y no la votación**, así que el id de la
  /// elección sólo viaja aquí, en la columna de la propia fila.
  final int votacionId;

  /// **Booleano de verdad desde el 22 sep 2026.** Antes era `[]` —una lista
  /// vacía— y en JavaScript `[]` es cierto, así que el front web llevaba años
  /// creyendo que estaba todo votado. Se lee con [siONo] y no con `== true`
  /// para que un `0`, un `"1"` o un `null` de un servidor viejo no se lean al
  /// revés.
  final bool votado;

  final List<CandidatoDelTarjeton> candidatos;

  factory CargoDeLaPapeleta.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};
    final crudos = mapa['candidatos'];

    return CargoDeLaPapeleta(
      id: enteroO(mapa['id']),
      nombre: '${mapa['aspiracion'] ?? ''}'.trim(),
      abrev: '${mapa['abrev'] ?? ''}'.trim(),
      votacionId: enteroO(mapa['votacion_id']),
      votado: siONo(mapa['votado']) ?? false,
      candidatos: crudos is List
          ? crudos.map(CandidatoDelTarjeton.fromJson).toList()
          : const <CandidatoDelTarjeton>[],
    );
  }

  /// Cómo se nombra este cargo. Vacío no es un nombre: mejor decir «Cargo» que
  /// dejar el renglón en blanco y que parezca que la pantalla falló.
  String get comoSeLlama => nombre.isEmpty
      ? (abrev.isEmpty ? 'Cargo' : abrev)
      : nombre;

  /// Sólo los candidatos de verdad: el blanco tiene su propio botón abajo y no
  /// es una tarjeta más de la rejilla.
  List<CandidatoDelTarjeton> get soloCandidatos =>
      candidatos.where((c) => !c.blanco).toList();
}

/// Una opción del tarjetón: un candidato, o el voto en blanco.
///
/// ## El blanco NO es un candidato con id falso
///
/// El servidor lo mete en la misma lista —`array_push($candidatos, $blanco)`—
/// con `voto_blanco: true` y **sin `candidato_id`**, porque el voto en blanco es
/// `aspiracion_id` sin `candidato_id` (`vt_votos.candidato_id` nulo). Aquí se
/// lee igual y se marca en [blanco]: quien pinte la papeleta lo saca de la
/// rejilla de candidatos y lo pone en su botón de abajo.
///
/// **Y su `foto_nombre` es una trampa.** El servidor manda
/// `foto_nombre: 'voto_en_blanco.jpg'`, que es un archivo del front web y no
/// existe en `images/perfil`. Pasado a `AvatarPersona` eso no falla: se cae a
/// las iniciales y pinta un círculo morado con **«VE»** dentro, que es lo peor
/// de los dos mundos. Por eso [fotoNombre] queda nula cuando es el blanco.
class CandidatoDelTarjeton {
  const CandidatoDelTarjeton({
    this.candidatoId,
    this.blanco = false,
    required this.nombre,
    this.numero,
    this.plancha,
    this.grupo,
    this.fotoNombre,
  });

  /// Nulo cuando es el voto en blanco. Es lo que se manda —o no— en
  /// `votos/store`.
  final int? candidatoId;

  final bool blanco;

  /// Nombre y apellidos ya juntos. `porAspiracion()` los manda por separado y
  /// **une sólo con `alumnos`**, así que un docente no puede salir en la
  /// papeleta aunque `votan_profes` exista (11 §8, punto 6 de lo que queda).
  final String nombre;

  /// El número de la chapa. Es `varchar` en la base, así que se pinta como
  /// texto: un colegio puede escribir «01» y el cero no se puede perder.
  final String? numero;

  final String? plancha;

  /// `nombre_grupo`, y si no, `abrev_grupo`. La consulta del servidor manda
  /// `'N/A'` cuando la persona no es alumno, y eso no es un grupo: se descarta.
  final String? grupo;

  final String? fotoNombre;

  factory CandidatoDelTarjeton.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};
    final esBlanco = siONo(mapa['voto_blanco']) ?? false;

    final nombre = [mapa['nombres'], mapa['apellidos']]
        .where((parte) => parte != null && '$parte'.trim().isNotEmpty)
        .map((parte) => '$parte'.trim())
        .join(' ');

    final crudoGrupo =
        texto(mapa['nombre_grupo']) ?? texto(mapa['abrev_grupo']);

    return CandidatoDelTarjeton(
      candidatoId: entero(mapa['candidato_id']),
      blanco: esBlanco,
      nombre: nombre.isEmpty ? 'Voto en Blanco' : nombre,
      numero: texto(mapa['numero']),
      plancha: texto(mapa['plancha']),
      grupo: esBlanco || crudoGrupo == 'N/A' ? null : crudoGrupo,
      // Ver el docblock de la clase: el archivo del blanco no existe aquí.
      fotoNombre: esBlanco ? null : texto(mapa['foto_nombre']),
    );
  }
}

/// La papeleta de esta persona: los cargos de su elección abierta.
///
/// **Tres respuestas y no dos**, que es la regla de esta casa. Una lista vacía
/// de cargos y «no tienes elección» se leen igual en pantalla y no son lo
/// mismo, así que el servidor las separa con `sin_votaciones_propias` y aquí se
/// separan también:
///
///   - [sinEleccion] `true` — no hay elección para este usuario.
///   - [cargos] vacío con [sinEleccion] `false` — hay elección **sin cargos**,
///     que es una elección que el colegio dejó a medias.
class Papeleta {
  const Papeleta({required this.sinEleccion, required this.cargos});

  final bool sinEleccion;
  final List<CargoDeLaPapeleta> cargos;

  static const Papeleta ninguna =
      Papeleta(sinEleccion: true, cargos: <CargoDeLaPapeleta>[]);

  int get votacionId => cargos.isEmpty ? 0 : cargos.first.votacionId;

  List<CargoDeLaPapeleta> get faltan =>
      cargos.where((cargo) => !cargo.votado).toList();

  bool get completa => cargos.isNotEmpty && faltan.isEmpty;
}

/// Lo que queda escrito cuando un voto entra, y lo que vuelve cuando ya estaba.
///
/// **El sitio donde vive la hora del voto es éste y ningún otro.** No hay
/// ninguna ruta que le diga a una persona a qué hora votó: `votos/show` devuelve
/// papeletas, `conaspiraciones` y `en-accion-inscrito` devuelven `votado` como
/// booleano a propósito —*«se mira **si** votó, nunca **a quién**»*— y la lista
/// nominal sale sólo por `auditoria/{id}`, que es del superusuario. Así que la
/// hora se sabe por dos caminos, los dos de `votos/store`:
///
///   - **201** — el voto entró, y vuelve la fila con su `created_at`.
///   - **409** — ya había votado ese cargo, y vuelve `voto` con la constancia
///     dentro: `created_at`, el cargo, y la mesa y el asistente si lo condujo
///     alguien.
class Constancia {
  const Constancia({
    required this.aspiracionId,
    this.cargo,
    this.cuando,
    this.completo = false,
  });

  final int aspiracionId;

  /// El nombre del cargo, cuando la constancia del 409 lo trae.
  final String? cargo;

  /// **Ya en hora de Bogotá.** `vt_votos.created_at` es la única columna del
  /// sistema que se sella en UTC —`RelojUnicoTest::SELLAN_EN_UTC` lo deja
  /// escrito a propósito— y el resto guarda Bogotá. Son cinco horas, y
  /// convertir es cosa del front por decisión del backend (11 §8). Lo hace
  /// [horaDeUnVotoEnBogota].
  final DateTime? cuando;

  /// Si con este voto se acabó la papeleta. Lo cuelga `postStore` para que la
  /// pantalla no tenga que volver a preguntar.
  final bool completo;

  factory Constancia.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};

    return Constancia(
      aspiracionId: enteroO(mapa['aspiracion_id']),
      cargo: texto(mapa['aspiracion']),
      cuando: horaDeUnVotoEnBogota(mapa['created_at']),
      completo: siONo(mapa['completo']) ?? false,
    );
  }
}

/// El escrutinio de una elección, con las dos urnas dentro.
///
/// `GET resultados/{id}`. Tiene **dos formas y las dos son válidas**, y cuál
/// llega lo dice [conteoVisible]:
///
///   - `conteo_visible: true` — cargos con números, totales y participación.
///   - `conteo_visible: false` — la estructura y **ni un número**: ni el del
///     candidato, ni el blanco, ni el total, ni la participación. El colegio no
///     ha publicado el conteo.
///
/// La segunda **no es un error ni una lista vacía**, y de ahí que el campo
/// exista: sin él la pantalla pintaría ceros, que es decirle a la gente que
/// nadie votó.
class Escrutinio {
  const Escrutinio({
    required this.votacionId,
    required this.nombre,
    required this.conteoVisible,
    required this.cargos,
    this.participacion,
    this.actas = 0,
    this.votosDePapel = 0,
  });

  final int votacionId;
  final String nombre;
  final bool conteoVisible;
  final List<CargoDelEscrutinio> cargos;

  /// Nula cuando el conteo no viaja.
  final Participacion? participacion;

  /// Cuántas actas de papel hay en esta elección. Van dichas aparte porque
  /// **63 papeletas no son 63 personas**: de un montón de papeletas no se saca
  /// quién votó qué, así que el papel no entra en el porcentaje.
  final int actas;

  final int votosDePapel;

  bool get hayPapel => actas > 0 || votosDePapel > 0;

  /// Los votos contados de toda la elección: la suma de los totales de cada
  /// cargo. **Una persona vota varios cargos**, así que esto son votos y no
  /// votantes; los votantes los cuenta [Participacion].
  int get votosContados => cargos.fold(0, (suma, cargo) => suma + cargo.total);

  factory Escrutinio.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};
    final votacion =
        mapa['votacion'] is Map ? mapa['votacion'] as Map : const {};
    final crudos = mapa['cargos'];
    final origen = mapa['origen'] is Map ? mapa['origen'] as Map : const {};

    return Escrutinio(
      votacionId: enteroO(votacion['id']),
      nombre: '${votacion['nombre'] ?? 'Resultados'}'.trim(),
      conteoVisible: siONo(mapa['conteo_visible']) ?? false,
      cargos: crudos is List
          ? crudos.map(CargoDelEscrutinio.fromJson).toList()
          : const <CargoDelEscrutinio>[],
      participacion: mapa['participacion'] is Map
          ? Participacion.fromJson(mapa['participacion'])
          : null,
      actas: enteroO(origen['actas']),
      votosDePapel: enteroO(origen['papel']),
    );
  }
}

/// Un cargo del escrutinio: sus candidatos, el blanco y el total de su urna.
class CargoDelEscrutinio {
  const CargoDelEscrutinio({
    required this.aspiracionId,
    required this.nombre,
    required this.abrev,
    required this.candidatos,
    this.blanco,
    this.total = 0,
  });

  final int aspiracionId;
  final String nombre;
  final String abrev;
  final List<CasillaDelEscrutinio> candidatos;

  /// El blanco viaja aparte **y cuenta en el total**, como cuenta en una urna
  /// de verdad. Contarlo fuera era la mitad del bug del módulo viejo: un cargo
  /// con 40 votos y 8 blancos decía «total 32» y los porcentajes de los
  /// candidatos salían inflados uno por uno.
  final CasillaDelEscrutinio? blanco;

  final int total;

  factory CargoDelEscrutinio.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};
    final crudos = mapa['candidatos'];

    return CargoDelEscrutinio(
      aspiracionId: enteroO(mapa['aspiracion_id']),
      nombre: '${mapa['aspiracion'] ?? ''}'.trim(),
      abrev: '${mapa['abrev'] ?? ''}'.trim(),
      candidatos: crudos is List
          ? crudos
              .map(CasillaDelEscrutinio.fromJson)
              .where((casilla) => !casilla.blanco)
              .toList()
          : const <CasillaDelEscrutinio>[],
      blanco: mapa['blanco'] is Map
          ? CasillaDelEscrutinio.fromJson(mapa['blanco'])
          : null,
      total: enteroO(mapa['total']),
    );
  }

  String get comoSeLlama =>
      nombre.isEmpty ? (abrev.isEmpty ? 'Cargo' : abrev) : nombre;

  /// Quién ganó, para la etiqueta. Nulo si nadie tiene un voto, y nulo también
  /// **si hay empate arriba**: poner la etiqueta a uno de dos empatados es decir
  /// en la pantalla algo que el escrutinio no dice.
  CasillaDelEscrutinio? get ganador {
    if (candidatos.isEmpty) return null;

    var mejor = candidatos.first;
    var empatados = 1;

    for (final casilla in candidatos.skip(1)) {
      if (casilla.total > mejor.total) {
        mejor = casilla;
        empatados = 1;
      } else if (casilla.total == mejor.total) {
        empatados++;
      }
    }

    if (mejor.total == 0 || empatados > 1) return null;
    return mejor;
  }

  /// Los candidatos de más votado a menos. La barra se lee de arriba abajo.
  List<CasillaDelEscrutinio> get porVotos {
    final lista = [...candidatos];
    lista.sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }
}

/// Una casilla del escrutinio: un candidato, o el blanco.
class CasillaDelEscrutinio {
  const CasillaDelEscrutinio({
    this.candidatoId,
    required this.nombre,
    this.numero,
    this.plancha,
    this.blanco = false,
    this.total = 0,
    this.porcentaje = 0,
    this.dePapel = 0,
  });

  final int? candidatoId;
  final String nombre;
  final String? numero;
  final String? plancha;
  final bool blanco;
  final int total;

  /// Lo calcula el servidor sobre el total de la urna, blanco incluido. Se lee
  /// tal cual y **no se recalcula aquí**: dos mitades que dividen por su cuenta
  /// acaban enseñando dos porcentajes distintos del mismo cargo.
  final double porcentaje;

  /// Los que entraron por un acta de papel. Va al lado del total porque un
  /// candidato con 63 votos de los que 60 son de una sola acta es un dato
  /// distinto de uno con 63 repartidos.
  final int dePapel;

  factory CasillaDelEscrutinio.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};
    final origen = mapa['origen'] is Map ? mapa['origen'] as Map : const {};

    final nombre = [mapa['nombres'], mapa['apellidos']]
        .where((parte) => parte != null && '$parte'.trim().isNotEmpty)
        .map((parte) => '$parte'.trim())
        .join(' ');

    return CasillaDelEscrutinio(
      candidatoId: entero(mapa['candidato_id']),
      nombre: nombre.isEmpty ? 'Voto en Blanco' : nombre,
      numero: texto(mapa['numero']),
      plancha: texto(mapa['plancha']),
      blanco: siONo(mapa['blanco']) ?? false,
      total: enteroO(mapa['total']),
      porcentaje: decimalO(mapa['porcentaje']),
      dePapel: enteroO(origen['papel']),
    );
  }
}

/// Cuánta gente votó, sobre el censo.
///
/// **Tres cifras y son tres cosas distintas**, por eso van las tres: [votantes]
/// es gente del censo que votó y es el numerador del porcentaje;
/// [otrosVotantes] es gente que votó y **no está en el censo** —docentes,
/// acudientes, administrativos, que no tienen censo sino el interruptor de su
/// estamento—; y el papel va aparte y sin porcentaje.
class Participacion {
  const Participacion({
    this.censo = 0,
    this.votantes = 0,
    this.otrosVotantes = 0,
    this.porcentaje = 0,
    this.papeletas = 0,
    this.actas = 0,
    this.actasFirmadas = 0,
  });

  final int censo;
  final int votantes;
  final int otrosVotantes;
  final double porcentaje;
  final int papeletas;
  final int actas;
  final int actasFirmadas;

  factory Participacion.fromJson(dynamic json) {
    final mapa = json is Map ? json : const {};
    final papel = mapa['papel'] is Map ? mapa['papel'] as Map : const {};

    return Participacion(
      censo: enteroO(mapa['censo']),
      votantes: enteroO(mapa['votantes']),
      otrosVotantes: enteroO(mapa['otros_votantes']),
      porcentaje: decimalO(mapa['porcentaje']),
      papeletas: enteroO(papel['papeletas']),
      actas: enteroO(papel['actas']),
      actasFirmadas: enteroO(papel['actas_firmadas']),
    );
  }
}
