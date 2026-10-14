import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';

/// Cómo se ve «Mi cuenta» en el teléfono.
///
/// **Es la única pantalla que no va en el morado de la casa, y es a propósito.**
/// Joseth lo pidió así el 8 oct 2026: la cuenta con la tesorería va en azul,
/// el de la maqueta «Lo que ve la familia» del prototipo de cartera
/// (`--acento: #1677ff`), que es también el de la web de cartera. Sigue sin ser
/// el color de un colegio: es el mismo azul para los dieciséis.
///
/// Lo demás —el gris de fondo, la tinta, las cajas— es el de las actividades,
/// para que no parezca otra app. Y como allí, **el color nunca va solo**: lo
/// vencido dice «venció», no sólo se pone rojo.
class EstiloCartera {
  EstiloCartera._();

  static const Color azul = Color(0xFF1677FF);

  /// Para texto azul sobre fondo claro: el [azul] se queda corto de contraste
  /// en letra pequeña.
  static const Color azulOscuro = Color(0xFF0958D9);
  static const Color azulSuave = Color(0x1A1677FF);

  static const Color fondo = EstiloActividades.fondo;
  static const Color tinta = EstiloActividades.tinta;
  static const Color tintaSuave = EstiloActividades.tintaSuave;
  static const Color tintaApagada = EstiloActividades.tintaApagada;
  static const Color borde = EstiloActividades.borde;

  static const Color bienFondo = Color(0x2452C41A);
  static const Color bienTinta = Color(0xFF2B6B0B);
  static const Color avisoFondo = Color(0x2EFAAD14);
  static const Color avisoTinta = Color(0xFF8A5300);
  static const Color malFondo = Color(0x21FF4D4F);
  static const Color malTinta = Color(0xFFCF1322);

  static const double radio = EstiloActividades.radio;

  static BoxDecoration bloque() => EstiloActividades.bloque();

  static Widget pildora(String texto, Color fondo, Color tinta) =>
      EstiloActividades.pildora(texto, fondo, tinta);
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

/// `$ 1.234.567`, como la web (`pesos` de `app2/.../cartera/comun.ts`): sin
/// decimales, con punto de miles y un espacio que no se parte.
String pesos(int valor) {
  final cifras = valor.abs().toString();
  final partes = <String>[];
  for (var fin = cifras.length; fin > 0; fin -= 3) {
    partes.insert(0, cifras.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${valor < 0 ? '−' : ''}\$ ${partes.join('.')}';
}

/// «10 oct 2026».
String fechaCorta(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_meses[d.month - 1].substring(0, 3)} ${d.year}';
}

/// «10 de octubre de 2026».
String fechaLarga(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} de ${_meses[d.month - 1]} de ${d.year}';
}

/// «hace 1 día», «hace 12 días».
String haceDias(int dias) => dias == 1 ? 'hace 1 día' : 'hace $dias días';
