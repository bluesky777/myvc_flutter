import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:myvc_flutter/Http/PorteriaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/PorteriaModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';

/// PORTERÍA (Joseth, 9 oct 2026): la cámara arriba y el buscador abajo. En el
/// menú se llama «Control de entrada» desde el 28 oct: la entrada la hacen
/// sobre todo los docentes por turnos, y casi ningún colegio tiene portero.
///
/// Se escanea **sólo a quien el portero decide**: el que llega un minuto tarde
/// y no se escanea no tiene tardanza. No hay hora que las ponga solas.
///
/// Escanear pone la tardanza al instante —sin confirmar— y deja «Deshacer» a
/// mano unos segundos. Es lo que hace que sea más rápido que la lista del grupo:
/// un carné, un pitido, el siguiente.
///
/// La NOVEDAD DE UNIFORME (28 oct 2026) va aparte de la tardanza: llegue tarde
/// o temprano. Arriba de la cámara se elige qué hace el carné: «Tardanza» (lo
/// de siempre) o «Sólo novedad», que lee al alumno sin ponerle nada. En los
/// dos, la tarjeta del alumno trae debajo el bloque «Novedad de hoy». El
/// acceso directo «Novedades de uniforme» del menú abre esta misma pantalla en
/// «Sólo novedad» ([modo]). Ver myvc_front/docs/novedades-de-entrada.md.
///
/// La cámara se abre una vez y se queda abierta mientras se está aquí; no se
/// reabre en cada lectura. Si pasan [_reposo] sin leer nada se pausa sola, por
/// la batería, y se reanuda con un toque.
///
/// Lo que se puede escanear, sin registrar nada antes: el QR de MyVC, el
/// documento del alumno en el código de barras de un carné que ya existía, o un
/// código cualquiera que alguien ya dijo de quién es. Un código que no es de
/// nadie abre «¿De quién es este carné?» y queda guardado. Ver docs/porteria.md.
class PorteriaScreen extends StatefulWidget {
  const PorteriaScreen({super.key, this.modo = ModoDeEntrada.tardanza});

  /// Con qué modo se abre. Se puede cambiar arriba de la cámara.
  final ModoDeEntrada modo;

  @override
  State<PorteriaScreen> createState() => _PorteriaScreenState();
}

class _PorteriaScreenState extends State<PorteriaScreen> {
  static const _reposo = Duration(minutes: 3);
  static const _ventanaDeshacer = Duration(seconds: 10);

  /// El mismo carné delante de la cámara se lee muchas veces por segundo. Lo
  /// que se repite dentro de esta ventana es la misma lectura.
  static const _mismoCarne = Duration(seconds: 5);

  final _server = Server();
  final _drawerController = ZoomDrawerController();
  final _buscador = TextEditingController();
  final _foco = FocusNode();

  /// Sólo los formatos que traen los carnés: con la lista corta el lector
  /// trabaja menos en cada cuadro. PDF417 es el del reverso de la tarjeta de
  /// identidad; code128 y code39, los de las carnetizadoras.
  final _camara = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.pdf417,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.itf14,
      BarcodeFormat.ean13,
    ],
    detectionTimeoutMs: 300,
  );

  late ModoDeEntrada _modo = widget.modo;

  List<AlumnoDePorteria> _alumnos = const [];
  final Map<int, AlumnoDePorteria> _porId = {};
  final Map<int, TardanzaDeHoy> _tardanzas = {};

  /// Las novedades de hoy por alumno, la más reciente primero. Es lo que deja
  /// a la tarjeta decir «Ya tiene novedad hoy» antes de anotar otra sin querer.
  final Map<int, List<NovedadDeHoy>> _novedades = {};
  String? _errorAlTraer;
  bool _cargando = true;

  bool _ocupado = false;
  bool _enReposo = false;
  Timer? _temporizadorReposo;

  String? _ultimoCodigo;
  DateTime? _ultimoCodigoEn;

  /// Lo último que pasó, para la tarjeta de debajo de la cámara.
  _Letrero? _letrero;
  Timer? _temporizadorDeshacer;

  @override
  void initState() {
    super.initState();
    _traer();
    _reiniciarReposo();
    _buscador.addListener(() => setState(() {}));
    _foco.addListener(() => setState(() {}));
    _camara.addListener(_alCambiarCamara);
  }

  @override
  void dispose() {
    _temporizadorReposo?.cancel();
    _temporizadorDeshacer?.cancel();
    _camara.removeListener(_alCambiarCamara);
    unawaited(_camara.dispose());
    _buscador.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _traer() async {
    setState(() {
      _cargando = true;
      _errorAlTraer = null;
    });
    try {
      final lista = await traerPorteria(_server);
      setState(() {
        _alumnos = lista.alumnos;
        _porId
          ..clear()
          ..addEntries(lista.alumnos.map((a) => MapEntry(a.id, a)));
        _tardanzas
          ..clear()
          ..addEntries(lista.tardanzasHoy.map((t) => MapEntry(t.alumnoId, t)));
        _novedades.clear();
        for (final n in lista.novedadesHoy) {
          _novedades.putIfAbsent(n.alumnoId, () => []).add(n);
        }
        _cargando = false;
      });
    } catch (err) {
      setState(() {
        _errorAlTraer = '$err'.replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  // ---------------------------------------------------------------- cámara

  /// Si el sistema reanudó la cámara —al volver a la app— ya no está en reposo.
  void _alCambiarCamara() {
    if (_enReposo && _camara.value.isRunning) {
      setState(() => _enReposo = false);
      _reiniciarReposo();
    }
  }

  void _reiniciarReposo() {
    _temporizadorReposo?.cancel();
    _temporizadorReposo = Timer(_reposo, () {
      unawaited(_camara.stop());
      setState(() => _enReposo = true);
    });
  }

  Future<void> _despertar() async {
    setState(() => _enReposo = false);
    _reiniciarReposo();
    await _camara.start();
  }

  void _alLeer(BarcodeCapture captura) {
    final codigo = captura.barcodes
        .map((b) => (b.rawValue ?? '').trim())
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');

    if (codigo.isEmpty || _ocupado) return;

    final ahora = DateTime.now();
    if (codigo == _ultimoCodigo &&
        _ultimoCodigoEn != null &&
        ahora.difference(_ultimoCodigoEn!) < _mismoCarne) {
      return;
    }
    _ultimoCodigo = codigo;
    _ultimoCodigoEn = ahora;
    _reiniciarReposo();

    _registrar(codigo: codigo);
  }

  void _cambiarModo(ModoDeEntrada modo) {
    HapticFeedback.selectionClick();
    // El carné que sigue delante de la cámara se vuelve a leer en el modo
    // nuevo: el docente cambió de modo justo por él.
    _ultimoCodigo = null;
    setState(() => _modo = modo);
  }

  /// Lo que hace el carné (o el alumno elegido en el buscador) según el modo.
  Future<void> _registrar({String? codigo, AlumnoDePorteria? alumno}) =>
      _modo == ModoDeEntrada.tardanza
          ? _poner(codigo: codigo, alumno: alumno)
          : _leer(codigo: codigo, alumno: alumno);

  // ------------------------------------------------------------- tardanzas

  Future<void> _poner({String? codigo, AlumnoDePorteria? alumno}) async {
    setState(() => _ocupado = true);
    final r = await ponerTardanza(_server, codigo: codigo, alumnoId: alumno?.id);
    setState(() => _ocupado = false);

    if (!mounted || !await _hallado(r, codigo)) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _tardanzas[r.alumno!.id] = r.tardanza!;
      _porId.putIfAbsent(r.alumno!.id, () => r.alumno!);
    });
    _mostrar(_Letrero.alumno(r.alumno!,
        tardanza: r.tardanza,
        yaTenia: r.yaTenia,
        uniforme: r.uniforme,
        puedeDeshacer: !r.yaTenia));
  }

  /// «Sólo novedad», o tocar a alguien que ya tiene tardanza: enseña al alumno
  /// sin poner nada (`porteria/leer`).
  Future<void> _leer({String? codigo, AlumnoDePorteria? alumno}) async {
    setState(() => _ocupado = true);
    final r = await leerCarne(_server, codigo: codigo, alumnoId: alumno?.id);
    setState(() => _ocupado = false);

    if (!mounted || !await _hallado(r, codigo)) return;

    HapticFeedback.mediumImpact();
    setState(() {
      final a = r.alumno!;
      _porId.putIfAbsent(a.id, () => a);
      if (r.tardanza != null) _tardanzas[a.id] = r.tardanza!;
      // Lo del servidor manda: otro docente pudo anotarle una en otra puerta.
      _novedades[a.id] = [...?r.novedades];
    });
    _mostrar(_Letrero.alumno(r.alumno!,
        tardanza: r.tardanza,
        yaTenia: r.tardanza != null,
        uniforme: r.uniforme));
  }

  /// El carné que no es de nadie, el anulado y los errores. Devuelve si hay
  /// alumno que enseñar.
  Future<bool> _hallado(ResultadoDelCarne r, String? codigo) async {
    if (r.desconocido) {
      HapticFeedback.heavyImpact();
      await _preguntarDeQuienEs(r.codigo ?? codigo ?? '');
      return false;
    }

    if (!r.hallado) {
      HapticFeedback.heavyImpact();
      _mostrar(_Letrero.error(
          r.anulado ? 'Ese carné está anulado. Búscalo por nombre.' : r.error!));
      return false;
    }

    // Elegido en el buscador: se cierra para que se vea la tarjeta.
    if (_buscador.text.isNotEmpty || _foco.hasFocus) {
      _buscador.clear();
      _foco.unfocus();
    }
    return true;
  }

  void _mostrar(_Letrero letrero) {
    _temporizadorDeshacer?.cancel();
    setState(() => _letrero = letrero);
    if (letrero.puedeDeshacer) {
      _temporizadorDeshacer = Timer(_ventanaDeshacer, () {
        setState(() => _letrero = _letrero?.sinDeshacer());
      });
    }
  }

  Future<void> _quitar(TardanzaDeHoy tardanza, {bool preguntar = true}) async {
    final alumno = _porId[tardanza.alumnoId];

    if (preguntar) {
      final si = await _confirmar(
        titulo: 'Quitar la tardanza',
        pregunta:
            '¿Quitar la tardanza de hoy de ${alumno?.nombreCompleto ?? 'este alumno'}?',
      );
      if (!si) return;
    }

    final error = await quitarTardanza(_server, tardanza.id);

    if (error != null) {
      _mostrar(_Letrero.error(error));
      return;
    }

    setState(() {
      _tardanzas.remove(tardanza.alumnoId);
      if (_letrero?.tardanza?.id == tardanza.id) _letrero = null;
    });
  }

  Future<bool> _confirmar({required String titulo, required String pregunta}) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(pregunta),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitar')),
        ],
      ),
    );
    return si == true;
  }

  // ------------------------------------------------------------- novedades

  void _alGuardarNovedad(NovedadDeHoy n, ConteoUniforme? uniforme) {
    setState(() {
      _novedades.putIfAbsent(n.alumnoId, () => []).insert(0, n);
      if (_letrero?.alumno?.id == n.alumnoId) {
        _letrero = _letrero!.conUniforme(uniforme);
      }
    });
  }

  /// [antes] es el conteo de antes de guardarla: deshacer lo deja como estaba.
  void _alQuitarNovedad(NovedadDeHoy n, ConteoUniforme? antes) {
    setState(() {
      _novedades[n.alumnoId]?.removeWhere((o) => o.id == n.id);
      if (_letrero?.alumno?.id == n.alumnoId) {
        _letrero = _letrero!.conUniforme(antes);
      }
    });
  }

  /// Quitar desde la lista de hoy. No se sabe cómo queda el conteo, así que
  /// la tarjeta de ese alumno, si está, se cierra.
  Future<void> _quitarNovedadDeLaLista(NovedadDeHoy n) async {
    final alumno = _porId[n.alumnoId];
    final si = await _confirmar(
      titulo: 'Quitar la novedad',
      pregunta:
          '¿Quitar la novedad de hoy (${n.motivosLeibles}) de ${alumno?.nombreCompleto ?? 'este alumno'}?',
    );
    if (!si) return;

    final error = await quitarNovedad(_server, n.id);

    if (error != null) {
      _mostrar(_Letrero.error(error));
      return;
    }

    setState(() {
      _novedades[n.alumnoId]?.removeWhere((o) => o.id == n.id);
      if (_letrero?.alumno?.id == n.alumnoId) _letrero = null;
    });
  }

  // ------------------------------------------------- carné que no es de nadie

  Future<void> _preguntarDeQuienEs(String codigo) async {
    _temporizadorReposo?.cancel();
    final elegido = await showModalBottomSheet<AlumnoDePorteria>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HojaDeQuienEs(alumnos: _alumnos),
    );
    _reiniciarReposo();

    if (elegido == null || !mounted) return;

    final error =
        await vincularCarne(_server, codigo: codigo, alumnoId: elegido.id);

    if (error != null) {
      _mostrar(_Letrero.error(error));
      return;
    }

    await _registrar(alumno: elegido);
  }

  // ---------------------------------------------------------------- pantalla

  int get _cuantasNovedades =>
      _novedades.values.fold(0, (suma, lista) => suma + lista.length);

  @override
  Widget build(BuildContext context) {
    final tardanzas = _tardanzas.length;
    final novedades = _cuantasNovedades;
    // Con el teclado abierto —el buscador o la nota— la cámara se encoge y el
    // selector se esconde, para dejar sitio a lo que se escribe.
    final escribiendo =
        _foco.hasFocus || MediaQuery.viewInsetsOf(context).bottom > 0;

    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        appBar: AppBar(
          title: TituloPantalla(
            titulo: 'Control de entrada',
            subtitulo: tardanzas == 0 && novedades == 0
                ? 'Sin tardanzas ni novedades hoy'
                : '${tardanzas == 1 ? '1 tardanza' : '$tardanzas tardanzas'}'
                    ' · ${novedades == 1 ? '1 novedad' : '$novedades novedades'} hoy',
          ),
          leading: GestureDetector(
            child: const Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
          actions: [
            IconButton(
              tooltip: 'Volver a cargar',
              icon: const Icon(Icons.refresh),
              onPressed: _traer,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!escribiendo) _selectorDeModo(),
              _zonaCamara(context, escribiendo: escribiendo),
              Expanded(child: _abajo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorDeModo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Al escanear un carné se registra:',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          SegmentedButton<ModoDeEntrada>(
            segments: const [
              ButtonSegment(
                value: ModoDeEntrada.tardanza,
                icon: Icon(Icons.schedule),
                label: Text('Tardanza'),
              ),
              ButtonSegment(
                value: ModoDeEntrada.soloNovedad,
                icon: Icon(Icons.checkroom_outlined),
                label: Text('Sólo novedad'),
              ),
            ],
            selected: {_modo},
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, 44)),
            ),
            onSelectionChanged: (s) => _cambiarModo(s.first),
          ),
        ],
      ),
    );
  }

  Widget _zonaCamara(BuildContext context, {required bool escribiendo}) {
    final alto = MediaQuery.sizeOf(context).height;
    // Con la tarjeta del alumno a la vista la cámara se encoge: el bloque de la
    // novedad necesita el sitio, y el carné se lee igual en un recuadro menor.
    final conTarjeta = _letrero?.alumno != null;
    final altura = escribiendo
        ? 96.0
        : conTarjeta
            ? (alto * 0.22).clamp(140.0, 200.0)
            : (alto * 0.34).clamp(190.0, 330.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: altura,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camara,
            onDetect: _alLeer,
            errorBuilder: (context, error) => _sinCamara(error),
          ),
          if (!escribiendo) const _Mira(),
          if (_ocupado)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            right: 6,
            top: 6,
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _camara,
              builder: (context, estado, _) => estado.torchState ==
                      TorchState.unavailable
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Linterna',
                      color: Colors.white,
                      icon: Icon(estado.torchState == TorchState.on
                          ? Icons.flash_on
                          : Icons.flash_off),
                      onPressed: () => _camara.toggleTorch(),
                    ),
            ),
          ),
          if (_enReposo)
            Material(
              color: Colors.black87,
              child: InkWell(
                onTap: _despertar,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 44),
                      SizedBox(height: 8),
                      Text('Cámara en pausa · toca para seguir',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sinCamara(MobileScannerException error) {
    final sinPermiso = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          sinPermiso
              ? 'La app no tiene permiso para usar la cámara. Dáselo en los ajustes del teléfono (Aplicaciones › MyVC › Permisos). Mientras tanto, busca por nombre abajo.'
              : 'No se pudo abrir la cámara. Busca por nombre abajo.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _letreroDeError(String error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(error)),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _letrero = null),
          ),
        ],
      ),
    );
  }

  /// La tarjeta del alumno: arriba quién es y su tardanza, abajo el bloque de
  /// la novedad de hoy.
  Widget _tarjeta(_Letrero l) {
    final a = l.alumno!;
    final t = l.tardanza;
    final fondo = t == null
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (l.yaTenia ? Colors.amber.shade50 : kColorTardanza.withValues(alpha: 0.18));
    final estado = t == null
        ? 'Sin tardanza hoy'
        : '${l.yaTenia ? 'Ya tenía tardanza' : 'Tardanza'} ${_hora(t)}';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: fondo,
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                AvatarPersona(fotoNombre: a.foto, nombre: a.nombreCompleto, radio: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.nombreCompleto,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${a.grupo} · $estado',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
                if (l.puedeDeshacer && t != null)
                  _BotonDeshacer(
                    // Una tardanza nueva es otro botón: la cuenta vuelve a empezar.
                    key: ObjectKey(t),
                    duracion: _ventanaDeshacer,
                    onPressed: () => _quitar(t, preguntar: false),
                  ),
              ],
            ),
          ),
          _BloqueNovedad(
            // El bloque es de un alumno: volver a leer su carné no borra lo
            // que el docente ya marcó; otro alumno empieza de cero.
            key: ValueKey(a.id),
            server: _server,
            alumno: a,
            uniforme: l.uniforme,
            deHoy: _novedades[a.id] ?? const [],
            ventanaDeshacer: _ventanaDeshacer,
            onGuardada: _alGuardarNovedad,
            onQuitada: _alQuitarNovedad,
          ),
        ],
      ),
    );
  }

  Widget _campoBuscar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: TextField(
        controller: _buscador,
        focusNode: _foco,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar alumno por nombre',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _buscador.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _buscador.clear();
                    _foco.unfocus();
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// Debajo de la cámara todo va en un mismo desplazamiento —la tarjeta, que
  /// con el bloque de la novedad es alta, y la lista—, con el buscador fijo
  /// arriba cuando la tarjeta ya se fue.
  Widget _abajo() {
    final l = _letrero;
    // Mientras se busca, la tarjeta se esconde: lo que importa son los nombres.
    final buscando = _foco.hasFocus || _buscador.text.isNotEmpty;
    final escala = MediaQuery.textScalerOf(context);

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (l?.error != null) SliverToBoxAdapter(child: _letreroDeError(l!.error!)),
        if (l?.alumno != null && !buscando) SliverToBoxAdapter(child: _tarjeta(l!)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _Fijo(
            alto: 8 + escala.scale(52),
            fondo: Theme.of(context).scaffoldBackgroundColor,
            child: _campoBuscar(),
          ),
        ),
        ..._lista(),
      ],
    );
  }

  List<Widget> _lista() {
    if (_cargando) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_errorAlTraer != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorAlTraer!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _traer, child: const Text('Reintentar')),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final texto = _buscador.text.trim();
    if (texto.isNotEmpty) return _resultados(texto);
    return _modo == ModoDeEntrada.tardanza ? _tardanzasDeHoy() : _novedadesDeHoy();
  }

  Widget _aviso(String texto) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );

  Widget _encabezado(String texto) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
        ),
      );

  /// Una lista con su raya entre filas, como las de antes.
  Widget _filas(int cuantas, Widget Function(int i) fila) => SliverList.separated(
        itemCount: cuantas,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) => fila(i),
      );

  List<Widget> _resultados(String texto) {
    final palabras =
        sinTildes(texto).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final hallados =
        _alumnos.where((a) => a.coincide(palabras)).take(40).toList();

    if (hallados.isEmpty) return [_aviso('Nadie con ese nombre este año.')];

    final conTardanza = _modo == ModoDeEntrada.tardanza;

    return [
      _filas(hallados.length, (i) {
        final a = hallados[i];
        final tardanza = _tardanzas[a.id];
        final conNovedad = (_novedades[a.id] ?? const []).isNotEmpty;
        // Quien ya tiene tardanza, o el modo «Sólo novedad», sólo se lee: se
        // abre su tarjeta para anotarle la novedad.
        final alTocar = conTardanza && tardanza == null
            ? () => _poner(alumno: a)
            : () => _leer(alumno: a);
        return ListTile(
          leading: AvatarPersona(fotoNombre: a.foto, nombre: a.nombreCompleto),
          title: Text(a.nombreCompleto),
          subtitle: Text(conNovedad ? '${a.grupo} · Novedad hoy' : a.grupo),
          trailing: conTardanza && tardanza != null
              ? _ChipHora(texto: _hora(tardanza))
              : FilledButton.tonal(
                  onPressed: _ocupado ? null : alTocar,
                  child: Text(conTardanza ? 'Tardanza' : 'Novedad'),
                ),
          onTap: _ocupado ? null : alTocar,
        );
      }),
    ];
  }

  List<Widget> _tardanzasDeHoy() {
    final hoy = _tardanzas.values.toList()
      ..sort((a, b) => (b.fechaHora ?? DateTime(0)).compareTo(a.fechaHora ?? DateTime(0)));

    if (hoy.isEmpty) {
      return [
        _aviso('Escanea el carné de quien llega tarde, o búscalo por nombre.\n'
            'Sólo tiene tardanza a quien tú se la pongas.'),
      ];
    }

    return [
      _encabezado('Tardanzas de hoy'),
      _filas(hoy.length, (i) {
        final t = hoy[i];
        final a = _porId[t.alumnoId];
        return ListTile(
          leading: AvatarPersona(
              fotoNombre: a?.foto, nombre: a?.nombreCompleto ?? '?'),
          title: Text(a?.nombreCompleto ?? 'Alumno ${t.alumnoId}'),
          subtitle: Text('${a?.grupo ?? ''} · ${_hora(t)}'),
          trailing: IconButton(
            tooltip: 'Quitar la tardanza',
            icon: const Icon(Icons.undo),
            onPressed: () => _quitar(t),
          ),
          // Para anotarle la novedad al que ya llegó tarde.
          onTap: a == null || _ocupado ? null : () => _leer(alumno: a),
        );
      }),
    ];
  }

  List<Widget> _novedadesDeHoy() {
    final hoy = _novedades.values.expand((n) => n).toList()
      ..sort((a, b) => (b.fechaHora ?? DateTime(0)).compareTo(a.fechaHora ?? DateTime(0)));

    if (hoy.isEmpty) {
      return [
        _aviso('Escanea el carné o busca al alumno para anotarle la novedad de uniforme.\n'
            'En este modo no se pone tardanza.'),
      ];
    }

    return [
      _encabezado('Novedades de hoy'),
      _filas(hoy.length, (i) {
        final n = hoy[i];
        final a = _porId[n.alumnoId];
        final hora = n.fechaHora == null ? '' : ' · ${formatoHora12(n.fechaHora!)}';
        return ListTile(
          leading: AvatarPersona(
              fotoNombre: a?.foto, nombre: a?.nombreCompleto ?? '?'),
          title: Text(a?.nombreCompleto ?? 'Alumno ${n.alumnoId}'),
          subtitle: Text('${a?.grupo ?? ''} · ${n.motivosLeibles}$hora'),
          trailing: IconButton(
            tooltip: 'Quitar la novedad',
            icon: const Icon(Icons.undo),
            onPressed: () => _quitarNovedadDeLaLista(n),
          ),
          onTap: a == null || _ocupado ? null : () => _leer(alumno: a),
        );
      }),
    ];
  }

  String _hora(TardanzaDeHoy t) =>
      t.fechaHora == null ? '' : formatoHora12(t.fechaHora!);
}

/// Lo último que pasó: un alumno (con su tardanza, puesta o que ya estaba, o
/// sin ella en «Sólo novedad») o un error.
class _Letrero {
  _Letrero._({
    this.alumno,
    this.tardanza,
    this.yaTenia = false,
    this.uniforme,
    this.error,
    this.puedeDeshacer = false,
  });

  factory _Letrero.alumno(
    AlumnoDePorteria a, {
    TardanzaDeHoy? tardanza,
    bool yaTenia = false,
    ConteoUniforme? uniforme,
    bool puedeDeshacer = false,
  }) =>
      _Letrero._(
          alumno: a,
          tardanza: tardanza,
          yaTenia: yaTenia,
          uniforme: uniforme,
          puedeDeshacer: puedeDeshacer);

  factory _Letrero.error(String error) => _Letrero._(error: error);

  final AlumnoDePorteria? alumno;
  final TardanzaDeHoy? tardanza;
  final bool yaTenia;

  /// Cómo va en la regla del uniforme. Cambia al guardar o deshacer la novedad.
  final ConteoUniforme? uniforme;
  final String? error;

  /// El «Deshacer» de la tardanza.
  final bool puedeDeshacer;

  _Letrero sinDeshacer() => _Letrero._(
      alumno: alumno,
      tardanza: tardanza,
      yaTenia: yaTenia,
      uniforme: uniforme,
      error: error);

  _Letrero conUniforme(ConteoUniforme? u) => _Letrero._(
      alumno: alumno,
      tardanza: tardanza,
      yaTenia: yaTenia,
      uniforme: u,
      error: error,
      puedeDeshacer: puedeDeshacer);
}

/// «Deshacer» con lo que le queda (Joseth, 13 oct 2026): un anillo que se
/// vacía con los segundos dentro. Sin la cuenta, el portero no sabía cuánto tiempo tenía
/// para corregir, y el botón desaparecía de golpe. La ventana la sigue cerrando
/// `_temporizadorDeshacer`; esto sólo la enseña.
class _BotonDeshacer extends StatefulWidget {
  const _BotonDeshacer({super.key, required this.duracion, required this.onPressed});

  final Duration duracion;
  final VoidCallback onPressed;

  @override
  State<_BotonDeshacer> createState() => _BotonDeshacerState();
}

class _BotonDeshacerState extends State<_BotonDeshacer> with SingleTickerProviderStateMixin {
  late final AnimationController _queda =
      AnimationController(vsync: this, duration: widget.duracion, value: 1)..reverse();

  @override
  void dispose() {
    _queda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _queda,
      builder: (context, _) {
        final segundos = (_queda.value * widget.duracion.inSeconds).ceil();
        return TextButton(
          onPressed: widget.onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El número dentro del anillo: «Deshacer · 8 s» al lado le quitaba sitio al
              // nombre, que es lo que el portero coteja con la cara.
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: CircularProgressIndicator(value: _queda.value, strokeWidth: 2.5)),
                    Text('$segundos', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('Deshacer'),
            ],
          ),
        );
      },
    );
  }
}

/// El recuadro que dice dónde poner el carné.
class _Mira extends StatelessWidget {
  const _Mira();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.62,
          heightFactor: 0.62,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipHora extends StatelessWidget {
  const _ChipHora({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kColorTardanza.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// «¿De quién es este carné?»: buscar al alumno y elegirlo. Lo que se elige
/// queda vinculado al código y la próxima vez se lee solo.
class _HojaDeQuienEs extends StatefulWidget {
  const _HojaDeQuienEs({required this.alumnos});

  final List<AlumnoDePorteria> alumnos;

  @override
  State<_HojaDeQuienEs> createState() => _HojaDeQuienEsState();
}

class _HojaDeQuienEsState extends State<_HojaDeQuienEs> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palabras = sinTildes(_texto.text.trim())
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final hallados = palabras.isEmpty
        ? const <AlumnoDePorteria>[]
        : widget.alumnos.where((a) => a.coincide(palabras)).take(30).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text('¿De quién es este carné?',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Todavía no está registrado. Busca al alumno: queda guardado y la próxima vez se lee solo.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _texto,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Nombre del alumno',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: hallados.length,
                itemBuilder: (context, i) {
                  final a = hallados[i];
                  return ListTile(
                    leading:
                        AvatarPersona(fotoNombre: a.foto, nombre: a.nombreCompleto),
                    title: Text(a.nombreCompleto),
                    subtitle: Text(a.grupo),
                    onTap: () => Navigator.pop(context, a),
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

/// «Novedad de hoy · Periodo N», debajo del alumno en la tarjeta: los seis
/// motivos, la nota, cómo va en la regla del uniforme y «Guardar novedad».
///
/// Es opcional en «Tardanza» —la tardanza ya se puso al leer— y es lo único
/// que hay que hacer en «Sólo novedad». Si el alumno ya tiene novedad hoy lo
/// dice primero, para no anotarle otra sin querer; «Anotar otra» abre los
/// botones igual.
class _BloqueNovedad extends StatefulWidget {
  const _BloqueNovedad({
    super.key,
    required this.server,
    required this.alumno,
    required this.uniforme,
    required this.deHoy,
    required this.ventanaDeshacer,
    required this.onGuardada,
    required this.onQuitada,
  });

  final Server server;
  final AlumnoDePorteria alumno;
  final ConteoUniforme? uniforme;

  /// Las novedades que ya tiene hoy, la más reciente primero.
  final List<NovedadDeHoy> deHoy;
  final Duration ventanaDeshacer;
  final void Function(NovedadDeHoy novedad, ConteoUniforme? uniforme) onGuardada;

  /// Con el conteo de antes de guardarla.
  final void Function(NovedadDeHoy novedad, ConteoUniforme? antes) onQuitada;

  @override
  State<_BloqueNovedad> createState() => _BloqueNovedadState();
}

class _BloqueNovedadState extends State<_BloqueNovedad> {
  final Set<MotivoDeNovedad> _elegidos = {};
  final _nota = TextEditingController();
  bool _guardando = false;
  String? _error;

  /// La que se acaba de guardar desde esta tarjeta, para «Deshacer».
  NovedadDeHoy? _guardada;
  ConteoUniforme? _antes;
  bool _puedeDeshacer = false;
  Timer? _ventana;

  /// El alumno ya tenía novedad hoy y el docente pidió anotar otra.
  bool _otra = false;

  @override
  void dispose() {
    _ventana?.cancel();
    _nota.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  List<String> get _claves => [
        // En el orden de los botones, no en el que se tocaron.
        for (final m in MotivoDeNovedad.values)
          if (_elegidos.contains(m)) m.clave,
      ];

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await guardarNovedad(widget.server,
        alumnoId: widget.alumno.id, motivos: _claves, descripcion: _nota.text);
    setState(() => _guardando = false);

    if (r.novedad == null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = r.error);
      return;
    }

    HapticFeedback.mediumImpact();
    _ventana?.cancel();
    setState(() {
      _antes = widget.uniforme;
      _guardada = r.novedad;
      _puedeDeshacer = true;
      _otra = false;
      _elegidos.clear();
      _nota.clear();
    });
    _ventana = Timer(widget.ventanaDeshacer,
        () => setState(() => _puedeDeshacer = false));
    widget.onGuardada(r.novedad!, r.uniforme);
  }

  Future<void> _deshacer() async {
    final n = _guardada;
    if (n == null) return;
    _ventana?.cancel();
    setState(() => _puedeDeshacer = false);

    final error = await quitarNovedad(widget.server, n.id);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    // Vuelven los botones con lo que tenía, para corregir sin volver a tocarlos.
    setState(() {
      _guardada = null;
      _otra = true;
      _elegidos
        ..clear()
        ..addAll(MotivoDeNovedad.values.where((m) => n.motivos.contains(m.clave)));
      _nota.text = n.descripcion ?? '';
    });
    widget.onQuitada(n, _antes);
  }

  @override
  Widget build(BuildContext context) {
    final periodo = widget.uniforme?.periodo;
    final guardada = _guardada;
    // Si la recién guardada se quitó desde la lista, ya no está.
    final sigue = guardada != null && widget.deHoy.any((n) => n.id == guardada.id);
    final yaTiene = widget.deHoy.isNotEmpty && !_otra;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            periodo == null ? 'Novedad de hoy' : 'Novedad de hoy · Periodo $periodo',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (sigue)
            ..._guardadaYa(guardada)
          else if (yaTiene)
            ..._yaTieneHoy()
          else
            ..._formulario(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }

  List<Widget> _guardadaYa(NovedadDeHoy n) => [
        Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Novedad guardada',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(n.motivosLeibles,
                      style: TextStyle(color: Colors.grey.shade800)),
                ],
              ),
            ),
            if (_puedeDeshacer)
              _BotonDeshacer(
                key: ObjectKey(n),
                duracion: widget.ventanaDeshacer,
                onPressed: _deshacer,
              )
            else
              TextButton(
                onPressed: () => setState(() {
                  _guardada = null;
                  _otra = true;
                }),
                child: const Text('Anotar otra'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _LetreroConteo(uniforme: widget.uniforme, motivos: n.motivos),
      ];

  List<Widget> _yaTieneHoy() => [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.deHoy.length == 1
                    ? 'Ya tiene novedad hoy'
                    : 'Ya tiene ${widget.deHoy.length} novedades hoy',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final n in widget.deHoy)
                Text(
                  [
                    n.motivosLeibles,
                    if (n.fechaHora != null) formatoHora12(n.fechaHora!),
                    if ((n.descripcion ?? '').trim().isNotEmpty) n.descripcion!.trim(),
                  ].join(' · '),
                  style: TextStyle(color: Colors.grey.shade800),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _LetreroConteo(uniforme: widget.uniforme),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _otra = true),
            icon: const Icon(Icons.add),
            label: const Text('Anotar otra'),
          ),
        ),
      ];

  List<Widget> _formulario() {
    final hayElegidos = _elegidos.isNotEmpty;

    return [
      // Tres por fila: los seis caben en dos filas y se tocan sin apuntar.
      LayoutBuilder(
        builder: (context, caja) {
          const espacio = 8.0;
          final ancho = (caja.maxWidth - espacio * 2) / 3;
          return Wrap(
            spacing: espacio,
            runSpacing: espacio,
            children: [
              for (final m in MotivoDeNovedad.values)
                SizedBox(
                  width: ancho,
                  child: _BotonMotivo(
                    texto: m.nombre,
                    elegido: _elegidos.contains(m),
                    onTap: _guardando
                        ? null
                        : () => setState(() {
                              if (!_elegidos.remove(m)) _elegidos.add(m);
                              _error = null;
                            }),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _nota,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: _elegidos.contains(MotivoDeNovedad.otra)
              ? 'Nota (cuál es la otra)'
              : 'Nota (opcional)',
          isDense: true,
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      const SizedBox(height: 8),
      _LetreroConteo(
        uniforme: widget.uniforme,
        motivos: hayElegidos ? _claves : null,
        sumar: true,
      ),
      const SizedBox(height: 10),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: hayElegidos && !_guardando ? _guardar : null,
        child: _guardando
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar novedad'),
      ),
    ];
  }
}

/// Uno de los seis motivos: se marca y se desmarca con un toque. Del color
/// del tema cuando está elegido.
class _BotonMotivo extends StatelessWidget {
  const _BotonMotivo({required this.texto, required this.elegido, this.onTap});

  final String texto;
  final bool elegido;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      toggled: elegido,
      child: Material(
        color: elegido ? colores.primary : colores.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: elegido ? colores.primary : colores.outline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    texto,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: elegido ? colores.onPrimary : colores.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Uniforme: 2 de 3 en el periodo 4», y el aviso naranja cuando toca una
/// situación tipo 1.
///
/// Con [sumar] es lo que pasaría al guardar los [motivos] elegidos («Con ésta:
/// 3 de 3…»); sin él, cómo va. Si los motivos no cuentan para la regla no se
/// promete conteo, y si el colegio la apagó (`cada` = 0) no se enseña nada.
class _LetreroConteo extends StatelessWidget {
  const _LetreroConteo({required this.uniforme, this.motivos, this.sumar = false});

  final ConteoUniforme? uniforme;
  final List<String>? motivos;
  final bool sumar;

  @override
  Widget build(BuildContext context) {
    final u = uniforme;
    if (u == null || u.apagada) return const SizedBox.shrink();

    final m = motivos;
    if (m != null && !u.cuentaCon(m)) {
      return _caja(context, 'Esta novedad no cuenta para la regla del uniforme.',
          pide: false);
    }

    final c = m != null && sumar ? u.conUnaMas() : u;
    final vez = c.cuenta <= c.cada
        ? '${c.cuenta} de ${c.cada} ${c.donde}'
        : '${c.cuenta} ${c.donde} · una situación cada ${c.cada}';
    return _caja(
      context,
      '${m != null && sumar ? 'Con ésta' : 'Uniforme'}: $vez',
      pide: c.pideSituacion,
    );
  }

  Widget _caja(BuildContext context, String texto, {required bool pide}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: pide
            ? Colors.orange.shade50
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: pide ? FontWeight.w600 : FontWeight.normal,
              color: pide ? Colors.orange.shade900 : Colors.grey.shade800,
            ),
          ),
          if (pide)
            Text(
              'Pide una situación tipo 1. Coordinación la verá en Pendientes.',
              style: TextStyle(fontSize: 13.5, color: Colors.orange.shade900),
            ),
        ],
      ),
    );
  }
}

/// El buscador fijo arriba de la lista cuando la tarjeta ya se desplazó.
class _Fijo extends SliverPersistentHeaderDelegate {
  _Fijo({required this.alto, required this.fondo, required this.child});

  final double alto;
  final Color fondo;
  final Widget child;

  @override
  double get minExtent => alto;

  @override
  double get maxExtent => alto;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: fondo, child: Align(alignment: Alignment.center, child: child));

  @override
  bool shouldRebuild(_Fijo old) =>
      old.alto != alto || old.fondo != fondo || old.child != child;
}
