import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Screens/DrawPanel.dart';

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
    server.get('/grupos').then((response) {
      final String res = response.body;
      final List parsedList = json.decode(res);
      setState(() {
        grupos = parsedList.map((dato) => GrupoModel.fromJson(dato)).toList();
        print('grupos.length: ${grupos?.length}');
      });

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: SingleChildScrollView(
        child: grupos != null ? _buildListaGrupos() : Text('Esperando grupos...')
      ),
      drawer: DrawPanel(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget buildTile(GrupoModel grupo) => ListTile(
        title: Text(
          grupo.nombre,
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  Widget _buildListaGrupos() => ExpansionPanelList.radio(
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
