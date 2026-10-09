/// Las PQRS del acudiente (Joseth, 9 oct 2026): lo que devuelve `mis-pqrs/*`
/// de 8myvc (`MisPqrsController`). Ver `docs/pqrs.md`.
///
/// El semáforo del plazo ([PlazoPqrs]) lo calcula el servidor, que es quien
/// sabe de festivos: aquí sólo se pinta.
library;

DateTime? _fecha(dynamic crudo) {
  final texto = crudo?.toString().trim() ?? '';
  if (texto.isEmpty || texto == 'null') return null;
  return DateTime.tryParse(texto.replaceFirst(' ', 'T'));
}

int? _entero(dynamic crudo) => crudo == null ? null : int.tryParse('$crudo');

/// `a_tiempo`, `por_vencer`, `vencida`, `respondida` o `sin_plazo`, con el
/// tono (`ok`, `aviso`, `mal`, `neutro`) y la frase ya escrita.
class PlazoPqrs {
  const PlazoPqrs({required this.clave, required this.tono, required this.texto});

  final String clave;
  final String tono;
  final String texto;

  factory PlazoPqrs.fromJson(Map<String, dynamic> j) => PlazoPqrs(
        clave: '${j['clave'] ?? 'sin_plazo'}',
        tono: '${j['tono'] ?? 'neutro'}',
        texto: '${j['texto'] ?? ''}',
      );
}

class AlumnoPqrs {
  const AlumnoPqrs({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.grupo,
    this.foto,
    this.matriculado = true,
  });

  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? grupo;
  final String? foto;
  final bool matriculado;

  String get nombre => '$nombres $apellidos'.trim();

  factory AlumnoPqrs.fromJson(Map<String, dynamic> j) => AlumnoPqrs(
        alumnoId: _entero(j['alumno_id']) ?? 0,
        nombres: '${j['nombres'] ?? ''}',
        apellidos: '${j['apellidos'] ?? ''}',
        grupo: j['grupo']?.toString(),
        foto: j['foto']?.toString(),
        matriculado: j['matriculado'] != false,
      );
}

class FilaPqrs {
  const FilaPqrs({
    required this.id,
    required this.radicado,
    required this.tipo,
    required this.tipoTexto,
    required this.claseTexto,
    required this.asunto,
    required this.estado,
    required this.estadoTexto,
    required this.plazo,
    this.radicadaAt,
    this.fechaLimite,
    this.diasHabiles,
    this.alumno,
  });

  final int id;
  final String radicado;
  final String tipo;
  final String tipoTexto;
  final String claseTexto;
  final String asunto;

  /// `radicada`, `en_tramite`, `respondida` o `cerrada`.
  final String estado;
  final String estadoTexto;
  final PlazoPqrs plazo;
  final DateTime? radicadaAt;
  final DateTime? fechaLimite;
  final int? diasHabiles;
  final AlumnoPqrs? alumno;

  bool get abierta => estado == 'radicada' || estado == 'en_tramite';

  factory FilaPqrs.fromJson(Map<String, dynamic> j) => FilaPqrs(
        id: _entero(j['id']) ?? 0,
        radicado: '${j['radicado'] ?? ''}',
        tipo: '${j['tipo'] ?? ''}',
        tipoTexto: '${j['tipo_texto'] ?? ''}',
        claseTexto:
            j['tipo'] == 'peticion' && j['clase'] != 'general' ? '${j['clase_texto'] ?? ''}' : '',
        asunto: '${j['asunto'] ?? ''}',
        estado: '${j['estado'] ?? ''}',
        estadoTexto: '${j['estado_texto'] ?? ''}',
        plazo: PlazoPqrs.fromJson(Map<String, dynamic>.from(j['plazo'] as Map? ?? const {})),
        radicadaAt: _fecha(j['radicada_at']),
        fechaLimite: _fecha(j['fecha_limite']),
        diasHabiles: _entero(j['dias_habiles']),
        alumno: j['alumno'] is Map
            ? AlumnoPqrs.fromJson(Map<String, dynamic>.from(j['alumno'] as Map))
            : null,
      );
}

/// Un paso del hilo que el acudiente puede ver: radicada, en trámite,
/// respondida, encuesta o cerrada. Lo interno del colegio no llega.
class EventoPqrs {
  const EventoPqrs({required this.tipo, this.texto, this.at});

  final String tipo;
  final String? texto;
  final DateTime? at;

  String get frase => switch (tipo) {
        'radicada' => 'Radicada',
        'en_tramite' => 'El colegio la está atendiendo',
        'respondida' => 'El colegio respondió',
        'encuesta' => 'Contestó la encuesta',
        'cerrada' => 'Cerrada',
        _ => tipo,
      };

  factory EventoPqrs.fromJson(Map<String, dynamic> j) => EventoPqrs(
        tipo: '${j['tipo'] ?? ''}',
        texto: j['texto']?.toString(),
        at: _fecha(j['at']),
      );
}

class AdjuntoPqrs {
  const AdjuntoPqrs({
    required this.id,
    required this.momento,
    required this.nombre,
    required this.mime,
    required this.bytes,
  });

  final int id;

  /// `radicacion` o `respuesta`.
  final String momento;
  final String nombre;
  final String mime;
  final int bytes;

  bool get esImagen => mime.startsWith('image/');

  factory AdjuntoPqrs.fromJson(Map<String, dynamic> j) => AdjuntoPqrs(
        id: _entero(j['id']) ?? 0,
        momento: '${j['momento'] ?? ''}',
        nombre: '${j['nombre'] ?? ''}',
        mime: '${j['mime'] ?? ''}',
        bytes: _entero(j['bytes']) ?? 0,
      );
}

class DetallePqrs {
  const DetallePqrs({
    required this.fila,
    required this.descripcion,
    required this.canalTexto,
    this.respuesta,
    this.respondidaAt,
    this.respondidaPor,
    this.satisfaccion,
    this.comentario,
    required this.puedeEncuesta,
    required this.eventos,
    required this.adjuntos,
  });

  final FilaPqrs fila;
  final String descripcion;
  final String canalTexto;
  final String? respuesta;
  final DateTime? respondidaAt;

  /// Quién firmó la respuesta. Lo demás del colegio va sin nombre.
  final String? respondidaPor;
  final int? satisfaccion;
  final String? comentario;
  final bool puedeEncuesta;
  final List<EventoPqrs> eventos;
  final List<AdjuntoPqrs> adjuntos;

  factory DetallePqrs.fromJson(Map<String, dynamic> j) {
    final encuesta = j['encuesta'] is Map ? Map<String, dynamic>.from(j['encuesta'] as Map) : null;
    final firma = j['respondida_por'] is Map ? Map<String, dynamic>.from(j['respondida_por'] as Map) : null;
    return DetallePqrs(
      fila: FilaPqrs.fromJson(j),
      descripcion: '${j['descripcion'] ?? ''}',
      canalTexto: '${j['canal_texto'] ?? ''}',
      respuesta: j['respuesta']?.toString(),
      respondidaAt: _fecha(j['respondida_at']),
      respondidaPor: firma?['nombre']?.toString(),
      satisfaccion: _entero(encuesta?['satisfaccion']),
      comentario: encuesta?['comentario']?.toString(),
      puedeEncuesta: j['puede_encuesta'] == true,
      eventos: [
        for (final e in (j['eventos'] as List? ?? const []))
          EventoPqrs.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      adjuntos: [
        for (final a in (j['adjuntos'] as List? ?? const []))
          AdjuntoPqrs.fromJson(Map<String, dynamic>.from(a as Map)),
      ],
    );
  }
}

/// Un tipo o una clase de petición, con su explicación y su plazo, tal como
/// los manda el servidor (`catalogo`): el texto es uno para la app y la web.
class OpcionPqrs {
  const OpcionPqrs({required this.clave, required this.texto, this.explicacion, this.dias});

  final String clave;
  final String texto;
  final String? explicacion;
  final int? dias;

  factory OpcionPqrs.fromJson(Map<String, dynamic> j) => OpcionPqrs(
        clave: '${j['clave'] ?? ''}',
        texto: '${j['texto'] ?? ''}',
        explicacion: j['explicacion']?.toString(),
        dias: _entero(j['dias']),
      );
}

class ListaDePqrs {
  const ListaDePqrs({
    required this.filas,
    required this.hijos,
    required this.tipos,
    required this.clases,
  });

  final List<FilaPqrs> filas;
  final List<AlumnoPqrs> hijos;
  final List<OpcionPqrs> tipos;
  final List<OpcionPqrs> clases;

  factory ListaDePqrs.fromJson(Map<String, dynamic> j) {
    final catalogo = Map<String, dynamic>.from(j['catalogo'] as Map? ?? const {});
    return ListaDePqrs(
      filas: [
        for (final f in (j['filas'] as List? ?? const []))
          FilaPqrs.fromJson(Map<String, dynamic>.from(f as Map)),
      ],
      hijos: [
        for (final h in (j['hijos'] as List? ?? const []))
          AlumnoPqrs.fromJson(Map<String, dynamic>.from(h as Map)),
      ],
      tipos: [
        for (final t in (catalogo['tipos'] as List? ?? const []))
          OpcionPqrs.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
      clases: [
        for (final c in (catalogo['clases'] as List? ?? const []))
          OpcionPqrs.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
    );
  }
}
