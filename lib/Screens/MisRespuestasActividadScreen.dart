import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Screens/ResponderActividadScreen.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lo que respondí o entregué, y los resultados que se compartieron.
///
/// Maqueta `MisRespuestas`, llevada al teléfono: una actividad por pantalla
/// (la lista de «Hechas» ya es la bandeja). **Todo sale del servidor**
/// (`act/{id}/mis-respuestas`), también en las encuestas anónimas: el
/// anonimato es de presentación, frente a quien la creó, no frente a uno
/// mismo (Joseth, 26 sep).
///
/// - **Cuestionario**: la nota, las correctas, el tiempo, los intentos y el
///   promedio del grupo (sólo con cinco o más), y pregunta por pregunta con la
///   correcta al lado si el docente las deja ver.
/// - **Tarea**: lo entregado y lo que dijo el docente.
/// - **Encuesta**: mis respuestas y, si se cerró compartiendo, los resultados
///   del grupo con la marca «tú» en lo que elegí. Sin responder, sólo se
///   llega aquí si se compartieron «con todos».
class MisRespuestasActividadScreen extends StatefulWidget {
  /// Desde una fila de la bandeja.
  MisRespuestasActividadScreen({super.key, required ActEnBandeja this.fila})
      : actividadId = fila.id,
        alumnoId = fila.porAlumno?.alumnoId,
        paraQuien = fila.porAlumno?.primerNombre;

  /// Sin fila: desde un aviso de algo que no está en la bandeja de quien lo
  /// abre. Es el acudiente con la nota de una tarea de su hijo: la tarea es
  /// del alumno y no le sale en su lista, pero «mis respuestas» se la enseña
  /// con el `alumno_id` del hijo.
  const MisRespuestasActividadScreen.porId({
    super.key,
    required this.actividadId,
    this.alumnoId,
    this.paraQuien,
  }) : fila = null;

  final ActEnBandeja? fila;
  final int actividadId;
  final int? alumnoId;

  /// El primer nombre del hijo, cuando quien mira es su acudiente.
  final String? paraQuien;

  @override
  State<MisRespuestasActividadScreen> createState() =>
      _MisRespuestasActividadScreenState();
}

class _MisRespuestasActividadScreenState
    extends State<MisRespuestasActividadScreen> {
  final _server = Server();

  bool _cargando = true;
  String? _error;
  MisRespuestasAct? _datos;

  bool _soloFalladas = false;
  bool _verGrupo = true;
  Uint8List? _fotoBytes;

  /// El `alumno_id` sólo lo manda el acudiente: el servidor lo lee así.
  int? get _alumnoId => AuthService.user.esAcudiente ? widget.alumnoId : null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await traerMisRespuestas(_server, widget.actividadId,
          alumnoId: _alumnoId);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
        _verGrupo = datos.compartidos != null;
      });
      final foto = datos.entrega?.foto;
      if (foto != null) {
        final bytes = await traerArchivoDeActividad(_server, foto.id);
        if (mounted) setState(() => _fotoBytes = bytes);
      }
    } on MotivoDeActividad catch (m) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = m.status == 409
            ? ((widget.fila?.abierta ?? true)
                ? 'Todavía no has respondido esta actividad.'
                : 'Esta actividad cerró sin que la respondieras.')
            : m.mensaje;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quien = AuthService.user.esAcudiente ? widget.paraQuien : null;
    return Scaffold(
      backgroundColor: EstiloActividades.fondo,
      appBar: AppBar(
        backgroundColor: EstiloActividades.fondo,
        title: Text(quien == null ? 'Mis respuestas' : 'Respuestas · $quien',
            style: const TextStyle(fontSize: 17)),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final d = _datos;
    if (d == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 48, color: EstiloActividades.tintaApagada),
              const SizedBox(height: 12),
              Text(_error ?? 'No hay nada que enseñar.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final hijos = switch (d.actividad.modo) {
      'cuestionario' => _cuestionario(d),
      'tarea' => _tarea(d),
      _ => _encuesta(d),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [_cabecera(d), const SizedBox(height: 12), ...hijos],
    );
  }

  Widget _cabecera(MisRespuestasAct d) {
    final f = d.actividad;
    final nota = d.nota ?? d.entrega?.nota;
    final cuando = d.enviadaAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EstiloActividades.bloque(),
      child: Row(
        children: [
          if (nota != null) ...[
            _anilloDeNota(nota, d),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.titulo,
                    style: const TextStyle(fontSize: 20, height: 1.2)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    EstiloActividades.pildora(
                        EstiloActividades.nombreDelModo(f.modo),
                        EstiloActividades.chapa(f.modo).$2,
                        EstiloActividades.chapa(f.modo).$3),
                    if (!f.abierta)
                      EstiloActividades.pildora(
                          'Cerrada',
                          EstiloActividades.normalFondo,
                          EstiloActividades.normalTinta),
                    if (d.entrega?.calificada ?? false)
                      EstiloActividades.pildora(
                          'Calificada',
                          EstiloActividades.hechaFondo,
                          EstiloActividades.hechaTinta),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    f.donde,
                    if (cuando != null)
                      (f.esTarea ? 'entregada ' : 'lo hiciste ') +
                          momentoDeActividad(cuando) +
                          ((d.entrega?.tarde ?? false) ? ' (tarde)' : ''),
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 12.5, color: EstiloActividades.tintaSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anilloDeNota(int nota, MisRespuestasAct d) {
    final max = d.puntajeMax != null && d.puntaje != null && d.puntajeMax! > 0
        ? d.puntaje! / d.puntajeMax!
        : null;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: max ?? 1,
            strokeWidth: 8,
            backgroundColor: const Color(0xFFECEEF3),
            color: const Color(0xFF1BAF7A),
          ),
          Center(
            child: Text('$nota',
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _dato(String cifra, String rotulo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cifra,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Text(rotulo,
                style: const TextStyle(
                    fontSize: 12, color: EstiloActividades.tintaApagada)),
          ],
        ),
      );

  List<Widget> _cuestionario(MisRespuestasAct d) {
    final conCorrectas = d.respuestas.any((r) => r.acerto != null);
    final datos = <Widget>[
      if (d.correctas != null)
        _dato('${d.correctas} de ${d.respuestas.length}', 'correctas'),
      if (d.puntaje != null && d.puntajeMax != null)
        _dato(
            '${cifraAct(d.puntaje!)} de ${cifraAct(d.puntajeMax!)}', 'puntos'),
      if (d.tiempoSegundos != null)
        _dato(_duracion(d.tiempoSegundos!), 'te tomó'),
      _dato('${d.intentos}', d.intentos == 1 ? 'intento' : 'intentos'),
      if (d.promedioGrupo != null)
        _dato(cifraAct(d.promedioGrupo!), 'promedio del grupo'),
    ];

    final filas =
        d.respuestas.where((r) => !_soloFalladas || r.acerto == false).toList();

    return [
      Wrap(spacing: 8, runSpacing: 8, children: datos),
      const SizedBox(height: 12),
      if (d.nota == null)
        _nota('La nota y las respuestas correctas se ven cuando el '
            'cuestionario cierre.'),
      if (d.nota != null && !conCorrectas)
        _nota('El docente no muestra las respuestas correctas de este '
            'cuestionario.'),
      if (conCorrectas)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Todas')),
              ButtonSegment(value: true, label: Text('Sólo las que fallé')),
            ],
            selected: {_soloFalladas},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _soloFalladas = s.first),
          ),
        ),
      for (var i = 0; i < filas.length; i++) _preguntaCalificada(filas[i]),
      if (d.actividad.abierta)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => ResponderActividadScreen(
                      fila: widget.fila ?? d.actividad)),
            ),
            child: const Text('Intentarlo otra vez'),
          ),
        ),
    ];
  }

  String _duracion(int s) {
    if (s < 60) return '$s s';
    final m = (s / 60).round();
    return m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
  }

  Widget _nota(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 12.5, color: EstiloActividades.tintaSuave)),
      );

  /// Lo mío de una pregunta, en palabras.
  String _loMio(PreguntaAct p, RespuestaAct? r) {
    if (r == null) return 'Sin responder';
    if (p.esDeOpciones) {
      final nombres = r.opcionIds
          .map((id) => p.definicionDe(id) ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      if ((r.texto ?? '').isNotEmpty) nombres.add('Otra: ${r.texto}');
      return nombres.isEmpty ? 'Sin responder' : nombres.join(', ');
    }
    return switch (p.tipo) {
      'escala' => r.valor == null ? 'Sin responder' : '${r.valor} de 5',
      'fecha' => r.fecha ?? 'Sin responder',
      'archivo' => r.archivoId == null ? 'Sin responder' : 'Archivo subido',
      _ => (r.texto ?? '').isEmpty ? 'Sin responder' : r.texto!,
    };
  }

  Widget _preguntaCalificada(RespuestaMia fila) {
    final p = fila.pregunta;
    final bien = fila.acerto;
    final correctas = p.opciones
        .where((o) => o.esCorrecta == true)
        .map((o) => o.definicion)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: EstiloActividades.bloque(
          borde: bien == false ? const Color(0xFFFFD1C6) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bien != null) ...[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bien
                    ? EstiloActividades.hechaFondo
                    : EstiloActividades.urgenteFondo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(bien ? Icons.check : Icons.close,
                  size: 18,
                  color: bien
                      ? EstiloActividades.hechaTinta
                      : EstiloActividades.urgenteTinta),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.enunciado,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 13),
                  children: [
                    const TextSpan(
                        text: 'Tu respuesta: ',
                        style:
                            TextStyle(color: EstiloActividades.tintaApagada)),
                    TextSpan(
                        text: _loMio(p, fila.mia),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: bien == false
                              ? EstiloActividades.urgenteTinta
                              : bien == true
                                  ? EstiloActividades.hechaTinta
                                  : EstiloActividades.tinta,
                        )),
                    if (bien == false && correctas.isNotEmpty) ...[
                      const TextSpan(
                          text: ' · Correcta: ',
                          style:
                              TextStyle(color: EstiloActividades.tintaApagada)),
                      TextSpan(
                          text: correctas,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ],
                )),
                if ((p.explicacion ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(p.explicacion!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: EstiloActividades.tintaSuave)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tarea(MisRespuestasAct d) {
    final e = d.entrega;
    if (e == null) return [_nota('No hay entrega.')];

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: EstiloActividades.bloque(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LO QUE ENTREGASTE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    color: EstiloActividades.tintaApagada)),
            const SizedBox(height: 10),
            if (e.foto != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _fotoBytes == null
                      ? Container(
                          height: 120,
                          color: EstiloActividades.fondo,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator())
                      : Image.memory(_fotoBytes!, fit: BoxFit.contain),
                ),
              ),
            if (e.archivo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    EstiloActividades.pildora(
                        e.archivo!.extension,
                        EstiloActividades.urgenteFondo,
                        EstiloActividades.urgenteTinta),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${e.archivo!.nombreOriginal} · ${pesoLegible(e.archivo!.bytes)}',
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            if (e.enlace != null)
              InkWell(
                onTap: () async {
                  final uri = Uri.tryParse(e.enlace!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(e.enlace!,
                      style: const TextStyle(
                          color: Color(0xFF0E56BD),
                          decoration: TextDecoration.underline)),
                ),
              ),
            if ((e.texto ?? '').isNotEmpty)
              Text('«${e.texto}»',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: EstiloActividades.tintaSuave)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: EstiloActividades.bloque(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LO QUE DIJO EL DOCENTE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    color: EstiloActividades.tintaApagada)),
            const SizedBox(height: 8),
            Text(
              e.calificada
                  ? ((e.comentario ?? '').isNotEmpty
                      ? e.comentario!
                      : 'Calificó sin comentario.')
                  : 'Todavía no la ha calificado.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
      if (d.respuestas.isNotEmpty) ...[
        const SizedBox(height: 10),
        ..._misRespuestasEnLista(d),
      ],
    ];
  }

  List<Widget> _encuesta(MisRespuestasAct d) {
    final compartidos = d.compartidos;
    final hayMias = d.respuestas.isNotEmpty;

    return [
      if (compartidos != null && hayMias)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Resultados del grupo')),
              ButtonSegment(value: false, label: Text('Mis respuestas')),
            ],
            selected: {_verGrupo},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _verGrupo = s.first),
          ),
        ),
      if (compartidos != null && (_verGrupo || !hayMias))
        ..._resultadosDelGrupo(compartidos)
      else ...[
        if (d.actividad.anonima)
          _nota('Sólo tú ves esta página. Quien creó la encuesta recibió '
              'estas respuestas sin tu nombre.'),
        ..._misRespuestasEnLista(d),
      ],
    ];
  }

  List<Widget> _misRespuestasEnLista(MisRespuestasAct d) => [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: EstiloActividades.bloque(),
          child: Column(
            children: [
              for (var i = 0; i < d.respuestas.length; i++)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(
                            top: BorderSide(color: Color(0x0F172640))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.respuestas[i].pregunta.enunciado,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: EstiloActividades.tintaApagada)),
                      const SizedBox(height: 2),
                      Text(
                          _loMio(d.respuestas[i].pregunta, d.respuestas[i].mia),
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ];

  List<Widget> _resultadosDelGrupo(ResultadosCompartidos c) {
    return [
      _nota('Quien la creó cerró la encuesta y compartió los resultados. '
          'No se ve quién respondió qué.'),
      for (final p in c.preguntas) _resultado(p),
      _nota('Respondieron ${c.respondieron} de ${c.destinatarios}. Las '
          'respuestas escritas sólo se comparten si quien la creó lo eligió.'),
    ];
  }

  Widget _resultado(ResultadoCompartido p) {
    final total = p.barras.fold<int>(0, (s, b) => s + b.n);
    final sub = [
      if (p.tipo == 'escala') 'Escala 1–5' else 'Opciones',
      if (p.promedio != null) 'promedio ${cifraAct(p.promedio!)}',
      '${p.respondidaPor} respuestas',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: EstiloActividades.bloque(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.enunciado,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(
                  fontSize: 12, color: EstiloActividades.tintaApagada)),
          const SizedBox(height: 10),
          if (p.oculto)
            const Text(
                'Muy pocas respuestas para enseñarlas sin que se sepa de '
                'quién son.',
                style: TextStyle(
                    fontSize: 13, color: EstiloActividades.tintaSuave))
          else ...[
            for (final b in p.barras) _barra(b, total),
            for (final t in p.textos)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('«$t»',
                    style: const TextStyle(
                        fontSize: 13, fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _barra(BarraCompartida b, int total) {
    final pct = total == 0 ? 0 : (b.n * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(b.etiqueta,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  b.mia ? FontWeight.w700 : FontWeight.w400)),
                    ),
                    if (b.mia) ...[
                      const SizedBox(width: 6),
                      EstiloActividades.pildora(
                          'tú',
                          EstiloActividades.primarioSuave,
                          EstiloActividades.primarioOscuro),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('$pct %',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : b.n / total,
              minHeight: 8,
              backgroundColor: const Color(0xFFECEEF3),
              color:
                  b.mia ? EstiloActividades.primario : const Color(0xFF2A78D6),
            ),
          ),
        ],
      ),
    );
  }
}
