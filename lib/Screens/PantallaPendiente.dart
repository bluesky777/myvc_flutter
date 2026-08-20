import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';

/// Una sección que ya está en el menú pero todavía no está construida.
///
/// El menú se armó entero de una vez para que se vea la forma que va a tener la
/// app. Lo que falta se dice aquí y con todas las letras, en vez de dejar una
/// opción que no responde o que lleva a otro sitio: eso se lee como una avería,
/// no como algo pendiente.
class PantallaPendiente extends StatelessWidget {
  const PantallaPendiente({super.key, required this.seccion});

  final String seccion;

  @override
  Widget build(BuildContext context) {
    final controlador = ZoomDrawerController();

    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: controlador,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        appBar: AppBar(
          title: Text(seccion),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => controlador.toggle!(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction_outlined,
                    size: 56, color: Colors.black26),
                SizedBox(height: 16),
                Text(
                  '«$seccion» todavía no está lista.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Está en el menú porque va a ir aquí, pero aún no se ha'
                  ' construido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
