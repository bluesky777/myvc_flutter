import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// Cómo se ven las PQRS en el teléfono. Los tonos son los de las estaciones y
/// las piezas las de actividades —fondo gris, cajas blancas de borde fino,
/// píldoras—, que es lo último que se hizo para la familia.
///
/// **El color nunca va solo**: el semáforo del plazo lleva su frase («Vence en
/// 2 días hábiles»), y el estado su palabra.
class EstiloPqrs {
  EstiloPqrs._();

  static const Color fondo = EstiloActividades.fondo;
  static const Color tinta = EstiloActividades.tinta;
  static const Color tintaSuave = EstiloActividades.tintaSuave;
  static const Color tintaApagada = EstiloActividades.tintaApagada;
  static const Color primario = PaletaEstaciones.primario;
  static const Color primarioSuave = PaletaEstaciones.primarioSuave;

  /// Fondo y tinta del semáforo según el tono que manda el servidor.
  static (Color, Color) delTono(String tono) => switch (tono) {
        'ok' => (PaletaEstaciones.verdeFondo, PaletaEstaciones.verdeTinta),
        'aviso' => (PaletaEstaciones.ambarFondo, PaletaEstaciones.ambar),
        'mal' => (PaletaEstaciones.rojoFondo, PaletaEstaciones.rojoTinta),
        _ => (EstiloActividades.normalFondo, EstiloActividades.normalTinta),
      };

  static Widget plazo(String texto, String tono) {
    final (f, t) = delTono(tono);
    return EstiloActividades.pildora(texto, f, t);
  }

  static Widget estado(String estado, String texto) => switch (estado) {
        'respondida' => EstiloActividades.pildora(
            texto, EstiloActividades.hechaFondo, EstiloActividades.hechaTinta),
        'radicada' => EstiloActividades.pildora(texto, primarioSuave, PaletaEstaciones.primarioOscuro),
        _ => EstiloActividades.pildora(
            texto, EstiloActividades.normalFondo, EstiloActividades.normalTinta),
      };

  static IconData iconoDelTipo(String tipo) => switch (tipo) {
        'peticion' => Icons.help_outline,
        'queja' => Icons.report_gmailerrorred_outlined,
        'reclamo' => Icons.gavel_outlined,
        'sugerencia' => Icons.lightbulb_outline,
        'felicitacion' => Icons.favorite_border,
        _ => Icons.mail_outline,
      };

  static BoxDecoration bloque({Color? borde}) => EstiloActividades.bloque(borde: borde);

  /// Un rótulo de sección en versalitas, como en actividades.
  static Widget rotulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: EstiloActividades.tintaApagada)),
      );
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre'
];
const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// «lunes 3 de noviembre»: el día que vence, dicho como se dice.
String diaDePqrs(DateTime d) => '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';
