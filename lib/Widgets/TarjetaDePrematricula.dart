import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/PrematriculaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/constantes.dart';

/// «Prematrícula 2027» en la portada de la familia: un renglón por hijo.
///
/// Sale sólo cuando el colegio abrió la prematrícula de los antiguos (ver
/// [leerPrematricula]). Elegir el grupo y confirmar lo deja en `PREA`; la
/// matrícula se formaliza después, en el colegio. Si falta el pago de la
/// renovación, el renglón lo dice en vez de ofrecer el botón.
class TarjetaDePrematricula extends StatefulWidget {
  const TarjetaDePrematricula({
    super.key,
    required this.prematricula,
    required this.anio,
    required this.alCambiar,
    this.servidor,
  });

  final PrematriculaDeLaFamilia prematricula;

  /// El año que se prematricula, o null si no se sabe el de la sesión.
  final int? anio;

  /// Para recargar el muro cuando un hijo quedó prematriculado.
  final VoidCallback alCambiar;

  final Server? servidor;

  @override
  State<TarjetaDePrematricula> createState() => _TarjetaDePrematriculaState();
}

class _TarjetaDePrematriculaState extends State<TarjetaDePrematricula> {
  late final Server server = widget.servidor ?? Server();

  /// El grupo elegido para cada hijo, antes de confirmar.
  final Map<int, GrupoSiguiente> elegidos = {};

  /// Los hijos a los que el servidor les contestó el 409 en esta sesión.
  final Set<int> sinPago = {};

  int? mandando;

  String get _elAnio => widget.anio == null ? '' : ' ${widget.anio}';

  Future<void> _elegirGrupo(HijoAPrematricular hijo) async {
    final grupo = await showModalBottomSheet<GrupoSiguiente>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Grupo de ${hijo.primerNombre} para$_elAnio',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final g in widget.prematricula.grupos)
                ListTile(
                  title: Text(g.nombre),
                  trailing: elegidos[hijo.alumnoId]?.id == g.id
                      ? const Icon(Icons.check, color: kPrimaryColor)
                      : null,
                  onTap: () => Navigator.pop(context, g),
                ),
            ],
          ),
        ),
      ),
    );
    if (grupo != null) setState(() => elegidos[hijo.alumnoId] = grupo);
  }

  Future<void> _prematricular(HijoAPrematricular hijo) async {
    final grupo = elegidos[hijo.alumnoId];
    if (grupo == null) return;

    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('¿Prematricular a ${hijo.primerNombre} en ${grupo.nombre}?'),
        content: const Text(
          'Se aparta el cupo. Para cambiar el grupo después, hay que ir a '
          'secretaría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, prematricular'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;

    setState(() => mandando = hijo.alumnoId);
    final salida = await prematricular(
      server,
      alumnoId: hijo.alumnoId,
      grupoId: grupo.id,
    );
    if (!mounted) return;
    setState(() => mandando = null);

    switch (salida.resultado) {
      case ResultadoPrematricula.hecho:
        Analitica.evento('prematricula_hecha');
        widget.alCambiar();
      case ResultadoPrematricula.faltaPago:
        setState(() => sinPago.add(hijo.alumnoId));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(salida.mensaje!)));
      case ResultadoPrematricula.fallo:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(salida.mensaje!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hijos = widget.prematricula.hijos;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_seat_outlined, color: kPrimaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prematrícula$_elAnio',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Abierta',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Aparta el cupo de cada hijo para el año que viene. La matrícula '
              'se formaliza después, en el colegio.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (hijos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Todavía no hay ningún estudiante asociado a tu cuenta.',
                ),
              ),
            for (final hijo in hijos) ...[
              const Divider(height: 24),
              _renglon(hijo),
            ],
          ],
        ),
      ),
    );
  }

  Widget _renglon(HijoAPrematricular hijo) {
    final nombre = Text(
      '${hijo.nombres} ${hijo.apellidos}'.trim(),
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
    final actual = hijo.grupoActual == null
        ? null
        : Text(
            'Este año en ${hijo.grupoActual}',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          );

    final quedo = hijo.comoQuedo;
    if (quedo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nombre,
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.verified, size: 18, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hijo.grupoSiguiente == null
                      ? quedo
                      : '$quedo ${hijo.grupoSiguiente}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Para cambiar el grupo, acércate a secretaría.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      );
    }

    if (hijo.faltaPago || sinPago.contains(hijo.alumnoId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nombre,
          if (actual != null) actual,
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.payments_outlined,
                  size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Para prematricular, primero tesorería tiene que registrar '
                  'el pago del formulario de renovación.',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (widget.prematricula.grupos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nombre,
          if (actual != null) actual,
          const SizedBox(height: 6),
          Text(
            'El colegio todavía no ha abierto los grupos de$_elAnio.',
            style: const TextStyle(fontSize: 13.5),
          ),
        ],
      );
    }

    final elegido = elegidos[hijo.alumnoId];
    final ocupado = mandando == hijo.alumnoId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nombre,
        if (actual != null) actual,
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ocupado ? null : () => _elegirGrupo(hijo),
          icon: const Icon(Icons.groups_outlined, size: 18),
          label: Text(elegido == null
              ? 'Elegir el grupo para$_elAnio'
              : 'Grupo: ${elegido.nombre}'),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed:
                elegido == null || ocupado ? null : () => _prematricular(hijo),
            child: Text(ocupado
                ? 'Prematriculando…'
                : 'Prematricular a ${hijo.primerNombre}'),
          ),
        ),
      ],
    );
  }
}
