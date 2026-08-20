import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Un comentario debajo de una publicación.
class ComentarioModel {
  final int id;
  final String autor;
  final String? fotoAutor;
  final String comentario;
  final DateTime? cuando;

  ComentarioModel({
    required this.id,
    required this.autor,
    required this.comentario,
    this.fotoAutor,
    this.cuando,
  });

  factory ComentarioModel.fromJson(Map<String, dynamic> json) {
    return ComentarioModel(
      id: enteroO(json['id']),
      autor: '${json['nombre_autor'] ?? ''}',
      fotoAutor: texto(json['foto_autor']),
      comentario: '${json['comentario'] ?? ''}',
      cuando: DateTime.tryParse('${json['created_at']}'),
    );
  }
}

/// Una publicación del muro del colegio.
///
/// Se pinta de tres formas, que es como las escribe la plataforma web: solo
/// texto, solo imagen, o la imagen con su texto debajo. De ahí que [contenido]
/// y [imagenNombre] sean los dos opcionales; lo que no puede ser es que falten
/// los dos, y esas se descartan al leerlas.
class PublicacionModel {
  final int id;

  /// El cuerpo. Viene con etiquetas HTML —el editor del front las permite—, y
  /// aquí se guarda ya en texto plano: ver [_sinEtiquetas].
  final String? contenido;

  final String? imagenNombre;
  final String autor;
  final String? fotoAutor;
  final DateTime? cuando;
  final List<ComentarioModel> comentarios;

  /// Quién la escribió, para saber si el que mira es su dueño.
  final int? personaId;

  PublicacionModel({
    required this.id,
    required this.autor,
    this.contenido,
    this.imagenNombre,
    this.fotoAutor,
    this.cuando,
    this.personaId,
    this.comentarios = const [],
  });

  bool get tieneTexto => contenido != null && contenido!.trim().isNotEmpty;

  bool get tieneImagen => imagenNombre != null && imagenNombre!.trim().isNotEmpty;

  /// Si hay algo que enseñar. Una publicación sin texto ni imagen no se pinta.
  bool get tieneAlgo => tieneTexto || tieneImagen;

  /// El pie de comentarios. Se enseña siempre, también en cero: saber que
  /// nadie ha comentado es un dato, y un pie que aparece y desaparece hace que
  /// las tarjetas bailen al recorrer la lista.
  String get resumenComentarios {
    if (comentarios.isEmpty) return 'Sin comentarios';
    if (comentarios.length == 1) return '1 comentario';
    return '${comentarios.length} comentarios';
  }

  /// Si el texto es corto y va solo, se pinta en grande y centrado.
  ///
  /// Son los avisos: «Mañana no hay clase». En la plataforma web se publican
  /// así, sobre un fondo de color, para que no se pasen por alto al bajar. Un
  /// texto largo con ese tratamiento sería un muro de letras.
  bool get esAviso => tieneTexto && !tieneImagen && contenido!.length <= 140;

  factory PublicacionModel.fromJson(Map<String, dynamic> json) {
    final crudos = json['comentarios'];

    return PublicacionModel(
      id: enteroO(json['id']),
      contenido: _sinEtiquetas(texto(json['contenido'])),
      imagenNombre: texto(json['imagen_nombre']),
      autor: '${json['nombre_autor'] ?? ''}',
      fotoAutor: texto(json['foto_autor']),
      // Llega como '2026-08-19 19:10:58', sin zona: se lee tal cual.
      cuando: DateTime.tryParse('${json['created_at']}'),
      personaId: entero(json['persona_id']),
      comentarios: crudos is List
          ? crudos
              .whereType<Map>()
              .map((c) => ComentarioModel.fromJson(
                  Map<String, dynamic>.from(c)))
              .toList()
          : const [],
    );
  }

  /// El texto sin las etiquetas HTML con que lo guarda la plataforma web.
  ///
  /// El editor del front deja escribir HTML y allí se pinta como tal. Aquí no
  /// se interpreta: enseñar `<p>Hola</p>` sería peor que enseñar «Hola», y
  /// pintar HTML de verdad pide una dependencia nueva y decidir qué etiquetas
  /// se permiten. Los saltos de línea sí se respetan, que es lo que da forma a
  /// una publicación larga.
  static String? _sinEtiquetas(String? crudo) {
    if (crudo == null) return null;

    final conSaltos = crudo
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');

    final limpio = conSaltos
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return limpio.isEmpty ? null : limpio;
  }
}
