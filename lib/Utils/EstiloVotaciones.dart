import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';

/// Cómo se ve el módulo de votaciones, y por qué casi nada es nuevo.
///
/// ## Aquí NO hay color de colegio y NO hay modo oscuro
///
/// Es **una sola app para los dieciséis**, y los colores son los de la casa:
/// el morado de [PaletaEstaciones.primario] —que es el mismo `kPrimaryColor` de
/// siempre— y su familia. No se añade `ThemeData` ni `darkTheme`: una urna que
/// cambia de color según el colegio es una urna que alguien tiene que mantener
/// dieciséis veces, y un modo oscuro que nadie ha pedido es una segunda pantalla
/// que hay que revisar entera cada vez que se toca la primera.
///
/// ## Las tarjetas llevan borde y no sombra
///
/// Está escrito en [PaletaEstaciones.borde] y vale igual aquí: se vota en el
/// patio, en el salón, con sol en la cara, y **una sombra a media luz no se ve,
/// un borde sí**. El módulo no estrena ni una elevación.
///
/// ## Lo que sí es propio de aquí, y es poco
///
/// Dos tonos y dos medidas, y los dos tonos vienen de una pantalla que ya
/// existe: [fondo] es el gris del muro (`MuroScreen`) y no el de las estaciones,
/// porque la tarjeta de la votación **nace encima del muro** y el tarjetón se
/// abre desde ahí — que las dos pantallas compartan el fondo es lo que hace que
/// se lean como un sitio y no como dos apps.
class EstiloVotaciones {
  EstiloVotaciones._();

  /// El morado de la app, y con él todo lo demás.
  static const Color morado = PaletaEstaciones.primario;

  /// Para texto e iconos morados **sobre fondo claro**: el morado sobre blanco
  /// se queda en 3,9:1 y no llega al 4,5:1 que pide el texto normal.
  static const Color moradoOscuro = PaletaEstaciones.primarioOscuro;

  /// El relleno suave: la chapa del número, el fondo de una barra vacía.
  static const Color moradoSuave = PaletaEstaciones.primarioSuave;

  /// El gris de detrás. **El del muro**, ver la cabecera.
  static const Color fondo = Color(0xFFF4F5F7);

  static const Color tinta = PaletaEstaciones.tinta;
  static const Color tintaSuave = PaletaEstaciones.tintaSuave;
  static const Color tintaApagada = PaletaEstaciones.tintaApagada;

  /// El borde de una tarjeta blanca: `rgba(0,0,0,.07)`.
  static const Color borde = Color(0x12000000);

  /// El radio de una tarjeta. Uno solo para todo el módulo: dos radios
  /// parecidos en la misma pantalla se leen como un descuido.
  static const double radio = 12;

  /// Lo que decide algo se toca de pie, con una mano. Mismo número que en las
  /// estaciones, y por lo mismo.
  static const double alturaDeBoton = PaletaEstaciones.alturaDeBoton;

  /// El avatar del tarjetón. Grande a propósito: **la cara es el dato** con el
  /// que un muchacho de sexto reconoce a quien va a votar, más que el nombre.
  static const double radioDeAvatar = 38; // 76 px de lado

  /// La decoración de una tarjeta blanca del módulo. En un sitio para que no se
  /// escriba cinco veces y se corrija cuatro.
  static BoxDecoration get tarjeta => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde),
      );

  /// La misma tarjeta cuando está elegida: el borde se hace morado y grueso.
  ///
  /// **El borde y no el relleno.** Un relleno morado claro detrás de un nombre
  /// le quita contraste al texto justo cuando más falta hace leerlo; un borde de
  /// dos píxeles se ve a un metro y no toca la legibilidad. Y nunca va solo: la
  /// tarjeta elegida lleva además el chulo y la palabra.
  static BoxDecoration get tarjetaElegida => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: morado, width: 2),
      );
}

/// En qué va la urna, con su color, su icono y su palabra.
///
/// **El color nunca va solo**, que es la regla de [PaletaEstaciones]: se vota al
/// sol, y quien no distingue el rojo del verde está en cualquier salón de
/// cuarenta. Por eso esto no expone un color suelto, expone los tres juntos.
enum EstadoDeLaUrna {
  abierta,
  pausada,
  cerrada;

  /// **Lo que se sabe desde aquí, y la app no lo usa para negar nada.** Quien
  /// decide de verdad es `votos/store`: mira además el censo, las fechas y su
  /// propio reloj. Esto sirve para pintar la etiqueta y para no ofrecer un botón
  /// que va a dar 423 seguro.
  static EstadoDeLaUrna de({required bool enAccion, required bool bloqueada}) {
    if (bloqueada) return EstadoDeLaUrna.pausada;
    if (!enAccion) return EstadoDeLaUrna.cerrada;
    return EstadoDeLaUrna.abierta;
  }

  Color get color => switch (this) {
        EstadoDeLaUrna.abierta => PaletaEstaciones.verde,
        EstadoDeLaUrna.pausada => PaletaEstaciones.ambar,
        EstadoDeLaUrna.cerrada => PaletaEstaciones.gris,
      };

  Color get fondo => switch (this) {
        EstadoDeLaUrna.abierta => PaletaEstaciones.verdeFondo,
        EstadoDeLaUrna.pausada => PaletaEstaciones.ambarFondo,
        EstadoDeLaUrna.cerrada => const Color(0xFFEDEDF2),
      };

  IconData get icono => switch (this) {
        EstadoDeLaUrna.abierta => Icons.how_to_vote,
        EstadoDeLaUrna.pausada => Icons.pause_circle_outline,
        EstadoDeLaUrna.cerrada => Icons.lock_outline,
      };

  String get palabra => switch (this) {
        EstadoDeLaUrna.abierta => 'Abierta',
        EstadoDeLaUrna.pausada => 'Pausada',
        EstadoDeLaUrna.cerrada => 'Cerrada',
      };
}

/// Si un cargo de la papeleta ya está votado o falta.
///
/// Dos estados y no uno, con su icono y su palabra cada uno: una lista donde los
/// votados salen en verde y los que faltan **no salen de ningún color** obliga a
/// deducir por ausencia, y eso con cuatro cargos en la pantalla ya no se hace.
enum EstadoDelCargo {
  votado,
  falta;

  static EstadoDelCargo de(bool votado) =>
      votado ? EstadoDelCargo.votado : EstadoDelCargo.falta;

  Color get color => switch (this) {
        EstadoDelCargo.votado => PaletaEstaciones.verde,
        EstadoDelCargo.falta => EstiloVotaciones.moradoOscuro,
      };

  Color get fondo => switch (this) {
        EstadoDelCargo.votado => PaletaEstaciones.verdeFondo,
        EstadoDelCargo.falta => EstiloVotaciones.moradoSuave,
      };

  IconData get icono => switch (this) {
        EstadoDelCargo.votado => Icons.check_circle,
        EstadoDelCargo.falta => Icons.radio_button_unchecked,
      };

  String get palabra => switch (this) {
        EstadoDelCargo.votado => 'Votado',
        EstadoDelCargo.falta => 'Te falta',
      };
}

/// La etiqueta de estado: color, icono y palabra, juntos y sin separarse.
///
/// Un solo sitio para las cinco o seis que lleva el módulo. Que sea un widget y
/// no tres constantes es lo que impide que alguien coja el color y se deje el
/// icono.
class EtiquetaDeEstado extends StatelessWidget {
  const EtiquetaDeEstado({
    super.key,
    required this.color,
    required this.fondo,
    required this.icono,
    required this.palabra,
  });

  EtiquetaDeEstado.urna(EstadoDeLaUrna estado, {super.key})
      : color = estado.color,
        fondo = estado.fondo,
        icono = estado.icono,
        palabra = estado.palabra;

  EtiquetaDeEstado.cargo(EstadoDelCargo estado, {super.key})
      : color = estado.color,
        fondo = estado.fondo,
        icono = estado.icono,
        palabra = estado.palabra;

  final Color color;
  final Color fondo;
  final IconData icono;
  final String palabra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            palabra,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// El número del candidato, en una chapa.
///
/// Redonda y con el número dentro, como la del pecho de una camiseta: en el
/// tarjetón de papel el número es lo que se marca, así que en la pantalla tiene
/// que ser igual de reconocible que la cara.
///
/// Se pinta como texto y no como entero porque `vt_candidatos.numero` es
/// `varchar`: un colegio puede escribir «01» y el cero no se puede perder.
class ChapaDeNumero extends StatelessWidget {
  const ChapaDeNumero({super.key, required this.numero, this.lado = 30});

  final String numero;
  final double lado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: EstiloVotaciones.moradoSuave,
        shape: BoxShape.circle,
        border: Border.all(color: EstiloVotaciones.morado, width: 1.5),
      ),
      child: Text(
        numero,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: EstiloVotaciones.moradoOscuro,
          fontWeight: FontWeight.w700,
          fontSize: lado * 0.45,
        ),
      ),
    );
  }
}

/// Un aviso en ámbar: lo que hay que leer antes de seguir.
///
/// Con icono y con texto, nunca sólo el color de fondo.
class AvisoAmbar extends StatelessWidget {
  const AvisoAmbar({
    super.key,
    required this.texto,
    this.icono = Icons.warning_amber_rounded,
  });

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaletaEstaciones.ambarFondo,
        borderRadius: BorderRadius.circular(EstiloVotaciones.radio),
        border: Border.all(color: PaletaEstaciones.ambar.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: PaletaEstaciones.ambar),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: PaletaEstaciones.ambar,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El avatar de un candidato, o el círculo del voto en blanco.
///
/// **El blanco no pasa por `AvatarPersona` y ahí está el motivo de que esto
/// exista.** El servidor le manda `foto_nombre: 'voto_en_blanco.jpg'`, un
/// archivo del front web que no está en `images/perfil`; `AvatarPersona` no
/// falla con eso, se cae a las iniciales y pinta **«VE»** dentro de un círculo
/// morado, que se lee como una persona que no existe. El blanco lleva su propio
/// círculo, con un icono y en gris.
class CirculoDeCandidato extends StatelessWidget {
  const CirculoDeCandidato({
    super.key,
    required this.nombre,
    this.fotoNombre,
    this.blanco = false,
    this.radio = EstiloVotaciones.radioDeAvatar,
  });

  final String nombre;
  final String? fotoNombre;
  final bool blanco;
  final double radio;

  @override
  Widget build(BuildContext context) {
    if (blanco) {
      return Container(
        width: radio * 2,
        height: radio * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDF2),
          shape: BoxShape.circle,
          border: Border.all(color: EstiloVotaciones.borde),
        ),
        child: Icon(
          Icons.check_box_outline_blank,
          size: radio,
          color: PaletaEstaciones.gris,
        ),
      );
    }

    // Con foto: [AvatarPersona] tal cual, que ya cachea en disco y se cae a las
    // iniciales cuando no hay foto o la red falla.
    return AvatarPersona(nombre: nombre, fotoNombre: fotoNombre, radio: radio);
  }
}
