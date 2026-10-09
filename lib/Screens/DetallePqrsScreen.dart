import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/PqrsApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PqrsModel.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/EstiloPqrs.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Una PQRS del acudiente: el plazo, lo que escribió, la respuesta del colegio,
/// la encuesta de cierre y lo que ha pasado (Joseth, 9 oct 2026).
///
/// [recien] llega al radicar: enseña el radicado y el día que vence arriba, en
/// grande, que es lo que hay que guardar.
///
/// Los adjuntos que son imagen se ven aquí; un PDF o un Word todavía no se
/// abren en la app (no hay con qué sin una dependencia nueva): se dice, con el
/// nombre del fichero. Ver «Pendiente» en `docs/pqrs.md`.
class DetallePqrsScreen extends StatefulWidget {
  const DetallePqrsScreen({super.key, required this.pqrsId, this.recien});

  final int pqrsId;
  final DetallePqrs? recien;

  @override
  State<DetallePqrsScreen> createState() => _DetallePqrsScreenState();
}

class _DetallePqrsScreenState extends State<DetallePqrsScreen> {
  DetallePqrs? _p;
  String? _error;
  int _estrellas = 0;
  final _comentario = TextEditingController();
  bool _enviando = false;
  final Map<int, Future<Uint8List>> _imagenes = {};

  @override
  void initState() {
    super.initState();
    _p = widget.recien;
    if (_p == null) _cargar();
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final p = await traerPqrs(Server(), widget.pqrsId);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviarEncuesta() async {
    if (_estrellas == 0) {
      _avisar('Elige de 1 a 5.');
      return;
    }
    setState(() => _enviando = true);
    try {
      final p = await contestarEncuestaPqrs(Server(), widget.pqrsId,
          satisfaccion: _estrellas, comentario: _comentario.text);
      if (!mounted) return;
      setState(() {
        _p = p;
        _enviando = false;
      });
      _avisar('Gracias. La PQRS queda cerrada.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _avisar('$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: EstiloPqrs.fondo,
      appBar: AppBar(title: TituloPantalla(titulo: 'PQRS', subtitulo: p?.fila.radicado)),
      body: SafeArea(child: _cuerpo(p)),
    );
  }

  Widget _cuerpo(DetallePqrs? p) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ]),
        ),
      );
    }
    if (p == null) return const Center(child: CircularProgressIndicator());

    final f = p.fila;
    final deRadicacion = p.adjuntos.where((a) => a.momento == 'radicacion').toList();
    final deRespuesta = p.adjuntos.where((a) => a.momento == 'respuesta').toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.recien != null && f.estado == 'radicada') ...[_recien(f), const SizedBox(height: 14)],
          _cabeza(f),
          const SizedBox(height: 14),
          if (f.prorroga != null && p.respuesta == null) ...[_prorroga(f), const SizedBox(height: 14)],
          if (p.respuesta != null) ...[
            _respuesta(p, deRespuesta),
            const SizedBox(height: 14),
          ],
          if (p.puedeEncuesta) ...[_encuesta(), const SizedBox(height: 14)],
          if (p.satisfaccion != null) ...[_encuestaHecha(p), const SizedBox(height: 14)],
          _bloque([
            EstiloPqrs.rotulo('Lo que escribiste'),
            Text(p.descripcion, style: const TextStyle(fontSize: 14, height: 1.45, color: EstiloPqrs.tinta)),
            for (final a in deRadicacion) _adjunto(a),
          ]),
          const SizedBox(height: 14),
          _bloque([
            EstiloPqrs.rotulo('Lo que ha pasado'),
            for (final e in p.eventos.reversed) _evento(e),
          ]),
        ],
      ),
    );
  }

  Widget _bloque(List<Widget> hijos, {Color? borde}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: EstiloPqrs.bloque(borde: borde),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: hijos),
      );

  Widget _recien(FilaPqrs f) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaletaEstaciones.verdeFondo,
          borderRadius: BorderRadius.circular(EstiloActividades.radio),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: PaletaEstaciones.verdeTinta, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, height: 1.45, color: PaletaEstaciones.verdeTinta),
                  children: [
                    const TextSpan(text: 'Radicada. Tu radicado es '),
                    TextSpan(text: f.radicado, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (f.fechaLimite != null) ...[
                      const TextSpan(text: ', y el colegio responde a más tardar el '),
                      TextSpan(text: diaDePqrs(f.fechaLimite!), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                    const TextSpan(text: '. Te avisamos cuando responda.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _cabeza(FilaPqrs f) {
    final lineas = [f.tipoTexto, if (f.claseTexto.isNotEmpty) f.claseTexto, if (f.alumno != null) f.alumno!.nombre];
    return _bloque([
      Text(lineas.join(' · '), style: const TextStyle(fontSize: 12.5, color: EstiloPqrs.tintaApagada)),
      const SizedBox(height: 4),
      Text(f.asunto,
          style: const TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w700, color: EstiloPqrs.tinta)),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        EstiloPqrs.estado(f.estado, f.estadoTexto),
        if (f.abierta || f.plazo.clave == 'respondida') EstiloPqrs.plazo(f.plazo.texto, f.plazo.tono),
        if (f.abierta && f.prorroga != null) EstiloPqrs.prorrogada(),
      ]),
      const SizedBox(height: 10),
      Text(
        [
          if (f.radicadaAt != null) 'Radicada el ${fechaDeActividad(f.radicadaAt!)}',
          if (f.fechaLimite != null && f.abierta) 'el colegio responde a más tardar el ${diaDePqrs(f.fechaLimite!)}',
        ].join(' · '),
        style: const TextStyle(fontSize: 12.5, color: EstiloPqrs.tintaSuave),
      ),
    ]);
  }

  /// La prórroga, mientras no haya respuesta: la fecha nueva, la de antes y
  /// los motivos, que es lo que la ley manda decirle (Ley 1755, art. 14,
  /// parágrafo). Respondida, queda en «Lo que ha pasado».
  Widget _prorroga(FilaPqrs f) {
    final pr = f.prorroga!;
    return _bloque([
      EstiloPqrs.rotulo('El colegio pidió más tiempo'),
      Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, height: 1.45, color: EstiloPqrs.tinta),
          children: [
            const TextSpan(text: 'Te responde a más tardar el '),
            TextSpan(text: diaDePqrs(pr.hasta), style: const TextStyle(fontWeight: FontWeight.w800)),
            if (f.fechaLimiteInicial != null) TextSpan(text: ', en vez del ${diaDePqrs(f.fechaLimiteInicial!)}'),
            const TextSpan(text: '.'),
          ],
        ),
      ),
      if (pr.motivo.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(pr.motivo, style: const TextStyle(fontSize: 13.5, height: 1.45, color: EstiloPqrs.tintaSuave)),
      ],
    ], borde: PaletaEstaciones.ambar.withValues(alpha: .45));
  }

  Widget _respuesta(DetallePqrs p, List<AdjuntoPqrs> adjuntos) => _bloque([
        EstiloPqrs.rotulo('Respuesta del colegio'),
        Text(p.respuesta!, style: const TextStyle(fontSize: 14.5, height: 1.5, color: EstiloPqrs.tinta)),
        for (final a in adjuntos) _adjunto(a),
        const SizedBox(height: 10),
        Text(
          [if (p.respondidaPor != null) p.respondidaPor!, if (p.respondidaAt != null) fechaDeActividad(p.respondidaAt!)]
              .join(' · '),
          style: const TextStyle(fontSize: 12.5, color: EstiloPqrs.tintaApagada),
        ),
      ], borde: PaletaEstaciones.verde.withValues(alpha: .35));

  Widget _encuesta() => _bloque([
        EstiloPqrs.rotulo('¿Qué tal la respuesta?'),
        const Text('Califícala de 1 a 5. Al enviarla, la PQRS queda cerrada.',
            style: TextStyle(fontSize: 13, color: EstiloPqrs.tintaSuave)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 1; n <= 5; n++)
              IconButton(
                tooltip: '$n de 5',
                iconSize: 38,
                onPressed: _enviando ? null : () => setState(() => _estrellas = n),
                icon: Icon(n <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: n <= _estrellas ? const Color(0xFFE8A200) : EstiloPqrs.tintaApagada),
              ),
          ],
        ),
        if (_estrellas > 0)
          Center(
            child: Text(_palabra(_estrellas),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EstiloPqrs.tintaSuave)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _comentario,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Un comentario (opcional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        FilledButton(
          style: EstiloActividades.botonPrincipal(),
          onPressed: _enviando || _estrellas == 0 ? null : _enviarEncuesta,
          child: _enviando
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Enviar'),
        ),
      ]);

  String _palabra(int n) => switch (n) {
        1 => 'Muy mala',
        2 => 'Mala',
        3 => 'Regular',
        4 => 'Buena',
        _ => 'Muy buena',
      };

  Widget _encuestaHecha(DetallePqrs p) => _bloque([
        EstiloPqrs.rotulo('Tu calificación'),
        Row(children: [
          for (var n = 1; n <= 5; n++)
            Icon(n <= p.satisfaccion! ? Icons.star_rounded : Icons.star_outline_rounded,
                color: n <= p.satisfaccion! ? const Color(0xFFE8A200) : EstiloPqrs.tintaApagada),
          const SizedBox(width: 8),
          Text('${p.satisfaccion} de 5 · ${_palabra(p.satisfaccion!)}',
              style: const TextStyle(fontSize: 13, color: EstiloPqrs.tintaSuave)),
        ]),
        if ((p.comentario ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('«${p.comentario}»',
              style: const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic, color: EstiloPqrs.tintaSuave)),
        ],
      ]);

  Widget _adjunto(AdjuntoPqrs a) {
    if (a.esImagen) {
      final futuro = _imagenes.putIfAbsent(a.id, () => traerAdjuntoDePqrs(Server(), a.id));
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List>(
            future: futuro,
            builder: (context, snap) {
              if (snap.hasError) return _nombreDeAdjunto(a, 'No se pudo traer la imagen.');
              if (!snap.hasData) {
                return Container(
                  height: 120,
                  color: EstiloPqrs.fondo,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              }
              return GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(snap.data!))),
                ),
                child: Image.memory(snap.data!, fit: BoxFit.contain),
              );
            },
          ),
        ),
      );
    }
    return _nombreDeAdjunto(a, 'Este documento todavía no se abre en la app: pídelo en el colegio si lo necesitas.');
  }

  Widget _nombreDeAdjunto(AdjuntoPqrs a, String nota) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.attach_file, size: 18, color: EstiloPqrs.tintaSuave),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a.nombre} · ${pesoLegible(a.bytes)}', style: const TextStyle(fontSize: 13)),
                Text(nota, style: const TextStyle(fontSize: 12, color: EstiloPqrs.tintaApagada)),
              ]),
            ),
          ],
        ),
      );

  Widget _evento(EventoPqrs e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5, right: 10),
              decoration: const BoxDecoration(color: EstiloPqrs.primario, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.frase,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: EstiloPqrs.tinta)),
                if ((e.texto ?? '').isNotEmpty && e.tipo != 'encuesta')
                  Text(e.texto!, style: const TextStyle(fontSize: 13, color: EstiloPqrs.tintaSuave)),
                if (e.at != null)
                  Text(fechaDeActividad(e.at!),
                      style: const TextStyle(fontSize: 12, color: EstiloPqrs.tintaApagada)),
              ]),
            ),
          ],
        ),
      );
}
