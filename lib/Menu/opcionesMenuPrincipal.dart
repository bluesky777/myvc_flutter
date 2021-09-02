import 'package:flutter/material.dart';

List<Map> opcionesMenuPrincipal = [
  {'icon': Icons.home, 'title': 'Inicio'},
  {'icon': Icons.access_time, 'title': 'Asistencia clases'},
  {'icon': Icons.time_to_leave, 'title': 'Asistencia Institución'},
  {'icon': Icons.home, 'title': 'Inicio'},
];

final List<Widget> itemsMenuPrincipal = List.generate(
  opcionesMenuPrincipal.length,
  (index) => ListTile(
    leading: Icon(opcionesMenuPrincipal[index]['icon']),
    title: Text(opcionesMenuPrincipal[index]['title']),
    onTap: () {
      print('presionando');
    },
  ),
);
