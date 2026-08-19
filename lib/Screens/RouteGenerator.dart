import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/Login/LoginAnimScreen.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Screens/FaltasAlumnoScreen.dart';

import 'AlumTardanzaColeScreen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(
            settings: settings, builder: (context) => LoginAnimScreen());
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
        return MaterialPageRoute(
            settings: settings, builder: (context) => PanelScreen());
    }
  }
}
