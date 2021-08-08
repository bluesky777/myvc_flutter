import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Screens/DrawPanel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PanelScreen extends StatefulWidget {
  @override
  _PanelScreen createState() => _PanelScreen();
}

class _PanelScreen extends State<PanelScreen> {
  Server server = Server();
  List<GrupoModel>? grupos;

  @override
  void initState() {
    super.initState();
    print('**** init panel');
    server.get('/grupos').then((response) {
      final String res = response.body;

      setState(() {
        grupos = grupoModelFromJson(res);
        print('grupos.length: ${grupos?.length}');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Elija grupo'),
      ),
      body: SingleChildScrollView(
          child: grupos != null
              ? _buildListaGrupos()
              : Text('Esperando grupos...')),
      drawer: DrawPanel(),
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
                onTap: (){
                  print(grupo);
                  SharedPreferences.getInstance().then((SharedPreferences preferences) {
                    print('grupoSelected ${grupo.toJson()}');
                    preferences.setString('grupoSelected', grupo.toRawJson() );

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

  Widget _buildListaGruposOriginal() => ExpansionPanelList.radio(
        children: grupos!
            .map((grupo) => ExpansionPanelRadio(
                  canTapOnHeader: true,
                  value: grupo.nombre,
                  headerBuilder: (context, isExpanded) => buildTile(grupo),
                  body: Column(children: [
                    Text('Una cosa mientras'),
                  ]),
                ))
            .toList(),
      );
}
