import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Widgets/FondoFalta.dart';
import 'package:myvc_flutter/constantes.dart';

void main() {
  test('sin faltas no se pinta nada', () {
    expect(fondoDeFaltas(tardanza: false, ausencia: false), isNull);
    expect(colorFinalDeFaltas(tardanza: false, ausencia: false), isNull);
  });

  test('solo tardanza: rosa liso', () {
    final fondo = fondoDeFaltas(tardanza: true, ausencia: false)!;

    expect(fondo.color, kColorTardanza);
    expect(fondo.gradient, isNull);
    expect(colorFinalDeFaltas(tardanza: true, ausencia: false), kColorTardanza);
  });

  test('solo ausencia: morado liso', () {
    final fondo = fondoDeFaltas(tardanza: false, ausencia: true)!;

    expect(fondo.color, kColorAusencia);
    expect(fondo.gradient, isNull);
    expect(colorFinalDeFaltas(tardanza: false, ausencia: true), kColorAusencia);
  });

  test('las dos cosas el mismo día: degradado de rosa a morado', () {
    final fondo = fondoDeFaltas(tardanza: true, ausencia: true)!;

    expect(fondo.color, isNull);
    expect(
      (fondo.gradient as LinearGradient).colors,
      [kColorTardanza, kColorAusencia],
    );
  });

  test('el degradado termina en morado, y ahí sigue la flecha', () {
    // El trozo de la flecha lo pinta el panel: tiene que continuar el color en
    // el que acaba la cabecera, no empezar otro.
    final fondo = fondoDeFaltas(tardanza: true, ausencia: true)!;
    final ultimo = (fondo.gradient as LinearGradient).colors.last;

    expect(colorFinalDeFaltas(tardanza: true, ausencia: true), ultimo);
  });
}
