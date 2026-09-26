/// Las formas JSON del módulo nuevo de actividades —tareas, cuestionarios y
/// encuestas—, del lado de quien responde.
///
/// **El contrato es `myvc_front/ACTIVIDADES-CONTRATO.md` §4**, y donde el
/// backend real difiere del papel manda el backend: `8myvc`,
/// `app/Services/Act/Formas.php`, leído el 26 sep 2026. Aquí sólo están los
/// tipos que usan el alumno y el acudiente; lo del creador (configurar,
/// preguntas, resultados, calificar) vive en la web.
///
/// Todo se lee con [JsonBackend]: aunque `Formas` ya manda los booleanos como
/// `true`/`false` y los ids como números, no cuesta nada no creérselo.
library;

import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Una hora del servidor, `"AAAA-MM-DD HH:MM:SS"` en hora de Colombia.
///
/// Se lee como hora local sin zona: el teléfono de un alumno está en Colombia,
/// y la API entera habla en esa hora (contrato §1).
DateTime? horaDeActividad(dynamic crudo) {
  final t = _txt(crudo)?.trim();
  if (t == null || t.isEmpty) return null;
  return DateTime.tryParse(t.replaceFirst(' ', 'T'));
}

/// El texto de las instrucciones, que llegan como HTML del editor rico.
///
/// Un párrafo por línea y sin etiquetas. No hace falta más: las instrucciones
/// son texto con negritas y listas, y en el teléfono se leen igual sin ellas.
String textoDeHtml(String? html) {
  if (html == null) return '';
  var t = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entidades = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&aacute;': 'á',
    '&eacute;': 'é',
    '&iacute;': 'í',
    '&oacute;': 'ó',
    '&uacute;': 'ú',
    '&ntilde;': 'ñ',
  };
  entidades.forEach((e, v) => t = t.replaceAll(e, v));
  return t.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// [texto] de JsonBackend con otro nombre: dentro de las clases que tienen un
/// campo `texto`, el campo tapa a la función.
String? _txt(dynamic valor) => texto(valor);

List<Map<String, dynamic>> _lista(dynamic crudo) => crudo is List
    ? crudo.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];

Map<String, dynamic>? _mapa(dynamic crudo) =>
    crudo is Map ? Map<String, dynamic>.from(crudo) : null;

/// `PersonaCorta`: el creador, o el hijo por el que responde un acudiente.
class PersonaCorta {
  final int? userId;
  final int? alumnoId;
  final String nombre;

  /// URL entera, ya armada por el servidor (no el nombre de `images`).
  final String? fotoUrl;

  const PersonaCorta({
    this.userId,
    this.alumnoId,
    required this.nombre,
    this.fotoUrl,
  });

  factory PersonaCorta.fromJson(Map<String, dynamic> j) => PersonaCorta(
        userId: entero(j['user_id']),
        alumnoId: entero(j['alumno_id']),
        nombre: '${j['nombre'] ?? ''}',
        fotoUrl: _txt(j['foto_url']),
      );

  /// El primer nombre, con mayúscula inicial: «NICOLE VALERIA …» → «Nicole».
  String get primerNombre {
    final primero = nombre.trim().split(RegExp(r'\s+')).first;
    if (primero.isEmpty) return nombre;
    return primero[0].toUpperCase() + primero.substring(1).toLowerCase();
  }

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final a = partes.first[0];
    final b = partes.length > 2
        ? partes[2][0]
        : (partes.length > 1 ? partes[1][0] : '');
    return (a + b).toUpperCase();
  }
}

/// `ActEnBandeja`: una fila de la bandeja «para responder».
///
/// El acudiente «una vez por hijo» recibe **una fila por hijo**, con el mismo
/// `id` y distinto [porAlumno]: la clave de una fila es el par, no el id.
class ActEnBandeja {
  final int id;

  /// `tarea`, `cuestionario` o `encuesta`.
  final String modo;
  final String titulo;

  /// El estado efectivo (contrato §2.1): aquí sólo llegan `abierta` y `cerrada`.
  final String estado;

  /// «Matemáticas · 7A», «Todo el colegio».
  final String donde;
  final DateTime? cierraAt;
  final String anonimato;
  final bool califica;
  final PersonaCorta creador;
  final PersonaCorta? porAlumno;

  /// `pendiente`, `borrador`, `enviada`, `entregada`, `tarde`, `calificada` o
  /// `vencida` (`Respuestas::miEstado`).
  final String miEstado;
  final int? miNota;

  const ActEnBandeja({
    required this.id,
    required this.modo,
    required this.titulo,
    required this.estado,
    required this.donde,
    required this.cierraAt,
    required this.anonimato,
    required this.califica,
    required this.creador,
    required this.porAlumno,
    required this.miEstado,
    required this.miNota,
  });

  factory ActEnBandeja.fromJson(Map<String, dynamic> j) => ActEnBandeja(
        id: enteroO(j['id']),
        modo: '${j['modo'] ?? ''}',
        titulo: '${j['titulo'] ?? ''}',
        estado: '${j['estado'] ?? ''}',
        donde: '${j['donde'] ?? ''}',
        cierraAt: horaDeActividad(j['cierra_at']),
        anonimato: '${j['anonimato'] ?? 'nombre'}',
        califica: siONo(j['califica']) ?? false,
        creador: PersonaCorta.fromJson(_mapa(j['creador']) ?? const {}),
        porAlumno: _mapa(j['por_alumno']) == null
            ? null
            : PersonaCorta.fromJson(_mapa(j['por_alumno'])!),
        miEstado: '${j['mi_estado'] ?? 'pendiente'}',
        miNota: entero(j['mi_nota']),
      );

  bool get esTarea => modo == 'tarea';
  bool get esCuestionario => modo == 'cuestionario';
  bool get esEncuesta => modo == 'encuesta';
  bool get abierta => estado == 'abierta';
  bool get anonima => anonimato != 'nombre';

  /// Si todavía le toca hacer algo: sin responder, o empezada, y abierta.
  bool get pendiente =>
      abierta && (miEstado == 'pendiente' || miEstado == 'borrador');
}

/// `OpcionAct`, sin `is_correct` salvo en «mis respuestas» cuando se permite.
class OpcionAct {
  final int id;
  final String definicion;
  final String? imagenUrl;
  final bool? esCorrecta;

  const OpcionAct({
    required this.id,
    required this.definicion,
    this.imagenUrl,
    this.esCorrecta,
  });

  factory OpcionAct.fromJson(Map<String, dynamic> j) => OpcionAct(
        id: enteroO(j['id']),
        definicion: '${j['definicion'] ?? ''}',
        imagenUrl: _txt(j['imagen_url']),
        esCorrecta: siONo(j['is_correct']),
      );
}

/// `CondicionAct`: una de las condiciones de un grupo (contrato §2.5).
class CondicionAct {
  final int dependeDeId;

  /// `es`, `no_es` o `contiene`.
  final String operador;
  final int? opcionId;
  final String? valor;

  const CondicionAct({
    required this.dependeDeId,
    required this.operador,
    this.opcionId,
    this.valor,
  });

  factory CondicionAct.fromJson(Map<String, dynamic> j) => CondicionAct(
        dependeDeId: enteroO(j['depende_de_id']),
        operador: '${j['operador'] ?? 'es'}',
        opcionId: entero(j['opcion_id']),
        valor: _txt(j['valor']),
      );
}

/// `PreguntaAct`, como la ve quien responde.
class PreguntaAct {
  final int id;
  final int orden;

  /// `unica`, `multiple`, `corta`, `parrafo`, `escala`, `sino`,
  /// `imagen_opciones`, `video`, `archivo` o `fecha`.
  final String tipo;
  final String enunciado;
  final String? ayuda;
  final bool obligatoria;
  final int puntos;
  final String? imagenUrl;
  final String? youtubeId;
  final int? youtubeInicio;
  final String? enlaceUrl;

  /// `numeros`, `caras` o `estrellas`.
  final String? escalaEstilo;

  /// El rótulo del extremo alto de la escala (el 5).
  final String? textoArriba;

  /// El rótulo del extremo bajo de la escala (el 1).
  final String? textoAbajo;
  final bool opcionOtra;
  final bool aleatorias;
  final String? explicacion;
  final List<OpcionAct> opciones;

  /// O de Y: visible si **algún** grupo tiene **todas** sus condiciones.
  final List<List<CondicionAct>> condiciones;

  const PreguntaAct({
    required this.id,
    required this.orden,
    required this.tipo,
    required this.enunciado,
    this.ayuda,
    required this.obligatoria,
    required this.puntos,
    this.imagenUrl,
    this.youtubeId,
    this.youtubeInicio,
    this.enlaceUrl,
    this.escalaEstilo,
    this.textoArriba,
    this.textoAbajo,
    required this.opcionOtra,
    required this.aleatorias,
    this.explicacion,
    required this.opciones,
    required this.condiciones,
  });

  factory PreguntaAct.fromJson(Map<String, dynamic> j) => PreguntaAct(
        id: enteroO(j['id']),
        orden: enteroO(j['orden']),
        tipo: '${j['tipo'] ?? 'unica'}',
        enunciado: '${j['enunciado'] ?? ''}',
        ayuda: _txt(j['ayuda']),
        obligatoria: siONo(j['obligatoria']) ?? false,
        puntos: enteroO(j['puntos']),
        imagenUrl: _txt(j['imagen_url']),
        youtubeId: _txt(j['youtube_id']),
        youtubeInicio: entero(j['youtube_inicio']),
        enlaceUrl: _txt(j['enlace_url']),
        escalaEstilo: _txt(j['escala_estilo']),
        textoArriba: _txt(j['texto_arriba']),
        textoAbajo: _txt(j['texto_abajo']),
        opcionOtra: siONo(j['opcion_otra']) ?? false,
        aleatorias: siONo(j['aleatorias']) ?? false,
        explicacion: _txt(j['explicacion']),
        opciones: _lista(j['opciones']).map(OpcionAct.fromJson).toList(),
        condiciones: (j['condiciones'] is List ? j['condiciones'] as List : [])
            .map((g) => _lista(g).map(CondicionAct.fromJson).toList())
            .toList(),
      );

  static const tiposDeOpciones = {
    'unica',
    'multiple',
    'sino',
    'imagen_opciones',
    'video'
  };

  bool get esDeOpciones => tiposDeOpciones.contains(tipo);
  bool get tieneCondiciones => condiciones.isNotEmpty;

  String? definicionDe(int opcionId) {
    for (final o in opciones) {
      if (o.id == opcionId) return o.definicion;
    }
    return null;
  }
}

/// `RespuestaEnviada`: lo que se manda al guardar el borrador, al enviar y al
/// entregar, y lo que devuelve el servidor en `borrador` y en «mis respuestas».
class RespuestaAct {
  final int preguntaId;
  final List<int> opcionIds;
  final String? texto;
  final int? valor;
  final String? fecha;
  final int? archivoId;

  /// Sólo para pintar: el nombre del archivo subido en esta sesión.
  final String? archivoNombre;

  const RespuestaAct({
    required this.preguntaId,
    this.opcionIds = const [],
    this.texto,
    this.valor,
    this.fecha,
    this.archivoId,
    this.archivoNombre,
  });

  factory RespuestaAct.fromJson(Map<String, dynamic> j) => RespuestaAct(
        preguntaId: enteroO(j['pregunta_id']),
        opcionIds: (j['opcion_ids'] is List ? j['opcion_ids'] as List : [])
            .map(entero)
            .whereType<int>()
            .toList(),
        texto: _txt(j['texto']),
        valor: entero(j['valor']),
        fecha: _txt(j['fecha']),
        archivoId: entero(j['archivo_id']),
      );

  Map<String, dynamic> toJson() => {
        'pregunta_id': preguntaId,
        'opcion_ids': opcionIds,
        'texto': texto,
        'valor': valor,
        'fecha': fecha,
        'archivo_id': archivoId,
      };
}

/// `ArchivoAct`: una foto o un archivo subido a `act/{id}/archivo`.
class ArchivoAct {
  final int id;

  /// `foto` o `archivo`.
  final String clase;
  final String nombreOriginal;
  final String mime;
  final int bytes;

  const ArchivoAct({
    required this.id,
    required this.clase,
    required this.nombreOriginal,
    required this.mime,
    required this.bytes,
  });

  factory ArchivoAct.fromJson(Map<String, dynamic> j) => ArchivoAct(
        id: enteroO(j['id']),
        clase: '${j['clase'] ?? 'archivo'}',
        nombreOriginal: '${j['nombre_original'] ?? ''}',
        mime: '${j['mime'] ?? ''}',
        bytes: enteroO(j['bytes']),
      );

  /// «PDF», «DOCX»: la chapa del archivo.
  String get extension {
    final punto = nombreOriginal.lastIndexOf('.');
    if (punto < 0 || punto == nombreOriginal.length - 1) return 'ARCH';
    return nombreOriginal.substring(punto + 1).toUpperCase();
  }
}

/// `EntregaAct`: la entrega de una tarea.
class EntregaAct {
  final String? texto;
  final String? enlace;
  final ArchivoAct? foto;
  final ArchivoAct? archivo;
  final DateTime? entregadaAt;
  final bool tarde;
  final int? nota;
  final String? comentario;
  final DateTime? calificadaAt;

  const EntregaAct({
    this.texto,
    this.enlace,
    this.foto,
    this.archivo,
    this.entregadaAt,
    this.tarde = false,
    this.nota,
    this.comentario,
    this.calificadaAt,
  });

  factory EntregaAct.fromJson(Map<String, dynamic> j) => EntregaAct(
        texto: _txt(j['texto']),
        enlace: _txt(j['enlace']),
        foto: _mapa(j['foto']) == null
            ? null
            : ArchivoAct.fromJson(_mapa(j['foto'])!),
        archivo: _mapa(j['archivo']) == null
            ? null
            : ArchivoAct.fromJson(_mapa(j['archivo'])!),
        entregadaAt: horaDeActividad(j['entregada_at']),
        tarde: siONo(j['tarde']) ?? false,
        nota: entero(j['nota']),
        comentario: _txt(j['comentario']),
        calificadaAt: horaDeActividad(j['calificada_at']),
      );

  bool get entregada => entregadaAt != null;
  bool get calificada => nota != null;
}

/// Qué pide una tarea: `entrega` de `ActParaResponder`.
class EntregaPedida {
  final bool texto;
  final bool foto;
  final bool archivo;
  final bool enlace;

  const EntregaPedida({
    this.texto = false,
    this.foto = false,
    this.archivo = false,
    this.enlace = false,
  });

  factory EntregaPedida.fromJson(Map<String, dynamic> j) => EntregaPedida(
        texto: siONo(j['texto']) ?? false,
        foto: siONo(j['foto']) ?? false,
        archivo: siONo(j['archivo']) ?? false,
        enlace: siONo(j['enlace']) ?? false,
      );
}

/// `ActParaResponder`: la actividad con sus preguntas, sin las correctas.
class ActParaResponder {
  final int id;
  final String modo;
  final String titulo;
  final String instrucciones;
  final String estado;
  final DateTime? cierraAt;
  final String anonimato;
  final PersonaCorta? porAlumno;
  final EntregaPedida? entrega;
  final int? notaMaxima;
  final int intentosUsados;
  final int intentosMaximo;
  final List<PreguntaAct> preguntas;
  final List<RespuestaAct> borrador;
  final EntregaAct? miEntrega;

  const ActParaResponder({
    required this.id,
    required this.modo,
    required this.titulo,
    required this.instrucciones,
    required this.estado,
    required this.cierraAt,
    required this.anonimato,
    required this.porAlumno,
    required this.entrega,
    required this.notaMaxima,
    required this.intentosUsados,
    required this.intentosMaximo,
    required this.preguntas,
    required this.borrador,
    required this.miEntrega,
  });

  factory ActParaResponder.fromJson(Map<String, dynamic> j) {
    final intentos = _mapa(j['intentos']) ?? const {};
    final preguntas = _lista(j['preguntas']).map(PreguntaAct.fromJson).toList()
      ..sort((a, b) => a.orden != b.orden
          ? a.orden.compareTo(b.orden)
          : a.id.compareTo(b.id));

    return ActParaResponder(
      id: enteroO(j['id']),
      modo: '${j['modo'] ?? ''}',
      titulo: '${j['titulo'] ?? ''}',
      instrucciones: textoDeHtml(_txt(j['instrucciones'])),
      estado: '${j['estado'] ?? ''}',
      cierraAt: horaDeActividad(j['cierra_at']),
      anonimato: '${j['anonimato'] ?? 'nombre'}',
      porAlumno: _mapa(j['por_alumno']) == null
          ? null
          : PersonaCorta.fromJson(_mapa(j['por_alumno'])!),
      entrega: _mapa(j['entrega']) == null
          ? null
          : EntregaPedida.fromJson(_mapa(j['entrega'])!),
      notaMaxima: entero(j['nota_maxima']),
      intentosUsados: enteroO(intentos['usados']),
      intentosMaximo: enteroO(intentos['maximo'], 1),
      preguntas: preguntas,
      borrador: _lista(j['borrador']).map(RespuestaAct.fromJson).toList(),
      miEntrega: _mapa(j['mi_entrega']) == null
          ? null
          : EntregaAct.fromJson(_mapa(j['mi_entrega'])!),
    );
  }

  bool get anonima => anonimato != 'nombre';
  bool get sinIntentos => intentosUsados >= intentosMaximo;
}

/// `ResultadoDeEnvio`.
class ResultadoDeEnvio {
  final int? nota;
  final double? puntaje;
  final double? puntajeMax;
  final int quedanIntentos;

  const ResultadoDeEnvio({
    this.nota,
    this.puntaje,
    this.puntajeMax,
    this.quedanIntentos = 0,
  });

  factory ResultadoDeEnvio.fromJson(Map<String, dynamic> j) => ResultadoDeEnvio(
        nota: entero(j['nota']),
        puntaje: j['puntaje'] == null ? null : decimalO(j['puntaje']),
        puntajeMax:
            j['puntaje_max'] == null ? null : decimalO(j['puntaje_max']),
        quedanIntentos: enteroO(j['quedan_intentos']),
      );
}

/// Una fila de «mis respuestas»: la pregunta, lo mío y si acerté.
class RespuestaMia {
  final PreguntaAct pregunta;
  final RespuestaAct? mia;

  /// Null cuando no se enseñan las correctas.
  final bool? acerto;

  const RespuestaMia({required this.pregunta, this.mia, this.acerto});

  factory RespuestaMia.fromJson(Map<String, dynamic> j) => RespuestaMia(
        pregunta: PreguntaAct.fromJson(_mapa(j['pregunta']) ?? const {}),
        mia: _mapa(j['mia']) == null
            ? null
            : RespuestaAct.fromJson(_mapa(j['mia'])!),
        acerto: siONo(j['acerto']),
      );
}

/// Una barra de un resultado compartido: una opción o un valor de la escala.
class BarraCompartida {
  final String etiqueta;
  final int n;

  /// Si es lo que eligió quien mira: la marca «tú».
  final bool mia;

  const BarraCompartida(
      {required this.etiqueta, required this.n, this.mia = false});
}

/// Una pregunta de los resultados compartidos (`ResultadoDePregunta`).
class ResultadoCompartido {
  final String tipo;
  final String enunciado;
  final int respondidaPor;

  /// Menos de cinco respuestas: no se enseñan cifras (k-anonimato, §2.6).
  final bool oculto;
  final List<BarraCompartida> barras;
  final double? promedio;
  final List<String> textos;

  const ResultadoCompartido({
    required this.tipo,
    required this.enunciado,
    required this.respondidaPor,
    required this.oculto,
    required this.barras,
    this.promedio,
    this.textos = const [],
  });

  factory ResultadoCompartido.fromJson(Map<String, dynamic> j) {
    final escala = _lista(j['escala']);
    final barras = escala.isNotEmpty
        ? (escala
            .map((e) => BarraCompartida(
                  etiqueta: '${e['valor'] ?? ''}',
                  n: enteroO(e['n']),
                  mia: siONo(e['mia']) ?? false,
                ))
            .toList()
          ..sort((a, b) => b.etiqueta.compareTo(a.etiqueta)))
        : _lista(j['opciones'])
            .map((o) => BarraCompartida(
                  etiqueta: entero(o['opcion_id']) == null
                      ? 'Otra'
                      : '${o['definicion'] ?? ''}',
                  n: enteroO(o['n']),
                  mia: siONo(o['mia']) ?? false,
                ))
            .toList();

    return ResultadoCompartido(
      tipo: '${j['tipo'] ?? ''}',
      enunciado: '${j['enunciado'] ?? ''}',
      respondidaPor: enteroO(j['respondida_por']),
      oculto: siONo(j['oculto']) ?? false,
      barras: barras,
      promedio: j['promedio'] == null ? null : decimalO(j['promedio']),
      textos: _lista(j['textos'])
          .map((t) => '${t['texto'] ?? ''}')
          .where((t) => t.trim().isNotEmpty)
          .toList(),
    );
  }
}

/// Los resultados que el creador compartió al cerrar una encuesta.
class ResultadosCompartidos {
  final int destinatarios;
  final int respondieron;
  final List<ResultadoCompartido> preguntas;

  const ResultadosCompartidos({
    required this.destinatarios,
    required this.respondieron,
    required this.preguntas,
  });

  factory ResultadosCompartidos.fromJson(Map<String, dynamic> j) {
    final p = _mapa(j['participacion']) ?? const {};
    return ResultadosCompartidos(
      destinatarios: enteroO(p['destinatarios']),
      respondieron: enteroO(p['respondieron']),
      preguntas:
          _lista(j['preguntas']).map(ResultadoCompartido.fromJson).toList(),
    );
  }
}

/// `MisRespuestasAct`.
class MisRespuestasAct {
  final ActEnBandeja actividad;
  final DateTime? enviadaAt;
  final int? nota;
  final double? puntaje;
  final double? puntajeMax;
  final int? correctas;
  final int? tiempoSegundos;
  final int intentos;
  final double? promedioGrupo;
  final List<RespuestaMia> respuestas;
  final EntregaAct? entrega;
  final ResultadosCompartidos? compartidos;

  const MisRespuestasAct({
    required this.actividad,
    this.enviadaAt,
    this.nota,
    this.puntaje,
    this.puntajeMax,
    this.correctas,
    this.tiempoSegundos,
    this.intentos = 0,
    this.promedioGrupo,
    this.respuestas = const [],
    this.entrega,
    this.compartidos,
  });

  factory MisRespuestasAct.fromJson(Map<String, dynamic> j) => MisRespuestasAct(
        actividad: ActEnBandeja.fromJson(_mapa(j['actividad']) ?? const {}),
        enviadaAt: horaDeActividad(j['enviada_at']),
        nota: entero(j['nota']),
        puntaje: j['puntaje'] == null ? null : decimalO(j['puntaje']),
        puntajeMax:
            j['puntaje_max'] == null ? null : decimalO(j['puntaje_max']),
        correctas: entero(j['correctas']),
        tiempoSegundos: entero(j['tiempo_segundos']),
        intentos: enteroO(j['intentos']),
        promedioGrupo:
            j['promedio_grupo'] == null ? null : decimalO(j['promedio_grupo']),
        respuestas: _lista(j['respuestas']).map(RespuestaMia.fromJson).toList(),
        entrega: _mapa(j['entrega']) == null
            ? null
            : EntregaAct.fromJson(_mapa(j['entrega'])!),
        compartidos: _mapa(j['compartidos']) == null
            ? null
            : ResultadosCompartidos.fromJson(_mapa(j['compartidos'])!),
      );
}
