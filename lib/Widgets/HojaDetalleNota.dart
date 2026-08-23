import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/HistorialNotaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// La hoja que cuenta de dónde viene una nota, y desde donde se puede borrar.
///
/// Es el doble clic del front web, con dos diferencias. Allí hay que **activar
/// un modo** —un interruptor «Ver historial» arriba de la tabla— para que el
/// doble clic haga algo; aquí no hay modo que activar: se mantiene pulsada la
/// fila y sale. Un modo que hay que acordarse de encender es un modo que nadie
/// enciende.
///
/// Y borrar vive dentro de esta hoja y no suelto en la lista, a propósito:
/// borrar una nota es lo bastante raro y lo bastante destructivo como para que
/// haya que abrir algo primero. Junto al historial, además, se ve lo que se va
/// a perder antes de perderlo.
///
/// Devuelve true si la nota se borró, para que quien la abrió repinte.
Future<bool> mostrarDetalleDeNota(
  BuildContext context, {
  required int notaId,
  required String titulo,
  required String subtitulo,
}) async {
  final borrada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.8,
    ),
    builder: (_) => _HojaDetalleNota(
      notaId: notaId,
      titulo: titulo,
      subtitulo: subtitulo,
    ),
  );

  return borrada ?? false;
}

class _HojaDetalleNota extends StatefulWidget {
  const _HojaDetalleNota({
    required this.notaId,
    required this.titulo,
    required this.subtitulo,
  });

  final int notaId;
  final String titulo;
  final String subtitulo;

  @override
  State<_HojaDetalleNota> createState() => _HojaDetalleNotaState();
}

class _HojaDetalleNotaState extends State<_HojaDetalleNota> {
  final Server server = Server();

  HistorialDeNota? historial;
  bool cargando = true;
  bool borrando = false;
  String? error;

  bool get _puedeBorrar =>
      ContextoAcademico.instancia.config.puedeEditarNotas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      historial =
          await traerHistorialDeNota(server, notaId: widget.notaId);
    } catch (err) {
      error = 'No se pudo traer el historial: $err';
    }

    setState(() => cargando = false);
  }

  Future<void> _borrar() async {
    final navegador = Navigator.of(context);

    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar esta nota?'),
        // Se dice que vuelve, porque si no, borrar da miedo de más: parece que
        // el alumno se queda sin casilla y no es eso lo que pasa.
        content: const Text(
          'La casilla no desaparece: al recargar el libro se vuelve a crear con'
          ' la nota por defecto de la subunidad. Es la forma de deshacer una'
          ' nota que no debía estar ahí.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (seguro != true) return;

    setState(() => borrando = true);
    final fallo = await borrarNota(server, notaId: widget.notaId);
    setState(() => borrando = false);

    if (fallo != null) {
      setState(() => error = fallo);
      return;
    }

    navegador.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.subtitulo,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Flexible(child: _buildCuerpo()),
          if (_puedeBorrar) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: borrando ? null : _borrar,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(borrando ? 'Borrando…' : 'Borrar la nota'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[700],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final actual = historial;
    if (actual == null) return const SizedBox.shrink();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (actual.creadaPor.isNotEmpty)
          _buildLinea('La creó', actual.creadaPor),
        if (actual.modificadaPor.isNotEmpty)
          _buildLinea('La tocó por última vez', actual.modificadaPor),
        const SizedBox(height: 12),
        if (actual.vacio)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Esta nota no se ha cambiado desde que se creó.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ...actual.cambios.map(_buildCambio),
      ],
    );
  }

  Widget _buildLinea(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildCambio(CambioDeNota cambio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cambio.quien.isEmpty ? 'Alguien' : cambio.quien,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatoDiaYHora(cambio.cuando),
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
          Text(
            '${cambio.anterior ?? '—'} → ${cambio.nueva ?? '—'}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
