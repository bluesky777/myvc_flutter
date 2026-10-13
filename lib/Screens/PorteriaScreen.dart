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

/// PORTERÍA (Joseth, 9 oct 2026): la cámara arriba y el buscador abajo.
///
/// Se escanea **sólo a quien el portero decide**: el que llega un minuto tarde
/// y no se escanea no tiene tardanza. No hay hora que las ponga solas.
///
/// Escanear pone la tardanza al instante —sin confirmar— y deja «Deshacer» a
/// mano unos segundos. Es lo que hace que sea más rápido que la lista del grupo:
/// un carné, un pitido, el siguiente.
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
  const PorteriaScreen({super.key});

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

  List<AlumnoDePorteria> _alumnos = const [];
  final Map<int, AlumnoDePorteria> _porId = {};
  final Map<int, TardanzaDeHoy> _tardanzas = {};
  String? _errorAlTraer;
  bool _cargando = true;

  bool _ocupado = false;
  bool _enReposo = false;
  Timer? _temporizadorReposo;

  String? _ultimoCodigo;
  DateTime? _ultimoCodigoEn;

  /// Lo último que pasó, para el letrero de debajo de la cámara.
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

    _poner(codigo: codigo);
  }

  // ------------------------------------------------------------- tardanzas

  Future<void> _poner({String? codigo, AlumnoDePorteria? alumno}) async {
    setState(() => _ocupado = true);
    final r = await ponerTardanza(_server, codigo: codigo, alumnoId: alumno?.id);
    setState(() => _ocupado = false);

    if (!mounted) return;

    if (r.desconocido) {
      HapticFeedback.heavyImpact();
      await _preguntarDeQuienEs(r.codigo ?? codigo ?? '');
      return;
    }

    if (!r.puesta) {
      HapticFeedback.heavyImpact();
      _mostrar(_Letrero.error(
          r.anulado ? 'Ese carné está anulado. Búscalo por nombre.' : r.error!));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _tardanzas[r.alumno!.id] = r.tardanza!;
      _porId.putIfAbsent(r.alumno!.id, () => r.alumno!);
    });
    _mostrar(_Letrero.tardanza(r.alumno!, r.tardanza!, yaTenia: r.yaTenia));
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
      final si = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quitar la tardanza'),
          content: Text(
              '¿Quitar la tardanza de hoy de ${alumno?.nombreCompleto ?? 'este alumno'}?'),
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
      if (si != true) return;
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

    await _poner(alumno: elegido);
  }

  // ---------------------------------------------------------------- pantalla

  @override
  Widget build(BuildContext context) {
    final cuantas = _tardanzas.length;

    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        appBar: AppBar(
          title: TituloPantalla(
            titulo: 'Portería',
            subtitulo: cuantas == 0
                ? 'Sin tardanzas hoy'
                : (cuantas == 1 ? '1 tardanza hoy' : '$cuantas tardanzas hoy'),
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
              _zonaCamara(context),
              if (_letrero != null) _letreroWidget(_letrero!),
              _campoBuscar(),
              Expanded(child: _abajo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zonaCamara(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    // Con el teclado abierto la cámara se encoge y deja sitio a los
    // resultados; sigue leyendo igual.
    final escribiendo = _foco.hasFocus || MediaQuery.viewInsetsOf(context).bottom > 0;
    final altura = escribiendo ? 96.0 : (alto * 0.34).clamp(190.0, 330.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: altura,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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

  Widget _letreroWidget(_Letrero l) {
    final esError = l.error != null;
    final color = esError
        ? Colors.red.shade50
        : (l.yaTenia ? Colors.amber.shade50 : kColorTardanza.withValues(alpha: 0.18));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: esError
          ? Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(child: Text(l.error!)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _letrero = null),
                ),
              ],
            )
          : Row(
              children: [
                AvatarPersona(
                  fotoNombre: l.alumno!.foto,
                  nombre: l.alumno!.nombreCompleto,
                  radio: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.alumno!.nombreCompleto,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l.alumno!.grupo} · ${l.yaTenia ? 'Ya tenía tardanza' : 'Tardanza'} ${_hora(l.tardanza!)}',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
                if (l.puedeDeshacer)
                  _BotonDeshacer(
                    // Una tardanza nueva es otro botón: la cuenta vuelve a empezar.
                    key: ObjectKey(l.tardanza),
                    duracion: _ventanaDeshacer,
                    onPressed: () => _quitar(l.tardanza!, preguntar: false),
                  ),
              ],
            ),
    );
  }

  Widget _campoBuscar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _abajo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAlTraer != null) {
      return Center(
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
      );
    }

    final texto = _buscador.text.trim();
    return texto.isEmpty ? _deHoy() : _resultados(texto);
  }

  Widget _resultados(String texto) {
    final palabras =
        sinTildes(texto).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final hallados =
        _alumnos.where((a) => a.coincide(palabras)).take(40).toList();

    if (hallados.isEmpty) {
      return const Center(child: Text('Nadie con ese nombre este año.'));
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: hallados.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final a = hallados[i];
        final tardanza = _tardanzas[a.id];
        return ListTile(
          leading: AvatarPersona(fotoNombre: a.foto, nombre: a.nombreCompleto),
          title: Text(a.nombreCompleto),
          subtitle: Text(a.grupo),
          trailing: tardanza != null
              ? _ChipHora(texto: _hora(tardanza))
              : FilledButton.tonal(
                  onPressed: _ocupado ? null : () => _poner(alumno: a),
                  child: const Text('Tardanza'),
                ),
          onTap: tardanza != null || _ocupado ? null : () => _poner(alumno: a),
        );
      },
    );
  }

  Widget _deHoy() {
    final hoy = _tardanzas.values.toList()
      ..sort((a, b) => (b.fechaHora ?? DateTime(0)).compareTo(a.fechaHora ?? DateTime(0)));

    if (hoy.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Escanea el carné de quien llega tarde, o búscalo por nombre.\n'
            'Sólo tiene tardanza a quien tú se la pongas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: hoy.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Tardanzas de hoy',
                style: Theme.of(context).textTheme.titleSmall),
          );
        }
        final t = hoy[i - 1];
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
        );
      },
    );
  }

  String _hora(TardanzaDeHoy t) =>
      t.fechaHora == null ? '' : formatoHora12(t.fechaHora!);
}

/// Lo último que pasó: una tardanza (puesta o que ya estaba) o un error.
class _Letrero {
  _Letrero._({this.alumno, this.tardanza, this.yaTenia = false, this.error, this.puedeDeshacer = false});

  factory _Letrero.tardanza(AlumnoDePorteria a, TardanzaDeHoy t, {required bool yaTenia}) =>
      _Letrero._(alumno: a, tardanza: t, yaTenia: yaTenia, puedeDeshacer: !yaTenia);

  factory _Letrero.error(String error) => _Letrero._(error: error);

  final AlumnoDePorteria? alumno;
  final TardanzaDeHoy? tardanza;
  final bool yaTenia;
  final String? error;
  final bool puedeDeshacer;

  _Letrero sinDeshacer() => _Letrero._(
      alumno: alumno, tardanza: tardanza, yaTenia: yaTenia, error: error);
}

/// «Deshacer» con lo que le queda (Joseth, 13 oct 2026): un anillo que se
/// vacía y los segundos. Sin la cuenta, el portero no sabía cuánto tiempo tenía
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
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(value: _queda.value, strokeWidth: 2.5),
              ),
              const SizedBox(width: 8),
              Text('Deshacer · $segundos s'),
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
