import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Screens/TardanzasAlumnoScreen.dart';
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
  DateTime? _selectedDate;
  final _drawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    _selectedDate = today;

    traerGrupo();
  }

  Future<void> _selectDate() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
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

    // El mismo menú y la misma forma de abrirlo que en el inicio.
    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: _drawerController,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        appBar: AppBar(
          title: Text(grupo?.nombre ?? 'Alumnos'),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: grupo == null
            ? Text('Esperando alumnos en build...')
            : _buildFutureBuilder(),
      ),
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

  Widget buildTile(AlumnoModel alumno, DateTime dia) => ListTile(
        dense: false,
        title: Text(
          '${alumno.apellidos} ${alumno.nombres}',
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${alumno.tardanzasDelDia(dia).length} el ${_formatoFecha(dia)}'
          ' · ${alumno.ausenciasTotal!['cant_tardanzas_entrada'] ?? 0} en el periodo',
        ),
        leading: CircleAvatar(
          backgroundImage:
              NetworkImage('${Server.urlImages}/${alumno.fotoNombre}'),
          backgroundColor: Colors.lightBlueAccent,
        ),
      );

  Widget _buildListaGrupos() {
    final dia = _selectedDate ?? today!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Fecha: ${_formatoFecha(dia)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: _selectDate,
              ),
            ],
          ),
        ),
        ExpansionPanelList.radio(
          children: alumnos!
              .map((AlumnoModel alumno) => ExpansionPanelRadio(
                    // Resalta si tiene tardanza EL DÍA ELEGIDO. Antes se miraba
                    // created_at, así que cualquiera registrada hoy salía
                    // resaltada aunque fuera de otro día.
                    backgroundColor: alumno.tieneTardanzaEn(dia)
                        ? Colors.pinkAccent
                        : null,
                    canTapOnHeader: true,
                    value: '${alumno.apellidos} ${alumno.nombres}',
                    headerBuilder: (context, isExpanded) =>
                        buildTile(alumno, dia),
                    body: _buildCuerpoAlumno(alumno, dia),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// El cuerpo del panel del alumno.
  ///
  /// Todo lo que muestra y lo que hacen los botones va referido al día elegido
  /// arriba. Antes el contador era el total del periodo y el botón de quitar
  /// borraba la última tardanza de la lista, fuera del día que fuera.
  Widget _buildCuerpoAlumno(AlumnoModel alumno, DateTime dia) {
    final delDia = alumno.tardanzasDelDia(dia).length;
    final total = alumno.ausenciasTotal!['cant_tardanzas_entrada'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Text(
            'Tardanzas del ${_formatoFecha(dia)}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _botonContador(
                icono: Icons.remove,
                color: Colors.redAccent,
                onPressed: () => _quitarTardanza(alumno, dia),
              ),
              Container(
                width: 80,
                alignment: Alignment.center,
                child: Text(
                  '$delDia',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                ),
              ),
              _botonContador(
                icono: Icons.add,
                color: Colors.green,
                onPressed: () => _agregarTardanza(alumno, dia),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _verAsistenciaClases(alumno),
            icon: Icon(Icons.class_outlined, size: 18),
            label: Text('Asistencia a clases'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(color: kPrimaryColor),
              foregroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _verHistorico(alumno),
            icon: Icon(Icons.history, size: 18),
            label: Text('Total del periodo: $total'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(color: kPrimaryColor),
              foregroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonContador({
    required IconData icono,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(18),
      ),
      child: Icon(icono, size: 26),
    );
  }

  Future<void> _agregarTardanza(AlumnoModel alumno, DateTime dia) async {
    try {
      final res = await server.post('/ausencias/store', {
        'alumno_id': alumno.id,
        'entrada': 1,
        'tipo': 'tardanza',
        'fecha_hora': _fechaParaServidor(dia),
      });

      if (res.statusCode >= 300) {
        _aviso('No se pudo registrar la tardanza (HTTP ${res.statusCode}).');
        return;
      }

      final creada = AsistenciaModel.fromJson(jsonDecode(res.body));

      setState(() {
        alumno.tardanzasEntrada ??= [];
        alumno.tardanzasEntrada!.add(creada);
        alumno.ausenciasTotal!['cant_tardanzas_entrada'] = total(alumno) + 1;
      });

      _aviso('Tardanza registrada el ${_formatoFecha(dia)}.', error: false);
    } catch (err) {
      _aviso('Error registrando la tardanza: $err');
    }
  }

  Future<void> _quitarTardanza(AlumnoModel alumno, DateTime dia) async {
    final delDia = alumno.tardanzasDelDia(dia);

    if (delDia.isEmpty) {
      _aviso('No hay tardanzas del ${_formatoFecha(dia)} para quitar.');
      return;
    }

    final tardanza = delDia.last;

    try {
      final res = await server.delete('/ausencias/destroy/${tardanza.id}');

      if (res.statusCode >= 300) {
        _aviso('No se pudo eliminar la tardanza (HTTP ${res.statusCode}).');
        return;
      }

      setState(() {
        alumno.tardanzasEntrada!.remove(tardanza);
        alumno.ausenciasTotal!['cant_tardanzas_entrada'] = total(alumno) - 1;
      });

      _aviso('Tardanza del ${_formatoFecha(dia)} eliminada.', error: false);
    } catch (err) {
      _aviso('Error eliminando la tardanza: $err');
    }
  }

  void _verAsistenciaClases(AlumnoModel alumno) {
    Navigator.pushNamed(
      context,
      '/asistencia-clase',
      arguments: AsistenciaClaseArgs(
        alumnoId: alumno.id,
        nombre: '${alumno.apellidos} ${alumno.nombres}',
        grupoId: grupo!.id,
      ),
    );
  }

  void _verHistorico(AlumnoModel alumno) {
    Navigator.pushNamed(
      context,
      '/tardanzas-alumno',
      arguments: TardanzasAlumnoArgs(
        alumnoId: alumno.id,
        nombre: '${alumno.apellidos} ${alumno.nombres}',
        grupoId: grupo!.id,
      ),
    );
  }

  int total(AlumnoModel alumno) =>
      alumno.ausenciasTotal!['cant_tardanzas_entrada'] ?? 0;

  String _formatoFecha(DateTime d) =>
      '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}/${d.year}';

  String _dosDigitos(int n) => n.toString().padLeft(2, '0');

  /// La fecha tal como la espera la columna datetime de MySQL.
  ///
  /// Con la hora real cuando el día elegido es hoy —en una tardanza a la
  /// entrada la hora es el dato— y a las 00:00 cuando se registra una de un día
  /// pasado, donde no hay hora que reconstruir.
  String _fechaParaServidor(DateTime dia) {
    final ahora = DateTime.now();
    final esHoy =
        dia.year == ahora.year && dia.month == ahora.month && dia.day == ahora.day;
    final momento = esHoy ? ahora : DateTime(dia.year, dia.month, dia.day);

    return '${momento.year}-${_dosDigitos(momento.month)}-${_dosDigitos(momento.day)}'
        ' ${_dosDigitos(momento.hour)}:${_dosDigitos(momento.minute)}'
        ':${_dosDigitos(momento.second)}';
  }

  void _aviso(String mensaje, {bool error = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? Colors.red.shade700 : Colors.lightBlueAccent,
        ),
      );
  }
}
