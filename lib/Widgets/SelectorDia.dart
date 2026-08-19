import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// Pide el día y la hora de una falta en un solo cuadro.
///
/// Arriba el calendario y abajo la hora y los minutos; Guardar se lleva las dos
/// cosas de una vez. Antes eran dos diálogos seguidos —calendario y después
/// reloj— y para corregir solo la hora había que pasar igual por el calendario.
///
/// La hora se teclea en el reloj de doce, con a. m. y p. m., que es como se
/// dice una hora aquí. A la columna fecha_hora sigue yendo en 24.
///
/// El día y la hora son un mismo dato en la columna fecha_hora, así que se
/// eligen juntos. Devuelve null si se cancela.
Future<DateTime?> pedirDiaDeFalta(BuildContext context, DateTime? actual) {
  final ahora = DateTime.now();

  return showDialog<DateTime>(
    context: context,
    builder: (_) => _DialogoDiaYHora(
      inicial: actual ?? ahora,
      ultimoDia: DateTime(ahora.year, ahora.month, ahora.day),
    ),
  );
}

class _DialogoDiaYHora extends StatefulWidget {
  final DateTime inicial;

  /// Hoy: una falta no puede ser de un día que aún no ha llegado.
  final DateTime ultimoDia;

  const _DialogoDiaYHora({required this.inicial, required this.ultimoDia});

  @override
  State<_DialogoDiaYHora> createState() => _DialogoDiaYHoraState();
}

class _DialogoDiaYHoraState extends State<_DialogoDiaYHora> {
  static final DateTime _primerDia = DateTime(2020);

  late DateTime dia;
  late TextEditingController hora;
  late TextEditingController minuto;

  /// Si la hora tecleada es de la tarde. Las 12 de la noche son a. m. y las 12
  /// del día son p. m.
  late bool esTarde;

  @override
  void initState() {
    super.initState();

    dia = _dentroDeRango(widget.inicial);
    esTarde = widget.inicial.hour >= 12;

    final doce = widget.inicial.hour % 12 == 0 ? 12 : widget.inicial.hour % 12;
    hora = TextEditingController(text: '$doce');
    minuto = TextEditingController(text: _dd(widget.inicial.minute));
  }

  @override
  void dispose() {
    hora.dispose();
    minuto.dispose();
    super.dispose();
  }

  /// El calendario revienta si el día de partida cae fuera de sus límites, y
  /// una falta guardada con fecha rara no tiene por qué impedir corregirla.
  DateTime _dentroDeRango(DateTime d) {
    final soloDia = DateTime(d.year, d.month, d.day);

    if (soloDia.isBefore(_primerDia)) return _primerDia;
    if (soloDia.isAfter(widget.ultimoDia)) return widget.ultimoDia;
    return soloDia;
  }

  int? get _horaValida => _enRango(hora.text, minimo: 1, maximo: 12);
  int? get _minutoValido => _enRango(minuto.text, minimo: 0, maximo: 59);

  int? _enRango(String texto, {required int minimo, required int maximo}) {
    final valor = int.tryParse(texto.trim());
    if (valor == null || valor < minimo || valor > maximo) return null;
    return valor;
  }

  void _guardar() {
    final h = _horaValida;
    final m = _minutoValido;
    if (h == null || m == null) return;

    Navigator.pop(
      context,
      DateTime(
        dia.year,
        dia.month,
        dia.day,
        hora24DesdeDoce(hora12: h, esTarde: esTarde),
        m,
        // Los segundos no se preguntan —nadie apunta una tardanza al segundo—
        // pero se conservan los que hubiera: no se toca lo que no se pidió.
        widget.inicial.second,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sePuedeGuardar = _horaValida != null && _minutoValido != null;

    return AlertDialog(
      title: Text('Día y hora de la falta'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 320,
                child: CalendarDatePicker(
                  initialDate: dia,
                  firstDate: _primerDia,
                  lastDate: widget.ultimoDia,
                  onDateChanged: (nuevo) => setState(() => dia = nuevo),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hora',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _campo(hora, minimo: 1, maximo: 12, pista: 'hh'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(':',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        _campo(minuto, minimo: 0, maximo: 59, pista: 'mm'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('a. m.')),
                              ButtonSegment(value: true, label: Text('p. m.')),
                            ],
                            selected: {esTarde},
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onSelectionChanged: (elegido) =>
                                setState(() => esTarde = elegido.first),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: sePuedeGuardar ? _guardar : null,
          child: Text('Guardar'),
        ),
      ],
    );
  }

  Widget _campo(
    TextEditingController controlador, {
    required int minimo,
    required int maximo,
    required String pista,
  }) {
    final valido = _enRango(controlador.text, minimo: minimo, maximo: maximo) != null;

    return SizedBox(
      width: 56,
      child: TextField(
        controller: controlador,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        style: TextStyle(fontSize: 20),
        decoration: InputDecoration(
          hintText: pista,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(),
          // Sin texto de error debajo: el cuadro no crece y el rojo ya dice
          // que ese número no vale.
          errorText: valido ? null : '',
          errorStyle: const TextStyle(fontSize: 0, height: 0),
        ),
        onTap: () => controlador.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controlador.text.length,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  String _dd(int n) => n.toString().padLeft(2, '0');
}
