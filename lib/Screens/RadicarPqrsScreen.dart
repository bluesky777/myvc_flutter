import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/PqrsApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PqrsModel.dart';
import 'package:myvc_flutter/Utils/ElegirParaActividad.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/EstiloPqrs.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Radicar una PQRS desde la app (Joseth, 9 oct 2026).
///
/// Una sola pantalla de arriba abajo: qué es, sobre cuál hijo (si es de uno),
/// el asunto, lo que pasó y, si hace falta, una foto o un documento. Los tipos
/// y sus explicaciones los manda el servidor, para que la app y la web digan
/// lo mismo. Al radicar vuelve con el detalle, que se abre con el radicado y
/// el día que vence en grande.
class RadicarPqrsScreen extends StatefulWidget {
  const RadicarPqrsScreen({super.key, required this.lista});

  final ListaDePqrs lista;

  @override
  State<RadicarPqrsScreen> createState() => _RadicarPqrsScreenState();
}

class _RadicarPqrsScreenState extends State<RadicarPqrsScreen> {
  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  String? _tipo;
  String _clase = 'general';
  int? _alumnoId;
  ElegidoParaSubir? _adjunto;
  bool _enviando = false;

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  int? get _dias {
    final tipo = widget.lista.tipos.where((t) => t.clave == _tipo).firstOrNull;
    if (tipo == null) return null;
    if (tipo.clave != 'peticion') return tipo.dias;
    return widget.lista.clases.where((c) => c.clave == _clase).firstOrNull?.dias ?? tipo.dias;
  }

  String? get _falta {
    if (_tipo == null) return 'Elige qué quieres hacer.';
    if (_asunto.text.trim().length < 3) return 'Escribe el asunto.';
    if (_descripcion.text.trim().length < 10) return 'Cuenta un poco más en la descripción.';
    return null;
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _elegirFoto() async {
    final f = await elegirFotoReducida(context, CalidadDeFoto.normal);
    if (f != null && mounted) setState(() => _adjunto = f);
  }

  Future<void> _elegirDocumento() async {
    final f = await elegirDocumento();
    if (f == null || !mounted) return;
    if (f.bytes.length > 10 * 1024 * 1024) {
      _avisar('El archivo pasa de 10 MB.');
      return;
    }
    setState(() => _adjunto = f);
  }

  Future<void> _radicar() async {
    final falta = _falta;
    if (falta != null) {
      _avisar(falta);
      return;
    }
    setState(() => _enviando = true);
    try {
      final detalle = await radicarPqrs(
        Server(),
        tipo: _tipo!,
        clase: _tipo == 'peticion' ? _clase : 'general',
        asunto: _asunto.text.trim(),
        descripcion: _descripcion.text.trim(),
        alumnoId: _alumnoId,
        adjunto: _adjunto,
      );
      if (mounted) Navigator.pop(context, detalle);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _avisar('$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hijos = widget.lista.hijos;
    return Scaffold(
      backgroundColor: EstiloPqrs.fondo,
      appBar: AppBar(title: const TituloPantalla(titulo: 'Radicar una PQRS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            EstiloPqrs.rotulo('Qué quieres hacer'),
            for (final t in widget.lista.tipos) ...[
              _opcion(
                icono: EstiloPqrs.iconoDelTipo(t.clave),
                titulo: t.texto,
                detalle: t.explicacion,
                elegida: _tipo == t.clave,
                onTap: () => setState(() => _tipo = t.clave),
              ),
              const SizedBox(height: 8),
            ],
            if (_tipo == 'peticion') ...[
              const SizedBox(height: 8),
              EstiloPqrs.rotulo('Qué pides'),
              for (final c in widget.lista.clases) ...[
                _opcion(
                  titulo: c.texto,
                  detalle: c.dias == null ? null : 'El colegio tiene ${c.dias} días hábiles para responder.',
                  elegida: _clase == c.clave,
                  onTap: () => setState(() => _clase = c.clave),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (hijos.isNotEmpty) ...[
              const SizedBox(height: 8),
              EstiloPqrs.rotulo('Sobre cuál de tus hijos (si es de uno)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipHijo(null, 'Ninguno en particular', null),
                  for (final h in hijos) _chipHijo(h.alumnoId, h.nombres, h),
                ],
              ),
            ],
            const SizedBox(height: 18),
            EstiloPqrs.rotulo('Asunto'),
            TextField(
              controller: _asunto,
              maxLength: 191,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: _campo('En una línea: de qué se trata'),
            ),
            const SizedBox(height: 6),
            EstiloPqrs.rotulo('Cuéntalo'),
            TextField(
              controller: _descripcion,
              maxLength: 5000,
              minLines: 5,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: _campo('Qué pasó o qué necesitas, con todos los detalles'),
            ),
            const SizedBox(height: 6),
            EstiloPqrs.rotulo('Adjunto (opcional)'),
            if (_adjunto == null)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _enviando ? null : _elegirFoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Foto'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _enviando ? null : _elegirDocumento,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Documento'),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                decoration: EstiloPqrs.bloque(),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18, color: EstiloPqrs.tintaSuave),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${_adjunto!.nombre} · ${pesoLegible(_adjunto!.bytes.length)}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: 'Quitar el adjunto',
                      onPressed: _enviando ? null : () => setState(() => _adjunto = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (_dias != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'El colegio tiene $_dias días hábiles para responder, contados desde mañana. '
                  'Te avisamos cuando responda.',
                  style: const TextStyle(fontSize: 13, color: EstiloPqrs.tintaSuave),
                ),
              )
            else if (_tipo == 'felicitacion')
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Una felicitación no tiene plazo legal, pero el colegio la recibe igual.',
                    style: TextStyle(fontSize: 13, color: EstiloPqrs.tintaSuave)),
              ),
            FilledButton(
              style: EstiloActividades.botonPrincipal(),
              onPressed: _enviando ? null : _radicar,
              child: _enviando
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Radicar'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _campo(String pista) => InputDecoration(
        hintText: pista,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstiloActividades.borde),
        ),
      );

  /// Una tarjeta de elegir. «Elegida» con borde y fondo propios: el color solo
  /// no basta, así que lleva también el visto.
  Widget _opcion({
    IconData? icono,
    required String titulo,
    String? detalle,
    required bool elegida,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: elegida,
      button: true,
      child: Material(
        color: elegida ? EstiloPqrs.primarioSuave : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: elegida ? EstiloPqrs.primario : EstiloActividades.borde, width: elegida ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _enviando ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (icono != null) ...[
                  Icon(icono, color: elegida ? EstiloPqrs.primario : EstiloPqrs.tintaSuave),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: EstiloPqrs.tinta)),
                      if (detalle != null) ...[
                        const SizedBox(height: 2),
                        Text(detalle,
                            style: const TextStyle(fontSize: 12.5, color: EstiloPqrs.tintaSuave)),
                      ],
                    ],
                  ),
                ),
                if (elegida) const Icon(Icons.check_circle, color: EstiloPqrs.primario),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipHijo(int? id, String texto, AlumnoPqrs? hijo) {
    final elegido = _alumnoId == id;
    return ChoiceChip(
      selected: elegido,
      onSelected: _enviando ? null : (_) => setState(() => _alumnoId = id),
      avatar: hijo == null ? null : AvatarPersona(nombre: hijo.nombre, fotoNombre: hijo.foto, radio: 12),
      label: Text(hijo?.grupo == null ? texto : '$texto · ${hijo!.grupo}'),
      selectedColor: EstiloPqrs.primarioSuave,
      side: BorderSide(color: elegido ? EstiloPqrs.primario : EstiloActividades.borde),
      showCheckmark: false,
    );
  }
}
