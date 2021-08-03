

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/LoginScreen.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(settings: settings, builder: (context) => LoginScreen());
        break;
      case '/panel':
        return MaterialPageRoute(settings: settings, builder: (context) => PanelScreen());
        break;
      default:
        return MaterialPageRoute(settings: settings, builder: (context) => PanelScreen());
    }
  }
}