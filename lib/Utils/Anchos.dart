import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Cuánto se deja crecer a lo que se lee en línea.
///
/// **Por qué existe este archivo.** La app se diseñó para un teléfono y ahí un
/// ancho proporcional —«el 80% de la pantalla»— es exactamente lo correcto: el
/// control ocupa lo que hay y deja un margen a los lados. En una tablet ese
/// mismo 80% son 1.300 px, y un campo de texto de 1.300 px no lo lee nadie: el
/// ojo pierde el renglón, el icono de la izquierda queda a un palmo del texto y
/// el botón «Entrar» se convierte en una franja de lado a lado.
///
/// Así que la regla no es «proporcional» ni «fijo», sino **proporcional con
/// tope**: en un teléfono manda la proporción y nada cambia; en una tablet manda
/// el tope y el control se queda centrado con aire a los lados.
///
/// No es un sistema de *breakpoints* y no hay que convertirlo en uno. Es un
/// número máximo, que es lo que resuelve el 90% del problema de esta app en
/// tablet — el otro 10% son las pantallas de detalle, que necesitan aprovechar
/// el hueco y no solo dejar de estirarse. Ver `docs/tablets.md`.
class Anchos {
  Anchos._();

  /// El tope de un control de formulario: un campo, un botón, una casilla.
  ///
  /// 420 no es un número redondo por casualidad: es aproximadamente el ancho de
  /// un teléfono grande, así que **en tablet el formulario se ve como se ve en
  /// el teléfono para el que se diseñó**, centrado, en vez de como una versión
  /// estirada de sí mismo.
  static const double formulario = 420;

  /// El tope de una ficha: una columna de datos de una persona.
  ///
  /// Casi el doble que [formulario], y no por capricho. Una ficha no es un
  /// formulario: aguanta más ancho porque lo que lleva dentro son bloques —una
  /// fila de tres contadores, una lista de situaciones con su fecha y su
  /// docente— y no un renglón que el ojo tenga que seguir de punta a punta.
  /// Apretarla a 420 desperdiciaría la tablet en la dirección contraria.
  ///
  /// Lo que sí hace es cortar los dos estiramientos que se midieron: los tres
  /// contadores, que son `Expanded` y se reparten lo que haya —a pantalla
  /// completa cada uno mide medio palmo—, y la descripción de una situación,
  /// que sí es un renglón y a 1.700 px no se lee.
  static const double ficha = 720;

  /// La banda del login: el 80% de la pantalla, sin pasar de [formulario].
  ///
  /// Los tres controles del login —el campo, el botón y la casilla de recordar—
  /// tienen que medir **lo mismo** o se ve un escalón entre ellos. Antes cada
  /// uno escribía `size.width * 0.8` por su cuenta y el comentario de uno de
  /// ellos avisaba de que los otros dos hacían lo mismo; eso es tres sitios
  /// donde cambiar una decisión que es una.
  static double bandaDeLogin(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;

    return math.min(ancho * 0.8, formulario);
  }
}
