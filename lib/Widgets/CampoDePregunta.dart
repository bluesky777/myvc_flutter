import 'dart:math';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lo que se ve de una pregunta al responderla: el enunciado con su imagen,
/// su video o su enlace, y el control de su tipo.
///
/// Lo usan las dos pantallas que responden: la de una pregunta por pantalla
/// (encuestas y cuestionarios) y la de la tarea, cuando la tarea trae
/// preguntas. **No guarda nada**: avisa con [alCambiar] y quien lo usa decide
/// cuándo va al servidor.
///
/// Se monta con `key: ValueKey(pregunta.id)`: los campos de texto guardan su
/// propio estado, y sin la llave pasar a la pregunta siguiente dejaría escrito
/// lo de la anterior.
class CampoDePregunta extends StatefulWidget {
  const CampoDePregunta({
    super.key,
    required this.pregunta,
    required this.respuesta,
    required this.alCambiar,
    this.alPedirArchivo,
    this.grande = true,
    this.soloLectura = false,
  });

  final PreguntaAct pregunta;
  final RespuestaAct? respuesta;
  final ValueChanged<RespuestaAct?> alCambiar;

  /// Sube el archivo de una pregunta `archivo` y devuelve la respuesta con su
  /// `archivo_id`, o null si se canceló. Sin él, la pregunta dice que no se
  /// puede responder desde aquí.
  final Future<RespuestaAct?> Function(PreguntaAct)? alPedirArchivo;

  /// El enunciado grande de una pregunta por pantalla, o el pequeño de una
  /// lista.
  final bool grande;
  final bool soloLectura;

  @override
  State<CampoDePregunta> createState() => _CampoDePreguntaState();
}

class _CampoDePreguntaState extends State<CampoDePregunta> {
  late final TextEditingController _texto;
  late final TextEditingController _otra;
  late List<OpcionAct> _opciones;
  bool _otraMarcada = false;
  bool _subiendo = false;

  PreguntaAct get p => widget.pregunta;
  RespuestaAct? get r => widget.respuesta;

  @override
  void initState() {
    super.initState();
    final deOpciones = p.esDeOpciones;
    _texto = TextEditingController(text: deOpciones ? '' : (r?.texto ?? ''));
    _otra = TextEditingController(text: deOpciones ? (r?.texto ?? '') : '');
    _otraMarcada = deOpciones && (r?.texto ?? '').isNotEmpty;

    // Barajadas con la pregunta de semilla: el orden cambia de pregunta a
    // pregunta, pero no cada vez que se vuelve a ella.
    _opciones = [...p.opciones];
    if (p.aleatorias) _opciones.shuffle(Random(p.id));
  }

  @override
  void dispose() {
    _texto.dispose();
    _otra.dispose();
    super.dispose();
  }

  void _cambiar({
    List<int>? opcionIds,
    String? texto,
    int? valor,
    String? fecha,
    bool limpiarTexto = false,
  }) {
    final nueva = RespuestaAct(
      preguntaId: p.id,
      opcionIds: opcionIds ?? r?.opcionIds ?? const [],
      texto: limpiarTexto ? null : (texto ?? r?.texto),
      valor: valor ?? r?.valor,
      fecha: fecha ?? r?.fecha,
      archivoId: r?.archivoId,
      archivoNombre: r?.archivoNombre,
    );
    widget.alCambiar(nueva);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.tieneCondiciones && widget.grande)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EstiloActividades.pildora('Por lo que respondiste',
                  EstiloActividades.ramaFondo, EstiloActividades.ramaTinta),
            ),
          ),
        Text(
          p.enunciado + (p.obligatoria ? '' : ' (opcional)'),
          style: widget.grande
              ? const TextStyle(
                  fontSize: 24, height: 1.2, color: EstiloActividades.tinta)
              : const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: EstiloActividades.tinta),
        ),
        if ((p.ayuda ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(p.ayuda!,
              style: const TextStyle(
                  fontSize: 13.5, color: EstiloActividades.tintaSuave)),
        ],
        ..._medios(),
        SizedBox(height: widget.grande ? 18 : 10),
        _control(),
      ],
    );
  }

  List<Widget> _medios() {
    final hijos = <Widget>[];

    if (p.imagenUrl != null) {
      hijos.add(Padding(
        padding: const EdgeInsets.only(top: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            p.imagenUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 60,
              child: Center(child: Text('No se pudo cargar la imagen.')),
            ),
          ),
        ),
      ));
    }

    if (p.youtubeId != null) hijos.add(_video(p.youtubeId!));

    if (p.enlaceUrl != null) {
      hijos.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _abrir(p.enlaceUrl!),
            icon: const Icon(Icons.link),
            label: const Text('Abrir el enlace'),
          ),
        ),
      ));
    }

    return hijos;
  }

  /// El video, como miniatura que abre YouTube.
  ///
  /// **No se incrusta un reproductor**: haría falta un `webview` en la app, que
  /// es un paquete nativo más para una sola clase de pregunta. La miniatura es
  /// la de YouTube (`img.youtube.com`) y el toque abre el video en su app o
  /// en el navegador, desde el segundo que eligió el docente.
  Widget _video(String id) {
    final inicio = p.youtubeInicio;
    final url =
        'https://www.youtube.com/watch?v=$id${inicio != null && inicio > 0 ? '&t=${inicio}s' : ''}';

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        button: true,
        label: 'Ver el video en YouTube',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _abrir(url),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    'https://img.youtube.com/vi/$id/hqdefault.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF1D3B2A)),
                  ),
                ),
                Center(
                  child: Container(
                    width: 60,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE62117),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _control() {
    switch (p.tipo) {
      case 'unica':
      case 'sino':
      case 'video':
        return _opcionesUna();
      case 'imagen_opciones':
        return _opcionesConImagen();
      case 'multiple':
        return _opcionesVarias();
      case 'corta':
      case 'parrafo':
        return _campoDeTexto();
      case 'escala':
        return _escala();
      case 'fecha':
        return _fecha();
      case 'archivo':
        return _archivo();
      default:
        return const Text('Esta pregunta no se puede responder desde el '
            'teléfono. Ábrela en la web.');
    }
  }

  Widget _opcion({
    required String texto,
    required bool marcada,
    required bool cuadrada,
    required VoidCallback? alTocar,
  }) {
    const base = EstiloActividades.primario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: marcada ? EstiloActividades.primarioSuave : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: marcada ? base : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.soloLectura ? null : alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    cuadrada
                        ? (marcada
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                        : (marcada
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    color: marcada ? base : const Color(0x4D172640),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: marcada ? FontWeight.w600 : FontWeight.w400,
                        color: EstiloActividades.tinta,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoOtra(bool unica) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _otra,
        maxLength: 300,
        readOnly: widget.soloLectura,
        decoration: _decoracion('Escribe tu respuesta'),
        onChanged: (t) => unica
            ? _cambiar(opcionIds: const [], texto: t)
            : _cambiar(texto: t),
      ),
    );
  }

  Widget _opcionesUna() {
    final elegida = r?.opcionIds.isNotEmpty == true ? r!.opcionIds.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in _opciones)
          _opcion(
            texto: o.definicion,
            marcada: !_otraMarcada && elegida == o.id,
            cuadrada: false,
            alTocar: () {
              setState(() => _otraMarcada = false);
              _cambiar(opcionIds: [o.id], limpiarTexto: true);
            },
          ),
        if (p.opcionOtra) ...[
          _opcion(
            texto: 'Otra…',
            marcada: _otraMarcada,
            cuadrada: false,
            alTocar: () {
              setState(() => _otraMarcada = true);
              _cambiar(opcionIds: const [], texto: _otra.text);
            },
          ),
          if (_otraMarcada) _campoOtra(true),
        ],
      ],
    );
  }

  Widget _opcionesVarias() {
    final marcadas = r?.opcionIds ?? const <int>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Marca todas las que apliquen',
              style: TextStyle(
                  fontSize: 12.5, color: EstiloActividades.tintaApagada)),
        ),
        for (final o in _opciones)
          _opcion(
            texto: o.definicion,
            marcada: marcadas.contains(o.id),
            cuadrada: true,
            alTocar: () {
              final nuevas = [...marcadas];
              nuevas.contains(o.id) ? nuevas.remove(o.id) : nuevas.add(o.id);
              _cambiar(opcionIds: nuevas);
            },
          ),
        if (p.opcionOtra) ...[
          _opcion(
            texto: 'Otra…',
            marcada: _otraMarcada,
            cuadrada: true,
            alTocar: () {
              setState(() => _otraMarcada = !_otraMarcada);
              if (_otraMarcada) {
                _cambiar(texto: _otra.text);
              } else {
                _cambiar(limpiarTexto: true);
              }
            },
          ),
          if (_otraMarcada) _campoOtra(false),
        ],
      ],
    );
  }

  Widget _opcionesConImagen() {
    final elegida = r?.opcionIds.isNotEmpty == true ? r!.opcionIds.first : null;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: [
        for (final o in _opciones)
          Material(
            color: elegida == o.id
                ? EstiloActividades.primarioSuave
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: elegida == o.id
                    ? EstiloActividades.primario
                    : Colors.transparent,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.soloLectura
                  ? null
                  : () => _cambiar(opcionIds: [o.id], limpiarTexto: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: o.imagenUrl == null
                        ? const Icon(Icons.image_not_supported_outlined)
                        : Image.network(o.imagenUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported_outlined)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(o.definicion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: elegida == o.id
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _decoracion(String pista) => InputDecoration(
        hintText: pista,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: EstiloActividades.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: EstiloActividades.borde, width: 1.5),
        ),
      );

  Widget _campoDeTexto() {
    final larga = p.tipo == 'parrafo';
    return TextField(
      controller: _texto,
      readOnly: widget.soloLectura,
      minLines: larga ? 5 : 1,
      maxLines: larga ? 10 : 3,
      maxLength: larga ? 5000 : 300,
      textCapitalization: TextCapitalization.sentences,
      decoration: _decoracion('Tu respuesta'),
      style: const TextStyle(fontSize: 15),
      onChanged: (t) => _cambiar(texto: t),
    );
  }

  Widget _escala() {
    final valor = r?.valor;
    const caras = [
      Icons.sentiment_very_dissatisfied_outlined,
      Icons.sentiment_dissatisfied_outlined,
      Icons.sentiment_neutral_outlined,
      Icons.sentiment_satisfied_outlined,
      Icons.sentiment_very_satisfied_outlined,
    ];
    final estilo = p.escalaEstilo ?? 'numeros';

    Widget contenido(int n, bool elegido) {
      final color = elegido ? Colors.white : EstiloActividades.tinta;
      if (estilo == 'caras') return Icon(caras[n - 1], color: color, size: 30);
      if (estilo == 'estrellas') {
        final llena = valor != null && n <= valor;
        return Icon(llena ? Icons.star : Icons.star_border,
            color: elegido
                ? Colors.white
                : (llena ? EstiloActividades.primario : color),
            size: 30);
      }
      return Text('$n', style: TextStyle(fontSize: 22, color: color));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var n = 1; n <= 5; n++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: n < 5 ? 8 : 0),
                  child: Semantics(
                    selected: valor == n,
                    label: '$n de 5',
                    child: Material(
                      color: valor == n
                          ? EstiloActividades.primario
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.soloLectura
                            ? null
                            : () => _cambiar(valor: n),
                        child: SizedBox(
                          height: 64,
                          child: Center(child: contenido(n, valor == n)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (p.textoAbajo != null || p.textoArriba != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.textoAbajo ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: EstiloActividades.tintaApagada)),
                Text(p.textoArriba ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: EstiloActividades.tintaApagada)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _fecha() {
    final elegida = soloElDia(r?.fecha);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.event_outlined),
      label: Text(elegida == null
          ? 'Elegir la fecha'
          : fechaDeActividad(elegida, conHora: false)),
      onPressed: widget.soloLectura
          ? null
          : () async {
              final hoy = DateTime.now();
              final dia = await showDatePicker(
                context: context,
                initialDate: elegida ?? hoy,
                firstDate: DateTime(hoy.year - 100),
                lastDate: DateTime(hoy.year + 5),
              );
              if (dia == null) return;
              _cambiar(
                  fecha: '${dia.year}-${dia.month.toString().padLeft(2, '0')}-'
                      '${dia.day.toString().padLeft(2, '0')}');
            },
    );
  }

  Widget _archivo() {
    final pedir = widget.alPedirArchivo;
    if (pedir == null) {
      return const Text('Esta pregunta pide un archivo: respóndela en la web.');
    }
    final nombre =
        r?.archivoNombre ?? (r?.archivoId != null ? 'Archivo subido' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nombre != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: EstiloActividades.hechaTinta),
                const SizedBox(width: 8),
                Expanded(child: Text(nombre)),
              ],
            ),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: _subiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file),
          label:
              Text(nombre == null ? 'Subir un archivo' : 'Cambiar el archivo'),
          onPressed: widget.soloLectura || _subiendo
              ? null
              : () async {
                  setState(() => _subiendo = true);
                  try {
                    final nueva = await pedir(p);
                    if (nueva != null) widget.alCambiar(nueva);
                  } finally {
                    if (mounted) setState(() => _subiendo = false);
                  }
                },
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Hasta 5 MB.',
              style: TextStyle(
                  fontSize: 12, color: EstiloActividades.tintaApagada)),
        ),
      ],
    );
  }
}
