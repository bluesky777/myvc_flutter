import 'package:flutter/material.dart';
import 'package:myvc_flutter/constantes.dart';

/// El fondo con el que se señala, en la lista del grupo, lo que un alumno tiene
/// ese día frente a la institución.
///
/// Rosa si llegó tarde, morado si no vino, y un degradado de los dos cuando
/// tiene de las dos cosas: son dos hechos distintos del mismo día y ninguno
/// tapa al otro.
///
/// Devuelve null cuando no hay nada que señalar. En una lista de cuarenta
/// alumnos lo que tiene que saltar a la vista son los pocos que sí.
BoxDecoration? fondoDeFaltas({
  required bool tardanza,
  required bool ausencia,
}) {
  if (tardanza && ausencia) {
    return const BoxDecoration(
      gradient: LinearGradient(colors: [kColorTardanza, kColorAusencia]),
    );
  }
  if (tardanza) return const BoxDecoration(color: kColorTardanza);
  if (ausencia) return const BoxDecoration(color: kColorAusencia);

  return null;
}

/// El color en el que termina esa franja, por la derecha.
///
/// La flecha de abrir el panel la pinta ExpansionPanelList por su cuenta, fuera
/// de la cabecera, y ese trozo solo se puede colorear con el backgroundColor
/// del panel. Dándole el color final, la franja llega entera hasta el borde.
Color? colorFinalDeFaltas({
  required bool tardanza,
  required bool ausencia,
}) {
  if (ausencia) return kColorAusencia;
  if (tardanza) return kColorTardanza;
  return null;
}
