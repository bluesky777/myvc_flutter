import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/ConfigDisciplinaModel.dart';
import 'package:myvc_flutter/Models/SituacionModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/CampoConSugerencias.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/Widgets/SelectorDocente.dart';
import 'package:myvc_flutter/Widgets/SelectorOrdinales.dart';
import 'package:myvc_flutter/constantes.dart';

/// Con qué se abre el editor.
class SituacionEditorArgs {
  final AlumnoDisciplinaModel alumno;
  final DatosDisciplina datos;

  /// En qué periodo se anota. El número es para el rótulo y el id para el
  /// backend, que no entiende de números de periodo.
  final int numeroPeriodo;
  final int periodoId;

  /// Los docentes del colegio, ya traídos por la pantalla de detrás. No se
  /// piden aquí: abrir un formulario no debería esperar a una petición.
  final List<DocenteModel> docentes;

  /// La situación que se está editando, o null para crear una nueva.
  final SituacionModel? situacion;

  SituacionEditorArgs({
    required this.alumno,
    required this.datos,
    required this.numeroPeriodo,
    required this.periodoId,
    this.docentes = const [],
    this.situacion,
  });
}

/// Crear o editar una situación de un alumno.
///
/// Es el modal de `crearFaltaModal.html` del front web, con los mismos campos y
/// una diferencia deliberada en cómo guarda los ordinales.
///
/// **Allí se guardan solos**: marcar un ordinal dispara `asignar-ordinal` en
/// ese instante, aunque después se cancele el formulario. Aquí no se toca nada
/// hasta pulsar Guardar, y entonces se manda todo junto. La razón es que en el
/// teléfono se cancela mucho más —basta el gesto de volver— y guardar a
/// espaldas de quien está escribiendo deja ordinales puestos en situaciones que
/// nadie llegó a modificar.
///
/// Cuando se guarda, primero van los ordinales y después el resto. Es al revés
/// de como se lee, y es a propósito: `disciplina/update` devuelve el alumno
/// recalculado, así que si los ordinales fueran después, lo que vuelve estaría
/// ya viejo y la ficha pintaría los de antes.
///
/// Al cerrarse devuelve el alumno recalculado por el backend, o null si no se
/// guardó nada.
class SituacionEditorScreen extends StatefulWidget {
  final SituacionEditorArgs args;

  const SituacionEditorScreen({super.key, required this.args});

  @override
  State<SituacionEditorScreen> createState() => _SituacionEditorScreenState();
}

class _SituacionEditorScreenState extends State<SituacionEditorScreen> {
  final Server server = Server();
  final _formulario = GlobalKey<FormState>();

  final _descripcion = TextEditingController();
  final _focoDescripcion = FocusNode();
  final _testigos = TextEditingController();
  final _descargo = TextEditingController();

  late int tipo;
  DateTime? fecha;
  DocenteModel? docente;
  late List<int> ordinales;

  bool guardando = false;
  bool borrando = false;

  SituacionModel? get situacion => widget.args.situacion;

  bool get creando => situacion == null;

  ConfigDisciplinaModel get config => widget.args.datos.config;

  /// Quién puede borrar una situación.
  ///
  /// El front web solo le enseña la papelera a coordinación y a los
  /// administradores; un docente crea y corrige, pero no borra lo que anotó
  /// otro. Se respeta la misma regla. El backend no la comprueba —cualquiera
  /// del personal puede llamar a `destroy`—, así que esto es un acuerdo del
  /// colegio, no una barrera.
  bool get puedeBorrar => AuthService.user.esEspecial;

  @override
  void initState() {
    super.initState();

    final actual = situacion;

    tipo = actual?.tipo ?? 1;
    fecha = actual?.fecha;
    ordinales = [...?actual?.ordinalIds];
    _descripcion.text = actual?.descripcion ?? '';
    _testigos.text = actual?.testigos ?? '';
    _descargo.text = actual?.descargo ?? '';

    final profesorId = actual?.profesorId;
    if (profesorId != null) {
      for (final candidato in widget.args.docentes) {
        if (candidato.profesorId == profesorId) docente = candidato;
      }
    }
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _focoDescripcion.dispose();
    _testigos.dispose();
    _descargo.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // La cara del alumno en la barra y no en el cuerpo: así se queda a la
        // vista mientras se rellena el formulario, y anotarle una falta al
        // alumno equivocado deja de depender de recordar a quién se tocó.
        title: Row(
          children: [
            AvatarPersona(
              nombre: widget.args.alumno.nombreCompleto,
              fotoNombre: widget.args.alumno.fotoNombre,
              radio: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TituloPantalla(
                titulo: creando ? 'Nueva situación' : 'Editar situación',
                subtitulo: widget.args.alumno.nombreCompleto,
              ),
            ),
          ],
        ),
        actions: [
          if (!creando && puedeBorrar)
            IconButton(
              tooltip: 'Borrar la situación',
              icon: Icon(Icons.delete_outline),
              onPressed: (guardando || borrando) ? null : _borrar,
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: guardando || borrando,
        child: Form(
          key: _formulario,
          child: ListView(
            children: [
              _enQuePeriodo(),
              _selectorDeTipo(),
              CampoConSugerencias(
                controlador: _descripcion,
                foco: _focoDescripcion,
                sugerencias: widget.args.datos.descripciones,
                etiqueta: 'Descripción',
                pista: 'Qué pasó',
                validar: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'Sin descripción no se sabe qué pasó.'
                    : null,
              ),
              _campoFecha(),
              _campoTexto(
                controlador: _testigos,
                etiqueta: 'Testigo(s)',
                pista: 'Quién lo vio',
              ),
              _campoTexto(
                controlador: _descargo,
                etiqueta: 'Descargo',
                pista: 'Lo que dice el estudiante',
                lineas: 3,
              ),
              _campoDocente(),
              CampoOrdinales(
                catalogo: widget.args.datos.ordinales,
                elegidos: ordinales,
                alCambiar: (nuevos) => setState(() => ordinales = nuevos),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: FilledButton.icon(
                  onPressed: guardando ? null : _guardar,
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Icon(Icons.save_outlined),
                  label: Text(creando ? 'Crear situación' : 'Guardar cambios'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// En qué periodo se está anotando.
  ///
  /// A tamaño de leerse y no en la letra chica del subtítulo: es lo que decide
  /// en qué casilla del año cae la situación, no se puede cambiar desde aquí
  /// —se elige antes, al abrir— y equivocarse de periodo no se ve hasta que
  /// alguien echa en falta la anotación.
  Widget _enQuePeriodo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
        ],
      ),
    );
  }

  /// Los tres tipos, con el nombre que les da el colegio.
  ///
  /// En vertical y no en una fila de botones: «Situación gravísima» no cabe
  /// tres veces a lo ancho de un teléfono, y recortarlas a «Situ…» deja al
  /// docente eligiendo a ciegas justo en el campo que decide la gravedad.
  Widget _selectorDeTipo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Tipo de situación',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        ),
        child: RadioGroup<int>(
          groupValue: tipo,
          onChanged: (elegido) => setState(() => tipo = elegido ?? tipo),
          child: Column(
            children: [
              for (final numero in ConfigDisciplinaModel.tipos)
                RadioListTile<int>(
                  value: numero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(config.nombre(numero)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoFecha() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        onTap: _elegirFecha,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha',
            helperText: 'El día en que pasó, no el de hoy',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          child: Row(
            children: [
              Icon(Icons.event_outlined, size: 20, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fecha == null ? 'Sin fecha' : formatoDia(fecha),
                  style: TextStyle(
                    color: fecha == null ? Colors.black54 : null,
                    fontWeight: fecha == null ? null : FontWeight.w600,
                  ),
                ),
              ),
              if (fecha != null)
                IconButton(
                  tooltip: 'Quitar la fecha',
                  icon: Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => fecha = null),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();

    final elegida = await showDatePicker(
      context: context,
      initialDate: fecha ?? ahora,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
    );

    if (elegida != null) setState(() => fecha = elegida);
  }

  Widget _campoTexto({
    required TextEditingController controlador,
    required String etiqueta,
    String? pista,
    int lineas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextFormField(
        controller: controlador,
        minLines: 1,
        maxLines: lineas,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: etiqueta,
          hintText: pista,
          alignLabelWithHint: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _campoDocente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CampoDocente(
          docentes: widget.args.docentes,
          elegido: docente,
          alElegir: (elegido) => setState(() => docente = elegido),
          etiqueta: 'Docente',
        ),
        if (docente != null)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: TextButton(
              onPressed: () => setState(() => docente = null),
              child: Text('Dejarlo sin docente'),
            ),
          ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;

    final yearId = ContextoAcademico.instancia.yearId;
    if (yearId == null) {
      _avisar('No se sabe con qué año se está trabajando.');
      return;
    }

    setState(() => guardando = true);

    final avisos = <String>[];

    // Primero los ordinales, para que el alumno que devuelva el guardado ya
    // los traiga. Ver el comentario de la clase.
    if (!creando) avisos.addAll(await _guardarOrdinales());

    final resultado = creando
        ? await crearSituacion(
            server,
            alumnoId: widget.args.alumno.alumnoId,
            periodoId: widget.args.periodoId,
            yearId: yearId,
            tipo: tipo,
            descripcion: _descripcion.text.trim(),
            fecha: fecha,
            testigos: _limpio(_testigos),
            descargo: _limpio(_descargo),
            profesorId: docente?.profesorId,
            ordinalIds: ordinales,
          )
        : await actualizarSituacion(
            server,
            situacionId: situacion!.id,
            alumnoId: widget.args.alumno.alumnoId,
            yearId: yearId,
            tipo: tipo,
            descripcion: _descripcion.text.trim(),
            fecha: fecha,
            testigos: _limpio(_testigos),
            descargo: _limpio(_descargo),
            profesorId: docente?.profesorId,
          );

    setState(() => guardando = false);

    if (!resultado.correcto) {
      _avisar(resultado.error!);
      return;
    }

    if (!mounted) return;

    if (avisos.isNotEmpty) {
      // Se guardó, pero algún ordinal se quedó por el camino. Se dice y se
      // sale igual: la situación está guardada y volver a entrar enseña
      // exactamente cómo quedó.
      _avisar('Se guardó, pero ${avisos.first}');
    }

    Navigator.pop(context, resultado.alumno);
  }

  /// Aplica a la tabla pivote lo que cambió, ordinal a ordinal.
  ///
  /// `disciplina/update` no los mira, así que esto no es un adorno: sin estas
  /// llamadas, marcar o desmarcar un ordinal no cambia nada en la base.
  ///
  /// Devuelve los avisos de lo que no se pudo. No corta al primer fallo: si un
  /// ordinal no se deja quitar, los otros tres cambios sí tienen que entrar.
  Future<List<String>> _guardarOrdinales() async {
    final antes = situacion!.ordinalIds.toSet();
    final ahora = ordinales.toSet();

    final avisos = <String>[];

    for (final id in ahora.difference(antes)) {
      final fallo = await asignarOrdinal(
        server,
        situacionId: situacion!.id,
        ordinalId: id,
      );
      if (fallo != null) avisos.add(fallo);
    }

    for (final id in antes.difference(ahora)) {
      final fallo = await quitarOrdinal(
        server,
        situacionId: situacion!.id,
        ordinalId: id,
      );
      if (fallo != null) avisos.add(fallo);
    }

    return avisos;
  }

  Future<void> _borrar() async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar la situación?'),
        content: Text(
          'Se quita de la ficha del alumno y de los contadores del periodo. '
          'Queda en la papelera del colegio y desde la plataforma web se '
          'puede restaurar.',
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

    setState(() => borrando = true);

    final resultado = await borrarSituacion(
      server,
      situacionId: situacion!.id,
      alumnoId: widget.args.alumno.alumnoId,
    );

    setState(() => borrando = false);

    if (!resultado.correcto) {
      _avisar(resultado.error!);
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, resultado.alumno);
  }

  /// El texto del campo, o null si está vacío.
  ///
  /// Cadena vacía y null no son lo mismo en la tabla, y guardar '' donde no
  /// había nada convierte un campo sin rellenar en un campo rellenado con
  /// nada.
  String? _limpio(TextEditingController controlador) {
    final texto = controlador.text.trim();
    return texto.isEmpty ? null : texto;
  }
}
