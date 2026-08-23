import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/ConfigDisciplinaModel.dart';
import 'package:myvc_flutter/Models/SituacionModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/constantes.dart';

/// El campo con el que se dice de qué situaciones viene esta.
///
/// Es cómo el colegio convierte la reincidencia en una falta mayor: tres leves
/// se vuelven una grave. Al enlazarlas, el backend le pone `become_id` a cada
/// una apuntando a la nueva, y desde ese momento dejan de contar por separado
/// —el contador del periodo las salta— porque ya se contaron dentro de esta.
///
/// Por eso no es un adorno y por eso se enseña qué se está enganchando: quitar
/// tres situaciones de la cuenta de un alumno es una decisión, no un detalle.
class CampoSituacionesDerivantes extends StatelessWidget {
  const CampoSituacionesDerivantes({
    super.key,
    required this.candidatas,
    required this.elegidas,
    required this.alCambiar,
    required this.config,
    required this.tipoOrigen,
  });

  /// De las que puede venir. Las calcula el alumno, que es quien sabe en qué
  /// periodos mirar y cuáles ya cuelgan de otra.
  final List<SituacionModel> candidatas;

  final List<int> elegidas;
  final ValueChanged<List<int>> alCambiar;

  final ConfigDisciplinaModel config;

  /// El tipo del que se sube: una de tipo 2 viene de las de tipo 1.
  final int tipoOrigen;

  List<SituacionModel> get _elegidas {
    final porId = {for (final situacion in candidatas) situacion.id: situacion};

    final puestas = <SituacionModel>[];
    for (final id in elegidas) {
      final situacion = porId[id];
      if (situacion != null) puestas.add(situacion);
    }
    return puestas;
  }

  @override
  Widget build(BuildContext context) {
    final puestas = _elegidas;
    final vacio = candidatas.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        onTap: vacio ? null : () => _elegir(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Deriva de estas ${config.nombres(tipoOrigen)}',
            helperText: puestas.isEmpty
                ? 'No es obligatorio'
                : 'Dejarán de contar por separado: se cuentan dentro de esta',
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: puestas.isEmpty
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        vacio
                            ? 'No tiene ${config.nombres(tipoOrigen).toLowerCase()}'
                                ' sueltas que enganchar'
                            : 'Elige de cuáles viene',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    for (final situacion in puestas)
                      Chip(
                        label: Text(
                          _corta(situacion),
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onDeleted: () =>
                            alCambiar([...elegidas]..remove(situacion.id)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _elegir(BuildContext context) async {
    final nuevas = await pedirSituacionesDerivantes(
      context,
      candidatas,
      elegidas: elegidas,
      config: config,
      tipoOrigen: tipoOrigen,
    );

    if (nuevas == null) return;

    alCambiar(nuevas);
  }
}

/// Cómo se nombra una situación en un chip: el periodo y el día.
///
/// La descripción no cabe —son frases enteras— y el día es lo que distingue a
/// una de otra en una lista de cuatro del mismo tipo.
String _corta(SituacionModel situacion) {
  final dia = situacion.fecha == null ? 'sin día' : formatoDia(situacion.fecha);
  return 'P${situacion.numeroPeriodo} · $dia';
}

/// La hoja con las situaciones que se pueden enganchar, por periodo.
///
/// Devuelve los ids marcados, o null si se cerró sin aceptar.
Future<List<int>?> pedirSituacionesDerivantes(
  BuildContext context,
  List<SituacionModel> candidatas, {
  List<int> elegidas = const [],
  required ConfigDisciplinaModel config,
  required int tipoOrigen,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => _HojaSituaciones(
      candidatas: candidatas,
      elegidas: elegidas,
      config: config,
      tipoOrigen: tipoOrigen,
    ),
  );
}

class _HojaSituaciones extends StatefulWidget {
  const _HojaSituaciones({
    required this.candidatas,
    required this.elegidas,
    required this.config,
    required this.tipoOrigen,
  });

  final List<SituacionModel> candidatas;
  final List<int> elegidas;
  final ConfigDisciplinaModel config;
  final int tipoOrigen;

  @override
  State<_HojaSituaciones> createState() => _HojaSituacionesState();
}

class _HojaSituacionesState extends State<_HojaSituaciones> {
  late List<int> marcadas;

  @override
  void initState() {
    super.initState();
    // Copia propia: se marca y se desmarca sin tocar el formulario de detrás,
    // que solo cambia al aceptar.
    marcadas = [...widget.elegidas];
  }

  /// Por periodo, que es como se leen: «las dos del primero y una del
  /// segundo».
  Map<int, List<SituacionModel>> get _porPeriodo {
    final mapa = <int, List<SituacionModel>>{};
    for (final situacion in widget.candidatas) {
      mapa.putIfAbsent(situacion.numeroPeriodo, () => []).add(situacion);
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    final porPeriodo = _porPeriodo;
    final periodos = porPeriodo.keys.toList()..sort();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Viene de estas ${widget.config.nombres(widget.tipoOrigen)}',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (marcadas.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(marcadas.clear),
                    child: Text('Quitar todas'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Las que marques dejarán de contar por separado en su periodo: '
              'pasan a contarse dentro de esta.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
          Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final numero in periodos) ...[
                  Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.04),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Periodo $numero',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  for (final situacion in porPeriodo[numero]!)
                    CheckboxListTile(
                      value: marcadas.contains(situacion.id),
                      onChanged: (_) => setState(() {
                        if (marcadas.contains(situacion.id)) {
                          marcadas.remove(situacion.id);
                        } else {
                          marcadas.add(situacion.id);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(
                        situacion.fecha == null
                            ? 'Sin día'
                            : formatoDia(situacion.fecha),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(situacion.descripcion),
                    ),
                ],
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    marcadas.isEmpty
                        ? 'Ninguna'
                        : '${marcadas.length} marcada'
                            '${marcadas.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, marcadas),
                  style: FilledButton.styleFrom(backgroundColor: kPrimaryColor),
                  child: Text('Aceptar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
