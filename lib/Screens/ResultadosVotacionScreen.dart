import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/VotacionesApi.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Utils/EstiloVotaciones.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// **Pantalla 6** · Los resultados, cuando el colegio los publica.
///
/// ## Lo que esta pantalla NO hace: pintar ceros
///
/// `GET resultados/{id}` tiene **dos formas** y las dos son correctas. Con
/// `conteo_visible: false` devuelve la estructura —los cargos y sus candidatos— y
/// **ni un número**: ni el del candidato, ni el blanco, ni el total, ni la
/// participación. Eso no es una elección sin votos: es una elección cuyo conteo
/// **rectoría no ha publicado**, y el campo existe justamente para que la
/// pantalla sepa por qué no hay números en vez de pintar ceros.
///
/// Un cero es una afirmación. «Personero: 0 votos» le dice a un colegio de
/// ochocientos alumnos que nadie fue a votar, y eso, un día de elección, es la
/// mentira más cara que esta pantalla podría contar.
///
/// Y hay una excepción que es la mitad de la regla: **al personal del colegio se
/// le dan los conteos siempre**, encendido o apagado el interruptor. Existe para
/// que los alumnos no vean el marcador en vivo mientras se vota, no para que el
/// rector no pueda mirar su propia elección. La app no decide nada de eso: pinta
/// lo que le llegue.
///
/// ## Las barras, y por qué el denominador importa
///
/// El porcentaje **lo calcula el servidor** y aquí no se recalcula: dos mitades
/// que dividen por su cuenta acaban enseñando dos porcentajes distintos del mismo
/// cargo. Y su denominador es **toda la urna, blanco incluido**, que era la otra
/// mitad del bug del módulo viejo — un cargo con 40 votos y 8 blancos decía
/// «total 32» y los porcentajes de los candidatos salían inflados uno por uno.
///
/// ## Y el papel se dice aparte, siempre
///
/// Cuando hay votos de actas de papel se avisa en ámbar y no se esconde dentro
/// del total, porque **63 papeletas no son 63 personas**: de un montón de
/// papeletas no se saca quién votó qué, así que el papel suma en los votos y
/// **no entra en el porcentaje de participación**. Un colegio que sume las
/// columnas y encuentre un descuadre tiene que poder leer de dónde sale.
class ResultadosVotacionScreen extends StatefulWidget {
  const ResultadosVotacionScreen({
    super.key,
    required this.votacionId,
    required this.nombre,
  });

  final int votacionId;

  /// El nombre que ya se sabe, para que la barra de arriba no salga vacía
  /// mientras carga. El de la respuesta manda cuando llega.
  final String nombre;

  @override
  State<ResultadosVotacionScreen> createState() =>
      _ResultadosVotacionScreenState();
}

class _ResultadosVotacionScreenState extends State<ResultadosVotacionScreen> {
  final Server server = Server();

  Escrutinio? escrutinio;
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

  Future<void> _cargar() async {
    setState(() {
      error = null;
      escrutinio = null;
    });

    try {
      final traido = await traerElEscrutinio(server, widget.votacionId);
      setState(() => escrutinio = traido);
    } catch (err) {
      setState(() => error = '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EstiloVotaciones.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: EstiloVotaciones.tinta,
        elevation: 0,
        title: Text(escrutinio?.nombre.isNotEmpty == true
            ? escrutinio!.nombre
            : widget.nombre),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (error != null) return _elError();
    if (escrutinio == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final datos = escrutinio!;

    if (datos.cargos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.bar_chart_outlined, size: 56, color: Colors.black26),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Esta votación todavía no tiene cargos.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (!datos.conteoVisible) ...[
          const AvisoAmbar(
            icono: Icons.hourglass_empty,
            texto: 'Rectoría todavía no publicó el conteo de esta votación.'
                ' Estos son los cargos y los candidatos; los números salen'
                ' cuando el colegio los publique.',
          ),
          const SizedBox(height: 12),
        ] else ...[
          _lasDosCifras(datos),
          const SizedBox(height: 12),
          if (datos.hayPapel) ...[
            AvisoAmbar(
              icono: Icons.description_outlined,
              texto: _loQueDiceElPapel(datos),
            ),
            const SizedBox(height: 12),
          ],
        ],
        for (final cargo in datos.cargos)
          _tarjetaDeCargo(cargo, datos.conteoVisible),
      ],
    );
  }

  /// Las dos cifras de arriba: votos contados y participación.
  ///
  /// **Son dos cosas distintas y por eso son dos.** Los votos son filas de la
  /// urna y una persona echa varias —una por cargo—; la participación son
  /// personas del censo. Enseñar sólo la primera hace que un colegio de
  /// ochocientos lea «3.200 votos» y crea que votó cuatro veces su matrícula.
  Widget _lasDosCifras(Escrutinio datos) {
    final participacion = datos.participacion;

    return Row(
      children: [
        Expanded(
          child: _cifra(
            'Votos contados',
            '${datos.votosContados}',
            Icons.how_to_vote_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _cifra(
            'Participación',
            participacion == null
                ? '—'
                : '${participacion.porcentaje.toStringAsFixed(1)} %',
            Icons.groups_outlined,
            detalle: participacion == null
                ? null
                : '${participacion.votantes} de ${participacion.censo}',
          ),
        ),
      ],
    );
  }

  Widget _cifra(
    String rotulo,
    String valor,
    IconData icono, {
    String? detalle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: EstiloVotaciones.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: EstiloVotaciones.moradoOscuro),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rotulo,
                  style: const TextStyle(
                    color: EstiloVotaciones.tintaSuave,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              color: EstiloVotaciones.tinta,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detalle != null)
            Text(
              detalle,
              style: const TextStyle(
                color: EstiloVotaciones.tintaApagada,
                fontSize: 11.5,
              ),
            ),
        ],
      ),
    );
  }

  /// Lo que dice el aviso del papel, con los números que haya.
  String _loQueDiceElPapel(Escrutinio datos) {
    final actas = datos.actas;
    final votos = datos.votosDePapel;
    final cuantas = actas == 1 ? 'un acta' : '$actas actas';

    if (votos == 0) {
      return 'Esta votación tiene $cuantas de papel. Sus votos se suman al'
          ' conteo, pero las papeletas no se pueden repartir por persona: no'
          ' entran en el porcentaje de participación.';
    }

    return '$votos ${votos == 1 ? 'voto viene' : 'votos vienen'} de $cuantas'
        ' de papel. Se suman al conteo, pero las papeletas no se pueden'
        ' repartir por persona: no entran en el porcentaje de participación.';
  }

  Widget _tarjetaDeCargo(CargoDelEscrutinio cargo, bool conNumeros) {
    final ganador = conNumeros ? cargo.ganador : null;
    final casillas = conNumeros ? cargo.porVotos : cargo.candidatos;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: EstiloVotaciones.tarjeta,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (conNumeros)
                Text(
                  '${cargo.total} ${cargo.total == 1 ? 'voto' : 'votos'}',
                  style: const TextStyle(
                    color: EstiloVotaciones.tintaSuave,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (casillas.isEmpty)
            const Text(
              'Este cargo no tuvo candidatos inscritos.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          for (final casilla in casillas)
            _barra(
              casilla,
              conNumeros: conNumeros,
              esGanador: ganador != null &&
                  ganador.candidatoId == casilla.candidatoId,
            ),
          // El blanco al final y en gris: es una casilla de la urna, no un
          // candidato, y va abajo por lo mismo que en el tarjetón.
          if (cargo.blanco != null)
            _barra(cargo.blanco!, conNumeros: conNumeros, esGanador: false),
        ],
      ),
    );
  }

  /// Una barra horizontal: avatar, nombre, número y porcentaje.
  ///
  /// **El avatar sale de la casilla y no de una consulta más.** El escrutinio no
  /// manda `foto_nombre` —`candidatosDe()` devuelve nombre, apellidos, plancha y
  /// número—, así que aquí el círculo son las iniciales sobre morado, que es lo
  /// que hace [CirculoDeCandidato] sin foto. Pedir las fotos una por una para
  /// esta pantalla serían veinte peticiones para adornar un recuento.
  Widget _barra(
    CasillaDelEscrutinio casilla, {
    required bool conNumeros,
    required bool esGanador,
  }) {
    final color =
        casilla.blanco ? PaletaEstaciones.gris : EstiloVotaciones.morado;
    final fraccion = (casilla.porcentaje / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CirculoDeCandidato(
                nombre: casilla.nombre,
                blanco: casilla.blanco,
                radio: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      casilla.nombre,
                      maxLines: 2,
                      style: TextStyle(
                        color: casilla.blanco
                            ? EstiloVotaciones.tintaSuave
                            : EstiloVotaciones.tinta,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (casilla.numero != null && casilla.numero!.isNotEmpty)
                      Text(
                        'Número ${casilla.numero}'
                        '${casilla.plancha == null || casilla.plancha!.isEmpty ? '' : ' · Plancha ${casilla.plancha}'}',
                        style: const TextStyle(
                          color: EstiloVotaciones.tintaApagada,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (esGanador) ...[
                const SizedBox(width: 8),
                EtiquetaDeEstado(
                  color: PaletaEstaciones.verde,
                  fondo: PaletaEstaciones.verdeFondo,
                  icono: Icons.emoji_events,
                  palabra: 'Ganador',
                ),
              ],
              if (conNumeros) ...[
                const SizedBox(width: 8),
                Text(
                  '${casilla.porcentaje.toStringAsFixed(1)} %',
                  style: TextStyle(
                    color: casilla.blanco
                        ? EstiloVotaciones.tintaSuave
                        : EstiloVotaciones.moradoOscuro,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (conNumeros) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 10,
                backgroundColor: casilla.blanco
                    ? const Color(0xFFEDEDF2)
                    : EstiloVotaciones.moradoSuave,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _elRenglonDelTotal(casilla),
              style: const TextStyle(
                color: EstiloVotaciones.tintaApagada,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// «312 votos», y «· 60 de papel» cuando los hay.
  ///
  /// El desglose va al lado del total porque **un candidato con 63 votos de los
  /// que 60 son de una sola acta es un dato distinto** de uno con 63 repartidos,
  /// y sin esto no se puede explicar un número sin volver a preguntar.
  String _elRenglonDelTotal(CasillaDelEscrutinio casilla) {
    final base = '${casilla.total} ${casilla.total == 1 ? 'voto' : 'votos'}';
    if (casilla.dePapel == 0) return base;
    return '$base · ${casilla.dePapel} de papel';
  }

  Widget _elError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Text(
          'No se pudieron traer los resultados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _cargar,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}
