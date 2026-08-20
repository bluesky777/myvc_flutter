import 'package:flutter/material.dart';

/// Un campo de texto que sugiere lo ya escrito otras veces.
///
/// Es el `uib-typeahead` del front web: al teclear la descripción de una
/// situación, propone las que el colegio ya ha escrito este año y el pasado.
/// No es un desplegable con opciones cerradas —se puede escribir cualquier
/// cosa—, es un atajo: «Llegó tarde a la formación» se repite doscientas veces
/// al año y nadie debería teclearla doscientas veces.
///
/// El texto lo lleva el controlador de quien lo monta, no este widget: la
/// pantalla necesita leerlo para guardar y rellenarlo al abrir una situación
/// que ya existe.
class CampoConSugerencias extends StatelessWidget {
  const CampoConSugerencias({
    super.key,
    required this.controlador,
    required this.foco,
    required this.sugerencias,
    required this.etiqueta,
    this.pista,
    this.lineas = 3,
    this.validar,
  });

  final TextEditingController controlador;
  final FocusNode foco;

  /// De dónde salen las propuestas. Puede venir vacía y entonces el campo es
  /// un campo de texto normal.
  final List<String> sugerencias;

  final String etiqueta;
  final String? pista;
  final int lineas;
  final String? Function(String?)? validar;

  /// Cuántas letras hay que llevar escritas antes de proponer nada.
  ///
  /// Con una sola, la lista tapa el formulario entero desde la primera tecla y
  /// estorba más de lo que ayuda.
  static const _minimoParaSugerir = 2;

  /// Cuántas se enseñan. Las mismas ocho que el front web.
  static const _cuantas = 8;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: LayoutBuilder(
        builder: (context, medidas) {
          return RawAutocomplete<String>(
            textEditingController: controlador,
            focusNode: foco,
            optionsBuilder: _proponer,
            fieldViewBuilder: (context, controlador, foco, alEnviar) {
              return TextFormField(
                controller: controlador,
                focusNode: foco,
                minLines: 1,
                maxLines: lineas,
                textCapitalization: TextCapitalization.sentences,
                validator: validar,
                decoration: InputDecoration(
                  labelText: etiqueta,
                  hintText: pista,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            optionsViewBuilder: (context, alElegir, opciones) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 240,
                      maxWidth: medidas.maxWidth,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: opciones.length,
                      itemBuilder: (context, i) {
                        final opcion = opciones.elementAt(i);

                        return ListTile(
                          dense: true,
                          title: Text(
                            opcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => alElegir(opcion),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Iterable<String> _proponer(TextEditingValue valor) {
    final aguja = valor.text.trim().toLowerCase();
    if (aguja.length < _minimoParaSugerir) return const Iterable<String>.empty();

    return sugerencias
        .where((sugerencia) {
          final paja = sugerencia.toLowerCase();
          // Fuera la que ya está escrita entera: proponer lo que uno acaba de
          // teclear es una fila que solo estorba.
          return paja != aguja && paja.contains(aguja);
        })
        .take(_cuantas);
  }
}
