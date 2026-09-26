import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Utils/ElegirParaActividad.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/RecorridoActividad.dart';
import 'package:myvc_flutter/Widgets/CampoDePregunta.dart';
import 'package:url_launcher/url_launcher.dart';

/// Entregar una tarea: foto, archivo, enlace y texto, lo que la tarea pida.
///
/// Maqueta `FlutterTarea`. Las reglas son las de Joseth (26 sep) y las del
/// servidor (`EntregasController`):
///
/// - **Una foto y un archivo como máximo**, 5 MB cada uno. Subir otra foto
///   reemplaza la anterior —lo hace el servidor—, así que aquí no hay lista.
/// - **La foto se reduce en el teléfono** antes de subirla: 1280 px de lado
///   largo en calidad Normal, 800 en Ligera. Sin «modo cuaderno».
/// - Por encima de 5 MB no se sube: se ofrece pegar un enlace.
/// - Los archivos se suben al elegirlos y la entrega se hace con el botón: lo
///   subido no cuenta hasta «Entregar». Se puede cambiar hasta el cierre; una
///   entrega calificada ya no se toca.
class EntregarTareaScreen extends StatefulWidget {
  const EntregarTareaScreen({super.key, required this.fila});

  final ActEnBandeja fila;

  @override
  State<EntregarTareaScreen> createState() => _EntregarTareaScreenState();
}

class _EntregarTareaScreenState extends State<EntregarTareaScreen> {
  final _server = Server();
  final _texto = TextEditingController();

  bool _cargando = true;
  String? _error;
  ActParaResponder? _act;
  EntregaAct? _entrega;

  ArchivoAct? _foto;
  Uint8List? _fotoBytes;
  ArchivoAct? _archivo;
  String? _enlace;
  final Map<int, RespuestaAct> _respuestas = {};

  CalidadDeFoto _calidad = CalidadDeFoto.normal;
  bool _subiendoFoto = false;
  bool _subiendoArchivo = false;
  bool _entregando = false;

  /// Si hay algo distinto de lo entregado.
  bool _cambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final act = await traerParaResponder(_server, widget.fila.id);
      if (!mounted) return;
      final e = act.miEntrega;
      setState(() {
        _act = act;
        _entrega = e;
        _foto = e?.foto;
        _archivo = e?.archivo;
        _enlace = e?.enlace;
        _texto.text = e?.texto ?? '';
        for (final r in act.borrador) {
          _respuestas[r.preguntaId] = r;
        }
        _cargando = false;
      });
      final foto = e?.foto;
      if (foto != null) _bajarFoto(foto.id);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$err';
      });
    }
  }

  Future<void> _bajarFoto(int id) async {
    try {
      final bytes = await traerArchivoDeActividad(_server, id);
      if (mounted && _foto?.id == id) setState(() => _fotoBytes = bytes);
    } catch (_) {
      // Sin la miniatura se sigue viendo el nombre: no vale la pena un aviso.
    }
  }

  bool get _calificada => _entrega?.calificada ?? false;

  void _avisar(String texto) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _elegirFoto() async {
    final elegida = await elegirFotoReducida(context, _calidad);
    if (elegida == null || !mounted) return;
    if (elegida.bytes.length > topeDeArchivoAct) {
      await _demasiadoGrande();
      return;
    }
    setState(() => _subiendoFoto = true);
    try {
      final subida = await subirArchivoDeActividad(_server, _act!.id,
          clase: 'foto', bytes: elegida.bytes, nombre: elegida.nombre);
      if (!mounted) return;
      setState(() {
        _foto = subida;
        _fotoBytes = elegida.bytes;
        _cambios = true;
      });
    } catch (err) {
      if (mounted) _avisar('$err');
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _elegirArchivo() async {
    final elegido = await elegirDocumento();
    if (elegido == null || !mounted) return;
    if (elegido.bytes.length > topeDeArchivoAct) {
      await _demasiadoGrande();
      return;
    }
    setState(() => _subiendoArchivo = true);
    try {
      final subido = await subirArchivoDeActividad(_server, _act!.id,
          clase: 'archivo', bytes: elegido.bytes, nombre: elegido.nombre);
      if (!mounted) return;
      setState(() {
        _archivo = subido;
        _cambios = true;
      });
    } catch (err) {
      if (mounted) _avisar('$err');
    } finally {
      if (mounted) setState(() => _subiendoArchivo = false);
    }
  }

  Future<void> _demasiadoGrande() async {
    final conEnlace = _act?.entrega?.enlace ?? false;
    final pegar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('El archivo pasa de 5 MB'),
        content: Text(conEnlace
            ? 'Súbelo a Drive, OneDrive o donde lo guardes, y pega aquí el '
                'enlace.'
            : 'Esta tarea recibe archivos de hasta 5 MB. Prueba con uno más '
                'liviano, o con la foto en calidad Ligera.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Entendido')),
          if (conEnlace)
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Pegar un enlace')),
        ],
      ),
    );
    if (pegar == true) await _pedirEnlace();
  }

  Future<void> _pedirEnlace() async {
    final control = TextEditingController(text: _enlace ?? '');
    final escrito = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pega el enlace'),
        content: TextField(
          controller: control,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, control.text.trim()),
              child: const Text('Poner')),
        ],
      ),
    );
    control.dispose();
    if (escrito == null || !mounted) return;
    if (escrito.isEmpty) {
      setState(() {
        _enlace = null;
        _cambios = true;
      });
      return;
    }
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(escrito)) {
      _avisar('El enlace tiene que empezar por http:// o https://');
      return;
    }
    setState(() {
      _enlace = escrito;
      _cambios = true;
    });
  }

  Future<void> _entregar() async {
    final act = _act!;
    final pedida = act.entrega ?? const EntregaPedida();
    final texto = _texto.text.trim();
    final visibles = preguntasVisibles(act.preguntas, _respuestas).toSet();

    setState(() => _entregando = true);
    try {
      final hecha = await entregarTarea(
        _server,
        act.id,
        texto: pedida.texto && texto.isNotEmpty ? texto : null,
        enlace: pedida.enlace ? _enlace : null,
        fotoId: pedida.foto ? _foto?.id : null,
        archivoId: pedida.archivo ? _archivo?.id : null,
        respuestas: act.preguntas.isEmpty
            ? null
            : _respuestas.values.where((r) => visibles.contains(r.preguntaId)),
      );
      if (!mounted) return;
      setState(() {
        _entrega = hecha;
        _cambios = false;
      });
    } catch (err) {
      if (mounted) _avisar('$err');
    } finally {
      if (mounted) setState(() => _entregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EstiloActividades.fondo,
      body: SafeArea(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final act = _act;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(),
        Expanded(
          child: act == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error ?? 'No se pudo abrir la tarea.',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(act.titulo,
                          style: const TextStyle(fontSize: 24, height: 1.2)),
                    ),
                    const SizedBox(height: 8),
                    _autor(act),
                    const SizedBox(height: 10),
                    if (act.instrucciones.isNotEmpty ||
                        (widget.fila.califica && act.notaMaxima != null))
                      _instrucciones(act),
                    const SizedBox(height: 10),
                    _tuEntrega(act),
                    if (_entrega?.entregada ?? false) ...[
                      const SizedBox(height: 10),
                      _notaDeEntregada(),
                    ],
                  ],
                ),
        ),
        if (act != null && !_calificada)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: EstiloActividades.botonPrincipal(
                color: (_entrega?.entregada ?? false)
                    ? EstiloActividades.normalTinta
                    : EstiloActividades.primario,
              ),
              onPressed: _entregando ||
                      _subiendoFoto ||
                      _subiendoArchivo ||
                      ((_entrega?.entregada ?? false) && !_cambios)
                  ? null
                  : _entregar,
              child: _entregando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text((_entrega?.entregada ?? false)
                      ? 'Cambiar mi entrega'
                      : 'Entregar'),
            ),
          ),
      ],
    );
  }

  Widget _cabecera() {
    final e = _entrega;
    final (texto, fondo, tinta) = e?.calificada ?? false
        ? (
            'Calificada',
            EstiloActividades.hechaFondo,
            EstiloActividades.hechaTinta
          )
        : e?.entregada ?? false
            ? (
                e!.tarde ? 'Entregada tarde' : 'Entregada',
                EstiloActividades.hechaFondo,
                EstiloActividades.hechaTinta
              )
            : (
                'Pendiente',
                EstiloActividades.urgenteFondo,
                EstiloActividades.urgenteTinta
              );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.fila.donde,
                style: const TextStyle(
                    fontSize: 12.5, color: EstiloActividades.tintaApagada)),
          ),
          if (_act != null) EstiloActividades.pildora(texto, fondo, tinta),
        ],
      ),
    );
  }

  Widget _autor(ActParaResponder act) {
    final c = widget.fila.creador;
    final partes = [
      c.nombre,
      if (act.cierraAt != null) 'entrega el ${fechaDeActividad(act.cierraAt!)}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF8A5A3C),
            foregroundImage:
                c.fotoUrl == null ? null : NetworkImage(c.fotoUrl!),
            child: Text(c.iniciales,
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(partes.join(' · '),
                style: const TextStyle(
                    fontSize: 12.5, color: EstiloActividades.tintaSuave)),
          ),
        ],
      ),
    );
  }

  Widget _instrucciones(ActParaResponder act) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: EstiloActividades.bloque(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (act.instrucciones.isNotEmpty)
            Text(act.instrucciones,
                style: const TextStyle(fontSize: 13.5, height: 1.5)),
          if (widget.fila.califica && act.notaMaxima != null)
            Padding(
              padding: EdgeInsets.only(top: act.instrucciones.isEmpty ? 0 : 8),
              child: Text('Vale ${act.notaMaxima} puntos · va a la planilla',
                  style: const TextStyle(
                      fontSize: 12, color: EstiloActividades.tintaApagada)),
            ),
        ],
      ),
    );
  }

  Widget _tuEntrega(ActParaResponder act) {
    final pide = act.entrega ?? const EntregaPedida();
    final soloLectura = _calificada;
    final visibles = preguntasVisibles(act.preguntas, _respuestas);

    final botones = <Widget>[
      if (pide.foto)
        _adjuntar(
          icono: Icons.photo_camera_outlined,
          texto: _foto == null ? 'Foto' : 'Otra foto',
          ocupado: _subiendoFoto,
          alTocar: soloLectura ? null : _elegirFoto,
        ),
      if (pide.archivo)
        _adjuntar(
          icono: Icons.description_outlined,
          texto: _archivo == null ? 'Archivo' : 'Otro archivo',
          ocupado: _subiendoArchivo,
          alTocar: soloLectura ? null : _elegirArchivo,
        ),
      if (pide.enlace)
        _adjuntar(
          icono: Icons.link,
          texto: _enlace == null ? 'Enlace' : 'Cambiar enlace',
          ocupado: false,
          alTocar: soloLectura ? null : _pedirEnlace,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: EstiloActividades.bloque(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Tu entrega',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_foto != null) ...[
            _miniaturaDeFoto(soloLectura),
            const SizedBox(height: 10),
          ],
          if (_archivo != null) ...[
            _fichaDeArchivo(_archivo!, soloLectura),
            const SizedBox(height: 8),
          ],
          if (_enlace != null) ...[
            _fichaDeEnlace(_enlace!, soloLectura),
            const SizedBox(height: 8),
          ],
          if (botones.isNotEmpty && !soloLectura)
            Row(
              children: [
                for (var i = 0; i < botones.length; i++) ...[
                  Expanded(child: botones[i]),
                  if (i < botones.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          if (pide.foto && !soloLectura) ...[
            const SizedBox(height: 10),
            _calidades(),
          ],
          if ((pide.foto || pide.archivo) && !soloLectura) ...[
            const SizedBox(height: 6),
            const Text(
              'Una foto y un archivo como máximo. Hasta 5 MB por archivo.',
              style: TextStyle(
                  fontSize: 12, color: EstiloActividades.tintaApagada),
            ),
          ],
          if (pide.texto) ...[
            const SizedBox(height: 12),
            Text(
              pide.foto || pide.archivo || pide.enlace
                  ? 'Un comentario para tu docente (opcional)'
                  : 'Tu respuesta',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: EstiloActividades.normalTinta),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _texto,
              readOnly: soloLectura,
              minLines: 2,
              maxLines: 8,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _cambios = true),
              decoration: InputDecoration(
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          for (final p in act.preguntas)
            if (visibles.contains(p.id))
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: CampoDePregunta(
                  key: ValueKey(p.id),
                  pregunta: p,
                  respuesta: _respuestas[p.id],
                  grande: false,
                  soloLectura: soloLectura,
                  alCambiar: (r) => setState(() {
                    if (r == null) {
                      _respuestas.remove(p.id);
                    } else {
                      _respuestas[p.id] = r;
                    }
                    _cambios = true;
                  }),
                ),
              ),
        ],
      ),
    );
  }

  Widget _adjuntar({
    required IconData icono,
    required String texto,
    required bool ocupado,
    required VoidCallback? alTocar,
  }) {
    return Material(
      color: const Color(0xFFFAFBFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x33172640), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: ocupado ? null : alTocar,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ocupado
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icono, size: 20, color: EstiloActividades.normalTinta),
              const SizedBox(height: 4),
              Text(ocupado ? 'Subiendo…' : texto,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: EstiloActividades.normalTinta)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calidades() {
    final peso = _fotoBytes != null && _cambios
        ? pesoLegible(_fotoBytes!.length)
        : (_calidad == CalidadDeFoto.normal ? '≈ 220 KB' : '≈ 110 KB');
    return Row(
      children: [
        const Text('Calidad',
            style:
                TextStyle(fontSize: 12, color: EstiloActividades.tintaSuave)),
        const SizedBox(width: 6),
        for (final c in CalidadDeFoto.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(c.nombre),
              selected: _calidad == c,
              showCheckmark: false,
              selectedColor: EstiloActividades.primario,
              labelStyle: TextStyle(
                fontSize: 12,
                color: _calidad == c ? Colors.white : EstiloActividades.tinta,
                fontWeight: _calidad == c ? FontWeight.w600 : FontWeight.w400,
              ),
              onSelected: (_) => setState(() => _calidad = c),
            ),
          ),
        const Spacer(),
        Text(peso,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _miniaturaDeFoto(bool soloLectura) {
    final bytes = _fotoBytes;
    return Row(
      children: [
        GestureDetector(
          onTap: bytes == null ? null : () => _verFoto(bytes),
          child: Container(
            width: 72,
            height: 92,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14172640)),
            ),
            child: bytes == null
                ? const Icon(Icons.image_outlined)
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_foto?.nombreOriginal ?? 'Foto',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5)),
        ),
        if (!soloLectura)
          IconButton(
            tooltip: 'Quitar la foto',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _foto = null;
              _fotoBytes = null;
              _cambios = true;
            }),
          ),
      ],
    );
  }

  void _verFoto(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }

  Widget _fichaDeArchivo(ArchivoAct a, bool soloLectura) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EstiloActividades.fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: EstiloActividades.urgenteFondo,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(a.extension,
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: EstiloActividades.urgenteTinta)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nombreOriginal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(pesoLegible(a.bytes),
                    style: const TextStyle(
                        fontSize: 12, color: EstiloActividades.tintaApagada)),
              ],
            ),
          ),
          if (!soloLectura)
            IconButton(
              tooltip: 'Quitar el archivo',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                _archivo = null;
                _cambios = true;
              }),
            ),
        ],
      ),
    );
  }

  Widget _fichaDeEnlace(String enlace, bool soloLectura) {
    return Row(
      children: [
        const Icon(Icons.link, size: 18, color: EstiloActividades.tintaSuave),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () async {
              final uri = Uri.tryParse(enlace);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(enlace,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0E56BD),
                    decoration: TextDecoration.underline)),
          ),
        ),
        if (!soloLectura)
          IconButton(
            tooltip: 'Quitar el enlace',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _enlace = null;
              _cambios = true;
            }),
          ),
      ],
    );
  }

  Widget _notaDeEntregada() {
    final e = _entrega!;
    // «… 7:12 p. m.» ya termina en punto: no se le pone otro.
    final entregada = 'Entregada ${momentoDeActividad(e.entregadaAt!)}'
        '${e.tarde ? ', tarde' : ''}';
    final texto = e.calificada
        ? 'Calificada: ${e.nota}${_act?.notaMaxima != null ? ' de ${_act!.notaMaxima}' : ''}.'
            '${(e.comentario ?? '').isNotEmpty ? ' «${e.comentario}»' : ''}'
        : '$entregada${entregada.endsWith('.') ? ' ' : '. '}'
            '${_cambios ? 'Tienes cambios sin entregar.' : 'Puedes cambiarla hasta el cierre.'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cambios
            ? EstiloActividades.ramaFondo
            : EstiloActividades.hechaFondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12.5,
              color: _cambios
                  ? EstiloActividades.ramaTinta
                  : const Color(0xFF2B5B10))),
    );
  }
}
