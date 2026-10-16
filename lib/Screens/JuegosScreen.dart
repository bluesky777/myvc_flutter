import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/JuegosApi.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Screens/JuegoScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// La portada de los juegos: una tarjeta por juego, como en la web.
class JuegosScreen extends StatefulWidget {
  const JuegosScreen({super.key});

  @override
  State<JuegosScreen> createState() => _JuegosScreenState();
}

class _JuegosScreenState extends State<JuegosScreen> {
  final _drawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    Analitica.evento('juegos_abierta');
  }

  void _abrir(Juego3D juego) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'juego-${juego.id}'),
        builder: (_) => JuegoScreen(juego: juego),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: const TituloPantalla(titulo: 'Juegos'),
          leading: GestureDetector(
            child: const Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, medidas) {
            final columnas = medidas.maxWidth >= 900
                ? 3
                : medidas.maxWidth >= 600
                    ? 2
                    : 1;
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 150,
              ),
              itemCount: juegos3D.length,
              itemBuilder: (context, i) => _TarjetaDeJuego(
                juego: juegos3D[i],
                alTocar: () => _abrir(juegos3D[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaDeJuego extends StatelessWidget {
  const _TarjetaDeJuego({required this.juego, required this.alTocar});

  final Juego3D juego;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 84,
              color: juego.color,
              alignment: Alignment.center,
              child: Text(juego.emoji, style: const TextStyle(fontSize: 38)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      juego.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      juego.materia,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: juego.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        juego.texto,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
