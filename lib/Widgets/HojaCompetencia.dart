import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/PrefijoDeBanda.dart';
import 'package:myvc_flutter/Widgets/CampoConSugerencias.dart';
import 'package:myvc_flutter/constantes.dart';

/// Lo que se escribió en la hoja: el texto y su marca.
class CompetenciaEscrita {
  const CompetenciaEscrita({required this.definicion, this.tipo});

  final String definicion;

  /// La «marca» del colegio —Saber, Hacer, Ser, cognitivo…—, o null.
  ///
  /// Null y no cadena vacía: el backend valida `tipo` como texto libre y
  /// convierte el vacío en `null`, así que mandar `''` sería pedirle que
  /// deshaga lo que la app podía no haber hecho.
  final String? tipo;
}

/// La hoja para escribir o corregir una competencia.
///
/// **Es una hoja inferior y no un diálogo, y eso lo decide el teclado.** Lo que
/// tiene que quedar visible mientras se escribe es el previo de impresión, y en
/// un `AlertDialog` el teclado lo tapa: el diálogo se centra en el hueco que
/// queda y el previo se va por debajo. Con la hoja, el previo queda justo encima
/// del teclado, que es donde se mira. Es el mismo trato que [pedirFrase] y
/// [pedirOrdinales].
///
/// ## El previo enseña TODAS las bandas, no una
///
/// El front web enseña una de ejemplo. Aquí se enseñan todas las que el colegio
/// tenga escritas, y el motivo no es adorno: **una frase puede encajar
/// perfectamente detrás de «Fortaleza en…» y ser absurda detrás de «Dificultad
/// en…»**. Con un solo ejemplo, el docente escribe las cuatro mal y se entera
/// cuando el boletín ya está en una casa.
///
/// Cuesta tres renglones de texto y caza el fallo mientras se escribe, que es
/// lo único que hace legible un catálogo de 536 frases. Ver `docs/competencias.md`
/// §3.4.
///
/// **Cuando ninguna banda tiene frase, el bloque no se pinta**: ni un marco
/// vacío ni un «(sin prefijo)». Es el caso de todos los colegios hoy —las
/// escalas vivas tienen la descripción vacía— y un hueco rotulado se lee como
/// que algo falta.
Future<CompetenciaEscrita?> pedirCompetencia(
  BuildContext context, {
  required String titulo,
  required List<EscalaDeValoracion> escalas,
  String definicionInicial = '',
  String? tipoInicial,
  List<String> marcasUsadas = const [],
}) {
  return showModalBottomSheet<CompetenciaEscrita>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => _HojaCompetencia(
      titulo: titulo,
      escalas: escalas,
      definicionInicial: definicionInicial,
      tipoInicial: tipoInicial,
      marcasUsadas: marcasUsadas,
    ),
  );
}

class _HojaCompetencia extends StatefulWidget {
  const _HojaCompetencia({
    required this.titulo,
    required this.escalas,
    required this.definicionInicial,
    required this.tipoInicial,
    required this.marcasUsadas,
  });

  final String titulo;
  final List<EscalaDeValoracion> escalas;
  final String definicionInicial;
  final String? tipoInicial;
  final List<String> marcasUsadas;

  @override
  State<_HojaCompetencia> createState() => _HojaCompetenciaState();
}

class _HojaCompetenciaState extends State<_HojaCompetencia> {
  late final TextEditingController _definicion;
  late final TextEditingController _tipo;
  final _focoDefinicion = FocusNode();
  final _focoTipo = FocusNode();

  @override
  void initState() {
    super.initState();
    _definicion = TextEditingController(text: widget.definicionInicial);
    _tipo = TextEditingController(text: widget.tipoInicial ?? '');
    // Repinta el previo mientras se teclea: es su única razón de ser.
    _definicion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _definicion.dispose();
    _tipo.dispose();
    _focoDefinicion.dispose();
    _focoTipo.dispose();
    super.dispose();
  }

  bool get _sePuedeGuardar => _definicion.text.trim().isNotEmpty;

  void _guardar() {
    if (!_sePuedeGuardar) return;

    final marca = _tipo.text.trim();

    Navigator.pop(
      context,
      CompetenciaEscrita(
        definicion: _definicion.text.trim(),
        tipo: marca.isEmpty ? null : marca,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previo = previoDeImpresion(_definicion.text, widget.escalas);

    return Padding(
      // El teclado empuja la hoja hacia arriba en vez de taparla.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // En tablet la hoja no se estira de lado a lado: un campo de texto
            // a lo ancho de diez pulgadas no lo lee nadie.
            constraints: const BoxConstraints(maxWidth: Anchos.ficha),
            child: SingleChildScrollView(
              // Horizontal a 4 y no a 20, y los hermanos ponen los 16 que
              // faltan: [CampoConSugerencias] trae su propio `Padding` de 16
              // por dentro y no se le puede quitar, así que sumarle 20 lo
              // dejaría un dedo más adentro que el campo de arriba.
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _conMargen(Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  )),
                  const SizedBox(height: 12),
                  _conMargen(TextField(
                    controller: _definicion,
                    focusNode: _focoDefinicion,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'La competencia',
                      border: OutlineInputBorder(),
                    ),
                  )),
                  const SizedBox(height: 12),
                  // Un solo campo y rotulado «opcional», y esto importa: `tipo`
                  // es `varchar(60)` anulable y texto libre, y **nunca hubo un
                  // mínimo de tres**. El mockup del front pintaba una Saber, una
                  // Hacer y una Ser, y tres filas con tres marcas distintas se
                  // leen como un trío obligatorio. Aquí se sugiere lo que el
                  // colegio ya escribió y nada más.
                  CampoConSugerencias(
                    controlador: _tipo,
                    foco: _focoTipo,
                    sugerencias: widget.marcasUsadas,
                    etiqueta: 'Marca (opcional)',
                    pista: 'Saber, Hacer, Ser… como las llame tu colegio',
                    lineas: 1,
                  ),
                  if (previo.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _conMargen(_buildPrevio(previo)),
                  ],
                  const SizedBox(height: 16),
                  _conMargen(Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sePuedeGuardar ? _guardar : null,
                        child: const Text('Guardar'),
                      ),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Los 16 px que [CampoConSugerencias] ya trae puestos por dentro.
  Widget _conMargen(Widget hijo) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: hijo,
      );

  Widget _buildPrevio(List<String> lineas) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se imprimirá:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...lineas.map(
            (linea) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $linea',
                style: const TextStyle(fontSize: 12.5, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
