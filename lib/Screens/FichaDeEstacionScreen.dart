import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// La ficha en la estación — pantalla 04 de `docs/estaciones.md`.
///
/// ## Esta pantalla ya NO se abre en sólo-lectura por no ser tu estación
///
/// La versión de la maqueta llevaba un título *«Lo que cierras tú»* que era un
/// filtro de permiso: lo demás se veía en gris. **Eso cambió el 20 de septiembre
/// de 2026**, cuando Joseth decidió que cierra cualquiera del personal y `rol_id`
/// se descartó. Aquí eso significa que el recorrido entero se ve y se puede
/// cerrar, y **lo que protege el paso no es un 403**: es la firma con nombre y
/// hora, el deshacer de ocho segundos y el motivo escrito que lee la familia.
///
/// ## El globo sale en CUALQUIER estación, haya llegado o no
///
/// La barra de pasos lleva un bocadillo con número sobre el círculo de
/// cualquiera de ellas —la 1, la 4 o la 5, esté cerrada, en curso o sin
/// empezar—. No es un adorno: **el tesorero puede dejar escrito el lunes que esa
/// familia tiene un saldo pendiente y la estación 5 se atiende el sábado**, y
/// entre esas dos fechas el dato existe y no lo ve nadie. Quien atiende
/// Documentos tiene que poder verlo **antes** de mandar a la familia a hacer
/// cuatro colas.
class FichaDeEstacionScreen extends StatefulWidget {
  const FichaDeEstacionScreen({
    super.key,
    required this.estacion,
    required this.persona,
    this.servidor,
    this.encajada = false,
  });

  final Estacion estacion;
  final PersonaEnCola persona;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  /// Si va dentro del panel derecho de un maestro-detalle, en tablet.
  ///
  /// Encajada **no lleva `AppBar` propia**: ya está la de la cola, y dos barras
  /// seguidas en una tablet son media pantalla perdida. El nombre de quien se
  /// atiende sale entonces de la propia ficha, que ya lo enseña grande.
  final bool encajada;

  @override
  State<FichaDeEstacionScreen> createState() => _FichaDeEstacionScreenState();
}

class _FichaDeEstacionScreenState extends State<FichaDeEstacionScreen> {
  late final Server server = widget.servidor ?? Server();

  FichaDeEstacion? ficha;
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_ficha_abierta');
    _cargar();
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
      final traida = await traerLaFicha(server, widget.persona.id);
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

  /// El paso que esta estación atiende, dentro del recorrido de esta persona.
  PasoDelRecorrido? get _miPaso {
    final pasos = ficha?.pasos;
    if (pasos == null) return null;
    for (final paso in pasos) {
      if (paso.nro == widget.estacion.nro) return paso;
    }
    return null;
  }

  @override
  void didUpdateWidget(FichaDeEstacionScreen anterior) {
    super.didUpdateWidget(anterior);
    // En maestro-detalle el panel derecho no se recrea al tocar a otra persona
    // de la cola: se le cambia la persona. Sin esto, la tablet enseñaría la
    // ficha del anterior bajo el nombre del nuevo — el peor error posible aquí,
    // porque es silencioso y decide si una familia sigue en la fila.
    if (anterior.persona.id != widget.persona.id) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.encajada) {
      final pie = _elPie();
      return Container(
        color: PaletaEstaciones.fondo,
        child: Column(
          children: [
            Expanded(child: ColumnaDeFicha(child: _cuerpo())),
            if (pie != null) pie,
          ],
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
      body: ColumnaDeFicha(child: _cuerpo()),
      bottomNavigationBar: _elPie(),
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

    final actual = ficha;
    if (actual == null) {
      return const _Centrado(
        icono: Icons.person_search_outlined,
        texto: 'No se encontró el recorrido de esta persona.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _LaPersona(ficha: actual),
        const SizedBox(height: 10),
        _LaBarraDePasos(
          ficha: actual,
          nroDeMiEstacion: widget.estacion.nro,
        ),
        if (actual.leFalta != null) ...[
          const SizedBox(height: 10),
          _LaBandaDelSalteado(leFalta: actual.leFalta!),
        ],
        const SizedBox(height: 10),
        _LosRequisitos(paso: _miPaso, nombreEstacion: widget.estacion.nombre),
      ],
    );
  }

  /// Los dos botones del final, los dos apagados hoy y con su motivo escrito.
  Widget? _elPie() {
    if (cargando || error != null || ficha == null) return null;

    if (!PendientesEstaciones.marcarElPaso) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_clock,
                    size: 18,
                    color: PaletaEstaciones.tintaApagada,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cerrar ${widget.estacion.nombre}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PaletaEstaciones.tintaApagada,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                // Se dice el motivo entero, y por qué el orden es ése: quien lo
                // lee es quien puede decidir encenderlo.
                'Cerrar el paso está apagado hasta que estén las pantallas que '
                'lo acompañan: enseñar a qué estación pasa y qué le llega a la '
                'familia antes de confirmar, y el deshacer de ocho segundos. Un '
                'botón que cierre sin eso sería peor que no tenerlo.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: PaletaEstaciones.tintaApagada,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: PaletaEstaciones.alturaDeBoton,
              child: FilledButton(
                // El botón no se enciende mientras quede un obligatorio sin
                // resolver. Los opcionales nunca lo apagan.
                onPressed:
                    (_miPaso?.obligatoriosQueFaltan ?? 0) == 0 ? () {} : null,
                child: Text('Cerrar ${widget.estacion.nombre}'),
              ),
            ),
            if (PendientesEstaciones.devolverConMotivo)
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Devolver a la familia',
                  style: TextStyle(color: PaletaEstaciones.rojo),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Quién es, y cómo se llama a su casa.
class _LaPersona extends StatelessWidget {
  const _LaPersona({required this.ficha});

  final FichaDeEstacion ficha;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarPersona(
            nombre: ficha.persona.nombreCompleto,
            fotoNombre: ficha.persona.fotoNombre,
            radio: 27,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ficha.persona.nombreCompleto,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                if (ficha.persona.grupo != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    ficha.persona.grupo!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: PaletaEstaciones.tintaSuave,
                    ),
                  ),
                ],
                if (ficha.acudiente != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 14,
                        color: PaletaEstaciones.primarioOscuro,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ficha.telefonoAcudiente == null
                              ? ficha.acudiente!
                              : '${ficha.acudiente} · ${ficha.telefonoAcudiente}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PaletaEstaciones.primarioOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (ficha.codigo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: PaletaEstaciones.primarioSuave,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ficha.codigo!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: PaletaEstaciones.primarioOscuro,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// La barra horizontal de los N pasos.
///
/// Horizontal en la ficha —de un vistazo, ¿dónde va?— y vertical en la consulta,
/// que es leer y no mirar. **Se desplaza**, y eso no es una concesión: el
/// colegio arma las estaciones que quiera, así que el número no se conoce.
class _LaBarraDePasos extends StatelessWidget {
  const _LaBarraDePasos({required this.ficha, required this.nroDeMiEstacion});

  final FichaDeEstacion ficha;
  final int nroDeMiEstacion;

  @override
  Widget build(BuildContext context) {
    final cerrados =
        ficha.pasos.where((p) => p.estado == EstadoDelPaso.cumplido).length;
    final notas = ficha.notasDeTodoElRecorrido;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Lleva $cerrados de ${ficha.pasos.length} pasos del recorrido '
              'de este colegio',
              style: const TextStyle(
                fontSize: 13,
                color: PaletaEstaciones.tintaSuave,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final paso in ficha.pasos)
                  _UnPaso(paso: paso, esElMio: paso.nro == nroDeMiEstacion),
              ],
            ),
          ),
          if (notas.hayAlgo) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _ElAvisoDeLasNotas(ficha: ficha),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnPaso extends StatelessWidget {
  const _UnPaso({required this.paso, required this.esElMio});

  final PasoDelRecorrido paso;
  final bool esElMio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: _elCirculo()),
                if (paso.notas.hayAlgo)
                  Positioned(
                    top: -6,
                    right: -4,
                    child: _GloboDeNotas(
                      cuantas: paso.notas.total,
                      algoSinResolver: paso.notas.algoSinResolver,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            paso.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: esElMio ? FontWeight.w600 : FontWeight.w400,
              color:
                  esElMio ? PaletaEstaciones.primarioOscuro : paso.estado.color,
            ),
          ),
          // La palabra del estado, porque el color nunca va solo.
          Text(
            esElMio ? 'la tuya' : paso.estado.palabra,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              color: PaletaEstaciones.tintaApagada,
            ),
          ),
        ],
      ),
    );
  }

  Widget _elCirculo() {
    final cumplido = paso.estado == EstadoDelPaso.cumplido;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cumplido
            ? PaletaEstaciones.verde
            : esElMio
                ? PaletaEstaciones.primario
                : PaletaEstaciones.fondo,
        border: esElMio
            ? Border.all(color: const Color(0xFFD5D0F0), width: 3)
            : Border.all(color: PaletaEstaciones.borde),
      ),
      child: cumplido
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : Text(
              '${paso.nro}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: esElMio ? Colors.white : PaletaEstaciones.gris,
              ),
            ),
    );
  }
}

/// «Tesorería dejó 2 notas en la 5, una sin resolver.»
///
/// El número del globo **nunca va solo**: debajo de la barra va la misma
/// información en palabras, que es lo que se lee de verdad con sol en la cara.
class _ElAvisoDeLasNotas extends StatelessWidget {
  const _ElAvisoDeLasNotas({required this.ficha});

  final FichaDeEstacion ficha;

  @override
  Widget build(BuildContext context) {
    final conNotas = ficha.pasos.where((p) => p.notas.hayAlgo).toList();
    final algoSinResolver = conNotas.any((p) => p.notas.algoSinResolver);

    final frases = conNotas
        .map((p) => p.notas.enPalabras(p.nombre))
        .where((f) => f.isNotEmpty)
        .join('. ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PaletaEstaciones.ambarFondo,
        border: Border.all(color: const Color(0xFFF0DFC0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: PaletaEstaciones.ambar,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              algoSinResolver
                  ? '$frases. Léelas antes de mandarla.'
                  : '$frases.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF7A4300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «No lo atiendas todavía: le falta la 1.»
///
/// Ocupa el ancho entero **antes que la ficha**, porque hoy eso depende de que
/// quien atiende mire bien la hoja, y con fila detrás no mira. **Lo dice la
/// pantalla, no el profesor.**
class _LaBandaDelSalteado extends StatelessWidget {
  const _LaBandaDelSalteado({required this.leFalta});

  final PasoDelRecorrido leFalta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PaletaEstaciones.rojoFondo,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, size: 20, color: PaletaEstaciones.rojo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No lo atiendas todavía',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.rojoTinta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Le falta la Estación ${leFalta.nro} · ${leFalta.nombre}. '
                  'Mándalo allá y vuelve después.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: PaletaEstaciones.rojoTinta,
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

/// Lo que hay que entregar en esta estación.
class _LosRequisitos extends StatelessWidget {
  const _LosRequisitos({required this.paso, required this.nombreEstacion});

  final PasoDelRecorrido? paso;
  final String nombreEstacion;

  @override
  Widget build(BuildContext context) {
    final actual = paso;

    if (actual == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Esta persona no tiene este paso en su recorrido.',
          style: TextStyle(color: PaletaEstaciones.tintaSuave),
        ),
      );
    }

    if (actual.requisitos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '$nombreEstacion no tiene requisitos configurados: se cierra '
          'entera, sin lista.',
          style: const TextStyle(color: PaletaEstaciones.tintaSuave),
        ),
      );
    }

    final faltan = actual.obligatoriosQueFaltan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Lo que se cierra aquí',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
              ),
              Text(
                faltan == 0
                    ? 'todo listo'
                    : faltan == 1
                        ? 'falta 1 obligatorio'
                        : 'faltan $faltan obligatorios',
                style: TextStyle(
                  fontSize: 12.5,
                  color: faltan == 0
                      ? PaletaEstaciones.verdeTinta
                      : PaletaEstaciones.ambar,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: PaletaEstaciones.borde),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              for (var i = 0; i < actual.requisitos.length; i++)
                _UnRequisito(
                  requisito: actual.requisitos[i],
                  elUltimo: i == actual.requisitos.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnRequisito extends StatelessWidget {
  const _UnRequisito({required this.requisito, required this.elUltimo});

  final Requisito requisito;
  final bool elUltimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        border: elUltimo
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEFEEF5))),
      ),
      child: Row(
        children: [
          // Icono Y color Y palabra: los tres, siempre.
          Icon(requisito.estado.icono, size: 22, color: requisito.estado.color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        requisito.nombre,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: PaletaEstaciones.tinta,
                        ),
                      ),
                    ),
                    if (!requisito.obligatorio) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PaletaEstaciones.fondo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'opcional',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: PaletaEstaciones.tintaSuave,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  requisito.detalle ?? requisito.estado.palabra,
                  style: TextStyle(fontSize: 12, color: requisito.estado.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El mismo bocadillo de la cola. Ver `ColaDeEstacionScreen`.
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
