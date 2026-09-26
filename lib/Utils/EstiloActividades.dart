import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// Cómo se ven las actividades en el teléfono.
///
/// **Los tonos salen de las maquetas aprobadas** (`FlutterLista`,
/// `FlutterResponder`, `FlutterTarea`, `MisRespuestas`): la chapa de cada modo
/// —TA, CU, EN— y las tres píldoras de estado. El color de acción no es el del
/// colegio que pintan las maquetas sino el morado de la casa, por lo mismo que
/// en EstiloVotaciones: es una sola app para los dieciséis.
///
/// Y como en las estaciones, **el color nunca va solo**: cada modo lleva su
/// sigla y cada estado su palabra.
class EstiloActividades {
  EstiloActividades._();

  static const Color primario = PaletaEstaciones.primario;
  static const Color primarioOscuro = PaletaEstaciones.primarioOscuro;
  static const Color primarioSuave = PaletaEstaciones.primarioSuave;

  /// El gris del muro, de donde se llega.
  static const Color fondo = Color(0xFFF4F5F7);
  static const Color tinta = Color(0xFF16202E);
  static const Color tintaSuave = Color(0xFF4E5B6E);
  static const Color tintaApagada = Color(0xFF65728A);
  static const Color borde = Color(0x1F172640);

  static const double radio = 18;
  static const double alturaDeBoton = 52;

  /// Sigla, fondo y tinta de la chapa de cada modo.
  static (String, Color, Color) chapa(String modo) => switch (modo) {
        'tarea' => ('TA', const Color(0xFFE2F4F1), const Color(0xFF0B5E53)),
        'cuestionario' => (
            'CU',
            const Color(0xFFF1EAFA),
            const Color(0xFF5B3494)
          ),
        _ => ('EN', const Color(0xFFFFF1D6), const Color(0xFF7A4F00)),
      };

  static String nombreDelModo(String modo) => switch (modo) {
        'tarea' => 'Tarea',
        'cuestionario' => 'Cuestionario',
        _ => 'Encuesta',
      };

  static const urgenteFondo = Color(0xFFFFF1EE);
  static const urgenteTinta = Color(0xFFA8300D);
  static const normalFondo = Color(0xFFEEF0F4);
  static const normalTinta = Color(0xFF3B4859);
  static const hechaFondo = Color(0xFFEEFBE3);
  static const hechaTinta = Color(0xFF2B6B0B);
  static const ramaFondo = Color(0xFFFFF1D6);
  static const ramaTinta = Color(0xFF8A4A00);

  /// Una píldora: palabra sobre su fondo.
  ///
  /// `Center(widthFactor: 1)` y no `alignment:` en el `Container`: con
  /// `alignment`, dentro de un `Wrap` la píldora se estira a todo el ancho.
  static Widget pildora(String texto, Color fondo, Color tinta) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            texto,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: tinta),
          ),
        ),
      );

  /// La chapa cuadrada con la sigla del modo.
  static Widget chapaDelModo(String modo, {double lado = 42}) {
    final (sigla, fondo, tinta) = chapa(modo);
    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(lado * 0.31),
      ),
      child: Text(sigla,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: tinta)),
    );
  }

  /// Un botón ancho de acción, el de «Siguiente», «Entregar», «Enviar».
  static ButtonStyle botonPrincipal({Color color = primario}) =>
      FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(alturaDeBoton),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  /// Una caja blanca, sin sombra fuerte: borde fino.
  static BoxDecoration bloque({Color? borde}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde ?? const Color(0x0F172640)),
      );
}

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic'
];

/// «vie 2 oct, 11:59 p. m.», como en las maquetas.
String fechaDeActividad(DateTime d, {bool conHora = true}) {
  final dia = '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';
  return conHora ? '$dia, ${formatoHora12(d)}' : dia;
}

/// «hoy a las 7:12 p. m.», «ayer a las …» o la fecha entera.
String momentoDeActividad(DateTime d, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  if (esElMismoDia(d, hoy)) return 'hoy a las ${formatoHora12(d)}';
  if (esElMismoDia(d, hoy.subtract(const Duration(days: 1)))) {
    return 'ayer a las ${formatoHora12(d)}';
  }
  return 'el ${fechaDeActividad(d)}';
}

/// «1,2 MB», «220 KB».
String pesoLegible(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}

/// Una cifra con coma decimal y sin ceros de más: 3,3 · 10.
String cifraAct(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toStringAsFixed(1).replaceAll('.', ',');
}
