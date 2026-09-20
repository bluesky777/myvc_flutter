/// Las notas que el personal se deja escritas en el recorrido de una persona.
///
/// **Una nota NO es el motivo de una devolución, y por eso vive en otra tabla y
/// en otro modelo.** El motivo pertenece al paso, **lo lee la familia tal cual**
/// y viaja en `PasoDelRecorrido.motivo`; una nota es entre el personal y la
/// familia no la ve nunca. El día que compartan sitio, un comentario interno
/// acaba en el celular de una mamá — está escrito así en
/// `EstacionesController::postNota` y en el 46 §3.3.
///
/// El detalle llega **dentro de la ficha**, en `pasos[].notas_detalle`, nunca en
/// una llamada aparte: una pantalla que preguntara «¿y las notas?» paso por paso
/// no dibujaría la ficha, la dibujaría cuatro segundos después, en un patio con
/// mala señal. Los contadores de ese mismo sitio —`pasos[].notas`— ya los lee
/// `NotasDelPaso` en `EstacionModel.dart`; **esto es el texto, no el número**.
library;

import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Una nota suelta: quién la escribió, cuándo, y si pide que alguien haga algo.
///
/// Sale de `notas_estacion` a través de `EstacionesController::notasDeLaFicha`.
/// **Los campos que este modelo lee son los del controlador de verdad**, que
/// manda dos que el contrato del 46 no listaba —[resuelta] y
/// [puedoResolverla]— y que son justo los que gobiernan el botón de la pantalla.
class NotaDeEstacion {
  const NotaDeEstacion({
    required this.id,
    this.texto,
    this.reservada = false,
    this.pendiente = false,
    this.resuelta = false,
    this.de,
    this.cuando,
    this.puedoResolverla = false,
  });

  /// El id de la fila en `notas_estacion`. Es lo que lleva
  /// `PUT estaciones/nota/{id}/resuelta`, así que sin él no hay botón.
  final int id;

  /// Lo escrito, **o null cuando es reservada y no te toca leerlo**.
  ///
  /// Que sea null no quiere decir que no haya nota: la nota se cuenta igual en
  /// el globo. **Esconder que una nota existe es peor que esconder su
  /// contenido** —quien ve el globo y no puede abrirlo sabe a quién
  /// preguntarle; quien no ve nada, no pregunta—. Ver [elTextoNoEsParaTi].
  final String? texto;

  /// Si su texto solo lo leen unos pocos.
  ///
  /// **Quiénes lo deciden el servidor y no esta app**: el 46 §3.3 decía
  /// «cualquiera del personal, salvo las reservadas» y **no decía quién sí**, y
  /// el controlador cerró el hueco con el conjunto más pequeño que hace la
  /// regla coherente —quien la escribió y quien puede darla por resuelta—.
  /// Aquí llega ya resuelto: el texto viene o no viene.
  final bool reservada;

  /// Si pide que alguien haga algo, frente a la que solo deja constancia.
  final bool pendiente;

  /// Si ya alguien la dio por resuelta. Es `resuelta_at IS NOT NULL` en el
  /// servidor, traducido a un sí o un no antes de salir.
  final bool resuelta;

  /// Quién la escribió, con su nombre. Puede faltar: de las 22 cuentas
  /// administrativas del colegio medido **ninguna tiene ficha en `profesores`**,
  /// y el servidor se cae al `username` cuando puede.
  final String? de;

  /// Cuándo se escribió, tal como lo manda el servidor (`Y-m-d H:i:s`).
  ///
  /// **No se convierte a «hace 2 min» aquí**: el reloj del teléfono de un
  /// docente en el patio no es una fuente de verdad, y esta capa no inventa
  /// husos horarios. Quien la pinte decide.
  final String? cuando;

  /// Si **tú** puedes darla por resuelta. **Lo calcula el servidor**, con
  /// `Autoriza::puedeResolverNotaDeEstacion`, y por eso viaja en la respuesta.
  ///
  /// La app es **una sola para dieciséis colegios** y no sabe los roles de
  /// quien mira: deducirlo aquí sería encender un botón que luego contesta 403,
  /// o apagárselo a quien sí puede. Ninguna de las dos se puede arreglar desde
  /// el teléfono.
  final bool puedoResolverla;

  /// La que todavía le estorba a alguien: pide algo y nadie lo ha dado por
  /// hecho. Es la que pinta el globo en ambar en vez de en pizarra.
  bool get sinResolver => pendiente && !resuelta;

  /// Hay nota y **no** puedes leerla. Distinto de una nota sin texto, que no
  /// existe: el servidor rechaza con 422 una nota vacía.
  bool get elTextoNoEsParaTi => reservada && texto == null;

  /// Si la pantalla debe **encender** el botón de darla por resuelta.
  ///
  /// Las dos condiciones, y ninguna sobra: una nota ya resuelta no se resuelve
  /// dos veces —el servidor lo aguanta con `COALESCE`, pero el botón mentiría—
  /// y una que no puedes resolver se enseña **apagada con el motivo**, no
  /// escondida. Ver `docs/estaciones.md` §2.10.
  bool get puedeDarsePorResuelta => sinResolver && puedoResolverla;

  factory NotaDeEstacion.fromJson(Map<String, dynamic> json) => NotaDeEstacion(
        id: enteroO(json['id']),
        texto: _elTextoDe(json['texto']),
        reservada: _verdad(json['reservada']),
        pendiente: _verdad(json['pendiente']),
        resuelta: _verdad(json['resuelta']),
        de: _elTextoDe(json['de']),
        cuando: _elTextoDe(json['cuando']) ?? _elTextoDe(json['created_at']),
        puedoResolverla: _verdad(json['puedo_resolverla']),
      );
}

/// Las notas de **un** paso de la ficha, leídas de su `notas_detalle`.
///
/// Devuelve la lista vacía cuando no hay ninguna o cuando la clave no vino: una
/// versión del servidor anterior a esto contesta la ficha sin `notas_detalle`, y
/// eso no es un error que deba reventar la pantalla.
List<NotaDeEstacion> notasDelPaso(dynamic jsonDelPaso) {
  final crudo = jsonDelPaso is Map ? jsonDelPaso['notas_detalle'] : jsonDelPaso;

  if (crudo is! List) return const [];

  final salida = <NotaDeEstacion>[];
  for (final una in crudo) {
    if (una is Map) {
      salida.add(NotaDeEstacion.fromJson(Map<String, dynamic>.from(una)));
    }
  }
  return salida;
}

/// Todas las notas de una ficha, **agrupadas por el numero de la estacion**.
///
/// ## Por qué se devuelven TODAS y no solo las de la estacion que atiende
///
/// Es la razón de ser del módulo: *«puede ser que se adelante el tesorero a
/// poner una nota antes de empezar el proceso»*. El tesorero sabe el lunes que
/// esa familia tiene un saldo pendiente y la estación 5 se atiende el sábado.
/// Quien atiende Documentos tiene que ver esa nota **antes** de mandar a la
/// familia a hacer cuatro colas, así que la ficha las trae todas y esto las
/// entrega todas.
///
/// La clave es `pasos[].nro`, que es `requisitos_matricula.orden` — el número
/// impreso en la cartulina—. **El 0 es una clave válida y no un hueco**: un
/// colegio que no haya numerado sus pasos los tiene todos en la estación 0, que
/// es lo que hay hoy en la copia de desarrollo.
Map<int, List<NotaDeEstacion>> notasDeLaFicha(dynamic jsonDeLaFicha) {
  final pasos = jsonDeLaFicha is Map ? jsonDeLaFicha['pasos'] : jsonDeLaFicha;

  if (pasos is! List) return const {};

  final salida = <int, List<NotaDeEstacion>>{};
  for (final paso in pasos) {
    if (paso is! Map) continue;

    final suyas = notasDelPaso(paso);
    if (suyas.isEmpty) continue;

    salida
        .putIfAbsent(enteroO(paso['nro']), () => <NotaDeEstacion>[])
        .addAll(suyas);
  }
  return salida;
}

/// Las notas de toda la ficha en una sola lista, en el orden en que llegaron.
///
/// El servidor las manda ya ordenadas por `created_at, id`, así que **no se
/// vuelven a ordenar aquí**: la primera que se escribió es la primera que se
/// lee, y eso cuenta una historia que reordenar por estación rompería.
List<NotaDeEstacion> todasLasNotas(dynamic jsonDeLaFicha) {
  final pasos = jsonDeLaFicha is Map ? jsonDeLaFicha['pasos'] : jsonDeLaFicha;

  if (pasos is! List) return const [];

  final salida = <NotaDeEstacion>[];
  for (final paso in pasos) {
    if (paso is Map) salida.addAll(notasDelPaso(paso));
  }
  return salida;
}

/// El [texto] de `JsonBackend`, llamado desde fuera de la clase.
///
/// Existe por una tontería del lenguaje que no conviene resolver renombrando el
/// campo: **la nota tiene un campo que se llama `texto`**, igual que la función,
/// y dentro de un `factory` el nombre de un miembro de instancia gana y el
/// analizador corta con `instance_member_access_from_factory`. Renombrar el
/// campo a otra cosa alejaría el modelo de la clave que manda el servidor, que
/// es `texto`; renombrar la llamada no cuesta nada.
String? _elTextoDe(dynamic valor) => texto(valor);

/// Un booleano que puede llegar como `1`, `"1"`, `true` o `"true"`.
///
/// La misma razón que [enteroO], y no una precaución: los listados del backend
/// salen de `DB::select`, así que **PDO decide el tipo** y un `tinyint` llega
/// unas veces entero y otras cadena. `notas_estacion.pendiente` y `.reservada`
/// son `tinyint`, y el controlador los saca con `(bool)`, pero `resuelta` sale
/// de comparar una fecha y `puedo_resolverla` de una función de PHP: tres
/// caminos distintos hasta el mismo JSON.
bool _verdad(dynamic valor) {
  if (valor == null) return false;
  if (valor is bool) return valor;
  final crudo = '$valor'.trim().toLowerCase();
  return crudo == '1' || crudo == 'true' || crudo == 'si' || crudo == 'sí';
}
