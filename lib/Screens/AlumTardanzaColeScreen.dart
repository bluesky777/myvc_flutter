import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Screens/DrawPanel.dart';

class AlumTardanzaColeScreen extends StatefulWidget {
  @override
  _AlumTardanzaColeScreen createState() => _AlumTardanzaColeScreen();
}

class _AlumTardanzaColeScreen extends State<AlumTardanzaColeScreen> {
  Server server = Server();
  List<AlumnoModel>? alumnos;

  @override
  void initState() {
    super.initState();
    server.get('/alumnos').then((response) {
      final String res = response.body;
      final List parsedList = json.decode(res);
      setState(() {
        alumnos = parsedList.map((dato) => AlumnoModel.fromJson(dato)).toList();
        print('grupos.length: ${alumnos?.length}');
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
      headerBuilder: (context, is_expanded) => buildTile(alumno),
      body: Column(children: [
        Text('Una cosa mientras'),
      ]),
    ))
        .toList(),
  );
}
