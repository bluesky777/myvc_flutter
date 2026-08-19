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
        child: url.isEmpty
            ? _iniciales()
            : Image.network(
                url,
                width: lado,
                height: lado,
                fit: BoxFit.cover,
                // Mientras se desarrolla en web, la app va por un puerto y las
                // fotos por otro: el navegador bloquea el fetch por CORS y la
                // foto no sale. Con fallback se reintenta con una etiqueta
                // <img>, que no sufre esa restricción. En el móvil y en el web
                // ya desplegado no cambia nada, porque ahí no hay dos orígenes.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, __, ___) => _iniciales(),
                loadingBuilder: (context, hijo, progreso) =>
                    progreso == null ? hijo : _iniciales(),
              ),
      ),
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
