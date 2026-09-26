import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Screens/MisRespuestasActividadScreen.dart';
import 'package:myvc_flutter/Utils/ElegirParaActividad.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/RecorridoActividad.dart';
import 'package:myvc_flutter/Widgets/CampoDePregunta.dart';

/// Responder una encuesta o un cuestionario, **una pregunta por pantalla**.
///
/// Maqueta `FlutterResponder`. Tres cosas que no se ven y mandan:
///
/// - **El recorrido se recalcula con cada respuesta** (contrato §2.5, en
///   `RecorridoActividad`): «Siguiente» va a la próxima pregunta *visible* con
///   lo respondido hasta ahora, y las barras de arriba son las visibles, así
///   que cambiar una respuesta puede alargar o acortar lo que queda.
/// - **El borrador vive en el servidor** (`act/{id}/borrador`), en los tres
///   niveles de anonimato: el anonimato es de presentación y todo se guarda
///   con identidad (Joseth, 26 sep). Se guarda un momento después de cada
///   cambio, al pasar de pregunta y al cerrar; reabrir la actividad sigue
///   donde se quedó, en este teléfono o en otro.
/// - **El servidor vuelve a evaluar al enviar**: si dice que falta una
///   obligatoria, se salta a ella.
class ResponderActividadScreen extends StatefulWidget {
  const ResponderActividadScreen({super.key, required this.fila});

  final ActEnBandeja fila;

  @override
  State<ResponderActividadScreen> createState() =>
      _ResponderActividadScreenState();
}

class _ResponderActividadScreenState extends State<ResponderActividadScreen> {
  final _server = Server();

  bool _cargando = true;
  String? _error;
  ActParaResponder? _act;

  final Map<int, RespuestaAct> _respuestas = {};

  /// La pregunta en pantalla; null con la portada de instrucciones delante.
  int? _actual;
  bool _enPortada = false;

  Timer? _espera;
  bool _sucio = false;
  bool _guardando = false;
  DateTime? _guardadoAt;
  String? _errorAlGuardar;

  bool _enviando = false;
  ResultadoDeEnvio? _resultado;

  int? get _alumnoId => widget.fila.porAlumno?.alumnoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    // Lo último escrito, si quedó algo sin guardar: se manda y no se espera.
    if (_sucio && _resultado == null) _guardarBorrador();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final act = await traerParaResponder(_server, widget.fila.id,
          alumnoId: _alumnoId);
      if (!mounted) return;

      for (final r in act.borrador) {
        _respuestas[r.preguntaId] = r;
      }
      final visibles = _visiblesDe(act);

      // Se sigue donde se quedó: la primera visible sin responder.
      int? primera;
      for (final id in visibles) {
        final p = act.preguntas.firstWhere((p) => p.id == id);
        if (!respuestaDada(p.tipo, _respuestas[id])) {
          primera = id;
          break;
        }
      }

      setState(() {
        _act = act;
        _cargando = false;
        _actual = primera ?? (visibles.isEmpty ? null : visibles.last);
        _enPortada = act.instrucciones.isNotEmpty && act.borrador.isEmpty;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$err';
      });
    }
  }

  List<int> _visiblesDe(ActParaResponder act) =>
      preguntasVisibles(act.preguntas, _respuestas);

  PreguntaAct? get _pregunta {
    final act = _act;
    if (act == null || _actual == null) return null;
    for (final p in act.preguntas) {
      if (p.id == _actual) return p;
    }
    return null;
  }

  void _alCambiar(RespuestaAct? r) {
    setState(() {
      if (r == null) {
        _respuestas.remove(_actual);
      } else {
        _respuestas[r.preguntaId] = r;
      }
      _sucio = true;
    });
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 1200), _guardarBorrador);
  }

  Future<void> _guardarBorrador() async {
    final act = _act;
    if (act == null || !_sucio || _guardando) return;
    _sucio = false;
    if (mounted) setState(() => _guardando = true);
    try {
      final hora = await guardarBorradorDeActividad(
          _server, act.id, _respuestas.values,
          alumnoId: _alumnoId);
      if (!mounted) return;
      setState(() {
        _guardadoAt = hora ?? DateTime.now();
        _errorAlGuardar = null;
      });
    } catch (err) {
      _sucio = true;
      if (mounted) setState(() => _errorAlGuardar = '$err');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _siguiente() {
    final act = _act!;
    if (_enPortada) {
      setState(() => _enPortada = false);
      return;
    }
    final visibles = _visiblesDe(act);
    final i = visibles.indexOf(_actual ?? -1);
    if (i < 0 || i == visibles.length - 1) {
      _enviar();
      return;
    }
    _espera?.cancel();
    _guardarBorrador();
    setState(() => _actual = visibles[i + 1]);
  }

  void _atras() {
    final visibles = _visiblesDe(_act!);
    final i = visibles.indexOf(_actual ?? -1);
    if (i > 0) {
      setState(() => _actual = visibles[i - 1]);
    } else if (_act!.instrucciones.isNotEmpty) {
      setState(() => _enPortada = true);
    }
  }

  Future<void> _enviar() async {
    final act = _act!;
    _espera?.cancel();
    setState(() => _enviando = true);

    final visibles = _visiblesDe(act).toSet();
    try {
      final resultado = await enviarActividad(
        _server,
        act.id,
        _respuestas.values.where((r) => visibles.contains(r.preguntaId)),
        alumnoId: _alumnoId,
      );
      if (!mounted) return;
      setState(() {
        _sucio = false;
        _resultado = resultado;
        _enviando = false;
      });
    } on MotivoDeActividad catch (m) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        final falta = m.faltan.where(visibles.contains);
        if (falta.isNotEmpty) _actual = falta.first;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m.mensaje)));
    } catch (err) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo enviar: $err')));
    }
  }

  Future<RespuestaAct?> _subirArchivoDePregunta(PreguntaAct p) async {
    final elegido = await elegirDocumento();
    if (elegido == null) return null;
    try {
      final archivo = await subirArchivoDeActividad(
        _server,
        _act!.id,
        clase: 'archivo',
        bytes: elegido.bytes,
        nombre: elegido.nombre,
        alumnoId: _alumnoId,
        preguntaId: p.id,
      );
      return RespuestaAct(
        preguntaId: p.id,
        archivoId: archivo.id,
        archivoNombre: archivo.nombreOriginal,
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$err')));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EstiloActividades.fondo,
      body: SafeArea(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final act = _act;
    if (_error != null || act == null) {
      return _aviso(
        icono: Icons.error_outline,
        texto: _error ?? 'No se pudo abrir la actividad.',
      );
    }

    if (_resultado != null) return _fin(act, _resultado!);

    if (act.sinIntentos) {
      return _aviso(
        icono: Icons.task_alt,
        texto: act.intentosMaximo > 1
            ? 'Ya usaste tus ${act.intentosMaximo} intentos.'
            : 'Ya respondiste esta actividad.',
        conMisRespuestas: true,
      );
    }

    if (act.preguntas.isEmpty) {
      return _aviso(
          icono: Icons.inbox_outlined,
          texto: 'Esta actividad todavía no tiene preguntas.');
    }

    final visibles = _visiblesDe(act);
    final i = visibles.indexOf(_actual ?? -1);
    final p = _pregunta;
    final ultima = i == visibles.length - 1;
    final bloqueada = !_enPortada &&
        p != null &&
        p.obligatoria &&
        !respuestaDada(p.tipo, _respuestas[p.id]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _barraDeArriba(act),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var k = 0; k < visibles.length; k++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin:
                        EdgeInsets.only(right: k < visibles.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: !_enPortada && k <= i
                          ? EstiloActividades.primario
                          : const Color(0x1F172640),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: _enPortada
                ? _portada(act, visibles.length)
                : p == null
                    ? const SizedBox.shrink()
                    : CampoDePregunta(
                        key: ValueKey(p.id),
                        pregunta: p,
                        respuesta: _respuestas[p.id],
                        alCambiar: _alCambiar,
                        alPedirArchivo: act.anonimato == 'nombre'
                            ? _subirArchivoDePregunta
                            : null,
                      ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (!_enPortada && (i > 0 || act.instrucciones.isNotEmpty)) ...[
                SizedBox(
                  height: EstiloActividades.alturaDeBoton,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: EstiloActividades.tinta,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _enviando ? null : _atras,
                    child: const Text('Atrás',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  style: EstiloActividades.botonPrincipal(),
                  onPressed: bloqueada || _enviando ? null : _siguiente,
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(_enPortada
                          ? 'Empezar'
                          : ultima
                              ? 'Enviar'
                              : 'Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barraDeArriba(ActParaResponder act) {
    final partes = <String>[
      if (act.anonima) 'Anónima',
      if (act.porAlumno != null) 'Por ${act.porAlumno!.primerNombre}',
      _estadoDelGuardado(),
    ];
    final error = _errorAlGuardar != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(act.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  partes.join(' · '),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: error
                        ? EstiloActividades.urgenteTinta
                        : EstiloActividades.hechaTinta,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _estadoDelGuardado() {
    if (_errorAlGuardar != null) return 'no se pudo guardar, se reintenta';
    if (_guardando) return 'guardando…';
    if (_guardadoAt != null) return 'guardado';
    return 'se guarda sola';
  }

  Widget _portada(ActParaResponder act, int nVisibles) {
    final datos = <String>[
      EstiloActividades.nombreDelModo(act.modo),
      '$nVisibles ${nVisibles == 1 ? 'pregunta' : 'preguntas'}',
      if (act.cierraAt != null) 'cierra el ${fechaDeActividad(act.cierraAt!)}',
      if (act.intentosMaximo > 1)
        'intento ${act.intentosUsados + 1} de ${act.intentosMaximo}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(act.titulo, style: const TextStyle(fontSize: 26, height: 1.2)),
        const SizedBox(height: 8),
        Text(datos.join(' · '),
            style: const TextStyle(
                fontSize: 13, color: EstiloActividades.tintaApagada)),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: EstiloActividades.bloque(),
          child: Text(act.instrucciones,
              style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
        if (act.anonima) ...[
          const SizedBox(height: 14),
          const Text(
            'Es anónima: quien la creó ve las respuestas del grupo, no quién '
            'respondió qué.',
            style: TextStyle(fontSize: 13, color: EstiloActividades.tintaSuave),
          ),
        ],
      ],
    );
  }

  Widget _fin(ActParaResponder act, ResultadoDeEnvio r) {
    final nombre = act.porAlumno == null
        ? (AuthService.user.nombres ?? '').trim().split(' ').first
        : '';
    final lineas = <String>[];

    if (act.modo == 'cuestionario') {
      if (r.nota != null) {
        lineas.add('Tu nota: ${r.nota}'
            '${act.notaMaxima != null ? ' de ${act.notaMaxima}' : ''}.');
      } else {
        lineas.add('Tu nota se verá cuando el cuestionario cierre.');
      }
      if (r.quedanIntentos > 0) {
        lineas.add(r.quedanIntentos == 1
            ? 'Te queda un intento más.'
            : 'Te quedan ${r.quedanIntentos} intentos más.');
      }
    } else if (act.anonima) {
      lineas.add('Llegó sin tu nombre: quien la creó ve los resultados del '
          'grupo, no quién respondió qué.');
    } else if (act.porAlumno != null) {
      lineas.add('Quedó respondida por ${act.porAlumno!.primerNombre}.');
    } else {
      lineas.add('Tus respuestas llegaron.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: EstiloActividades.hechaFondo,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        size: 36, color: EstiloActividades.hechaTinta),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      nombre.isEmpty
                          ? '¡Gracias!'
                          : '¡Gracias, ${_capital(nombre)}!',
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 10),
                  for (final l in lineas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(l,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14,
                              color: EstiloActividades.tintaSuave)),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MisRespuestasActividadScreen(fila: widget.fila)),
                ),
                child: const Text('Ver mis respuestas'),
              ),
              const SizedBox(height: 6),
              FilledButton(
                style: EstiloActividades.botonPrincipal(),
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver a actividades'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Widget _aviso({
    required IconData icono,
    required String texto,
    bool conMisRespuestas = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 48, color: EstiloActividades.tintaApagada),
                  const SizedBox(height: 12),
                  Text(texto, textAlign: TextAlign.center),
                  if (conMisRespuestas) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      style: EstiloActividades.botonPrincipal(),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MisRespuestasActividadScreen(
                                fila: widget.fila)),
                      ),
                      child: const Text('Ver mis respuestas'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
