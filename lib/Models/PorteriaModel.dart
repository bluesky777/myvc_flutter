/// Lo que maneja la portería: los alumnos del año, las tardanzas y las
/// novedades de hoy, y lo que contesta el servidor al escanear. Ver
/// docs/porteria.md y, para la novedad de uniforme,
/// myvc_front/docs/novedades-de-entrada.md.
library;

/// Qué registra el carné al escanearlo (o el alumno al elegirlo en el
/// buscador). Lo elige arriba de la cámara quien está en la entrada.
enum ModoDeEntrada {
  /// Lo de siempre: pone la tardanza al instante.
  tardanza,

  /// Sólo enseña al alumno, para anotarle la novedad de uniforme al que llegó
  /// a tiempo. No pone tardanza.
  soloNovedad,
}

/// Las novedades que se anotan en la entrada, en el orden en que salen los
/// botones. Cada una es una columna de `uniformes`; «Sin cámara» no va, que es
/// de la clase virtual (ver MarcaUniforme).
enum MotivoDeNovedad {
  sinUniforme('sin_uniforme', 'Sin uniforme'),
  contrario('contrario', 'Contrario'),
  incompleto('incompleto', 'Incompleto'),
  cabello('cabello', 'Cabello'),
  accesorios('accesorios', 'Accesorios'),

  /// La «Otra»: lo que sea va en la nota.
  otra('otro1', 'Otra');

  const MotivoDeNovedad(this.clave, this.nombre);

  /// La columna del backend.
  final String clave;

  /// Cómo se lee en el botón.
  final String nombre;

  /// «sin_uniforme» → «Sin uniforme». Una clave que no conoce se enseña tal cual.
  static String nombreDe(String clave) =>
      values.where((m) => m.clave == clave).firstOrNull?.nombre ?? clave;
}

/// Un alumno del año actual, como lo baja `GET porteria/alumnos`.
///
/// La lista entera se baja una vez al abrir la pantalla —unos cientos de
/// filas— y el buscador filtra en el teléfono: escribir no gasta peticiones.
class AlumnoDePorteria {
  AlumnoDePorteria({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.grupo,
    this.foto,
  });

  final int id;
  final String nombres;
  final String apellidos;
  final String grupo;
  final String? foto;

  String get nombreCompleto => '$nombres $apellidos';

  /// Nombre, apellidos y grupo, en minúsculas y sin tildes: «jose perez 6a».
  late final String _buscable = sinTildes('$nombres $apellidos $grupo');

  /// Todas las palabras escritas están, en cualquier orden: «perez jo» encuentra
  /// a José Pérez.
  bool coincide(List<String> palabras) => palabras.every(_buscable.contains);

  factory AlumnoDePorteria.fromJson(Map<String, dynamic> j) => AlumnoDePorteria(
        id: _entero(j['alumno_id']),
        nombres: '${j['nombres'] ?? ''}'.trim(),
        apellidos: '${j['apellidos'] ?? ''}'.trim(),
        grupo: '${j['grupo'] ?? ''}'.trim(),
        foto: j['foto'] as String?,
      );
}

/// Una tardanza de entrada de hoy.
class TardanzaDeHoy {
  TardanzaDeHoy({required this.id, required this.alumnoId, this.fechaHora});

  final int id;
  final int alumnoId;

  /// Hora de Bogotá, tal cual la guarda el servidor (`Y-m-d H:i:s`).
  final DateTime? fechaHora;

  factory TardanzaDeHoy.fromJson(Map<String, dynamic> j) => TardanzaDeHoy(
        id: _entero(j['id']),
        alumnoId: _entero(j['alumno_id']),
        fechaHora: DateTime.tryParse('${j['fecha_hora'] ?? ''}'),
      );
}

/// Una novedad de uniforme anotada hoy en la entrada: una fila de `uniformes`
/// sin asignatura y con `entrada = 1`. No tiene nada que ver con la tardanza.
class NovedadDeHoy {
  NovedadDeHoy({
    required this.id,
    required this.alumnoId,
    required this.motivos,
    this.descripcion,
    this.fechaHora,
    this.createdBy,
  });

  final int id;
  final int alumnoId;

  /// Las claves de [MotivoDeNovedad] que se marcaron: `sin_uniforme`, `otro1`…
  final List<String> motivos;

  /// La «Nota (opcional)».
  final String? descripcion;

  /// Hora de Bogotá, tal cual la guarda el servidor (`Y-m-d H:i:s`).
  final DateTime? fechaHora;

  /// Quién la anotó (`user_id`).
  final int? createdBy;

  /// «Sin uniforme, Cabello».
  String get motivosLeibles => motivos.map(MotivoDeNovedad.nombreDe).join(', ');

  factory NovedadDeHoy.fromJson(Map<String, dynamic> j) => NovedadDeHoy(
        id: _entero(j['id']),
        alumnoId: _entero(j['alumno_id']),
        motivos: [for (final m in (j['motivos'] as List? ?? const [])) '$m'],
        descripcion: j['descripcion'] as String?,
        fechaHora: DateTime.tryParse('${j['fecha_hora'] ?? ''}'),
        createdBy: j['created_by'] == null ? null : _entero(j['created_by']),
      );
}

/// Cómo va el alumno en la regla del uniforme del colegio: cada [cada]
/// novedades de las que [cuentan] se pide una situación tipo 1, como
/// `cant_tard_to_ft1` con las tardanzas. Viene en lo que contestan
/// `porteria/tardanza`, `porteria/leer` y `porteria/novedad`
/// (`ReglaDelUniforme::conteo` en el servidor).
///
/// Cuentan las novedades de institución —las de la entrada y las de
/// disciplina—, no sólo las de hoy; la de un profesor en su clase no.
class ConteoUniforme {
  ConteoUniforme({
    required this.cuenta,
    required this.cada,
    required this.porPeriodo,
    required this.situaciones,
    required this.pideSituacion,
    required this.cuentan,
    this.periodo,
  });

  /// Las novedades que cuentan, en el periodo o en el año según [porPeriodo].
  final int cuenta;

  /// Cada cuántas se pide la situación. 0 es que el colegio apagó la regla, y
  /// entonces no se enseña conteo.
  final int cada;

  /// Si el conteo se reinicia cada periodo; si no, cuenta el año.
  final bool porPeriodo;

  /// El número del periodo actual (no el id): «Periodo 4».
  final int? periodo;

  /// Las situaciones que ya salieron de esta regla.
  final int situaciones;

  /// Ya le toca una situación que nadie ha creado.
  final bool pideSituacion;

  /// Las claves que cuentan para la regla. Una novedad cuenta si marca alguna.
  final List<String> cuentan;

  bool get apagada => cada <= 0;

  /// Si una novedad con estos motivos entra en el conteo.
  bool cuentaCon(Iterable<String> motivos) => motivos.any(cuentan.contains);

  /// «en el periodo 4» o «en el año».
  String get donde =>
      porPeriodo && periodo != null ? 'en el periodo $periodo' : 'en el año';

  /// Lo que quedaría después de anotar una novedad que cuenta. Es lo que se
  /// le promete al docente antes de guardar; al guardar manda el servidor.
  ConteoUniforme conUnaMas() => ConteoUniforme(
        cuenta: cuenta + 1,
        cada: cada,
        porPeriodo: porPeriodo,
        periodo: periodo,
        situaciones: situaciones,
        pideSituacion: cada > 0 && (cuenta + 1) ~/ cada > situaciones,
        cuentan: cuentan,
      );

  static ConteoUniforme? fromJson(dynamic j) {
    if (j is! Map) return null;
    return ConteoUniforme(
      cuenta: _entero(j['cuenta']),
      cada: _entero(j['cada']),
      porPeriodo: j['por_periodo'] == true,
      periodo: j['periodo'] == null ? null : _entero(j['periodo']),
      situaciones: _entero(j['situaciones']),
      pideSituacion: j['pide_situacion'] == true,
      cuentan: [for (final m in (j['cuentan'] as List? ?? const [])) '$m'],
    );
  }
}

class ListaDePorteria {
  ListaDePorteria({
    required this.alumnos,
    required this.tardanzasHoy,
    required this.novedadesHoy,
  });

  final List<AlumnoDePorteria> alumnos;
  final List<TardanzaDeHoy> tardanzasHoy;
  final List<NovedadDeHoy> novedadesHoy;
}

/// Lo que pasó al leer un carné: con tardanza (`porteria/tardanza`) o sin
/// ella (`porteria/leer`, el modo «Sólo novedad»).
///
/// Cuatro desenlaces, y la pantalla hace una cosa distinta con cada uno:
///   - [hallado]: se enseña la foto, la tardanza si la hay y el bloque de la
///     novedad;
///   - [desconocido]: el carné no es de nadie todavía, y se pregunta de quién es;
///   - [anulado]: el carné se dio por perdido;
///   - [error]: cualquier otra cosa, con la frase del servidor.
class ResultadoDelCarne {
  ResultadoDelCarne._({
    this.alumno,
    this.tardanza,
    this.yaTenia = false,
    this.novedades,
    this.uniforme,
    this.desconocido = false,
    this.anulado = false,
    this.error,
    this.codigo,
  });

  /// Con tardanza: la que se puso, o la que ya tenía.
  factory ResultadoDelCarne.puesta(
    AlumnoDePorteria alumno,
    TardanzaDeHoy tardanza,
    bool yaTenia, {
    List<NovedadDeHoy>? novedades,
    ConteoUniforme? uniforme,
  }) =>
      ResultadoDelCarne._(
          alumno: alumno,
          tardanza: tardanza,
          yaTenia: yaTenia,
          novedades: novedades,
          uniforme: uniforme);

  /// Sin escribir nada: el alumno, su tardanza de hoy si la tiene y sus
  /// novedades de hoy.
  factory ResultadoDelCarne.leido(
    AlumnoDePorteria alumno, {
    TardanzaDeHoy? tardanza,
    required List<NovedadDeHoy> novedades,
    ConteoUniforme? uniforme,
  }) =>
      ResultadoDelCarne._(
          alumno: alumno,
          tardanza: tardanza,
          novedades: novedades,
          uniforme: uniforme);

  factory ResultadoDelCarne.desconocido(String codigo) =>
      ResultadoDelCarne._(desconocido: true, codigo: codigo);

  factory ResultadoDelCarne.anulado(String codigo) =>
      ResultadoDelCarne._(anulado: true, codigo: codigo);

  factory ResultadoDelCarne.mal(String error) =>
      ResultadoDelCarne._(error: error);

  final AlumnoDePorteria? alumno;
  final TardanzaDeHoy? tardanza;
  final bool yaTenia;

  /// Las novedades de hoy de este alumno, en la tardanza y en la lectura
  /// (8myvc f2558b70). Null si el servidor todavía no las manda: entonces
  /// valen las de `GET porteria/alumnos`.
  final List<NovedadDeHoy>? novedades;

  /// Null si el servidor todavía no lo manda.
  final ConteoUniforme? uniforme;
  final bool desconocido;
  final bool anulado;
  final String? error;
  final String? codigo;

  bool get hallado => alumno != null;
}

/// Lo que contesta `POST porteria/novedad`: la fila y cómo queda el conteo.
class NovedadGuardada {
  NovedadGuardada({this.novedad, this.uniforme, this.error});

  final NovedadDeHoy? novedad;
  final ConteoUniforme? uniforme;
  final String? error;
}

/// Lo que contesta `DELETE porteria/novedad/{id}`: cómo queda el conteo ya sin
/// esa novedad.
class NovedadQuitada {
  NovedadQuitada({this.uniforme, this.error});

  final ConteoUniforme? uniforme;
  final String? error;

  bool get quitada => error == null;
}

/// El carné de la app: lo que ve el alumno, o el acudiente de cada hijo.
class CarneDeAlumno {
  CarneDeAlumno({required this.alumno, required this.codigo});

  final AlumnoDePorteria alumno;

  /// Lo que lleva el QR: `MYVC-` y diez caracteres al azar.
  final String codigo;

  factory CarneDeAlumno.fromJson(Map<String, dynamic> j) => CarneDeAlumno(
        alumno: AlumnoDePorteria.fromJson(j),
        codigo: '${j['codigo'] ?? ''}',
      );
}

/// Minúsculas y sin tildes, para buscar «Peña» escribiendo «pena».
String sinTildes(String texto) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñç';
  const a = 'aaaaeeeeiiiioooouuuunc';
  final buffer = StringBuffer();
  for (final letra in texto.toLowerCase().split('')) {
    final i = de.indexOf(letra);
    buffer.write(i >= 0 ? a[i] : letra);
  }
  return buffer.toString();
}

int _entero(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
