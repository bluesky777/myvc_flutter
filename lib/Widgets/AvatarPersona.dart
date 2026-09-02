import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/constantes.dart';

/// La foto de un alumno o de un docente, redonda.
///
/// Nunca deja un hueco ni revienta la pantalla: si no hay foto, si el nombre
/// del archivo no existe en el servidor o si la red falla, en su lugar quedan
/// las iniciales de la persona.
class AvatarPersona extends StatelessWidget {
  /// Lo que trae el backend en foto_nombre. Puede venir nulo.
  final String? fotoNombre;

  /// Para las iniciales cuando no hay foto que mostrar.
  final String nombre;

  final double radio;

  const AvatarPersona({
    super.key,
    required this.nombre,
    this.fotoNombre,
    this.radio = 20,
  });

  @override
  Widget build(BuildContext context) {
    final url = Server.urlFoto(fotoNombre);
    final lado = radio * 2;

    return SizedBox(
      width: lado,
      height: lado,
      child: ClipOval(
        child: url.isEmpty ? _iniciales() : _foto(url, lado),
      ),
    );
  }

  /// La foto, cacheada en disco fuera de la web.
  ///
  /// **En móvil no se usa `Image.network` y el motivo es el servidor.** Las
  /// fotos no las sirve Laravel: las saca LiteSpeed del disco y las manda con
  /// `cache-control: max-age=604800, public` —comprobado con `curl -I` contra
  /// demo.micolevirtual.com—. Esa cabecera dice «guárdala una semana», y
  /// `Image.network` **no la escucha**: su caché es la de memoria del motor,
  /// que se vacía al cerrar la app. O sea que cada arranque en frío volvía a
  /// bajar la foto de cada alumno de una planilla de treinta, con la cabecera
  /// puesta y nadie escuchándola. [CachedNetworkImage] sí guarda en disco, y
  /// entonces la cabecera empieza a servir para algo.
  ///
  /// **En web se queda `Image.network`**, y no por descuido:
  ///
  /// - El navegador **ya** cachea por esa misma cabecera, así que ahí no hay
  ///   nada que ganar.
  /// - Y hay algo que perder: `webHtmlElementStrategy` no existe en
  ///   `CachedNetworkImage`. Sirve para que, cuando la app se sirve desde un
  ///   dominio distinto al del colegio, la foto se reintente con una etiqueta
  ///   `<img>` —que no está sujeta a CORS— en vez de quedarse en las
  ///   iniciales. Cambiarlo en web sería arreglar una caché que ya funciona
  ///   rompiendo las fotos de un despliegue que sí se usa.
  Widget _foto(String url, double lado) {
    if (kIsWeb) {
      return Image.network(
        url,
        width: lado,
        height: lado,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => _iniciales(),
        loadingBuilder: (context, hijo, progreso) =>
            progreso == null ? hijo : _iniciales(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: lado,
      height: lado,
      fit: BoxFit.cover,
      // Lo mismo que hacían `errorBuilder` y `loadingBuilder`: nunca un hueco
      // ni una rueda girando dentro de un círculo de 40 px, siempre las
      // iniciales. Es lo que promete el docblock de la clase.
      placeholder: (_, __) => _iniciales(),
      errorWidget: (_, __, ___) => _iniciales(),
    );
  }

  Widget _iniciales() {
    final letras = _dosLetras(nombre);

    return Container(
      color: kPrimaryColor,
      alignment: Alignment.center,
      child: letras.isEmpty
          ? Icon(Icons.person, color: Colors.white, size: radio)
          : Text(
              letras,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: radio * 0.7,
              ),
            ),
    );
  }

  /// Las iniciales: la primera letra de las dos primeras palabras del nombre.
  static String _dosLetras(String nombre) {
    final palabras =
        nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    return palabras
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
  }
}
