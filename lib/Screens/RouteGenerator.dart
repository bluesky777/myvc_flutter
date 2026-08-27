import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/Login/LoginAnimScreen.dart';
import 'package:myvc_flutter/Screens/MiAsistenciaScreen.dart';
import 'package:myvc_flutter/Screens/MisNotasScreen.dart';
import 'package:myvc_flutter/Screens/MuroScreen.dart';
import 'package:myvc_flutter/Screens/NotasPerdidasScreen.dart';
import 'package:myvc_flutter/Screens/NotasScreen.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';
import 'package:myvc_flutter/Screens/MiDisciplinaScreen.dart';
import 'package:myvc_flutter/Screens/PrivacidadScreen.dart';
import 'package:myvc_flutter/Screens/UnidadesScreen.dart';
import 'package:myvc_flutter/Screens/UsuariosScreen.dart';
import 'package:myvc_flutter/Screens/ActualizarScreen.dart';
import 'package:myvc_flutter/Utils/VersionMinima.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Screens/ConfiguracionScreen.dart';
import 'package:myvc_flutter/Screens/DisciplinaGrupoScreen.dart';
import 'package:myvc_flutter/Screens/FaltasAlumnoScreen.dart';

import 'AlumTardanzaColeScreen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Antes que nada, y para todas las rutas: si esta versión ya no la acepta
    // el colegio, no se entra a ninguna parte. Va aquí y no en cada pantalla
    // porque una puerta que se comprueba en veinte sitios es una puerta que un
    // día se queda sin comprobar en uno.
    //
    // Y no bloquea por sospecha: `bloquea` solo dice que sí cuando el servidor
    // mandó un número que se entiende y esta app se queda corta. Ver
    // VersionMinima.
    //
    // El login se deja pasar, y no es una rendija: son quince colegios con
    // una sola app, y el número lo pone cada colegio en su servidor. Sin esto,
    // a quien tenga cuenta en dos y le bloquee el primero no le quedaría forma
    // de llegar a la pantalla de entrar para usar el segundo, que sí acepta su
    // versión. No debilita nada, porque entrar vuelve a leer el número: si el
    // colegio nuevo también lo exige, la puerta se cierra otra vez al salir
    // del login.
    const fuera = ['/actualizar', '/login', '/'];

    if (VersionMinima.bloquea && !fuera.contains(settings.name)) {
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/actualizar'),
        builder: (context) => const ActualizarScreen(),
      );
    }

    switch (settings.name) {
      case '/actualizar':
        return MaterialPageRoute(
            settings: settings, builder: (context) => const ActualizarScreen());
      // '/' es el login: es donde cae quien abre la app sin sesión, y antes lo
      // resolvía el `home:` de MaterialApp, que se quitó para poder arrancar en
      // otra pantalla al recuperar la sesión.
      case '/':
      case '/login':
        return MaterialPageRoute(
            settings: settings, builder: (context) => LoginAnimScreen());
      case '/muro':
        return MaterialPageRoute(
            settings: settings, builder: (context) => MuroScreen());
      case '/mis-notas':
        return MaterialPageRoute(
            settings: settings, builder: (context) => MisNotasScreen());
      case '/mi-asistencia':
        return MaterialPageRoute(
            settings: settings, builder: (context) => MiAsistenciaScreen());
      case '/mi-disciplina':
        return MaterialPageRoute(
            settings: settings,
            builder: (context) => const MiDisciplinaScreen());
      case '/privacidad':
        return MaterialPageRoute(
            settings: settings, builder: (context) => const PrivacidadScreen());
      case '/notas':
        return MaterialPageRoute(
            settings: settings, builder: (context) => NotasScreen());
      case '/notas-perdidas':
        return MaterialPageRoute(
            settings: settings, builder: (context) => NotasPerdidasScreen());
      case '/unidades':
        return MaterialPageRoute(
            settings: settings, builder: (context) => UnidadesScreen());
      // Solo la de entrada tiene nombre. La ficha del alumno, el editor de
      // situaciones y los uniformes se abren con push directo: reciben modelos
      // ya cargados y devuelven el alumno recalculado, y por una ruta con
      // nombre eso viaja como `Object?` y hay que creerse el tipo al bajarlo.
      case '/disciplina':
        return MaterialPageRoute(
            settings: settings, builder: (context) => DisciplinaGrupoScreen());
      case '/configuracion':
        return MaterialPageRoute(
            settings: settings, builder: (context) => ConfiguracionScreen());
      case '/usuarios':
        return MaterialPageRoute(
            settings: settings, builder: (context) => UsuariosScreen());
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
