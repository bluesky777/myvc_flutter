import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';

/// La planilla de un indicador: los alumnos del grupo y su nota en esa casilla.
///
/// Es la pantalla del trabajo diario —se acaba la clase y se pasan las treinta
/// notas de un quiz— y por eso todo aquí está pensado para escribir rápido:
///
///  - Teclado numérico y el campo seleccionado entero al entrar, para escribir
///    encima sin borrar lo que había.
///  - «Siguiente» del teclado baja al alumno de abajo **sin cerrar el
///    teclado**. Es el equivalente del «Tab vertical» del front web y es lo que
///    decide si pasar treinta notas cuesta un minuto o cinco.
///  - «A todos» rellena la columna de una vez, para el caso real: casi todos
///    sacaron lo mismo y hay tres excepciones.
///
/// **Se guarda al pulsar Guardar, no al teclear.** El front web manda un `PUT`
/// por nota, un segundo después de salir del campo; una columna de treinta son
/// treinta peticiones sueltas. En un teléfono con la red del colegio eso deja
/// al docente sin saber cuáles entraron. Aquí se edita en local, se manda solo
/// lo que cambió, de tres en tres, y lo que falle se queda marcado para
/// reintentarlo sin volver a teclear nada.
class PlanillaScreen extends StatefulWidget {
  const PlanillaScreen({
    super.key,
    required this.libro,
    required this.unidad,
    required this.subunidad,
  });

  final LibroDeNotas libro;
  final UnidadModel unidad;
  final SubunidadModel subunidad;

  @override
  State<PlanillaScreen> createState() => _PlanillaScreenState();
}

class _PlanillaScreenState extends State<PlanillaScreen> {
  final Server server = Server();

  /// Un campo y un foco por alumno, en el mismo orden en que se pintan.
  final List<TextEditingController> _campos = [];
  final List<FocusNode> _focos = [];

  final _aTodos = TextEditingController();

  /// Lo que trajo el servidor, para saber qué cambió de verdad.
  final List<double?> _original = [];

  /// Las que no entraron en el último guardado, por id de alumno.
  Set<int> _fallidas = {};

  bool guardando = false;
  int _hechas = 0;

  /// Todo lo que se ha guardado en esta pantalla, para devolverlo al salir.
  final List<NotaPendiente> _guardadas = [];

  bool get _puedeEditar =>
      ContextoAcademico.instancia.config.puedeEditarNotas;

  List<AlumnoDelLibro> get _alumnos => widget.libro.alumnos;

  @override
  void initState() {
    super.initState();

    for (final alumno in _alumnos) {
      final nota = alumno.notaDe(widget.subunidad.id)?.nota;
      _original.add(nota);
      _campos.add(TextEditingController(text: notaEscrita(nota)));
      _focos.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.dispose();
    }
    for (final foco in _focos) {
      foco.dispose();
    }
    _aTodos.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// Lo que hay escrito ahora en ese campo, o null si está vacío.
  double? _leido(int indice) => notaLeida(_campos[indice].text);

  /// Las notas que cambiaron y se pueden guardar.
  ///
  /// Solo las que cambiaron: en el caso «puse 100 a todos y ya estaban en 100»
  /// son cero peticiones, donde el front web hace treinta. Y se saltan las que
  /// no tienen fila en `notas` —id 0—, porque `notas/update/{id}` no tendría
  /// qué actualizar.
  List<NotaPendiente> get _pendientes {
    final cambios = <NotaPendiente>[];

    for (var i = 0; i < _alumnos.length; i++) {
      final escrita = _leido(i);
      if (escrita == null || escrita == _original[i]) continue;

      final nota = _alumnos[i].notaDe(widget.subunidad.id);
      if (nota == null || nota.id == 0) continue;

      cambios.add(NotaPendiente(
        notaId: nota.id,
        alumnoId: _alumnos[i].alumnoId,
        nota: escrita,
      ));
    }

    return cambios;
  }

  int get _cuantasPendientes => _pendientes.length;

  void _aplicarATodos() {
    final valor = double.tryParse(_aTodos.text.trim().replaceAll(',', '.'));
    if (valor == null) {
      _avisar('Escribe la nota que quieres poner a todos.');
      return;
    }

    setState(() {
      for (var i = 0; i < _campos.length; i++) {
        _campos[i].text = notaEscrita(valor);
      }
    });
  }

  Future<void> _guardar() async {
    final cambios = _pendientes;
    if (cambios.isEmpty) {
      _avisar('No hay nada que guardar.');
      return;
    }

    setState(() {
      guardando = true;
      _hechas = 0;
      _fallidas = {};
    });

    final resultado = await guardarNotas(
      server,
      cambios,
      avance: (hechas, _) => setState(() => _hechas = hechas),
    );

    // Lo que entró pasa a ser lo nuevo «original»: así, si el docente vuelve a
    // pulsar Guardar, no se remanda lo que ya está puesto.
    final fallidas = resultado.fallidas.map((f) => f.alumnoId).toSet();

    for (final cambio in cambios) {
      if (fallidas.contains(cambio.alumnoId)) continue;

      final indice =
          _alumnos.indexWhere((a) => a.alumnoId == cambio.alumnoId);
      if (indice >= 0) _original[indice] = cambio.nota;
      _guardadas.add(cambio);
    }

    setState(() {
      guardando = false;
      _fallidas = fallidas;
    });

    if (resultado.todoBien) {
      _avisar('${resultado.guardadas} notas guardadas.');
    } else {
      _avisar(
        '${resultado.guardadas} guardadas, ${resultado.fallidas.length}'
        ' fallaron. ${resultado.motivo ?? ''}'.trim(),
      );
    }
  }

  /// Qué hacer al salir con notas sin guardar.
  ///
  /// Se pregunta en vez de guardar sin avisar: en el teléfono se sale mucho por
  /// el gesto de volver, sin querer, y guardar a espaldas de quien está
  /// escribiendo deja notas puestas que nadie confirmó. Es el mismo criterio
  /// que ya sigue el editor de situaciones.
  Future<bool> _confirmarSalida() async {
    if (_cuantasPendientes == 0) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Quedan notas sin guardar'),
        content: Text(
          'Tienes $_cuantasPendientes notas escritas que no se han guardado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir aquí'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );

    return salir ?? false;
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _abrirAsistencia(AlumnoDelLibro alumno) {
    Navigator.of(context).pushNamed(
      '/asistencia-clase',
      arguments: AsistenciaClaseArgs(
        alumnoId: alumno.alumnoId,
        nombre: alumno.nombreEnLista,
        grupoId: widget.libro.asignatura.grupoId,
        fotoNombre: alumno.fotoNombre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numero = widget.unidad.subunidades.indexOf(widget.subunidad) + 1;

    // El navegador se toma antes de esperar nada: el `context` del build no
    // sirve después de un await, y el `mounted` del State no lo cubre.
    final navegador = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) async {
        if (yaSalio) return;
        if (!await _confirmarSalida()) return;
        if (!mounted) return;
        navegador.pop(_guardadas);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: TituloPantalla(
            titulo: '${widget.libro.asignatura.abrevGrupo}'
                ' · ${widget.libro.asignatura.materia}',
            subtitulo: '$numero. ${widget.subunidad.definicion}'
                ' (${porcentajeEscrito(widget.subunidad.porcentaje)})',
          ),
        ),
        body: Column(
          children: [
            if (_puedeEditar) _buildATodos(),
            Expanded(child: _buildLista()),
          ],
        ),
        bottomNavigationBar: _puedeEditar ? _buildBarraGuardar() : null,
      ),
    );
  }

  /// La «nota rápida» del front web, sin el panel flotante.
  ///
  /// Allí es un widget arrastrable que hay que activar y luego ir tocando
  /// celdas una a una. El caso real —casi todos sacaron lo mismo y hay tres
  /// excepciones— se resuelve mejor al revés: se rellena la columna entera y se
  /// corrigen las tres. Un campo y un botón, sin modo que activar ni apagar.
  Widget _buildATodos() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          const Text('A todos:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _aTodos,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: guardando ? null : _aplicarATodos,
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_alumnos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Este grupo no tiene alumnos matriculados.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      // Sitio de sobra abajo para que el último alumno no quede debajo del
      // teclado cuando se llega a él con «Siguiente».
      padding: const EdgeInsets.only(top: 8, bottom: 200),
      itemCount: _alumnos.length,
      itemBuilder: (contexto, indice) => _buildAlumno(indice),
    );
  }

  Widget _buildAlumno(int indice) {
    final alumno = _alumnos[indice];
    final config = ContextoAcademico.instancia.config;

    final escrita = _leido(indice);
    final perdida = config.esPerdida(escrita);
    final cambiada = escrita != null && escrita != _original[indice];
    final fallo = _fallidas.contains(alumno.alumnoId);

    // Sin fila en `notas` no hay nada que actualizar. No debería pasar
    // —`notas/detailed` las crea al abrir el libro— pero si pasa, más vale un
    // campo apagado con su motivo que uno que acepta lo que se pierde.
    final sinFila = (alumno.notaDe(widget.subunidad.id)?.id ?? 0) == 0;
    final editable = _puedeEditar && !sinFila && !guardando;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fallo ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: cambiada && !fallo
            ? Border.all(color: kPrimaryColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Text(
            '${indice + 1}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(width: 8),
          // La foto y el nombre llevan a su asistencia en esta clase: es lo
          // otro que se hace al acabar la clase, y ya está a un toque.
          InkWell(
            onTap: () => _abrirAsistencia(alumno),
            child: Row(
              children: [
                AvatarPersona(
                  nombre: alumno.nombreEnLista,
                  fotoNombre: alumno.fotoNombre,
                  radio: 18,
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _abrirAsistencia(alumno),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alumno.nombreEnLista,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      // Los asistentes van en cursiva, como en el front web: no
                      // están matriculados y conviene notarlo antes de ponerles
                      // una nota.
                      fontStyle: alumno.estado == 'ASIS'
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  if (alumno.ausenciasCount > 0 || alumno.tardanzasCount > 0)
                    Text(
                      [
                        if (alumno.ausenciasCount > 0)
                          '${alumno.ausenciasCount} aus',
                        if (alumno.tardanzasCount > 0)
                          '${alumno.tardanzasCount} tard',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _campos[indice],
              focusNode: _focos[indice],
              enabled: editable,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              // El último cierra el teclado; los demás bajan al siguiente.
              textInputAction: indice == _alumnos.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: (_) => _siguiente(indice),
              // Al enfocar, el contenido queda seleccionado: se escribe encima
              // sin tener que borrar.
              onTap: () => _campos[indice].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _campos[indice].text.length,
              ),
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: perdida ? Colors.red[700] : Colors.black87,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: sinFila ? '—' : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: perdida,
                fillColor: perdida ? const Color(0xFFFFEBEE) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Baja al siguiente alumno seleccionando su nota, sin cerrar el teclado.
  void _siguiente(int indice) {
    if (indice >= _alumnos.length - 1) {
      FocusScope.of(context).unfocus();
      return;
    }

    final siguiente = indice + 1;
    _campos[siguiente].selection = TextSelection(
      baseOffset: 0,
      extentOffset: _campos[siguiente].text.length,
    );
    FocusScope.of(context).requestFocus(_focos[siguiente]);
  }

  Widget _buildBarraGuardar() {
    final pendientes = _cuantasPendientes;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                guardando
                    ? 'Guardando $_hechas de $pendientes…'
                    : pendientes == 0
                        ? 'Todo guardado'
                        : '$pendientes sin guardar',
                style: TextStyle(
                  fontSize: 13,
                  color: pendientes == 0 ? Colors.black54 : Colors.black87,
                  fontWeight:
                      pendientes == 0 ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: guardando || pendientes == 0 ? null : _guardar,
              child: Text(_fallidas.isEmpty ? 'Guardar' : 'Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
