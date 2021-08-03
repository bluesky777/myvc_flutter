import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DrawPanel extends StatelessWidget {
  const DrawPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Mi Colegio Virtual'),
          ),
          ListTile(
            title: const Text('Tardanzas a la entrada'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
