import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/Login/LoginAnimScreen.dart';
import 'package:myvc_flutter/Screens/MuroScreen.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';
import 'package:myvc_flutter/Screens/PantallaPendiente.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Screens/FaltasAlumnoScreen.dart';

import 'AlumTardanzaColeScreen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(
            settings: settings, builder: (context) => LoginAnimScreen());
      case '/muro':
        return MaterialPageRoute(
            settings: settings, builder: (context) => MuroScreen());
      // Todavía sin construir, pero ya en el menú: ver PantallaPendiente.
      case '/mis-notas':
        return MaterialPageRoute(
            settings: settings,
            builder: (context) => PantallaPendiente(seccion: 'Mis notas'));
      case '/mi-asistencia':
        return MaterialPageRoute(
            settings: settings,
            builder: (context) => PantallaPendiente(seccion: 'Asistencia'));
      case '/unidades':
        return MaterialPageRoute(
            settings: settings,
            builder: (context) => PantallaPendiente(seccion: 'Unidades'));
      case '/panel':
        return MaterialPageRoute(
            settings: settings, builder: (context) => PanelScreen());
      case '/alum-tardanza-cole':
        return MaterialPageRoute(
            settings: settings, builder: (context) => AlumTardanzaColeScreen());
      case '/asistencia-clase':
        final argsClase = settings.arguments as AsistenciaClaseArgs;
        return MaterialPageRoute(
            settings: settings,
            builder: (context) => AsistenciaClaseScreen(args: argsClase));
      case '/faltas-alumno':
        final args = settings.arguments as FaltasAlumnoArgs;
        return MaterialPageRoute(
            settings: settings,
            builder: (context) => FaltasAlumnoScreen(args: args));
      default:
        // Y no PanelScreen. Mandar lo desconocido al panel hacía que un nombre
        // de ruta mal escrito no fallara: simplemente llevaba a otro sitio, y
        // eso se busca durante horas. Mejor que se vea dónde está el error.
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => _RutaDesconocida(nombre: settings.name),
        );
    }
  }
}

/// Lo que se ve cuando se navega a una ruta que no existe.
class _RutaDesconocida extends StatelessWidget {
  const _RutaDesconocida({this.nombre});

  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ruta desconocida')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wrong_location, size: 48),
              SizedBox(height: 12),
              Text(
                'No existe ninguna pantalla en «${nombre ?? 'sin nombre'}».',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/muro', (_) => false),
                child: Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
