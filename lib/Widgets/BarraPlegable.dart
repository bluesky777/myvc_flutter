import 'package:flutter/material.dart';
import 'package:myvc_flutter/Widgets/BarraContexto.dart';

/// La barra de arriba de las pantallas que cuelgan del menú.
///
/// Arriba el nombre de la pantalla, que se queda siempre; debajo el año con el
/// periodo, que al desplazar sube y se esconde detrás del título. Así, al
/// leer una lista larga, la pantalla no gasta dos renglones en decir dónde
/// estás cuando ya lo sabes, pero basta volver arriba para cambiar de periodo.
///
/// Envuelve al cuerpo en vez de sustituirlo: se monta en `body:` y el cuerpo
/// sigue siendo la misma lista de siempre, con su RefreshIndicator. Es lo que
/// permite plegar la barra sin reescribir tres pantallas como slivers.
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
/// Sin `appBar:` en el Scaffold: la barra va aquí dentro, que es lo que la
/// hace parte del desplazamiento.
class BarraPlegable extends StatelessWidget {
  const BarraPlegable({
    super.key,
    required this.titulo,
    required this.child,
    this.alAbrirMenu,
    this.alCambiarContexto,
    this.actions = const [],
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

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          title: Text(titulo),
          leading: alAbrirMenu == null
              ? null
              : GestureDetector(
                  onTap: alAbrirMenu,
                  child: Icon(Icons.menu),
                ),
          actions: actions,
          // Lo que mide desplegada. Al plegarse se queda en la altura del
          // título, que es lo que mantiene `pinned`.
          expandedHeight: kToolbarHeight + BarraContexto.alto,
          flexibleSpace: FlexibleSpaceBar(
            // `pin` y no el parallax de por defecto: la franja se queda quieta
            // y el título la va tapando, en vez de subir a media velocidad,
            // que se lee como que algo va mal encajado.
            collapseMode: CollapseMode.pin,
            background: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // El hueco del título, que va por encima de esto.
                  const SizedBox(height: kToolbarHeight),
                  BarraContexto(alCambiar: alCambiarContexto),
                ],
              ),
            ),
          ),
        ),
      ],
      body: child,
    );
  }
}
