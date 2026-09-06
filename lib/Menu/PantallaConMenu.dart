import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';

/// Una pantalla con el menú lateral detrás, y la animación de abrirlo.
///
/// Es el mismo `ZoomDrawer` que montaba cada pantalla por su cuenta —catorce
/// copias de la misma configuración—, escrito una sola vez. No es solo por
/// ahorrar líneas: la copia fue lo que dejó pasar el fallo que motivó sacarlo
/// aquí.
///
/// Al subir `flutter_zoom_drawer` de 2 a 3 (commit ed1e86b) se cambió
/// `DrawerStyle.Style1` por `DrawerStyle.style1`, dando por hecho que solo
/// había cambiado la mayúscula. No: el paquete renumeró los estilos, y lo dice
/// en la tabla de migración de su README. El que era `Style1` —el contenido se
/// desliza a la derecha, se encoge a un 80 % y se inclina 8°, con dos sombras
/// claras detrás— pasó a llamarse `defaultStyle`; y `style1` pasó a ser el
/// antiguo `Style4`: un panel que se desliza por encima de un contenido que se
/// queda quieto. Con `angle: -8` en ese estilo, el paquete gira el contenido
/// sobre su esquina superior izquierda y nada más: ni se desliza ni se
/// encoge. Eso era lo que se veía desde la migración, y parecía una falla.
///
/// Lo demás son mandos que en la versión 2 estaban fijos y en la 3 son
/// parámetros con otro valor por defecto, puestos como estaban.
class PantallaConMenu extends StatelessWidget {
  const PantallaConMenu({
    super.key,
    required this.controller,
    required this.pantalla,
  });

  /// El que abre y cierra el menú. Cada pantalla tiene el suyo y lo llama
  /// desde el icono ☰ de su barra.
  final ZoomDrawerController controller;

  /// El contenido: normalmente un `Scaffold` con su `AppBar`.
  final Widget pantalla;

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      controller: controller,
      menuScreen: const MenuLateral(),
      mainScreen: pantalla,
      style: DrawerStyle.defaultStyle,
      slideWidth: 300,
      angle: -8.0,
      borderRadius: 40.0,
      // En la 2 el contenido se encogía un 20 % fijo; en la 3 es un mando que
      // viene en 30 %.
      mainScreenScale: 0.2,
      // Las dos sombras, con los tonos de la 2: una casi transparente al
      // fondo y una blanca del todo pegada al contenido. En la 3 vienen las
      // dos a medias.
      showShadow: true,
      shadowLayer1Color: Colors.white.withAlpha(31),
      shadowLayer2Color: Colors.white,
      // El menú quieto detrás y de lado a lado, que es como se dibujaba en la
      // 2. En la 3 viene deslizándose junto con el contenido y recortado a
      // unos 250 px de ancho, con lo que su fondo azul no llegaba a cubrir
      // todo lo que la inclinación deja ver.
      moveMenuScreen: false,
      menuScreenWidth: double.infinity,
      // Sin esto el menú no se podía cerrar: mainScreenAbsorbPointer viene en
      // true, así que con el menú abierto la pantalla principal se traga los
      // toques y el icono ☰ deja de responder; y mainScreenTapClose viene en
      // false, así que tocar fuera tampoco cerraba. Solo quedaba arrastrar.
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
    );
  }
}
