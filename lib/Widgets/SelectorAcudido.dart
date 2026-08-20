import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';

/// Pregunta a un acudiente de cuál de sus acudidos quiere ver algo.
///
/// Devuelve el elegido, o null si cerró el cuadro. Con un solo acudido no
/// pregunta nada: lo devuelve directamente, que es lo que pidió Joseth —a un
/// padre con un solo hijo, elegirlo cada vez le sobra—.
Future<AcudidoModel?> pedirAcudido(
  BuildContext context,
  List<AcudidoModel> acudidos, {
  String titulo = '¿De quién?',
}) async {
  if (acudidos.isEmpty) return null;
  if (acudidos.length == 1) return acudidos.first;

  return showModalBottomSheet<AcudidoModel>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ListaAcudidos(acudidos: acudidos, titulo: titulo),
  );
}

class _ListaAcudidos extends StatelessWidget {
  const _ListaAcudidos({required this.acudidos, required this.titulo});

  final List<AcudidoModel> acudidos;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: acudidos.length,
              itemBuilder: (context, i) => _fila(context, acudidos[i]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _fila(BuildContext context, AcudidoModel acudido) {
    return ListTile(
      leading: AvatarPersona(
        nombre: acudido.nombreCompleto,
        fotoNombre: acudido.fotoNombre,
        radio: 24,
      ),
      title: Text(acudido.nombreCompleto),
      subtitle: Text(acudido.grupo ?? 'Sin grupo'),
      // La deuda no se enseña aquí: esto es para elegir, no para cobrar. El
      // aviso de tesorería sale dentro, cuando ya se sabe de quién se habla.
      trailing: acudido.pazYSalvo
          ? const Icon(Icons.chevron_right)
          : const Icon(Icons.lock_outline, color: Colors.redAccent),
      onTap: () => Navigator.pop(context, acudido),
    );
  }
}
