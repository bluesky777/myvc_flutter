import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MiPerfilApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/PizarraDeFirma.dart';

/// La cuenta de quien entró: su foto, su contraseña y, si es titular, la firma
/// que sale en los boletines de su grupo.
///
/// **No es `UsuariosScreen`**, que administra cuentas ajenas: allí la
/// contraseña se pone sin pedir la anterior, y aquí se pide siempre.
///
/// Lo urgente es la firma. Desde `4f44e06` en `8myvc` el titular la **pide** y
/// la aprueba secretaría, coordinación o rectoría; el boletín no cambia hasta
/// entonces. Es el flujo de `/mi-firma` de la web, con sus mismos textos. Va
/// detrás de [Interruptores.miFirma] hasta que esas rutas estén en todos los
/// colegios.
class MiPerfilScreen extends StatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  State<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends State<MiPerfilScreen> {
  final _drawerController = ZoomDrawerController();
  final _server = Server();
  final _selector = ImagePicker();

  bool _subiendoFoto = false;

  /// La firma: null mientras carga o si falló, y entonces [_falloFirma] dice
  /// por qué.
  MiFirma? _firma;
  String? _falloFirma;
  bool _enviandoFirma = false;

  UserAutenticado get _yo => AuthService.user;

  /// La firma es del personal: `firmas-del-titular/*` lleva `auth.personal`,
  /// que deja fuera a alumnos y acudientes.
  bool get _veFirma =>
      Interruptores.miFirma && !_yo.esAlumno && !_yo.esAcudiente;

  @override
  void initState() {
    super.initState();
    Analitica.evento('mi_perfil_abierta');
    if (_veFirma) _cargarFirma();
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ── Foto ──────────────────────────────────────────────────────────────────

  Future<void> _cambiarFoto() async {
    final userId = _yo.id;
    if (userId == null) return;

    // En la web no hay cámara que ofrecer: el navegador abre su selector.
    final origen = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Tomar una foto'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Elegir de la galería'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
    if (origen == null) return;

    // El servidor la recorta a 200×200: mandarla de 4000 px es gastar datos
    // del plan de alguien para tirarlos allí.
    final XFile? elegida = await _selector.pickImage(
      source: origen,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (elegida == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final foto = await cambiarMiFoto(
        _server,
        userId: userId,
        bytes: await elegida.readAsBytes(),
        nombreArchivo: _nombreConExtension(elegida.name, 'jpg'),
      );
      Analitica.evento('mi_foto_cambiada',
          datos: {'aplicada': foto.aplicada ? 1 : 0});

      if (foto.aplicada) {
        setState(() => _yo.imagenNombre = foto.nombre);
        _avisar('Tu foto de perfil ha cambiado.');
      } else {
        _avisar('Foto enviada: un administrador tiene que aceptarla. '
            'Hasta entonces sigues con la que tienes.');
      }
    } catch (e) {
      _avisar('No se pudo cambiar la foto: $e');
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  /// El servidor decide por la extensión, y en la web el nombre puede llegar
  /// sin ella —`blob:…`—.
  String _nombreConExtension(String nombre, String respaldo) {
    final minusculas = nombre.toLowerCase();
    const validas = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    if (validas.any(minusculas.endsWith)) return nombre;
    return 'imagen.$respaldo';
  }

  // ── Contraseña ────────────────────────────────────────────────────────────

  Future<void> _cambiarContrasena() async {
    final userId = _yo.id;
    if (userId == null) return;

    final claves = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogoMiContrasena(),
    );
    if (claves == null) return;

    final fallo = await cambiarMiContrasena(
      _server,
      userId: userId,
      anterior: claves.$1,
      nueva: claves.$2,
    );
    if (fallo != null) {
      _avisar(fallo);
      return;
    }
    Analitica.evento('mi_contrasena_cambiada');
    _avisar('Contraseña cambiada. La próxima vez entra con la nueva.');
  }

  // ── Firma ─────────────────────────────────────────────────────────────────

  Future<void> _cargarFirma() async {
    setState(() {
      _firma = null;
      _falloFirma = null;
    });
    try {
      final firma = await traerMiFirma(_server);
      if (mounted) setState(() => _firma = firma);
    } catch (e) {
      if (mounted) setState(() => _falloFirma = '$e');
    }
  }

  Future<void> _dibujarFirma() async {
    final png = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _DibujarFirmaScreen(),
    ));
    if (png == null) return;
    await _enviarFirma(png, 'firma.png');
  }

  Future<void> _subirImagenDeFirma() async {
    final elegida = await _selector.pickImage(source: ImageSource.gallery);
    if (elegida == null) return;

    // El servidor solo acepta PNG y JPG, y lo decide por la extensión.
    final nombre = elegida.name.toLowerCase();
    final esPng = nombre.endsWith('.png');
    final esJpg = nombre.endsWith('.jpg') || nombre.endsWith('.jpeg');
    if (!esPng && !esJpg && !kIsWeb) {
      _avisar('La firma tiene que ser una imagen PNG o JPG.');
      return;
    }

    await _enviarFirma(
      await elegida.readAsBytes(),
      esPng ? 'firma.png' : 'firma.jpg',
    );
  }

  Future<void> _enviarFirma(List<int> bytes, String nombreArchivo) async {
    setState(() => _enviandoFirma = true);
    try {
      final solicitud =
          await pedirFirma(_server, bytes: bytes, nombreArchivo: nombreArchivo);
      Analitica.evento('mi_firma_pedida');
      if (mounted) setState(() => _firma = _firma?.conSolicitud(solicitud));
      _avisar('Firma enviada. Queda pendiente hasta que la aprueben.');
    } catch (e) {
      _avisar('No se pudo enviar la firma: $e');
    } finally {
      if (mounted) setState(() => _enviandoFirma = false);
    }
  }

  Future<void> _retirarFirma() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar la firma pendiente?'),
        content: const Text('Nadie la va a revisar. La firma que sale hoy en '
            'los boletines no cambia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Dejarla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (si != true) return;

    setState(() => _enviandoFirma = true);
    try {
      final anterior = await retirarFirma(_server);
      if (mounted) setState(() => _firma = _firma?.conSolicitud(anterior));
      _avisar('Firma retirada.');
    } catch (e) {
      _avisar('No se pudo retirar la firma: $e');
    } finally {
      if (mounted) setState(() => _enviandoFirma = false);
    }
  }

  // ── Pantalla ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: const Text('Mi perfil'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _veFirma ? _cargarFirma : () async {},
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _cabecera(),
              _tarjeta(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar contraseña'),
                  subtitle: const Text('Te pide la que tienes ahora.',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _cambiarContrasena,
                ),
              ),
              if (_veFirma) _seccionFirma(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Stack(
            children: [
              AvatarPersona(
                nombre: _yo.nombreVisible,
                fotoNombre: _yo.imagenNombre,
                radio: 52,
              ),
              if (_subiendoFoto)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_yo.nombreVisible,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text(_yo.username,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _subiendoFoto ? null : _cambiarFoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Cambiar foto'),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }

  Widget _seccionFirma() {
    final Widget cuerpo;

    if (_falloFirma != null) {
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No se pudo cargar tu firma.'),
          Text(_falloFirma!,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          TextButton(onPressed: _cargarFirma, child: const Text('Reintentar')),
        ],
      );
    } else if (_firma == null) {
      cuerpo = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!_firma!.esTitular) {
      cuerpo = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Este año no eres titular de ningún grupo',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('La firma del boletín es la del titular. Cuando te asignen un '
              'grupo, podrás pedir aquí que se cambie la tuya.'),
        ],
      );
    } else {
      cuerpo = _firmaDelTitular(_firma!);
    }

    return _tarjeta(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mi firma',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'La firma que sale sobre tu nombre en los boletines e informes '
              'de tu grupo. Si la cambias, la revisa secretaría, rectoría o '
              'coordinación antes de que se imprima.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            cuerpo,
          ],
        ),
      ),
    );
  }

  Widget _firmaDelTitular(MiFirma firma) {
    final solicitud = firma.solicitud;
    final pendiente = solicitud?.estado == EstadoDeFirma.pendiente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subtitulo('La que sale hoy'
            '${firma.grupos.isEmpty ? '' : ' · ${firma.grupos.join(', ')}'}'),
        if (firma.vigente != null)
          _ImagenDeFirma(nombre: firma.vigente!)
        else
          const Text('Aún no tienes firma: el boletín sale con el renglón en '
              'blanco.'),
        const SizedBox(height: 16),
        _subtitulo('La que pediste'),
        if (solicitud == null)
          const Text('No has pedido ningún cambio.')
        else
          _solicitud(solicitud),
        const SizedBox(height: 16),
        if (_enviandoFirma)
          const LinearProgressIndicator()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _dibujarFirma,
                icon: const Icon(Icons.draw_outlined, size: 18),
                label: const Text('Dibujarla aquí'),
              ),
              OutlinedButton.icon(
                onPressed: _subirImagenDeFirma,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                    pendiente ? 'Cambiar por otra imagen' : 'Subir una imagen'),
              ),
              if (pendiente)
                TextButton(
                  onPressed: _retirarFirma,
                  child: const Text('Retirar'),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          // La web recorta la imagen subida en el navegador; aquí no, y el
          // servidor tampoco. Por eso se pide ya recortada.
          'Una imagen subida sale tal cual: PNG o JPG, recortada y con fondo '
          'blanco o transparente.'
          '${pendiente ? ' Enviar otra reemplaza a la pendiente.' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _subtitulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );

  Widget _solicitud(SolicitudDeFirma s) {
    final (etiqueta, color) = switch (s.estado) {
      EstadoDeFirma.pendiente => ('Pendiente de aprobación', Colors.amber),
      EstadoDeFirma.aprobada => ('Aprobada', Colors.green),
      EstadoDeFirma.rechazada => ('Rechazada', Colors.red),
    };

    final detalle = [
      if (s.enviada != null) 'Enviada el ${_fecha(s.enviada!)}',
      if (s.respondida != null)
        '${s.estado == EstadoDeFirma.aprobada ? 'aprobada' : 'rechazada'} el '
            '${_fecha(s.respondida!)}'
            '${s.respondidaPor != null ? ' por ${s.respondidaPor}' : ''}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text(etiqueta),
          backgroundColor: color.withValues(alpha: 0.15),
          side: BorderSide(color: color),
          visualDensity: VisualDensity.compact,
        ),
        if (s.firmaNombre != null) _ImagenDeFirma(nombre: s.firmaNombre!),
        if (detalle.isNotEmpty)
          Text(detalle,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        if (s.estado == EstadoDeFirma.rechazada && s.motivo != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Motivo: ${s.motivo}'),
          ),
      ],
    );
  }

  /// `2026-09-24 10:00:00` → `24/09/2026`.
  String _fecha(String mysql) {
    final f = DateTime.tryParse(mysql);
    if (f == null) return mysql;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year}';
  }
}

/// Una firma tal como la sirve el servidor: estática en `images/perfil`, sin
/// token. Sobre blanco, que es como se imprime.
class _ImagenDeFirma extends StatelessWidget {
  final String nombre;

  const _ImagenDeFirma({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Image.network(
        Server.urlFoto(nombre),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('No se pudo cargar la imagen.',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
        ),
      ),
    );
  }
}

/// El diálogo de la contraseña propia: la actual y la nueva.
///
/// **La nueva se repite solo si va tapada.** Repetirla existe para cazar una
/// tecla que no se ve; con el ojo abierto ya se está viendo, y pedirla dos
/// veces es trabajo sin motivo (Joseth, 24 sep 2026). Cada campo tiene su ojo.
///
/// El mínimo de 4 caracteres es el de la página de perfil de la web. El
/// servidor solo exige que no venga vacía.
class _DialogoMiContrasena extends StatefulWidget {
  const _DialogoMiContrasena();

  @override
  State<_DialogoMiContrasena> createState() => _DialogoMiContrasenaState();
}

class _DialogoMiContrasenaState extends State<_DialogoMiContrasena> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  bool _actualTapada = true;
  bool _nuevaTapada = true;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  String? get _cortaLaNueva => _nueva.text.isNotEmpty && _nueva.text.length < 4
      ? 'Al menos 4 caracteres.'
      : null;

  String? get _noCoinciden =>
      _repetida.text.isNotEmpty && _repetida.text != _nueva.text
          ? 'Las dos no coinciden.'
          : null;

  bool get _lista =>
      _actual.text.isNotEmpty &&
      _nueva.text.length >= 4 &&
      (!_nuevaTapada || _nueva.text == _repetida.text);

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    required bool tapada,
    VoidCallback? alternar,
    bool autofocus = false,
    String? error,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        autofocus: autofocus,
        obscureText: tapada,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: etiqueta,
          errorText: error,
          border: const OutlineInputBorder(),
          suffixIcon: alternar == null
              ? null
              : IconButton(
                  icon: Icon(tapada ? Icons.visibility : Icons.visibility_off),
                  tooltip: tapada ? 'Mostrarla' : 'Taparla',
                  onPressed: alternar,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo(
              _actual,
              'Contraseña actual',
              autofocus: true,
              tapada: _actualTapada,
              alternar: () => setState(() => _actualTapada = !_actualTapada),
            ),
            _campo(
              _nueva,
              'Contraseña nueva',
              tapada: _nuevaTapada,
              error: _cortaLaNueva,
              alternar: () => setState(() => _nuevaTapada = !_nuevaTapada),
            ),
            if (_nuevaTapada)
              _campo(_repetida, 'Repite la nueva',
                  tapada: true, error: _noCoinciden),
            Text(
              _nuevaTapada
                  ? 'Sin espacios ni Ñ ni tildes. Con el ojo abierto no hace '
                      'falta repetirla.'
                  : 'Sin espacios ni Ñ ni tildes.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _lista
              ? () => Navigator.pop(context, (_actual.text, _nueva.text))
              : null,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

/// La pizarra a pantalla completa, fuera del menú lateral: si no, el gesto de
/// arrastrar para firmar le abría el cajón.
///
/// Devuelve el PNG ya recortado y transparente, o null si se canceló.
class _DibujarFirmaScreen extends StatefulWidget {
  const _DibujarFirmaScreen();

  @override
  State<_DibujarFirmaScreen> createState() => _DibujarFirmaScreenState();
}

class _DibujarFirmaScreenState extends State<_DibujarFirmaScreen> {
  final _trazos = TrazosDeFirma();
  bool _preparando = false;

  @override
  void dispose() {
    _trazos.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _preparando = true);
    final png = await _trazos.aPng();
    if (!mounted) return;
    Navigator.pop(context, png);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dibuja tu firma')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La proporción de la pizarra de la web —1000×320—, que es la
              // del renglón del boletín.
              AspectRatio(
                aspectRatio: 1000 / 320,
                child: PizarraDeFirma(trazos: _trazos),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _trazos.borrar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Borrar y volver a empezar'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No sale en los boletines todavía: la revisa secretaría, '
                'rectoría o coordinación, y te avisamos aquí mismo si la '
                'aprueban o no.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: _trazos,
                builder: (context, _) => FilledButton(
                  onPressed: _trazos.vacia || _preparando ? null : _enviar,
                  child: Text(
                      _preparando ? 'Preparando…' : 'Enviar para aprobación'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
