import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/MiCuentaModel.dart';

/// El estado de cuenta de la familia: `GET mi-cuenta`.
///
/// Sólo esa ruta. Las otras tres del grupo —`recibos/{id}`, `pagar` y
/// `pagos/{referencia}`— son de la web por ahora: la app enseña la cuenta y
/// para pagar dice cómo, sin pasarela.
///
/// Los dos «no» que puede contestar el servidor no son errores de red, y por
/// eso tienen su frase:
///
///  - **404**: `ExigirModulo` con el módulo apagado. El menú no lleva aquí en
///    ese caso, pero un aviso viejo o una sesión de antes de que el colegio lo
///    apagara sí. Con `Accept: application/json` el cuerpo es `{"message": ""}`,
///    o sea que no hay nada del servidor que enseñar.
///  - **403**: quien mira no es `Acudiente`. Trae su frase («Esta pantalla es de
///    las familias.»), y gana.
Future<MiCuenta> traerMiCuenta(Server server) async {
  final res = await server.get('/mi-cuenta');

  if (res.statusCode == 404) {
    throw Exception(
      'Su colegio no tiene el estado de cuenta en la aplicación. '
      'Consulte en la tesorería del colegio.',
    );
  }

  if (res.statusCode >= 300) {
    throw Exception(
      (res.statusCode < 500 ? loQueDijoElServidor(res.body) : null) ??
          mensajeDeFallo(res.statusCode, 'ver el estado de cuenta'),
    );
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió el estado de cuenta.');
  }

  return MiCuenta.fromJson(Map<String, dynamic>.from(cuerpo));
}
