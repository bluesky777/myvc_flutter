import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvc_flutter/Http/DefinitivasApi.dart';
import 'package:myvc_flutter/Http/FrasesApi.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ControlOcupado.dart';
import 'package:myvc_flutter/Widgets/HojaDetalleNota.dart';
import 'package:myvc_flutter/Widgets/SelectorFrases.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';

/// Lo que la ficha devuelve al libro, para no volver a pedir `notas/detailed`.
class CambiosDeLaFicha {
  const CambiosDeLaFicha({
    this.notas = const [],
    this.notaFinal,
    this.frases,
    this.hayQueRecargar = false,
  });

  /// Las notas de subunidad que entraron.
  final List<NotaPendiente> notas;

  /// La definitiva, si cambió. Null si nadie la tocó.
  final NotaFinalDelLibro? notaFinal;

  /// Las frases del alumno, si se puso o se quitó alguna.
  final List<FraseDeAlumno>? frases;

  /// Si algo de lo que pasó aquí deja al libro con datos viejos que la app no
  /// puede recalcular sola. Hoy solo lo enciende borrar una nota: el backend
  /// recalcula la definitiva por su cuenta y no dice con qué valor.
  final bool hayQueRecargar;

  bool get hayAlgo =>
      notas.isNotEmpty || notaFinal != null || frases != null || hayQueRecargar;
}

/// La ficha de notas de un alumno en una asignatura: el otro eje del libro.
///
/// La planilla lee la matriz por indicadores —una casilla, treinta alumnos— y
/// es la del trabajo diario. Esta la lee por el otro lado —un alumno, todas sus
/// casillas— y es la de las dos preguntas que no son diarias:
///
///  - **«¿Cómo va mi hijo?»**, cuando el acudiente llama o aparece. Aquí está
///    todo lo suyo en la asignatura, con el promedio al día.
///  - **Nivelar al cerrar el periodo**: subir la definitiva por encima de lo
///    que dan las cuentas, marcarla como puesta a mano o como recuperada.
///
/// **Dos formas de guardar en la misma pantalla, y es a propósito.** Los
/// números —las notas y la definitiva— se editan en local y salen al pulsar
/// Guardar, igual que en la planilla y por lo mismo: en el teléfono se cancela
/// mucho y guardar mientras alguien teclea deja notas que nadie confirmó. Los
/// dos interruptores, en cambio, se mandan al tocarlos: son peticiones
/// diminutas, y sobre todo **el servidor cruza sus efectos** —quitar «manual»
/// quita «recuperada»— así que hay que enseñar lo que de verdad quedó, y eso
/// solo se sabe después de preguntar.
class FichaAlumnoNotasScreen extends StatefulWidget {
  const FichaAlumnoNotasScreen({
    super.key,
    required this.libro,
    required this.alumno,
  });

  final LibroDeNotas libro;
  final AlumnoDelLibro alumno;

  @override
  State<FichaAlumnoNotasScreen> createState() => _FichaAlumnoNotasScreenState();
}

class _FichaAlumnoNotasScreenState extends State<FichaAlumnoNotasScreen> {
  final Server server = Server();

  /// Un campo por subunidad, en el orden en que se pintan.
  final Map<int, TextEditingController> _campos = {};

  /// Lo que trajo el servidor, por subunidad, para saber qué cambió de verdad.
  final Map<int, double?> _original = {};

  final _definitiva = TextEditingController();
  double? _definitivaOriginal;

  /// La definitiva tal como está ahora, con lo que hayan hecho los
  /// interruptores. Null cuando el alumno no tiene fila en `notas_finales`.
  NotaFinalDelLibro? _notaFinal;

  /// Si la definitiva cambió en esta pantalla, para devolverla al libro.
  bool _definitivaTocada = false;

  bool guardando = false;
  bool _alternando = false;

  final List<NotaPendiente> _guardadas = [];
  Set<int> _fallidas = {};

  /// Las frases del alumno tal como están ahora.
  late List<FraseDeAlumno> _frases;

  /// Si se puso o se quitó alguna, para devolverlas al libro.
  bool _frasesTocadas = false;

  /// El catálogo del año, pedido la primera vez que alguien abre la hoja.
  List<FraseDelCatalogo>? _catalogo;
  bool _trayendoCatalogo = false;

  /// Encendido si se borró alguna nota: el backend recalcula la definitiva por
  /// su cuenta y no dice con qué, así que lo que hay en memoria ya no vale.
  bool _hayQueRecargar = false;

  bool get _puedeEditarNotas =>
      ContextoAcademico.instancia.config.puedeEditarNotas;

  bool get _puedeNivelar => ContextoAcademico.instancia.config.puedeNivelar;

  @override
  void initState() {
    super.initState();

    for (final unidad in widget.libro.unidades) {
      for (final subunidad in unidad.subunidades) {
        final nota = widget.alumno.notaDe(subunidad.id)?.nota;
        _original[subunidad.id] = nota;
        _campos[subunidad.id] = TextEditingController(text: notaEscrita(nota));
      }
    }

    _frases = widget.alumno.frases;
    _notaFinal = widget.alumno.notaFinal;
    _definitivaOriginal = _notaFinal?.nota;
    _definitiva.text = notaEscrita(_definitivaOriginal);
  }

  @override
  void dispose() {
    for (final campo in _campos.values) {
      campo.dispose();
    }
    _definitiva.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// Lo escrito ahora en cada casilla, para que el promedio se mueva mientras
  /// se teclea sin haber guardado nada todavía.
  Map<int, double?> get _escritas => {
        for (final entrada in _campos.entries)
          entrada.key: notaLeida(entrada.value.text),
      };

  double get _promedio =>
      widget.libro.promedioDe(widget.alumno, sobrescritas: _escritas);

  /// Las notas de subunidad que cambiaron y se pueden guardar.
  List<NotaPendiente> get _pendientes {
    final cambios = <NotaPendiente>[];

    for (final entrada in _campos.entries) {
      final escrita = notaLeida(entrada.value.text);
      if (escrita == null || escrita == _original[entrada.key]) continue;

      final nota = widget.alumno.notaDe(entrada.key);
      if (nota == null || nota.id == 0) continue;

      cambios.add(NotaPendiente(
        notaId: nota.id,
        alumnoId: widget.alumno.alumnoId,
        nota: escrita,
      ));
    }

    return cambios;
  }

  /// Si la definitiva escrita es distinta de la que hay guardada.
  bool get _definitivaPendiente {
    final actual = _notaFinal;
    if (actual == null || !actual.existe || !_puedeNivelar) return false;

    final escrita = notaLeida(_definitiva.text);
    return escrita != null && escrita != actual.nota;
  }

  int get _cuantasPendientes => _pendientes.length + (_definitivaPendiente ? 1 : 0);

  Future<void> _guardar() async {
    final cambios = _pendientes;
    final tocaDefinitiva = _definitivaPendiente;

    if (cambios.isEmpty && !tocaDefinitiva) {
      _avisar('No hay nada que guardar.');
      return;
    }

    setState(() {
      guardando = true;
      _fallidas = {};
    });

    // Primero las notas y después la definitiva, y no al revés: la definitiva
    // que se escribe es la que el docente decidió **viendo** el promedio que
    // sale de esas notas. Mandarla antes dejaría un instante en que la fila
    // nivelada es más vieja que las notas de las que salió, que es justo lo que
    // el backend marca como «desactualizada».
    var fallidas = <int>{};

    if (cambios.isNotEmpty) {
      final resultado = await guardarNotas(server, cambios);
      fallidas = resultado.fallidas.map((f) => f.notaId).toSet();

      for (final cambio in cambios) {
        if (fallidas.contains(cambio.notaId)) continue;

        final subunidadId = _subunidadDe(cambio.notaId);
        if (subunidadId != null) _original[subunidadId] = cambio.nota;
        _guardadas.add(cambio);
      }

      if (!resultado.todoBien) {
        _avisar('${resultado.guardadas} notas guardadas,'
            ' ${resultado.fallidas.length} fallaron.'
            ' ${resultado.motivo ?? ''}'.trim());
      }
    }

    String? falloDefinitiva;

    if (tocaDefinitiva) {
      final escrita = notaLeida(_definitiva.text)!;
      falloDefinitiva = await guardarDefinitiva(
        server,
        nfId: _notaFinal!.nfId,
        nota: escrita,
      );

      if (falloDefinitiva == null) {
        setState(() {
          _notaFinal = _notaFinal!.trasCambiarLaNota(escrita);
          _definitivaOriginal = escrita;
          _definitivaTocada = true;
        });
      }
    }

    setState(() {
      guardando = false;
      _fallidas = {
        for (final notaId in fallidas)
          if (_subunidadDe(notaId) != null) _subunidadDe(notaId)!,
      };
    });

    if (falloDefinitiva != null) {
      _avisar(falloDefinitiva);
    } else if (tocaDefinitiva && fallidas.isEmpty) {
      // Se dice siempre, porque no es lo que se pidió: se pidió cambiar un
      // número y además quedó marcada a mano. Callarlo haría que la próxima
      // vez que el sistema NO recalcule esa nota pareciera un fallo.
      _avisar('Definitiva guardada. Queda marcada como manual, así que el'
          ' sistema ya no la recalculará.');
    } else if (fallidas.isEmpty) {
      _avisar('${cambios.length} notas guardadas.');
    }
  }

  /// De qué subunidad es esa fila de `notas`.
  int? _subunidadDe(int notaId) {
    for (final entrada in widget.alumno.notas.entries) {
      if (entrada.value.id == notaId) return entrada.key;
    }
    return null;
  }

  Future<void> _alternarManual(bool nuevo) async {
    final actual = _notaFinal;
    if (actual == null || !actual.existe) return;

    setState(() => _alternando = true);
    final fallo = await alternarManual(server, nfId: actual.nfId, manual: nuevo);
    setState(() => _alternando = false);

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    setState(() {
      _notaFinal = actual.trasAlternarManual(nuevo);
      _definitivaTocada = true;
    });

    if (!nuevo && actual.recuperada) {
      _avisar('Vuelve a ser automática, y por eso deja de estar marcada como'
          ' recuperada.');
    } else if (nuevo) {
      _avisar('Marcada como puesta a mano: el sistema no la recalculará.');
    } else {
      _avisar('Vuelve a calcularla el sistema.');
    }
  }

  Future<void> _alternarRecuperada(bool nuevo) async {
    final actual = _notaFinal;
    if (actual == null || !actual.existe) return;

    setState(() => _alternando = true);
    final fallo =
        await alternarRecuperada(server, nfId: actual.nfId, recuperada: nuevo);
    setState(() => _alternando = false);

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    setState(() {
      _notaFinal = actual.trasAlternarRecuperada(nuevo);
      _definitivaTocada = true;
    });

    if (nuevo && !actual.manual) {
      _avisar('Marcada como recuperada, y con ella como puesta a mano: una'
          ' recuperada que se recalculara se perdería.');
    } else {
      _avisar(nuevo ? 'Marcada como recuperada.' : 'Ya no es recuperada.');
    }
  }

  /// El catálogo del año, traído la primera vez que hace falta.
  ///
  /// No se pide al abrir la ficha: son cuatrocientas filas que la mayoría de
  /// las visitas no llegan a mirar, y esta pantalla se abre muchas veces al
  /// día. Una vez traído se queda mientras la pantalla viva.
  Future<void> _asegurarCatalogo() async {
    if (_catalogo != null || _trayendoCatalogo) return;

    setState(() => _trayendoCatalogo = true);
    try {
      _catalogo = await traerCatalogoDeFrases(server);
    } catch (err) {
      _avisar('No se pudo traer el catálogo de frases: $err');
      _catalogo = const [];
    }
    setState(() => _trayendoCatalogo = false);
  }

  Future<void> _ponerFrase() async {
    await _asegurarCatalogo();
    if (!mounted) return;

    final elegida = await pedirFrase(context, _catalogo ?? const []);
    if (elegida == null) return;

    final resultado = await ponerFrase(
      server,
      alumnoId: widget.alumno.alumnoId,
      asignaturaId: widget.libro.asignatura.id,
      fraseId: elegida.fraseId,
      texto: elegida.texto,
    );

    if (!resultado.entro) {
      _avisar(resultado.motivo!);
      return;
    }

    // El backend contesta la lista entera ya recalculada, así que se pinta lo
    // que él dice y no lo que la app supone.
    setState(() {
      _frases = resultado.frases ?? _frases;
      _frasesTocadas = true;
    });
  }

  Future<void> _quitarFrase(FraseDeAlumno frase) async {
    final fallo = await quitarFrase(server, id: frase.id);

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    // Quitar no devuelve la lista nueva —contesta la fila borrada—, así que se
    // quita de la de aquí.
    setState(() {
      _frases = _frases.where((f) => f.id != frase.id).toList();
      _frasesTocadas = true;
    });
  }

  /// Abre el detalle de una nota: quién la tocó, cuándo, y borrarla.
  ///
  /// Se llega manteniendo pulsada la fila. En el front web hay que encender
  /// antes un interruptor «Ver historial» para que el doble clic haga algo, y
  /// un modo que hay que acordarse de encender es un modo que nadie enciende.
  Future<void> _abrirDetalle(SubunidadModel subunidad) async {
    final nota = widget.alumno.notaDe(subunidad.id);
    if (nota == null || nota.id == 0) return;

    final borrada = await mostrarDetalleDeNota(
      context,
      notaId: nota.id,
      titulo: widget.alumno.nombreEnLista,
      subtitulo: subunidad.definicion,
    );

    if (!borrada) return;

    setState(() {
      // El campo se vacía porque la fila ya no está. Y se apaga, porque
      // `notas/update` sobre una nota borrada no tendría qué actualizar: la
      // casilla vuelve al recargar el libro.
      _campos[subunidad.id]?.text = '';
      _original[subunidad.id] = null;
      _hayQueRecargar = true;
    });

    _avisar('Nota borrada. Recarga el libro para que la casilla se vuelva a'
        ' crear.');
  }

  Future<bool> _confirmarSalida() async {
    if (_cuantasPendientes == 0) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Quedan cambios sin guardar'),
        content: Text('Tienes $_cuantasPendientes cambios escritos que no se'
            ' han guardado.'),
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

  void _abrirAsistencia() {
    Navigator.of(context).pushNamed(
      '/asistencia-clase',
      arguments: AsistenciaClaseArgs(
        alumnoId: widget.alumno.alumnoId,
        nombre: widget.alumno.nombreEnLista,
        grupoId: widget.libro.asignatura.grupoId,
        fotoNombre: widget.alumno.fotoNombre,
      ),
    );
  }

  CambiosDeLaFicha get _resultado => CambiosDeLaFicha(
        notas: _guardadas,
        notaFinal: _definitivaTocada ? _notaFinal : null,
        frases: _frasesTocadas ? _frases : null,
        hayQueRecargar: _hayQueRecargar,
      );

  @override
  Widget build(BuildContext context) {
    final navegador = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) async {
        if (yaSalio) return;
        if (!await _confirmarSalida()) return;
        if (!mounted) return;
        navegador.pop(_resultado);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: TituloPantalla(
            titulo: widget.alumno.nombreEnLista,
            subtitulo: '${widget.libro.asignatura.abrevGrupo}'
                ' · ${widget.libro.asignatura.materia}',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 220),
          children: [
            _buildCabecera(),
            _buildDefinitiva(),
            _buildFrases(),
            if (widget.libro.unidades.isEmpty)
              _buildVacio()
            else
              ...widget.libro.unidades.map(_buildUnidad),
          ],
        ),
        bottomNavigationBar: _buildBarraGuardar(),
      ),
    );
  }

  Widget _buildVacio() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'Esta asignatura no tiene'
        ' ${ContextoAcademico.instancia.config.unidades.toLowerCase()}'
        ' en el periodo.',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCabecera() {
    final alumno = widget.alumno;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Tocar al alumno lleva a su asistencia en esta clase, igual que en la
        // planilla: es la otra cosa que se mira cuando alguien pregunta por él.
        onTap: _abrirAsistencia,
        leading: AvatarPersona(
          nombre: alumno.nombreEnLista,
          fotoNombre: alumno.fotoNombre,
          radio: 24,
        ),
        title: Text(
          alumno.nombreEnLista,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontStyle:
                alumno.estado == 'ASIS' ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        subtitle: Text(
          [
            if (alumno.estado == 'ASIS') 'asistente',
            if (alumno.estado == 'PREM') 'prematriculado',
            if (alumno.nee) 'NEE',
            '${alumno.ausenciasCount} ausencias',
            '${alumno.tardanzasCount} tardanzas',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.event_available_outlined, size: 20),
      ),
    );
  }

  /// El bloque de nivelar: promedio, definitiva y las dos banderas.
  Widget _buildDefinitiva() {
    final config = ContextoAcademico.instancia.config;
    final actual = _notaFinal;
    final promedio = _promedio;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Promedio automático',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Text(
                promedio.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: config.esPerdida(promedio)
                      ? Colors.red[700]
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Definitiva', style: TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _definitiva,
                  enabled: _puedeNivelar &&
                      (actual?.existe ?? false) &&
                      !guardando,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onTap: () => _definitiva.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _definitiva.text.length,
                  ),
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: config.esPerdida(notaLeida(_definitiva.text))
                        ? Colors.red[700]
                        : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          if (actual != null && actual.manual && actual.desactualizada)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Esta definitiva se puso a mano antes de la última nota, así'
                ' que ya no corresponde al promedio de arriba.',
                style: TextStyle(fontSize: 11, color: Colors.orange[900]),
              ),
            ),
          ControlOcupado(
            ocupado: _alternando,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: actual?.manual ?? false,
                  onChanged: _puedeNivelar && (actual?.existe ?? false)
                      ? _alternarManual
                      : null,
                  title: const Text('Puesta a mano',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'El sistema deja de recalcularla',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: actual?.recuperada ?? false,
                  onChanged: _puedeNivelar && (actual?.existe ?? false)
                      ? _alternarRecuperada
                      : null,
                  title: const Text('Viene de recuperación',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'Marcarla también la deja puesta a mano',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (!_puedeNivelar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                config.avisoDeBloqueo ??
                    'En este periodo no puedes nivelar las definitivas.',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
          if (actual != null && !actual.existe)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Este alumno todavía no tiene definitiva guardada. Se crea al'
                ' recargar el libro.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  /// Lo que se le dice al alumno además de la nota.
  ///
  /// El colegio las llama «información para el alumno» y salen en el boletín.
  /// Vienen ya dentro de `notas/detailed`, así que enseñarlas no cuesta nada;
  /// lo que se pide aparte, y solo si alguien va a poner una, es el catálogo.
  ///
  /// **Van al periodo de la barra de arriba, siempre.** El backend escribe
  /// `periodo_id = $user->periodo_id` y no mira lo que se le mande, así que
  /// ofrecer elegir el periodo aquí sería ofrecer algo que no se cumple.
  Widget _buildFrases() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Información para el alumno',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (_puedeEditarNotas)
                TextButton.icon(
                  onPressed: _trayendoCatalogo ? null : _ponerFrase,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Poner'),
                ),
            ],
          ),
          if (_frases.isEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 6, bottom: 6),
              child: Text(
                'Sin frases en este periodo.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            ..._frases.map(_buildFrase),
        ],
      ),
    );
  }

  Widget _buildFrase(FraseDeAlumno frase) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(frase.frase, style: const TextStyle(fontSize: 13)),
                // Solo las del catálogo llevan tipo; una escrita a mano no
                // tiene ninguno, y poner ahí «—» sería ruido.
                if (frase.esDelCatalogo && frase.tipo.isNotEmpty)
                  Text(
                    frase.tipo,
                    style: TextStyle(fontSize: 11, color: kPrimaryColor),
                  ),
              ],
            ),
          ),
          if (_puedeEditarNotas)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Quitar',
              onPressed: () => _quitarFrase(frase),
            ),
        ],
      ),
    );
  }

  Widget _buildUnidad(UnidadModel unidad) {
    final numero = widget.libro.unidades.indexOf(unidad) + 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$numero. ${unidad.definicion}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  porcentajeEscrito(unidad.porcentaje),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (unidad.subunidades.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'Sin ${ContextoAcademico.instancia.config.subunidades.toLowerCase()}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            ...unidad.subunidades.map((s) => _buildSubunidad(unidad, s)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSubunidad(UnidadModel unidad, SubunidadModel subunidad) {
    final config = ContextoAcademico.instancia.config;
    final campo = _campos[subunidad.id]!;

    final escrita = notaLeida(campo.text);
    final cambiada = escrita != null && escrita != _original[subunidad.id];
    final fallo = _fallidas.contains(subunidad.id);

    final sinFila = (widget.alumno.notaDe(subunidad.id)?.id ?? 0) == 0;
    final editable = _puedeEditarNotas && !sinFila && !guardando;

    final numero = unidad.subunidades.indexOf(subunidad) + 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fallo ? const Color(0xFFFFEBEE) : null,
        borderRadius: BorderRadius.circular(8),
        border: cambiada && !fallo
            ? Border.all(color: kPrimaryColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            // Mantener pulsado abre el detalle: quién tocó esta nota, cuándo, y
            // borrarla. No hay modo que encender antes, al revés que en la web.
            child: InkWell(
              onLongPress: sinFila ? null : () => _abrirDetalle(subunidad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$numero. ${subunidad.definicion}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    porcentajeEscrito(subunidad.porcentaje),
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: campo,
              enabled: editable,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onTap: () => campo.selection = TextSelection(
                baseOffset: 0,
                extentOffset: campo.text.length,
              ),
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: config.esPerdida(escrita)
                    ? Colors.red[700]
                    : Colors.black87,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: sinFila ? '—' : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: config.esPerdida(escrita),
                fillColor: config.esPerdida(escrita)
                    ? const Color(0xFFFFEBEE)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraGuardar() {
    if (!_puedeEditarNotas && !_puedeNivelar) return const SizedBox.shrink();

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
                    ? 'Guardando…'
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
