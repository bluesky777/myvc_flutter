import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';
import 'package:myvc_flutter/constantes.dart';

/// Lo que se eligió en la hoja de frases: una del catálogo o uno escrito a mano.
class FraseElegida {
  const FraseElegida.delCatalogo(this.fraseId) : texto = null;
  const FraseElegida.escrita(String this.texto) : fraseId = null;

  final int? fraseId;
  final String? texto;

  bool get esDelCatalogo => fraseId != null;
}

/// La hoja para ponerle una frase a un alumno.
///
/// El catálogo del colegio pasa de cuatrocientas frases, así que se busca
/// escribiendo y no se recorre —el mismo trato que el manual de convivencia en
/// [pedirOrdinales]—. Y debajo, la posibilidad de escribir una a mano: el
/// backend acepta las dos y el docente casi siempre quiere una del catálogo,
/// pero de vez en cuando el caso concreto no está.
///
/// Se elige **una cada vez** y no varias. Poner frases no es marcar una lista:
/// se piensa cuál va, se pone, y se mira cómo queda. Y cada una es su propia
/// petición de todos modos, porque el backend no acepta lotes.
Future<FraseElegida?> pedirFrase(
  BuildContext context,
  List<FraseDelCatalogo> catalogo, {
  bool cargando = false,
}) {
  return showModalBottomSheet<FraseElegida>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => _HojaFrases(catalogo: catalogo, cargando: cargando),
  );
}

class _HojaFrases extends StatefulWidget {
  const _HojaFrases({required this.catalogo, this.cargando = false});

  final List<FraseDelCatalogo> catalogo;
  final bool cargando;

  @override
  State<_HojaFrases> createState() => _HojaFrasesState();
}

class _HojaFrasesState extends State<_HojaFrases> {
  final _escrita = TextEditingController();
  String busqueda = '';

  @override
  void dispose() {
    _escrita.dispose();
    super.dispose();
  }

  List<FraseDelCatalogo> get _filtradas =>
      widget.catalogo.where((f) => f.coincideCon(busqueda)).toList();

  @override
  Widget build(BuildContext context) {
    final frases = _filtradas;

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Información para el alumno',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar en las frases del colegio',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (texto) => setState(() => busqueda = texto),
              ),
            ),
            const Divider(height: 1),
            Flexible(child: _buildLista(frases)),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _escrita,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'O escribe una',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _escrita.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(
                              context,
                              FraseElegida.escrita(_escrita.text.trim()),
                            ),
                    child: const Text('Poner'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(List<FraseDelCatalogo> frases) {
    if (widget.cargando) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (frases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          widget.catalogo.isEmpty
              ? 'Este año no tiene frases cargadas. Se escriben desde la'
                  ' plataforma web; aquí abajo puedes poner una a mano.'
              : 'Ninguna frase dice eso.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: frases.length,
      itemBuilder: (context, i) {
        final frase = frases[i];

        return ListTile(
          dense: true,
          onTap: () =>
              Navigator.pop(context, FraseElegida.delCatalogo(frase.id)),
          title: Text(frase.frase, style: const TextStyle(fontSize: 13)),
          subtitle: frase.tipo.isEmpty
              ? null
              : Text(
                  frase.tipo,
                  style: TextStyle(fontSize: 11, color: kPrimaryColor),
                ),
        );
      },
    );
  }
}
