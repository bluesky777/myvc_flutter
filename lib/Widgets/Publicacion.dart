import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PublicacionModel.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';

/// Una publicación del muro, como la pinta la plataforma web.
///
/// Tres formas, según lo que traiga: solo texto, solo imagen, o la imagen con
/// su texto. No hay una cuarta: las que no traen ninguna de las dos se
/// descartan antes de llegar aquí.
class Publicacion extends StatelessWidget {
  const Publicacion({super.key, required this.publicacion});

  final PublicacionModel publicacion;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(),
          if (publicacion.tieneImagen) _imagen(),
          if (publicacion.tieneTexto) _texto(),
          if (publicacion.comentarios.isNotEmpty) _comentarios(context),
        ],
      ),
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          AvatarPersona(
            nombre: publicacion.autor,
            fotoNombre: publicacion.fotoAutor,
            radio: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  publicacion.autor.isEmpty ? 'Sin autor' : publicacion.autor,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (publicacion.cuando != null)
                  Text(
                    publicacion.cuando!,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagen() {
    final url = Server.urlFoto(publicacion.imagenNombre);

    // Sin altura fija: una publicación puede ser un cartel vertical o una foto
    // apaisada, y recortarla a una franja se come justo lo que se quiso decir.
    return Image.network(
      url,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _imagenRota(),
      loadingBuilder: (context, hijo, progreso) =>
          progreso == null ? hijo : _cargandoImagen(),
    );
  }

  Widget _cargandoImagen() => Container(
        height: 160,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _imagenRota() => Container(
        height: 120,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.black45),
            SizedBox(width: 8),
            Text('No se pudo cargar la imagen',
                style: TextStyle(color: Colors.black45)),
          ],
        ),
      );

  Widget _texto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Text(
        publicacion.contenido!,
        style: const TextStyle(fontSize: 15, height: 1.35),
      ),
    );
  }

  Widget _comentarios(BuildContext context) {
    final primero = publicacion.comentarios.first;
    final restantes = publicacion.comentarios.length - 1;

    return Container(
      color: Colors.black.withValues(alpha: 0.03),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarPersona(
                nombre: primero.autor,
                fotoNombre: primero.fotoAutor,
                radio: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primero.autor,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(primero.comentario,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (restantes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                restantes == 1
                    ? 'Y un comentario más.'
                    : 'Y $restantes comentarios más.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
