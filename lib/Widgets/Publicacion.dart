import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PublicacionModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/constantes.dart';

/// Una publicación del muro.
///
/// Tres formas, que son las que publica la plataforma web: solo texto, solo
/// imagen, o la imagen con su texto. Las que no traen ninguna de las dos se
/// descartan antes de llegar aquí.
///
/// El aspecto no copia al del front web —allí la imagen va sobre una copia
/// borrosa de sí misma y los avisos sobre un degradado de colores—: aquí se
/// busca que la lista se recorra sin ruido, y para eso el color lo pone el
/// contenido y no el marco.
class Publicacion extends StatelessWidget {
  const Publicacion({super.key, required this.publicacion});

  final PublicacionModel publicacion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(),
          if (publicacion.tieneImagen) _imagen(),
          if (publicacion.tieneTexto)
            publicacion.esAviso ? _aviso() : _texto(),
          _pie(),
        ],
      ),
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          AvatarPersona(
            nombre: publicacion.autor,
            fotoNombre: publicacion.fotoAutor,
            radio: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  publicacion.autor.isEmpty ? 'Sin autor' : publicacion.autor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  hace(publicacion.cuando),
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La imagen, entera y sin recortar.
  ///
  /// Sin altura fija a propósito: una publicación puede ser un cartel vertical
  /// o una foto apaisada, y encajarla en una franja se come justo lo que se
  /// quiso enseñar.
  Widget _imagen() {
    return Image.network(
      Server.urlFoto(publicacion.imagenNombre),
      fit: BoxFit.fitWidth,
      width: double.infinity,
      // Lo mismo que hace AvatarPersona, y por lo mismo. Las fotos no las
      // sirve Laravel: las saca el servidor web del disco, y ahí no pasan por
      // el middleware que pone `Access-Control-Allow-Origin`. O sea que en
      // cuanto la app se sirve desde un dominio distinto al del colegio
      // —app.micolevirtual.com pidiendo a lalvirtual.edu.co— el navegador
      // bloquea el fetch de bytes aunque el servidor responda 200, y el muro
      // enseñaba «No se pudo cargar la imagen» en todas las publicaciones.
      // Con fallback se reintenta con una etiqueta <img>, que no está sujeta a
      // esa regla. Se pierde poder aplicarle filtros, que aquí no se usan.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, __, ___) => _marcoGris(
        alto: 110,
        hijo: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 20, color: Colors.black38),
            SizedBox(width: 8),
            Text('No se pudo cargar la imagen',
                style: TextStyle(color: Colors.black38, fontSize: 13)),
          ],
        ),
      ),
      loadingBuilder: (context, hijo, progreso) => progreso == null
          ? hijo
          : _marcoGris(
              alto: 180,
              hijo: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }

  Widget _marcoGris({required double alto, required Widget hijo}) => Container(
        height: alto,
        color: Colors.black.withValues(alpha: 0.04),
        alignment: Alignment.center,
        child: hijo,
      );

  /// Un aviso corto: grande, centrado y con aire.
  ///
  /// Es el «Mañana no hay clase» que no puede pasarse por alto al bajar. El
  /// color es el de la app en un tono muy suave: suficiente para que la tarjeta
  /// se distinga de las demás sin que la lista parezca una feria.
  Widget _aviso() {
    return Container(
      width: double.infinity,
      color: kPrimaryColor.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Text(
        publicacion.contenido!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 19,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: kPrimaryColor,
        ),
      ),
    );
  }

  Widget _texto() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        publicacion.tieneImagen ? 12 : 0,
        14,
        14,
      ),
      child: Text(
        publicacion.contenido!,
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
    );
  }

  /// El pie: cuántos comentarios hay, también cuando no hay ninguno.
  ///
  /// Escribirlos todavía no está; leer el primero, sí, que es lo que da idea de
  /// si la publicación tuvo respuesta.
  Widget _pie() {
    final primero =
        publicacion.comentarios.isEmpty ? null : publicacion.comentarios.first;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                publicacion.comentarios.isEmpty
                    ? Icons.mode_comment_outlined
                    : Icons.mode_comment,
                size: 15,
                color: Colors.black38,
              ),
              const SizedBox(width: 6),
              Text(
                publicacion.resumenComentarios,
                style: const TextStyle(fontSize: 12.5, color: Colors.black45),
              ),
            ],
          ),
          if (primero != null) ...[
            const SizedBox(height: 10),
            _comentario(primero),
          ],
        ],
      ),
    );
  }

  Widget _comentario(ComentarioModel comentario) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarPersona(
          nombre: comentario.autor,
          fotoNombre: comentario.fotoAutor,
          radio: 13,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comentario.autor,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(comentario.comentario,
                  style: const TextStyle(fontSize: 13, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
