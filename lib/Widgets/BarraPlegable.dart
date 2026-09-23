import 'package:flutter/material.dart';
import 'package:myvc_flutter/Widgets/BarraContexto.dart';
import 'package:myvc_flutter/Widgets/LogoDelColegio.dart';

/// La barra de arriba de las pantallas que cuelgan del menú.
///
/// Una sola fila: el menú, el nombre de la pantalla y, a la derecha, el año con
/// el periodo. **Fueron dos durante un tiempo** —el periodo tenía franja
/// propia, que se plegaba al desplazar— y el porqué del cambio está escrito en
/// [BarraContexto], que es la que se mudó.
///
/// Envuelve al cuerpo en vez de sustituirlo: se monta en `body:` y el cuerpo
/// sigue siendo la misma lista de siempre, con su RefreshIndicator.
///
///     Scaffold(
///       body: BarraPlegable(
///         titulo: 'Disciplina',
///         alAbrirMenu: () => _drawerController.toggle!(),
///         alCambiarContexto: _arrancar,
///         child: _cuerpo(),
///       ),
///     )
///
/// Sin `appBar:` en el Scaffold: la barra va aquí dentro.
///
/// **Sigue siendo un `NestedScrollView` con un sliver aunque ya no se pliegue
/// nada**, y eso es a propósito: las seis pantallas que la usan montan dentro
/// listas que se desplazan, y cambiarlo por una `Column` con la barra fija
/// movería el desplazamiento de sitio en las seis a cambio de nada que se vea.
class BarraPlegable extends StatelessWidget {
  const BarraPlegable({
    super.key,
    required this.titulo,
    required this.child,
    this.alAbrirMenu,
    this.alCambiarContexto,
    this.actions = const [],
    this.conLogo = false,
  });

  /// Dónde estoy. El mismo nombre que use el menú.
  final String titulo;

  /// El cuerpo de la pantalla, tal cual.
  final Widget child;

  /// Abrir el menú lateral. Sin esto no sale el botón.
  final VoidCallback? alAbrirMenu;

  /// Qué hacer cuando se cambia de año o de periodo: normalmente, recargar.
  final VoidCallback? alCambiarContexto;

  final List<Widget> actions;

  /// Si delante del título va el logo del colegio.
  ///
  /// **Apagado por defecto, y a propósito.** Lo enciende el muro, donde el
  /// título son las siglas del colegio y el logo las acompaña; en «Unidades» o
  /// «Disciplina» el título ya dice dónde estás y el logo solo le quitaría
  /// ancho. Además no es gratis en todas: esas pantallas tienen botones propios
  /// en `actions`, y el sitio de la fila es el mismo para todos.
  ///
  /// Sin logo guardado no deja hueco: ver [LogoDelColegio].
  final bool conLogo;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          title: Row(
            children: [
              if (conLogo) const LogoDelColegio(),
              Flexible(child: Text(titulo, overflow: TextOverflow.ellipsis)),
            ],
          ),
          leading: alAbrirMenu == null
              ? null
              : GestureDetector(
                  onTap: alAbrirMenu,
                  child: Icon(Icons.menu),
                ),
          // El año y el periodo delante de lo que traiga la pantalla: es el
          // control que está en las seis y conviene que no baile de sitio
          // según cuántos botones tenga cada una.
          actions: [
            BarraContexto(alCambiar: alCambiarContexto),
            ...actions,
          ],
          // El título cede el sitio antes que el periodo: es el dato que no se
          // toca, y en las pantallas del menú quien mira ya sabe dónde está.
          titleSpacing: 0,
        ),
      ],
      body: child,
    );
  }
}
