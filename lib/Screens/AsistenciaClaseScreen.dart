import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/constantes.dart';

class AsistenciaClaseArgs {
  final int alumnoId;
  final String nombre;
  final int grupoId;

  AsistenciaClaseArgs({
    required this.alumnoId,
    required this.nombre,
    required this.grupoId,
  });
}

/// Asistencia a clases: las ausencias y tardanzas de un alumno en una materia.
///
/// Es lo que hace el panel de "Clases de hoy" del front web, pero para un solo
/// alumno. Se arma con endpoints que ya existen:
///
///   GET    /asignaturas/listasignaturas[/{profesor_id}]  las materias del docente
///   GET    /asignaturas                                  para saber qué docentes
///                                                        dan clase al grupo
///   PUT    /notas/subunidad {grupo_id, asignatura_id}    alumnos con sus fallas
///   POST   /ausencias/agregar-ausencia {now, alumno_id, asignatura_id}
///   POST   /ausencias/agregar-tardanza {now, alumno_id, asignatura_id}
///   DELETE /ausencias/destroy/{id}
///
/// Un docente ve directamente sus materias. Cualquier otro usuario elige antes
/// de qué docente, porque no tiene materias propias.
class AsistenciaClaseScreen extends StatefulWidget {
  final AsistenciaClaseArgs args;

  const AsistenciaClaseScreen({Key? key, required this.args}) : super(key: key);

  @override
  _AsistenciaClaseScreenState createState() => _AsistenciaClaseScreenState();
}

class _AsistenciaClaseScreenState extends State<AsistenciaClaseScreen> {
  final Server server = Server();

  bool get esDocente => AuthService.user.tipo == 'Profesor';

  List<DocenteModel> docentes = [];
  DocenteModel? docenteElegido;

  List<AsignaturaModel> asignaturas = [];
  AsignaturaModel? asignaturaElegida;

  List<AsistenciaModel> ausencias = [];
  List<AsistenciaModel> tardanzas = [];

  bool cargando = true;
  bool guardando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _arrancar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      if (esDocente) {
        await _cargarAsignaturas(null);
      } else {
        await _cargarDocentesDelGrupo();
      }
      setState(() => cargando = false);
    } catch (err) {
      setState(() {
        cargando = false;
        error = 'No se pudieron cargar los datos.\n$err';
      });
    }
  }

  /// Los docentes que dan clase al grupo del alumno.
  ///
  /// /asignaturas trae todas las del colegio con su profesor_id; se filtran por
  /// el grupo y los nombres salen de /contratos, que es de donde los saca el
  /// resto de la app.
  Future<void> _cargarDocentesDelGrupo() async {
    final resAsig = await server.get('/asignaturas');
    final todas = jsonDecode(resAsig.body) as List;

    final idsDelGrupo = <int>{};
    for (final a in todas) {
      final grupo = int.tryParse('${a['grupo_id']}');
      final profe = int.tryParse('${a['profesor_id']}');
      if (grupo == widget.args.grupoId && profe != null) idsDelGrupo.add(profe);
    }

    final resContratos = await server.get('/contratos');
    final contratos = jsonDecode(resContratos.body) as List;

    final encontrados = <DocenteModel>[];
    for (final c in contratos) {
      final profe = int.tryParse('${c['profesor_id']}');
      if (profe != null && idsDelGrupo.contains(profe)) {
        encontrados.add(DocenteModel(
          profesorId: profe,
          nombre: '${c['nombre_completo'] ?? 'Docente $profe'}'.trim(),
        ));
      }
    }

    encontrados.sort((a, b) => a.nombre.compareTo(b.nombre));

    setState(() {
      docentes = encontrados;
      if (encontrados.isEmpty) {
        error = 'Ningún docente tiene asignaturas en este grupo.';
      }
    });
  }

  Future<void> _cargarAsignaturas(int? profesorId) async {
    final ruta = profesorId == null
        ? '/asignaturas/listasignaturas'
        : '/asignaturas/listasignaturas/$profesorId';

    final res = await server.get(ruta);
    final cuerpo = jsonDecode(res.body);

    final crudas = (cuerpo is Map ? cuerpo['asignaturas'] : cuerpo) as List? ?? [];

    // Solo las del grupo del alumno: un docente da clase a varios grupos.
    final propias = crudas
        .map((a) => AsignaturaModel.fromJson(a as Map<String, dynamic>))
        .where((a) => a.grupoId == widget.args.grupoId)
        .toList();

    setState(() {
      asignaturas = propias;
      asignaturaElegida = null;
      ausencias = [];
      tardanzas = [];
      error = propias.isEmpty
          ? 'Este docente no tiene asignaturas en el grupo del alumno.'
          : null;
    });
  }

  Future<void> _cargarFallas(AsignaturaModel asignatura) async {
    setState(() {
      cargando = true;
      error = null;
      asignaturaElegida = asignatura;
    });

    try {
      final res = await server.put('/notas/subunidad', {
        'grupo_id': asignatura.grupoId,
        'asignatura_id': asignatura.id,
      });

      final alumnos = (jsonDecode(res.body)['alumnos'] as List?) ?? [];

      Map<String, dynamic>? alumno;
      for (final a in alumnos) {
        if ('${a['alumno_id']}' == '${widget.args.alumnoId}') {
          alumno = a as Map<String, dynamic>;
          break;
        }
      }

      setState(() {
        ausencias = _lista(alumno, 'ausencias');
        tardanzas = _lista(alumno, 'tardanzas');
        cargando = false;
      });
    } catch (err) {
      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las fallas de la materia.\n$err';
      });
    }
  }

  List<AsistenciaModel> _lista(Map<String, dynamic>? alumno, String clave) {
    final crudas = alumno == null ? const [] : (alumno[clave] as List?) ?? const [];
    return crudas
        .map((t) => AsistenciaModel.fromJson(t as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => (b.fecha ?? DateTime(1900)).compareTo(a.fecha ?? DateTime(1900)));
  }

  Future<void> _agregar(String tipo) async {
    if (asignaturaElegida == null || guardando) return;

    setState(() => guardando = true);

    try {
      final ruta = tipo == 'tardanza'
          ? '/ausencias/agregar-tardanza'
          : '/ausencias/agregar-ausencia';

      final res = await server.post(ruta, {
        'alumno_id': widget.args.alumnoId,
        'asignatura_id': asignaturaElegida!.id,
        // La hora real: en una clase importa a qué hora llegó.
        'now': _ahoraParaServidor(),
        'entrada': 0,
      });

      if (res.statusCode >= 300) {
        _aviso('No se pudo registrar (HTTP ${res.statusCode}).');
        return;
      }

      await _cargarFallas(asignaturaElegida!);
      _aviso('${tipo == 'tardanza' ? 'Tardanza' : 'Ausencia'} registrada.',
          error: false);
    } catch (err) {
      _aviso('Error registrando: $err');
    } finally {
      setState(() => guardando = false);
    }
  }

  Future<void> _eliminar(AsistenciaModel falla) async {
    if (guardando) return;
    setState(() => guardando = true);

    try {
      final res = await server.delete('/ausencias/destroy/${falla.id}');

      if (res.statusCode >= 300) {
        _aviso('No se pudo eliminar (HTTP ${res.statusCode}).');
        return;
      }

      await _cargarFallas(asignaturaElegida!);
      _aviso('Eliminada.', error: false);
    } catch (err) {
      _aviso('Error eliminando: $err');
    } finally {
      setState(() => guardando = false);
    }
  }

  String _ahoraParaServidor() {
    final d = DateTime.now();
    return '${d.year}-${_dd(d.month)}-${_dd(d.day)} '
        '${_dd(d.hour)}:${_dd(d.minute)}:${_dd(d.second)}';
  }

  String _dd(int n) => n.toString().padLeft(2, '0');

  String _fecha(DateTime? d) => d == null
      ? '—'
      : '${_dd(d.day)}/${_dd(d.month)}/${d.year} ${_dd(d.hour)}:${_dd(d.minute)}';

  void _aviso(String mensaje, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red.shade700 : Colors.lightBlueAccent,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Asistencia a clases')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.args.nombre,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!esDocente) _buildSelectorDocente(),
          _buildSelectorAsignatura(),
          Divider(height: 1),
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  Widget _buildSelectorDocente() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text('Docente:', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButton<DocenteModel>(
              isExpanded: true,
              value: docenteElegido,
              hint: Text('Elige el docente'),
              items: docentes
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.nombre)))
                  .toList(),
              onChanged: (nuevo) {
                if (nuevo == null) return;
                setState(() => docenteElegido = nuevo);
                _cargarAsignaturas(nuevo.profesorId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorAsignatura() {
    if (asignaturas.isEmpty) return SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: asignaturas.map((a) {
          final activa = asignaturaElegida?.id == a.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${a.abrevGrupo}. ${a.aliasMateria}'),
              tooltip: a.materia,
              selected: activa,
              onSelected: (_) => _cargarFallas(a),
            ),
          );
        }).toList(),
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
            ElevatedButton(onPressed: _arrancar, child: Text('Reintentar')),
          ],
        ),
      );
    }

    if (asignaturaElegida == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            esDocente
                ? 'Elige una de tus materias.'
                : 'Elige el docente y luego la materia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          asignaturaElegida!.materia,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildContador('Ausencias', ausencias.length, Colors.redAccent,
                () => _agregar('ausencia')),
            _buildContador('Tardanzas', tardanzas.length, Colors.orange,
                () => _agregar('tardanza')),
          ],
        ),
        const SizedBox(height: 24),
        if (ausencias.isEmpty && tardanzas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sin ausencias ni tardanzas en esta materia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ...ausencias.map((f) => _buildFalla(f, 'Ausencia', Colors.redAccent)),
        ...tardanzas.map((f) => _buildFalla(f, 'Tardanza', Colors.orange)),
      ],
    );
  }

  Widget _buildContador(
      String titulo, int cantidad, Color color, VoidCallback onAgregar) {
    return Column(
      children: [
        Text(titulo, style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('$cantidad',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: guardando ? null : onAgregar,
          icon: Icon(Icons.add, size: 18),
          label: Text('Agregar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFalla(AsistenciaModel falla, String etiqueta, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(
            etiqueta == 'Ausencia' ? Icons.close : Icons.access_time,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(etiqueta),
        subtitle: Text(_fecha(falla.fecha)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: kPrimaryColor),
          onPressed: guardando ? null : () => _eliminar(falla),
        ),
      ),
    );
  }
}
