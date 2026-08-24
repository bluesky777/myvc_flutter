import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Screens/LibroAsignaturaScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FiltroAsignaturas.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';
import 'package:myvc_flutter/Widgets/SelectorDocente.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';

/// Por dónde se entra a poner notas: las asignaturas del docente.
///
/// Arranca enseñando **las de hoy**. El colegio puede configurar, asignatura
/// por asignatura, qué días se dicta, y cuando lo hace, de doce asignaturas hoy
/// tocan tres; enseñar las doce al entrar entre clase y clase es hacerle buscar
/// la suya entre nueve que no le sirven. El filtro se recuerda por usuario, así
/// que quien prefiera verlas todas lo cambia una vez.
///
/// El horario de hoy no cuesta ninguna petición: viene dentro de la respuesta
/// del muro y se guarda al leerlo. Ver [HorarioDeHoy].
class NotasScreen extends StatefulWidget {
  const NotasScreen({super.key});

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  bool get esDocente => AuthService.user.esDocente;

  /// Solo para quien no es docente: de qué docente son las asignaturas.
  List<DocenteModel> docentes = [];
  DocenteModel? docenteElegido;

  List<AsignaturaConUnidades> asignaturas = [];

  FiltroAsignaturas filtro = FiltroAsignaturas.hoy;

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
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
      asignaturas = [];
    });

    filtro = await PreferenciaFiltroAsignaturas.leer();

    try {
      if (esDocente) {
        asignaturas = await traerAsignaturasConUnidades(server);
      } else {
        docentes = await traerDocentesDelColegio(server);
        if (docenteElegido != null) {
          asignaturas = await traerAsignaturasConUnidades(
            server,
            profesorId: docenteElegido!.profesorId,
          );
        }
      }
    } catch (err) {
      error = 'No se pudieron traer las asignaturas: $err';
    }

    setState(() => cargando = false);
  }

  /// Si tiene sentido ofrecer el filtro de hoy.
  ///
  /// Tres casos en que no:
  ///
  ///  - El colegio pidió ignorar el horario (`show_materias_todas`). Ahí ha
  ///    dicho explícitamente que quiere verlas todas, y un filtro que no filtra
  ///    nada solo desconcierta.
  ///  - El muro no se ha leído todavía, así que no se sabe qué toca hoy. No
  ///    saberlo no es lo mismo que no haber clases.
  ///  - Quien mira no es el docente, sino un administrativo viendo las
  ///    asignaturas de otro: el horario que se guardó es el de quien tiene la
  ///    sesión abierta, no el del docente elegido.
  bool get _cabeFiltrar {
    if (ContextoAcademico.instancia.config.mostrarTodasLasMaterias) return false;
    if (!HorarioDeHoy.instancia.seSabe) return false;
    return esDocente;
  }

  /// Hoy no hay clases, y hay que decirlo en vez de enseñar una lista vacía.
  bool get _hoyNoHayClases =>
      _cabeFiltrar && HorarioDeHoy.instancia.asignaturaIds.isEmpty;

  /// Las que se pintan, según el filtro.
  ///
  /// Se filtra el listado completo por los ids de hoy y no se usan directamente
  /// las asignaturas del horario, aunque también vengan con sus unidades: el
  /// listado trae además cuántas notas lleva puesta cada subunidad, que es lo
  /// que permite decir «faltan notas» sin pedir nada más.
  List<AsignaturaConUnidades> get _visibles {
    if (filtro == FiltroAsignaturas.todas) return asignaturas;
    if (!_cabeFiltrar || _hoyNoHayClases) return asignaturas;

    final hoy = HorarioDeHoy.instancia.asignaturaIds;
    return asignaturas.where((a) => hoy.contains(a.asignatura.id)).toList();
  }

  Future<void> _cambiarFiltro(FiltroAsignaturas nuevo) async {
    setState(() => filtro = nuevo);
    await PreferenciaFiltroAsignaturas.guardar(nuevo);
  }

  Future<void> _cambiarDocente(DocenteModel elegido) async {
    setState(() {
      docenteElegido = elegido;
      cargando = true;
      error = null;
    });

    try {
      asignaturas = await traerAsignaturasConUnidades(
        server,
        profesorId: elegido.profesorId,
      );
    } catch (err) {
      error = 'No se pudieron traer sus asignaturas: $err';
    }

    setState(() => cargando = false);
  }

  void _abrir(AsignaturaConUnidades fila) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'libro-asignatura'),
        builder: (_) => LibroAsignaturaScreen(
          asignatura: fila.asignatura,
          profesorId: esDocente ? null : docenteElegido?.profesorId,
        ),
      ),
    );
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
        // Las notas son del periodo de la barra de arriba, igual que las
        // unidades: cambiarlo ahí cambia lo que se ve y lo que se guarda.
        body: BarraPlegable(
          titulo: 'Notas',
          alAbrirMenu: () => _drawerController.toggle!(),
          alCambiarContexto: _arrancar,
          child: _buildCuerpo(),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando && asignaturas.isEmpty && docentes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ContextoAcademico.instancia.periodoId == null) {
      return _buildMensaje(
        'No hay un periodo elegido, y las notas son de un periodo.'
        ' Elige uno en la barra de arriba.',
      );
    }

    final visibles = _visibles;

    return RefreshIndicator(
      onRefresh: Analitica.refresco('notas', _arrancar),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // El selector va fuera del bloque de carga: es desde donde se cambia
          // de docente, y si desapareciera mientras carga no quedaría forma de
          // elegir otro.
          if (!esDocente) _buildSelectorDocente(),
          if (_cabeFiltrar) _buildFiltro(),
          if (cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _buildMensaje(error!, conReintento: true)
          else if (asignaturas.isEmpty)
            _buildMensaje(
              esDocente
                  ? 'No tienes asignaturas en este año.'
                  : 'Elige un docente para ver sus notas.',
            )
          else
            ...visibles.map(_buildAsignatura),
        ],
      ),
    );
  }

  Widget _buildSelectorDocente() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CampoDocente(
        docentes: docentes,
        elegido: docenteElegido,
        titulo: 'Docentes del colegio',
        alElegir: _cambiarDocente,
      ),
    );
  }

  Widget _buildFiltro() {
    final deHoy = HorarioDeHoy.instancia.asignaturaIds.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _chip(
            texto: _hoyNoHayClases ? 'Hoy (ninguna)' : 'Hoy ($deHoy)',
            activo: filtro == FiltroAsignaturas.hoy,
            alTocar: () => _cambiarFiltro(FiltroAsignaturas.hoy),
          ),
          const SizedBox(width: 8),
          _chip(
            texto: 'Todas (${asignaturas.length})',
            activo: filtro == FiltroAsignaturas.todas,
            alTocar: () => _cambiarFiltro(FiltroAsignaturas.todas),
          ),
          const Spacer(),
          // Una lista vacía sin explicación parece la app rota. Es domingo, o
          // el colegio no configuró los días de esta asignatura.
          if (_hoyNoHayClases && filtro == FiltroAsignaturas.hoy)
            const Flexible(
              child: Text(
                'Hoy no tienes clases;\nse muestran todas.',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String texto,
    required bool activo,
    required VoidCallback alTocar,
  }) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? kPrimaryColor : const Color(0xFFEDEDF3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? Colors.white : Colors.black87,
            fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAsignatura(AsignaturaConUnidades fila) {
    final config = ContextoAcademico.instancia.config;
    final asignatura = fila.asignatura;

    final cuantasSubunidades =
        fila.unidades.fold<int>(0, (acc, u) => acc + u.subunidades.length);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _abrir(fila),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            asignatura.abrevGrupo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
        ),
        title: Text(
          asignatura.materia,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          cuantasSubunidades == 0
              ? 'Sin ${config.subunidades.toLowerCase()} en este periodo'
              : '${asignatura.nombreGrupo} · $cuantasSubunidades'
                  ' ${config.subunidades.toLowerCase()}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: fila.faltanNotas
            ? const Icon(Icons.circle, size: 10, color: Colors.orange)
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildMensaje(String texto, {bool conReintento = false}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(texto, textAlign: TextAlign.center),
          if (conReintento) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: _arrancar, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}
