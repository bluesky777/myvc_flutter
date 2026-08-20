import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/OrdinalModel.dart';
import 'package:myvc_flutter/constantes.dart';

/// El campo con el que se eligen los ordinales del manual de convivencia en
/// que incurrió el alumno.
///
/// Es el `ui-select multiple` del front web traducido a un teléfono: allí es
/// una caja que se despliega y filtra según se escribe, y aquí es un campo con
/// los elegidos a la vista y una hoja de abajo con buscador. Lo que se conserva
/// es lo que importa: que se busquen escribiendo —el manual pasa de cien
/// artículos y nadie baja rodando hasta el suyo— y que se puedan elegir varios.
///
/// El campo no guarda nada: avisa de cuáles quedaron elegidos y quien lo monta
/// decide qué hacer con eso. Es a propósito, porque crear y editar no se
/// parecen: al crear los ordinales viajan dentro de la situación, y al editar
/// hay que asignarlos y quitarlos uno a uno contra la tabla pivote.
class CampoOrdinales extends StatelessWidget {
  const CampoOrdinales({
    super.key,
    required this.catalogo,
    required this.elegidos,
    required this.alCambiar,
    this.etiqueta = 'Ordinales en que incurrió',
  });

  /// Todos los del año. Aquí solo se leen: crearlos y editarlos es cosa de la
  /// web.
  final List<OrdinalModel> catalogo;

  /// Los ids elegidos, en el orden en que se quieran enseñar.
  final List<int> elegidos;

  final ValueChanged<List<int>> alCambiar;

  final String etiqueta;

  List<OrdinalModel> get _elegidos {
    final porId = {for (final ordinal in catalogo) ordinal.id: ordinal};

    final resueltos = <OrdinalModel>[];
    for (final id in elegidos) {
      final ordinal = porId[id];
      if (ordinal != null) resueltos.add(ordinal);
    }
    return resueltos;
  }

  @override
  Widget build(BuildContext context) {
    final puestos = _elegidos;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        onTap: catalogo.isEmpty ? null : () => _elegir(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etiqueta,
            helperText: catalogo.isEmpty
                ? 'Este año no tiene ordinales cargados'
                : 'No es obligatorio',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: puestos.isEmpty
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        catalogo.isEmpty
                            ? 'No hay ordinales que elegir'
                            : 'Elige los ordinales',
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
                    for (final ordinal in puestos)
                      Chip(
                        label: Text(
                          // El número basta en el chip: la descripción entera
                          // ocuparía tres líneas por ordinal y con cuatro
                          // puestos no se vería el resto del formulario.
                          ordinal.numero.isEmpty
                              ? ordinal.descripcion
                              : ordinal.numero,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onDeleted: () => alCambiar(
                          [...elegidos]..remove(ordinal.id),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _elegir(BuildContext context) async {
    final nuevos = await pedirOrdinales(context, catalogo, elegidos: elegidos);

    if (nuevos == null) return;

    alCambiar(nuevos);
  }
}

/// La hoja con el manual entero y su buscador.
///
/// Devuelve los ids que quedaron marcados, o null si se cerró sin aceptar: sin
/// esa diferencia, cerrar por equivocación borraría los ordinales que ya
/// estaban puestos.
Future<List<int>?> pedirOrdinales(
  BuildContext context,
  List<OrdinalModel> catalogo, {
  List<int> elegidos = const [],
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
    builder: (_) => _HojaOrdinales(catalogo: catalogo, elegidos: elegidos),
  );
}

class _HojaOrdinales extends StatefulWidget {
  const _HojaOrdinales({required this.catalogo, required this.elegidos});

  final List<OrdinalModel> catalogo;
  final List<int> elegidos;

  @override
  State<_HojaOrdinales> createState() => _HojaOrdinalesState();
}

class _HojaOrdinalesState extends State<_HojaOrdinales> {
  late List<int> marcados;
  String busqueda = '';

  @override
  void initState() {
    super.initState();
    // Copia propia: mientras la hoja está abierta se marca y se desmarca sin
    // tocar lo que tiene el formulario de detrás, que solo cambia al aceptar.
    marcados = [...widget.elegidos];
  }

  List<OrdinalModel> get _filtrados =>
      widget.catalogo.where((o) => o.coincideCon(busqueda)).toList();

  void _alternar(OrdinalModel ordinal) {
    setState(() {
      if (marcados.contains(ordinal.id)) {
        marcados.remove(ordinal.id);
      } else {
        marcados.add(ordinal.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordinales = _filtrados;

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ordinales del manual',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (marcados.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(marcados.clear),
                      child: Text('Quitar todos'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por número o por texto',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (texto) => setState(() => busqueda = texto),
              ),
            ),
            Divider(height: 1),
            Flexible(
              child: ordinales.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        widget.catalogo.isEmpty
                            ? 'Este año no tiene ordinales cargados. Se cargan '
                                'desde la plataforma web.'
                            : 'Ningún ordinal dice eso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: ordinales.length,
                      itemBuilder: (context, i) {
                        final ordinal = ordinales[i];
                        final marcado = marcados.contains(ordinal.id);

                        return CheckboxListTile(
                          value: marcado,
                          onChanged: (_) => _alternar(ordinal),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: Text(
                            ordinal.numero.isEmpty ? '—' : ordinal.numero,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: marcado ? kPrimaryColor : null,
                            ),
                          ),
                          subtitle: Text(ordinal.descripcion),
                        );
                      },
                    ),
            ),
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      marcados.isEmpty
                          ? 'Ninguno elegido'
                          : '${marcados.length} elegido'
                              '${marcados.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, marcados),
                    child: Text('Aceptar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
