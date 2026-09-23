import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// El logo del colegio, del tamaño que cabe en la barra de arriba.
///
/// **Cuando no hay logo no ocupa nada.** Ni un recuadro gris, ni una rueda, ni
/// un hueco reservado: `SizedBox.shrink()`. Hay colegios sin logo —`logo_id`
/// admite nulo— y en ésos la barra tiene que verse como si esto no existiera,
/// no como una barra a la que le falta algo.
///
/// El archivo sale de `GET /years`, que ya une `images` por `y.logo_id`; se
/// guarda en disco entre arranques igual que la sigla. Ver
/// [ContextoAcademico.logoColegio].
class LogoDelColegio extends StatelessWidget {
  const LogoDelColegio({super.key, this.lado = 28});

  final double lado;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ContextoAcademico.instancia,
      builder: (context, _) {
        final url = Server.urlFoto(ContextoAcademico.instancia.logoColegio);
        if (url.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            width: lado,
            height: lado,
            // Redondo como los avatares, porque un logo cuadrado dentro de una
            // fila de iconos redondos se lee como una imagen pegada encima.
            child: ClipOval(child: _imagen(url)),
          ),
        );
      },
    );
  }

  /// La misma decisión que [AvatarPersona](AvatarPersona.dart), y por el mismo
  /// motivo: en móvil `CachedNetworkImage`, que guarda en disco y hace que la
  /// cabecera `max-age` del servidor sirva para algo; en web `Image.network`,
  /// donde el navegador ya cachea y `webHtmlElementStrategy` salva el caso de
  /// servir la app desde un dominio distinto al del colegio.
  ///
  /// **Mientras carga y si falla, nada.** Es un adorno de la barra: un icono
  /// roto donde va el logo del colegio se ve peor que no tener logo.
  Widget _imagen(String url) {
    if (kIsWeb) {
      return Image.network(
        url,
        width: lado,
        height: lado,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (context, hijo, progreso) =>
            progreso == null ? hijo : const SizedBox.shrink(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: lado,
      height: lado,
      // `contain` y no `cover`: un logo recortado por los bordes deja de ser el
      // logo. Se prefiere que sobre fondo a que falte escudo.
      fit: BoxFit.contain,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
