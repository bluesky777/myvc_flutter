import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Models/NotaDeEstacionModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Las notas de cualquier estación — pantalla 12 de `docs/estaciones.md`.
///
/// *«Puede ser que se adelante el tesorero a poner una nota antes de empezar el
/// proceso»* —Joseth—, y eso no es un caso raro: **es lo más útil que puede
/// pasar**. El tesorero sabe el lunes que esa familia tiene un saldo pendiente
/// y la estación 5 la atiende el sábado. Entre esas dos fechas la información
/// existe y no la ve nadie. Esta pantalla es donde se ve.
///
/// ## Las cuatro reglas que hacen que esto no sea un chat (§2.10)
///
/// 1. **Escribe cualquiera del personal, en cualquier estación** —la suya o
///    no—. Es la contrapartida exacta de «ver todo, cerrar solo lo tuyo»: por
///    eso el selector de estación de abajo trae **todas** las del recorrido y
///    no solo la que se atiende.
/// 2. **Resolver una pendiente no lo puede cualquiera, y el que puede lo dice
///    el servidor.** Cada nota llega con `puedo_resolverla` **ya calculado**
///    ([NotaDeEstacion.puedeDarsePorResuelta]) y esta pantalla lo obedece: no
///    deduce la regla, porque la app es una sola para dieciséis colegios, no
///    sabe los roles de quien mira y la regla ya se ensanchó una vez. Lo que
///    esto protege: **el aviso del tesorero no lo puede apagar el primero a
///    quien le estorbe.** Y cuando el servidor corta con 403, el motivo viene
///    escrito dentro y se pinta **tal cual**, que es lo que convierte un botón
///    muerto en una instrucción.
/// 3. **Una nota NO es el motivo de una devolución.** El motivo pertenece al
///    paso, va en su columna y **lo lee la familia tal cual, en su celular**;
///    la nota es entre el personal y la familia no la ve nunca. Que compartan
///    sitio es la forma de que un comentario interno acabe en el teléfono de
///    una mamá, así que la pantalla lo dice en el sitio donde alguien podría
///    equivocarse: encima de la casilla de escribir.
/// 4. **Una nota reservada cuenta para el número y no enseña su texto.** Sale
///    con candado. *«Esconder que una nota existe es peor que esconder su
///    contenido»*: quien ve el globo y no puede abrirlo sabe a quién
///    preguntarle; quien no ve nada, no pregunta.
///
/// ## El globo se distingue por su SILUETA, no por su color
///
/// Ámbar si hay algo sin resolver, pizarra si solo hay algo escrito —pero lo
/// que lo separa de los cuatro estados del paso es la **forma de bocadillo**,
/// que no la tiene ningún otro indicador de este módulo—. Y el número nunca va
/// solo: al lado va la misma información en palabras ([loQueDicenLasNotas]),
/// que es lo que se lee de verdad con sol en la cara.
class NotasDeEstacionScreen extends StatefulWidget {
  const NotasDeEstacionScreen({
    super.key,
    required this.personaId,
    required this.nombre,
    this.fotoNombre,
    this.grupo,
    this.pasos = const [],
    this.nroDeMiEstacion,
    this.notasYaTraidas,
    this.servidor,
    this.encajada = false,
  });

  /// `alumno_id`. Es lo que lleva la nota y lo que se vuelve a pedir al
  /// recargar.
  final int personaId;

  final String nombre;
  final String? fotoNombre;
  final String? grupo;

  /// El recorrido de esta persona, si quien abre ya lo tenía.
  ///
  /// Sirve para dos cosas y ninguna es decorativa: **poner nombre a cada
  /// estación** —los nombres los arma el colegio y no se cablean (§2.8)— y
  /// **saber dónde se puede escribir**, que es en cualquiera de ellas.
  final List<PasoDelRecorrido> pasos;

  /// Cuál atiende quien mira, para proponerla ya elegida al escribir.
  ///
  /// Solo eso: **no filtra nada**. La regla 1 dice que se escribe en cualquiera.
  final int? nroDeMiEstacion;

  /// Las notas que la ficha ya trajo, para no pedirlas otra vez.
  ///
  /// **No es un apaño de pruebas: es la decisión del contrato.** Las notas
  /// viajan dentro de la ficha —`pasos[].notas_detalle`— justamente para que
  /// nadie tenga que preguntar «¿y las notas?» aparte. Si quien abre esta
  /// pantalla acaba de leer la ficha, pedirla otra vez es una petición de más
  /// por cada persona atendida, ocho horas, sobre un hosting de un núcleo.
  ///
  /// Null es «pídelas tú».
  final Map<int, List<NotaDeEstacion>>? notasYaTraidas;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  /// Si va dentro del panel derecho de un maestro-detalle, en tablet.
  final bool encajada;

  @override
  State<NotasDeEstacionScreen> createState() => _NotasDeEstacionScreenState();
}

class _NotasDeEstacionScreenState extends State<NotasDeEstacionScreen> {
  late final Server server = widget.servidor ?? Server();
  final TextEditingController _campo = TextEditingController();

  Map<int, List<NotaDeEstacion>> notas = const {};
  bool cargando = false;
  String? error;

  /// En qué estación se dejaría la nota que se está escribiendo.
  int? aQueEstacion;

  bool pideAlgo = false;
  bool reservada = false;
  bool escribiendo = false;
  String? falloAlEscribir;

  /// Lo que contestó el servidor al intentar resolver cada nota, por su id.
  ///
  /// Por nota y no una sola cadena: con tres notas a la vista, un fallo suelto
  /// arriba no dice de cuál habla.
  final Map<int, String> falloDe = {};
  final Set<int> resolviendo = {};

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_notas_abierta');

    aQueEstacion = widget.nroDeMiEstacion ??
        (widget.pasos.isNotEmpty ? widget.pasos.first.nro : null);

    final yaTraidas = widget.notasYaTraidas;
    if (yaTraidas != null) {
      notas = yaTraidas;
      return;
    }

    // Con el interruptor apagado no se pregunta **nada**: las nueve rutas
    // `estaciones/*` están en `main` de `8myvc` y sin desplegar, así que cada
    // apertura sería un 404 por dieciséis colegios sobre un hosting de un
    // núcleo. Ver `docs/backend-pendiente.md` §8.
    if (Interruptores.estaciones) _cargar();
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  bool get _sePuedeHablarConElServidor =>
      Interruptores.estaciones && widget.notasYaTraidas == null;

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traidas = await traerLasNotasDeLaFicha(server, widget.personaId);
      setState(() {
        notas = traidas;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        error = '$err'.replaceFirst('Exception: ', '');
        cargando = false;
      });
    }
  }

  Future<void> _resolver(NotaDeEstacion nota) async {
    setState(() {
      resolviendo.add(nota.id);
      falloDe.remove(nota.id);
    });

    final fallo = await darPorResueltaLaNota(server, notaId: nota.id);

    setState(() {
      resolviendo.remove(nota.id);
      // El texto del servidor **gana y se pinta tal cual**: su 403 trae escrito
      // quién puede, y esa frase es lo único que no envejece con el despliegue.
      if (fallo != null) falloDe[nota.id] = fallo;
    });

    if (fallo != null) return;

    _darlaPorResueltaAqui(nota);
    if (_sePuedeHablarConElServidor) await _cargar();
  }

  /// Apaga el ámbar de esa nota sin esperar a releer la ficha.
  ///
  /// Se hace igual cuando después se recarga: con mala señal, la relectura
  /// tarda y quien acaba de tocar el botón necesita ver que pasó algo.
  void _darlaPorResueltaAqui(NotaDeEstacion nota) {
    final copia = <int, List<NotaDeEstacion>>{};

    notas.forEach((nro, lista) {
      copia[nro] = [
        for (final una in lista)
          if (una.id != nota.id)
            una
          else
            NotaDeEstacion(
              id: una.id,
              texto: una.texto,
              reservada: una.reservada,
              pendiente: una.pendiente,
              resuelta: true,
              de: una.de,
              cuando: una.cuando,
              puedoResolverla: una.puedoResolverla,
            ),
      ];
    });

    setState(() => notas = copia);
  }

  Future<void> _dejarLaNota() async {
    final nro = aQueEstacion;
    final texto = _campo.text.trim();

    if (nro == null || texto.isEmpty) return;

    setState(() {
      escribiendo = true;
      falloAlEscribir = null;
    });

    final fallo = await dejarUnaNota(
      server,
      nroEstacion: nro,
      personaId: widget.personaId,
      texto: texto,
      pendiente: pideAlgo,
      reservada: reservada,
    );

    setState(() {
      escribiendo = false;
      falloAlEscribir = fallo;
    });

    if (fallo != null) return;

    _campo.clear();
    setState(() {
      pideAlgo = false;
      reservada = false;
    });

    if (_sePuedeHablarConElServidor) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.encajada) {
      return Container(
        color: PaletaEstaciones.fondo,
        child: ColumnaDeFicha(child: _cuerpo()),
      );
    }

    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: 'Notas',
          subtitulo: widget.nombre,
          conFlecha: true,
        ),
      ),
      body: ColumnaDeFicha(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    final porEstacion = notas.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      children: [
        _LaPersona(
          nombre: widget.nombre,
          fotoNombre: widget.fotoNombre,
          grupo: widget.grupo,
          resumen: elResumenDeLasNotas(notas),
        ),
        if (!Interruptores.estaciones) ...[
          const SizedBox(height: 10),
          const _PorQueEstaApagado(),
        ],
        if (porEstacion.isEmpty && Interruptores.estaciones) ...[
          const SizedBox(height: 10),
          const _SinNotasTodavia(),
        ],
        for (final nro in porEstacion) ...[
          const SizedBox(height: 10),
          _LaEstacion(
            nro: nro,
            nombre: _comoSeLlamaLa(nro),
            esLaMia: nro == widget.nroDeMiEstacion,
            notas: notas[nro] ?? const [],
            resolviendo: resolviendo,
            falloDe: falloDe,
            alResolver: _resolver,
          ),
        ],
        const SizedBox(height: 14),
        _dejarUna(),
      ],
    );
  }

  /// El nombre que el colegio le puso a esa estación, o su número a secas.
  ///
  /// **No se inventa ninguno.** §2.8: los nombres vienen del servidor siempre,
  /// y cuando no llegaron —esta pantalla abierta sin el recorrido delante— se
  /// dice el número, que es el que está impreso en la cartulina del patio.
  String _comoSeLlamaLa(int nro) {
    for (final paso in widget.pasos) {
      if (paso.nro == nro) return paso.nombre;
    }
    return 'Estación $nro';
  }

  Widget _dejarUna() {
    final donde = <int, String>{
      for (final paso in widget.pasos) paso.nro: paso.nombre,
    };

    if (donde.isEmpty && widget.nroDeMiEstacion != null) {
      donde[widget.nroDeMiEstacion!] = _comoSeLlamaLa(widget.nroDeMiEstacion!);
    }

    return _DejarUnaNota(
      campo: _campo,
      donde: donde,
      aQueEstacion: aQueEstacion,
      pideAlgo: pideAlgo,
      reservada: reservada,
      escribiendo: escribiendo,
      fallo: falloAlEscribir,
      alElegirEstacion: (nro) => setState(() => aQueEstacion = nro),
      alCambiarPideAlgo: (valor) => setState(() => pideAlgo = valor),
      alCambiarReservada: (valor) => setState(() => reservada = valor),
      alMandar: _dejarLaNota,
      // Se redibuja al teclear para que el botón se encienda con la primera
      // letra: sin texto el servidor contesta 422, y gastar una petición para
      // enterarse de algo que ya se sabe aquí es lo que no se hace.
      alEscribir: () => setState(() {}),
    );
  }
}

// ---------------------------------------------------------------------------
// Las cuentas, sueltas y públicas.
//
// **Se dejan fuera del State a propósito**: mientras `Interruptores.estaciones`
// sea `const false` esta pantalla no tiene notas que enseñar en ninguna prueba
// que pase por el servidor, y sin funciones sueltas nadie comprobaría que las
// palabras del globo dicen lo que tienen que decir. Es el mismo motivo por el
// que `EstacionesApi` dejó públicas `leerElPasoMarcado` y `motivoDeUnaEscritura`.
// ---------------------------------------------------------------------------

/// Los tres números del globo de una lista de notas.
///
/// Devuelve un [NotasDelPaso] —el mismo tipo que manda el servidor dentro de la
/// ficha— **para que las palabras las ponga una sola función en toda la app**:
/// [NotasDelPaso.enPalabras]. Dos sitios contando lo mismo con frases distintas
/// es como se acaba leyendo «2 notas» en la cola y «3» en la ficha.
NotasDelPaso contarLasNotas(List<NotaDeEstacion> notas) => NotasDelPaso(
      total: notas.length,
      pendientes: notas.where((una) => una.sinResolver).length,
      reservadas: notas.where((una) => una.reservada).length,
    );

/// «2 notas en Tesorería, una sin resolver.»
String loQueDicenLasNotas(
  String nombreDeLaEstacion,
  List<NotaDeEstacion> notas,
) =>
    contarLasNotas(notas).enPalabras(nombreDeLaEstacion);

/// Si el globo va en ámbar. Pizarra cuando solo hay algo escrito.
bool algoSinResolverEn(List<NotaDeEstacion> notas) =>
    notas.any((una) => una.sinResolver);

/// Lo que hay en toda la ficha, en una línea y en palabras.
///
/// **Las reservadas se nombran y se cuentan.** Que el número las incluya es la
/// regla 4 y es a propósito: quien lee «3 notas, una reservada» sabe que hay
/// algo que no puede leer y a quién ir a preguntarle. Quien lee «2» no pregunta
/// nada, porque no sabe que falta.
String elResumenDeLasNotas(Map<int, List<NotaDeEstacion>> porEstacion) {
  final todas = <NotaDeEstacion>[
    for (final lista in porEstacion.values) ...lista,
  ];

  if (todas.isEmpty) return '';

  final cuentas = contarLasNotas(todas);
  final estaciones =
      porEstacion.entries.where((par) => par.value.isNotEmpty).length;

  final trozos = <String>[
    cuentas.total == 1 ? '1 nota' : '${cuentas.total} notas',
    estaciones == 1 ? 'en 1 estación' : 'en $estaciones estaciones',
  ];

  var linea = trozos.join(' ');

  if (cuentas.pendientes > 0) {
    linea += cuentas.pendientes == 1
        ? ', una sin resolver'
        : ', ${cuentas.pendientes} sin resolver';
  }

  if (cuentas.reservadas > 0) {
    linea += cuentas.reservadas == 1
        ? '. Una es reservada: cuenta y no se lee'
        : '. ${cuentas.reservadas} son reservadas: cuentan y no se leen';
  }

  return '$linea.';
}

/// Quién es, y qué hay escrito de ella en todo el recorrido.
class _LaPersona extends StatelessWidget {
  const _LaPersona({
    required this.nombre,
    required this.fotoNombre,
    required this.grupo,
    required this.resumen,
  });

  final String nombre;
  final String? fotoNombre;
  final String? grupo;
  final String resumen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarPersona(nombre: nombre, fotoNombre: fotoNombre, radio: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: PaletaEstaciones.tinta,
                      ),
                    ),
                    if (grupo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        grupo!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PaletaEstaciones.tintaSuave,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // La regla 3, dicha antes de leer nada: lo de aquí es entre el
          // personal, y el motivo de una devolución vive en otro sitio porque
          // **ése sí lo lee la familia**.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                size: 16,
                color: PaletaEstaciones.tintaSuave,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Esto lo escribe y lo lee el personal. La familia no lo ve '
                  'nunca.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: PaletaEstaciones.tintaSuave,
                  ),
                ),
              ),
            ],
          ),
          if (resumen.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              resumen,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: PaletaEstaciones.tinta,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que hay escrito en una estación, con su globo y sus palabras.
class _LaEstacion extends StatelessWidget {
  const _LaEstacion({
    required this.nro,
    required this.nombre,
    required this.esLaMia,
    required this.notas,
    required this.resolviendo,
    required this.falloDe,
    required this.alResolver,
  });

  final int nro;
  final String nombre;
  final bool esLaMia;
  final List<NotaDeEstacion> notas;
  final Set<int> resolviendo;
  final Map<int, String> falloDe;
  final Future<void> Function(NotaDeEstacion) alResolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GloboDeNotas(
                cuantas: notas.length,
                algoSinResolver: algoSinResolverEn(notas),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esLaMia
                          ? 'Estación $nro · $nombre · la tuya'
                          : 'Estación $nro · $nombre',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PaletaEstaciones.tinta,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // El número del globo nunca va solo.
                    Text(
                      loQueDicenLasNotas(nombre, notas),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: PaletaEstaciones.tintaSuave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final nota in notas)
            _UnaNota(
              nota: nota,
              resolviendo: resolviendo.contains(nota.id),
              fallo: falloDe[nota.id],
              alResolver: () => alResolver(nota),
            ),
        ],
      ),
    );
  }
}

/// Una nota: lo que dice, quién la dejó, y si todavía le estorba a alguien.
class _UnaNota extends StatelessWidget {
  const _UnaNota({
    required this.nota,
    required this.resolviendo,
    required this.fallo,
    required this.alResolver,
  });

  final NotaDeEstacion nota;
  final bool resolviendo;
  final String? fallo;
  final VoidCallback alResolver;

  @override
  Widget build(BuildContext context) {
    final sinResolver = nota.sinResolver;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color:
            sinResolver ? PaletaEstaciones.ambarFondo : PaletaEstaciones.fondo,
        border: Border.all(
          color: sinResolver ? const Color(0xFFF0DFC0) : PaletaEstaciones.borde,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _laMarca(),
          const SizedBox(height: 6),
          if (nota.elTextoNoEsParaTi) _elCandado() else _elTexto(),
          const SizedBox(height: 6),
          Text(
            _quienYCuando(),
            style: const TextStyle(
              fontSize: 12,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
          if (sinResolver) ...[
            const SizedBox(height: 8),
            _elBotonDeResolver(),
          ],
          if (fallo != null) ...[
            const SizedBox(height: 8),
            // Lo que dijo el servidor, **tal cual**. Su 403 trae escrito el
            // criterio, y esa frase es la que no envejece: los ids de los roles
            // no son los mismos en los dieciséis colegios.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: PaletaEstaciones.rojoTinta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fallo!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: PaletaEstaciones.rojoTinta,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Icono **y** palabra, siempre. Ningún estado se distingue solo por el color.
  Widget _laMarca() {
    final IconData icono;
    final String palabra;
    final Color color;

    if (nota.sinResolver) {
      icono = Icons.flag_outlined;
      palabra = 'Sin resolver';
      color = PaletaEstaciones.ambar;
    } else if (nota.pendiente && nota.resuelta) {
      icono = Icons.check_circle_outline;
      palabra = 'Resuelta';
      color = PaletaEstaciones.verdeTinta;
    } else {
      icono = Icons.sticky_note_2_outlined;
      palabra = 'Solo constancia';
      color = PaletaEstaciones.tintaSuave;
    }

    return Row(
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          palabra,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: color,
          ),
        ),
        if (nota.reservada) ...[
          const SizedBox(width: 10),
          const Icon(Icons.lock_outline, size: 14, color: Color(0xFF5C5870)),
          const SizedBox(width: 4),
          const Text(
            'Reservada',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
        ],
      ],
    );
  }

  Widget _elTexto() => Text(
        nota.texto ?? '',
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.4,
          color: PaletaEstaciones.tinta,
        ),
      );

  /// Hay nota y no te toca leerla — y eso se dice, no se esconde.
  Widget _elCandado() => Text(
        'El texto de esta nota no te toca leerlo. Cuenta igual para el número: '
        'si te hace falta, pregúntale a quien la escribió.',
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.4,
          fontStyle: FontStyle.italic,
          color: PaletaEstaciones.tintaSuave,
        ),
      );

  String _quienYCuando() {
    final quien = nota.de ?? 'Alguien del personal';
    // La fecha se enseña **tal como la manda el servidor** y no como «hace 2
    // min»: el reloj del teléfono de un docente en el patio no es una fuente de
    // verdad, y esta pantalla no va a inventar husos horarios.
    return nota.cuando == null ? quien : '$quien · ${nota.cuando}';
  }

  Widget _elBotonDeResolver() {
    if (!PendientesEstaciones.resolverUnaNota) {
      return const _BotonApagado(
        titulo: 'Darla por resuelta',
        // Nunca «no disponible»: se dice qué falta, porque quien lo lee es
        // quien puede pedirlo.
        motivo: 'Todavía no está instalado en tu colegio lo que apaga el globo '
            'ámbar: está escrito y falta subirlo al servidor. Mientras tanto la '
            'nota sigue a la vista de todos, que es lo que hace que no se '
            'pierda.',
      );
    }

    if (!nota.puedeDarsePorResuelta) {
      return _BotonApagado(
        titulo: 'Darla por resuelta',
        // **El criterio no se escribe aquí.** Quién puede lo calcula el
        // servidor por nota —llega en `puedo_resolverla`— y lo explica con sus
        // palabras en el 403. Una lista de roles escrita en la app envejece en
        // silencio: los ids no son los mismos en los dieciséis colegios y la
        // regla ya se ensanchó una vez, el 20 sep 2026.
        motivo: nota.de == null
            ? 'A ti el servidor no te deja darla por resuelta. Habla con quien '
                'la escribió: el aviso no lo puede apagar el primero a quien le '
                'estorbe, y eso es lo que protege.'
            : 'La escribió ${nota.de}, y a ti el servidor no te deja darla por '
                'resuelta. Pídeselo: el aviso no lo puede apagar el primero a '
                'quien le estorbe, y eso es lo que protege.',
      );
    }

    return SizedBox(
      height: PaletaEstaciones.alturaDeBoton,
      child: FilledButton.icon(
        onPressed: resolviendo ? null : alResolver,
        icon: resolviendo
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: const Text('Darla por resuelta'),
      ),
    );
  }
}

/// Un botón que no se puede tocar **y dice por qué**.
///
/// Apagado y a la vista, no escondido: un botón que desaparece no se puede ni
/// pedir ni arreglar, y quien lo lee —personal del colegio— es justamente quien
/// puede hacer que deje de estar apagado.
class _BotonApagado extends StatelessWidget {
  const _BotonApagado({required this.titulo, required this.motivo});

  final String titulo;
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lock_clock,
              size: 16,
              color: PaletaEstaciones.tintaApagada,
            ),
            const SizedBox(width: 7),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: PaletaEstaciones.tintaApagada,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
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

/// El bocadillo con el número.
///
/// **La silueta es la que manda**: ningún otro indicador de este módulo tiene
/// forma de globo de conversación, así que se distingue de los cuatro estados
/// del paso sin depender del color —que con sol en la cara, o para quien no
/// separa el rojo del verde, es el mismo gris—.
class GloboDeNotas extends StatelessWidget {
  const GloboDeNotas({
    super.key,
    required this.cuantas,
    required this.algoSinResolver,
  });

  final int cuantas;
  final bool algoSinResolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: algoSinResolver
            ? PaletaEstaciones.globoAmbar
            : PaletaEstaciones.globoPizarra,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(3),
        ),
      ),
      child: Text(
        '$cuantas',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Dejar una nota, en la estación que sea.
///
/// **El selector trae todas las estaciones del recorrido y no solo la tuya**:
/// es la regla 1, y es la mitad de para qué sirve esta pantalla —el tesorero
/// escribe el lunes en la 5 aunque él atienda otra cosa—.
class _DejarUnaNota extends StatelessWidget {
  const _DejarUnaNota({
    required this.campo,
    required this.donde,
    required this.aQueEstacion,
    required this.pideAlgo,
    required this.reservada,
    required this.escribiendo,
    required this.fallo,
    required this.alElegirEstacion,
    required this.alCambiarPideAlgo,
    required this.alCambiarReservada,
    required this.alMandar,
    required this.alEscribir,
  });

  final TextEditingController campo;
  final Map<int, String> donde;
  final int? aQueEstacion;
  final bool pideAlgo;
  final bool reservada;
  final bool escribiendo;
  final String? fallo;
  final void Function(int) alElegirEstacion;
  final void Function(bool) alCambiarPideAlgo;
  final void Function(bool) alCambiarReservada;
  final VoidCallback alMandar;
  final VoidCallback alEscribir;

  @override
  Widget build(BuildContext context) {
    final apagada = !Interruptores.estaciones;
    final nros = donde.keys.toList()..sort();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dejar una nota',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.tinta,
            ),
          ),
          const SizedBox(height: 4),
          // La regla 3, en el sitio exacto donde alguien se puede equivocar.
          const Text(
            'La familia no la ve nunca. Si lo que vas a escribir es el motivo '
            'de una devolución, no va aquí: va en su casilla, y ése sí lo lee '
            'la familia tal cual en su celular.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
          const SizedBox(height: 12),
          if (nros.isEmpty)
            const Text(
              'Para dejar una nota hace falta saber en qué estación: abre esta '
              'pantalla desde la ficha de la persona, que trae el recorrido.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: PaletaEstaciones.tintaApagada,
              ),
            )
          else ...[
            const Text(
              'En qué estación',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: PaletaEstaciones.tintaSuave,
              ),
            ),
            const SizedBox(height: 6),
            // Chips y no una lista desplegable: se toca de pie, con una mano, y
            // el número que va dentro es el que está impreso en la cartulina.
            // Se desplaza porque el colegio arma las estaciones que quiera.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final nro in nros)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$nro · ${donde[nro]}'),
                        selected: nro == aQueEstacion,
                        onSelected:
                            apagada ? null : (_) => alElegirEstacion(nro),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: campo,
              enabled: !apagada && !escribiendo,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => alEscribir(),
              decoration: InputDecoration(
                hintText: 'Lo que la estación siguiente tiene que saber',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: pideAlgo,
              onChanged: apagada ? null : alCambiarPideAlgo,
              title: const Text(
                'Pide que alguien haga algo',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Sale en ámbar y no se apaga hasta que alguien la dé por '
                'resuelta.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reservada,
              onChanged: apagada ? null : alCambiarReservada,
              title: const Text(
                'Reservada',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Cuenta para el número igual, y su texto no lo lee cualquiera.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            if (apagada)
              const _BotonApagado(
                titulo: 'Dejar la nota',
                // El motivo entero, y sin número de versión: lo que falta es un
                // despliegue, no una decisión.
                motivo: 'Tu colegio todavía no tiene instalada esta parte del '
                    'día de matrículas. Está escrita y probada, y se enciende '
                    'cuando el servidor del colegio la tenga; hasta entonces la '
                    'app no le pregunta nada, para no gastar una llamada en '
                    'balde en cada apertura.',
              )
            else
              SizedBox(
                width: double.infinity,
                height: PaletaEstaciones.alturaDeBoton,
                child: FilledButton(
                  // Sin texto no se enciende: el servidor contesta 422 a una
                  // nota vacía, y eso ya se sabe desde aquí.
                  onPressed: escribiendo || campo.text.trim().isEmpty
                      ? null
                      : alMandar,
                  child:
                      Text(escribiendo ? 'Dejando la nota…' : 'Dejar la nota'),
                ),
              ),
            if (fallo != null) ...[
              const SizedBox(height: 8),
              Text(
                fallo!,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: PaletaEstaciones.rojoTinta,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Por qué esta pantalla no tiene nada que enseñar todavía.
///
/// **No dice «no disponible»**, que no se puede ni pedir ni arreglar: dice qué
/// falta y quién lo puede mover. Y mientras está así **no se le pregunta nada
/// al servidor**, porque las nueve rutas no están desplegadas en ningún colegio
/// y cada apertura sería un 404 sobre un hosting de un núcleo.
class _PorQueEstaApagado extends StatelessWidget {
  const _PorQueEstaApagado();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock,
            size: 20,
            color: PaletaEstaciones.tintaApagada,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Las notas todavía no se leen aquí',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'La pantalla está escrita entera y lo que falta es del '
                  'servidor del colegio: hasta que lo tenga, la app no le '
                  'pregunta por las notas para no gastar una llamada en balde '
                  'cada vez que alguien abre una ficha.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: PaletaEstaciones.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nadie ha escrito nada de esta familia. Que es distinto de que esté apagado.
class _SinNotasTodavia extends StatelessWidget {
  const _SinNotasTodavia();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 20,
            color: PaletaEstaciones.tintaApagada,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nadie ha dejado nada escrito de esta persona, en ninguna '
              'estación.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: PaletaEstaciones.tintaSuave,
              ),
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
        padding: const EdgeInsets.all(28),
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
