import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Widgets/Publicacion.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';

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
        // El nombre de la pantalla arriba y el periodo en su propia franja
        // debajo. Antes iba solo el periodo, con el argumento de que el muro se
        // reconoce solo; pero las unidades y la disciplina llevaban ese mismo
        // título, así que las tres barras decían lo mismo y ninguna decía dónde
        // estabas. «Inicio» y no «Muro», que es como lo llama el menú.
        body: BarraPlegable(
          titulo: 'Inicio',
          alAbrirMenu: () => _drawerController.toggle!(),
          alCambiarContexto: _cargar,
          child: _buildCuerpo(),
        ),
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
    final acceso = _buildAccesoANotas();

    return RefreshIndicator(
      onRefresh: Analitica.refresco('muro', _cargar),
      child: publicaciones.isEmpty
          ? _muroVacio(acceso)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // El acceso a notas va dentro de la lista y no flotando encima:
              // un botón flotante tapa publicaciones, y en un muro largo eso
              // estorba justo donde se está leyendo.
              itemCount: publicaciones.length + (acceso == null ? 0 : 1),
              itemBuilder: (context, i) {
                if (acceso != null && i == 0) return acceso;
                final indice = acceso == null ? i : i - 1;
                return Publicacion(publicacion: publicaciones[indice]);
              },
            ),
    );
  }

  /// La puerta a las notas, para el docente, encima de las publicaciones.
  ///
  /// Con las clases de hoy dentro y no como un botón a secas: ese dato ya viene
  /// en la misma respuesta del muro —no cuesta ninguna petición, ver
  /// [HorarioDeHoy]— y convierte el botón en información. Cuando no se sabe
  /// cuántas son, se dice «Notas» y ya.
  Widget? _buildAccesoANotas() {
    if (!AuthService.user.esDocente) return null;

    final horario = HorarioDeHoy.instancia;
    final cuantas = horario.cuantas;

    final grupos = horario.clases
        .map((c) => c.asignatura.abrevGrupo)
        .where((abrev) => abrev.isNotEmpty)
        .toSet()
        .join(', ');

    final String detalle;
    if (!horario.seSabe) {
      detalle = 'Poner y corregir notas';
    } else if (cuantas == 0) {
      detalle = 'Hoy no tienes clases';
    } else {
      detalle = '$cuantas ${cuantas == 1 ? 'clase' : 'clases'} hoy'
          '${grupos.isEmpty ? '' : ' · $grupos'}';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, '/notas'),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.edit_note_outlined, color: kPrimaryColor),
        ),
        title: const Text(
          'Notas',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detalle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  /// Un muro sin nada. Tiene que poder tirarse hacia abajo igual, o el docente
  /// que entra el primer día del año se queda sin forma de recargar.
  Widget _muroVacio(Widget? acceso) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (acceso != null) acceso,
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
