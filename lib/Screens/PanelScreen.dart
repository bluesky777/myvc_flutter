import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PanelScreen extends StatefulWidget {
  @override
  _PanelScreen createState() => _PanelScreen();
}

class _PanelScreen extends State<PanelScreen> {
  Server server = Server();
  List<GrupoModel>? grupos;
  final _drawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    try {
      server.get('/grupos').then((response) {
        final String res = response.body;

        setState(() {
          grupos = grupoModelFromJson(res);
        });
      });
    } catch (e) {
      print('*** Error ${Server.urlApi}/grupos ');
      print(e);
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
      // Sin esto el menú no se podía cerrar: mainScreenAbsorbPointer viene en
      // true, así que con el menú abierto la pantalla principal se traga los
      // toques y el icono ☰ deja de responder; y mainScreenTapClose viene en
      // false, así que tocar fuera tampoco cerraba. Solo quedaba arrastrar.
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        appBar: AppBar(
          title: Text('Elija grupo'),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () {
              print('Presionando icon');
              _drawerController.toggle!();
            },
          ),
        ),
        body: SingleChildScrollView(
            child: grupos != null
                ? _buildListaGrupos()
                : Text('Esperando grupos...')),

        //drawer: DrawPanel(),
      ),
    );
  }

  Widget _buildListaGrupos() => ListView.builder(
        scrollDirection: Axis.vertical,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: grupos!.length,
        itemBuilder: (context, index) {
          GrupoModel grupo = grupos![index];
          return ListTile(
            title: Text(grupo.nombre),
            leading: CircleAvatar(
              child: Text(grupo.abrev),
            ),
            onTap: () {
              print(grupo);
              SharedPreferences.getInstance()
                  .then((SharedPreferences preferences) {
                preferences.setString('grupoSelected', grupo.toRawJson());
                Navigator.pushNamed(context, '/alum-tardanza-cole');
              });
            },
            trailing: Icon(Icons.arrow_right),
          );
        },
      );

  Widget buildTile(GrupoModel grupo) => ListTile(
        title: Text(
          grupo.nombre,
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}
