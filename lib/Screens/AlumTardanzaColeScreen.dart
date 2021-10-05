import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
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
  DateTime? today; // la cambio en init

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);

    traerGrupo();
  }

  void traerGrupo() {
    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? grupoString = preferences.getString('grupoSelected');

      if (grupoString != null) {
        setState(() {
          grupo = GrupoModel.fromRawJson(grupoString);
        });
      } else {
        Navigator.pushNamed(context, '/panel');
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('**** En build');

    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: grupo == null
          ? Text('Esperando alumnos en build...')
          : _buildFutureBuilder(),
      drawer: DrawPanel(),
    );
  }

  FutureBuilder<List<AlumnoModel>> _buildFutureBuilder() {
    return FutureBuilder<List<AlumnoModel>>(
        future: traerAlumnosModel(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          print('Buildereando el future');
          if (snapshot.hasData) {
            return SingleChildScrollView(
                child: alumnos != null
                    ? _buildListaGrupos()
                    : Text('Esperando alumnos...'));
          } else if (snapshot.hasError) {
            return Text('Ocurrió un error trayendo los alumnos con tardanzas.');
          } else {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        });
  }

  Future<List<AlumnoModel>> traerAlumnosModel() async {
    var argum = {'grupo_id': '${grupo!.id}', 'con_grupos': false};

    var response = await server.put('/asistencias/detailed', argum);
    final List alumnosList = jsonDecode(response.body)['alumnos'];
    print('Trajo datos');
    List<AlumnoModel> alumnosTemp =
        alumnosList.map((e) => AlumnoModel.fromJson(e)).toList();

    alumnos = alumnosTemp;

    print('alumnos: ${alumnos?.length}');
    return alumnos as List<AlumnoModel>;
  }

  Widget buildTile(AlumnoModel alumno, DateTime today) => ListTile(
        dense: false,
        title: Text(
          '${alumno.apellidos} ${alumno.nombres}',
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Tardanzas: ${alumno.tardanzasEntrada!.length}'),
        leading: CircleAvatar(
          backgroundImage:
              NetworkImage('${Server.urlImages}/${alumno.fotoNombre}'),
          backgroundColor: Colors.lightBlueAccent,
        ),
      );

  Widget _buildListaGrupos() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    return ExpansionPanelList.radio(
      children: alumnos!
          .map((AlumnoModel alumno) => ExpansionPanelRadio(
                backgroundColor:
                    alumno.tieneTardanzaHoy(today) ? Colors.pinkAccent : null,
                canTapOnHeader: true,
                value: '${alumno.apellidos} ${alumno.nombres}',
                headerBuilder: (context, isExpanded) =>
                    buildTile(alumno, today),
                body: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tardanzas: ${alumno.ausenciasTotal!['cant_tardanzas_entrada'].toString()} ',
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (alumno.tardanzasEntrada != null) {
                            int cantTar = alumno.tardanzasEntrada!.length;
                            if (cantTar > 0) {
                              AsistenciaModel tardanzaTemp;
                              tardanzaTemp =
                                  alumno.tardanzasEntrada![cantTar - 1];

                              try {
                                var res = await server.delete(
                                    '/ausencias/destroy/${tardanzaTemp.id}');

                                if (res.statusCode < 300) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.lightBlueAccent,
                                      content: Text('Eliminada'),
                                    ),
                                  );
                                  setState(() {
                                    print(
                                        'Antes ${alumno.tardanzasEntrada!.length}');
                                    alumno.ausenciasTotal![
                                            'cant_tardanzas_entrada'] =
                                        alumno.ausenciasTotal![
                                                'cant_tardanzas_entrada']! -
                                            1;
                                    alumno.tardanzasEntrada!
                                        .remove(tardanzaTemp);
                                  });
                                } else {
                                  print(alumno.tardanzasEntrada);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error eliminado tardanza')));
                                }
                              } catch (err) {
                                print(err);
                              }
                            }
                          }
                        },
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all<Color>(Colors.green)),
                        child: Text(
                          '-',
                          style: TextStyle(fontSize: 30),
                        ),
                      ),
                      ElevatedButton(
                        child: Text('+', style: TextStyle(fontSize: 30)),
                        onPressed: () async {
                          try {
                            var now = DateTime.now();
                            // String fecha_hora = '${now.year}-$now.month-${now.day} ${now.hours}:${now.minutes}:${now.seconds}';

                            var res = await server.post('/ausencias/store', {
                              'alumno_id': alumno.id,
                              'entrada': 1,
                              'tipo': 'tardanza',
                              'fecha_hora': now.toString(),
                            });

                            if (res.statusCode < 300) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.lightBlueAccent,
                                  content: Text('Creada'),
                                ),
                              );

                              print(res.body);
                              AsistenciaModel egragada =
                                  AsistenciaModel.fromJson(
                                      jsonDecode(res.body));

                              setState(() {
                                alumno.ausenciasTotal![
                                        'cant_tardanzas_entrada'] =
                                    alumno.ausenciasTotal![
                                            'cant_tardanzas_entrada']! +
                                        1;
                                if (alumno.tardanzasEntrada == null) {
                                  alumno.tardanzasEntrada = [];
                                }
                                alumno.tardanzasEntrada!.add(egragada);
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error creando tardanza')));
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
}
