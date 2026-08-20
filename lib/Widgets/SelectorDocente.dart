import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/constantes.dart';

/// El campo con el que se elige un docente, con su foto.
///
/// No es un DropdownButton y no lo será: son dieciséis docentes con nombres de
/// hasta cinco palabras, y en el menú de un dropdown la foto y el nombre no
/// caben en la misma línea sin recortar el nombre. La hoja inferior da el ancho
/// de la pantalla y sitio para una foto que se reconozca de un vistazo, que es
/// como el colegio distingue a «Ariolfo Gómez» de «Ariolfo Gómez Pico».
///
/// Nació dentro de la pantalla de asistencia a clases y se sacó aquí cuando la
/// de unidades necesitó lo mismo: tener dos formas de elegir docente en la
/// misma app es tener una buena y otra que alguien copió con prisa.
class CampoDocente extends StatelessWidget {
  const CampoDocente({
    super.key,
    required this.docentes,
    required this.elegido,
    required this.alElegir,
    this.etiqueta = 'Docente',
    this.titulo = 'Docentes',
  });

  final List<DocenteModel> docentes;
  final DocenteModel? elegido;

  /// Qué hacer con el elegido. No se llama si se cerró la hoja sin elegir ni
  /// si se volvió a tocar el que ya estaba: recargar para quedarse igual es
  /// una espera que no lleva a ninguna parte.
  final ValueChanged<DocenteModel> alElegir;

  /// El rótulo del campo.
  final String etiqueta;

  /// El título de la hoja. Cambia según de dónde salga la lista: los del
  /// grupo de un alumno no son los del colegio entero.
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final actual = elegido;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: InkWell(
        onTap: docentes.isEmpty ? null : () => _elegir(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etiqueta,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Row(
            children: [
              if (actual != null) ...[
                AvatarPersona(
                  nombre: actual.nombre,
                  fotoNombre: actual.fotoNombre,
                  radio: 16,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  actual?.nombre ?? 'Elige el docente',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: actual == null ? null : FontWeight.w600,
                    color: actual == null ? Colors.black54 : null,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _elegir(BuildContext context) async {
    final nuevo = await pedirDocente(
      context,
      docentes,
      elegido: elegido,
      titulo: titulo,
    );

    if (nuevo == null || identical(nuevo, elegido)) return;

    alElegir(nuevo);
  }
}

/// La hoja de abajo con los docentes y sus fotos.
///
/// Devuelve el elegido, o null si se cerró sin elegir. Se puede llamar suelta,
/// sin el campo, cuando la pantalla ya tiene dónde enseñar quién está elegido.
Future<DocenteModel?> pedirDocente(
  BuildContext context,
  List<DocenteModel> docentes, {
  DocenteModel? elegido,
  String titulo = 'Docentes',
}) {
  return showModalBottomSheet<DocenteModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.7,
    ),
    builder: (_) => _HojaDocentes(
      docentes: docentes,
      elegido: elegido,
      titulo: titulo,
    ),
  );
}

class _HojaDocentes extends StatelessWidget {
  const _HojaDocentes({
    required this.docentes,
    required this.elegido,
    required this.titulo,
  });

  final List<DocenteModel> docentes;
  final DocenteModel? elegido;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${docentes.length}',
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: docentes.length,
              itemBuilder: (context, i) {
                final docente = docentes[i];
                final esElActual = identical(docente, elegido);

                return ListTile(
                  leading: AvatarPersona(
                    nombre: docente.nombre,
                    fotoNombre: docente.fotoNombre,
                    radio: 22,
                  ),
                  title: Text(docente.nombre),
                  selected: esElActual,
                  trailing: esElActual
                      ? Icon(Icons.check, color: kPrimaryColor)
                      : null,
                  onTap: () => Navigator.pop(context, docente),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
