import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/constantes.dart';

/// El campo con el que se elige un grupo.
///
/// Se parece a propósito a `CampoDocente`: es el mismo gesto —tocar y elegir en
/// una hoja de abajo— para que el docente no tenga que aprender dos. Lo que
/// cambia es que un grupo no es una persona, así que en vez de foto lleva su
/// abreviatura, y que la hoja trae buscador: un colegio grande pasa de treinta
/// grupos y bajar rodando hasta «11-C» es peor que escribir «11».
class CampoGrupo extends StatelessWidget {
  const CampoGrupo({
    super.key,
    required this.grupos,
    required this.elegido,
    required this.alElegir,
    this.etiqueta = 'Grupo',
  });

  final List<GrupoModel> grupos;
  final GrupoModel? elegido;

  /// No se llama al cerrar sin elegir ni al volver a tocar el que ya estaba:
  /// recargar cuarenta alumnos para quedarse igual es una espera que no lleva
  /// a ninguna parte.
  final ValueChanged<GrupoModel> alElegir;

  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final actual = elegido;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        onTap: grupos.isEmpty ? null : () => _elegir(context),
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
                _Insignia(grupo: actual, radio: 16),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  actual == null
                      ? (grupos.isEmpty
                          ? 'No hay grupos que mirar'
                          : 'Elige el grupo')
                      : _titulo(actual),
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
    final nuevo = await pedirGrupo(context, grupos, elegido: elegido);

    if (nuevo == null || nuevo.id == elegido?.id) return;

    alElegir(nuevo);
  }
}

/// El nombre del grupo como se lee: «10-B · Décimo B».
///
/// Con el grado detrás cuando lo hay, porque dos grupos pueden llamarse igual
/// de abreviado en jornadas distintas y la abreviatura sola no los separa.
String _titulo(GrupoModel grupo) {
  final nombre = grupo.nombre.trim();
  final grado = grupo.nombreGrado?.trim();

  if (grado == null || grado.isEmpty || grado == nombre) return nombre;
  return '$nombre · $grado';
}

/// La hoja de abajo con los grupos y su buscador.
///
/// Devuelve el elegido, o null si se cerró sin elegir.
Future<GrupoModel?> pedirGrupo(
  BuildContext context,
  List<GrupoModel> grupos, {
  GrupoModel? elegido,
  String titulo = 'Grupos',
}) {
  return showModalBottomSheet<GrupoModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.75,
    ),
    builder: (_) =>
        _HojaGrupos(grupos: grupos, elegido: elegido, titulo: titulo),
  );
}

class _HojaGrupos extends StatefulWidget {
  const _HojaGrupos({
    required this.grupos,
    required this.elegido,
    required this.titulo,
  });

  final List<GrupoModel> grupos;
  final GrupoModel? elegido;
  final String titulo;

  @override
  State<_HojaGrupos> createState() => _HojaGruposState();
}

class _HojaGruposState extends State<_HojaGrupos> {
  String busqueda = '';

  /// El buscador solo aparece cuando hay lista que buscar. Con seis grupos
  /// —un docente cualquiera— un campo de texto encima es un estorbo.
  bool get conBuscador => widget.grupos.length > 8;

  List<GrupoModel> get _filtrados {
    final aguja = busqueda.trim().toLowerCase();
    if (aguja.isEmpty) return widget.grupos;

    return widget.grupos.where((grupo) {
      final paja = '${grupo.nombre} ${grupo.abrev} ${grupo.nombreGrado ?? ''} '
              '${grupo.nombreTitular ?? ''}'
          .toLowerCase();
      return paja.contains(aguja);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _filtrados;

    return SafeArea(
      child: Padding(
        // Para que el buscador no se quede debajo del teclado.
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${grupos.length}',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            if (conBuscador)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar grupo',
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
              child: grupos.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text('Ningún grupo se llama así.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: grupos.length,
                      itemBuilder: (context, i) {
                        final grupo = grupos[i];
                        final esElActual = grupo.id == widget.elegido?.id;

                        return ListTile(
                          leading: _Insignia(grupo: grupo, radio: 20),
                          title: Text(_titulo(grupo)),
                          subtitle: grupo.nombreTitular == null
                              ? null
                              : Text('Titular: ${grupo.nombreTitular}'),
                          selected: esElActual,
                          trailing: esElActual
                              ? Icon(Icons.check, color: kPrimaryColor)
                              : null,
                          onTap: () => Navigator.pop(context, grupo),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La abreviatura del grupo en un círculo, que hace de icono.
class _Insignia extends StatelessWidget {
  const _Insignia({required this.grupo, required this.radio});

  final GrupoModel grupo;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final abrev = grupo.abrev.trim().isEmpty
        ? grupo.nombre.trim()
        : grupo.abrev.trim();

    return CircleAvatar(
      radius: radio,
      backgroundColor: kPrimaryColor,
      child: Text(
        // Más de cuatro caracteres no caben en el círculo sin encogerse hasta
        // no leerse; la abreviatura de un grupo rara vez pasa de tres.
        abrev.length > 4 ? abrev.substring(0, 4) : abrev,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radio * 0.62,
        ),
      ),
    );
  }
}
