import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/DevolverConMotivoScreen.dart';
import 'package:myvc_flutter/Screens/PasoCerradoScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// **Cerrar el paso** — pantalla 05 de `docs/estaciones.md`.
///
/// Tres salidas —cumple, cumple con observación, devolver— y, **antes de
/// confirmar, la consecuencia entera**.
///
/// ## El bloque de la consecuencia no es adorno, y es la mitad de esta pantalla
///
/// §2.3: *«quien atiende es responsable de lo que dispara y hoy no tiene forma
/// de saberlo: en la práctica se lo dice a la familia de viva voz y reza»*.
/// Enseñar a qué estación pasa, cuántos hay delante y **el texto exacto que le
/// va a llegar al celular** es lo que convierte «chulear un requisito» en
/// «pasar a alguien a la estación 3», que es lo que de verdad se está haciendo.
///
/// ## Cerrar la estación entera es lo normal, y por eso no hay lista que marcar
///
/// `putMarcar` acepta una lista de requisitos y **sin lista cierra la estación
/// entera**, que es lo que hace esta pantalla. Los requisitos de la estación se
/// enseñan en el bloque de la consecuencia —«se dan por cumplidos éstos»— en vez
/// de como casillas que marcar: la estación de un solo papel es casi todas, y
/// una casilla por requisito es un toque de más por familia en una fila.
///
/// ## Aquí NO se exige que los requisitos vengan ya cumplidos
///
/// La ficha llegó a apagar su botón mientras quedara un obligatorio sin
/// cumplir, y eso **habría dejado el botón apagado para siempre**: los
/// requisitos de `requisitos_alumno` sólo pasan a `Cumple` cuando alguien
/// cierra la estación, o sea cuando se pulsa este botón. Quien acaba de llegar
/// —el caso más común de la mañana— los tiene todos en `Falta`. Lo que falta se
/// enseña, y no bloquea: bloquear era pedirle al paso que se cerrara solo antes
/// de dejarlo cerrar.
class MarcarPasoScreen extends StatefulWidget {
  const MarcarPasoScreen({
    super.key,
    required this.estacion,
    required this.ficha,
    this.servidor,
  });

  final Estacion estacion;
  final FichaDeEstacion ficha;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  @override
  State<MarcarPasoScreen> createState() => _MarcarPasoScreenState();
}

class _MarcarPasoScreenState extends State<MarcarPasoScreen> {
  late final Server server = widget.servidor ?? Server();

  final TextEditingController observacion = TextEditingController();

  /// Cuál de las tres. Null es «todavía no ha elegido», y entonces el botón no
  /// se enciende: **ninguna de las tres puede ser la de por defecto**, porque
  /// una salida por defecto es una salida que se pulsa sin leer.
  ResultadoDelPaso? elegida;

  /// El recorrido del colegio, sólo para el renglón de «cuántos esperan allí».
  List<Estacion> recorridoDelColegio = const [];

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_marcar_abierta');
    _cargarElRecorrido();
  }

  @override
  void dispose() {
    observacion.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// Trae las estaciones **sólo para saber cuántos esperan en la siguiente**.
  ///
  /// Es la única cifra de la consecuencia que no está ya en la ficha, y viene
  /// de `GET estaciones`, que es una lista corta. Va en segundo plano y **nada
  /// espera por ella**: si tarda o falla, el renglón no se pinta y la pantalla
  /// funciona igual. Un número inventado ahí es peor que ninguno.
  Future<void> _cargarElRecorrido() async {
    try {
      final traidas = await traerLasEstaciones(server);
      setState(() => recorridoDelColegio = traidas);
    } catch (_) {
      // Un fallo aquí no puede tapar la pantalla que cierra el paso: lo único
      // que se pierde es el renglón de cuántos esperan.
      setState(() => recorridoDelColegio = const []);
    }
  }

  /// El paso que esta estación atiende dentro del recorrido de esta persona.
  PasoDelRecorrido? get _miPaso {
    for (final paso in widget.ficha.pasos) {
      if (paso.nro == widget.estacion.nro) return paso;
    }
    return null;
  }

  String get _nombreDeMiEstacion =>
      comoSeLlamaLaEstacion(widget.estacion.nro, widget.estacion.nombre);

  /// A qué estación pasa si esto se cierra bien. Null es «termina el recorrido».
  PasoDelRecorrido? get _laSiguiente =>
      laSiguienteDelRecorrido(widget.ficha.pasos, widget.estacion.nro);

  int? _cuantosEsperanEn(int nro) {
    for (final estacion in recorridoDelColegio) {
      if (estacion.nro == nro) return estacion.esperando;
    }
    return null;
  }

  /// Abre la 07 con lo elegido, y cuando ella conteste se quita de en medio.
  ///
  /// La 07 es la que escribe, y no por reparto de tareas: **el deshacer de ocho
  /// segundos sólo puede existir si la marca todavía no ha salido**, porque
  /// ninguna de las nueve rutas sabe deshacer un paso. El porqué entero está en
  /// el docblock de [PasoCerradoScreen].
  Future<void> _confirmar() async {
    final salida = elegida;
    if (salida == null) return;

    if (salida == ResultadoDelPaso.devuelto) return _irADevolver();

    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'paso-cerrado'),
        builder: (_) => PasoCerradoScreen(
          estacion: widget.estacion,
          ficha: widget.ficha,
          resultado: salida,
          escrito: observacion.text,
          recorridoDelColegio: recorridoDelColegio,
          servidor: widget.servidor,
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    Navigator.pop(context, resultado);
  }

  /// Devolver no se confirma aquí: se confirma **con el motivo escrito**.
  ///
  /// §2.4. Esta pantalla ya enseñó lo que la familia va a recibir; lo que falta
  /// es lo único que esa familia va a poder leer para saber qué traer, y eso no
  /// cabe en un botón.
  Future<void> _irADevolver() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'devolver-con-motivo'),
        builder: (_) => DevolverConMotivoScreen(
          estacion: widget.estacion,
          ficha: widget.ficha,
          recorridoDelColegio: recorridoDelColegio,
          servidor: widget.servidor,
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: 'Cerrar el paso',
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
        _DeQuienEs(persona: widget.ficha.persona),
        const SizedBox(height: 14),
        const Text(
          '¿Cómo quedó?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: PaletaEstaciones.tinta,
          ),
        ),
        const SizedBox(height: 8),
        _LaSalida(
          icono: Icons.check_circle,
          color: PaletaEstaciones.verde,
          palabra: 'Cumple',
          explicacion: 'Trajo lo que había que traer. El paso se cierra.',
          elegida: elegida == ResultadoDelPaso.cumple,
          alTocar: () => setState(() => elegida = ResultadoDelPaso.cumple),
        ),
        const SizedBox(height: 8),
        _LaSalida(
          icono: Icons.error_outline,
          color: PaletaEstaciones.ambar,
          palabra: 'Cumple, con observación',
          explicacion: 'El paso se cierra igual, y queda algo escrito en la '
              'ficha para quien venga detrás.',
          elegida: elegida == ResultadoDelPaso.observado,
          alTocar: () => setState(() => elegida = ResultadoDelPaso.observado),
        ),
        if (elegida == ResultadoDelPaso.observado) ...[
          const SizedBox(height: 8),
          _LaObservacion(controlador: observacion),
        ],
        // Aire de sobra antes de la destructiva: §3 pide los destructivos
        // separados del principal, y aquí la distancia es el separador.
        const SizedBox(height: 22),
        _LaSalida(
          icono: Icons.undo,
          color: PaletaEstaciones.rojo,
          palabra: 'Devolver',
          explicacion: 'No trajo lo que falta. El paso NO se cierra: se queda '
              'en tu fila hasta que vuelva.',
          elegida: elegida == ResultadoDelPaso.devuelto,
          alTocar: () => setState(() => elegida = ResultadoDelPaso.devuelto),
        ),
        const SizedBox(height: 18),
        _LaConsecuencia(
          elegida: elegida,
          persona: widget.ficha.persona,
          estacionActual: _nombreDeMiEstacion,
          siguiente: _laSiguiente,
          esperanAlla: _laSiguiente == null
              ? null
              : _cuantosEsperanEn(_laSiguiente!.nro),
          requisitos: _miPaso?.requisitos ?? const [],
          nombreDeLaEstacion: widget.estacion.nombre,
        ),
      ],
    );
  }

  Widget _elPie() {
    final apagadoPorElPendiente = !PendientesEstaciones.marcarElPaso;
    final salida = elegida;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: PaletaEstaciones.alturaDeBoton,
              child: FilledButton(
                onPressed:
                    salida == null || apagadoPorElPendiente ? null : _confirmar,
                style: salida == ResultadoDelPaso.devuelto
                    ? FilledButton.styleFrom(
                        backgroundColor: PaletaEstaciones.rojo,
                      )
                    : null,
                child: Text(_loQueDiceElBoton(salida)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              apagadoPorElPendiente
                  // Nunca «no disponible»: quien lo lee es quien puede pedirlo.
                  ? 'Cerrar el paso está apagado hasta que las nueve rutas de '
                      'estaciones estén desplegadas en todos los colegios. Las '
                      'pantallas ya están escritas; lo que falta es el '
                      'despliegue.'
                  : salida == null
                      ? 'Elige arriba cómo quedó el paso.'
                      : 'Lee lo que va a pasar antes de confirmar: eso es lo '
                          'que le vas a decir a la familia.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: PaletaEstaciones.tintaApagada,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _loQueDiceElBoton(ResultadoDelPaso? salida) => switch (salida) {
        null => 'Confirmar',
        ResultadoDelPaso.cumple => 'Confirmar: cumple',
        ResultadoDelPaso.observado => 'Confirmar: cumple con observación',
        // No dice «devolver» a secas porque **todavía no devuelve nada**: lleva
        // a escribir el motivo, que es lo que devuelve.
        ResultadoDelPaso.devuelto => 'Escribir el motivo y devolver',
      };
}

/// A quién se le está cerrando el paso.
///
/// El nombre grande, y **el documento cuando lo hay**: el deshacer de la 07
/// existe porque en una fila con dos hermanos apellidados igual se toca el
/// renglón de al lado, y aquí es donde eso todavía se puede ver a tiempo.
class _DeQuienEs extends StatelessWidget {
  const _DeQuienEs({required this.persona});

  final PersonaEnCola persona;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PaletaEstaciones.borde),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            persona.nombreCompleto,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PaletaEstaciones.tinta,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (persona.grupo != null) persona.grupo!,
              if (persona.documento != null) 'Documento ${persona.documento}',
            ].join(' · '),
            style: const TextStyle(
              fontSize: 12.5,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una de las tres salidas. **Icono Y palabra Y color**, nunca el color solo.
class _LaSalida extends StatelessWidget {
  const _LaSalida({
    required this.icono,
    required this.color,
    required this.palabra,
    required this.explicacion,
    required this.elegida,
    required this.alTocar,
  });

  final IconData icono;
  final Color color;
  final String palabra;
  final String explicacion;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida ? color.withValues(alpha: 0.07) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          // Lo que decide algo se toca de pie, con una mano, a veces con
          // guantes en tierra fría. §3 pide 56.
          constraints: const BoxConstraints(
            minHeight: PaletaEstaciones.alturaDeBoton,
          ),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: elegida ? color : PaletaEstaciones.borde,
              width: elegida ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 24, color: color),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palabra,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      explicacion,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: PaletaEstaciones.tintaSuave,
                      ),
                    ),
                  ],
                ),
              ),
              // La marca de elegido tampoco es sólo el color del borde.
              if (elegida)
                Icon(Icons.radio_button_checked, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// La casilla de la observación, con lo que hace y lo que NO hace.
///
/// **Dejarla en blanco no borra la que hubiera**, y decirlo importa: el
/// servidor decide con `Request::has('observacion')`, así que mandar una
/// casilla vacía **borraría** lo que otra estación dejó escrito en ese
/// requisito. Esta app no la manda cuando está vacía —ver [repartirElTexto]—, y
/// aquí se cuenta para que nadie espere lo contrario.
class _LaObservacion extends StatelessWidget {
  const _LaObservacion({required this.controlador});

  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controlador,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Qué conviene que sepa la estación siguiente',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'La ve el personal en la ficha, no la familia. Si la dejas en '
          'blanco, la observación que ya hubiera se queda como está; para '
          'cambiarla, escribe la nueva encima.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: PaletaEstaciones.tintaApagada,
          ),
        ),
      ],
    );
  }
}

/// **Lo que va a pasar cuando confirmes.** El bloque entero de §2.3.
class _LaConsecuencia extends StatelessWidget {
  const _LaConsecuencia({
    required this.elegida,
    required this.persona,
    required this.estacionActual,
    required this.siguiente,
    required this.esperanAlla,
    required this.requisitos,
    required this.nombreDeLaEstacion,
  });

  final ResultadoDelPaso? elegida;
  final PersonaEnCola persona;
  final String estacionActual;
  final PasoDelRecorrido? siguiente;
  final int? esperanAlla;
  final List<Requisito> requisitos;
  final String nombreDeLaEstacion;

  @override
  Widget build(BuildContext context) {
    final salida = elegida;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              const Icon(
                Icons.play_circle_outline,
                size: 19,
                color: PaletaEstaciones.primarioOscuro,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lo que pasa al confirmar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.primarioOscuro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (salida == null)
            const Text(
              'Elige una de las tres y aquí sale, antes de confirmar, a qué '
              'estación pasa y qué le va a llegar a la familia.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: PaletaEstaciones.tintaSuave,
              ),
            )
          else ...[
            ..._loDelPaso(salida),
            const SizedBox(height: 12),
            const Text(
              'Y a la familia le llega esto, tal cual',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: PaletaEstaciones.tinta,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: PaletaEstaciones.primarioSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                elAvisoParaLaFamilia(
                  nombres: persona.nombres,
                  resultado: salida,
                  estacionActual: estacionActual,
                  estacionSiguiente:
                      salida == ResultadoDelPaso.devuelto || siguiente == null
                          ? null
                          : comoSeLlamaLaEstacion(
                              siguiente!.nro,
                              siguiente!.nombre,
                            ),
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: PaletaEstaciones.tinta,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _comoLeLlega(salida),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: PaletaEstaciones.tintaApagada,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Ver el porqué entero en `_LoQueSabeLaFamilia._comoLeLlega`: el push de las
  /// estaciones **no entra** (rectificado el 20 sep 2026) y esta app ni siquiera
  /// tiene `firebase_messaging`, así que prometer un aviso sería quitarle a la
  /// familia el único que hoy funciona, que es que se lo digan.
  String _comoLeLlega(ResultadoDelPaso salida) {
    if (!PendientesEstaciones.pushInmediato) {
      return 'Hoy ese aviso NO sale solo: díselo tú antes de que se vaya.';
    }

    return salida == ResultadoDelPaso.devuelto
        ? 'Le sale al celular del acudiente. El motivo NO va dentro del '
            'aviso: lo lee abriendo la app.'
        : 'Le sale al celular del acudiente.';
  }

  List<Widget> _loDelPaso(ResultadoDelPaso salida) {
    if (salida == ResultadoDelPaso.devuelto) {
      return [
        _renglon(
          Icons.undo,
          PaletaEstaciones.rojo,
          'El paso NO se cierra',
          'Se queda en la fila de $estacionActual —devolver lo reabre a '
              'propósito— y no pasa a ninguna estación.',
        ),
        const SizedBox(height: 8),
        _renglon(
          Icons.edit_note,
          PaletaEstaciones.rojo,
          'Hace falta el motivo, escrito',
          'En la pantalla siguiente. Sin texto el botón no se enciende, '
              'porque ese texto es lo único que la familia va a poder leer.',
        ),
      ];
    }

    return [
      _renglon(
        Icons.check_circle_outline,
        PaletaEstaciones.verde,
        'Se cierra $nombreDeLaEstacion',
        requisitos.isEmpty
            ? 'Esta estación no tiene requisitos configurados: se cierra '
                'entera, sin lista.'
            : 'Se dan por cumplidos sus '
                '${requisitos.length == 1 ? 'requisito' : '${requisitos.length} requisitos'}'
                ': ${requisitos.map((r) => r.nombre).join(', ')}.',
      ),
      const SizedBox(height: 8),
      if (siguiente == null)
        _renglon(
          Icons.flag_outlined,
          PaletaEstaciones.verde,
          'Termina el recorrido',
          'No le queda ninguna estación por cerrar: ya puede irse.',
        )
      else
        _renglon(
          Icons.arrow_forward,
          PaletaEstaciones.primarioOscuro,
          'Pasa a ${comoSeLlamaLaEstacion(siguiente!.nro, siguiente!.nombre)}',
          esperanAlla == null
              ? 'Es la primera que le queda sin cerrar.'
              : esperanAlla == 0
                  ? 'Ahora mismo no espera nadie allí.'
                  : esperanAlla == 1
                      ? 'Hay 1 persona esperando allí.'
                      : 'Hay $esperanAlla personas esperando allí.',
        ),
    ];
  }

  Widget _renglon(IconData icono, Color color, String titulo, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 19, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
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
}
