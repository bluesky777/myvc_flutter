import 'dart:ui';

import 'package:flutter/material.dart';

/// Tapa y bloquea un grupo de controles mientras su petición está en curso.
///
/// Los botones que ponen o quitan una falta escriben en la base de datos. Entre
/// el toque y la respuesta del servidor pasa un rato —más en la red de un
/// colegio— y en ese rato los botones seguían aceptando toques: dos toques
/// seguidos en «+» son dos filas en la tabla ausencias, y el docente no tiene
/// forma de saber que la primera ya iba en camino.
///
/// Lo que se bloquea es solo lo que envuelve este widget. Cada alumno y cada
/// tipo de falta llevan el suyo, así que esperar por la tardanza de uno no
/// congela los botones de los otros treinta y nueve.
class ControlOcupado extends StatelessWidget {
  const ControlOcupado({
    super.key,
    required this.ocupado,
    required this.child,
  });

  final bool ocupado;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // AbsorbPointer y no IgnorePointer: los toques tienen que morir aquí,
        // no colarse a lo que haya debajo.
        AbsorbPointer(absorbing: ocupado, child: child),
        if (ocupado) ...[
          // El ClipRect encierra el desenfoque en este recuadro; sin él,
          // BackdropFilter difumina también lo que tiene alrededor.
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
          ),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ],
    );
  }
}
