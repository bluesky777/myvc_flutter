import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/HojaDetalleNota.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/TecladoDeNota.dart';
import 'package:myvc_flutter/Utils/FormatoDeNota.dart';

/// Lo que la planilla devuelve al libro cuando se sale de ella.
///
/// Antes devolvía sólo la lista de notas. Ahora también las definitivas, porque
/// `notas/lote` las trae calculadas por el mismo recalculador que las escribe:
/// sin ellas, la pestaña «Por alumno» seguía enseñando la definitiva que la app
/// se había calculado sola, y las dos sólo coinciden mientras nadie tenga una
/// manual o una recuperada.
///
/// Vacía cuando se guardó de una en una: ese camino no las trae, y eso no es un
/// fallo. Ver [ResultadoGuardado.definitivas].
class CambiosDeLaPlanilla {
  const CambiosDeLaPlanilla({
    this.notas = const [],
    this.definitivas = const [],
  });

  final List<NotaPendiente> notas;
  final List<DefinitivaDelLote> definitivas;

  bool get hayAlgo => notas.isNotEmpty || definitivas.isNotEmpty;
}

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
    this.encajada = false,
    this.alGuardar,
  });

  final LibroDeNotas libro;
  final UnidadModel unidad;
  final SubunidadModel subunidad;

  /// Si va dentro de otra pantalla en vez de ser una pantalla propia.
  ///
  /// **Es el modo maestro-detalle de tablet**: la lista de indicadores a un
  /// lado y esto al otro, sin navegar. Encajada no pone su propia barra —el
  /// título ya lo da la pantalla que la contiene— y **no se sale de ella por el
  /// botón atrás**, así que no lleva `PopScope` ni hace `pop`: quien la
  /// contiene le pide lo guardado con [PlanillaScreenState.cambios] y le
  /// pregunta si puede irse con [PlanillaScreenState.puedeSalir].
  ///
  /// El resto —cómo se teclea, cómo se guarda, qué se manda— es idéntico. Esa
  /// es la razón de encajarla en vez de escribir una segunda planilla: pasar
  /// treinta notas tiene que costar lo mismo en un teléfono y en una tablet.
  final bool encajada;

  /// Avisa de lo que acaba de entrar, guardado a guardado.
  ///
  /// Solo lo usa el modo encajado. Lleva **el trozo de ese guardado**, no todo
  /// lo acumulado: quien escucha lo aplica según llega, y sumar dos veces la
  /// misma nota sería pintarla dos veces.
  final void Function(CambiosDeLaPlanilla)? alGuardar;

  @override
  State<PlanillaScreen> createState() => PlanillaScreenState();
}

/// Público a propósito: en maestro-detalle, la pantalla que la contiene
/// necesita preguntarle dos cosas —qué llevas guardado, y puedo cambiarte de
/// indicador— y eso no cabe en un callback sin duplicar el diálogo de «quedan
/// notas sin guardar» en los dos sitios.
class PlanillaScreenState extends State<PlanillaScreen> {
  final Server server = Server();

  /// Un campo y un foco por alumno, en el mismo orden en que se pintan.
  final List<TextEditingController> _campos = [];
  final List<FocusNode> _focos = [];

  final _aTodos = TextEditingController();

  /// Lo que trajo el servidor, para saber qué cambió de verdad.
  final List<double?> _original = [];

  /// Las que no entraron en el último guardado, por id de alumno.
  Set<int> _fallidas = {};

  /// Los alumnos cuya nota se borró aquí, por su índice en la lista. Su campo
  /// se apaga: la fila ya no está y `notas/update` sobre ella contesta 422.
  final Set<int> _borradas = {};

  bool guardando = false;
  int _hechas = 0;

  /// Todo lo que se ha guardado en esta pantalla, para devolverlo al salir.
  final List<NotaPendiente> _guardadas = [];

  /// Las definitivas que el servidor devolvió, por alumno.
  ///
  /// Un mapa y no una lista: pasando dos veces la misma columna, la segunda
  /// definitiva de un alumno es la buena y la primera ya no dice nada.
  final Map<int, DefinitivaDelLote> _definitivas = {};

  bool get _puedeEditar =>
      ContextoAcademico.instancia.config.puedeEditarNotas;

  List<AlumnoDelLibro> get _alumnos => widget.libro.alumnos;

  @override
  void initState() {
    super.initState();

    // La pregunta que motivó la analítica: ¿de verdad quitó el portátil de en
    // medio? La hora es la que la contesta —abrirla a las 9 de la mañana es
    // usarla en clase; a las 10 de la noche es corregir en casa, que ya se
    // hacía en la web—. Ver docs/analitica.md.
    Analitica.evento('planilla_abierta', datos: {
      'hora_del_dia': DateTime.now().hour,
    });

    for (final alumno in _alumnos) {
      final nota = alumno.notaDe(widget.subunidad.id)?.nota;
      _original.add(nota);
      _campos.add(TextEditingController(text: notaEnCasilla(nota)));
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
        _campos[i].text = notaEnCasilla(valor);
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

    // Cuántas de golpe, no cuáles ni de quién: pasar una columna entera desde
    // el móvil es lo que hay que saber, y para eso basta el número.
    Analitica.evento('notas_guardadas', datos: {
      'cuantas': resultado.guardadas,
      'fallidas': resultado.fallidas.length,
    });

    for (final definitiva in resultado.definitivas) {
      _definitivas[definitiva.alumnoId] = definitiva;
    }

    // Lo que entró pasa a ser lo nuevo «original»: así, si el docente vuelve a
    // pulsar Guardar, no se remanda lo que ya está puesto.
    final fallidas = resultado.fallidas.map((f) => f.alumnoId).toSet();
    final entraron = <NotaPendiente>[];

    for (final cambio in cambios) {
      if (fallidas.contains(cambio.alumnoId)) continue;

      final indice =
          _alumnos.indexWhere((a) => a.alumnoId == cambio.alumnoId);
      if (indice >= 0) _original[indice] = cambio.nota;
      _guardadas.add(cambio);
      entraron.add(cambio);
    }

    setState(() {
      guardando = false;
      _fallidas = fallidas;
    });

    // Encajada, lo guardado se avisa **ahora** y no al salir: en
    // maestro-detalle la lista de indicadores está a la izquierda, a un palmo,
    // y su «faltan 30» se quedaría mintiendo mientras el docente lo mira.
    // Desde una pantalla propia esto es null y todo viaja en el `pop`.
    widget.alGuardar?.call(CambiosDeLaPlanilla(
      notas: entraron,
      definitivas: resultado.definitivas,
    ));

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
  /// Lo guardado hasta ahora, para quien la tenga encajada.
  CambiosDeLaPlanilla get cambios => CambiosDeLaPlanilla(
        notas: _guardadas,
        definitivas: _definitivas.values.toList(),
      );

  /// ¿Se puede dejar esta casilla? Pregunta si quedan notas escritas sin
  /// guardar, con el mismo diálogo que al salir por el botón atrás.
  Future<bool> puedeSalir() => _confirmarSalida();

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

  /// Abre el detalle de la nota de ese alumno: quién la tocó, cuándo, y
  /// borrarla.
  ///
  /// Manteniendo pulsado el número, que es donde está la nota. El toque corto
  /// sobre la foto y el nombre ya lleva a la asistencia, así que el gesto largo
  /// va sobre la otra mitad de la fila y los dos no se pisan.
  Future<void> _abrirDetalle(int indice) async {
    final alumno = _alumnos[indice];
    final nota = alumno.notaDe(widget.subunidad.id);
    if (nota == null || nota.id == 0) return;

    final borrada = await mostrarDetalleDeNota(
      context,
      notaId: nota.id,
      titulo: alumno.nombreEnLista,
      subtitulo: widget.subunidad.definicion,
    );

    if (!borrada) return;

    setState(() {
      // La casilla vuelve al recargar el libro con la nota por defecto de la
      // subunidad; hasta entonces queda vacía y sin nada que mandar.
      _campos[indice].text = '';
      _original[indice] = null;
      _borradas.add(indice);
    });

    _avisar('Nota borrada. Recarga el libro para que la casilla se vuelva a'
        ' crear.');
  }

  @override
  Widget build(BuildContext context) {
    final numero = widget.unidad.subunidades.indexOf(widget.subunidad) + 1;

    final cuerpo = Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: widget.encajada
          ? null
          : AppBar(
              title: TituloPantalla(
                titulo: '${widget.libro.asignatura.abrevGrupo}'
                    ' · ${widget.libro.asignatura.materia}',
                subtitulo: '$numero. ${widget.subunidad.definicion}'
                    ' (${porcentajeEscrito(widget.subunidad.porcentaje)})',
              ),
            ),
      body: Column(
        children: [
          if (widget.encajada) _buildCabeceraEncajada(numero),
          if (_puedeEditar) _buildATodos(),
          Expanded(child: _buildLista()),
        ],
      ),
      bottomNavigationBar: _puedeEditar ? _buildBarraGuardar() : null,
    );

    // Encajada no se sale por atrás: de ella se sale tocando otro indicador, y
    // eso lo pregunta quien la contiene con `puedeSalir`. Un `PopScope` aquí
    // secuestraría el botón atrás de la pantalla entera.
    if (widget.encajada) return cuerpo;

    // El navegador se toma antes de esperar nada: el `context` del build no
    // sirve después de un await, y el `mounted` del State no lo cubre.
    final navegador = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) async {
        if (yaSalio) return;
        if (!await _confirmarSalida()) return;
        if (!mounted) return;
        navegador.pop(cambios);
      },
      child: cuerpo,
    );
  }

  /// El título del indicador cuando no hay barra propia que lo lleve.
  ///
  /// Sin él, en maestro-detalle la mitad derecha empieza directamente por «A
  /// todos» y no dice de qué casilla son las treinta notas que se están
  /// tecleando. La lista de la izquierda lo marca, pero el ojo está aquí.
  Widget _buildCabeceraEncajada(int numero) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$numero. ${widget.subunidad.definicion}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            porcentajeEscrito(widget.subunidad.porcentaje),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
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
              keyboardType: tecladoDeNota,
              inputFormatters: formateadoresDeNota,
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
    final sinFila = (alumno.notaDe(widget.subunidad.id)?.id ?? 0) == 0 ||
        _borradas.contains(indice);
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
          // Mantener pulsado el número abre el detalle de la nota: quién la
          // tocó, cuándo, y borrarla.
          GestureDetector(
            onLongPress: sinFila ? null : () => _abrirDetalle(indice),
            child: SizedBox(
              width: 64,
              child: TextField(
                controller: _campos[indice],
                focusNode: _focos[indice],
                enabled: editable,
                keyboardType: tecladoDeNota,
                inputFormatters: formateadoresDeNota,
                // El último cierra el teclado; los demás bajan al siguiente.
                textInputAction: indice == _alumnos.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) => _siguiente(indice),
                // Al enfocar, el contenido queda seleccionado: se escribe
                // encima sin tener que borrar.
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
