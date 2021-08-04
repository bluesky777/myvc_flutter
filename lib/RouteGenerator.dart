

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/LoginScreen.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';

import 'Screens/AlumTardanzaColeScreen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(settings: settings, builder: (context) => LoginScreen());
      case '/panel':
        return MaterialPageRoute(settings: settings, builder: (context) => PanelScreen());
      case '/alum-tardanza-cole':
        return MaterialPageRoute(settings: settings, builder: (context) => AlumTardanzaColeScreen());
      default:
        return MaterialPageRoute(settings: settings, builder: (context) => PanelScreen());
    }
  }
}