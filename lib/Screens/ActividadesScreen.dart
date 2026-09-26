import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Screens/AvisosDeActividadesScreen.dart';
import 'package:myvc_flutter/Screens/EntregarTareaScreen.dart';
import 'package:myvc_flutter/Screens/MisRespuestasActividadScreen.dart';
import 'package:myvc_flutter/Screens/ResponderActividadScreen.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Las actividades del alumno y del acudiente: pendientes y hechas.
///
/// Maqueta `FlutterLista`. **Una sola petición**, `act/bandeja?vista=responder`,
/// y todo lo demás —el selector de hijo, las dos pestañas, los grupos «vence
/// hoy» / «esta semana»— se arma aquí con lo que llegó.
///
/// ## El selector de hijo sale de la bandeja, no del muro
///
/// El acudiente con «una vez por hijo» recibe **una fila por hijo**, con el
/// hijo en `por_alumno` (contrato §3.1). Los hijos del selector son esos, y no
/// la lista de acudidos del muro: pedirla sería una segunda petición para
/// enseñar un hijo del que no hay nada que responder. Lo que el acudiente
/// responde **una sola vez** llega sin `por_alumno` y sale con cualquier hijo
/// elegido, marcado «para ti».
///
/// ## Desde un aviso
///
/// Con [aviso] abre directamente esa actividad en cuanto carga la bandeja, que
/// es donde se sabe si toca responderla, entregarla o ver lo respondido. Si ya
/// no está —la cerraron, o no le toca— lo dice y se queda en la lista.
class ActividadesScreen extends StatefulWidget {
  const ActividadesScreen({super.key, this.aviso});

  final AvisoDeActividad? aviso;

  @override
  State<ActividadesScreen> createState() => _ActividadesScreenState();
}

class _ActividadesScreenState extends State<ActividadesScreen> {
  final _drawerController = ZoomDrawerController();
  final _server = Server();

  bool _cargando = true;
  String? _error;
  List<ActEnBandeja> _filas = const [];
  int? _hijo;
  bool _verHechas = false;
  AvisoDeActividad? _avisoPendiente;
  AvisosAct? _avisos;

  @override
  void initState() {
    super.initState();
    _avisoPendiente = widget.aviso;
    _hijo = widget.aviso?.alumnoId;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _filas.isEmpty;
      _error = null;
    });
    try {
      final filas = await traerBandejaDeActividades(_server);
      if (!mounted) return;
      setState(() {
        _filas = filas;
        _cargando = false;
        final hijos = _hijos;
        if (hijos.isNotEmpty &&
            (_hijo == null || !hijos.any((h) => h.alumnoId == _hijo))) {
          _hijo = hijos.first.alumnoId;
        }
      });
      _abrirElDelAviso();
      _traerAvisos();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$err';
      });
    }
  }

  /// La campana. Si el colegio todavía no tiene la tanda 5 contesta 404, y la
  /// campana simplemente no sale: nada que avisar.
  Future<void> _traerAvisos() async {
    try {
      final avisos = await traerAvisosDeActividades(_server);
      if (mounted) setState(() => _avisos = avisos);
    } catch (_) {}
  }

  /// Los hijos por los que hay filas, en el orden en que llegaron.
  List<PersonaCorta> get _hijos {
    final vistos = <int>{};
    return [
      for (final f in _filas)
        if (f.porAlumno?.alumnoId != null && vistos.add(f.porAlumno!.alumnoId!))
          f.porAlumno!
    ];
  }

  List<ActEnBandeja> get _delHijo => _filas
      .where((f) => f.porAlumno == null || f.porAlumno!.alumnoId == _hijo)
      .toList();

  void _abrirElDelAviso() {
    final aviso = _avisoPendiente;
    if (aviso == null) return;
    _avisoPendiente = null;
    _abrirAviso(aviso);
  }

  /// Lleva a donde apunta un aviso —del push o de la campana—.
  ///
  /// Casi siempre la actividad está en la bandeja, y entonces se abre como si
  /// se hubiera tocado su fila: la fila sabe si toca responder, entregar o ver
  /// lo hecho. **El caso que no** es el acudiente con un aviso del tema de su
  /// hijo sobre algo que responde el hijo (una tarea, un cuestionario): no le
  /// sale en su lista porque no es para él. Si es la nota o los resultados,
  /// se los enseña «mis respuestas» con el `alumno_id`; si es algo por
  /// responder, se le dice que lo hace el hijo desde su cuenta.
  void _abrirAviso(AvisoDeActividad aviso) {
    ActEnBandeja? fila;
    for (final f in _filas) {
      if (f.id != aviso.actividadId) continue;
      if (aviso.alumnoId != null &&
          f.porAlumno != null &&
          f.porAlumno!.alumnoId != aviso.alumnoId) {
        continue;
      }
      fila = f;
      break;
    }

    if (fila != null) {
      final encontrada = fila;
      setState(() {
        _hijo = encontrada.porAlumno?.alumnoId ?? _hijo;
        _verHechas = !encontrada.pendiente;
      });
      _abrir(encontrada);
      return;
    }

    final acudiente = AuthService.user.esAcudiente;
    final alumnoId = aviso.alumnoId;
    if (acudiente && alumnoId != null && aviso.esDeLoHecho) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MisRespuestasActividadScreen.porId(
            actividadId: aviso.actividadId,
            alumnoId: alumnoId,
            paraQuien: aviso.nombreAlumno ?? _nombreDeHijo(alumnoId),
          ),
        ),
      );
      return;
    }

    final nombre = alumnoId == null
        ? null
        : (aviso.nombreAlumno ?? _nombreDeHijo(alumnoId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(acudiente && alumnoId != null
            ? '${nombre ?? 'Tu acudido'} la responde desde su propia cuenta.'
            : 'Esa actividad ya no está en tu lista.')));
  }

  String? _nombreDeHijo(int alumnoId) {
    for (final h in _hijos) {
      if (h.alumnoId == alumnoId) return h.primerNombre;
    }
    return null;
  }

  Future<void> _abrirCampana() async {
    final elegido = await Navigator.push<AvisoAct>(
      context,
      MaterialPageRoute(
          builder: (_) => AvisosDeActividadesScreen(yaTraidos: _avisos)),
    );
    if (!mounted) return;
    // Abrirla los marcó leídos: el número se va sin esperar al servidor.
    final antes = _avisos;
    if (antes != null) {
      setState(() => _avisos =
          AvisosAct(noLeidos: 0, hastaId: antes.hastaId, avisos: antes.avisos));
    }
    if (elegido != null) {
      _abrirAviso(AvisoDeActividad(
        actividadId: elegido.actividadId,
        alumnoId: elegido.alumnoId,
        clase: elegido.clase,
        nombreAlumno: elegido.alumnoNombre == null
            ? null
            : PersonaCorta(nombre: elegido.alumnoNombre!).primerNombre,
      ));
    }
  }

  Future<void> _abrir(ActEnBandeja fila) async {
    final Widget destino;
    final m = fila.miEstado;

    if (fila.esTarea) {
      // La tarea se puede cambiar hasta el cierre, y después si acepta
      // entregas tarde: en ese caso llega `cerrada` y `pendiente`, no
      // `vencida`. La calificada ya no se toca.
      destino = (m == 'pendiente' ||
              m == 'borrador' ||
              m == 'entregada' ||
              m == 'tarde')
          ? EntregarTareaScreen(fila: fila)
          : MisRespuestasActividadScreen(fila: fila);
    } else {
      destino = fila.pendiente
          ? ResponderActividadScreen(fila: fila)
          : MisRespuestasActividadScreen(fila: fila);
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => destino));
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: EstiloActividades.fondo,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle?.call(),
          ),
          title: const TituloPantalla(titulo: 'Actividades'),
          actions: [
            if (_avisos != null)
              IconButton(
                tooltip: 'Avisos',
                onPressed: _abrirCampana,
                icon: Badge(
                  isLabelVisible: _avisos!.noLeidos > 0,
                  label: Text('${_avisos!.noLeidos}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
          ],
        ),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final delHijo = _delHijo;
    final pendientes = delHijo.where((f) => f.pendiente).toList();
    final hechas = delHijo.where((f) => !f.pendiente).toList();
    final grupos =
        _verHechas ? _gruposHechas(hechas) : _gruposPendientes(pendientes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(pendientes.length),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: grupos.isEmpty
                ? ListView(children: [_vacio()])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    children: [
                      for (final (nombre, filas) in grupos) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                          child: Text(
                            nombre.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                              color: EstiloActividades.tintaApagada,
                            ),
                          ),
                        ),
                        for (final f in filas) ...[
                          _tarjeta(f),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _cabecera(int nPendientes) {
    final hijos = _hijos;
    final acudiente = AuthService.user.esAcudiente;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (acudiente && hijos.length > 1) ...[
            const Text('Eres acudiente oficial de:',
                style: TextStyle(
                    fontSize: 12.5, color: EstiloActividades.tintaApagada)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final h in hijos)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _chipDeHijo(h),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _pestanas(nPendientes),
        ],
      ),
    );
  }

  Widget _chipDeHijo(PersonaCorta h) {
    final elegido = h.alumnoId == _hijo;
    return Semantics(
      selected: elegido,
      button: true,
      child: Material(
        color: elegido ? EstiloActividades.primarioSuave : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color:
                elegido ? EstiloActividades.primario : EstiloActividades.borde,
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _hijo = h.alumnoId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: EstiloActividades.primarioOscuro,
                  child: Text(h.iniciales,
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: 7),
                Text(h.primerNombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: elegido ? FontWeight.w600 : FontWeight.w400,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pestanas(int nPendientes) {
    Widget pestana(String texto, bool elegida, VoidCallback alTocar) =>
        Expanded(
          child: Semantics(
            selected: elegida,
            button: true,
            child: GestureDetector(
              onTap: alTocar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: elegida ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: elegida
                      ? const [
                          BoxShadow(
                              color: Color(0x33142240),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                              spreadRadius: -3)
                        ]
                      : null,
                ),
                child: Text(texto,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: elegida ? FontWeight.w700 : FontWeight.w400,
                      color: elegida
                          ? EstiloActividades.tinta
                          : EstiloActividades.tintaSuave,
                    )),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          pestana(nPendientes > 0 ? 'Pendientes · $nPendientes' : 'Pendientes',
              !_verHechas, () => setState(() => _verHechas = false)),
          pestana(
              'Hechas', _verHechas, () => setState(() => _verHechas = true)),
        ],
      ),
    );
  }

  List<(String, List<ActEnBandeja>)> _gruposPendientes(
      List<ActEnBandeja> filas) {
    final ahora = DateTime.now();
    final hoy = <ActEnBandeja>[];
    final semana = <ActEnBandeja>[];
    final despues = <ActEnBandeja>[];
    final sinFecha = <ActEnBandeja>[];

    for (final f in filas) {
      final c = f.cierraAt;
      if (c == null) {
        sinFecha.add(f);
      } else if (esElMismoDia(c, ahora) || c.isBefore(ahora)) {
        hoy.add(f);
      } else if (c.difference(ahora).inDays < 7) {
        semana.add(f);
      } else {
        despues.add(f);
      }
    }
    int porCierre(ActEnBandeja a, ActEnBandeja b) =>
        (a.cierraAt ?? DateTime(9999)).compareTo(b.cierraAt ?? DateTime(9999));

    return [
      if (hoy.isNotEmpty) ('Vence hoy', hoy..sort(porCierre)),
      if (semana.isNotEmpty) ('Esta semana', semana..sort(porCierre)),
      if (despues.isNotEmpty) ('Más adelante', despues..sort(porCierre)),
      if (sinFecha.isNotEmpty) ('Sin fecha de cierre', sinFecha),
    ];
  }

  List<(String, List<ActEnBandeja>)> _gruposHechas(List<ActEnBandeja> filas) {
    final hechas = filas
        .where((f) =>
            f.miEstado != 'vencida' &&
            f.miEstado != 'pendiente' &&
            f.miEstado != 'borrador')
        .toList();
    final sinHacer = filas.where((f) => !hechas.contains(f)).toList();
    return [
      if (hechas.isNotEmpty) ('Entregadas y respondidas', hechas),
      if (sinHacer.isNotEmpty) ('Cerraron sin respuesta', sinHacer),
    ];
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      child: Column(
        children: [
          Icon(
            _verHechas ? Icons.inbox_outlined : Icons.task_alt,
            size: 48,
            color: EstiloActividades.tintaApagada,
          ),
          const SizedBox(height: 12),
          Text(
            _verHechas
                ? 'Todavía no has respondido ni entregado ninguna actividad.'
                : 'No tienes actividades pendientes.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: EstiloActividades.tintaSuave),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(ActEnBandeja f) {
    final (estado, fondo, tinta) = _estadoDe(f);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EstiloActividades.radio),
        child: InkWell(
          borderRadius: BorderRadius.circular(EstiloActividades.radio),
          onTap: () => _abrir(f),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                EstiloActividades.chapaDelModo(f.modo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.titulo,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: EstiloActividades.tinta)),
                      const SizedBox(height: 2),
                      Text(_subtitulo(f),
                          style: const TextStyle(
                              fontSize: 12,
                              color: EstiloActividades.tintaApagada)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                EstiloActividades.pildora(estado, fondo, tinta),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitulo(ActEnBandeja f) {
    final partes = <String>[];
    if (AuthService.user.esAcudiente && f.porAlumno == null) {
      partes.add('Para ti, acudiente');
    }
    partes.add(f.donde);

    if (f.pendiente) {
      final c = f.cierraAt;
      if (c != null) {
        partes.add(esElMismoDia(c, DateTime.now())
            ? 'hasta las ${formatoHora12(c)}'
            : fechaDeActividad(c, conHora: false));
      }
      if (f.anonima) partes.add('anónima');
    } else if (f.miNota != null) {
      partes.add('nota ${f.miNota}');
    } else if (f.miEstado == 'entregada' || f.miEstado == 'tarde') {
      partes.add(f.abierta ? 'puedes cambiarla hasta el cierre' : 'entregada');
    } else if (f.miEstado == 'enviada') {
      partes.add('enviada');
    }
    return partes.join(' · ');
  }

  (String, Color, Color) _estadoDe(ActEnBandeja f) {
    const u = (EstiloActividades.urgenteFondo, EstiloActividades.urgenteTinta);
    const n = (EstiloActividades.normalFondo, EstiloActividades.normalTinta);
    const h = (EstiloActividades.hechaFondo, EstiloActividades.hechaTinta);

    if (f.pendiente) {
      if (f.miEstado == 'borrador') return ('Empezada', n.$1, n.$2);
      final c = f.cierraAt;
      if (c == null) return ('Abierta', n.$1, n.$2);
      if (esElMismoDia(c, DateTime.now())) return ('Hoy', u.$1, u.$2);
      final dia = fechaDeActividad(c, conHora: false).split(' ').first;
      return (dia[0].toUpperCase() + dia.substring(1), n.$1, n.$2);
    }

    if (f.miNota != null) return ('${f.miNota}', h.$1, h.$2);
    return switch (f.miEstado) {
      'calificada' => ('Calificada', h.$1, h.$2),
      'entregada' => ('Entregada', h.$1, h.$2),
      'tarde' => ('Tarde', u.$1, u.$2),
      'enviada' => ('Lista', h.$1, h.$2),
      _ => ('Cerrada', n.$1, n.$2),
    };
  }
}
