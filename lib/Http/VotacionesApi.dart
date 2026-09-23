import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// Las votaciones del colegio, desde el teléfono.
///
/// **Nada de aquí llama al servidor mientras [Interruptores.votaciones] esté
/// apagado.** Y el motivo no es el de siempre —gastar un 404—: es que
/// `votos/store` **existe en los dos mundos y contesta distinto**. Antes del
/// rediseño del 22 de septiembre de 2026 devolvía 200 con un `msg` dentro y
/// **reemplazaba el voto anterior**; ahora es 201, o 409/423/403/422. Una app que
/// lea los códigos contra un servidor sin desplegar leería un «ya votaste» como
/// si el voto hubiera entrado. Ver el docblock del interruptor.
///
/// El contrato entero está en `8myvc/docs/migracion/11-votaciones.md` §8 y
/// `8myvc/routes/api/votaciones.php`; el diseño de las pantallas, en
/// `docs/votaciones.md`.
///
/// ## Cuatro rutas, y ninguna más
///
/// De las cuarenta y tantas del módulo, esta app usa cuatro:
///
///     GET   candidatos/conaspiraciones   la papeleta
///     POST  votos/store                  el voto
///     GET   resultados/{id}              el escrutinio
///     GET   votaciones/en-accion-inscrito  sólo para refrescar el estado
///
/// Las de configuración, censo, mesas, actas y auditoría son de la web: se
/// arman sentado, no de pie. Y `auditoria/{id}` es del superusuario y **rompe el
/// secreto del voto**, así que no tiene nada que hacer en una app de bolsillo.
///
/// ## Y una que se lee a propósito a medias
///
/// `votaciones/en-accion-inscrito` devuelve la papeleta **con el conteo en vivo
/// dentro** —`cantidad` y `total` por candidato—, aunque el colegio no haya
/// publicado los resultados: es lo que queda del §1 de la 11, recortado en
/// `votos/show` pero no aquí. Esta capa **tira esos dos campos al leer** y ningún
/// modelo tiene sitio donde guardarlos, así que no hay forma de pintarlos por
/// descuido. Quien quiera números va por `resultados/{id}`, que sí comprueba
/// `can_see_results`.

/// Lo que el servidor contestó cuando no aceptó un voto.
///
/// ## Por qué el código importa y el texto también
///
/// El rediseño cambió el modo de fallo entero: `votos/store` **ya no devuelve
/// 200 con un `msg` dentro**. Ahora el código dice de qué familia es el rechazo
/// y el cuerpo dice la frase, y las frases están escritas para leerlas —«Ya
/// votaste este cargo», «La votación está pausada», «No estás en el censo de
/// esta votación»—.
///
/// **Esto ya se hizo mal una vez, en el otro front.** `app2` tenía una lista de
/// códigos cuyo cuerpo se enseña al usuario y **no incluía 409 ni 423**, así que
/// todos esos mensajes salían como «No se pudo guardar.» (11 §8, «Averías que se
/// encontraron de paso»). O sea el mismo modo de fallo que se vino a quitar del
/// backend, reaparecido en la pantalla. Aquí el texto del servidor es **lo
/// primero** que se enseña, y el respaldo por código sólo entra cuando el
/// servidor cortó sin explicarse.
class RechazoDeLaUrna implements Exception {
  const RechazoDeLaUrna({
    required this.codigo,
    required this.mensaje,
    this.constancia,
  });

  final int codigo;

  /// Lo que hay que enseñarle a la persona, ya resuelto.
  final String mensaje;

  /// Sólo en el 409: la constancia del voto que ya estaba, con su hora.
  final Constancia? constancia;

  /// Si ya había votado ese cargo. **No es un error que haya que reintentar**:
  /// es el sistema funcionando, y la pantalla lo trata como «esto ya está
  /// hecho», no como una avería.
  bool get yaHabiaVotado => codigo == 409;

  /// La urna está cerrada, pausada o fuera de fechas. Reintentar no sirve de
  /// nada hasta que el colegio la abra.
  bool get urnaCerrada => codigo == 423;

  /// No le corresponde: su estamento no vota, no está en el censo, o su grupo
  /// vota en su mesa.
  bool get noLeCorresponde => codigo == 403;

  @override
  String toString() => mensaje;
}

/// La papeleta de quien tiene la sesión abierta.
///
/// `GET candidatos/conaspiraciones`. **Es la ruta de la papeleta y está abierta a
/// propósito** —sin `auth.personal`—, porque la llama el alumno; se acota dentro
/// al censo del que pregunta.
///
/// Se prefiere a `en-accion-inscrito` por dos razones: no trae el conteo en vivo
/// dentro (ver la cabecera), y **contesta también a quien no es alumno**
/// resolviendo su elección por otro camino, así que el docente y el acudiente
/// entran por la misma puerta.
Future<Papeleta> traerLaPapeleta(Server server) async {
  if (!Interruptores.votaciones) return Papeleta.ninguna;

  final respuesta = await server.get('/candidatos/conaspiraciones');

  if (respuesta.statusCode != 200) {
    throw Exception(motivoDeRechazo(
      respuesta.body,
      respaldo: 'No se pudo traer la votación (HTTP ${respuesta.statusCode}).',
    ));
  }

  return leerLaPapeleta(respuesta.body);
}

/// Lee la respuesta de `candidatos/conaspiraciones`.
///
/// **Pública y separada de la petición a propósito**, como
/// `leerLasEstaciones`: con el interruptor en `const false`, todo lo que hay
/// detrás de la guarda es código que ninguna prueba alcanza, y esta lectura
/// tiene justo la trampa que no se puede descubrir el día del despliegue.
///
/// ## La trampa: la respuesta es una LISTA que a veces no es una lista de cargos
///
/// `getConaspiraciones` devuelve `[['sin_votaciones_propias' => true]]` cuando
/// esta persona no tiene elección, o sea **una lista de un elemento con forma de
/// otra cosa**. Leerla como cargos daría un cargo sin nombre, sin candidatos y
/// con `votado` falso: un tarjetón fantasma con un cargo en blanco. Y esa forma
/// existe porque la alternativa —una lista vacía— **no distingue «no hay
/// elección» de «elección sin cargos»**, que son dos cosas distintas que hay que
/// decir distinto.
Papeleta leerLaPapeleta(dynamic cuerpo) {
  final leido = _comoJson(cuerpo);
  if (leido is! List || leido.isEmpty) return Papeleta.ninguna;

  final primero = leido.first;

  if (primero is Map && primero.containsKey('sin_votaciones_propias')) {
    return Papeleta.ninguna;
  }

  final cargos = leido
      .whereType<Map>()
      .map(CargoDeLaPapeleta.fromJson)
      .where((cargo) => cargo.id != 0)
      .toList();

  return Papeleta(sinEleccion: false, cargos: cargos);
}

/// Echa un voto.
///
/// `POST votos/store`. **[candidatoId] nulo es el voto en blanco**, y no es un
/// caso aparte del contrato: el blanco es `aspiracion_id` con `candidato_id`
/// nulo, y `blanco_aspiracion_id` —la columna que lo separaba— se fue con la
/// migración del 22 de septiembre.
///
/// ## Lo que se manda, y lo que NO
///
/// Van tres campos: la votación, el cargo y —si no es en blanco— el candidato.
/// **No va `origen`**, porque el servidor no se lo cree del cuerpo: lo decide la
/// marca firmada de la mesa, *«porque un cliente que puede escribir
/// `origen = 'mesa'` puede falsear de dónde salió un voto»*. Y **no va
/// `sesion_mesa`**: conducir una mesa es una pantalla de la web y de esta app no
/// sale ningún voto asistido, así que aquí todo voto es `propio`.
///
/// `segundos` tampoco se manda. Existe para la auditoría de la mesa —cuánto
/// tardó el niño con alguien delante— y el servidor no se lo cree del todo: lo
/// acota y admite nulo como «no se sabe». Mandarlo desde aquí sería llenar una
/// columna de auditoría de mesas con datos de gente que no votó en una mesa.
Future<Constancia> votar(
  Server server, {
  required int votacionId,
  required int aspiracionId,
  int? candidatoId,
}) async {
  if (!Interruptores.votaciones) {
    throw const RechazoDeLaUrna(
      codigo: 0,
      mensaje: 'Votar desde la app todavía no está disponible en tu colegio.',
    );
  }

  final respuesta = await server.post('/votos/store', {
    'votacion_id': votacionId,
    'aspiracion_id': aspiracionId,
    if (candidatoId != null) 'candidato_id': candidatoId,
  });

  // 201 y no «2xx»: el 200 de un servidor sin desplegar significa otra cosa
  // —reemplazó el voto anterior— y leerlo como éxito sería lo peor que puede
  // pasar aquí. Ver la cabecera.
  if (respuesta.statusCode == 201) {
    final leido = _comoJson(respuesta.body);
    return Constancia.fromJson(leido is Map ? leido : const {});
  }

  throw _rechazo(respuesta);
}

/// El escrutinio de una elección.
///
/// `GET resultados/{id}`, **sin `auth.personal`: la lee el alumno**. Puede venir
/// sin conteos, y eso no es un error — ver [Escrutinio].
Future<Escrutinio> traerElEscrutinio(Server server, int votacionId) async {
  if (!Interruptores.votaciones) {
    throw Exception('Los resultados todavía no están disponibles.');
  }

  final respuesta = await server.get('/resultados/$votacionId');

  if (respuesta.statusCode != 200) {
    throw Exception(motivoDeRechazo(
      respuesta.body,
      respaldo:
          'No se pudieron traer los resultados (HTTP ${respuesta.statusCode}).',
    ));
  }

  final leido = _comoJson(respuesta.body);
  return Escrutinio.fromJson(leido is Map ? leido : const {});
}

/// Qué decirle a quien no pudo votar.
///
/// **El texto del servidor primero.** Sólo cuando cortó sin explicarse entra el
/// respaldo, y el respaldo es por código porque cada uno es una situación
/// distinta y se arregla de otra manera. Ver [RechazoDeLaUrna].
RechazoDeLaUrna _rechazo(dynamic respuesta) {
  final codigo = respuesta.statusCode as int;
  final cuerpo = _comoJson(respuesta.body);

  final delServidor = loQueDijoElServidor(respuesta.body);

  final constancia = cuerpo is Map && cuerpo['voto'] is Map
      ? Constancia.fromJson(cuerpo['voto'])
      : null;

  return RechazoDeLaUrna(
    codigo: codigo,
    mensaje: delServidor ?? _respaldoDe(codigo),
    constancia: constancia,
  );
}

String _respaldoDe(int codigo) {
  switch (codigo) {
    case 409:
      return 'Ya votaste este cargo.';
    case 423:
      return 'La votación no está abierta en este momento.';
    case 403:
      return 'Esta votación no es para ti.';
    case 422:
      return 'Ese voto no se pudo registrar.';
    case 401:
      return 'Tu sesión caducó. Vuelve a entrar.';
    default:
      return 'No se pudo registrar el voto (HTTP $codigo).';
  }
}

dynamic _comoJson(dynamic cuerpo) {
  if (cuerpo is! String || cuerpo.trim().isEmpty) return null;

  try {
    return jsonDecode(cuerpo);
  } catch (_) {
    // Sin `Accept: application/json` el servidor puede contestar su página de
    // error en HTML. Quien llama pone su propio texto.
    return null;
  }
}
