import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/alumno.dart';
import 'package:myvc_flutter/Screens/DrawPanel.dart';

class PanelScreen extends StatefulWidget {
  @override
  _PanelScreen createState() => _PanelScreen();
}

class _PanelScreen extends State<PanelScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: SingleChildScrollView(
        child: ExpansionPanelList.radio(
          children: alumnos
              .map((alum) => ExpansionPanelRadio(
                    canTapOnHeader: true,
                    value: alum.nombres,
                    headerBuilder: (context, is_expanded) => buildTile(alum),
                    body: Column(children: [
                      Text('Una cosa mientras'),
                    ]),
                  ))
              .toList(),
        ),
      ),
      drawer: DrawPanel(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget buildTile(AlumnoModel alum) => ListTile(
        title: Text(alum.nombres,
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),

      );
}
