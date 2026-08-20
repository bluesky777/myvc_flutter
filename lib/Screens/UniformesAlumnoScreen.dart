import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UniformesApi.dart';
import 'package:myvc_flutter/Models/UniformeModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';

/// Con qué se abre la pantalla.
class UniformesAlumnoArgs {
  final int alumnoId;
  final String nombre;
  final String? fotoNombre;

  final int numeroPeriodo;
  final int periodoId;

  /// Las que ya venían con el alumno. No se piden otra vez: no hay endpoint
  /// que traiga las fallas sueltas, vienen dentro de `disciplina/alumnos`.
  final List<UniformeModel> uniformes;

  UniformesAlumnoArgs({
    required this.alumnoId,
    required this.nombre,
    this.fotoNombre,
    required this.numeroPeriodo,
    required this.periodoId,
    this.uniformes = const [],
  });
}

/// Las fallas de uniforme de un alumno en un periodo.
///
/// No son situaciones del manual de convivencia: son su propia tabla, no se
/// tipifican con ordinales y no derivan en nada por sí solas. El colegio las
/// cuenta, y con suficientes abre una situación aparte.
///
/// Al cerrarse devuelve la lista como quedó, para que la ficha del alumno
/// pinte el contador al día sin volver a pedir el grupo entero.
class UniformesAlumnoScreen extends StatefulWidget {
  final UniformesAlumnoArgs args;

  const UniformesAlumnoScreen({super.key, required this.args});

  @override
  State<UniformesAlumnoScreen> createState() => _UniformesAlumnoScreenState();
}

class _UniformesAlumnoScreenState extends State<UniformesAlumnoScreen> {
  final Server server = Server();

  late List<UniformeModel> uniformes;

  /// Las fallas que están esperando respuesta, por id. Una por fila y no una
  /// para toda la pantalla: borrar la del martes no tiene por qué apagar los
  /// botones de la del jueves.
  final Set<int> ocupadas = {};

  bool agregando = false;

  @override
  void initState() {
    super.initState();
    uniformes = [...widget.args.uniformes];
    _ordenar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// De la más reciente a la más vieja. Las que no dicen qué día fueron, al
  /// final: no se puede afirmar que sean de ningún momento.
  void _ordenar() {
    uniformes.sort((a, b) {
      final unaFecha = a.fechaHora;
      final otraFecha = b.fechaHora;

      if (unaFecha == null && otraFecha == null) return 0;
      if (unaFecha == null) return 1;
      if (otraFecha == null) return -1;

      return otraFecha.compareTo(unaFecha);
    });
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<List<UniformeModel>>(
      // Se sale devolviendo la lista, también con el gesto de volver: si no,
      // la ficha de detrás se quedaría con el contador de cuando se entró.
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) {
        if (yaSalio) return;
        Navigator.pop(context, uniformes);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              AvatarPersona(
                nombre: widget.args.nombre,
                fotoNombre: widget.args.fotoNombre,
                radio: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TituloPantalla(
                  titulo: 'Fallas de uniforme',
                  subtitulo: widget.args.nombre,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: agregando ? null : _agregar,
          icon: Icon(Icons.add),
          label: Text('Registrar falla'),
        ),
        body: Column(
          children: [
            _cabecera(),
            Divider(height: 1),
            Expanded(
              child: uniformes.isEmpty ? _vacio() : _lista(),
            ),
          ],
        ),
      ),
    );
  }

  /// De qué periodo son estas fallas, y cuántas van.
  ///
  /// El periodo, a tamaño de leerse: aquí se registra y se borra, y no hay
  /// forma de cambiarlo desde esta pantalla, así que tiene que estar claro
  /// antes de tocar nada.
  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, size: 19, color: kPrimaryColor),
          const SizedBox(width: 8),
          Text(
            'Periodo ${widget.args.numeroPeriodo}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kPrimaryColor,
            ),
          ),
          const Spacer(),
          Text(
            uniformes.isEmpty
                ? 'Sin fallas'
                : '${uniformes.length} falla'
                    '${uniformes.length == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom_outlined, size: 44, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              'Este periodo no tiene ninguna falla de uniforme.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: uniformes.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, i) {
        final uniforme = uniformes[i];
        final ocupada = ocupadas.contains(uniforme.id);

        return Opacity(
          opacity: ocupada ? 0.5 : 1,
          child: ListTile(
            leading: Icon(
              uniforme.excusado
                  ? Icons.verified_outlined
                  : Icons.checkroom_outlined,
              color: uniforme.excusado ? Colors.green[700] : kPrimaryColor,
            ),
            title: Text(
              uniforme.fechaHora == null
                  ? 'Sin día'
                  : formatoDiaYHora(uniforme.fechaHora),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (uniforme.sinMarcas)
                  Text('Sin marcar en qué falló',
                      style: TextStyle(fontStyle: FontStyle.italic))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      for (final nombre in uniforme.nombresDeMarcas)
                        _Etiqueta(texto: nombre),
                      if (uniforme.excusado)
                        _Etiqueta(texto: 'Excusado', verde: true),
                    ],
                  ),
                if (uniforme.descripcion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(uniforme.descripcion!),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: Icon(Icons.edit_outlined, size: 20),
                  onPressed: ocupada ? null : () => _editar(uniforme),
                ),
                IconButton(
                  tooltip: 'Borrar',
                  icon: Icon(Icons.delete_outline, size: 20),
                  onPressed: ocupada ? null : () => _borrar(uniforme),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _agregar() async {
    final nueva = await _pedirDatos(
      UniformeModel(id: 0, fechaHora: DateTime.now()),
      titulo: 'Registrar falla de uniforme',
    );

    if (nueva == null) return;

    setState(() => agregando = true);

    final resultado = await agregarUniforme(
      server,
      alumnoId: widget.args.alumnoId,
      periodoId: widget.args.periodoId,
      uniforme: nueva,
    );

    setState(() => agregando = false);

    if (!resultado.correcto) {
      _avisar(resultado.error!);
      return;
    }

    setState(() {
      uniformes.add(resultado.uniforme!);
      _ordenar();
    });
  }

  Future<void> _editar(UniformeModel uniforme) async {
    final cambiada = await _pedirDatos(uniforme, titulo: 'Editar falla');

    if (cambiada == null) return;

    setState(() => ocupadas.add(uniforme.id));

    final fallo = await actualizarUniforme(server, uniforme: cambiada);

    setState(() => ocupadas.remove(uniforme.id));

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    setState(() {
      uniformes = [
        for (final una in uniformes) una.id == cambiada.id ? cambiada : una
      ];
      _ordenar();
    });
  }

  Future<void> _borrar(UniformeModel uniforme) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar la falla?'),
        content: Text(
          'Deja de contar en el periodo. Queda en la papelera del colegio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Dejarla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Borrar'),
          ),
        ],
      ),
    );

    if (seguro != true) return;

    setState(() => ocupadas.add(uniforme.id));

    final fallo = await eliminarUniforme(
      server,
      uniformeId: uniforme.id,
      alumnoId: widget.args.alumnoId,
    );

    setState(() => ocupadas.remove(uniforme.id));

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    // La fila se quita de la lista de aquí y no de la que devuelve el backend:
    // esa consulta filtra por asignatura y por el periodo del usuario, y desde
    // esta pantalla vuelve siempre vacía. Ver eliminarUniforme().
    setState(() => uniformes.removeWhere((una) => una.id == uniforme.id));
  }

  /// La hoja con los datos de una falla, para crearla o para editarla.
  Future<UniformeModel?> _pedirDatos(
    UniformeModel inicial, {
    required String titulo,
  }) {
    return showModalBottomSheet<UniformeModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) => _HojaUniforme(inicial: inicial, titulo: titulo),
    );
  }
}

/// El formulario de una falla de uniforme.
class _HojaUniforme extends StatefulWidget {
  const _HojaUniforme({required this.inicial, required this.titulo});

  final UniformeModel inicial;
  final String titulo;

  @override
  State<_HojaUniforme> createState() => _HojaUniformeState();
}

class _HojaUniformeState extends State<_HojaUniforme> {
  late Set<MarcaUniforme> marcas;
  late bool excusado;
  late DateTime cuando;
  late TextEditingController descripcion;

  @override
  void initState() {
    super.initState();
    marcas = {...widget.inicial.marcas};
    excusado = widget.inicial.excusado;
    cuando = widget.inicial.fechaHora ?? DateTime.now();
    descripcion = TextEditingController(text: widget.inicial.descripcion ?? '');
  }

  @override
  void dispose() {
    descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.titulo,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text('En qué falló',
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final marca in MarcaUniforme.values)
                    FilterChip(
                      label: Text(marca.nombre),
                      selected: marcas.contains(marca),
                      onSelected: (puesta) => setState(() {
                        if (puesta) {
                          marcas.add(marca);
                        } else {
                          marcas.remove(marca);
                        }
                      }),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              value: excusado,
              onChanged: (valor) => setState(() => excusado = valor),
              title: Text('Excusado'),
              subtitle: Text('El colegio le aceptó la excusa'),
            ),
            ListTile(
              leading: Icon(Icons.event_outlined),
              title: Text('Día'),
              subtitle: Text(formatoDia(cuando)),
              onTap: _elegirDia,
            ),
            ListTile(
              leading: Icon(Icons.schedule_outlined),
              title: Text('Hora'),
              subtitle: Text(formatoHora12(cuando)),
              onTap: _elegirHora,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: descripcion,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Descargo, detalles…',
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (marcas.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'No marcaste en qué falló. Se puede guardar así, pero en la '
                  'lista solo se verá la fecha.',
                  style: TextStyle(color: Colors.orange[800], fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _aceptar,
                      child: Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirDia() async {
    final ahora = DateTime.now();

    final dia = await showDatePicker(
      context: context,
      initialDate: cuando,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
    );

    if (dia == null) return;

    setState(() => cuando =
        DateTime(dia.year, dia.month, dia.day, cuando.hour, cuando.minute));
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(cuando),
    );

    if (hora == null) return;

    setState(() => cuando = DateTime(
        cuando.year, cuando.month, cuando.day, hora.hour, hora.minute));
  }

  void _aceptar() {
    final texto = descripcion.text.trim();

    // Se construye entera y no con `con()`: allí un null quiere decir «esto no
    // se toca», así que borrar del todo la descripción no llegaría a guardarse
    // nunca. Aquí lo que hay en el formulario es lo que queda, tal cual.
    Navigator.pop(
      context,
      UniformeModel(
        id: widget.inicial.id,
        alumnoId: widget.inicial.alumnoId,
        periodoId: widget.inicial.periodoId,
        materia: widget.inicial.materia,
        marcas: marcas,
        excusado: excusado,
        fechaHora: cuando,
        // Cadena vacía y null no son lo mismo en la tabla.
        descripcion: texto.isEmpty ? null : texto,
      ),
    );
  }
}

/// Una de las marcas, en pequeño, dentro de la fila de la lista.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, this.verde = false});

  final String texto;
  final bool verde;

  @override
  Widget build(BuildContext context) {
    final color = verde ? Colors.green[700]! : kPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
