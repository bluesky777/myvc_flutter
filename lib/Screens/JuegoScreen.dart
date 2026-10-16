import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/JuegosApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UsuariosApi.dart';
import 'package:myvc_flutter/Utils/GruposDelUsuario.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Un juego 3D en una WebView.
///
/// ## Por qué la página del juego va dentro de un iframe
///
/// `puente.js` sólo se sabe «dentro de la app» cuando va en un iframe con `?u`,
/// y entonces habla con su padre por `postMessage`, comprobando que los dos
/// sean del mismo origen. En la web el padre es app2; aquí es [_pagina], una
/// página mínima que se carga con `baseUrl` en `<colegio>/up2/juegos3d/` —así
/// tiene el origen del colegio— y le pasa a Dart cada mensaje por el canal
/// `Puente`:
///
/// - `juegos3d:volver` cierra la pantalla.
/// - `juegos3d:api` hace la petición con el token de la app, sólo a rutas
///   `juegos/…` ([llamarPorElJuego]). El token nunca entra a la página.
/// - `juegos3d:grupos` le da al personal sus grupos del año.
///
/// Las salas que el juego abra (`POST juegos/salas`) se borran al salir, como
/// en la web. El contrato entero: myvc_front `docs/juegos-3d/CONTRATO.md`.
///
/// Destello no lleva nada de esto: se abre con su dirección tal cual.
class JuegoScreen extends StatefulWidget {
  const JuegoScreen({super.key, required this.juego, this.servidor});

  final Juego3D juego;
  final Server? servidor;

  @override
  State<JuegoScreen> createState() => _JuegoScreenState();
}

class _JuegoScreenState extends State<JuegoScreen> {
  late final Server server = widget.servidor ?? Server();
  WebViewController? _web;
  bool _cargando = true;

  /// Las salas que abrió el juego desde aquí y siguen vivas.
  final Set<int> _salas = {};

  bool get _esPersonal =>
      !(AuthService.user.esAlumno || AuthService.user.esAcudiente);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _cargando = false);
        },
      ));

    final url = widget.juego.url;
    if (url != null) {
      web.loadRequest(Uri.parse(url));
    } else {
      web
        ..addJavaScriptChannel('Puente', onMessageReceived: _alMensaje)
        ..loadHtmlString(
          _pagina(direccionDelJuego(
            widget.juego,
            userId: AuthService.user.id ?? 0,
            color: kPrimaryColor,
            docente: _esPersonal,
          )),
          baseUrl: '${Server.urlServer}/up2/juegos3d/',
        );
    }
    _web = web;
  }

  @override
  void dispose() {
    for (final id in _salas) {
      server.delete('/juegos/salas/$id').catchError((_) => null);
    }
    super.dispose();
  }

  static String _pagina(String src) => '''<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
iframe{border:0;width:100%;height:100%;display:block}</style></head>
<body><iframe id="j" src="${const HtmlEscape().convert(src)}" allow="fullscreen; autoplay; gamepad"></iframe>
<script>
var j = document.getElementById('j');
window.addEventListener('message', function (ev) {
  if (ev.source !== j.contentWindow || ev.origin !== location.origin) return;
  var d = ev.data;
  if (!d || typeof d.tipo !== 'string' || d.tipo.indexOf('juegos3d:') !== 0) return;
  Puente.postMessage(JSON.stringify(d));
});
window.contestar = function (m) { j.contentWindow.postMessage(m, location.origin); };
</script></body></html>''';

  Future<void> _alMensaje(JavaScriptMessage m) async {
    final Object? d;
    try {
      d = jsonDecode(m.message);
    } catch (_) {
      return;
    }
    if (d is! Map) return;

    switch (d['tipo']) {
      case 'juegos3d:volver':
        if (mounted) Navigator.maybePop(context);
      case 'juegos3d:api':
        final ruta = '${d['ruta'] ?? ''}';
        final metodo = '${d['metodo'] ?? ''}'.toUpperCase();
        final r = await llamarPorElJuego(
          server,
          metodo: metodo,
          ruta: ruta,
          cuerpo: d['cuerpo'],
        );
        _anotarSala(metodo, ruta, r);
        _contestar(d, r);
      case 'juegos3d:grupos':
        _contestar(d, (
          ok: true,
          datos: await _misGrupos(),
          estado: 200,
          error: '',
        ));
    }
  }

  void _anotarSala(String metodo, String ruta, RespuestaAlJuego r) {
    final sala = RegExp(r'^juegos/salas/?(\d+)?$').firstMatch(ruta);
    if (sala == null || !r.ok) return;
    if (metodo == 'POST') {
      final datos = r.datos;
      final id = datos is Map ? int.tryParse('${datos['id']}') : null;
      if (id != null && id > 0) _salas.add(id);
    } else if (metodo == 'DELETE' && sala.group(1) != null) {
      _salas.remove(int.parse(sala.group(1)!));
    }
  }

  /// Los grupos del año para el personal; `[]` para la familia.
  Future<List<Map<String, Object?>>> _misGrupos() async {
    if (!_esPersonal) return const [];
    try {
      final todos = await traerGruposDelColegio(server);
      final mios = await gruposDelUsuario(server, todos);
      final personaId = AuthService.user.personaId;
      return [
        for (final g in mios)
          {
            'id': g.id,
            'nombre': g.nombre,
            'titular': personaId != null && g.titularId == personaId,
          },
      ];
    } catch (_) {
      return const [];
    }
  }

  void _contestar(Map pedido, RespuestaAlJuego r) {
    if (!mounted) return;
    final respuesta = r.ok
        ? {
            'tipo': pedido['tipo'],
            'id': pedido['id'],
            'ok': true,
            'datos': r.datos
          }
        : {
            'tipo': pedido['tipo'],
            'id': pedido['id'],
            'ok': false,
            'estado': r.estado,
            'error': r.error,
          };
    _web?.runJavaScript('contestar(${jsonEncode(respuesta)})');
  }

  Future<void> _abrirAfuera() async {
    final url = widget.juego.url;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final web = _web;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.juego.emoji} ${widget.juego.titulo}'),
        actions: [
          if (widget.juego.url != null)
            IconButton(
              tooltip: 'Abrir ${widget.juego.titulo} en su propia página, '
                  'para jugar en grupo',
              icon: const Icon(Icons.open_in_new),
              onPressed: _abrirAfuera,
            ),
        ],
      ),
      body: web == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Los juegos se abren en la app del celular o en la '
                  'plataforma web.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: web),
                if (_cargando) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
