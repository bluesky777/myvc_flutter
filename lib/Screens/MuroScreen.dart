import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Widgets/Publicacion.dart';
import 'package:myvc_flutter/Widgets/TituloContexto.dart';

/// Lo primero que se ve al entrar: el muro del colegio.
///
/// Es la misma pared para todos —docentes, alumnos y acudientes—, y se recorre
/// hacia abajo como cualquier muro. Lo que cambia según quién mira es el menú
/// lateral, no esto.
class MuroScreen extends StatefulWidget {
  const MuroScreen({super.key});

  @override
  State<MuroScreen> createState() => _MuroScreenState();
}

class _MuroScreenState extends State<MuroScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  MuroCargado? muro;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      error = null;
      muro = null;
    });

    try {
      final traido = await traerMuro(server);
      if (!mounted) return;
      setState(() => muro = traido);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: _drawerController,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        // Un gris muy claro detrás: es lo que hace que cada publicación se lea
        // como una tarjeta y no como un trozo suelto de la pantalla.
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          // El nombre de la pantalla arriba y el periodo en su propia franja
          // debajo. Antes iba solo el periodo, con el argumento de que el muro
          // se reconoce solo; pero las unidades y la disciplina llevaban ese
          // mismo título, así que las tres barras decían lo mismo y ninguna
          // decía dónde estabas. «Inicio» y no «Muro», que es como lo llama el
          // menú.
          title: Text('Inicio'),
          bottom: BarraContexto(alCambiar: _cargar),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: _buildCuerpo(),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudieron traer las publicaciones.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargar,
                child: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (muro == null) {
      return Center(child: CircularProgressIndicator());
    }

    final publicaciones = muro!.publicaciones;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: publicaciones.isEmpty
          ? _muroVacio()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: publicaciones.length,
              itemBuilder: (context, i) =>
                  Publicacion(publicacion: publicaciones[i]),
            ),
    );
  }

  /// Un muro sin nada. Tiene que poder tirarse hacia abajo igual, o el docente
  /// que entra el primer día del año se queda sin forma de recargar.
  Widget _muroVacio() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 120),
        Icon(Icons.forum_outlined, size: 56, color: Colors.black26),
        SizedBox(height: 12),
        Center(
          child: Text(
            AuthService.user.puedeComentar
                ? 'Todavía no hay publicaciones.'
                : 'Todavía no hay publicaciones del colegio.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
