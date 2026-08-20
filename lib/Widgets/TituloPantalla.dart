import 'package:flutter/material.dart';

/// El título de la barra de arriba, en dos líneas: dónde estoy, y sobre qué.
///
/// Nació de un problema que solo se ve con la app montada. Tres pantallas
/// —el inicio, las unidades y la disciplina— llevaban por título únicamente
/// «2026 · Periodo 3». Es un dato que hay que tener delante, sí, pero al ser el
/// mismo en las tres no había forma de saber en cuál se estaba: se entra por el
/// menú, se mira arriba y pone lo mismo que ponía antes de entrar. Lo mismo
/// pasaba con las de un alumno, que enseñaban su nombre y nada más: un
/// acudiente con un solo hijo veía «Ana Acosta» tanto en las notas como en la
/// asistencia.
///
/// Arriba va el nombre de la pantalla, el mismo con el que se la llama en el
/// menú. Debajo, en pequeño, sobre qué se está trabajando: el periodo, el
/// alumno, el grupo.
class TituloPantalla extends StatelessWidget {
  const TituloPantalla({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.conFlecha = false,
  });

  /// Dónde estoy. Corto, y el mismo nombre que use el menú: si el menú dice
  /// «Disciplina», la barra no puede decir «Convivencia».
  final String titulo;

  /// Sobre qué. Se omite cuando no hay nada que añadir.
  final String? subtitulo;

  /// La flechita que dice que esto se puede tocar para cambiarlo.
  final bool conFlecha;

  @override
  Widget build(BuildContext context) {
    // Del estilo que ya trae la barra, para que valga igual sobre fondo claro
    // que sobre uno oscuro en vez de fijar un gris que solo sirve en uno.
    final color = DefaultTextStyle.of(context).style.color;
    final apagado = color?.withValues(alpha: 0.7);

    final abajo = subtitulo?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            // Apretadas, que las dos líneas tienen que caber en los 56 píxeles
            // de alto que mide la barra.
            height: 1.15,
          ),
        ),
        if (abajo != null && abajo.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  abajo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.2, color: apagado),
                ),
              ),
              if (conFlecha)
                Icon(Icons.expand_more, size: 16, color: apagado),
            ],
          ),
      ],
    );
  }
}
