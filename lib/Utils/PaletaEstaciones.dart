import 'package:flutter/material.dart';

/// Los colores del día de matrículas, y por qué son un archivo aparte.
///
/// `constantes.dart` tiene cuatro colores que usa media app. Éstos son doce y
/// los usan tres pantallas, así que viven aquí: meterlos allí obligaría a tocar
/// un archivo compartido por cada ajuste de un módulo que todavía está apagado.
///
/// **Salen de la maqueta de las doce pantallas**, no de una elección nueva, y
/// [primario] es el mismo `kPrimaryColor` de siempre. Están aquí y no repartidos
/// por las pantallas porque un tono escrito tres veces se corrige dos.
///
/// ## La regla que manda sobre todas: el color NUNCA va solo
///
/// `docs/estaciones.md` §3: *«cuatro estados, y ninguno se distingue solo por el
/// color: cada uno lleva icono y palabra»*. Es por el sol del patio —donde un
/// verde y un ámbar a media luz son el mismo gris— y por **quien no distingue el
/// rojo del verde, que en un claustro de cincuenta docentes es uno o dos**. Por
/// eso [EstadoDelPaso] no expone un color suelto: expone el color, el icono y la
/// palabra juntos, y quien los use no puede coger solo uno sin darse cuenta.
class PaletaEstaciones {
  PaletaEstaciones._();

  /// El morado de la app. Es el mismo `kPrimaryColor`, repetido aquí a
  /// propósito para que estas pantallas no importen dos ficheros de color.
  static const Color primario = Color(0xFF6A62B7);

  /// Para texto y iconos morados **sobre fondo claro**. El [primario] sobre
  /// blanco se queda en 3,9:1 y no llega al 4,5:1 que pide el texto normal;
  /// éste llega a 7,1:1. No es un tono decorativo: es el que hace legible.
  static const Color primarioOscuro = Color(0xFF4F4899);

  /// El relleno suave: chips, avatares sin foto, el número de una estación que
  /// no es la que atiendes.
  static const Color primarioSuave = Color(0xFFEFECFB);

  /// El fondo de la pantalla. Gris con una gota de morado, no gris neutro.
  static const Color fondo = Color(0xFFF2F1F7);

  /// El negro de la tipografía, que no es negro puro.
  static const Color tinta = Color(0xFF1A1826);

  /// El segundo renglón de una tarjeta: el grupo, la hora, el sitio.
  static const Color tintaSuave = Color(0xFF5C5870);

  /// Lo que está ahí pero no pide nada: un rótulo auxiliar.
  static const Color tintaApagada = Color(0xFF8B8799);

  /// El borde de una tarjeta. Nunca una sombra fuerte: el patio tiene sol y una
  /// sombra no se ve, un borde sí.
  static const Color borde = Color(0xFFE2E0EC);

  /// Un paso cumplido.
  static const Color verde = Color(0xFF1E7A55);
  static const Color verdeTinta = Color(0xFF14603F);
  static const Color verdeFondo = Color(0xFFE6F2EC);

  /// Un paso con observación, o algo que hay que mirar antes de seguir.
  static const Color ambar = Color(0xFF8A4B00);
  static const Color ambarFondo = Color(0xFFFBF0E0);

  /// Un paso devuelto o bloqueado.
  static const Color rojo = Color(0xFFB8342A);
  static const Color rojoTinta = Color(0xFF93291F);
  static const Color rojoFondo = Color(0xFFFBE9E7);

  /// Un paso que todavía no ha empezado.
  static const Color gris = Color(0xFF6E6B7B);

  /// El globo de notas cuando **hay algo escrito** y está todo resuelto.
  static const Color globoPizarra = Color(0xFF2B2740);

  /// El globo cuando **hay algo sin resolver**. Léelo antes de seguir.
  static const Color globoAmbar = Color(0xFFB26A00);

  /// Lo que decide algo se toca de pie, con una mano, a veces con guantes en
  /// tierra fría. `docs/estaciones.md` §3 pide 56.
  static const double alturaDeBoton = 56;
}

/// En qué va un paso del recorrido.
///
/// **El servidor manda el estado como texto y esta app no lo cablea**: un
/// colegio puede tener un vocabulario que esta versión no conoce, y
/// `docs/estaciones.md` §2.8 dice qué hacer entonces —pintarlo con el control
/// genérico en vez de romperse—. Por eso [deTexto] tiene un caso por defecto
/// que **no lanza**: cae en [pendiente], que es el estado que no promete nada.
enum EstadoDelPaso {
  cumplido,
  observado,
  devuelto,
  pendiente;

  /// Lo que manda el servidor, convertido sin fiarse de las mayúsculas.
  ///
  /// **Las mayúsculas importan aquí y es un hecho medido, no una precaución.**
  /// En el backend, `requisitos_alumno.estado` es un `varchar` sin lista
  /// cerrada: el valor por defecto de la tabla es `'Falta'` y
  /// `AlumnosController:899` inserta `"falta"` en minúscula. Las dos formas de
  /// nacer una fila ya no se ponen de acuerdo, así que comparar tal cual sería
  /// leer mal a la mitad de las filas. Ver `docs/backend-pendiente.md` §8.
  /// ## La regla NO es una lista blanca, y eso se corrigió leyendo el servidor
  ///
  /// Esta función empezó siendo *«cumple, cumplido u ok son cumplido; lo demás,
  /// pendiente»*, y **estaba mal**. `RequisitosController::getRecorrido` lo
  /// tiene escrito en su SQL, con su motivo:
  ///
  /// > *«**«Cumplido» es cualquier estado que NO sea el de partida.** El seed
  /// > trae `falta` y el legacy escribe lo que la pantalla mande, así que una
  /// > lista blanca de estados buenos se quedaría corta en silencio el día que
  /// > un colegio escriba «Entregado» con mayúscula.»*
  ///
  /// Con una lista blanca, un colegio que escriba «Entregado» vería ese paso en
  /// gris **para siempre y sin que nada fallara**. Así que la regla se invierte:
  /// lo seguro es que `falta` —y una fila que no existe— significan que no está;
  /// lo demás está, salvo las dos palabras que sabemos que significan otra cosa.
  ///
  /// **Esto es alinearse con el servidor, no imitarlo por gusto**: si las dos
  /// mitades contestan distinto a la misma fila, la cola y la ficha se
  /// contradicen delante de la familia.
  ///
  /// [hayMarca] es si existe fila en `requisitos_alumno`. Sin ella no hay nada
  /// hecho, y es el caso más común de la mañana: el de quien acaba de llegar.
  static EstadoDelPaso deTexto(String? crudo, {bool hayMarca = true}) {
    final limpio = (crudo ?? '').trim().toLowerCase();

    if (!hayMarca || limpio.isEmpty || limpio == 'falta') {
      return EstadoDelPaso.pendiente;
    }

    if (limpio == 'devuelto' ||
        limpio == 'rechazado' ||
        limpio == 'bloqueado') {
      return EstadoDelPaso.devuelto;
    }
    if (limpio == 'observado' ||
        limpio == 'observacion' ||
        limpio == 'observación' ||
        limpio == 'revision' ||
        limpio == 'revisión') {
      return EstadoDelPaso.observado;
    }

    // Cualquier otra cosa que alguien escribió a propósito: está hecho.
    return EstadoDelPaso.cumplido;
  }

  Color get color => switch (this) {
        EstadoDelPaso.cumplido => PaletaEstaciones.verde,
        EstadoDelPaso.observado => PaletaEstaciones.ambar,
        EstadoDelPaso.devuelto => PaletaEstaciones.rojo,
        EstadoDelPaso.pendiente => PaletaEstaciones.gris,
      };

  IconData get icono => switch (this) {
        EstadoDelPaso.cumplido => Icons.check_circle,
        EstadoDelPaso.observado => Icons.error_outline,
        EstadoDelPaso.devuelto => Icons.undo,
        EstadoDelPaso.pendiente => Icons.circle_outlined,
      };

  /// La palabra que acompaña al icono. Nunca va sola tampoco: es la mitad de la
  /// regla de arriba.
  String get palabra => switch (this) {
        EstadoDelPaso.cumplido => 'Cumple',
        EstadoDelPaso.observado => 'Con observación',
        EstadoDelPaso.devuelto => 'Devuelto',
        EstadoDelPaso.pendiente => 'Pendiente',
      };
}
