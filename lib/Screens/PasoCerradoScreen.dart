import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Cuántos segundos dura el deshacer. `docs/estaciones.md` §2.7.
///
/// Ocho, y no es un número redondo elegido de lejos: es el rato que tarda quien
/// atiende en levantar la vista del teléfono, mirar a quien tiene delante y
/// darse cuenta de que marcó al hermano. Más corto no alcanza para eso; más
/// largo retrasa la cola de la estación siguiente, que es lo que esta pantalla
/// está disparando.
const int segundosParaDeshacer = 8;

/// Dónde va a parar lo que se escribió, según cómo quedó el paso.
///
/// Es [repartirElTexto] devuelto entero, para que quien lo reciba no pueda
/// coger uno de los dos campos y olvidarse del otro.
typedef LoQueSeEscribe = ({String motivo, String? observacion});

/// **`motivo` y `observacion` NO son el mismo campo**, y el reparto vive aquí.
///
/// Las pantallas 05 y 06 recogen **un** texto —quien atiende escribe en una
/// casilla, no en dos— y el servidor tiene dos columnas distintas con dos
/// reglas distintas. Traducir lo uno en lo otro es lo que hace esta función, y
/// está suelta y pública porque `Interruptores.estaciones` es `const false`:
/// detrás de esa guarda no la alcanzaría ninguna prueba, y equivocarse aquí
/// **no falla, se pierde en silencio**.
///
/// Las dos reglas, comprobadas el 20 sep 2026 en
/// `EstacionesController::putMarcar` y `::escribirElPaso` y no supuestas:
///
/// 1. **`motivo` sólo se escribe cuando el resultado es `devuelto`.**
///    `escribirElPaso` mete `motivo_devolucion=?` únicamente en la rama de
///    `devuelto`; en la otra escribe `motivo_devolucion=NULL`. O sea que un
///    motivo mandado con `cumple` u `observado` no es que se ignore: **borra el
///    que hubiera** y no lo guarda en ningún sitio. Por eso aquí va vacío
///    siempre que no se devuelva.
/// 2. **Una `observacion` vacía BORRA la que hubiera.** El controlador decide
///    con `Request::has('observacion')`, así que mandar cadena vacía es
///    `descripcion=''` y perder lo que otra estación —o tú mismo hace diez
///    minutos— dejó escrito ahí. Null es «no la toques», y es lo que se manda
///    cuando la casilla se quedó en blanco.
///
/// Al devolver, la observación va en null: la pantalla 06 no tiene casilla de
/// observación y **inventarle una vacía borraría la del paso**, que es
/// exactamente la trampa 2 por la puerta de atrás.
LoQueSeEscribe repartirElTexto(ResultadoDelPaso resultado, String escrito) {
  final limpio = escrito.trim();

  if (resultado == ResultadoDelPaso.devuelto) {
    return (motivo: limpio, observacion: null);
  }

  return (motivo: '', observacion: limpio.isEmpty ? null : limpio);
}

/// «Estación 3 · Tesorería». El número primero, porque es el del cartel.
///
/// La familia lleva en la mano un papel con números impresos y el patio tiene
/// carteles con números, no con nombres. El nombre va detrás para quien sí lee.
String comoSeLlamaLaEstacion(int nro, String nombre) =>
    'Estación $nro · $nombre';

/// El nombre con el que se le habla a la familia: «Laura», no «Laura Mejía Cruz».
///
/// `notificaciones.md` permite nombrar al menor y esta casa ya lo hace así en
/// los avisos de notas. El apellido sobra en el celular de su propia mamá, y
/// además alarga un texto que se lee en una pantalla bloqueada.
///
/// Si el servidor no mandó nombre —que pasa con un aspirante del modo `nuevos`,
/// donde la orden de inscripción nace sin nombres— se cae a una frase que
/// funciona igual, en vez de a un aviso que empieza con un hueco.
String elNombreDePila(String nombres) {
  final limpio = nombres.trim();
  if (limpio.isEmpty) return 'Tu hijo o tu hija';
  return limpio.split(RegExp(r'\s+')).first;
}

/// A qué paso pasa esta persona después de cerrar el número [nroActual].
///
/// **Es la misma regla del servidor, escrita en la app a propósito**:
/// `EstacionesController::siguienteDe` recorre las estaciones en orden y
/// devuelve *la primera con número mayor que ésta que no esté cerrada entera*.
/// Aquí se contesta con lo que ya trae la ficha, y eso es lo que permite a la
/// pantalla 05 **enseñar la consecuencia antes de confirmar** (§2.3) sin gastar
/// una petición para averiguar algo que está en la mano.
///
/// Cuando el servidor contesta manda la suya, y **gana la suya**: la de aquí es
/// una respuesta adelantada, no una segunda fuente de verdad.
///
/// `EstadoDelPaso.cumplido` es el único estado que cuenta como cerrado, y eso
/// cuadra con `cerrada()` del controlador: un paso devuelto tiene `cerrado_at`
/// en null —devolver reabre— y por tanto vuelve a ser candidato.
PasoDelRecorrido? laSiguienteDelRecorrido(
  List<PasoDelRecorrido> pasos,
  int nroActual,
) {
  final ordenados = [...pasos]..sort((a, b) => a.nro.compareTo(b.nro));

  for (final paso in ordenados) {
    if (paso.nro > nroActual && paso.estado != EstadoDelPaso.cumplido) {
      return paso;
    }
  }

  return null;
}

/// El texto que le llega al celular de la familia, palabra por palabra.
///
/// **Se enseña antes de confirmar** (§2.3): quien atiende es responsable de lo
/// que dispara, y hoy no tiene forma de saberlo — se lo dice a la familia de
/// viva voz y reza. Enseñar la consecuencia antes del botón es lo que convierte
/// «chulear un requisito» en «pasar a alguien a la estación 3».
///
/// ## El nombre sí va; el motivo, NUNCA
///
/// `docs/estaciones.md` §2.2 bis, que a su vez cita `notificaciones.md`: una
/// notificación se lee **en una pantalla bloqueada, con gente al lado**. El
/// nombre del menor está permitido —«Laura tiene 4 notas nuevas» ya se manda
/// así—; el contenido, no. Así que el aviso de una devolución dice que hay algo
/// pendiente y **manda a abrir la app**, donde el motivo se lee entero.
///
/// ## Y la frase de la devolución no dice «devuelta»
///
/// El diseño la escribió como *«Laura fue devuelta en Documentos»* y aquí se
/// cambia por una razón que el documento no podía ver: **la app no sabe el
/// género de la persona** —ni la cola ni la ficha mandan nada parecido—, así que
/// «devuelta» saldría mal escrito en la mitad de los casos, en el celular de su
/// casa. Se dice lo mismo sin concordancia: qué pasó y qué hacer.
String elAvisoParaLaFamilia({
  required String nombres,
  required ResultadoDelPaso resultado,
  required String estacionActual,
  String? estacionSiguiente,
}) {
  final quien = elNombreDePila(nombres);

  if (resultado == ResultadoDelPaso.devuelto) {
    return '$quien no pasó $estacionActual. Tiene que volver: abre la app '
        'para ver qué falta.';
  }

  if (estacionSiguiente == null) {
    return '$quien terminó el recorrido de matrícula.';
  }

  return '$quien pasó a $estacionSiguiente.';
}

/// Cómo se ve un paso **que el servidor ya guardó**: icono, color y palabra.
///
/// Los tres juntos y nunca uno suelto: `docs/estaciones.md` §3 pide que ningún
/// estado se distinga sólo por el color —por el sol del patio y por quien no
/// distingue el rojo del verde, que en un claustro de cincuenta docentes es uno
/// o dos—.
///
/// **Está suelta y pública porque es la trampa 3 y no hay otra forma de
/// probarla.** `Interruptores.estaciones` es `const false`, así que ninguna
/// prueba puede llevar a la pantalla hasta el momento en que el servidor
/// contesta; dentro de un `switch` privado, que un devuelto pinte un chulo
/// verde no lo descubriría nadie hasta el día del despliegue.
///
/// Y ese es justo el error caro: **un devuelto NO es un cierre**. El servidor
/// limpia `cerrado_at` y `cerrado_por` para que la cola de esta estación siga
/// viendo a esa persona, así que el paso sigue debiéndose y pintar un cumplido
/// sería pintar lo contrario de lo que pasó.
({IconData icono, Color color, String palabra, String explicacion})
    comoSeVeElCierre(ResultadoDelPaso resultado) {
  return switch (resultado) {
    ResultadoDelPaso.cumple => (
        icono: Icons.check_circle,
        color: PaletaEstaciones.verde,
        palabra: 'Cumple',
        explicacion:
            'El servidor lo guardó y lo firmó con tu nombre y la hora.',
      ),
    ResultadoDelPaso.observado => (
        icono: Icons.error_outline,
        color: PaletaEstaciones.ambar,
        palabra: 'Cumple, con observación',
        explicacion:
            'El paso quedó cerrado y la observación queda escrita en la ficha.',
      ),
    ResultadoDelPaso.devuelto => (
        icono: Icons.undo,
        color: PaletaEstaciones.rojo,
        palabra: 'Devuelto',
        explicacion:
            'El paso queda abierto y sigue debiéndose: no está cerrado.',
      ),
  };
}

/// **Listo, con deshacer** — pantalla 07 de `docs/estaciones.md`.
///
/// A qué estación pasa, dónde queda, qué le llegó a la familia, y **deshacer
/// durante ocho segundos**.
///
/// ## El deshacer es de verdad, y por eso la marca sale a los ocho segundos y NO antes
///
/// §2.7 pide el deshacer porque **en una fila, con dos hermanos apellidados
/// igual, tocar el renglón de al lado pasa todos los días**, y una corrección de
/// auditoría necesita a alguien con permisos y un rato de teléfono.
///
/// Lo que obliga a la forma de esta pantalla es un hecho **medido en el
/// servidor el 20 sep 2026, no supuesto: ninguna de las nueve rutas sabe
/// deshacer un paso.** `EstacionesController::RESULTADOS` es una lista cerrada
/// de tres —`cumple`, `observado`, `devuelto`— y **ninguna de las tres es el
/// estado de partida** (`Falta`); no hay ruta de borrado, y `putMarcar` es la
/// única que escribe el paso. Un botón de deshacer **después** de haber escrito
/// no podría deshacer nada: como mucho encadenaría una devolución, que le manda
/// un aviso a la familia y le deja escrito un motivo que es mentira.
///
/// Así que la marca **se retiene ocho segundos en el teléfono** y sale sola al
/// acabar la cuenta —o antes, si se toca «Mandarlo ya» o si se sale de la
/// pantalla—. Deshacer es **no mandarla**, que es la única forma de deshacer que
/// existe hoy.
///
/// **Y esos ocho segundos se ven, porque son un estado distinto** (§2.6): reloj
/// naranja = marcado aquí, el servidor no lo sabe; chulo verde = el servidor
/// contestó. Un verde optimista ahorra un icono y cuesta que alguien jure que
/// marcó a un alumno que no está marcado.
///
/// **Lo que este diseño cuesta, dicho entero:** si la app se muere dentro de
/// esos ocho segundos, la marca se pierde y nadie se entera. Es el agujero que
/// tapa la pantalla 09 —lo marcado espera en el teléfono, y **se ve que
/// espera**—, que todavía no está escrita. Se paga porque la alternativa es un
/// botón de deshacer que no deshace, y eso es peor que no tener botón.
///
/// ## Y no vuelve a pedir la ficha
///
/// `putMarcar` no contesta «vale»: contesta **el recorrido entero recalculado y
/// a qué estación pasa la familia**. Volver a pedir la ficha aquí sería una
/// petición de más por cada paso cerrado, ocho horas, sobre un hosting de un
/// núcleo.
class PasoCerradoScreen extends StatefulWidget {
  const PasoCerradoScreen({
    super.key,
    required this.estacion,
    required this.ficha,
    required this.resultado,
    this.escrito = '',
    this.requisitos = const [],
    this.recorridoDelColegio = const [],
    this.servidor,
  });

  final Estacion estacion;
  final FichaDeEstacion ficha;

  /// Cómo quedó el paso. Lo eligió la 05 (o la 06, que sólo devuelve).
  final ResultadoDelPaso resultado;

  /// Lo que se escribió en la casilla. **Una sola**: [repartirElTexto] decide si
  /// es el motivo que lee la familia o la observación del paso.
  final String escrito;

  /// Qué requisitos se cierran. Vacío es la estación entera, que es lo normal.
  final List<int> requisitos;

  /// El recorrido del colegio, sólo para saber **cuántos esperan** en la
  /// siguiente. Vacío es «no se sabe», y entonces ese renglón no se pinta: un
  /// número inventado ahí es peor que ninguno.
  final List<Estacion> recorridoDelColegio;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  @override
  State<PasoCerradoScreen> createState() => _PasoCerradoScreenState();
}

/// En qué va la marca. **No es el estado del paso**: es el de esta pantalla.
enum _Fase { contando, mandando, listo, fallo }

class _PasoCerradoScreenState extends State<PasoCerradoScreen> {
  late final Server server = widget.servidor ?? Server();

  Timer? reloj;
  int quedan = segundosParaDeshacer;
  _Fase fase = _Fase.contando;
  PasoMarcado? marcado;

  /// Si la marca **todavía no ha salido del teléfono**.
  ///
  /// Es el candado de los tres caminos de salida —la cuenta atrás, el botón de
  /// mandarla ya y el de deshacer— más el de irse con el botón de atrás. Sin él,
  /// salirse mientras se manda escribiría el paso dos veces.
  bool pendienteDeMandar = true;

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_paso_marcado');
    reloj = Timer.periodic(const Duration(seconds: 1), _tic);
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    reloj?.cancel();

    // Si se sale con el botón de atrás en mitad de la cuenta, **la marca se
    // manda igual**. Lo contrario sería perderla sin decirlo, que es justo lo
    // que esta pantalla no puede hacer: quien atiende ya le dijo a la familia
    // que pase. No se espera la respuesta —no hay pantalla donde enseñarla— y
    // por eso la ficha de detrás puede tardar un refresco en verlo.
    if (pendienteDeMandar) {
      pendienteDeMandar = false;
      unawaited(_escribirlo());
    }

    super.dispose();
  }

  void _tic(Timer cual) {
    if (!mounted) return;

    if (quedan <= 1) {
      setState(() => quedan = 0);
      _mandar();
      return;
    }

    setState(() => quedan--);
  }

  /// La escritura pelada, sin tocar la pantalla. La usa [dispose], donde ya no
  /// hay pantalla que tocar.
  Future<PasoMarcado> _escribirlo() {
    final reparto = repartirElTexto(widget.resultado, widget.escrito);

    return marcarElPaso(
      server,
      nroEstacion: widget.estacion.nro,
      personaId: widget.ficha.persona.id,
      resultado: widget.resultado,
      motivo: reparto.motivo,
      observacion: reparto.observacion,
      requisitos: widget.requisitos,
    );
  }

  Future<void> _mandar() async {
    if (!pendienteDeMandar) return;
    pendienteDeMandar = false;
    reloj?.cancel();

    setState(() => fase = _Fase.mandando);

    final salida = await _escribirlo();

    if (!mounted) return;

    setState(() {
      marcado = salida;
      fase = salida.fallo == null ? _Fase.listo : _Fase.fallo;
    });
  }

  void _deshacer() {
    reloj?.cancel();
    pendienteDeMandar = false;
    Analitica.evento('estacion_paso_deshecho');

    // `false` es «no quedó escrito nada»: la ficha de detrás no tiene que
    // recargarse, porque el servidor no se enteró de nada.
    Navigator.pop(context, false);
  }

  void _reintentar() {
    pendienteDeMandar = true;
    _mandar();
  }

  /// A qué estación pasa la familia. Null es «ya no hay más» **o «se devolvió»**.
  ///
  /// ## El `siguiente` del servidor NO sirve cuando se devolvió, y esto es un desajuste medido
  ///
  /// `putMarcar` contesta `siguiente` **siempre**, calculado con
  /// `siguienteDe($nro, …)`, que devuelve *la primera estación con número mayor
  /// que ésta que no esté cerrada*. Al devolver, esa cuenta sigue apuntando
  /// **hacia adelante** aunque devolver signifique justo lo contrario: el paso
  /// se reabre —`cerrado_at` y `cerrado_por` vuelven a null— para que la cola de
  /// **esta** estación siga viendo a esa persona.
  ///
  /// O sea que pintar ese número tras una devolución mandaría a la familia a la
  /// estación siguiente, que es el error más caro que puede cometer esta
  /// pantalla. Aquí se descarta con un `if` y se dice en voz alta a dónde va de
  /// verdad: **vuelve contigo**.
  ({int nro, String nombre})? _aDondePasa() {
    if (widget.resultado == ResultadoDelPaso.devuelto) return null;

    final delServidor = marcado;

    if (delServidor != null && delServidor.fallo == null) {
      final nro = delServidor.siguienteNro;
      if (nro == null) return null;
      return (nro: nro, nombre: delServidor.siguienteDonde ?? 'la siguiente');
    }

    final local =
        laSiguienteDelRecorrido(widget.ficha.pasos, widget.estacion.nro);

    return local == null ? null : (nro: local.nro, nombre: local.nombre);
  }

  /// Cuántos esperan en esa estación, si se sabe. Null es que no se sabe.
  int? _cuantosEsperanEn(int nro) {
    for (final estacion in widget.recorridoDelColegio) {
      if (estacion.nro == nro) return estacion.esperando;
    }
    return null;
  }

  /// Quién firma el paso, **leído del recorrido antes que de la cabecera**.
  ///
  /// Los dos vienen en la misma respuesta y **pueden no decir lo mismo**, que es
  /// un desajuste medido el 20 sep 2026: la cabecera manda siempre
  /// `cerrado_por` = quien acaba de tocar el botón y `cerrado_at` = ahora,
  /// mientras que `escribirElPaso` los guarda con `COALESCE(cerrado_por, ?)`, o
  /// sea **sólo la primera vez**. Volver a marcar un paso ya cerrado —pasar de
  /// `cumple` a `observado`, por ejemplo— deja en la base la firma original y
  /// contesta en la cabecera la del segundo. El `recorrido` de esa misma
  /// respuesta sale de la base, así que es el que dice la verdad.
  String? get _firma {
    for (final paso
        in marcado?.recorrido?.pasos ?? const <PasoDelRecorrido>[]) {
      if (paso.nro == widget.estacion.nro) {
        return paso.cerradoPor ?? marcado?.cerradoPor;
      }
    }
    return marcado?.cerradoPor;
  }

  String get _nombreDeMiEstacion =>
      comoSeLlamaLaEstacion(widget.estacion.nro, widget.estacion.nombre);

  String get _elAviso {
    final siguiente = _aDondePasa();

    return elAvisoParaLaFamilia(
      nombres: widget.ficha.persona.nombres,
      resultado: widget.resultado,
      estacionActual: _nombreDeMiEstacion,
      estacionSiguiente: siguiente == null
          ? null
          : comoSeLlamaLaEstacion(siguiente.nro, siguiente.nombre),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: widget.resultado == ResultadoDelPaso.devuelto
              ? 'Devuelto'
              : 'Listo',
          subtitulo: _nombreDeMiEstacion,
          conFlecha: true,
        ),
      ),
      body: ColumnaDeFicha(child: _cuerpo()),
      bottomNavigationBar: _elPie(),
    );
  }

  Widget _cuerpo() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _LaCabecera(
          fase: fase,
          resultado: widget.resultado,
          quedan: quedan,
          persona: widget.ficha.persona.nombreCompleto,
          documento: widget.ficha.persona.documento,
        ),
        const SizedBox(height: 12),
        if (fase == _Fase.fallo)
          _loQueFallo()
        else ...[
          _aDonde(),
          const SizedBox(height: 10),
          _LoQueSabeLaFamilia(
            aviso: _elAviso,
            motivo: widget.resultado == ResultadoDelPaso.devuelto
                ? widget.escrito.trim()
                : null,
            yaSalio: fase == _Fase.listo,
          ),
          if (_firma != null) ...[
            const SizedBox(height: 10),
            _LaFirma(quien: _firma!, cuando: marcado?.cerradoAt),
          ],
        ],
      ],
    );
  }

  Widget _loQueFallo() {
    return _Bloque(
      color: PaletaEstaciones.rojoFondo,
      borde: const Color(0xFFF0C9C4),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off, size: 20, color: PaletaEstaciones.rojo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                marcado?.fallo ?? 'No se pudo cerrar ese paso.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: PaletaEstaciones.rojoTinta,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          // Lo que hay que saber antes que nada: no hay nada a medias. Un
          // «algo salió mal» dejaría a quien atiende sin saber si el paso está
          // cerrado, y con una fila delante eso se resuelve marcando otra vez.
          'No quedó escrito nada: el paso sigue como estaba y la familia no '
          'recibió ningún aviso. Vuelve a intentarlo, o díselo de viva voz y '
          'márcalo cuando haya señal.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: PaletaEstaciones.rojoTinta,
          ),
        ),
      ],
    );
  }

  Widget _aDonde() {
    final siguiente = _aDondePasa();

    if (widget.resultado == ResultadoDelPaso.devuelto) {
      return _Bloque(
        color: PaletaEstaciones.rojoFondo,
        borde: const Color(0xFFF0C9C4),
        children: [
          _renglon(
            Icons.undo,
            PaletaEstaciones.rojo,
            'Vuelve contigo',
            'Se queda en la fila de $_nombreDeMiEstacion. Devolver reabre el '
                'paso a propósito: hasta que traiga lo que falta, esta '
                'estación la sigue viendo y la siguiente no.',
          ),
        ],
      );
    }

    if (siguiente == null) {
      return _Bloque(
        color: PaletaEstaciones.verdeFondo,
        borde: const Color(0xFFC9E2D6),
        children: [
          _renglon(
            Icons.flag_outlined,
            PaletaEstaciones.verde,
            'Terminó el recorrido',
            'No le queda ninguna estación por cerrar. Ya puede irse.',
          ),
        ],
      );
    }

    final esperan = _cuantosEsperanEn(siguiente.nro);

    return _Bloque(
      color: Colors.white,
      borde: PaletaEstaciones.borde,
      children: [
        _renglon(
          Icons.arrow_forward,
          PaletaEstaciones.primarioOscuro,
          'Pasa a ${comoSeLlamaLaEstacion(siguiente.nro, siguiente.nombre)}',
          esperan == null
              // El número es el de cuando se abrió esta pantalla y no se pide
              // otra vez: una petición más por cada paso cerrado, ocho horas.
              ? 'Dile el número: es el que está impreso en el cartel.'
              : esperan == 0
                  ? 'Ahora mismo no espera nadie allí. Dile el número: es el '
                      'que está impreso en el cartel.'
                  : esperan == 1
                      ? 'Hay 1 persona esperando allí. Dile el número: es el '
                          'que está impreso en el cartel.'
                      : 'Hay $esperan personas esperando allí. Dile el '
                          'número: es el que está impreso en el cartel.',
        ),
      ],
    );
  }

  Widget _renglon(IconData icono, Color color, String titulo, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: PaletaEstaciones.tintaSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Los botones. **El destructivo va separado del principal**, y aquí el
  /// destructivo es el de deshacer: deshace un trabajo que ya se hizo.
  Widget _elPie() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: switch (fase) {
            _Fase.contando => [
                SizedBox(
                  width: double.infinity,
                  height: PaletaEstaciones.alturaDeBoton,
                  child: FilledButton.icon(
                    onPressed: _mandar,
                    icon: const Icon(Icons.send),
                    label: const Text('Mandarlo ya'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: PaletaEstaciones.alturaDeBoton,
                  child: OutlinedButton.icon(
                    onPressed: _deshacer,
                    icon: const Icon(Icons.undo, color: PaletaEstaciones.rojo),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: PaletaEstaciones.rojo),
                    ),
                    label: Text(
                      'Deshacer ($quedan)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PaletaEstaciones.rojo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pasados los ocho segundos ya no se puede deshacer: '
                  'corregirlo es devolver el paso con motivo, que deja rastro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: PaletaEstaciones.tintaApagada,
                  ),
                ),
              ],
            _Fase.mandando => [
                const SizedBox(
                  height: PaletaEstaciones.alturaDeBoton,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            _Fase.listo => [
                SizedBox(
                  width: double.infinity,
                  height: PaletaEstaciones.alturaDeBoton,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Volver a la cola'),
                  ),
                ),
              ],
            _Fase.fallo => [
                SizedBox(
                  width: double.infinity,
                  height: PaletaEstaciones.alturaDeBoton,
                  child: FilledButton(
                    onPressed: _reintentar,
                    child: const Text('Reintentar'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Volver sin cerrar el paso'),
                ),
              ],
          },
        ),
      ),
    );
  }
}

/// El estado de la marca, **con icono y palabra**, nunca sólo con color.
///
/// Los dos estados de §2.6 se ven distintos porque son distintos: reloj naranja
/// mientras la marca espera en el teléfono, chulo verde cuando el servidor
/// contestó. Y tras un **devuelto no hay chulo verde nunca**: el paso quedó
/// reabierto, así que pintar un cumplido sería pintar lo contrario de lo que
/// pasó.
class _LaCabecera extends StatelessWidget {
  const _LaCabecera({
    required this.fase,
    required this.resultado,
    required this.quedan,
    required this.persona,
    this.documento,
  });

  final _Fase fase;
  final ResultadoDelPaso resultado;
  final int quedan;
  final String persona;
  final String? documento;

  @override
  Widget build(BuildContext context) {
    final (icono, color, palabra, renglon) = _loQueDice();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PaletaEstaciones.borde),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 30, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  palabra,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            renglon,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
          const SizedBox(height: 12),
          // El nombre grande y entero: el deshacer existe para el día que se
          // marca al hermano, y eso se ve leyendo el nombre, no el resultado.
          Text(
            persona,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PaletaEstaciones.tinta,
            ),
          ),
          if (documento != null)
            Text(
              'Documento $documento',
              style: const TextStyle(
                fontSize: 12.5,
                color: PaletaEstaciones.tintaApagada,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color, String, String) _loQueDice() {
    if (fase == _Fase.fallo) {
      return (
        Icons.error_outline,
        PaletaEstaciones.rojo,
        'No se guardó',
        'El servidor no aceptó la marca.',
      );
    }

    if (fase != _Fase.listo) {
      return (
        Icons.schedule,
        PaletaEstaciones.ambar,
        fase == _Fase.mandando ? 'Mandándolo…' : 'Marcado aquí',
        fase == _Fase.mandando
            ? 'Esperando al servidor.'
            : 'Todavía no ha salido del teléfono: se manda en $quedan '
                'segundo${quedan == 1 ? '' : 's'}. Hasta entonces, la estación '
                'siguiente no lo ve.',
      );
    }

    // Ni chulo ni verde tras un devuelto: ver [comoSeVeElCierre], que es donde
    // vive esa regla y donde se puede probar.
    final asiSeVe = comoSeVeElCierre(resultado);

    return (
      asiSeVe.icono,
      asiSeVe.color,
      asiSeVe.palabra,
      asiSeVe.explicacion,
    );
  }
}

/// Qué sabe la familia, palabra por palabra.
class _LoQueSabeLaFamilia extends StatelessWidget {
  const _LoQueSabeLaFamilia({
    required this.aviso,
    required this.yaSalio,
    this.motivo,
  });

  final String aviso;
  final bool yaSalio;

  /// El motivo de la devolución. **No viaja dentro del aviso** (§2.2 bis): se
  /// lee abriendo la app, no en una pantalla bloqueada con gente al lado.
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    return _Bloque(
      color: PaletaEstaciones.primarioSuave,
      borde: const Color(0xFFDDD7F4),
      children: [
        Row(
          children: [
            const Icon(
              Icons.smartphone,
              size: 18,
              color: PaletaEstaciones.primarioOscuro,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Lo que sabe la familia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PaletaEstaciones.primarioOscuro,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            aviso,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: PaletaEstaciones.tinta,
            ),
          ),
        ),
        if (motivo != null && motivo!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Y al abrir la app lee el motivo tal cual lo escribiste: '
            '«$motivo»',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: PaletaEstaciones.primarioOscuro,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _comoLeLlega(),
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: PaletaEstaciones.tintaSuave,
          ),
        ),
      ],
    );
  }

  /// **Y aquí no se promete un aviso que hoy no sale.**
  ///
  /// El 20 sep 2026 Joseth rectificó: *«que llegue cuando tenga que llegar, no
  /// me voy a complicar con que le llegue de inmediato»*, y el push de las
  /// estaciones **no entra** (§2.2). Además `pubspec.yaml` no tiene
  /// `firebase_messaging`, o sea que esta app ni siquiera puede recibirlo.
  ///
  /// Enseñar el texto y callar que no sale sería la versión cara del error:
  /// quien atiende dejaría de decírselo a la familia de viva voz confiando en
  /// un aviso que no existe. Así que mientras
  /// [PendientesEstaciones.pushInmediato] esté apagado, este renglón dice que
  /// **hay que decirlo en voz alta**, que es lo mismo que pide §2.6 cuando no
  /// hay señal.
  String _comoLeLlega() {
    if (!PendientesEstaciones.pushInmediato) {
      return 'Hoy ese aviso NO le sale solo al celular: díselo tú antes de que '
          'se vaya. El aviso inmediato está pendiente, y hasta entonces lo que '
          'la familia sabe es lo que le digas.';
    }

    return yaSalio
        ? 'Ya le salió al celular del acudiente.'
        : 'Le sale al celular del acudiente en cuanto esto se mande.';
  }
}

/// Quién firma el paso y cuándo. Es la mitad de lo que protege un paso, ahora
/// que cierra cualquiera del personal (§2.9).
class _LaFirma extends StatelessWidget {
  const _LaFirma({required this.quien, this.cuando});

  final String quien;
  final String? cuando;

  @override
  Widget build(BuildContext context) {
    final hace = haceCuanto(cuando);

    return Row(
      children: [
        const Icon(
          Icons.draw_outlined,
          size: 16,
          color: PaletaEstaciones.tintaApagada,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hace == null ? 'Firmado por $quien' : 'Firmado por $quien · $hace',
            style: const TextStyle(
              fontSize: 12.5,
              color: PaletaEstaciones.tintaApagada,
            ),
          ),
        ),
      ],
    );
  }
}

/// Una tarjeta con borde. Nunca una sombra: el patio tiene sol y una sombra no
/// se ve, un borde sí.
class _Bloque extends StatelessWidget {
  const _Bloque({
    required this.color,
    required this.borde,
    required this.children,
  });

  final Color color;
  final Color borde;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
