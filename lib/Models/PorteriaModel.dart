/// Lo que maneja la portería: los alumnos del año, las tardanzas de hoy y lo
/// que contesta el servidor al escanear. Ver docs/porteria.md.
library;

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

class ListaDePorteria {
  ListaDePorteria({required this.alumnos, required this.tardanzasHoy});

  final List<AlumnoDePorteria> alumnos;
  final List<TardanzaDeHoy> tardanzasHoy;
}

/// Lo que pasó al pedir una tardanza.
///
/// Cuatro desenlaces, y la pantalla hace una cosa distinta con cada uno:
///   - puesta (o ya la tenía): se enseña la foto y la hora;
///   - [desconocido]: el carné no es de nadie todavía, y se pregunta de quién es;
///   - [anulado]: el carné se dio por perdido;
///   - [error]: cualquier otra cosa, con la frase del servidor.
class ResultadoTardanza {
  ResultadoTardanza._({
    this.alumno,
    this.tardanza,
    this.yaTenia = false,
    this.desconocido = false,
    this.anulado = false,
    this.error,
    this.codigo,
  });

  factory ResultadoTardanza.puesta(
          AlumnoDePorteria alumno, TardanzaDeHoy tardanza, bool yaTenia) =>
      ResultadoTardanza._(alumno: alumno, tardanza: tardanza, yaTenia: yaTenia);

  factory ResultadoTardanza.desconocido(String codigo) =>
      ResultadoTardanza._(desconocido: true, codigo: codigo);

  factory ResultadoTardanza.anulado(String codigo) =>
      ResultadoTardanza._(anulado: true, codigo: codigo);

  factory ResultadoTardanza.mal(String error) =>
      ResultadoTardanza._(error: error);

  final AlumnoDePorteria? alumno;
  final TardanzaDeHoy? tardanza;
  final bool yaTenia;
  final bool desconocido;
  final bool anulado;
  final String? error;
  final String? codigo;

  bool get puesta => alumno != null && tardanza != null;
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
