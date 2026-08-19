import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/YearModel.dart';

/// Los datos que hacen falta para abrir la pantalla.
class TardanzasAlumnoArgs {
  final int alumnoId;
  final String nombre;
  final int grupoId;

  TardanzasAlumnoArgs({
    required this.alumnoId,
    required this.nombre,
    required this.grupoId,
  });
}

/// El histórico de tardanzas de un alumno, por periodo, del año que se elija.
///
/// Se arma con tres endpoints que ya existen, los mismos que usa la pantalla de
/// comportamiento del front web:
///
///   GET /years               los años y sus periodos, para el selector
///   GET /contratos           los docentes, para pasar de created_by a un nombre
///   PUT /disciplina/alumnos  acepta year_id y devuelve tardanzas_per1..perN
///
/// De momento solo se consulta: aquí no se borra ninguna tardanza.
class TardanzasAlumnoScreen extends StatefulWidget {
  final TardanzasAlumnoArgs args;

  const TardanzasAlumnoScreen({Key? key, required this.args}) : super(key: key);

  @override
  _TardanzasAlumnoScreenState createState() => _TardanzasAlumnoScreenState();
}

class _TardanzasAlumnoScreenState extends State<TardanzasAlumnoScreen> {
  final Server server = Server();

  List<YearModel> years = [];
  YearModel? yearElegido;

  /// created_by -> nombre del docente.
  Map<int, String> docentes = {};

  /// número de periodo -> tardanzas de ese periodo.
  Map<int, List<AsistenciaModel>> porPeriodo = {};

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargarTodo() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resYears = await server.get('/years');
      final crudos = jsonDecode(resYears.body) as List;

      years = crudos
          .map((y) => YearModel.fromJson(y as Map<String, dynamic>))
          .where((y) => y.periodos.isNotEmpty)
          .toList()
        ..sort((a, b) => b.year.compareTo(a.year));

      if (years.isEmpty) {
        setState(() {
          cargando = false;
          error = 'El colegio no tiene años con periodos.';
        });
        return;
      }

      yearElegido = years.firstWhere(
        (y) => y.actual,
        orElse: () => years.first,
      );

      await _cargarDocentes();
      await _cargarYear();
    } catch (err) {
      setState(() {
        cargando = false;
        error = 'No se pudieron cargar los datos.\n$err';
      });
    }
  }

  /// El nombre del docente no viene con la tardanza, solo su created_by.
  ///
  /// Si falla, la tabla sigue sirviendo: se muestra el número de usuario.
  Future<void> _cargarDocentes() async {
    try {
      final res = await server.get('/contratos');
      final lista = jsonDecode(res.body) as List;

      final mapa = <int, String>{};
      for (final c in lista) {
        final userId = c['user_id'];
        final nombre = c['nombre_completo'];
        if (userId != null && nombre != null) {
          mapa[int.parse('$userId')] = '$nombre'.trim();
        }
      }
      docentes = mapa;
    } catch (err) {
      print('No se pudo traer los docentes: $err');
    }
  }

  Future<void> _cargarYear() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final res = await server.put('/disciplina/alumnos', {
        'grupo_id': widget.args.grupoId,
        'year_id': yearElegido!.id,
      });

      final alumnos = (jsonDecode(res.body)['alumnos'] as List?) ?? [];

      Map<String, dynamic>? alumno;
      for (final a in alumnos) {
        if ('${a['alumno_id']}' == '${widget.args.alumnoId}') {
          alumno = a as Map<String, dynamic>;
          break;
        }
      }

      final resultado = <int, List<AsistenciaModel>>{};
      for (final periodo in yearElegido!.periodos) {
        final crudas = alumno == null
            ? const []
            : (alumno['tardanzas_per${periodo.numero}'] as List?) ?? const [];

        final tardanzas = crudas
            .map((t) => AsistenciaModel.fromJson(t as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => _orden(a).compareTo(_orden(b)));

        resultado[periodo.numero] = tardanzas;
      }

      setState(() {
        porPeriodo = resultado;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las tardanzas del año.\n$err';
      });
    }
  }

  DateTime _orden(AsistenciaModel t) => t.fecha ?? t.createdAt ?? DateTime(1900);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.nombre)),
      body: Column(
        children: [
          _buildSelectorYear(),
          Divider(height: 1),
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  Widget _buildSelectorYear() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text('Año:', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButton<YearModel>(
              isExpanded: true,
              value: yearElegido,
              items: years
                  .map((y) => DropdownMenuItem<YearModel>(
                        value: y,
                        child: Text(y.actual ? '${y.year} (actual)' : y.year),
                      ))
                  .toList(),
              onChanged: years.isEmpty
                  ? null
                  : (nuevo) {
                      if (nuevo == null || nuevo == yearElegido) return;
                      setState(() => yearElegido = nuevo);
                      _cargarYear();
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (cargando) return Center(child: CircularProgressIndicator());

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
            SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarTodo,
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final total = porPeriodo.values.fold<int>(0, (s, l) => s + l.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            total == 0
                ? 'Sin tardanzas en ${yearElegido!.year}.'
                : '$total ${total == 1 ? "tardanza" : "tardanzas"} en ${yearElegido!.year}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        ...yearElegido!.periodos.map(_buildPeriodo),
      ],
    );
  }

  Widget _buildPeriodo(PeriodoModel periodo) {
    final tardanzas = porPeriodo[periodo.numero] ?? const <AsistenciaModel>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: tardanzas.isNotEmpty,
        title: Text(
          'Periodo ${periodo.numero}',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          tardanzas.isEmpty
              ? 'Sin tardanzas'
              : '${tardanzas.length} ${tardanzas.length == 1 ? "tardanza" : "tardanzas"}',
        ),
        children: [
          if (tardanzas.isNotEmpty) _buildTabla(tardanzas),
        ],
      ),
    );
  }

  Widget _buildTabla(List<AsistenciaModel> tardanzas) {
    // La tabla se desborda a lo ancho en un móvil: se desplaza en su propia
    // caja en vez de romper el resto de la pantalla.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('Día')),
          DataColumn(label: Text('Docente')),
          DataColumn(label: Text('Registrada')),
        ],
        rows: tardanzas
            .map((t) => DataRow(cells: [
                  DataCell(Text(_dia(t.fecha))),
                  DataCell(Text(_docente(t.createdBy))),
                  DataCell(Text(_fechaHora(t.createdAt))),
                ]))
            .toList(),
      ),
    );
  }

  /// Cómo nombra la plataforma a quien puso la tardanza.
  ///
  /// El backend resuelve esto en el SQL de cada consulta, con un UNION: si el
  /// usuario es Profesor, su nombre de la tabla profesores; si no, su nombre de
  /// usuario. La tardanza solo trae created_by, así que la misma regla se
  /// aplica con lo que sí se puede consultar desde aquí:
  ///
  ///   - /contratos da el nombre de todos los profesores.
  ///   - Del que tiene la sesión abierta se sabe el nombre por /login, y suele
  ///     ser quien puso la mayoría de las que está mirando.
  ///
  /// Fuera de eso queda el número: ningún endpoint resuelve un usuario
  /// cualquiera por id, y sin tocar el backend no hay de dónde sacarlo.
  String _docente(int? createdBy) {
    if (createdBy == null) return 'Sin registrar';

    final profesor = docentes[createdBy];
    if (profesor != null && profesor.isNotEmpty) return profesor;

    if (AuthService.user.id == createdBy) {
      final propio = AuthService.user.nombreVisible;
      if (propio.isNotEmpty) return propio;
    }

    return 'Usuario $createdBy';
  }

  String _dia(DateTime? d) {
    if (d == null) return '—';
    return '${_dd(d.day)}/${_dd(d.month)}/${d.year}';
  }

  String _fechaHora(DateTime? d) {
    if (d == null) return '—';
    return '${_dd(d.day)}/${_dd(d.month)}/${d.year} ${_dd(d.hour)}:${_dd(d.minute)}';
  }

  String _dd(int n) => n.toString().padLeft(2, '0');
}
