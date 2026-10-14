import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/MiCuentaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/MiCuentaModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:myvc_flutter/Utils/EstiloCartera.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';

/// El estado de cuenta de la familia con la tesorería, **sólo para leer**.
///
/// Es la pantalla `/mi-cuenta` de la web (`cartera/familia/mi-cuenta`) con el
/// mismo orden y las mismas frases, y la maqueta «Lo que ve la familia» del
/// prototipo de cartera para el teléfono: el saldo es lo primero que se ve, lo
/// vencido va arriba y en rojo, lo que aún no vence debajo y en gris.
///
/// Lo que **no** trae de la web, y por qué:
///
///  - **Pagar en línea.** Decidido el 8 oct 2026: la pasarela no se ha probado
///    con dinero de verdad, y el retorno de Wompi sólo acepta `https`, así que
///    tras pagar la familia caería en la web sin sesión. Aquí se dice cómo
///    pagar, como en la web cuando el colegio no tiene pasarela.
///  - **El recibo abierto.** La lista sí; el detalle (`mi-cuenta/recibos/{id}`)
///    queda en la web.
///
/// Sólo llega aquí quien [UserAutenticado.veSuCuenta]: el menú y el aviso lo
/// miran antes. Si aun así el servidor dice que no —el colegio apagó el
/// módulo—, se enseña su frase.
class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({super.key, this.aviso, this.server});

  /// Si se abrió desde el recordatorio de tesorería: los mensajes suben.
  final AvisoDeCartera? aviso;

  /// Para las pruebas, que le ponen un servidor de mentira.
  final Server? server;

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _drawerController = ZoomDrawerController();
  late final server = widget.server ?? Server();

  bool cargando = true;
  String? error;
  MiCuenta? cuenta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traida = await traerMiCuenta(server);
      if (!mounted) return;
      setState(() {
        cuenta = traida;
        cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = '$err'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: EstiloCartera.fondo,
        appBar: AppBar(
          backgroundColor: EstiloCartera.azul,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Mi cuenta'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle?.call(),
          ),
        ),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    final traida = cuenta;

    if (traida == null) {
      if (cargando) {
        return const Center(
          child: CircularProgressIndicator(color: EstiloCartera.azul),
        );
      }
      return _Fallo(mensaje: error ?? '', alReintentar: _cargar);
    }

    return RefreshIndicator(
      color: EstiloCartera.azul,
      onRefresh: Analitica.refresco('mi-cuenta', _cargar),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: _bloques(traida),
      ),
    );
  }

  List<Widget> _bloques(MiCuenta d) {
    final desdeAviso = widget.aviso != null;
    final variasCuentas = d.cuentas.length > 1;

    return [
      // Un error al refrescar con la cuenta ya pintada no la tapa: se avisa
      // arriba y se sigue viendo lo de antes.
      if (error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _Nota(texto: error!, tono: _Tono.mal),
        ),
      for (final (i, c) in d.cuentas.indexed) ...[
        _Saldo(
          cuenta: c,
          titulo: variasCuentas ? c.nombre : 'Su saldo con el colegio',
          pegadoArriba: i == 0,
        ),
        if (desdeAviso && c.mensajes.isNotEmpty)
          _Mensajes(mensajes: c.mensajes, resaltarElPrimero: true),
        if (c.acuerdo != null) _Acuerdo(acuerdo: c.acuerdo!),
        if (c.cobros.isNotEmpty) _LoQueFalta(cuenta: c),
        _ComoPagar(referencia: c.referencia),
        if (c.pagos.isNotEmpty) _Recibos(pagos: c.pagos),
        if (!desdeAviso && c.mensajes.isNotEmpty)
          _Mensajes(mensajes: c.mensajes),
      ],
      if (d.cuentas.isEmpty) const SizedBox(height: 4),
      if (d.hijos.isNotEmpty)
        _Hijos(hijos: d.hijos, sinCuenta: d.cuentas.isEmpty),
      if (d.vacia)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No hay nada que mostrar todavía.',
            textAlign: TextAlign.center,
            style: TextStyle(color: EstiloCartera.tintaApagada),
          ),
        ),
    ];
  }
}

/// El saldo, en azul. La primera cuenta va pegada a la barra, como en la
/// maqueta; si hay más de una —una empresa que paga la pensión—, cada una
/// lleva su tarjeta.
class _Saldo extends StatelessWidget {
  const _Saldo({
    required this.cuenta,
    required this.titulo,
    required this.pegadoArriba,
  });

  final CuentaDeTercero cuenta;
  final String titulo;
  final bool pegadoArriba;

  @override
  Widget build(BuildContext context) {
    const blanco = TextStyle(color: Colors.white);
    final suave = TextStyle(color: Colors.white.withValues(alpha: 0.85));

    final String estado;
    if (cuenta.vencido > 0) {
      estado = '';
    } else if (cuenta.debe > 0) {
      estado = 'Al día: nada vencido';
    } else {
      estado = 'Está a paz y salvo';
    }

    return Container(
      margin: pegadoArriba
          ? const EdgeInsets.only(bottom: 4)
          : const EdgeInsets.fromLTRB(16, 20, 16, 4),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: EstiloCartera.azul,
        borderRadius: pegadoArriba
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : BorderRadius.circular(EstiloCartera.radio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: suave.copyWith(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            pesos(cuenta.debe),
            style: blanco.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Rojo sobre azul no se lee: lo vencido va en una píldora blanca.
              if (cuenta.vencido > 0)
                EstiloCartera.pildora(
                  'Vencido ${pesos(cuenta.vencido)}',
                  Colors.white,
                  EstiloCartera.malTinta,
                ),
              if (estado.isNotEmpty)
                Text(estado, style: suave.copyWith(fontSize: 14)),
              if (cuenta.aFavor > 0)
                Text('A favor ${pesos(cuenta.aFavor)}',
                    style: suave.copyWith(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una caja blanca con su título.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijos});

  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: EstiloCartera.bloque(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: EstiloCartera.tinta,
            ),
          ),
          const SizedBox(height: 10),
          ...hijos,
        ],
      ),
    );
  }
}

/// Una fila de lista: lo de la izquierda en dos renglones y un valor a la
/// derecha.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.titulo,
    required this.detalle,
    required this.valor,
    this.colorDetalle = EstiloCartera.tintaApagada,
    this.colorValor = EstiloCartera.tinta,
    this.tachado = false,
  });

  final String titulo;
  final String detalle;
  final String valor;
  final Color colorDetalle;
  final Color colorValor;
  final bool tachado;

  @override
  Widget build(BuildContext context) {
    final decoracion = tachado ? TextDecoration.lineThrough : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tachado
                        ? EstiloCartera.tintaApagada
                        : EstiloCartera.tinta,
                    decoration: decoracion,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detalle,
                    style: TextStyle(fontSize: 12.5, color: colorDetalle)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tachado ? EstiloCartera.tintaApagada : colorValor,
              decoration: decoracion,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tono { aviso, mal, azul }

class _Nota extends StatelessWidget {
  const _Nota({required this.texto, this.negrita, required this.tono});

  final String texto;
  final String? negrita;
  final _Tono tono;

  @override
  Widget build(BuildContext context) {
    final (fondo, tinta) = switch (tono) {
      _Tono.aviso => (EstiloCartera.avisoFondo, EstiloCartera.avisoTinta),
      _Tono.mal => (EstiloCartera.malFondo, EstiloCartera.malTinta),
      _Tono.azul => (EstiloCartera.azulSuave, EstiloCartera.azulOscuro),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(children: [
          if (negrita != null)
            TextSpan(
              text: '$negrita ',
              style: TextStyle(fontWeight: FontWeight.w700, color: tinta),
            ),
          TextSpan(text: texto),
        ]),
        style: const TextStyle(fontSize: 13.5, color: EstiloCartera.tinta),
      ),
    );
  }
}

class _Acuerdo extends StatelessWidget {
  const _Acuerdo({required this.acuerdo});

  final AcuerdoDePago acuerdo;

  @override
  Widget build(BuildContext context) {
    final atrasada = acuerdo.atrasada;
    final proxima = acuerdo.proxima;
    final pagado = acuerdo.pagado;
    final total = acuerdo.total;

    return _Seccion(
      titulo: 'Acuerdo de pago',
      hijos: [
        if (atrasada != null) ...[
          _Nota(
            negrita: 'La cuota ${atrasada.n} venció el '
                '${fechaLarga(atrasada.vence)}.',
            texto: 'Faltan ${pesos(atrasada.porPagar)}. Mientras no se pague, '
                'los boletines pueden bloquearse.',
            tono: _Tono.aviso,
          ),
          const SizedBox(height: 12),
        ] else if (proxima != null) ...[
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Próxima cuota: '),
              TextSpan(
                text: pesos(proxima.porPagar),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' hasta el ${fechaLarga(proxima.vence)}'),
            ]),
            style: const TextStyle(color: EstiloCartera.tinta),
          ),
          const SizedBox(height: 12),
        ],
        if (pagado != null && total > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (pagado / total).clamp(0, 1).toDouble(),
              minHeight: 6,
              color: EstiloCartera.azul,
              backgroundColor: EstiloCartera.borde,
              semanticsLabel: 'Pagado ${pesos(pagado)} de ${pesos(total)}',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pagado ${pesos(pagado)} de ${pesos(total)} · '
            '${acuerdo.numeroDeCuotas} cuotas',
            style: const TextStyle(
                fontSize: 12.5, color: EstiloCartera.tintaApagada),
          ),
        ] else
          Text(
            'Por ${pesos(total)} en ${acuerdo.numeroDeCuotas} cuotas.',
            style: const TextStyle(color: EstiloCartera.tintaSuave),
          ),
      ],
    );
  }
}

class _LoQueFalta extends StatelessWidget {
  const _LoQueFalta({required this.cuenta});

  final CuentaDeTercero cuenta;

  @override
  Widget build(BuildContext context) {
    String deQuien(CobroPendiente c) =>
        c.alumno.isEmpty ? '' : '${c.alumno} · ';

    return _Seccion(
      titulo: 'Lo que falta por pagar',
      hijos: [
        for (final c in cuenta.vencidos)
          _Fila(
            titulo: c.descripcion,
            detalle: '${deQuien(c)}venció ${haceDias(c.dias)}',
            valor: pesos(c.pendiente),
            colorDetalle: EstiloCartera.malTinta,
            colorValor: EstiloCartera.malTinta,
          ),
        for (final c in cuenta.porVencer)
          _Fila(
            titulo: c.descripcion,
            detalle: '${deQuien(c)}vence el ${fechaCorta(c.vence)}',
            valor: pesos(c.pendiente),
          ),
      ],
    );
  }
}

class _ComoPagar extends StatelessWidget {
  const _ComoPagar({this.referencia});

  final String? referencia;

  @override
  Widget build(BuildContext context) {
    final ref = referencia;

    return _Seccion(
      titulo: 'Cómo pagar',
      hijos: [
        Text(
          'En la tesorería del colegio, en efectivo, transferencia o '
          'consignación.${ref != null ? ' Al consignar, escriba su referencia:' : ''}',
          style: const TextStyle(color: EstiloCartera.tintaSuave),
        ),
        if (ref != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  ref,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: EstiloCartera.tinta,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiar la referencia',
                color: EstiloCartera.azulOscuro,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: ref));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Referencia copiada.')),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Recibos extends StatelessWidget {
  const _Recibos({required this.pagos});

  final List<PagoRecibido> pagos;

  @override
  Widget build(BuildContext context) {
    return _Seccion(
      titulo: 'Recibos',
      hijos: [
        for (final p in pagos)
          _Fila(
            titulo: 'Recibo n.º ${p.numero}',
            detalle: [
              fechaCorta(p.fecha),
              if (p.medio.isNotEmpty) p.medio,
              if (p.anulado) 'anulado',
            ].join(' · '),
            valor: pesos(p.valor),
            tachado: p.anulado,
          ),
      ],
    );
  }
}

class _Mensajes extends StatelessWidget {
  const _Mensajes({required this.mensajes, this.resaltarElPrimero = false});

  final List<MensajeDeTesoreria> mensajes;

  /// Desde el aviso, el último mensaje es el que la familia vino a leer.
  final bool resaltarElPrimero;

  @override
  Widget build(BuildContext context) {
    return _Seccion(
      titulo: 'Mensajes de tesorería',
      hijos: [
        for (final (i, m) in mensajes.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: resaltarElPrimero && i == 0
                ? const EdgeInsets.all(12)
                : const EdgeInsets.symmetric(vertical: 4),
            decoration: resaltarElPrimero && i == 0
                ? BoxDecoration(
                    color: EstiloCartera.azulSuave,
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fechaCorta(m.enviado),
                  style: const TextStyle(
                      fontSize: 12, color: EstiloCartera.tintaApagada),
                ),
                const SizedBox(height: 2),
                Text(m.mensaje,
                    style: const TextStyle(color: EstiloCartera.tinta)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Hijos extends StatelessWidget {
  const _Hijos({required this.hijos, required this.sinCuenta});

  final List<HijoEnCartera> hijos;

  /// Quien mira no responde por ningún pago: ve los chips, no los valores.
  final bool sinCuenta;

  @override
  Widget build(BuildContext context) {
    return _Seccion(
      titulo: hijos.length == 1 ? 'Su hijo' : 'Sus hijos',
      hijos: [
        for (final h in hijos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AvatarPersona(nombre: h.nombre, fotoNombre: h.foto, radio: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: EstiloCartera.tinta,
                        ),
                      ),
                      if (h.grupo != null)
                        Text(
                          h.grupo!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: EstiloCartera.tintaApagada),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          h.alDia
                              ? EstiloCartera.pildora(
                                  'Al día',
                                  EstiloCartera.bienFondo,
                                  EstiloCartera.bienTinta)
                              : EstiloCartera.pildora(
                                  'Pendiente',
                                  EstiloCartera.avisoFondo,
                                  EstiloCartera.avisoTinta),
                          if (!h.boletinHabilitado)
                            EstiloCartera.pildora('Boletín bloqueado',
                                EstiloCartera.malFondo, EstiloCartera.malTinta),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (sinCuenta) ...[
          const SizedBox(height: 8),
          const Text(
            'Los valores los ve la persona que paga. Si es usted, pida en '
            'tesorería que lo registren como responsable de pago.',
            style: TextStyle(fontSize: 12.5, color: EstiloCartera.tintaApagada),
          ),
        ],
      ],
    );
  }
}

class _Fallo extends StatelessWidget {
  const _Fallo({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(mensaje, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EstiloCartera.azul,
              foregroundColor: Colors.white,
            ),
            onPressed: alReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
