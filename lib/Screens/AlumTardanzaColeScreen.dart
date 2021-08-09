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
    traerDatos();
  }

  void traerDatos() {
    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? grupoString = preferences.getString('grupoSelected');
      print('grupoString $grupoString');
      setState(() {
        if (grupoString != null) {
          grupo = GrupoModel.fromRawJson(grupoString);
        } else {
          Navigator.pushNamed(context, '/panel');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    print('**** En build');
    if (alumnos == null && grupo != null) {
      var argum = {'grupo_id': '${grupo!.id}', 'con_grupos': false};

      server.put('/asistencias/detailed', argum).then((response) {
        final List alumnosList = jsonDecode(response.body)['alumnos'];

        setState(() {
          alumnos = alumnosList.map((e) => AlumnoModel.fromJson(e)).toList();
          print('alumnos: ${alumnos?.length}');
        });
      }, onError: (err) {
        print(
            'Error trayendo alumnos con ausencias ${Server.urlApi}/asistencias/detailed');
        print(err);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: SingleChildScrollView(
          child: alumnos != null
              ? _buildListaGrupos()
              : Text('Esperando alumnos...')),
      drawer: DrawPanel(),
    );
  }

  Widget buildTile(AlumnoModel alumno) => ListTile(
        title: Text(
          '${alumno.apellidos} ${alumno.nombres}',
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: CircleAvatar(
          backgroundImage:
              NetworkImage('${Server.urlImages}/${alumno.fotoNombre}'),
          backgroundColor: Colors.lightBlueAccent,
        ),
      );

  Widget _buildListaGrupos() => ExpansionPanelList.radio(
        children: alumnos!
            .map((AlumnoModel alumno) => ExpansionPanelRadio(
                  canTapOnHeader: true,
                  value: '${alumno.apellidos} ${alumno.nombres}',
                  headerBuilder: (context, isExpanded) => buildTile(alumno),
                  body: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            'Tardanzas: ${alumno.ausenciasTotal!['cant_tardanzas_entrada'].toString()} '),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              var res = await server.delete('/ausencias/destroy/${alumno.id}');

                              if (res.statusCode < 300) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.lightBlueAccent,
                                    content: Text('Eliminada'),
                                  ),
                                );
                                setState(() {
                                  alumno.ausenciasTotal!['cant_tardanzas_entrada'] = alumno.ausenciasTotal!['cant_tardanzas_entrada']! -1;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                        Text('Error eliminado tardanza')));
                              }
                            } catch (err) {
                              print(err);
                            }
                          },
                          style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  Colors.green)),
                          child: Text('-'),
                        ),
                        ElevatedButton(
                          child: Text('+'),
                          onPressed: () async {
                            try {
                              var res = await server.post('/ausencias/store', {
                                'alumno_id': alumno.id,
                                'entrada': 1,
                                'tipo': 'tardanza',
                              });

                              if (res.statusCode < 300) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.lightBlueAccent,
                                    content: Text('Creada'),
                                  ),
                                );
                                setState(() {
                                  alumno.ausenciasTotal!['cant_tardanzas_entrada'] = alumno.ausenciasTotal!['cant_tardanzas_entrada']! +1;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error creando tardanza')));
                              }
                            } catch (err) {
                              print(err);
                            }
                          },
                        ),
                      ],
                    ),
                    Text('Ausencias: '),
                  ]),
                ))
            .toList(),
      );
}
