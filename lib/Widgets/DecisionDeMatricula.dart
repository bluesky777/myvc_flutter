import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// La decisión de la matrícula, en la última estación del recorrido: ahí el
/// rector matricula o deja como asistente (Joseth, 14 oct 2026; en la app, 16
/// oct). En cualquier otra estación no pinta nada.
///
/// El grupo es el que el alumno ya tiene en el año de la campaña
/// (`GET estaciones/alumnos`); si no tiene, hay que prematricularlo antes en
/// la web. Cambiar de grupo también se queda en la web.
class DecisionDeMatricula extends StatefulWidget {
  const DecisionDeMatricula({
    super.key,
    required this.estacion,
    required this.persona,
    this.servidor,
  });

  final Estacion estacion;
  final PersonaEnCola persona;
  final Server? servidor;

  @override
  State<DecisionDeMatricula> createState() => _DecisionDeMatriculaState();
}

class _DecisionDeMatriculaState extends State<DecisionDeMatricula> {
  late final Server server = widget.servidor ?? Server();

  bool esLaUltima = false;
  int? anio;
  int? yearId;
  MatriculaEnLaCampana? matricula;
  bool cargado = false;
  bool decidiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final recorrido = await traerLasEstacionesDelColegio(server);
      final todas = recorrido.estaciones;
      final ultima = todas.isEmpty
          ? null
          : todas.map((e) => e.nro).reduce((a, b) => a > b ? a : b);
      if (ultima != widget.estacion.nro) return;

      final matriculas = await traerLasMatriculasDeLaCampana(server);
      if (!mounted) return;
      setState(() {
        esLaUltima = true;
        anio = recorrido.anio;
        yearId = recorrido.yearId;
        matricula = matriculas[widget.persona.id];
        cargado = true;
      });
    } catch (_) {
      // Sin esto la ficha sigue sirviendo para marcar: la decisión se toma en
      // la web.
    }
  }

  String get _grupoYAnio {
    final m = matricula!;
    return anio == null ? m.grupo : '${m.grupo} - $anio';
  }

  static String _estadoLegible(String estado) => switch (estado) {
        'MATR' => 'Matriculado',
        'ASIS' => 'Asistente',
        'PREM' || 'PREA' => 'Prematriculado',
        _ => estado,
      };

  Future<void> _matricular() async {
    final m = matricula;
    final year = yearId;
    if (m == null || year == null) return;

    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Matricular a ${widget.persona.nombres} en $_grupoYAnio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, matricular'),
          ),
        ],
      ),
    );
    if (si != true) return;

    await _decidir(
      () => matricularEnLaCampana(
        server,
        personaId: widget.persona.id,
        grupoId: m.grupoId,
        yearId: year,
      ),
      exito: 'Matriculado en $_grupoYAnio.',
      evento: 'estacion_matriculo',
    );
  }

  Future<void> _asistente() async {
    final m = matricula;
    if (m == null) return;
    await _decidir(
      () => asistenteEnLaCampana(
        server,
        personaId: widget.persona.id,
        grupoId: m.grupoId,
      ),
      exito: 'Queda como asistente.',
      evento: 'estacion_asistente',
    );
  }

  Future<void> _decidir(
    Future<String?> Function() escribir, {
    required String exito,
    required String evento,
  }) async {
    setState(() => decidiendo = true);
    final fallo = await escribir();
    if (!mounted) return;
    setState(() => decidiendo = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(fallo ?? exito)));
    if (fallo == null) {
      Analitica.evento(evento);
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!esLaUltima || !cargado) return const SizedBox.shrink();

    final m = matricula;
    final elAnio = anio == null ? 'el año que viene' : '$anio';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La matrícula de $elAnio',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PaletaEstaciones.tinta,
              ),
            ),
            const SizedBox(height: 6),
            if (m == null)
              Text(
                'No tiene grupo en $elAnio. Prematricúlalo primero en la '
                'plataforma web, en Prematrículas, y vuelve a abrir su ficha.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: PaletaEstaciones.tintaSuave,
                ),
              )
            else ...[
              Text(
                '$_grupoYAnio · ${_estadoLegible(m.estado)}',
                style: const TextStyle(color: PaletaEstaciones.tintaSuave),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: PaletaEstaciones.alturaDeBoton,
                child: FilledButton(
                  onPressed: decidiendo || m.estado == 'MATR' || yearId == null
                      ? null
                      : _matricular,
                  child: Text(m.estado == 'MATR'
                      ? 'Ya está matriculado en $_grupoYAnio'
                      : 'Matricular en $_grupoYAnio'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                      decidiendo || m.estado == 'ASIS' ? null : _asistente,
                  child: Text(m.estado == 'ASIS'
                      ? 'Ya es asistente'
                      : 'Poner como asistente'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
