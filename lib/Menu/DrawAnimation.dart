import 'package:flutter/material.dart';
import 'package:myvc_flutter/Menu/MyUserHeader.dart';
import 'package:myvc_flutter/Menu/opcionesMenuPrincipal.dart';

class DrawAnimation extends StatefulWidget {
  const DrawAnimation({Key? key}) : super(key: key);

  @override
  _DrawAnimationState createState() => _DrawAnimationState();
}

class _DrawAnimationState extends State<DrawAnimation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Stack(
        children: [
          CustomScrollView(
            slivers: <Widget>[
              SliverPersistentHeader(
                floating: true,
                pinned: true,
                delegate: MyUserHeader(),
              ),
              SliverList(
                delegate: SliverChildListDelegate(itemsMenuPrincipal),
              )
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Divider(
                height: 20,
                thickness: 2,
                indent: 20,
                endIndent: 20,
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Cerrar sesión'),
                onTap: () {
                  print('presionando cerrar');
                  Navigator.pushNamed(context, '/login');
                },
              ),
              SizedBox(
                height: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
