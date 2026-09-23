import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/BoletinCompetenciasApi.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/NotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/LineaDeBoletinModel.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/SelectorAcudido.dart';
import 'package:myvc_flutter/Widgets/TarjetaDeAsignatura.dart';
import 'package:myvc_flutter/Screens/DetalleAsignaturaScreen.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';

/// Las notas de un alumno, periodo a periodo.
///
/// Entra aquí el alumno con las suyas y el acudiente con las de uno de sus
/// acudidos, que elige antes en un cuadro. El año es el del usuario —el de la
/// barra del muro—: el backend no lo recibe, lo lee de su ficha.
class MisNotasScreen extends StatefulWidget {
  const MisNotasScreen({super.key, this.aviso});

  /// El aviso que abrió la pantalla, si fue uno: de quién son las notas y,
  /// si hablaba de una sola materia, cuál abrir.
  final AvisoDeNotas? aviso;

  @override
  State<MisNotasScreen> createState() => _MisNotasScreenState();
}

class _MisNotasScreenState extends State<MisNotasScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  NotasAlumnoModel? boletin;
  Map<int, String> docentes = {};
  PeriodoNotasModel? periodoMostrado;

  /// Los acudidos, si quien mira es acudiente.
  ///
  /// Se guardan de la primera carga para poder cambiar de hijo desde la barra:
  /// vinieron todos en la misma respuesta del muro y volver a pedirla solo
  /// para elegir a otro sería pedir dos veces lo mismo.
  List<AcudidoModel> acudidos = const [];
  int? alumnoMostrado;

  bool cargando = true;
  String? error;
  NotasBloqueadas? bloqueo;

  /// Las líneas del boletín por competencias, **por periodo**.
  ///
  /// `notas/alumno` trae los cuatro periodos de una vez y esta pantalla cambia
  /// entre ellos sin volver a preguntar. El boletín por competencias no: es de
  /// **un** periodo. Así que se pide el del periodo que se está mirando y se
  /// guarda aquí — volver a uno ya visto no cuesta nada.
  ///
  /// Sin esto, una familia que repase los cuatro periodos dispararía **cuatro
  /// informes de grupo entero**, que es justo la carga que este proyecto lleva
  /// un año esquivando en un servidor de un núcleo.
  final Map<int, BoletinDeCompetencias> _competenciasPorPeriodo = {};

  /// El periodo cuyas líneas se están pidiendo ahora mismo, si alguno.
  int? _pidiendoCompetencias;

  /// El aviso, hasta que se usa. Se usa **una vez**: cambiar de acudido
  /// después no tiene que volver a abrir la materia del aviso.
  AvisoDeNotas? _aviso;

  @override
  void initState() {
    super.initState();
    _aviso = widget.aviso;
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar());
  }

  /// Quién es el alumno del que se van a ver notas.
  ///
  /// Si quien entra es alumno, él mismo. Si es acudiente, hay que preguntarle
  /// —salvo que tenga un solo acudido, y entonces no hay nada que preguntar—.
  Future<void> _arrancar() async {
    final usuario = AuthService.user;

    if (usuario.esAcudiente) {
      await _porAcudido();
      return;
    }

    final alumnoId = usuario.personaId;
    if (alumnoId == null) {
      setState(() {
        cargando = false;
        error = 'Tu cuenta no tiene una ficha de alumno asociada.';
      });
      return;
    }

    await _cargar(alumnoId, null);
  }

  Future<void> _porAcudido() async {
    try {
      final muro = await traerMuro(server);
      if (!mounted) return;

      if (muro.acudidos.isEmpty) {
        setState(() {
          cargando = false;
          error = 'No hay ningún alumno a tu cargo este año.';
        });
        return;
      }

      setState(() => acudidos = muro.acudidos);

      // Si el aviso dice de quién es, no se pregunta. Solo si es de uno de
      // los suyos: el aviso no decide a quién se le enseñan notas.
      final delAviso = _aviso?.alumnoId;
      if (delAviso != null &&
          muro.acudidos.any((a) => a.alumnoId == delAviso)) {
        await _cargar(delAviso, null);
        return;
      }

      final elegido = await pedirAcudido(
        context,
        muro.acudidos,
        titulo: '¿De quién quieres ver las notas?',
      );

      if (!mounted) return;

      if (elegido == null) {
        // Cerró el cuadro sin elegir: se vuelve por donde vino.
        Navigator.pushNamedAndRemoveUntil(context, '/muro', (_) => false);
        return;
      }

      await _cargar(elegido.alumnoId, null);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = '$err';
      });
    }
  }

  /// Cambia de acudido sin salir de la pantalla.
  ///
  /// Mismo botón y misma hoja que en Asistencia: son la misma pregunta hecha
  /// en dos sitios y no tienen por qué contestarse distinto.
  Future<void> _cambiarAcudido() async {
    if (acudidos.length < 2) return;

    final elegido = await pedirAcudido(
      context,
      acudidos,
      titulo: '¿De quién quieres ver las notas?',
    );

    if (!mounted || elegido == null || elegido.alumnoId == alumnoMostrado) {
      return;
    }

    await _cargar(elegido.alumnoId, null);
  }

  Future<void> _cargar(int alumnoId, int? grupoId) async {
    setState(() {
      cargando = true;
      error = null;
      bloqueo = null;
      alumnoMostrado = alumnoId;
    });

    try {
      final traido =
          await traerNotasDe(server, alumnoId: alumnoId, grupoId: grupoId);
      final mapa = await traerDocentesPorProfesor(server);
      if (!mounted) return;

      setState(() {
        boletin = traido;
        docentes = mapa;
        periodoMostrado = _periodoDeEntrada(traido);
        cargando = false;
        _competenciasPorPeriodo.clear();
      });

      // Y **después**, sin bloquear nada. Ver [_traerCompetencias].
      _traerCompetencias();

      _abrirLaDelAviso(traido);
    } on NotasBloqueadas catch (parado) {
      if (!mounted) return;
      setState(() {
        bloqueo = parado;
        cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        error = '$err';
        cargando = false;
      });
    }
  }

  /// Pide las líneas del periodo que se está mirando, si el año va por
  /// competencias.
  ///
  /// **Se llama DESPUÉS de pintar las notas y a propósito.** La ruta que las
  /// trae es de informe —arma el boletín del grupo entero y filtra después— y
  /// **nadie la ha medido**. Pidiéndola en paralelo y esperando a las dos, una
  /// ruta lenta retrasaría el número que la familia vino a ver; así, si tarda o
  /// si falla, la pantalla se queda exactamente como está hoy.
  ///
  /// **Y sólo se pide si las notas llegaron.** Eso no es orden casual: el
  /// interruptor `alumnos_can_see_notas` —con el que el colegio cierra las notas
  /// mientras cuadra los boletines— **lo comprueba `NotasController::getAlumno`
  /// y sólo él**, así que esta ruta de informe seguiría entregando el boletín
  /// con las notas cerradas. Colgando la petición de que las notas hayan
  /// entrado, la app queda del lado estricto sin tener que saberlo.
  Future<void> _traerCompetencias() async {
    if (!Interruptores.competenciasDocente) return;
    if (!ContextoAcademico.instancia.config.vaPorCompetencias) return;

    final alumno = boletin;
    final periodo = periodoMostrado;
    final grupoId = alumno?.grupoId;

    if (alumno == null || periodo == null || grupoId == null) return;
    if (_competenciasPorPeriodo.containsKey(periodo.id)) return;
    if (_pidiendoCompetencias == periodo.id) return;

    setState(() => _pidiendoCompetencias = periodo.id);

    try {
      final traido = await traerBoletinPorCompetencias(
        server,
        grupoId: grupoId,
        alumnoId: alumno.alumnoId,
        periodoId: periodo.id,
      );

      if (!mounted) return;
      setState(() {
        _competenciasPorPeriodo[periodo.id] = traido;
        _pidiendoCompetencias = null;
      });
    } catch (_) {
      // **Se traga el fallo a propósito, y es la única vez que esta app lo
      // hace.** Lo que cuelga de aquí es un añadido: si no llega, la tarjeta es
      // la de siempre. Enseñar «no se pudieron traer las competencias» encima
      // de unas notas que sí llegaron le daría a la familia un error por algo
      // que no vino a buscar.
      if (!mounted) return;
      setState(() => _pidiendoCompetencias = null);
    }
  }

  /// Las líneas de una asignatura en el periodo que se está mirando.
  List<LineaDeBoletin> _lineasDe(int asignaturaId) {
    final periodo = periodoMostrado;
    if (periodo == null) return const [];

    final boletinDelPeriodo = _competenciasPorPeriodo[periodo.id];
    if (boletinDelPeriodo == null) return const [];

    for (final asignatura in boletinDelPeriodo.asignaturas) {
      if (asignatura.asignaturaId == asignaturaId) return asignatura.lineas;
    }

    return const [];
  }

  /// El periodo con el que se abre: el que el usuario tiene elegido arriba.
  PeriodoNotasModel? _periodoDeEntrada(NotasAlumnoModel traido) {
    if (traido.periodos.isEmpty) return null;

    final suyo = ContextoAcademico.instancia.periodoId;
    return traido.periodos.firstWhere(
      (p) => p.id == suyo,
      orElse: () => traido.periodos.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          // El nombre del alumno debajo y no como título: para un acudiente
          // con un solo hijo, «Ana Acosta» era el título tanto aquí como en la
          // asistencia, y las dos pantallas se veían iguales desde arriba.
          title: TituloPantalla(
            titulo: 'Mis notas',
            subtitulo: boletin?.nombreCompleto,
          ),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
          actions: [
            // Solo con más de un acudido: con uno solo no hay entre qué
            // elegir y el botón sobraría.
            if (acudidos.length > 1)
              IconButton(
                icon: const Icon(Icons.switch_account_outlined),
                tooltip: 'Cambiar de acudido',
                onPressed: _cambiarAcudido,
              ),
          ],
        ),
        body: _buildCuerpo(),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando) return Center(child: CircularProgressIndicator());
    if (bloqueo != null) return _buildBloqueo(bloqueo!);
    if (error != null) return _buildError(error!);
    if (boletin == null) return SizedBox();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildCabeceraGrupo(),
        _buildSelectorPeriodo(),
        ..._buildAsignaturas(),
      ],
    );
  }

  /// Dónde está el alumno: su grupo y quién lo dirige.
  Widget _buildCabeceraGrupo() {
    final alumno = boletin!;
    final titular =
        alumno.titularId == null ? null : docentes[alumno.titularId];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          AvatarPersona(
            nombre: alumno.nombreCompleto,
            fotoNombre: alumno.fotoNombre,
            radio: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumno.grupo ?? 'Sin grupo',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  titular == null
                      ? 'Sin titular asignado'
                      : 'Titular: $titular',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// El periodo, arriba y con el año al lado.
  ///
  /// El año no se elige aquí: es el del usuario, y se cambia desde la barra del
  /// muro. Ponerlo también aquí serían dos sitios para lo mismo y dos formas de
  /// que discrepen.
  Widget _buildSelectorPeriodo() {
    final periodos = boletin!.periodos;
    final year = ContextoAcademico.instancia.year;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PeriodoNotasModel>(
                value: periodoMostrado,
                isExpanded: true,
                items: periodos
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            'Periodo ${p.numero}',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
                onChanged: (nuevo) {
                  setState(() => periodoMostrado = nuevo);
                  // Las notas de los cuatro periodos ya están en memoria; las
                  // competencias son de UN periodo, así que cambiar arriba
                  // pide las del nuevo. Si ya se vieron, no cuesta nada.
                  _traerCompetencias();
                },
              ),
            ),
          ),
          if (year != null)
            Text(
              year,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAsignaturas() {
    final periodo = periodoMostrado;

    if (periodo == null || periodo.asignaturas.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No hay asignaturas en este periodo.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      ];
    }

    return periodo.asignaturas.map(_tarjetaDe).toList();
  }

  Widget _tarjetaDe(AsignaturaNotaModel asignatura) {
    return TarjetaDeAsignatura(
      asignatura: asignatura,
      lineas: _lineasDe(asignatura.asignaturaId),
      alTocar: () => _abrirDetalle(asignatura),
    );
  }

  /// Si el aviso hablaba de una materia, se abre su desglose directamente.
  ///
  /// Se busca primero en el periodo que se enseña y luego en los demás, del
  /// último al primero. Si no está en ninguno se queda la lista: es mejor
  /// que abrir otra.
  void _abrirLaDelAviso(NotasAlumnoModel traido) {
    final aviso = _aviso;
    _aviso = null;
    if (aviso == null || aviso.asignatura == null) return;

    final orden = [
      if (periodoMostrado != null) periodoMostrado!,
      ...traido.periodos.reversed.where((p) => p != periodoMostrado),
    ];

    for (final periodo in orden) {
      for (final asignatura in periodo.asignaturas) {
        if (aviso.esDe(materia: asignatura.materia, alias: asignatura.alias)) {
          if (periodo != periodoMostrado) {
            setState(() => periodoMostrado = periodo);
          }
          _abrirDetalle(asignatura);
          return;
        }
      }
    }
  }

  /// De qué notas sale esa definitiva.
  ///
  /// El dato ya está en memoria —vino con el resto en `notas/alumno`— así que
  /// abrirlo no cuesta ni una petición al colegio, que es lo que permite que
  /// sea un toque y no una pantalla que carga.
  void _abrirDetalle(AsignaturaNotaModel asignatura) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetalleAsignaturaScreen(
        args: DetalleAsignaturaArgs(
          asignatura: asignatura,
          alumno: boletin?.nombreCompleto ?? '',
          numeroPeriodo: periodoMostrado?.numero,
        ),
      ),
    ));
  }

  /// Los dos bloqueos, cada uno con lo suyo.
  Widget _buildBloqueo(NotasBloqueadas parado) {
    final esTesoreria = parado.motivo == MotivoBloqueo.tesoreria;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              esTesoreria
                  ? Icons.account_balance_wallet_outlined
                  : Icons.lock_outline,
              size: 52,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              esTesoreria ? 'Notas bloqueadas' : 'Sistema bloqueado',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              esTesoreria
                  ? 'No estás a paz y salvo en tesorería, y por eso las notas'
                      ' no se pueden ver. Esto se arregla en el colegio, no'
                      ' aquí.'
                  : parado.mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String detalle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudieron traer las notas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _arrancar, child: Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
