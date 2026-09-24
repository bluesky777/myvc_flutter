import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/FichaDeEstacionScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// El que llega salteado — pantalla 08 de `docs/estaciones.md`.
///
/// ## «No lo atiendas todavía: le falta la 1» LO DICE LA PANTALLA
///
/// Hoy eso depende de que quien atiende **mire bien la hoja**, y con fila
/// detrás no mira (§2.5). Por eso la banda roja ocupa el ancho entero y va
/// **antes que la ficha**: no es un aviso dentro de la ficha que se lee después
/// de haber empezado a atender, es lo primero que hay en la pantalla.
///
/// ## Las tres cosas de esta pantalla que no son evidentes
///
/// **1 · Aquí no se escribe ningún paso.** Mandar a alguien a la estación que
/// le falta apunta el intento en `envios_estacion` y el servidor contesta
/// `paso_escrito: false`. Eso es lo que permite al tablero del rector decir
/// *«en la 4 se presentan doce sin pasar por la 3 — el cartel está mal
/// puesto»* **sin ensuciar el recorrido de esa familia** con un paso que no
/// ocurrió. Así que al volver **no hay chulo verde**: hay «queda apuntado», que
/// es otra cosa y se pinta distinta.
///
/// **2 · «Atenderlo de todas formas» existe y está apagado.** Un sistema que no
/// puede saltarse su propia regla **se salta por fuera, en papel**, y entonces
/// no queda registro de nada. Lo levanta Coordinación caso por caso y **queda
/// con el nombre de quien lo autorizó**; hoy el servidor no tiene dónde guardar
/// ese nombre, y eso es lo que dice el botón apagado en vez de esconderse. Ver
/// [PendientesEstaciones.atenderloDeTodasFormas].
///
/// **3 · Mandarlo a la estación que le falta también avisa.** Le entra a la
/// cola de allá marcado, y a la familia le llega a dónde tiene que ir: es el
/// mecanismo de la §2.1 en la otra dirección, y por eso no hay que pararse a
/// explicárselo de palabra con la fila esperando.
///
/// ## Qué dice cuando NO le falta nada, que es la mitad del trabajo
///
/// A esta pantalla se llega porque el servidor marcó un aviso de salteado en la
/// cola, y ese aviso —el de la primera estación— significa *«cerró una estación
/// posterior sin pasar por ésta»*: o sea que quien está delante **sí** tiene que
/// ser atendido aquí, y lo que está mal es el cartel del patio, no la familia.
/// Pintarle «no lo atiendas» a ése sería mandarlo a una fila que no existe.
///
/// Así que **lo que decide el rojo no es el aviso: es la ficha**. Si
/// [FichaDeEstacion.leFalta] señala un paso anterior sin cerrar, banda roja y
/// alto; si no, banda ámbar que dice lo que pasó y **que se le atienda**. La
/// pantalla contesta la pregunta entera, que era lo que había que quitarle de
/// encima a quien atiende.
class SalteadoScreen extends StatefulWidget {
  const SalteadoScreen({
    super.key,
    required this.estacion,
    required this.persona,
    this.avisos = const [],
    this.servidor,
    this.encajada = false,
  });

  /// La estación donde se presentó: **desde** dónde se le manda.
  final Estacion estacion;

  final PersonaEnCola persona;

  /// Lo que el servidor dijo de esta persona en la cola, **con su texto**.
  ///
  /// Se pasan desde la cola en vez de volver a pedirlos: ya vinieron en la
  /// misma respuesta que la fila, y la ficha no los trae.
  final List<AvisoDeLaCola> avisos;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  /// En tablet esto va dentro del panel derecho de la cola, sin barra propia.
  final bool encajada;

  @override
  State<SalteadoScreen> createState() => _SalteadoScreenState();
}

class _SalteadoScreenState extends State<SalteadoScreen> {
  late final Server server = widget.servidor ?? Server();

  FichaDeEstacion? ficha;
  bool cargando = true;
  String? error;

  /// Null mientras no se haya intentado mandarlo a ninguna parte.
  String? resultadoDelEnvio;
  bool quedoApuntado = false;
  bool mandando = false;

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_salteado_abierto');
    _cargar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// Qué paso anterior le falta, **según la ficha y no según el aviso**.
  PasoDelRecorrido? get leFalta => ficha?.leFalta;

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traida = await traerLaFicha(
        server,
        widget.persona.id,
        desdeLaEstacion: widget.estacion.nro,
      );
      setState(() {
        ficha = traida;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        error = '$err'.replaceFirst('Exception: ', '');
        cargando = false;
      });
    }
  }

  /// Apunta el intento y le avisa a la estación que le falta.
  ///
  /// **No espera un «guardado»**: espera un «queda apuntado». La diferencia la
  /// pinta [_LoQueQuedoApuntado], y es la diferencia entre que quien atiende se
  /// vaya creyendo que cerró un paso y que sepa que la familia sigue debiendo
  /// esa estación.
  Future<void> _mandarlo() async {
    final destino = leFalta;
    if (destino == null || mandando) return;

    setState(() {
      mandando = true;
      resultadoDelEnvio = null;
    });

    final motivo = await mandarALaEstacionQueFalta(
      server,
      desdeLaEstacion: widget.estacion.nro,
      haciaLaEstacion: destino.nro,
      personaId: widget.persona.id,
    );

    setState(() {
      mandando = false;
      quedoApuntado = motivo == null;
      resultadoDelEnvio = motivo;
    });
  }

  @override
  Widget build(BuildContext context) {
    // La banda va **fuera** de [ColumnaDeFicha] a propósito: en tablet el resto
    // se centra en una columna y la banda sigue ocupando el ancho entero, que
    // es lo que pide la §2.5. Centrada con lo demás se leería como un renglón
    // más de la ficha.
    final dentro = Column(
      children: [
        _LaBanda(
          leFalta: leFalta,
          avisos: widget.avisos,
          comprobando: cargando,
        ),
        Expanded(child: ColumnaDeFicha(child: _cuerpo())),
      ],
    );

    if (widget.encajada) {
      return Container(
        color: PaletaEstaciones.fondo,
        child: Column(
          children: [Expanded(child: dentro), _lasAcciones()],
        ),
      );
    }

    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: widget.persona.nombreCompleto,
          subtitulo:
              'Estación ${widget.estacion.nro} · ${widget.estacion.nombre}',
          conFlecha: true,
        ),
      ),
      body: dentro,
      bottomNavigationBar: _lasAcciones(),
    );
  }

  Widget _cuerpo() {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    final actual = ficha;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _QuienEs(persona: actual?.persona ?? widget.persona, ficha: actual),
        if (quedoApuntado || resultadoDelEnvio != null) ...[
          const SizedBox(height: 10),
          _LoQueQuedoApuntado(
            aDonde: leFalta,
            motivoDelFallo: resultadoDelEnvio,
          ),
        ],
        if (actual == null) ...[
          const SizedBox(height: 10),
          const _Centrado(
            icono: Icons.person_search_outlined,
            texto: 'No se encontró el recorrido de esta persona.',
          ),
        ] else ...[
          const SizedBox(height: 10),
          _ElRecorrido(
            ficha: actual,
            nroDeMiEstacion: widget.estacion.nro,
            leFalta: leFalta,
          ),
        ],
      ],
    );
  }

  /// Los botones del final. **Ninguno enciende hoy, y los tres dicen por qué.**
  ///
  /// El orden no es decorativo: primero lo que hay que hacer —mandarlo a donde
  /// le falta—, y **separado** lo que rompe la regla, que es la única manera de
  /// que no se toque por inercia con la fila esperando (§3, los destructivos
  /// separados del principal).
  Widget _lasAcciones() {
    final destino = leFalta;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (destino != null) _elBotonDeMandarlo(destino),
            if (destino == null && !cargando && ficha != null)
              const _RenglonApagado(
                icono: Icons.how_to_reg,
                titulo: 'Atiéndelo normal',
                motivo: 'No le falta ningún paso anterior a esta estación. Lo '
                    'que se saltó ya no lo puedes arreglar tú desde aquí: '
                    'quien lleva el tablero verá el intento apuntado.',
              ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: PaletaEstaciones.borde),
            const SizedBox(height: 10),
            _elBotonDeAtenderloIgual(),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _abrirLaFicha,
              child: const Text('Abrir la ficha completa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _elBotonDeMandarlo(PasoDelRecorrido destino) {
    if (!PendientesEstaciones.mandarAlQueLlegaSalteado) {
      return _RenglonApagado(
        icono: Icons.alt_route,
        titulo: 'Mandarlo a la Estación ${destino.nro} · ${destino.nombre}',
        // El motivo entero, nunca «no disponible»: quien lo lee es quien puede
        // pedir el despliegue.
        motivo: 'Apuntar el envío espera a que las rutas del día de matrículas '
            'estén desplegadas en tu colegio. Mientras tanto, dile a la '
            'familia que pase por la Estación ${destino.nro} y vuelva.',
      );
    }

    return SizedBox(
      width: double.infinity,
      height: PaletaEstaciones.alturaDeBoton,
      child: FilledButton.icon(
        onPressed: mandando ? null : _mandarlo,
        icon: const Icon(Icons.alt_route),
        label: Text('Mandarlo a la Estación ${destino.nro}'),
      ),
    );
  }

  Widget _elBotonDeAtenderloIgual() {
    if (!PendientesEstaciones.atenderloDeTodasFormas) {
      return const _RenglonApagado(
        icono: Icons.lock_person_outlined,
        titulo: 'Atenderlo de todas formas',
        // Que esté escrito y apagado es la decisión, y se cuenta entera: una
        // regla que no se puede levantar por dentro se levanta por fuera.
        motivo: 'Esto lo levanta Coordinación caso por caso y tiene que quedar '
            'con el nombre de quien lo autorizó. Hoy el servidor no tiene '
            'dónde guardar ese nombre, así que el botón está apagado: '
            'saltárselo sin registro es lo mismo que hacerlo en papel.',
      );
    }

    return SizedBox(
      width: double.infinity,
      height: PaletaEstaciones.alturaDeBoton,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.lock_open, color: PaletaEstaciones.rojo),
        label: const Text(
          'Atenderlo de todas formas',
          style: TextStyle(color: PaletaEstaciones.rojo),
        ),
      ),
    );
  }

  Future<void> _abrirLaFicha() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ficha-de-estacion'),
        builder: (_) => FichaDeEstacionScreen(
          estacion: widget.estacion,
          persona: widget.persona,
          servidor: widget.servidor,
        ),
      ),
    );
  }
}

/// La banda del ancho entero, **antes que la ficha**.
///
/// Roja si le falta un paso anterior; ámbar si se saltó el orden pero aquí sí
/// le toca. **Nunca sólo por el color**: las dos llevan icono y palabras, que
/// es la regla del sol del patio y de quien no distingue el rojo del verde
/// (§3).
class _LaBanda extends StatelessWidget {
  const _LaBanda({
    required this.leFalta,
    required this.avisos,
    required this.comprobando,
  });

  final PasoDelRecorrido? leFalta;
  final List<AvisoDeLaCola> avisos;
  final bool comprobando;

  @override
  Widget build(BuildContext context) {
    final falta = leFalta;
    final alto = falta != null;

    final titulo = alto
        ? 'No lo atiendas todavía'
        : comprobando
            ? 'Se saltó el orden'
            : 'Se saltó el orden, pero aquí sí le toca';

    final detalle = alto
        ? 'Le falta la Estación ${falta.nro} · ${falta.nombre}. '
            'Mándalo allá y vuelve después.'
        : comprobando
            ? 'Comprobando qué paso le falta…'
            : 'No le falta ningún paso anterior a esta estación: atiéndelo. '
                'Lo que hay que revisar es por dónde entró, no a la familia.';

    return Container(
      width: double.infinity,
      color: alto ? PaletaEstaciones.rojoFondo : PaletaEstaciones.ambarFondo,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alto ? Icons.block : Icons.alt_route,
            size: 22,
            color: alto ? PaletaEstaciones.rojo : PaletaEstaciones.ambar,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: alto
                        ? PaletaEstaciones.rojoTinta
                        : PaletaEstaciones.ambar,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detalle,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: alto
                        ? PaletaEstaciones.rojoTinta
                        : PaletaEstaciones.ambar,
                  ),
                ),
                // Lo que dijo el servidor, **con sus palabras**: la app no lo
                // reescribe ni lo resume. Ver [AvisoDeLaCola].
                for (final aviso in avisos) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconoDelAviso(aviso.tipo),
                        size: 14,
                        color: alto
                            ? PaletaEstaciones.rojoTinta
                            : PaletaEstaciones.ambar,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          aviso.texto,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: alto
                                ? PaletaEstaciones.rojoTinta
                                : PaletaEstaciones.ambar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El icono de un aviso **por su tipo, y uno genérico si no lo conocemos**.
///
/// Un tipo que esta versión no conozca se pinta igual: el texto lo escribe el
/// servidor y lo que no se puede es tirarlo por no tener icono. Es la regla de
/// §2.8 —el vocabulario es del colegio y la app no lo cablea— aplicada a un
/// adorno.
IconData _iconoDelAviso(String tipo) => switch (tipo) {
      'salteado' => Icons.alt_route,
      'devuelto' => Icons.undo,
      _ => Icons.info_outline,
    };

/// Quién es, para no atender al hermano.
class _QuienEs extends StatelessWidget {
  const _QuienEs({required this.persona, required this.ficha});

  final PersonaEnCola persona;
  final FichaDeEstacion? ficha;

  @override
  Widget build(BuildContext context) {
    final renglones = <String>[
      if (persona.grupo != null && persona.grupo!.isNotEmpty) persona.grupo!,
      if (persona.documento != null) 'doc. ${persona.documento}',
      if (ficha?.codigo != null) 'hoja ${ficha!.codigo}',
    ];

    return _Tarjeta(
      child: Row(
        children: [
          AvatarPersona(
            nombre: persona.nombreCompleto,
            fotoNombre: persona.fotoNombre,
            radio: 22,
          ),
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
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                if (renglones.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    renglones.join(' · '),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PaletaEstaciones.tintaSuave,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Los N pasos **en vertical**, que es como se leen cuando hay que decidir.
///
/// La barra horizontal de la ficha contesta «¿dónde va?» de un vistazo; aquí la
/// pregunta es otra —«¿qué le falta y desde cuándo?»—, y eso es leer, no mirar
/// (§3).
class _ElRecorrido extends StatelessWidget {
  const _ElRecorrido({
    required this.ficha,
    required this.nroDeMiEstacion,
    required this.leFalta,
  });

  final FichaDeEstacion ficha;
  final int nroDeMiEstacion;
  final PasoDelRecorrido? leFalta;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Su recorrido',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
          const SizedBox(height: 8),
          for (final paso in ficha.pasos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(paso.estado.icono, size: 18, color: paso.estado.color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${paso.nro} · ${paso.nombre}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: paso.nro == nroDeMiEstacion ||
                                    paso.nro == leFalta?.nro
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: PaletaEstaciones.tinta,
                          ),
                        ),
                        Text(
                          _elRenglon(paso),
                          style: const TextStyle(
                            fontSize: 12,
                            color: PaletaEstaciones.tintaSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// La palabra del estado **siempre**, y lo demás si lo hay. El color nunca va
  /// solo.
  String _elRenglon(PasoDelRecorrido paso) {
    final trozos = <String>[
      paso.estado.palabra,
      if (paso.nro == leFalta?.nro) 'es la que le falta',
      if (paso.nro == nroDeMiEstacion) 'la tuya',
      if (paso.cerradoPor != null) 'por ${paso.cerradoPor}',
      if (paso.cerradoHace != null) paso.cerradoHace!,
    ];

    return trozos.join(' · ');
  }
}

/// «Queda apuntado» — **y no «guardado», que es lo que no pasó**.
///
/// El servidor contesta `paso_escrito: false`, así que aquí no hay chulo verde:
/// hay un icono de salida y la frase que dice exactamente qué quedó escrito y
/// qué no. Un verde optimista cuesta que alguien jure que cerró un paso que
/// sigue abierto (§2.6, la misma regla que separa «marcado aquí» de
/// «guardado»).
class _LoQueQuedoApuntado extends StatelessWidget {
  const _LoQueQuedoApuntado(
      {required this.aDonde, required this.motivoDelFallo});

  final PasoDelRecorrido? aDonde;
  final String? motivoDelFallo;

  @override
  Widget build(BuildContext context) {
    final fallo = motivoDelFallo;
    final mal = fallo != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: mal ? PaletaEstaciones.rojoFondo : PaletaEstaciones.ambarFondo,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            mal ? Icons.error_outline : Icons.outbox,
            size: 20,
            color: mal ? PaletaEstaciones.rojo : PaletaEstaciones.ambar,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mal
                  ? fallo
                  : 'Queda apuntado el intento. No se escribió ningún paso: su '
                      'recorrido sigue igual y le sigue faltando la Estación '
                      '${aDonde?.nro ?? ''}, que es a donde tiene que ir ahora.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color:
                    mal ? PaletaEstaciones.rojoTinta : PaletaEstaciones.ambar,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un botón que todavía no se puede pulsar, con su motivo escrito debajo.
class _RenglonApagado extends StatelessWidget {
  const _RenglonApagado({
    required this.icono,
    required this.titulo,
    required this.motivo,
  });

  final IconData icono;
  final String titulo;
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: PaletaEstaciones.tintaApagada),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PaletaEstaciones.tintaApagada,
                ),
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
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: PaletaEstaciones.borde),
      ),
      child: child,
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 38, color: Colors.black26),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
            if (accion != null) ...[const SizedBox(height: 12), accion!],
          ],
        ),
      ),
    );
  }
}
