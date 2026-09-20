import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/FichaDeEstacionScreen.dart';
import 'package:myvc_flutter/Screens/SalteadoScreen.dart';
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

  /// La cola **entera**: la cabecera del día y la fila.
  ///
  /// Guardaba sólo la lista de personas, y con ella se iban a la basura
  /// `atendidos_hoy` —una de las tres cifras de la cabecera del diseño, que el
  /// servidor ya calcula— y los `avisos` de cada persona. Ver [LaCola].
  LaCola datos = (
    nro: null,
    nombre: null,
    alDiaAt: null,
    atendidosHoy: null,
    fila: const [],
  );

  List<EnLaCola> get cola => datos.fila;

  bool cargando = true;
  String? error;

  /// A quién se está mirando en el panel derecho. Solo en tablet.
  EnLaCola? elegida;

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
      final traida = await traerLaColaEntera(server, widget.estacion.nro);
      setState(() {
        datos = traida;
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
      body: _hayEspacioParaLosDos(context)
          ? _maestroDetalle()
          : ColumnaDeFicha(child: _laColumna()),
    );
  }

  bool _hayEspacioParaLosDos(BuildContext context) =>
      MediaQuery.of(context).size.width >= Anchos.maestroDetalle;

  /// Tablet: la cola a la izquierda y la ficha a la derecha, **sin navegar**.
  ///
  /// Decidido el 20 sep 2026 —celular y tablet—, así que esto dejó de ser una
  /// mejora y pasó a ser requisito (`docs/tablets.md`, problema 2). Y es donde
  /// más se nota: en una columna estirada, cada persona de la fila cuesta ir y
  /// volver, con la familia de pie delante.
  Widget _maestroDetalle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: Anchos.maestro, child: _laColumna()),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _elDetalle()),
      ],
    );
  }

  Widget _laColumna() {
    return Column(
      children: [
        _LasTresCifras(
          atendidosHoy: datos.atendidosHoy,
          esperando: cola.length,
        ),
        _LaFrescura(desde: _ultimaVezQueSeMovio, cargando: cargando),
        Expanded(child: _cuerpo()),
        _elPie(),
      ],
    );
  }

  Widget _elDetalle() {
    final quien = elegida;

    if (quien == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            cola.isEmpty
                ? 'Cuando llegue alguien, aparece aquí.'
                : 'Toca a alguien de la fila para abrir su ficha.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    // El que se saltó el orden entra por la 08 también en tablet: si el panel
    // de la derecha enseñara la ficha de siempre, la banda que avisa quedaría
    // justo donde no se mira — dentro del scroll, debajo de la barra de pasos.
    if (dicenQueSeSaltoElOrden(quien.avisos)) {
      return SalteadoScreen(
        key: ValueKey('salteado-${quien.persona.id}'),
        estacion: widget.estacion,
        persona: quien.persona,
        avisos: quien.avisos,
        servidor: widget.servidor,
        encajada: true,
      );
    }

    return FichaDeEstacionScreen(
      // La clave hace que Flutter sepa que es otra persona.
      key: ValueKey(quien.persona.id),
      estacion: widget.estacion,
      persona: quien.persona,
      servidor: widget.servidor,
      encajada: true,
    );
  }

  /// «Estación 2 · 4 esperando».
  ///
  /// **Aquí había un sitio y el sitio no existe.** Este subtítulo pintaba
  /// `estacion.donde` —«Estación 2 · Aula 101 · 4 esperando»— y el servidor no
  /// manda ninguna ubicación: la única clave `donde` de todo el controlador es
  /// el nombre de la estación de destino al devolver a alguien. Ver el docblock
  /// de [Estacion], 20 sep 2026.
  ///
  /// La `descripcion` que sí manda el servidor **no entra aquí**: es la
  /// instrucción sobre el papel que se entrega, y esto es una barra de título
  /// de una línea que ya lleva el nombre de la estación encima.
  String _subtitulo() {
    final cuantos =
        cola.length == 1 ? '1 esperando' : '${cola.length} esperando';
    return 'Estación ${widget.estacion.nro} · $cuantos';
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

    // Se recalcula en cada pintado a propósito: la fila cambia cada veinte
    // segundos, y el empate de ahora puede no ser el de dentro de un minuto.
    final repetidos =
        losNombresQueSeRepiten(cola.map((uno) => uno.persona).toList());

    return RefreshIndicator(
      onRefresh: Analitica.refresco('estacion_cola', _cargar),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: cola.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _TarjetaDeLaCola(
            enLaCola: cola[i],
            esElPrimero: i == 0,
            estaAbierta: cola[i].persona.id == elegida?.persona.id,
            hayOtroQueSeLlamaIgual:
                repetidos.contains(cola[i].persona.claveDelNombre),
            alTocar: () => _abrir(cola[i]),
          ),
        ),
      ),
    );
  }

  /// Abre a quien se tocó: la ficha de siempre, **o la 08 si se saltó el
  /// orden**.
  ///
  /// Quien lo decide es el servidor, con su aviso, y no una regla escrita aquí
  /// (ver [dicenQueSeSaltoElOrden]). La 08 es la que dice en voz alta lo que
  /// hoy depende de que quien atiende mire bien la hoja — y con fila detrás no
  /// mira.
  Future<void> _abrir(EnLaCola quien) async {
    if (_hayEspacioParaLosDos(context)) {
      // En tablet no se navega: cambia el panel de la derecha.
      setState(() => elegida = quien);
      return;
    }

    final salteado = dicenQueSeSaltoElOrden(quien.avisos);

    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: salteado ? 'salteado-de-estacion' : 'ficha-de-estacion',
        ),
        builder: (_) => salteado
            ? SalteadoScreen(
                estacion: widget.estacion,
                persona: quien.persona,
                avisos: quien.avisos,
                servidor: widget.servidor,
              )
            : FichaDeEstacionScreen(
                estacion: widget.estacion,
                persona: quien.persona,
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

/// Un chip de una tarjeta de la cola: lo que hay que saber antes de llamarla.
typedef ChipDeLaCola = ({String texto, IconData icono, bool grave});

/// Los chips de una fila, **con el texto que escribió el servidor**.
///
/// ## Por qué el texto no se escribe aquí
///
/// `getCola` manda `avisos: [{tipo, texto}]` por persona con la frase ya hecha
/// —*«Cerró una estación posterior sin pasar por ésta»*, *«Ya estuvo aquí y se
/// le devolvió»*— y **el modelo los ignoraba**, así que el salteado que el
/// servidor calcula **no se veía en la cola**. Ahora se pintan, y se pintan con
/// sus palabras: quien calcula la regla es quien sabe decirla, y una frase
/// escrita en la app envejece en silencio cuando la del servidor cambia.
///
/// ## El «devuelto una vez» de toda la vida es ahora el RESPALDO
///
/// `devuelto_antes` y el aviso de tipo `devuelto` dicen lo mismo, así que
/// pintar los dos daría **dos chips seguidos con la misma noticia** en una
/// tarjeta que se mira de pie. Manda el del servidor; el de la app sólo sale
/// cuando no vino ninguno —un servidor anterior a `avisos`—, que es el caso en
/// el que sigue siendo lo único que hay.
///
/// Vive suelta y no dentro del widget para que se pueda probar: es una regla,
/// no un adorno. Y un `tipo` desconocido **no se descarta**: se pinta con el
/// icono genérico, porque el vocabulario lo pone el colegio (§2.8).
List<ChipDeLaCola> losChipsDeLaFila(EnLaCola uno) {
  final chips = <ChipDeLaCola>[
    for (final aviso in uno.avisos)
      (
        texto: aviso.texto,
        icono: switch (aviso.tipo) {
          'salteado' => Icons.alt_route,
          'devuelto' => Icons.undo,
          _ => Icons.info_outline,
        },
        // Lo grave es lo que cambia lo que hay que hacer con la familia que
        // está delante; un aviso que sólo informa va en ámbar.
        grave: aviso.tipo == 'salteado' || aviso.tipo == 'devuelto',
      ),
  ];

  final loDijoElServidor = uno.avisos.any((a) => a.tipo == 'devuelto');

  if (uno.persona.devueltoAntes && !loDijoElServidor) {
    chips.add((texto: 'devuelto una vez', icono: Icons.undo, grave: true));
  }

  return chips;
}

/// Las tres cifras del día, y **la que no existe se dice que no existe**.
///
/// La cabecera del diseño (§1, pantalla 02) enseña *atendidos, esperando y
/// espera media*, porque quien atiende necesita saber **si el tapón es suyo o
/// de la estación de al lado**. Medido contra `getCola` el 20 sep 2026:
///
/// - **Atendidos hoy** — `atendidos_hoy` **ya llegaba y se tiraba**: esta capa
///   se quedaba sólo con `cola`. No hace falta nada del servidor.
/// - **Esperando** — es el largo de la fila que vino en la misma respuesta.
/// - **Espera media** — **el servidor no la manda.** Y no se calcula aquí con
///   los `llego_at` de los que siguen esperando, que es el atajo que parece
///   gratis: eso mide *«cuánto llevan de pie los que aún no he atendido»* y
///   **baja justo cuando la cosa va mal** —al atender a los más viejos, la
///   media de los que quedan cae—. Una cifra que mejora cuando empeora el
///   tapón es peor que un hueco, así que queda el hueco, con su renglón
///   diciendo qué falta y quién lo puede poner.
///
/// Un hueco dicho no es lo mismo que un cero: [atendidosHoy] en `null` es «el
/// servidor no lo dijo» —una versión anterior a este campo— y se pinta con la
/// raya, no con un 0 que nadie contó.
class _LasTresCifras extends StatelessWidget {
  const _LasTresCifras({required this.atendidosHoy, required this.esperando});

  final int? atendidosHoy;
  final int esperando;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UnaCifra(
            cifra: atendidosHoy == null ? '—' : '$atendidosHoy',
            rotulo: 'Atendidos hoy',
            icono: Icons.task_alt,
            color: PaletaEstaciones.verde,
            nota: atendidosHoy == null ? 'tu colegio no lo manda' : null,
          ),
          _UnaCifra(
            cifra: '$esperando',
            rotulo: 'Esperando',
            icono: Icons.groups_outlined,
            color: PaletaEstaciones.primarioOscuro,
          ),
          const _UnaCifra(
            cifra: '—',
            rotulo: 'Espera media',
            icono: Icons.timer_outlined,
            color: PaletaEstaciones.tintaApagada,
            // El hueco dice qué falta: quien lo lee es quien puede pedirlo.
            nota: 'el servidor aún no la calcula',
          ),
        ],
      ),
    );
  }
}

/// Una de las tres. **Icono y palabra, nunca sólo el color** (§3).
class _UnaCifra extends StatelessWidget {
  const _UnaCifra({
    required this.cifra,
    required this.rotulo,
    required this.icono,
    required this.color,
    this.nota,
  });

  final String cifra;
  final String rotulo;
  final IconData icono;
  final Color color;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                cifra,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 11.5,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
          if (nota != null)
            Text(
              nota!,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.25,
                color: PaletaEstaciones.tintaApagada,
              ),
            ),
        ],
      ),
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

/// Alguien de la fila, con lo que el servidor dijo de él.
class _TarjetaDeLaCola extends StatelessWidget {
  const _TarjetaDeLaCola({
    required this.enLaCola,
    required this.esElPrimero,
    required this.alTocar,
    this.estaAbierta = false,
    this.hayOtroQueSeLlamaIgual = false,
  });

  final EnLaCola enLaCola;

  PersonaEnCola get persona => enLaCola.persona;

  final bool esElPrimero;
  final VoidCallback alTocar;

  /// Si es la que está abierta a la derecha. Solo pasa en tablet.
  final bool estaAbierta;

  /// Si otra persona de la misma fila tiene el mismo nombre completo.
  ///
  /// Entonces —y solo entonces— la tarjeta enseña el documento. Mientras la
  /// cola no mande la foto, es lo único que distingue a dos hermanos.
  final bool hayOtroQueSeLlamaIgual;

  @override
  Widget build(BuildContext context) {
    final abajo = _elRenglonDeAbajo();

    return Material(
      color: estaAbierta ? PaletaEstaciones.primarioSuave : Colors.white,
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
                    if (abajo != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        abajo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PaletaEstaciones.tintaSuave,
                        ),
                      ),
                    ],
                    if (_losChips.isNotEmpty || persona.tieneNotas) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final chip in _losChips)
                            _Chip(
                              texto: chip.texto,
                              icono: chip.icono,
                              color: chip.grave
                                  ? PaletaEstaciones.rojoTinta
                                  : PaletaEstaciones.ambar,
                              fondo: chip.grave
                                  ? PaletaEstaciones.rojoFondo
                                  : PaletaEstaciones.ambarFondo,
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

  /// El grupo y, **solo cuando hace falta**, el documento.
  ///
  /// El documento entra únicamente si otra persona de la fila se llama igual
  /// (ver `losNombresQueSeRepiten`). Lleva su rótulo —«doc.»— porque un número
  /// suelto debajo de un nombre se lee como cualquier cosa: un teléfono, un
  /// código de la hoja de ruta.
  String? _elRenglonDeAbajo() {
    final grupo = persona.grupo;

    final trozos = <String>[
      if (grupo != null && grupo.isNotEmpty) grupo,
      if (persona.esAspirante) 'aspirante',
      if (hayOtroQueSeLlamaIgual && persona.documento != null)
        'doc. ${persona.documento}',
    ];

    return trozos.isEmpty ? null : trozos.join(' · ');
  }

  List<ChipDeLaCola> get _losChips => losChipsDeLaFila(enLaCola);

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
///
/// **Y hoy cae siempre**, porque `getCola` no manda `foto_nombre` —comprobado
/// campo por campo el 20 sep 2026; el porqué y qué haría falta en el servidor
/// están en el docblock de `PersonaEnCola.fotoNombre`—. Esto no se apaga
/// mientras tanto: el avatar sigue siendo el sitio donde la foto va a entrar, y
/// el globo de notas cuelga de él. El desempate de hoy es el documento, y lo
/// pone la tarjeta.
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
          // Flexible porque **el texto lo escribe el servidor** y es una frase
          // entera —«Cerró una estación posterior sin pasar por ésta»—, no las
          // dos palabras de los chips de antes: sin esto se sale de la tarjeta
          // en un teléfono estrecho.
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
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
