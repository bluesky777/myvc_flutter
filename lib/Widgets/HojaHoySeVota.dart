import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/VotacionesApi.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Screens/TarjetonScreen.dart';
import 'package:myvc_flutter/Utils/EstiloVotaciones.dart';
import 'package:myvc_flutter/Utils/VotacionPendiente.dart';

/// **Pantalla 2** · El aviso que se abre solo encima de la portada.
///
/// ## Por qué se abre solo, cuando la tarjeta ya está ahí
///
/// Porque **la jornada electoral dura un día**. Una tarjeta en el muro la ve
/// quien mira el muro; un aviso encima lo ve quien abre la app, que es todo el
/// mundo. La diferencia entre las dos cosas es la participación, y la
/// participación es el número que el colegio mira al final del día.
///
/// Y porque es reversible: quien no quiera votar ahora le da a «Ahora no» y el
/// muro sigue debajo, con la tarjeta puesta. No se pierde nada — es el mismo
/// criterio con el que `OfrecerAvisos` pregunta por los avisos con el muro ya
/// pintado detrás, para que se entienda de qué colegio y de quién va lo que se
/// está ofreciendo.
///
/// ## Lo que evita que se vuelva una plaga
///
/// Tres cosas, y ninguna es un contador de días:
///
///   1. **Sólo si hay algo que votar.** Lo dice el servidor en el login y no la
///      app: `VotacionesPendientes` cuelga **sólo** las elecciones abiertas que
///      esta persona no ha completado.
///   2. **Una vez por sesión**, y la marca se pone **al abrirlo**, no al
///      cerrarlo: un aviso que se cierra deslizando —sin tocar ninguno de los dos
///      botones— volvería a salir en el siguiente refresco del muro, y ése es el
///      bucle de verdad. Ver [VotacionPendiente].
///   3. **Y al votar desaparece.** El tarjetón avisa a [VotacionPendiente] al
///      acabar la papeleta, así que el aviso no vuelve a salir ni con la sesión
///      abierta ni al recargar el muro.
///
/// La marca **no se guarda en el teléfono** a propósito, al revés que la de
/// `OfrecerAvisos`: aquella se gasta una sola vez en la vida del aparato porque
/// Android sólo deja preguntar una vez; esta tiene que volver mañana, y volver al
/// entrar otra persona en la misma tablet.
class HojaHoySeVota {
  HojaHoySeVota._();

  /// Abre el aviso si toca, y no hace nada si no.
  ///
  /// **No falla nunca y no devuelve nada**: es un extra encima de una pantalla
  /// que ya cargó. Si algo sale mal, el muro se queda como estaba y la tarjeta
  /// sigue ahí para entrar a mano.
  static Future<void> siToca(BuildContext context, Server server) async {
    final pendiente = VotacionPendiente.instancia;
    if (!pendiente.tocaAvisar) return;

    final votacion = pendiente.laDeHoy;
    if (votacion == null) return;

    // Antes de abrir nada: así, un aviso cerrado deslizando tampoco vuelve.
    pendiente.yaSeOfrecio();

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => _HojaHoySeVota(votacion: votacion, server: server),
    );
  }
}

class _HojaHoySeVota extends StatefulWidget {
  const _HojaHoySeVota({required this.votacion, required this.server});

  final VotacionAbierta votacion;
  final Server server;

  @override
  State<_HojaHoySeVota> createState() => _HojaHoySeVotaState();
}

class _HojaHoySeVotaState extends State<_HojaHoySeVota> {
  Papeleta? papeleta;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  /// Los cargos, que **el login no manda**.
  ///
  /// El servicio del backend cuelga filas de `vt_votaciones` sin sus
  /// `aspiraciones` dentro, así que para decir «te faltan Personero y Contralor»
  /// hace falta la papeleta. Es **una** petición, y ocurre cuando el aviso ya se
  /// está abriendo: la que se ahorra es la de abrir la app, que es la que se paga
  /// multiplicada por todo el colegio en el mismo medio minuto.
  Future<void> _cargar() async {
    setState(() {
      error = null;
      papeleta = null;
    });

    try {
      final traida = await traerLaPapeleta(widget.server);
      setState(() => papeleta = traida);
    } catch (err) {
      setState(() => error = '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EstiloVotaciones.borde,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: EstiloVotaciones.moradoSuave,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.how_to_vote,
                  size: 46,
                  color: EstiloVotaciones.moradoOscuro,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hoy se vota',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EstiloVotaciones.tinta,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.votacion.nombre} · ${widget.votacion.cuandoCierra()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EstiloVotaciones.tintaSuave,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _losCargos(),
            const SizedBox(height: 20),
            _losBotones(),
          ],
        ),
      ),
    );
  }

  Widget _losCargos() {
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No se pudo traer la votación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: EstiloVotaciones.tintaSuave,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (papeleta == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final cargos = papeleta!.cargos;

    if (cargos.isEmpty) {
      return const Text(
        'Esta votación todavía no tiene cargos.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      );
    }

    // Los cargos **con su estado, no sólo los que faltan**: quien ya votó dos de
    // tres necesita ver los dos en verde para entender por qué el botón dice
    // «Seguir votando» y no «Empezar».
    return Container(
      decoration: EstiloVotaciones.tarjeta,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final cargo in cargos)
            ListTile(
              dense: true,
              leading: Icon(
                EstadoDelCargo.de(cargo.votado).icono,
                color: EstadoDelCargo.de(cargo.votado).color,
              ),
              title: Text(
                cargo.comoSeLlama,
                style: const TextStyle(
                  color: EstiloVotaciones.tinta,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: EtiquetaDeEstado.cargo(EstadoDelCargo.de(cargo.votado)),
            ),
        ],
      ),
    );
  }

  Widget _losBotones() {
    final lista = papeleta;
    final puedeEmpezar = lista != null && lista.faltan.isNotEmpty;

    // «Empezar» la primera vez y «Seguir votando» cuando ya lleva alguno: el
    // botón dice lo que va a pasar, no una palabra fija.
    final yaLleva = lista != null && lista.cargos.any((cargo) => cargo.votado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: EstiloVotaciones.alturaDeBoton,
          child: FilledButton(
            onPressed: puedeEmpezar ? _empezar : null,
            style: FilledButton.styleFrom(
              backgroundColor: EstiloVotaciones.morado,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EstiloVotaciones.radio),
              ),
            ),
            child: Text(
              yaLleva ? 'Seguir votando' : 'Empezar',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: EstiloVotaciones.alturaDeBoton,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: EstiloVotaciones.tintaSuave,
            ),
            child: const Text(
              'Ahora no',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  /// Cierra el aviso y abre el tarjetón **con la papeleta ya traída**.
  ///
  /// Se cierra primero para que al volver del tarjetón no quede una hoja abierta
  /// encima del muro. Y la papeleta viaja como argumento: pedirla otra vez serían
  /// dos peticiones de lo mismo en el mismo segundo.
  void _empezar() {
    final lista = papeleta;
    final navegador = Navigator.of(context);

    navegador.pop();
    navegador.push(
      MaterialPageRoute(
        builder: (_) => TarjetonScreen(
          votacion: widget.votacion,
          papeleta: lista,
        ),
      ),
    );
  }
}
