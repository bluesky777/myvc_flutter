import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UsuariosApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/CuentaDeUsuarioModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ControlOcupado.dart';
import 'package:myvc_flutter/Widgets/SelectorGrupo.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Las cuentas del colegio: quién es quién, y arreglarle la entrada a alguien.
///
/// Es la única tarea administrativa que sí es diaria —«no me deja entrar», «se
/// me olvidó la clave»—, y por eso viene a la app cuando los ordinales del
/// manual se quedan en la plataforma web.
///
/// **Se entra por tipo y, si es alumnos o acudientes, por grupo.** Esa es toda
/// la diferencia con la pantalla que sustituye: aquella era una rejilla con las
/// 2.279 personas del colegio en una sola tabla, traídas de una vez y con tres
/// consultas por fila para sus roles. Aquí nunca se pide más de un grupo.
///
/// El plan entero, con lo que falta en el servidor y lo que está apagado y por
/// qué, en [docs/usuarios.md](../../docs/usuarios.md).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  TipoDeCuenta tipo = TipoDeCuenta.alumno;

  List<GrupoModel> grupos = [];
  GrupoModel? grupo;

  List<CuentaDeUsuario> cuentas = [];

  bool cargando = true;
  String? error;

  bool get _porGrupo =>
      tipo == TipoDeCuenta.alumno || tipo == TipoDeCuenta.acudiente;

  bool get _administra => AuthService.user.administraCuentas;

  @override
  void initState() {
    super.initState();
    Analitica.evento('usuarios_abierta');
    _arrancar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _arrancar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      grupos = await traerGruposDelColegio(server);
    } catch (err) {
      setState(() {
        cargando = false;
        error = 'No se pudieron traer los grupos: $err';
      });
      return;
    }

    setState(() => cargando = false);
  }

  Future<void> _cargar() async {
    if (_porGrupo && grupo == null) {
      setState(() => cuentas = []);
      return;
    }
    if (tipo == TipoDeCuenta.otro && !PendientesUsuarios.otrosUsuarios) {
      setState(() => cuentas = []);
      return;
    }

    setState(() {
      cargando = true;
      error = null;
      cuentas = [];
    });

    try {
      cuentas = switch (tipo) {
        TipoDeCuenta.alumno => await traerAlumnosDeGrupo(server, grupo!.id),
        TipoDeCuenta.acudiente =>
          await traerAcudientesDeGrupo(server, grupo!.id),
        TipoDeCuenta.docente => await traerDocentes(server),
        TipoDeCuenta.otro => const [],
      };
    } catch (err) {
      error = '$err'.replaceFirst('Exception: ', '');
    }

    setState(() => cargando = false);
  }

  void _cambiarTipo(TipoDeCuenta nuevo) {
    if (nuevo == tipo) return;

    setState(() {
      tipo = nuevo;
      cuentas = [];
      error = null;
    });

    _cargar();
  }

  void _cambiarGrupo(GrupoModel nuevo) {
    setState(() => grupo = nuevo);
    _cargar();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Abre la ficha de una cuenta y refleja lo que haya cambiado al cerrarla.
  Future<void> _abrirFicha(CuentaDeUsuario cuenta) async {
    if (!cuenta.tieneCuenta) {
      _avisar('${cuenta.nombreCompleto} todavía no tiene cuenta. Se crea desde '
          'la plataforma web.');
      return;
    }

    final quedo = await mostrarFichaDeCuenta(context, server, cuenta);
    if (quedo == null) return;

    setState(() {
      cuentas = [
        for (final c in cuentas)
          c.userId == quedo.userId && c.tipo == quedo.tipo ? quedo : c,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: _drawerController,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: TituloPantalla(titulo: 'Usuarios', subtitulo: _subtitulo()),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: Column(
          children: [
            _SelectorDeTipo(elegido: tipo, alElegir: _cambiarTipo),
            if (_porGrupo)
              CampoGrupo(
                grupos: grupos,
                elegido: grupo,
                alElegir: _cambiarGrupo,
              ),
            if (_porGrupo && grupo != null && _administra)
              _AccionesDeGrupo(
                server: server,
                grupo: grupo!,
                tipo: tipo,
                cuantos: cuentas.length,
                alAvisar: _avisar,
              ),
            Expanded(child: _cuerpo()),
          ],
        ),
      ),
    );
  }

  String? _subtitulo() {
    final nombre = switch (tipo) {
      TipoDeCuenta.alumno => 'Alumnos',
      TipoDeCuenta.acudiente => 'Acudientes',
      TipoDeCuenta.docente => 'Profesores',
      TipoDeCuenta.otro => 'Otros',
    };

    if (!_porGrupo) return nombre;
    if (grupo == null) return '$nombre · elige el grupo';
    return '$nombre · ${grupo!.nombre}';
  }

  Widget _cuerpo() {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(
          onPressed: _cargar,
          child: const Text('Reintentar'),
        ),
      );
    }

    if (tipo == TipoDeCuenta.otro && !PendientesUsuarios.otrosUsuarios) {
      return const _Centrado(
        icono: Icons.hourglass_empty,
        // Se dice qué falta y no «no disponible»: quien lo lee es quien puede
        // pedirlo, y «no disponible» no se puede pedir.
        texto: 'Las cuentas que no son de un alumno, un acudiente o un docente '
            'todavía no se pueden traer sin pedir las 2.279 del colegio.\n\n'
            'Falta un endpoint que las devuelva sueltas. Está pedido.',
      );
    }

    if (_porGrupo && grupo == null) {
      return const _Centrado(
        icono: Icons.groups_outlined,
        texto: 'Elige un grupo para ver sus cuentas.',
      );
    }

    if (cuentas.isEmpty) {
      return _Centrado(
        icono: Icons.person_off_outlined,
        texto: switch (tipo) {
          TipoDeCuenta.alumno => 'Este grupo no tiene alumnos matriculados.',
          TipoDeCuenta.acudiente =>
            'Ningún alumno de este grupo tiene acudientes registrados.',
          TipoDeCuenta.docente => 'El colegio no tiene docentes cargados.',
          TipoDeCuenta.otro => 'No hay otras cuentas.',
        },
      );
    }

    return RefreshIndicator(
      onRefresh: Analitica.refresco('usuarios', _cargar),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: cuentas.length,
        itemBuilder: (_, i) => _TarjetaCuenta(
          cuenta: cuentas[i],
          alTocar: () => _abrirFicha(cuentas[i]),
          alTocarAcudido: _abrirAcudido,
        ),
      ),
    );
  }

  /// La cuenta de un acudido, abierta desde la tarjeta de su acudiente.
  ///
  /// Es un alumno, así que se le puede hacer lo mismo que en la pestaña de
  /// alumnos. Se abre desde aquí para no obligar a salir, cambiar de tipo,
  /// buscar su grupo y encontrarlo: quien está mirando a la mamá y ve que el
  /// hijo no tiene usuario lo quiere arreglar ahí mismo.
  Future<void> _abrirAcudido(Acudido acudido) async {
    if (!acudido.tieneCuenta) {
      _avisar('${acudido.nombreCompleto} todavía no tiene cuenta. Se crea '
          'desde la plataforma web.');
      return;
    }

    await mostrarFichaDeCuenta(
      context,
      server,
      CuentaDeUsuario(
        userId: acudido.userId,
        tipo: TipoDeCuenta.alumno,
        nombres: acudido.nombres,
        apellidos: acudido.apellidos,
        username: acudido.username,
        fotoNombre: acudido.fotoNombre,
      ),
    );
  }
}

/// Los cuatro tipos, como chips.
///
/// Chips y no el selector con fotos: aquí no se está eligiendo a una persona
/// —para eso está la regla del proyecto— sino un montón para mirarlo.
class _SelectorDeTipo extends StatelessWidget {
  const _SelectorDeTipo({required this.elegido, required this.alElegir});

  final TipoDeCuenta elegido;
  final ValueChanged<TipoDeCuenta> alElegir;

  static const _nombres = {
    TipoDeCuenta.alumno: 'Alumnos',
    TipoDeCuenta.acudiente: 'Acudientes',
    TipoDeCuenta.docente: 'Profesores',
    TipoDeCuenta.otro: 'Otros',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final t in TipoDeCuenta.values) ...[
            ChoiceChip(
              label: Text(_nombres[t]!),
              selected: t == elegido,
              onSelected: (_) => alElegir(t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Las operaciones que tocan a todo el grupo de una vez.
///
/// Van en su propia tarjeta, separadas de la lista y con el color de aviso: lo
/// que hacen no se puede deshacer —el hash anterior no se guarda en ningún
/// sitio— y no se parece a nada de lo que hay debajo, que es de una persona.
class _AccionesDeGrupo extends StatelessWidget {
  const _AccionesDeGrupo({
    required this.server,
    required this.grupo,
    required this.tipo,
    required this.cuantos,
    required this.alAvisar,
  });

  final Server server;
  final GrupoModel grupo;
  final TipoDeCuenta tipo;
  final int cuantos;
  final void Function(String) alAvisar;

  /// La contraseña para todo el grupo solo existe hoy para alumnos, y es
  /// `alumnos/cambiar-claves`. La de acudientes no está escrita en el servidor.
  bool get _hayContrasenaDeGrupo =>
      tipo == TipoDeCuenta.alumno || PendientesUsuarios.masivasPorGrupoQueFaltan;

  @override
  Widget build(BuildContext context) {
    final pendientes = <String>[
      if (!PendientesUsuarios.masivasPorGrupoQueFaltan)
        'poner el documento como usuario',
      if (!_hayContrasenaDeGrupo) 'una contraseña para todos',
    ];

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: const Color(0xFFFFF6EC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFC98A4B)),
                const SizedBox(width: 6),
                Text(
                  'Todo el grupo ${grupo.nombre}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (PendientesUsuarios.masivasPorGrupoQueFaltan)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('Documento como usuario'),
                    onPressed: () => alAvisar('Pendiente del servidor.'),
                  ),
                if (_hayContrasenaDeGrupo)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.key_outlined, size: 18),
                    label: const Text('Una contraseña para todos'),
                    onPressed: () => _contrasenaParaTodos(context),
                  ),
              ],
            ),
            if (pendientes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Todavía no se puede ${pendientes.join(' ni ')}: falta en el '
                'servidor. Ver docs/usuarios.md.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _contrasenaParaTodos(BuildContext context) async {
    final clave = await _pedirContrasena(
      context,
      titulo: 'Una contraseña para el grupo ${grupo.nombre}',
      explicacion: _loQueVaAPasar(),
      boton: 'Cambiar las del grupo',
    );

    if (clave == null) return;

    final resultado = await contrasenaParaElGrupo(
      server,
      grupoId: grupo.id,
      clave: clave,
    );

    if (resultado.fallo != null) {
      alAvisar(resultado.fallo!);
      return;
    }

    Analitica.evento('grupo_contrasena_cambiada', datos: {'cuantos': cuantos});

    // El número, cuando el servidor lo diga. En la versión desplegada hoy no
    // viene, y entonces no se inventa: se dice que quedó hecho y ya.
    final cuantas = resultado.cambiadas;
    alAvisar(cuantas == null
        ? 'Listo. La contraseña del grupo ${grupo.nombre} quedó cambiada.'
        : 'Listo. $cuantas contraseñas cambiadas en ${grupo.nombre}.');
  }

  /// Lo que se le promete a quien va a apretar el botón.
  ///
  /// **No promete un número mientras el servidor alcance a más gente de la que
  /// la pantalla enseña.** La consulta desplegada hoy no filtra el estado de la
  /// matrícula ni las cuentas de la papelera, así que también le cambia la
  /// contraseña a los retirados del grupo: decir «a los 34» sería mentir. El
  /// arreglo está escrito en el backend y sin desplegar; en cuanto lo esté, el
  /// número que devuelve cuadra con la lista y esta frase puede prometerlo.
  /// Ver [PendientesUsuarios.cambiarClavesArreglado].
  String _loQueVaAPasar() {
    if (!PendientesUsuarios.cambiarClavesArreglado) {
      return cuantos == 0
          ? 'Se la pone a todos los alumnos de este grupo, y también a los que '
              'estén retirados de él. No se puede deshacer.'
          : 'Se la pone a los $cuantos alumnos de la lista, y también a los '
              'que estén retirados de este grupo. No se puede deshacer.';
    }

    return cuantos == 0
        ? 'Se la pone a todos los alumnos matriculados en este grupo. No se '
            'puede deshacer.'
        : 'Se la pone a los $cuantos alumnos de la lista. No se puede deshacer.';
  }
}

/// Una persona en la lista.
class _TarjetaCuenta extends StatelessWidget {
  const _TarjetaCuenta({
    required this.cuenta,
    required this.alTocar,
    required this.alTocarAcudido,
  });

  final CuentaDeUsuario cuenta;
  final VoidCallback alTocar;
  final ValueChanged<Acudido> alTocarAcudido;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarPersona(
                    nombre: cuenta.nombreCompleto,
                    fotoNombre: cuenta.fotoNombre,
                    radio: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _datos(context)),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
              if (cuenta.acudidos.isNotEmpty) _losAcudidos(),
              if (cuenta.years.isNotEmpty) _losYears(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datos(BuildContext context) {
    final usuario = cuenta.username?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cuenta.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              usuario == null || usuario.isEmpty
                  ? Icons.person_off_outlined
                  : Icons.person_outline,
              size: 14,
              color: Colors.black45,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                // «Sin usuario» y no un hueco: es el dato que se viene a
                // buscar, y un hueco se lee como que la app no lo trajo.
                usuario == null || usuario.isEmpty ? 'Sin usuario' : usuario,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: usuario == null || usuario.isEmpty
                      ? Colors.redAccent
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        if (_linea() != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _linea()!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (PendientesUsuarios.ultimoAcceso)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              cuenta.ultimoAcceso == null
                  ? 'Nunca ha entrado'
                  : 'Última vez: ${formatoDiaYHora(cuenta.ultimoAcceso)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (PendientesUsuarios.rolesPorPersona && cuenta.roles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final rol in cuenta.roles) _Etiqueta(texto: rol.nombre),
              ],
            ),
          ),
      ],
    );
  }

  /// El celular, el documento y el parentesco, los que haya, en una línea.
  String? _linea() {
    final trozos = <String>[
      if (cuenta.parentesco != null && cuenta.parentesco!.isNotEmpty)
        cuenta.parentesco!,
      if (cuenta.celular != null && cuenta.celular!.isNotEmpty)
        cuenta.celular!,
      if (cuenta.documento != null && cuenta.documento!.isNotEmpty)
        'CC ${cuenta.documento}',
    ];

    return trozos.isEmpty ? null : trozos.join(' · ');
  }

  Widget _losAcudidos() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A cargo de',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          for (final acudido in cuenta.acudidos)
            InkWell(
              onTap: () => alTocarAcudido(acudido),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    AvatarPersona(
                      nombre: acudido.nombreCompleto,
                      fotoNombre: acudido.fotoNombre,
                      radio: 13,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        acudido.nombreGrupo == null
                            ? acudido.nombreCompleto
                            : '${acudido.nombreCompleto} · '
                                '${acudido.nombreGrupo}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      acudido.username ?? 'sin usuario',
                      style: TextStyle(
                        fontSize: 11,
                        color: acudido.username == null
                            ? Colors.redAccent
                            : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _losYears() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contratado en',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final year in cuenta.years) _Etiqueta(texto: year),
            ],
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _Centrado extends StatelessWidget {
  const _Centrado({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
            if (accion != null) ...[const SizedBox(height: 12), accion!],
          ],
        ),
      ),
    );
  }
}

/// Abre la ficha de una cuenta. Devuelve cómo quedó, o null si no cambió nada.
Future<CuentaDeUsuario?> mostrarFichaDeCuenta(
  BuildContext context,
  Server server,
  CuentaDeUsuario cuenta,
) {
  return showModalBottomSheet<CuentaDeUsuario>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FichaCuenta(server: server, cuenta: cuenta),
  );
}

/// La ficha de una cuenta: su usuario, su contraseña y sus roles.
///
/// Aquí no se edita la ficha de la persona —dirección, correo, fecha de
/// nacimiento—: eso es de la plataforma web. Aquí se toca la **cuenta**.
class _FichaCuenta extends StatefulWidget {
  const _FichaCuenta({required this.server, required this.cuenta});

  final Server server;
  final CuentaDeUsuario cuenta;

  @override
  State<_FichaCuenta> createState() => _FichaCuentaState();
}

class _FichaCuentaState extends State<_FichaCuenta> {
  late CuentaDeUsuario cuenta = widget.cuenta;
  late final _usuario = TextEditingController(text: cuenta.username ?? '');

  bool _guardandoUsuario = false;
  bool _cambio = false;

  @override
  void dispose() {
    _usuario.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    // El teclado tapa los campos si la hoja no se sube con él.
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cabecera(),
              const Divider(height: 28),
              _elUsuario(),
              const SizedBox(height: 20),
              _laContrasena(),
              const SizedBox(height: 20),
              _losRoles(),
              if (PendientesUsuarios.ultimoAcceso) ...[
                const SizedBox(height: 20),
                _laUltimaVez(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Row(
      children: [
        AvatarPersona(
          nombre: cuenta.nombreCompleto,
          fotoNombre: cuenta.fotoNombre,
          radio: 26,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cuenta.nombreCompleto,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
              Text(
                switch (cuenta.tipo) {
                  TipoDeCuenta.alumno => 'Alumno',
                  TipoDeCuenta.acudiente => 'Acudiente',
                  TipoDeCuenta.docente => 'Profesor',
                  TipoDeCuenta.otro => 'Cuenta del colegio',
                },
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.pop(context, _cambio ? cuenta : null),
        ),
      ],
    );
  }

  Widget _elUsuario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nombre de usuario',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (!PendientesUsuarios.cambiarUsername)
          _Apagado(
            valor: cuenta.username ?? 'Sin usuario',
            // Se dice el motivo entero. Quien lo lee es quien puede decidir
            // encenderlo, y «no disponible» no se puede decidir.
            motivo: 'Cambiarlo está apagado hasta que el servidor cierre la '
                'guarda de esa ruta: hoy la deja usar a cualquier docente, '
                'sobre cualquier cuenta. Ver docs/usuarios.md.',
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usuario,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'usuario',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ControlOcupado(
                ocupado: _guardandoUsuario,
                child: FilledButton(
                  onPressed: _guardarUsuario,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _guardarUsuario() async {
    final nuevo = _usuario.text.trim();

    if (nuevo.isEmpty) {
      _avisar('El nombre de usuario no puede quedar vacío.');
      return;
    }
    if (nuevo == (cuenta.username ?? '')) return;

    setState(() => _guardandoUsuario = true);

    // Se pregunta antes porque `users.username` es UNIQUE y el endpoint que lo
    // escribe no avisa: se cae con un 500 y el usuario se queda sin saber que
    // el nombre ya era de otro.
    final libre = await estaLibreElNombreDeUsuario(widget.server, nuevo);

    if (!libre) {
      setState(() => _guardandoUsuario = false);
      _avisar('«$nuevo» ya está ocupado por otra cuenta.');
      return;
    }

    final fallo = await cambiarNombreDeUsuario(
      widget.server,
      userId: cuenta.userId,
      username: nuevo,
    );

    setState(() => _guardandoUsuario = false);

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    setState(() {
      cuenta = cuenta.conUsername(nuevo);
      _cambio = true;
    });
    Analitica.evento('cuenta_usuario_cambiado');
    _avisar('Nombre de usuario cambiado.');
  }

  Widget _laContrasena() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contraseña',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'La anterior no se puede recuperar: se escribe una nueva y esa queda.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.key_outlined, size: 18),
          label: const Text('Ponerle una contraseña'),
          onPressed: _ponerleContrasena,
        ),
      ],
    );
  }

  Future<void> _ponerleContrasena() async {
    final clave = await _pedirContrasena(
      context,
      titulo: 'Contraseña de ${cuenta.nombreCompleto}',
      explicacion: 'Entra con ella la próxima vez. No se puede deshacer.',
      boton: 'Cambiarla',
    );

    if (clave == null) return;

    final fallo = await ponerContrasena(
      widget.server,
      userId: cuenta.userId,
      clave: clave,
    );

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    Analitica.evento('cuenta_contrasena_cambiada');
    _avisar('Contraseña cambiada.');
  }

  Widget _losRoles() {
    if (!PendientesUsuarios.rolesPorPersona) {
      return const _Apagado(
        valor: 'Roles',
        motivo: 'Los roles de una persona hoy solo salen trayendo las 2.279 '
            'cuentas del colegio, y eso es lo que esta pantalla existe para no '
            'hacer. Falta el endpoint que los traiga por lista. Está pedido.',
      );
    }

    return _RolesDeLaCuenta(
      server: widget.server,
      cuenta: cuenta,
      alQuedar: (nuevos) => setState(() {
        cuenta = cuenta.conRoles(nuevos);
        _cambio = true;
      }),
    );
  }

  Widget _laUltimaVez() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Última vez',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          cuenta.ultimoAcceso == null
              ? 'No ha entrado nunca.'
              : formatoDiaYHora(cuenta.ultimoAcceso),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

/// Lo que se enseña en el sitio de algo que todavía no se puede hacer.
class _Apagado extends StatelessWidget {
  const _Apagado({required this.valor, required this.motivo});

  final String valor;
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(motivo,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

/// Los roles de una persona, con el catálogo del colegio.
class _RolesDeLaCuenta extends StatefulWidget {
  const _RolesDeLaCuenta({
    required this.server,
    required this.cuenta,
    required this.alQuedar,
  });

  final Server server;
  final CuentaDeUsuario cuenta;
  final ValueChanged<List<RolDeUsuario>> alQuedar;

  @override
  State<_RolesDeLaCuenta> createState() => _RolesDeLaCuentaState();
}

class _RolesDeLaCuentaState extends State<_RolesDeLaCuenta> {
  List<RolDeUsuario> catalogo = [];
  late List<RolDeUsuario> suyos = [...widget.cuenta.roles];

  bool cargando = true;
  String? error;

  /// Cuál se está moviendo. Por su id, para que esperar por uno no congele los
  /// otros.
  final Set<int> _ocupados = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargar() async {
    try {
      catalogo = await traerCatalogoDeRoles(widget.server);
    } catch (err) {
      error = '$err'.replaceFirst('Exception: ', '');
    }
    setState(() => cargando = false);
  }

  Future<void> _mover(RolDeUsuario rol, bool loTiene) async {
    setState(() => _ocupados.add(rol.id));

    final fallo = loTiene
        ? await quitarRol(widget.server,
            userId: widget.cuenta.userId, rolId: rol.id)
        : await ponerRol(widget.server,
            userId: widget.cuenta.userId, rolId: rol.id);

    setState(() => _ocupados.remove(rol.id));

    if (fallo != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(fallo)));
      return;
    }

    setState(() {
      suyos = loTiene
          ? [for (final r in suyos) if (r.id != rol.id) r]
          : [...suyos, rol];
    });
    widget.alQuedar(suyos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Roles', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Deciden qué puede hacer en la plataforma. Ante la duda, se pregunta '
          'antes de tocarlos.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        if (cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (error != null)
          Text(error!, style: const TextStyle(fontSize: 12))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final rol in catalogo)
                ControlOcupado(
                  ocupado: _ocupados.contains(rol.id),
                  child: FilterChip(
                    label: Text(rol.nombre),
                    selected: suyos.any((r) => r.id == rol.id),
                    onSelected: (_) =>
                        _mover(rol, suyos.any((r) => r.id == rol.id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Pide una contraseña nueva, la enseña mientras se escribe y la confirma.
///
/// Se enseña a propósito —con el ojo para taparla—: quien la escribe se la va a
/// dictar a alguien por teléfono, y escribirla a ciegas para después no poder
/// leerla es la forma segura de dejar a una familia fuera.
///
/// Devuelve la contraseña, o null si se cerró sin confirmar.
Future<String?> _pedirContrasena(
  BuildContext context, {
  required String titulo,
  required String explicacion,
  required String boton,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoContrasena(
      titulo: titulo,
      explicacion: explicacion,
      boton: boton,
    ),
  );
}

class _DialogoContrasena extends StatefulWidget {
  const _DialogoContrasena({
    required this.titulo,
    required this.explicacion,
    required this.boton,
  });

  final String titulo;
  final String explicacion;
  final String boton;

  @override
  State<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<_DialogoContrasena> {
  final _clave = TextEditingController();
  bool _tapada = false;

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.explicacion,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _clave,
            autofocus: true,
            obscureText: _tapada,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Contraseña nueva',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _tapada ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _tapada = !_tapada),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // Vacía no: el servidor la acepta y `Hash::make('')` deja la cuenta
          // abierta a cualquiera que sepa el nombre de usuario.
          onPressed: _clave.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _clave.text),
          child: Text(widget.boton),
        ),
      ],
    );
  }
}
