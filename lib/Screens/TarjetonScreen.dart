import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/VotacionesApi.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Screens/YaVotasteScreen.dart';
import 'package:myvc_flutter/Utils/EstiloVotaciones.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Utils/VotacionPendiente.dart';
import 'package:myvc_flutter/Widgets/HojaConfirmarVoto.dart';

/// **Pantalla 3** · El tarjetón: **un cargo por pantalla**.
///
/// ## Por qué un cargo por pantalla y no la papeleta entera en una lista
///
/// Porque cada cargo es **un voto que no se puede deshacer** —índice único
/// `vt_votos_un_voto_por_cargo`— y una lista larga con cuatro elecciones dentro
/// invita a bajar deprisa y tocar de más. Partida en pantallas, cada voto tiene
/// su momento, su confirmación y su vuelta atrás **antes** de mandarse.
///
/// Y porque en un teléfono una rejilla de caras de 76 px con cuatro cargos
/// encima no cabe sin hacer las caras pequeñas, y la cara **es el dato**: en
/// sexto se reconoce a quien se vota por la foto antes que por el nombre.
///
/// ## Lo que el servidor puede contestar, y qué hace cada cosa
///
/// `votos/store` dejó de devolver 200 con un `msg` dentro. Los cuatro rechazos
/// son cuatro situaciones distintas y **ninguna se enseña como «no se pudo
/// guardar»**:
///
///   - **409, ya votó ese cargo** — no es una avería: es el sistema
///     funcionando. Se dice, se apunta la constancia que trae dentro —con su
///     hora— y **se sigue al cargo siguiente**. Reintentar no tiene sentido.
///   - **423, la urna está cerrada o pausada** — reintentar tampoco sirve hasta
///     que el colegio la abra, así que se sale del tarjetón con el mensaje del
///     servidor delante.
///   - **403, no le corresponde** — su estamento no vota, no está en el censo, o
///     su grupo vota en su mesa. Lo mismo: se sale con el motivo.
///   - **422, validación** — el cargo o el candidato no son de esta votación. Se
///     queda donde está: es lo único que puede arreglarse volviendo a intentarlo
///     con la papeleta recargada.
///
/// En los cuatro casos el texto que se lee **es el del servidor**. Es él quien
/// sabe por qué, y una frase escrita en la app envejece en silencio el día que la
/// regla cambie.
class TarjetonScreen extends StatefulWidget {
  const TarjetonScreen({
    super.key,
    required this.votacion,
    this.papeleta,
  });

  final VotacionAbierta votacion;

  /// La papeleta ya traída, cuando quien abre esto la tenía.
  ///
  /// El aviso de la portada la pide para poder listar los cargos que faltan, así
  /// que se la pasa: sin esto, entrar a votar desde el aviso costaría **dos**
  /// peticiones de la misma cosa, una detrás de la otra, en el mismo segundo.
  final Papeleta? papeleta;

  @override
  State<TarjetonScreen> createState() => _TarjetonScreenState();
}

class _TarjetonScreenState extends State<TarjetonScreen> {
  final Server server = Server();

  Papeleta? papeleta;
  String? error;
  bool guardando = false;

  /// Cuántos cargos tenía que votar cuando entró, y cuántos lleva echados.
  ///
  /// **Las dos cifras se guardan y no se calculan de la papeleta**, y ahí hay una
  /// trampa que muerde: un cargo votado sale de [_porVotar], así que medir la
  /// ronda con `_porVotar.length` la hace **encogerse sola** — la cabecera diría
  /// «Voto 1 de 2», luego «Voto 1 de 1», y la barra se quedaría a cero las dos
  /// veces. El total de la ronda se fija al entrar; lo que avanza es [echados].
  int? totalDeLaRonda;
  int echados = 0;

  /// Lo que se sabe de cada voto de esta sesión, por `aspiracion_id`. Es la
  /// única fuente de la hora — ver [YaVotasteScreen].
  final Map<int, Constancia> constancias = {};

  @override
  void initState() {
    super.initState();

    if (widget.papeleta != null) {
      papeleta = widget.papeleta;
      totalDeLaRonda = widget.papeleta!.faltan.length;
    } else {
      _cargar();
    }
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargar() async {
    setState(() {
      error = null;
      papeleta = null;
    });

    try {
      final traida = await traerLaPapeleta(server);
      setState(() {
        papeleta = traida;
        // La ronda se mide contra lo que faltaba al entrar. Ver [totalDeLaRonda].
        totalDeLaRonda = traida.faltan.length;
        echados = 0;
      });
    } catch (err) {
      setState(() => error = '$err');
    }
  }

  /// Los cargos que le faltan, en el orden en que los manda el servidor.
  List<CargoDeLaPapeleta> get _porVotar => papeleta?.faltan ?? const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EstiloVotaciones.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: EstiloVotaciones.tinta,
        elevation: 0,
        title: Text(widget.votacion.nombre),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (error != null) return _elError();
    if (papeleta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (papeleta!.sinEleccion) {
      return _vacio(
        Icons.how_to_vote_outlined,
        'Ahora mismo no hay ninguna votación abierta para ti.',
      );
    }

    if (papeleta!.cargos.isEmpty) {
      return _vacio(
        Icons.playlist_remove_outlined,
        'Esta votación todavía no tiene cargos. El colegio los está armando.',
      );
    }

    if (_porVotar.isEmpty) {
      // Nada que votar: ya está todo. No se pinta un tarjetón vacío.
      return _vacio(
        Icons.check_circle_outline,
        'Ya votaste todos los cargos de esta votación.',
      );
    }

    // El cargo de ahora es siempre el primero que falta: al votar uno sale de la
    // lista, así que no hace falta llevar un índice —y un índice sobre una lista
    // que se acorta es la forma de acabar pintando el cargo equivocado—.
    return _elTarjeton(_porVotar.first);
  }

  Widget _elTarjeton(CargoDeLaPapeleta cargo) {
    final cuantos = totalDeLaRonda ?? _porVotar.length;
    final candidatos = cargo.soloCandidatos;

    return Column(
      children: [
        _cabecera(cargo, cuantos),
        Expanded(
          child: candidatos.isEmpty
              ? _vacio(
                  Icons.person_off_outlined,
                  'Este cargo no tiene candidatos inscritos. Puedes votar en'
                  ' blanco.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: candidatos.length,
                  itemBuilder: (_, i) =>
                      _tarjetaDeCandidato(cargo, candidatos[i]),
                ),
        ),
        _elPie(cargo),
      ],
    );
  }

  /// El cargo, «Voto 1 de 2» y la barra.
  ///
  /// **La cuenta es sobre los cargos que le FALTAN, no sobre todos.** Si de tres
  /// cargos ya votó uno ayer, hoy tiene dos votos que echar y eso es lo que la
  /// barra mide: una barra que arrancara al 33 % mediría un recorrido que esta
  /// persona no puede recorrer, porque el cargo votado no se vuelve a abrir.
  Widget _cabecera(CargoDeLaPapeleta cargo, int cuantos) {
    final voy = echados + 1;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cargo.comoSeLlama,
                  style: const TextStyle(
                    color: EstiloVotaciones.tinta,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Voto $voy de $cuantos',
                style: const TextStyle(
                  color: EstiloVotaciones.moradoOscuro,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: cuantos == 0 ? 0 : (voy - 1) / cuantos,
              minHeight: 8,
              backgroundColor: EstiloVotaciones.moradoSuave,
              valueColor: const AlwaysStoppedAnimation(
                EstiloVotaciones.morado,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca a quien quieras elegir.',
            style: TextStyle(
              color: EstiloVotaciones.tintaSuave,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Una tarjeta de candidato: avatar grande, chapa, nombre, grupo y plancha.
  ///
  /// La tarjeta entera es el objetivo de toque —bastante más de los 56 px que
  /// pide la casa— porque **esto es lo que decide algo**: apuntar a un círculo de
  /// 76 px con el pulgar, de pie, no es lo mismo que tocar una tarjeta de 100 px
  /// de alto.
  Widget _tarjetaDeCandidato(
    CargoDeLaPapeleta cargo,
    CandidatoDelTarjeton candidato,
  ) {
    final detalle = <String>[
      if (candidato.grupo != null && candidato.grupo!.isNotEmpty)
        candidato.grupo!,
      if (candidato.plancha != null && candidato.plancha!.isNotEmpty)
        'Plancha ${candidato.plancha}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(EstiloVotaciones.radio),
          onTap: guardando ? null : () => _elegir(cargo, candidato),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: EstiloVotaciones.tarjeta,
            child: Row(
              children: [
                CirculoDeCandidato(
                  nombre: candidato.nombre,
                  fotoNombre: candidato.fotoNombre,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidato.nombre,
                        style: const TextStyle(
                          color: EstiloVotaciones.tinta,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (detalle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detalle,
                          style: const TextStyle(
                            color: EstiloVotaciones.tintaSuave,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (candidato.numero != null && candidato.numero!.isNotEmpty)
                  ChapaDeNumero(numero: candidato.numero!, lado: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// El blanco y el aviso, abajo y siempre a la vista.
  ///
  /// **El blanco va aquí y no en la rejilla de caras.** En el contrato tampoco es
  /// un candidato: es `aspiracion_id` sin `candidato_id`. Puesto entre las caras
  /// sería una opción más que se toca por descuido al bajar; abajo, es una
  /// decisión que se toma.
  Widget _elPie(CargoDeLaPapeleta cargo) {
    final blanco = cargo.candidatos.firstWhere(
      (c) => c.blanco,
      orElse: () => const CandidatoDelTarjeton(
        blanco: true,
        nombre: 'Voto en Blanco',
      ),
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: EstiloVotaciones.borde)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: EstiloVotaciones.alturaDeBoton,
              child: OutlinedButton.icon(
                onPressed: guardando ? null : () => _elegir(cargo, blanco),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PaletaEstaciones.gris,
                  side: const BorderSide(color: EstiloVotaciones.borde),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EstiloVotaciones.radio),
                  ),
                ),
                icon: const Icon(Icons.check_box_outline_blank, size: 20),
                label: const Text(
                  'Votar en blanco',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: EstiloVotaciones.tintaApagada,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'El voto no se puede cambiar después de confirmarlo.',
                    style: TextStyle(
                      color: EstiloVotaciones.tintaApagada,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (guardando) ...[
              const SizedBox(height: 10),
              const SizedBox(
                height: 2,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Elegir, confirmar y mandar.
  Future<void> _elegir(
    CargoDeLaPapeleta cargo,
    CandidatoDelTarjeton candidato,
  ) async {
    final seguro = await confirmarElVoto(
      context,
      cargo: cargo,
      candidato: candidato,
    );

    if (!seguro || !mounted) return;

    setState(() => guardando = true);

    try {
      final constancia = await votar(
        server,
        votacionId: cargo.votacionId == 0
            ? widget.votacion.id
            : cargo.votacionId,
        aspiracionId: cargo.id,
        candidatoId: candidato.candidatoId,
      );

      constancias[cargo.id] = constancia;
      _apuntarQueYaEsta(cargo.id);
      setState(() => guardando = false);
      _seguir();
    } on RechazoDeLaUrna catch (rechazo) {
      setState(() => guardando = false);
      _tratarElRechazo(cargo, rechazo);
    } catch (err) {
      setState(() => guardando = false);
      _decir('No se pudo registrar el voto: $err');
    }
  }

  /// Lo que hace cada código. Ver la cabecera de la clase.
  void _tratarElRechazo(CargoDeLaPapeleta cargo, RechazoDeLaUrna rechazo) {
    if (!mounted) return;

    if (rechazo.yaHabiaVotado) {
      // No es un error: ese cargo ya estaba hecho. Se apunta la constancia —que
      // trae la hora dentro— y se sigue.
      final constancia = rechazo.constancia;
      if (constancia != null) constancias[cargo.id] = constancia;

      _apuntarQueYaEsta(cargo.id);
      _decir(rechazo.mensaje, color: PaletaEstaciones.ambar);
      _seguir();
      return;
    }

    if (rechazo.urnaCerrada || rechazo.noLeCorresponde) {
      // Reintentar no sirve: la urna está cerrada, o esta votación no es suya.
      _decir(rechazo.mensaje, color: PaletaEstaciones.rojo);
      Navigator.of(context).pop();
      return;
    }

    // 422 y lo demás: se queda donde está con el motivo delante.
    _decir(rechazo.mensaje, color: PaletaEstaciones.rojo);
  }

  /// Marca el cargo como votado en la papeleta que tiene en la mano.
  ///
  /// **Se reescribe la lista en vez de volver a pedirla.** Recargar la papeleta
  /// después de cada voto serían N peticiones por papeleta, en un patio con mala
  /// señal, para enterarse de algo que ya se sabe: el servidor acaba de decir que
  /// ese cargo quedó votado.
  void _apuntarQueYaEsta(int aspiracionId) {
    final actual = papeleta;
    if (actual == null) return;

    papeleta = Papeleta(
      sinEleccion: false,
      cargos: [
        for (final cargo in actual.cargos)
          if (cargo.id == aspiracionId)
            CargoDeLaPapeleta(
              id: cargo.id,
              nombre: cargo.nombre,
              abrev: cargo.abrev,
              votacionId: cargo.votacionId,
              votado: true,
              candidatos: cargo.candidatos,
            )
          else
            cargo,
      ],
    );
  }

  /// Al siguiente cargo, o a «Ya votaste» si era el último.
  void _seguir() {
    if (!mounted) return;

    final quedan = _porVotar;

    if (quedan.isEmpty) {
      // La portada tiene que dejar de ofrecerlo: el dato vino del login y el
      // login no se repite.
      VotacionPendiente.instancia.yaVoto(widget.votacion.id);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => YaVotasteScreen(
            votacion: widget.votacion,
            cargos: papeleta?.cargos ?? const [],
            constancias: constancias,
          ),
        ),
      );
      return;
    }

    // El cargo votado ya salió de `_porVotar`, así que la cuenta de la ronda se
    // **deriva** en vez de incrementarse: total menos lo que queda. Así no hay
    // dos contadores que puedan separarse, que es lo que pasaría si el servidor
    // contestara 409 de un cargo que ya no estaba en la lista.
    final total = totalDeLaRonda ?? quedan.length;
    setState(() => echados = (total - quedan.length).clamp(0, total));
  }

  void _decir(String mensaje, {Color? color}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _elError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No se pudo traer la votación.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacio(IconData icono, String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
