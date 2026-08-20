import 'package:flutter/material.dart';
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/Http/AuthService.dart';

/// El menú lateral, uno solo para toda la app.
///
/// Antes había dos: el del inicio, con la cabecera y el cierre de sesión, y
/// otro distinto en el listado de alumnos con un único elemento que no llevaba
/// a ninguna parte. Ahora las dos pantallas montan este mismo.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCabecera(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._opciones(context),
                ],
              ),
            ),
            Divider(height: 20, thickness: 2, indent: 20, endIndent: 20),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Cerrar sesión'),
              onTap: () async {
                await LoginController().logout();

                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (ruta) => false);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Lo que ve cada quien.
  ///
  /// El muro es de todos; lo demás depende del rol. Un alumno no tiene nada que
  /// hacer en el listado de grupos del colegio, y un docente no tiene «Mis
  /// notas» que mirar.
  List<Widget> _opciones(BuildContext context) {
    final usuario = AuthService.user;

    final opciones = <Widget>[
      _opcion(
        context,
        icono: Icons.forum_outlined,
        texto: 'Publicaciones',
        ruta: '/muro',
      ),
    ];

    if (usuario.esAlumno || usuario.esAcudiente) {
      opciones.addAll([
        _opcion(
          context,
          icono: Icons.school_outlined,
          texto: 'Mis notas',
          ruta: '/mis-notas',
        ),
        _opcion(
          context,
          icono: Icons.event_available_outlined,
          texto: 'Asistencia',
          ruta: '/mi-asistencia',
        ),
      ]);
      return opciones;
    }

    // Docentes, administrativos y superusuarios.
    opciones.add(_opcion(
      context,
      icono: Icons.fact_check_outlined,
      texto: 'Asistencias',
      ruta: '/panel',
    ));

    opciones.add(_opcion(
      context,
      icono: Icons.menu_book_outlined,
      texto: 'Unidades',
      ruta: '/unidades',
    ));

    return opciones;
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String texto,
    required String ruta,
  }) {
    return ListTile(
      leading: Icon(icono),
      title: Text(texto),
      onTap: () =>
          Navigator.pushNamedAndRemoveUntil(context, ruta, (_) => false),
    );
  }

  Widget _buildCabecera() {
    return Container(
      color: Colors.lightBlueAccent,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image(
            image: AssetImage('assets/images/logoMy.png'),
            height: 70,
          ),
          SizedBox(height: 12),
          // El usuario a la vista: es quien queda firmando cada tardanza.
          Text(
            AuthService.user.nombres ?? 'Sin identificar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            AuthService.user.username,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
