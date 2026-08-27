import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';

/// Centra el contenido de una ficha y no lo deja crecer más de la cuenta.
///
/// **En un teléfono no hace nada**, y eso es lo que la hace segura de meter en
/// una pantalla que ya funciona: la pantalla es más estrecha que el tope, así
/// que el `ConstrainedBox` no llega a apretar y el `Center` no tiene sitio que
/// repartir. En una tablet el contenido se queda en una columna centrada con
/// aire a los lados.
///
/// Va **por dentro del Scaffold y por fuera del scroll**, envolviendo la lista
/// entera y no cada fila: si se pone por dentro, cada fila se centra por su
/// cuenta y los separadores siguen yendo de punta a punta, que es peor que no
/// hacer nada porque el corte se ve a medias.
///
/// Ver `docs/tablets.md`.
class ColumnaDeFicha extends StatelessWidget {
  const ColumnaDeFicha({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Anchos.ficha),
        child: child,
      ),
    );
  }
}
