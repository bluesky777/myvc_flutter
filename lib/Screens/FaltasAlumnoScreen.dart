import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/SelectorDia.dart';
import 'package:myvc_flutter/constantes.dart';

/// Los datos que hacen falta para abrir la pantalla.
class FaltasAlumnoArgs {
  final int alumnoId;
  final String nombre;
  final int grupoId;

  /// La foto del alumno, ya cargada por la pantalla anterior.
  final String? fotoNombre;

  FaltasAlumnoArgs({
    required this.alumnoId,
    required this.nombre,
    required this.grupoId,
    this.fotoNombre,
  });
}

/// El histórico de faltas a la institución de un alumno, por periodo, del año
/// que se elija: las tardanzas y las ausencias, y el día de cada una se puede
/// corregir aquí mismo.
///
/// Se arma con endpoints que ya existen, los mismos que usa la pantalla de
/// comportamiento del front web:
///
///   GET /years                                los años y sus periodos
///   GET /contratos                            para pasar de created_by a un nombre
///   PUT /disciplina/alumnos                   acepta year_id y devuelve tardanzas_per1..perN
///   PUT /ausencias/guardar-cambios-ausencia   corrige el día de una falta
///
/// Ojo con `tardanzas_perN`: el nombre engaña. Esa consulta del backend filtra
/// por entrada=1 —falta a la institución— pero no por tipo, así que ahí vienen
/// mezcladas las tardanzas y las ausencias. Se separan aquí por la columna
/// `tipo`, que sí viene en cada fila; antes de hacerlo, las ausencias se
/// mostraban como si fueran tardanzas.
///
/// Aquí no se borra ninguna falta: eso se hace desde la lista del grupo.
class FaltasAlumnoScreen extends StatefulWidget {
  final FaltasAlumnoArgs args;

  const FaltasAlumnoScreen({Key? key, required this.args}) : super(key: key);

  @override
  _FaltasAlumnoScreenState createState() => _FaltasAlumnoScreenState();
}

class _FaltasAlumnoScreenState extends State<FaltasAlumnoScreen> {
  final Server server = Server();

  List<YearModel> years = [];
  YearModel? yearElegido;

  /// created_by -> nombre del docente.
  Map<int, String> docentes = {};

  /// número de periodo -> las faltas de ese periodo, de los dos tipos.
  Map<int, List<AsistenciaModel>> porPeriodo = {};

  bool cargando = true;
  bool guardando = false;
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

  /// El nombre del docente no viene con la falta, solo su created_by.
  ///
  /// Si falla, la pantalla sigue sirviendo: se muestra el número de usuario.
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

        final faltas = crudas
            .map((t) => AsistenciaModel.fromJson(t as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => _orden(a).compareTo(_orden(b)));

        resultado[periodo.numero] = faltas;
      }

      setState(() {
        porPeriodo = resultado;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las faltas del año.\n$err';
      });
    }
  }

  DateTime _orden(AsistenciaModel t) => t.fecha ?? t.createdAt ?? DateTime(1900);

  Future<void> _cambiarFechaDe(AsistenciaModel falta) async {
    if (guardando) return;

    final nueva = await pedirDiaDeFalta(context, falta.fecha);
    if (nueva == null) return;

    setState(() => guardando = true);

    try {
      final problema = await cambiarFechaDeFalta(
        server: server,
        faltaId: falta.id,
        nueva: nueva,
      );

      if (problema != null) {
        _aviso(problema);
        return;
      }

      // El periodo lo decide el backend por su cuenta: si la fecha nueva cae en
      // otro, la falta se mueve de sitio, así que se recarga el año entero.
      await _cargarYear();
      _aviso('Ahora consta del ${formatoDiaYHora(nueva)}.', error: false);
    } finally {
      setState(() => guardando = false);
    }
  }

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
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarPersona(
              nombre: widget.args.nombre,
              fotoNombre: widget.args.fotoNombre,
              radio: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.args.nombre,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
              onChanged: years.isEmpty || guardando
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

    final todas = porPeriodo.values.expand((l) => l).toList();
    final tardanzas = soloDelTipo(todas, TipoFalta.tardanza).length;
    final ausencias = soloDelTipo(todas, TipoFalta.ausencia).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tardanzas == 0 && ausencias == 0
                ? 'Sin faltas a la institución en ${yearElegido!.year}.'
                : '${TipoFalta.tardanza.contar(tardanzas)}'
                    ' · ${TipoFalta.ausencia.contar(ausencias)}'
                    ' en ${yearElegido!.year}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        ...yearElegido!.periodos.map(_buildPeriodo),
      ],
    );
  }

  Widget _buildPeriodo(PeriodoModel periodo) {
    final faltas = porPeriodo[periodo.numero] ?? const <AsistenciaModel>[];
    final tardanzas = soloDelTipo(faltas, TipoFalta.tardanza);
    final ausencias = soloDelTipo(faltas, TipoFalta.ausencia);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: faltas.isNotEmpty,
        title: Text(
          'Periodo ${periodo.numero}',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          faltas.isEmpty
              ? 'Sin faltas'
              : '${TipoFalta.tardanza.contar(tardanzas.length)}'
                  ' · ${TipoFalta.ausencia.contar(ausencias.length)}',
        ),
        children: [
          _buildBloque(TipoFalta.tardanza, tardanzas),
          _buildBloque(TipoFalta.ausencia, ausencias),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Las faltas de un tipo dentro de un periodo, una ficha por falta.
  Widget _buildBloque(TipoFalta tipo, List<AsistenciaModel> faltas) {
    if (faltas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _color(tipo),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tipo.titulo} (${faltas.length})',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          ...faltas.map((f) => _buildFicha(tipo, f)),
        ],
      ),
    );
  }

  /// Una falta, con su día editable.
  ///
  /// El día se presenta como un campo y no como texto: es el dato que se viene
  /// a corregir aquí, y tocarlo abre el calendario.
  Widget _buildFicha(TipoFalta tipo, AsistenciaModel falta) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Día y hora de la ${tipo.singular}',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  // Con la hora siempre, aunque sea 00:00: aquí es un campo que
                  // se edita, y un campo tiene que enseñar lo que guarda.
                  Text(
                    formatoDiaYHora(falta.fecha),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Puesta por ${_docente(falta.createdBy)}'
                    '${falta.createdAt == null ? '' : ' · registrada el ${formatoDiaYHora(falta.createdAt)}'}',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: guardando ? null : () => _cambiarFechaDe(falta),
              icon: Icon(Icons.edit_calendar_outlined, size: 18),
              label: Text('Cambiar'),
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(TipoFalta tipo) =>
      tipo == TipoFalta.tardanza ? kColorTardanza : kColorAusencia;

  /// Cómo nombra la plataforma a quien puso la falta.
  ///
  /// El backend resuelve esto en el SQL de cada consulta, con un UNION: si el
  /// usuario es Profesor, su nombre de la tabla profesores; si no, su nombre de
  /// usuario. La falta solo trae created_by, así que la misma regla se aplica
  /// con lo que sí se puede consultar desde aquí:
  ///
  ///   - /contratos da el nombre de todos los profesores.
  ///   - Del que tiene la sesión abierta se sabe el nombre por /login, y suele
  ///     ser quien puso la mayoría de las que está mirando.
  ///
  /// Fuera de eso queda el número: ningún endpoint resuelve un usuario
  /// cualquiera por id, y sin tocar el backend no hay de dónde sacarlo.
  String _docente(int? createdBy) {
    if (createdBy == null) return 'sin registrar';

    final profesor = docentes[createdBy];
    if (profesor != null && profesor.isNotEmpty) return profesor;

    if (AuthService.user.id == createdBy) {
      final propio = AuthService.user.nombreVisible;
      if (propio.isNotEmpty) return propio;
    }

    return 'Usuario $createdBy';
  }

}
