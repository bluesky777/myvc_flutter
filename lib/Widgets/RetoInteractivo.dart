import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Un reto de inglés (pregunta `interactiva` de Actividades) pintado por el
/// motor de la web dentro de una WebView. Es el `<myvc-reto>` de app2.
///
/// La página es `assets/retos/reto.html`, generada desde myvc_front con
/// `node tools/retos/generar.mjs`: va dentro de la app, sin red y sin token.
/// La WebView sólo pinta; lo que se juega vuelve por [alCambiar] y se guarda
/// con el borrador de siempre. **La nota la pone el servidor** con su copia en
/// PHP del motor; la app no calcula puntaje. Ver `docs/ingles.md`.
///
/// Se pinta una sola vez, al cargar: lo que vuelve por [estado] después de un
/// [alCambiar] es lo que el motor ya tiene, y repintar perdería la animación
/// (y la carta abierta de la memoria).
class RetoInteractivo extends StatefulWidget {
  const RetoInteractivo({
    super.key,
    required this.reto,
    required this.cfg,
    this.estado,
    required this.alCambiar,
    this.soloLectura = false,
  });

  /// La clave del reto en el motor (`pesca`, `memoria`…).
  final String reto;
  final Map<String, dynamic> cfg;

  /// Lo jugado hasta ahora; sin él, el reto arranca de cero (`init`).
  final Map<String, dynamic>? estado;

  /// El estado nuevo y si el reto quedó terminado (`done`), en cada jugada.
  final void Function(Map<String, dynamic> estado, bool hecho) alCambiar;
  final bool soloLectura;

  @override
  State<RetoInteractivo> createState() => _RetoInteractivoState();
}

class _RetoInteractivoState extends State<RetoInteractivo> {
  late final WebViewController _web;
  FlutterTts? _voz;
  double _alto = 240;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('Listo', onMessageReceived: (_) => _pintar())
      ..addJavaScriptChannel('Alto', onMessageReceived: _medir)
      ..addJavaScriptChannel('Reto', onMessageReceived: _jugada)
      ..addJavaScriptChannel('Voz', onMessageReceived: _hablar)
      ..loadFlutterAsset('assets/retos/reto.html');
  }

  @override
  void dispose() {
    _voz?.stop();
    super.dispose();
  }

  void _pintar() {
    final datos = jsonEncode({
      'reto': widget.reto,
      'cfg': widget.cfg,
      'estado': widget.estado,
      'soloLectura': widget.soloLectura,
    });
    _web.runJavaScript('pintarReto($datos)');
    if (mounted) setState(() => _listo = true);
  }

  void _medir(JavaScriptMessage m) {
    final alto = double.tryParse(m.message);
    if (alto == null || alto <= 0 || !mounted) return;
    setState(() => _alto = alto);
  }

  void _jugada(JavaScriptMessage m) {
    final j = jsonDecode(m.message);
    if (j is! Map || j['estado'] is! Map) return;
    widget.alCambiar(
        Map<String, dynamic>.from(j['estado'] as Map), j['hecho'] == true);
  }

  /// La voz del motor donde la WebView no trae `speechSynthesis` (Android).
  Future<void> _hablar(JavaScriptMessage m) async {
    final voz = _voz ??= FlutterTts();
    if (m.message == 'callar') {
      await voz.stop();
      return;
    }
    final j = jsonDecode(m.message);
    if (j is! Map) return;
    await voz.setLanguage('en-US');
    // El motor habla a 0.85–0.9 del ritmo normal; flutter_tts toma 0.5 como
    // normal en Android.
    await voz.setSpeechRate(((j['rate'] as num?) ?? 0.9).toDouble() * 0.5);
    await voz.awaitSpeakCompletion(true);
    await voz.speak('${j['texto'] ?? ''}');
    if (mounted) _web.runJavaScript('__vozTermino()');
  }

  @override
  Widget build(BuildContext context) {
    // El reto se arrastra con el dedo: la WebView se queda con los gestos que
    // empiezan dentro. Si es más alto que la pantalla, se desplaza por dentro.
    final tope = MediaQuery.sizeOf(context).height * 0.75;
    return AnimatedOpacity(
      opacity: _listo ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: SizedBox(
        height: _alto.clamp(160, tope),
        child: WebViewWidget(
          controller: _web,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer()),
          },
        ),
      ),
    );
  }
}
