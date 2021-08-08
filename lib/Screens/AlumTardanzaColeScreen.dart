import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Screens/DrawPanel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlumTardanzaColeScreen extends StatefulWidget {
  @override
  _AlumTardanzaColeScreen createState() => _AlumTardanzaColeScreen();
}

class _AlumTardanzaColeScreen extends State<AlumTardanzaColeScreen> {
  Server server = Server();
  List<AlumnoModel>? alumnos;
  GrupoModel? grupo;

  @override
  void initState() {
    super.initState();

    if (grupo == null) {
      SharedPreferences.getInstance().then((SharedPreferences preferences) {
        setState(() {
          String? gupoString = preferences.getString('grupoSelected');
          if(gupoString != null) {
            grupo = GrupoModel.fromRawJson(gupoString);
          }

        });
      });

    }else{
      print('Grupo después del if: ${grupo!.toJson()}');
    }


    server.get('/alumnos').then((response) {
      final String res = response.body;

      setState(() {
        alumnos = alumnoModelFromJson(res);
        print('alumnos: ${alumnos?.length}');
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
          child: alumnos != null ? _buildListaGrupos() : Text('Esperando alumnos...')
      ),
      drawer: DrawPanel(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget buildTile(AlumnoModel alumno) => ListTile(
    title: Text(
      alumno.nombres,
      //style: TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  Widget _buildListaGrupos() => ExpansionPanelList.radio(
    children: alumnos!
        .map((alumno) => ExpansionPanelRadio(
      canTapOnHeader: true,
      value: alumno.nombres,
      headerBuilder: (context, isExpanded) => buildTile(alumno),
      body: Column(children: [
        Text('Una cosa mientras'),
      ]),
    ))
        .toList(),
  );
}
