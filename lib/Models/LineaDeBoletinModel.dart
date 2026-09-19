/// Las líneas que el boletín por competencias imprime **debajo de la nota de
/// cada asignatura**.
///
/// Una línea es una frase ya montada —«Fortaleza en interpretar gráficas…»— y
/// viene de dos sitios distintos que el servidor mezcla en una sola lista, en
/// este orden: **el plan de área de la asignatura** (`desempenos_por_defecto`,
/// `origen: 'catalogo'`) y, al final, **las frases que el docente escribió para
/// ESE alumno** (`frases_asignatura`, `origen: 'frase'`).
///
/// La forma la monta `BoletinPorCompetenciasController::ponerLosDesempenos`
/// (8myvc, l. 549) y aquí sólo se lee. Las tres reglas que hay que respetar al
/// pintarlas están en [LineaDeBoletin.texto], [LineaDeBoletin.nivel] y
/// [AsignaturaDelBoletin.lineas], y ninguna es de estilo.
library;

import 'package:myvc_flutter/Utils/FormatoDeNota.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// De dónde salió una línea, que es lo que decide qué se puede decir de ella.
enum OrigenDeLinea {
  /// Una fila del plan de área de la materia: la escribió el colegio, vale para
  /// todos los alumnos de ese grado y **lleva el nivel de la asignatura**.
  catalogo,

  /// Una frase que el docente escribió para **este** alumno. Va al final y
  /// **nunca lleva nivel**. Ver [LineaDeBoletin.nivel].
  frase,
}

/// Por qué una asignatura imprime sus líneas sin nivel.
///
/// Son dos cosas distintas y el servidor las separa a propósito
/// (`motivo_del_nivel`): quien lo pinte no debería juntarlas, porque sólo una
/// de las dos es un fallo del colegio.
enum MotivoSinNivel {
  /// El docente no ha puesto la definitiva de esa asignatura en ese periodo.
  /// No hay nota que traducir.
  sinDefinitiva,

  /// Sí hay definitiva y **ninguna banda de la escala la cubre**: la nota es
  /// `DECIMAL(7,4)` y las bandas siguen siendo enteras, así que hay un hueco en
  /// cada frontera. Ya pasa hoy en los tres boletines de siempre, con 200 y sin
  /// una línea en el log.
  sinBanda,
}

/// Una línea del boletín: **una frase que se pinta tal cual**.
class LineaDeBoletin {
  const LineaDeBoletin({
    required this.texto,
    required this.origen,
    this.desempenoId,
    this.fraseAsignaturaId,
    this.tipo,
    this.orden,
    this.gradoId,
    this.escalaId,
    this.nivel,
    this.iconoInfantil,
    this.iconoAdolescente,
  });

  /// La fila del plan de área, cuando la línea viene de ahí. Null en las
  /// frases escritas a mano.
  final int? desempenoId;

  /// La fila de `frases_asignatura`, cuando la línea es una frase del docente.
  /// Null en las del catálogo.
  final int? fraseAsignaturaId;

  /// La línea entera, **con el prefijo de la banda ya montado delante**.
  ///
  /// «Fortaleza en interpretar gráficas…» llega así, en un solo campo: lo arma
  /// el servidor en `BoletinPorCompetenciasController::conElPrefijo`, que pega
  /// `escalas_de_valoracion.descripcion` —la frase del SIEE de la banda en la
  /// que cayó la definitiva— delante del texto de la competencia.
  ///
  /// **La app no lo arma, y eso es lo que hay que no hacer aquí.** Montarlo
  /// otra vez con [nivel] o con la escala sería un segundo sitio donde vive la
  /// misma regla, y los dos se separan el día que alguien toque uno: el papel
  /// que va a casa diría una cosa y la pantalla otra, sin que nadie vea el
  /// momento en que dejaron de coincidir.
  ///
  /// Se pinta **tal cual**, sin recortar ni tocar mayúsculas. El servidor
  /// recorta el prefijo y **no** el texto, así que si el docente escribió la
  /// competencia con un espacio delante, el boletín imprime dos espacios y aquí
  /// también. Es el papel, no un corrector.
  ///
  /// *(El previo que ve el docente mientras escribe —`Utils/PrefijoDeBanda.dart`—
  /// sí monta el prefijo en la app, y es el único sitio donde eso es correcto:
  /// ahí no hay boletín todavía, se está enseñando cómo saldría.)*
  final String texto;

  /// La marca opcional de la fila del plan de área: «Saber», «Hacer», «Ser»…
  ///
  /// Texto libre de hasta 60 caracteres, y lo normal es que no venga. Las
  /// frases escritas a mano no lo traen nunca.
  final String? tipo;

  /// La posición que le dio el servidor dentro de su asignatura. Null en las
  /// frases del docente, que no tienen columna de orden.
  ///
  /// **No sirve para reordenar**: la lista ya viene ordenada. Ver
  /// [AsignaturaDelBoletin.lineas].
  final int? orden;

  /// El grado al que alcanza la fila del plan de área, o null cuando vale para
  /// **todos los grados**.
  ///
  /// Viaja porque es lo único que distingue una fila que el docente puede
  /// editar de una que escribió el colegio entero. Nulo también, y por otro
  /// motivo, en las frases escritas a mano.
  final int? gradoId;

  /// La banda de la que salió el prefijo de [texto] y el nombre de [nivel].
  ///
  /// Es `escalas_de_valoracion.id`, y es el mismo en todas las líneas del
  /// catálogo de la misma asignatura. Null cuando no hay banda, y null siempre
  /// en las frases del docente.
  final int? escalaId;

  /// El nombre de la banda en la que cayó la definitiva de **la asignatura**:
  /// «Superior», «Alto», «Básico»…
  ///
  /// **D17: el nivel viaja en texto siempre.** Los iconos de abajo son adorno y
  /// nunca lo sustituyen: el Decreto 2247 art. 10 pide informes descriptivos y
  /// una carita no lo es.
  ///
  /// Null en dos casos que no son el mismo:
  ///
  ///  - **una frase del docente** ([OrigenDeLinea.frase]): no es un olvido. Una
  ///    frase escrita sobre un alumno concreto no es una fila de un plan de
  ///    área, así que ponerle la banda de la asignatura sería afirmar sobre ella
  ///    algo que nadie dijo;
  ///  - **una línea del catálogo sin banda**: la asignatura no tiene definitiva
  ///    o su nota no cae en ninguna banda. Eso se lee en
  ///    [AsignaturaDelBoletin.motivoSinNivel], que dice cuál de las dos es.
  final String? nivel;

  /// Los iconos de la banda, y **sólo si el grupo pidió «caritas»**
  /// (`grupos.caritas`). Adorno: el texto de [nivel] está siempre.
  final String? iconoInfantil;
  final String? iconoAdolescente;

  /// De cuál de los dos bloques salió la línea.
  final OrigenDeLinea origen;

  /// Una fila del plan de área que escribió el colegio.
  bool get esDelCatalogo => origen == OrigenDeLinea.catalogo;

  /// Una frase que el docente escribió para este alumno.
  bool get esFraseDelDocente => origen == OrigenDeLinea.frase;

  /// Si esta línea puede enseñar la banda de su asignatura.
  ///
  /// Falso siempre en las frases del docente, y falso en las del catálogo
  /// cuando la asignatura se quedó sin banda que traducir.
  bool get tieneNivel => (nivel ?? '').trim().isNotEmpty;

  /// El icono que le toca a esta línea, o null si el grupo no pide caritas.
  ///
  /// [infantil] lo decide quien pinta, que es quien sabe de qué grado es el
  /// grupo. **Nunca se pinta solo**: va al lado de [nivel], no en su lugar.
  String? icono({required bool infantil}) =>
      infantil ? iconoInfantil : iconoAdolescente;

  /// Los campos llegan por `DB::select` a pelo, así que el tipo de cada columna
  /// lo decide PDO y un entero puede venir como cadena. De ahí [JsonBackend].
  ///
  /// `origen` se lee literal —el servidor manda `'catalogo'` o `'frase'`—; si
  /// no viniera, se deduce de `frase_asignatura_id`, que es la otra cosa que
  /// sólo tienen las frases. Deducirlo importa porque de ahí cuelga que se
  /// pueda o no enseñar un nivel.
  factory LineaDeBoletin.fromJson(Map<String, dynamic> json) {
    final marca = '${json['origen'] ?? ''}'.trim().toLowerCase();
    final frase = entero(json['frase_asignatura_id']);

    final esFrase = marca == 'frase' || (marca != 'catalogo' && frase != null);

    return LineaDeBoletin(
      desempenoId: entero(json['desempeno_id']),
      fraseAsignaturaId: frase,
      // Sin `trim` y sin nada más: ver el docblock de [texto].
      texto: '${json['texto'] ?? ''}',
      tipo: _textoDe(json['tipo']),
      orden: entero(json['orden']),
      gradoId: entero(json['grado_id']),
      escalaId: entero(json['escala_id']),
      nivel: _textoDe(json['nivel']),
      iconoInfantil: _textoDe(json['icono_infantil']),
      iconoAdolescente: _textoDe(json['icono_adolescente']),
      origen: esFrase ? OrigenDeLinea.frase : OrigenDeLinea.catalogo,
    );
  }
}

/// Una asignatura del boletín: su nota, su nivel y **sus líneas**.
///
/// Es la agrupación con la que se pinta: un bloque por asignatura, la nota
/// arriba y debajo sus líneas. El servidor ya las manda repartidas así —cada
/// asignatura trae su propia clave `desempenos`—, o sea que aquí no se agrupa
/// nada, se lee el reparto que ya viene hecho.
class AsignaturaDelBoletin {
  const AsignaturaDelBoletin({
    required this.asignaturaId,
    required this.materia,
    this.alias,
    this.area,
    this.nota,
    this.nivel,
    this.motivoSinNivel,
    this.totalAusencias = 0,
    this.totalTardanzas = 0,
    this.lineas = const [],
  });

  final int asignaturaId;
  final String materia;
  final String? alias;
  final String? area;

  /// La definitiva del periodo. Null cuando el docente aún no la ha puesto.
  final double? nota;

  /// El nombre de la banda de [nota]: «Superior», «Alto»…
  ///
  /// **Es uno por asignatura y se repite en todas sus líneas del catálogo**
  /// (P1.bis): el nivel se deriva de la definitiva de la asignatura, no de cada
  /// competencia, porque ya no hay ninguna casilla que marcar por línea. Que se
  /// repita no es un descuido de la maqueta: significa «en esta materia el
  /// alumno está en ALTO», y debajo va el plan de área que el colegio escribió.
  final String? nivel;

  /// Por qué [nivel] viene vacío, cuando viene vacío. Null si hay nivel.
  final MotivoSinNivel? motivoSinNivel;

  /// Faltas y tardanzas a esta clase en este periodo, **sumando cantidades**
  /// como las suma el servidor y no contando filas.
  final int totalAusencias;
  final int totalTardanzas;

  /// Las líneas, **en el orden en que llegaron**.
  ///
  /// El orden lo hace el servidor y la app no lo toca: primero el plan de área
  /// —las filas de «todos los grados» antes que las del grado, y dentro de cada
  /// bloque por `orden` con `id` de desempate— y **al final las frases escritas
  /// a mano**, por el orden en que el docente las escribió.
  ///
  /// Reordenarlas aquí las separaría del papel que imprime el colegio y de la
  /// pantalla donde el docente las tecleó, que es el mismo `ORDER BY`.
  final List<LineaDeBoletin> lineas;

  bool get tieneNota => nota != null;

  /// La nota como se escribe en un boletín: entera, y una raya si no la hay.
  String get notaEscrita => notaPintada(nota);

  bool get tieneNivel => (nivel ?? '').trim().isNotEmpty;

  /// Las del plan de área, que son las que llevan nivel.
  List<LineaDeBoletin> get delCatalogo =>
      lineas.where((l) => l.esDelCatalogo).toList();

  /// Las que el docente escribió para este alumno, que van al final.
  List<LineaDeBoletin> get frasesDelDocente =>
      lineas.where((l) => l.esFraseDelDocente).toList();

  /// El colegio no escribió plan de área para esta materia y este grado.
  ///
  /// Es el fallo que de verdad ocurre: la asignatura sale con su nota y su
  /// nivel y **debajo no hay nada**, que desde la pantalla se ve igual que un
  /// colegio que no imprime competencias. Las frases del docente no cuentan
  /// aquí: son otro bloque y las escribe otra persona.
  bool get sinCatalogo => !lineas.any((l) => l.esDelCatalogo);

  factory AsignaturaDelBoletin.fromJson(Map<String, dynamic> json) {
    final crudas = json['desempenos'];

    return AsignaturaDelBoletin(
      asignaturaId: enteroO(json['asignatura_id']),
      materia: '${json['materia'] ?? ''}',
      alias: texto(json['alias_materia']),
      area: texto(json['area_nombre']),
      nota: _decimal(json['nota_asignatura']),
      nivel: texto(json['desempenio']),
      motivoSinNivel: _motivo(json['motivo_del_nivel']),
      totalAusencias: enteroO(json['total_ausencias']),
      totalTardanzas: enteroO(json['total_tardanzas']),
      lineas: crudas is List
          ? crudas
              .whereType<Map>()
              .map((l) => LineaDeBoletin.fromJson(Map<String, dynamic>.from(l)))
              .toList()
          : const [],
    );
  }
}

/// El boletín por competencias de **un** alumno.
///
/// Lo devuelve `BoletinCompetenciasApi.traerBoletinPorCompetencias`, ya
/// filtrado: la respuesta del servidor trae un alumno por elemento y quien
/// llama pide uno. El porqué del filtro está allí.
class BoletinDeCompetencias {
  const BoletinDeCompetencias({
    required this.alumnoId,
    required this.nombres,
    this.apellidos,
    this.asignaturas = const [],
    this.caritas = false,
  });

  final int alumnoId;
  final String nombres;
  final String? apellidos;

  /// Las asignaturas del alumno en el periodo, en el orden del boletín: por
  /// área, por materia y por asignatura, como las ordena el servidor.
  final List<AsignaturaDelBoletin> asignaturas;

  /// Si el grupo evalúa con «caritas» (`grupos.caritas`).
  ///
  /// Sólo entonces vienen los iconos de cada línea. **No cambia el texto**: con
  /// caritas o sin ellas, el nivel va escrito (D17). Sirve para saber si hay
  /// icono que pintar al lado, no para pintarlo en lugar de la palabra.
  final bool caritas;

  String get nombreCompleto => '$nombres ${apellidos ?? ''}'.trim();

  /// Si hay alguna línea que pintar en todo el boletín.
  ///
  /// Falso quiere decir que el colegio no ha escrito el plan de área de ninguna
  /// de estas materias: la pantalla puede entonces no pintar el bloque en lugar
  /// de pintar doce asignaturas con un hueco debajo.
  bool get tieneLineas => asignaturas.any((a) => a.lineas.isNotEmpty);

  factory BoletinDeCompetencias.fromJson(
    Map<String, dynamic> json, {
    bool caritas = false,
  }) {
    final crudas = json['asignaturas'];

    return BoletinDeCompetencias(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: texto(json['apellidos']),
      caritas: caritas,
      asignaturas: crudas is List
          ? crudas
              .whereType<Map>()
              .map((a) =>
                  AsignaturaDelBoletin.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
    );
  }
}

/// El lector de textos de [JsonBackend], con otro nombre.
///
/// `LineaDeBoletin.texto` es un campo, así que dentro de su `fromJson` el
/// nombre `texto` está cogido y la función de la librería queda tapada. Es eso
/// y nada más: null cuando no vino, y nunca la cadena 'null'.
String? _textoDe(dynamic valor) => texto(valor);

/// `motivo_del_nivel` tal como lo escribe el servidor, o null si hay nivel.
///
/// Un valor que no se conozca se lee como null y no como un motivo inventado:
/// decir «sin definitiva» de algo que el servidor llamó de otra manera sería
/// explicarle al padre un motivo que nadie midió.
MotivoSinNivel? _motivo(dynamic valor) {
  switch ('${valor ?? ''}'.trim()) {
    case 'sin_definitiva':
      return MotivoSinNivel.sinDefinitiva;
    case 'sin_banda':
      return MotivoSinNivel.sinBanda;
    default:
      return null;
  }
}

/// La definitiva llega como número o como cadena, según el driver; y con coma
/// decimal según cómo la serialice el servidor.
double? _decimal(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.'));
}
