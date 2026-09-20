import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/FichaDeEstacionScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Los que me llegan — pantalla 02 de `docs/estaciones.md`.
///
/// ## Esto es una CONSULTA, no una bandeja de avisos
///
/// Es la decisión que sostiene el módulo entero (§2.1). La cola de la estación 3
/// no se llena con los mensajes que le manda la 2: **se calcula** —«los que
/// cerraron el paso anterior y no han cerrado el mío»— cada vez que se pide.
///
/// La diferencia se ve el día que algo falla. Una bandeja con un aviso perdido
/// deja a una familia **invisible para siempre**, y nadie sabe que falta; una
/// consulta con un aviso perdido la deja en la fila **igual**, solo que la
/// pantalla tardó en enterarse. Por eso aquí **no hay «marcar como leído» ni
/// nada que vaciar**: no hay nada que vaciar, hay una pregunta que se repite.
///
/// ## Preguntar cada veinte segundos no puede costar lo que cuesta pedir la cola
///
/// Se sondea [traerLaHuella] —unos 300 bytes— y **solo cuando se mueve** se pide
/// la cola de verdad. Es el patrón medido de `8myvc/docs/migracion/34`, donde la
/// misma idea bajó una pregunta de 121 KB a 345 bytes. Con diez estaciones
/// abiertas ocho horas son unas 14.400 peticiones de 300 bytes al día: menos que
/// abrir la app dos veces.
///
/// Esto corre sobre un hosting compartido de un núcleo, así que la diferencia
/// entre sondear la huella y sondear la cola es la diferencia entre que esto se
/// pueda desplegar y que no.
class ColaDeEstacionScreen extends StatefulWidget {
  const ColaDeEstacionScreen({
    super.key,
    required this.estacion,
    this.servidor,
  });

  final Estacion estacion;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  @override
  State<ColaDeEstacionScreen> createState() => _ColaDeEstacionScreenState();
}

class _ColaDeEstacionScreenState extends State<ColaDeEstacionScreen> {
  late final Server server = widget.servidor ?? Server();

  List<PersonaEnCola> cola = [];
  bool cargando = true;
  String? error;

  Timer? _sondeo;
  String? _ultimaHuella;
  DateTime? _ultimaVezQueSeMovio;

  /// Cada cuánto se pregunta «¿ha llegado alguien?».
  ///
  /// Veinte segundos es lo que tarda una familia en cruzar el patio. Menos no
  /// llega antes; más se nota en la fila.
  static const Duration _cadaCuanto = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_cola_abierta');
    _cargar();
    _sondeo = Timer.periodic(_cadaCuanto, (_) => _mirarSiCambio());
  }

  @override
  void dispose() {
    // Si esto no se cancela, la pantalla sigue preguntando después de cerrarse
    // y multiplica por estaciones abiertas una carga que no sirve a nadie.
    _sondeo?.cancel();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traida = await traerLaCola(server, widget.estacion.nro);
      setState(() {
        cola = traida;
        cargando = false;
        _ultimaVezQueSeMovio = DateTime.now();
      });
    } catch (err) {
      setState(() {
        error = '$err'.replaceFirst('Exception: ', '');
        cargando = false;
      });
    }
  }

  /// El sondeo barato: pregunta la huella y **solo si cambió** pide la cola.
  Future<void> _mirarSiCambio() async {
    if (!mounted || cargando) return;

    try {
      final huella = await traerLaHuella(server);
      final mia = huella[widget.estacion.nro];
      if (mia == null) return;

      if (_ultimaHuella != null && _ultimaHuella == mia) {
        // No se ha movido nada: no se pide la cola. Esto es todo el ahorro.
        return;
      }
      _ultimaHuella = mia;
      await _cargar();
    } catch (_) {
      // Un sondeo que falla **no rompe la pantalla ni enseña un error**: quien
      // atiende tiene una fila delante y la cola que ya está en pantalla sigue
      // siendo buena. El indicador de frescura de arriba es el que lo cuenta.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: widget.estacion.nombre,
          subtitulo: _subtitulo(),
          conFlecha: true,
        ),
      ),
      body: ColumnaDeFicha(
        child: Column(
          children: [
            _LaFrescura(desde: _ultimaVezQueSeMovio, cargando: cargando),
            Expanded(child: _cuerpo()),
            _elPie(),
          ],
        ),
      ),
    );
  }

  String _subtitulo() {
    final donde = widget.estacion.donde;
    final cuantos =
        cola.length == 1 ? '1 esperando' : '${cola.length} esperando';
    if (donde == null || donde.isEmpty) {
      return 'Estación ${widget.estacion.nro} · $cuantos';
    }
    return 'Estación ${widget.estacion.nro} · $donde · $cuantos';
  }

  Widget _cuerpo() {
    if (cargando && cola.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    if (cola.isEmpty) {
      return const _Centrado(
        icono: Icons.done_all,
        // No es un error ni un hueco: es la mejor noticia del día.
        texto: 'Nadie esperando.\n\nCuando la estación anterior cierre el paso '
            'de alguien, aparece aquí solo.',
      );
    }

    return RefreshIndicator(
      onRefresh: Analitica.refresco('estacion_cola', _cargar),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: cola.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _TarjetaDeLaCola(
            persona: cola[i],
            esElPrimero: i == 0,
            alTocar: () => _abrirFicha(cola[i]),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFicha(PersonaEnCola persona) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ficha-de-estacion'),
        builder: (_) => FichaDeEstacionScreen(
          estacion: widget.estacion,
          persona: persona,
          servidor: widget.servidor,
        ),
      ),
    );
    // Siempre al volver de la ficha, como dice §2.2: la cola se vuelve a pedir
    // aunque el sondeo no toque todavía.
    if (mounted) await _cargar();
  }

  Widget _elPie() {
    if (PendientesEstaciones.escanearElCodigo) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        child: SizedBox(
          height: PaletaEstaciones.alturaDeBoton,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear la hoja de ruta'),
          ),
        ),
      );
    }

    return const _Apagado(
      titulo: 'Escanear la hoja de ruta',
      // Se dice el motivo entero. Quien lo lee es quien puede decidir
      // encenderlo, y «no disponible» no se puede decidir.
      motivo: 'La cámara todavía no está escrita. El código es el mismo del '
          'formulario de inscripción, que ya funciona: mientras tanto, busca a '
          'la persona en esta lista.',
    );
  }
}

/// «Al día · se actualizó hace N segundos».
///
/// Existe porque el sondeo puede fallar en silencio —el patio tiene mala
/// señal— y **una cola vieja se lee igual que una cola al día**. Esta línea es
/// lo único que distingue las dos.
class _LaFrescura extends StatelessWidget {
  const _LaFrescura({required this.desde, required this.cargando});

  final DateTime? desde;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final hace = desde == null ? null : DateTime.now().difference(desde!);
    final vieja = hace != null && hace.inMinutes >= 2;

    final color = cargando
        ? PaletaEstaciones.tintaApagada
        : vieja
            ? PaletaEstaciones.ambar
            : PaletaEstaciones.verde;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            _elTexto(hace),
            style: const TextStyle(
              fontSize: 12.5,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
        ],
      ),
    );
  }

  String _elTexto(Duration? hace) {
    if (cargando) return 'Preguntando…';
    if (hace == null) return 'Sin preguntar todavía';
    if (hace.inSeconds < 30) return 'Al día';
    if (hace.inMinutes < 1) return 'Al día · hace ${hace.inSeconds} segundos';
    if (hace.inMinutes == 1) return 'Se actualizó hace 1 minuto';
    return 'Se actualizó hace ${hace.inMinutes} minutos';
  }
}

/// Alguien de la fila.
class _TarjetaDeLaCola extends StatelessWidget {
  const _TarjetaDeLaCola({
    required this.persona,
    required this.esElPrimero,
    required this.alTocar,
  });

  final PersonaEnCola persona;
  final bool esElPrimero;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border(
              top: const BorderSide(color: PaletaEstaciones.borde),
              right: const BorderSide(color: PaletaEstaciones.borde),
              bottom: const BorderSide(color: PaletaEstaciones.borde),
              // El siguiente de la fila lleva una banda morada a la izquierda:
              // con sol en la cara, el borde grueso se ve antes que el chip.
              left: BorderSide(
                color: esElPrimero
                    ? PaletaEstaciones.primario
                    : PaletaEstaciones.borde,
                width: esElPrimero ? 4 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _ElAvatarConSuGlobo(persona: persona),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: PaletaEstaciones.tinta,
                      ),
                    ),
                    if (persona.grupo != null && persona.grupo!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        persona.esAspirante
                            ? '${persona.grupo} · aspirante'
                            : persona.grupo!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PaletaEstaciones.tintaSuave,
                        ),
                      ),
                    ],
                    if (persona.devueltoAntes || persona.tieneNotas) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (persona.devueltoAntes)
                            const _Chip(
                              texto: 'devuelto una vez',
                              color: PaletaEstaciones.rojoTinta,
                              fondo: PaletaEstaciones.rojoFondo,
                            ),
                          if (persona.tieneNotas)
                            _Chip(
                              texto: _textoDeLasNotas(),
                              color: PaletaEstaciones.ambar,
                              fondo: PaletaEstaciones.ambarFondo,
                              icono: Icons.chat_bubble_outline,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (esElPrimero)
                    const _Chip(
                      texto: 'el siguiente',
                      color: PaletaEstaciones.primarioOscuro,
                      fondo: PaletaEstaciones.primarioSuave,
                    ),
                  if (persona.llegoHace != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      persona.llegoHace!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PaletaEstaciones.tintaSuave,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _textoDeLasNotas() {
    final cuantas =
        persona.notasTotal == 1 ? '1 nota' : '${persona.notasTotal} notas';
    if (persona.notasPendientes == 0) return cuantas;
    return '$cuantas · ${persona.notasPendientes} sin resolver';
  }
}

/// La foto, con el globo de notas encima.
///
/// **La foto y no un desplegable ni unas iniciales a secas**: en una fila con
/// dos hermanos apellidados igual, la cara es lo que distingue. [AvatarPersona]
/// ya cae en las iniciales cuando no hay foto.
class _ElAvatarConSuGlobo extends StatelessWidget {
  const _ElAvatarConSuGlobo({required this.persona});

  final PersonaEnCola persona;

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarPersona(
      nombre: persona.nombreCompleto,
      fotoNombre: persona.fotoNombre,
      radio: 22,
    );

    if (!persona.tieneNotas) return avatar;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            top: -6,
            right: -8,
            child: _GloboDeNotas(
              cuantas: persona.notasTotal,
              algoSinResolver: persona.notasPendientes > 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// El bocadillo con el número.
///
/// **Se distingue de los estados del paso por su silueta, no por su color**:
/// ninguno de los otros indicadores tiene forma de bocadillo. Ámbar si hay algo
/// sin resolver, pizarra si solo hay algo escrito.
class _GloboDeNotas extends StatelessWidget {
  const _GloboDeNotas({required this.cuantas, required this.algoSinResolver});

  final int cuantas;
  final bool algoSinResolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: algoSinResolver
            ? PaletaEstaciones.globoAmbar
            : PaletaEstaciones.globoPizarra,
        border: Border.all(color: Colors.white, width: 2),
        // La esquina de abajo a la izquierda casi sin redondear es lo que le da
        // forma de bocadillo, y la forma es la que manda.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
          bottomLeft: Radius.circular(3),
        ),
      ),
      child: Text(
        '$cuantas',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.color,
    required this.fondo,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un botón que todavía no se puede pulsar, con su motivo escrito debajo.
class _Apagado extends StatelessWidget {
  const _Apagado({required this.titulo, required this.motivo});

  final String titulo;
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 18,
                color: PaletaEstaciones.tintaApagada,
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PaletaEstaciones.tintaApagada,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            motivo,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: PaletaEstaciones.tintaApagada,
            ),
          ),
        ],
      ),
    );
  }
}

class _Centrado extends StatelessWidget {
  const _Centrado({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Anchos.formulario),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 40, color: Colors.black26),
              const SizedBox(height: 12),
              Text(texto, textAlign: TextAlign.center),
              if (accion != null) ...[const SizedBox(height: 12), accion!],
            ],
          ),
        ),
      ),
    );
  }
}
