import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';

/// Los juegos 3D de la web, abiertos dentro de la app.
///
/// La lista es copia de myvc_front `app2/src/app/paginas/juegos/juegos.ts`
/// (`JUEGOS_3D`); cuando allí entre un juego, se añade aquí. Cada juego es una
/// página estática del colegio, `<colegio>/up2/juegos3d/<id>/index.html`, y el
/// contrato con ella está en myvc_front `docs/juegos-3d/CONTRATO.md`.
class Juego3D {
  const Juego3D({
    required this.id,
    required this.emoji,
    required this.titulo,
    required this.materia,
    required this.texto,
    required this.color,
    this.url,
  });

  final String id;
  final String emoji;
  final String titulo;
  final String materia;
  final String texto;
  final Color color;

  /// Un juego que no vive en el colegio y se abre con su dirección tal cual.
  /// Es Destello: no lleva `puente.js`, ni `?u`, ni `?colegio`.
  final String? url;
}

const List<Juego3D> juegos3D = [
  Juego3D(
    id: 'carrera',
    emoji: '🏁',
    titulo: 'Turbo Saber',
    materia: 'Lectura y tablas · 2.º a 7.º',
    color: Color(0xFFEE7D12),
    texto: 'Cada respuesta buena acelera tu corredor. Compite por el podio.',
  ),
  Juego3D(
    id: 'laboratorio',
    emoji: '🧪',
    titulo: 'Eureka',
    materia: 'Ciencias naturales · 4.º a 9.º',
    color: Color(0xFF0E9AA0),
    texto: 'Arma un circuito hasta que el bombillo prenda, recorre el sistema '
        'solar y predice qué pasa al mezclar.',
  ),
  Juego3D(
    id: 'celula',
    emoji: '🦠',
    titulo: 'Microviaje',
    materia: 'Ciencias naturales · 6.º a 9.º',
    color: Color(0xFFC2417A),
    texto: 'Pilota un nanorobot dentro de una célula: encuentra cada organelo, '
        'fabrica una proteína y descubre la célula vegetal.',
  ),
  Juego3D(
    id: 'colombia',
    emoji: '✈️',
    titulo: 'Vuelo Cóndor',
    materia: 'Ciencias sociales · 3.º a 9.º',
    color: Color(0xFF2F9E5D),
    texto: 'Pilota un avioncito sobre el relieve: las seis regiones, las '
        'cordilleras, los ríos y las capitales.',
  ),
  Juego3D(
    id: 'geometria',
    emoji: '🍕',
    titulo: 'Pizzamática',
    materia: 'Matemáticas · 3.º a 8.º',
    color: Color(0xFF3B63D9),
    texto: 'Corta pizzas en partes, desdobla un cubo en su red plana y llena '
        'cajas de cubitos para descubrir el volumen.',
  ),
  Juego3D(
    id: 'escape',
    emoji: '🔐',
    titulo: 'Escape Room',
    materia: 'Cualquier materia · 4.º a 11.º',
    color: Color(0xFF7B4FD0),
    texto: 'Abre candados y cofres resolviendo retos de matemáticas o de '
        'sociales.',
  ),
  Juego3D(
    id: 'cajas',
    emoji: '📦',
    titulo: 'Cajas de Palabras',
    materia: 'Inglés · 1.º a 5.º',
    color: Color(0xFFE8590C),
    texto: 'Salta por seis mundos, abre cajas y busca por el mapa la palabra '
        'en inglés que corresponde.',
  ),
  // En pruebas: pesa decenas de MB, el audio todavía falla y el modo en grupo
  // pide micrófono. En la app basta el modo de un jugador; para jugar en grupo,
  // su propia página en el navegador.
  Juego3D(
    id: 'destello',
    emoji: '✨',
    titulo: 'Destello',
    materia: 'En pruebas · un jugador',
    color: Color(0xFF5B3FD6),
    texto: 'Aventura en primera persona: responde bien y gana poder. Todavía '
        'en construcción, y por ahora sin sonido.',
    url: 'https://destello.pages.dev/',
  ),
];

/// La dirección del juego dentro del colegio, relativa a `up2/juegos3d/`.
///
/// `u` es el user_id (con él `puente.js` guarda el progreso por usuario y sabe
/// que va dentro de la app), `colegio` el color en `#rrggbb` y `docente=1` sólo
/// para el personal, que puede saltarse niveles.
String direccionDelJuego(
  Juego3D juego, {
  required int userId,
  required Color color,
  required bool docente,
}) {
  final q = <String, String>{
    'u': '$userId',
    'colegio': colorEnHex(color),
    if (docente) 'docente': '1',
  };
  return '${juego.id}/index.html?${Uri(queryParameters: q).query}';
}

String colorEnHex(Color color) {
  String dos(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${dos(color.r)}${dos(color.g)}${dos(color.b)}';
}

/// Las únicas rutas que un juego puede pedir con la sesión de la app: las de
/// `juegos/…`, sin `..`. La misma regla que la web (`paginas/juego/juego.ts`).
final RegExp _rutaDeJuegos =
    RegExp(r'^juegos/[A-Za-z0-9_\-/]*(\?[A-Za-z0-9_=&-]*)?$');

bool rutaDeJuegoPermitida(String ruta) =>
    _rutaDeJuegos.hasMatch(ruta) && !ruta.contains('..');

/// Lo que se le contesta al juego por un `juegos3d:api`.
typedef RespuestaAlJuego = ({bool ok, Object? datos, int estado, String error});

/// Hace la petición que pidió el juego, con el token de la app.
///
/// El token nunca entra a la página del juego: la página pide, la app llama.
/// Las fotos (`foto`, `*_foto`) salen ya como URL entera.
Future<RespuestaAlJuego> llamarPorElJuego(
  Server server, {
  required String metodo,
  required String ruta,
  Object? cuerpo,
}) async {
  final m = metodo.toUpperCase();
  if (!const ['GET', 'POST', 'PUT', 'DELETE'].contains(m) ||
      !rutaDeJuegoPermitida(ruta)) {
    return (ok: false, datos: null, estado: 400, error: 'Ruta no permitida');
  }

  final dynamic res;
  try {
    final direccion = '/$ruta';
    res = switch (m) {
      'GET' => await server.get(direccion),
      'POST' => await server.post(direccion, cuerpo ?? {}),
      'PUT' => await server.put(direccion, cuerpo ?? {}),
      _ => await server.delete(direccion),
    };
  } catch (_) {
    return (ok: false, datos: null, estado: 0, error: 'Sin conexión');
  }

  final codigo = res.statusCode as int;
  final texto = res.body as String;

  if (codigo >= 300) {
    return (
      ok: false,
      datos: null,
      estado: codigo,
      error: loQueDijoElServidor(texto) ?? 'No se pudo',
    );
  }

  Object? datos;
  try {
    datos = jsonDecode(texto);
  } catch (_) {
    datos = texto;
  }

  return (ok: true, datos: conFotos(datos), estado: codigo, error: '');
}

/// `foto`, `docente_foto`… llegan como nombre de fichero; el juego recibe la
/// URL entera, o null.
Object? conFotos(Object? dato) {
  if (dato is List) return dato.map(conFotos).toList();
  if (dato is! Map) return dato;

  return {
    for (final e in dato.entries)
      e.key: (e.key == 'foto' || '${e.key}'.endsWith('_foto')) &&
              (e.value == null || e.value is String)
          ? _urlDeFoto(e.value as String?)
          : e.value,
  };
}

String? _urlDeFoto(String? nombre) {
  // Las de por defecto no son una foto de nadie (`esFotoDeVerdad` de la web).
  if (nombre == null ||
      nombre.trim().isEmpty ||
      nombre == 'N/A' ||
      nombre.startsWith('default_')) {
    return null;
  }
  if (RegExp(r'^https?://').hasMatch(nombre)) return nombre;
  return Server.urlFoto(nombre);
}
