import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Una página de la web (app2, `<colegio>/up2/…`) dentro de la app, con la
/// sesión de la app. La primera es la racha de English Quest
/// (`docs/ingles.md`, fase 2).
///
/// ## Cómo entra la sesión
///
/// app2 lee su sesión de `localStorage`: `xtoken`, `xrefresco` y
/// `xtoken_expira`. Antes de abrir la ruta se carga una página mínima con
/// `baseUrl` en el colegio —mismo origen, mismo `localStorage`— que escribe el
/// token de la app y salta a la ruta. Las dos rarezas son a propósito:
///
/// - **Sin `xrefresco`**: el token de la app es de los de `POST login`, que no
///   tiene refresco. Si app2 intentara renovarlo, cerraría su sesión por
///   `refresco-invalido`, que **no** toca el servidor; sólo la cierra por
///   inactividad (doce horas en una misma página) llama a `auth/logout`.
/// - **`xtoken_expira` a siete días**: app2 renueva a la mitad de lo que queda,
///   así que en una visita a la WebView nunca llega a intentarlo. Si el token
///   caducó de verdad, el servidor contesta 401 y app2 enseña su login.
///
/// El menú de app2 se ve dentro. Esconderlo pide un «modo incrustado» en el
/// front, que todavía no existe.
class WebConSesionScreen extends StatefulWidget {
  const WebConSesionScreen({
    super.key,
    required this.titulo,
    required this.ruta,
  });

  final String titulo;

  /// La ruta de app2 sin `/up2`, p. ej. `/ingles/racha`.
  final String ruta;

  @override
  State<WebConSesionScreen> createState() => _WebConSesionScreenState();
}

/// La página que deja la sesión en `localStorage` y salta a [destino].
@visibleForTesting
String paginaQueDejaLaSesion({
  required String token,
  required String destino,
  required DateTime ahora,
}) {
  final expira =
      ahora.add(const Duration(days: 7)).millisecondsSinceEpoch.toString();
  return '''<!doctype html><html><head><meta charset="utf-8"></head><body>
<script>
try {
  localStorage.setItem('xtoken', ${jsonEncode(token)});
  localStorage.setItem('xtoken_expira', ${jsonEncode(expira)});
  localStorage.removeItem('xrefresco');
} catch (e) {}
location.replace(${jsonEncode(destino)});
</script></body></html>''';
}

class _WebConSesionScreenState extends State<WebConSesionScreen> {
  WebViewController? _web;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    final base = '${Server.urlServer}/up2/';
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (mounted && url.contains('/up2/')) {
            setState(() => _cargando = false);
          }
        },
      ))
      ..loadHtmlString(
        paginaQueDejaLaSesion(
          token: AuthService.user.token ?? '',
          destino: '${Server.urlServer}/up2${widget.ruta}',
          ahora: DateTime.now(),
        ),
        baseUrl: base,
      );
  }

  @override
  Widget build(BuildContext context) {
    final web = _web;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) async {
        if (hecho) return;
        // El «atrás» de Android navega dentro de la página mientras pueda.
        final navegador = Navigator.of(context);
        if (web != null && await web.canGoBack()) {
          await web.goBack();
        } else {
          navegador.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.titulo),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: web == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Esto se abre en la app del celular o en la plataforma '
                    'web.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: web),
                  if (_cargando)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
      ),
    );
  }
}
