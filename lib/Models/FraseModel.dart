import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Utils/TextoPlano.dart';

/// Una frase del catálogo del colegio: la información que se le pone a un
/// alumno en el boletín además de la nota.
///
/// El catálogo es del año y lo escribe el colegio a mano, una a una —en la
/// copia de producción son más de cuatrocientas—, así que la lista se busca
/// escribiendo y no se recorre. Aquí solo se leen: crearlas y editarlas es una
/// pantalla de la web.
class FraseDelCatalogo {
  final int id;
  final String frase;

  /// 'Fortaleza', 'Debilidad', 'Oportunidad' o 'Amenaza'. Son los cuatro que
  /// ofrece el desplegable de la web; el backend guarda la cadena tal cual, así
  /// que aquí no se traduce ni se valida, se enseña.
  final String tipo;

  const FraseDelCatalogo({
    required this.id,
    required this.frase,
    this.tipo = '',
  });

  bool coincideCon(String busqueda) =>
      coincideConBusqueda('$frase $tipo', busqueda);

  factory FraseDelCatalogo.fromJson(Map<String, dynamic> json) {
    return FraseDelCatalogo(
      id: enteroO(json['id']),
      frase: '${json['frase'] ?? ''}',
      tipo: '${json['tipo_frase'] ?? ''}',
    );
  }
}

/// Una frase ya puesta a un alumno en una asignatura y un periodo.
///
/// Puede venir de dos sitios y hay que distinguirlos: si tiene [fraseId] es una
/// del catálogo —y el backend resuelve su texto con un `IFNULL`, así que si
/// alguien la edita en la web cambia también aquí—, y si no, es una escrita a
/// mano para este alumno y solo vive en su fila.
class FraseDeAlumno {
  /// El id de la fila de `frases_asignatura`, que es lo que necesita
  /// `frases_asignatura/destroy/{id}`. **No es el id de la frase del catálogo.**
  final int id;

  final String frase;

  /// De qué frase del catálogo salió, o null si se escribió a mano.
  final int? fraseId;

  final String tipo;

  const FraseDeAlumno({
    required this.id,
    required this.frase,
    this.fraseId,
    this.tipo = '',
  });

  bool get esDelCatalogo => fraseId != null && fraseId != 0;

  factory FraseDeAlumno.fromJson(Map<String, dynamic> json) {
    return FraseDeAlumno(
      id: enteroO(json['id']),
      frase: '${json['frase'] ?? ''}',
      fraseId: entero(json['frase_id']),
      tipo: '${json['tipo_frase'] ?? ''}',
    );
  }
}

/// Las frases de una lista cruda del backend, saltándose lo que no sea un
/// objeto.
List<FraseDeAlumno> frasesDeLista(dynamic crudas) {
  if (crudas is! List) return const [];

  return crudas
      .whereType<Map>()
      .map((f) => FraseDeAlumno.fromJson(Map<String, dynamic>.from(f)))
      .where((f) => f.id != 0)
      .toList();
}

// ── Las frases de un GRUPO entero ────────────────────────────────────────────
//
// Lo que devuelven y lo que reciben `GET` y `PUT frases_asignatura/grupo/{id}`,
// las dos rutas que existen para que una pantalla de preescolar pueda pintar y
// guardar un grupo de una vez. El porqué del contrato, y lo que cuestan las de
// una en una, está en `FrasesApi`.
//
// **Nada de esto sustituye a [FraseDeAlumno]**, que es lo que traen
// `notas/detailed` y `frases_asignatura/store` y sigue siendo el camino que
// corre hoy. Las dos formas conviven porque son dos respuestas distintas del
// backend, y la de aquí trae dos cosas que aquélla no tiene: el texto guardado
// en la fila aparte del que imprime el boletín, y el periodo dentro de la
// respuesta.

/// Una frase ya puesta a un alumno, tal como la devuelven las dos rutas del
/// grupo.
///
/// **[frase] y [fraseEscrita] no son el mismo texto y por eso están las dos.**
/// La consulta es `IFNULL(f.frase, fa.frase) as frase, fa.frase as
/// frase_escrita` (`FraseAsignatura::deGrupo`):
///
///  - [frase] es **lo que imprime el boletín**: el texto del catálogo cuando la
///    fila apunta a uno, y si no el suyo propio;
///  - [fraseEscrita] es **lo que hay guardado en esta fila**, que es null
///    justamente cuando la frase es del catálogo.
///
/// Con una sola no se puede escribir el guardado por lotes: una frase del
/// catálogo y una escrita a mano que digan exactamente lo mismo se leerían
/// iguales, y el `PUT` compara contra lo que la fila tiene —no contra lo que el
/// boletín enseña— para saber si un guardado cambia algo.
class FraseDelGrupo {
  /// El id de la fila de `frases_asignatura`, que es lo que el `PUT` necesita
  /// para reconocerla. **No es el id de la frase del catálogo.**
  final int id;

  /// Lo que imprime el boletín.
  final String frase;

  /// Lo guardado en esta fila, o null cuando la frase es del catálogo.
  final String? fraseEscrita;

  /// De qué frase del catálogo salió, o null si se escribió a mano.
  final int? fraseId;

  /// 'Fortaleza', 'Debilidad'… Sale del catálogo con un `LEFT JOIN`, así que una
  /// frase escrita a mano no tiene ninguno.
  final String tipo;

  /// Cuándo se escribió, tal como viene: '2018-04-02 10:11:12'.
  ///
  /// Se deja en texto crudo a propósito: hoy no se enseña en ninguna pantalla y
  /// un segundo lector de fechas es un segundo sitio donde equivocarse con la
  /// zona horaria. Quien la pinte, que la lea donde la pinta.
  final String? creadaEl;

  const FraseDelGrupo({
    required this.id,
    required this.frase,
    this.fraseEscrita,
    this.fraseId,
    this.tipo = '',
    this.creadaEl,
  });

  bool get esDelCatalogo => fraseId != null && fraseId != 0;

  /// El texto que se edita en la casilla, que es el de **esta fila** y no el del
  /// boletín: vacío si la frase es del catálogo, porque entonces la fila no
  /// guarda texto ninguno.
  ///
  /// El respaldo a [frase] es para una respuesta que no traiga `frase_escrita`
  /// —un colegio con el backend viejo, el día que alguna otra ruta devuelva
  /// estas filas—: enseñar la casilla vacía cuando hay algo escrito sería
  /// invitar a borrarlo.
  String get textoAMano => esDelCatalogo ? '' : (fraseEscrita ?? frase);

  factory FraseDelGrupo.fromJson(Map<String, dynamic> json) {
    return FraseDelGrupo(
      id: enteroO(json['id']),
      frase: '${json['frase'] ?? ''}',
      fraseEscrita: texto(json['frase_escrita']),
      fraseId: entero(json['frase_id']),
      tipo: '${json['tipo_frase'] ?? ''}',
      creadaEl: texto(json['created_at']),
    );
  }
}

/// Un alumno del grupo con las frases que tiene en esa asignatura y ese periodo.
class AlumnoConFrases {
  final int alumnoId;

  /// La matrícula con la que está en el grupo. No hace falta para escribir
  /// —el `PUT` va por `alumno_id`—, pero es lo que identifica la fila que lo
  /// puso ahí.
  final int matriculaId;

  final String nombres;
  final String apellidos;

  /// Las suyas, en el orden en que las devuelve el servidor (`fa.id`
  /// ascendente), que es el orden en que se escribieron.
  ///
  /// **Dos frases iguales no se colapsan**: la tabla no tiene más clave que la
  /// primaria y cada fila es una línea del boletín.
  final List<FraseDelGrupo> frases;

  const AlumnoConFrases({
    required this.alumnoId,
    this.matriculaId = 0,
    this.nombres = '',
    this.apellidos = '',
    this.frases = const [],
  });

  /// Como los ordena el servidor —`ORDER BY al.apellidos, al.nombres`—, que es
  /// como se busca a un niño en una lista de clase.
  String get nombreCompleto => '$apellidos $nombres'.trim();

  factory AlumnoConFrases.fromJson(Map<String, dynamic> json) {
    return AlumnoConFrases(
      alumnoId: enteroO(json['alumno_id']),
      matriculaId: enteroO(json['matricula_id']),
      nombres: '${json['nombres'] ?? ''}'.trim(),
      apellidos: '${json['apellidos'] ?? ''}'.trim(),
      frases: _frasesDelGrupoDeLista(json['frases']),
    );
  }
}

List<FraseDelGrupo> _frasesDelGrupoDeLista(dynamic crudas) {
  if (crudas is! List) return const [];

  return crudas
      .whereType<Map>()
      .map((f) => FraseDelGrupo.fromJson(Map<String, dynamic>.from(f)))
      .where((f) => f.id != 0)
      .toList();
}

/// El sobre que traen **las dos** rutas del grupo: dónde se escribió y quién
/// puede escribir, más los alumnos.
///
/// Lo único que cambia entre el `GET` y el `PUT` es `poblacion` —aquél cuenta lo
/// que hay y éste lo que escribió—, y por eso la población no vive aquí sino en
/// [PoblacionLeida] y [PoblacionGuardada].
class FrasesDelGrupo {
  final int asignaturaId;
  final int grupoId;
  final int yearId;

  /// **En qué periodo se leyó o se escribió de verdad.** Viaja en la respuesta
  /// porque es opcional en la petición: sin él manda el de la sesión, y una
  /// pantalla que no sepa cuál le tocó no puede avisar de que le tocó el que no
  /// era.
  final int periodoId;

  /// La columna del periodo (`profes_pueden_editar_notas`).
  ///
  /// **No es [puedeEscribir] y no sirve para pintar el botón**: ver allí.
  final bool periodoAbierto;

  /// **Lo que el `PUT` le va a contestar a quien está mirando**, que es contra
  /// lo que se pinta el botón de guardar.
  ///
  /// No es [periodoAbierto]: `User::permiteEditarNotas` sólo mira la columna
  /// del periodo **cuando quien llama es un docente**, así que un superusuario
  /// escribe con el periodo cerrado y un docente no. Pintar contra el periodo le
  /// da al superusuario una pantalla de solo lectura que no le corresponde, y al
  /// docente un 403 que parece un fallo de la app.
  ///
  /// Y tampoco se deduce del papel de quien entra: un secretario **sin**
  /// `is_superuser` lee las frases de cualquier grupo —el `GET` se lo permite— y
  /// no puede escribir ninguna, con el periodo abierto o cerrado. Ésta es la
  /// única respuesta a esa pregunta que no hay que reconstruir aquí.
  ///
  /// **Por defecto false**: una respuesta que no lo traiga deja la pantalla en
  /// modo lectura, que es el fallo que no pierde trabajo de nadie.
  final bool puedeEscribir;

  final List<AlumnoConFrases> alumnos;

  const FrasesDelGrupo({
    this.asignaturaId = 0,
    this.grupoId = 0,
    this.yearId = 0,
    this.periodoId = 0,
    this.periodoAbierto = false,
    this.puedeEscribir = false,
    this.alumnos = const [],
  });

  factory FrasesDelGrupo.fromJson(Map<String, dynamic> json) {
    final crudos = json['alumnos'];

    return FrasesDelGrupo(
      asignaturaId: enteroO(json['asignatura_id']),
      grupoId: enteroO(json['grupo_id']),
      yearId: enteroO(json['year_id']),
      periodoId: enteroO(json['periodo_id']),
      periodoAbierto: _siONo(json['periodo_abierto']),
      puedeEscribir: _siONo(json['puede_escribir']),
      alumnos: crudos is! List
          ? const []
          : crudos
              .whereType<Map>()
              .map((a) => AlumnoConFrases.fromJson(Map<String, dynamic>.from(a)))
              .where((a) => a.alumnoId != 0)
              .toList(),
    );
  }
}

/// La población del `GET`: lo que hay, no lo que se escribió.
class PoblacionLeida {
  final int alumnos;
  final int frases;
  final int alumnosConFrases;
  final int alumnosSinFrases;

  /// Frases vivas de esa asignatura y ese periodo que son de alumnos que **no**
  /// están matriculados hoy en el grupo: un retirado, o uno que se cambió. La
  /// pantalla no las enseña y el `PUT` no las toca.
  ///
  /// **Es `int?` a propósito**: null es *«no se miró»* —una respuesta que no trae
  /// el renglón— y 0 es *«no hay ninguna»*, y las dos cosas no se pueden leer
  /// igual. Con un 0 de respaldo, un retirado con frases sería invisible y nadie
  /// podría saber que lo es. En el grupo 3 de la copia de desarrollo son 12
  /// filas de 2 alumnos, así que el caso no es teórico.
  final int? frasesFueraDelGrupo;

  const PoblacionLeida({
    this.alumnos = 0,
    this.frases = 0,
    this.alumnosConFrases = 0,
    this.alumnosSinFrases = 0,
    this.frasesFueraDelGrupo,
  });

  /// Si el servidor contestó ese renglón. Ver [frasesFueraDelGrupo].
  bool get seMiraronLasDeFuera => frasesFueraDelGrupo != null;

  bool get hayFrasesFueraDelGrupo => (frasesFueraDelGrupo ?? 0) > 0;

  factory PoblacionLeida.fromJson(dynamic json) {
    if (json is! Map) return const PoblacionLeida();

    return PoblacionLeida(
      alumnos: enteroO(json['alumnos']),
      frases: enteroO(json['frases']),
      alumnosConFrases: enteroO(json['alumnos_con_frases']),
      alumnosSinFrases: enteroO(json['alumnos_sin_frases']),
      frasesFueraDelGrupo: entero(json['frases_fuera_del_grupo']),
    );
  }
}

/// La población del `PUT`: lo que se escribió.
///
/// Es lo que contesta un guardado en esta casa en vez de un «listo», y la
/// pantalla la usa para decir qué pasó. **[sinCambio] no es relleno**: es la
/// diferencia entre *«se guardó y no cambió nada»* y *«no se guardó»*, que es
/// justo lo que pregunta quien cree que ha perdido el trabajo.
///
/// **Los ocho no suman entre ellos**: [escritas], [cambiadas], [sinCambio] y
/// [borradas] son **filas de la tabla**, y [vacias] son **entradas del cuerpo**.
/// Una entrada vacía que traía `id` sale en las dos —no escribió nada y su fila
/// se fue—. La única igualdad que se cumple es
/// `frasesRevisadas = escritas + cambiadas + sinCambio + vacias`; las borradas
/// no estaban en el cuerpo, por definición.
///
/// **No hay contador de «saltados por periodo cerrado»**, y no es un olvido: el
/// periodo cerrado corta la petición entera con 403 antes de mirar el cuerpo, o
/// sea que no existe el guardado a medias. Quien quiera saberlo antes de mandar
/// nada tiene [FrasesDelGrupo.puedeEscribir].
class PoblacionGuardada {
  final int alumnosDelGrupo;

  /// Cuántos alumnos venían nombrados en el cuerpo. Los demás **no se miraron**,
  /// que es lo que permite guardar por partes.
  final int alumnosRevisados;

  final int frasesRevisadas;
  final int escritas;
  final int cambiadas;
  final int sinCambio;
  final int borradas;

  /// Entradas sin `frase_id` y con el texto vacío: no son una frase, no se
  /// escriben, y si traían `id` esa fila se fue.
  final int vacias;

  const PoblacionGuardada({
    this.alumnosDelGrupo = 0,
    this.alumnosRevisados = 0,
    this.frasesRevisadas = 0,
    this.escritas = 0,
    this.cambiadas = 0,
    this.sinCambio = 0,
    this.borradas = 0,
    this.vacias = 0,
  });

  /// Filas de la tabla que se movieron. Las tres que el servidor mira para
  /// decidir si el guardado dejó rastro en la auditoría.
  int get filasTocadas => escritas + cambiadas + borradas;

  /// Se guardó y no cambió nada. **No es lo mismo que no haberse guardado.**
  bool get noCambioNada => filasTocadas == 0;

  factory PoblacionGuardada.fromJson(dynamic json) {
    if (json is! Map) return const PoblacionGuardada();

    return PoblacionGuardada(
      alumnosDelGrupo: enteroO(json['alumnos_del_grupo']),
      alumnosRevisados: enteroO(json['alumnos_revisados']),
      frasesRevisadas: enteroO(json['frases_revisadas']),
      escritas: enteroO(json['escritas']),
      cambiadas: enteroO(json['cambiadas']),
      sinCambio: enteroO(json['sin_cambio']),
      borradas: enteroO(json['borradas']),
      vacias: enteroO(json['vacias']),
    );
  }
}

/// Lo que contesta el `GET`: el grupo y la población de lo leído.
class LecturaDeFrasesDelGrupo {
  final FrasesDelGrupo grupo;
  final PoblacionLeida poblacion;

  const LecturaDeFrasesDelGrupo({
    required this.grupo,
    required this.poblacion,
  });

  factory LecturaDeFrasesDelGrupo.fromJson(Map<String, dynamic> json) {
    return LecturaDeFrasesDelGrupo(
      grupo: FrasesDelGrupo.fromJson(json),
      poblacion: PoblacionLeida.fromJson(json['poblacion']),
    );
  }
}

// ── Y lo que viaja hacia allá ────────────────────────────────────────────────

/// Una frase en el cuerpo del `PUT`, que es una de tres cosas y se dice con el
/// constructor:
///
///  - [FraseParaGuardar.deLaFila] — la que ya estaba, devuelta sin tocar;
///  - [FraseParaGuardar.delCatalogo] — una del catálogo (`GET frases`);
///  - [FraseParaGuardar.aMano] — una escrita para este alumno. En la copia de
///    desarrollo son 611 de las 686 del grupo 3, o sea el caso normal.
///
/// El [id] es lo que separa «esta fila, que ya existe» de «una nueva»: con id el
/// servidor la conserva y la reescribe si cambió, y sin id la inserta. Un id que
/// no sea del alumno —o de otra asignatura, o de otro periodo— es 422 y no una
/// frase ajena reescrita en silencio.
class FraseParaGuardar {
  /// La fila de `frases_asignatura` que se está guardando, o null si es nueva.
  final int? id;

  /// La frase del catálogo, o null si va texto.
  final int? fraseId;

  /// El texto escrito a mano. Vacío cuando va [fraseId].
  final String texto;

  const FraseParaGuardar._({this.id, this.fraseId, this.texto = ''});

  /// Una del catálogo del año.
  ///
  /// El texto no viaja **y no haría falta aunque viajara**: si vienen los dos
  /// gana el `frase_id`, y el servidor guarda la columna `frase` en null a
  /// propósito para que el boletín resuelva con `IFNULL` contra el catálogo
  /// vivo. Una copia del texto envejecería mal el día que el colegio lo corrija.
  const FraseParaGuardar.delCatalogo(int fraseId, {int? id})
      : this._(id: id, fraseId: fraseId);

  /// Una escrita a mano.
  ///
  /// **Con el texto vacío no es una frase**: el servidor no la escribe —la
  /// cuenta en `vacias`— y, si traía [id], esa fila se va con las que no
  /// vinieron. Es lo que pasa cuando el docente borra la casilla y guarda, y es
  /// lo que evita que la pantalla tenga que distinguir «la vacié» de «no la
  /// mandé» dentro de la lista de un alumno.
  const FraseParaGuardar.aMano(String texto, {int? id})
      : this._(id: id, texto: texto);

  /// La que ya estaba, tal como vino del `GET`, para devolverla sin cambiarla.
  ///
  /// Se manda **lo que guarda la fila** y no lo que imprime el boletín: para una
  /// del catálogo viaja su `frase_id`, no el texto que el `IFNULL` resolvió. Con
  /// el texto se convertiría en escrita a mano y dejaría de seguir al catálogo.
  ///
  /// Una fila con id 0 —que el servidor no manda, pero una lista a medio
  /// construir sí puede tener— viaja **como nueva**: `0` no es un identificador
  /// para el servidor y sería un 422 en vez de una frase.
  factory FraseParaGuardar.deLaFila(FraseDelGrupo fila) {
    final id = fila.id == 0 ? null : fila.id;

    return fila.esDelCatalogo
        ? FraseParaGuardar.delCatalogo(fila.fraseId!, id: id)
        : FraseParaGuardar.aMano(fila.textoAMano, id: id);
  }

  Map<String, dynamic> paraElCuerpo() => {
        if (id != null) 'id': id,
        if (fraseId != null) 'frase_id': fraseId else 'frase': texto,
      };
}

/// **La lista COMPLETA** de las frases de un alumno en esa asignatura y ese
/// periodo, que es lo que significa el `PUT`: lo que no viene, se va.
///
/// **[frases] no tiene valor por defecto y no puede ser null a propósito.** El
/// servidor distingue dos cosas que se parecen y no son iguales: `frases: []` es
/// *«quítaselas todas»* y omitir la clave es **422**, porque «la vacié» y «no la
/// mandé» tienen que poder decirse distinto. Con esta clase la segunda no se
/// puede escribir sin querer: para no tocar a un alumno **no se le nombra**, o
/// sea que no se construye su [FrasesDeUnAlumno] — y lo que no se construye no
/// viaja.
///
/// Y eso es también lo que hace seguro guardar por partes: un alumno que no
/// viene en el cuerpo no se mira, así que una pantalla que guarde de a poco —o
/// que pagine— no le puede borrar las frases a nadie por omisión.
class FrasesDeUnAlumno {
  final int alumnoId;

  /// Todas las suyas. `[]` es «quítaselas todas».
  final List<FraseParaGuardar> frases;

  const FrasesDeUnAlumno({required this.alumnoId, required this.frases});

  /// Las que ya tenía, tal como vinieron, para reenviarlas sin cambiarlas.
  ///
  /// Un guardado así entero cuenta en `sin_cambio` y no escribe ninguna fila ni
  /// ninguna línea de auditoría, que es lo normal en un reguardado.
  factory FrasesDeUnAlumno.deLoLeido(AlumnoConFrases alumno) {
    return FrasesDeUnAlumno(
      alumnoId: alumno.alumnoId,
      frases: alumno.frases.map(FraseParaGuardar.deLaFila).toList(),
    );
  }

  Map<String, dynamic> paraElCuerpo() => {
        'alumno_id': alumnoId,
        'frases': frases.map((f) => f.paraElCuerpo()).toList(),
      };
}

/// Un sí o un no del backend.
///
/// `periodo_abierto` y `puede_escribir` los calcula PHP y llegan como booleanos
/// de verdad, pero esta familia se arma con `DB::select` y lo que salga de una
/// columna lo decide PDO, así que `1` y `"1"` también se entienden. El
/// [respaldo] es para la respuesta que no traiga el campo.
bool _siONo(dynamic valor, {bool respaldo = false}) {
  if (valor == null) return respaldo;
  if (valor is bool) return valor;

  final numero = entero(valor);
  if (numero != null) return numero != 0;

  final crudo = '$valor'.trim().toLowerCase();
  if (crudo == 'true') return true;
  if (crudo == 'false') return false;

  return respaldo;
}
