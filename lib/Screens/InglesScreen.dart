import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Screens/WebConSesionScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// English Quest: la racha para jugar y, para el personal, la racha semanal
/// del curso. Las dos son las páginas de la web con la sesión de la app
/// ([WebConSesionScreen]); el progreso es la misma fila de
/// `ingles_progreso` que en el navegador. Ver `docs/ingles.md`.
class InglesScreen extends StatefulWidget {
  const InglesScreen({super.key});

  @override
  State<InglesScreen> createState() => _InglesScreenState();
}

class _InglesScreenState extends State<InglesScreen> {
  final _drawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    Analitica.evento('ingles_abierta');
  }

  void _abrir(String titulo, String ruta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'ingles${ruta.replaceAll('/', '-')}'),
        builder: (_) => WebConSesionScreen(titulo: titulo, ruta: ruta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.user;
    final personal = !(usuario.esAlumno || usuario.esAcudiente);

    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: const TituloPantalla(titulo: 'English Quest'),
          leading: GestureDetector(
            child: const Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _Entrada(
              emoji: '🔥',
              titulo: 'Racha',
              texto: 'Una lección corta cada día: el camino de A1, la meta '
                  'diaria y los protectores de racha.',
              alTocar: () => _abrir('Racha', '/ingles/racha'),
            ),
            if (personal) ...[
              const SizedBox(height: 10),
              _Entrada(
                emoji: '📊',
                titulo: 'Racha de mi curso',
                texto: 'Quién practicó esta semana, quién está en riesgo y la '
                    'nota sugerida con la escala del colegio.',
                alTocar: () =>
                    _abrir('Racha de mi curso', '/ingles/racha/curso'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.emoji,
    required this.titulo,
    required this.texto,
    required this.alTocar,
  });

  final String emoji;
  final String titulo;
  final String texto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(emoji, style: const TextStyle(fontSize: 32)),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Text(texto),
        trailing: const Icon(Icons.chevron_right),
        onTap: alTocar,
      ),
    );
  }
}
