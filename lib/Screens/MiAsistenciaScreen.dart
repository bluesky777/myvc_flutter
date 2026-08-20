import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/NotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AsistenciaPeriodoModel.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/SelectorAcudido.dart';
import 'package:myvc_flutter/constantes.dart';

/// Las faltas de un alumno en el año, periodo a periodo.
///
/// Separadas en las dos cosas que son: lo que se falta frente a la institución
/// —llegar tarde al colegio o no venir en todo el día— y lo que se falta a
/// clase. Un alumno puede tener el colegio impecable y faltar a media
/// asignatura, y juntarlo en un número escondería justo eso.
///
/// De dónde salen los datos, que tiene su porqué: todas las rutas de ausencias
/// están cerradas para alumnos y acudientes por el middleware ExigirPersonal
/// —decisión del 18 de agosto de 2026—, así que no se pueden pedir. Lo único
/// que sí llega es lo que ChangesAsked/to-me mete en la respuesta del panel:
/// `ausencias_periodo` para el alumno, y dentro de cada acudido para el
/// acudiente. Son cuentas por periodo, no las filas.
///
/// Con qué día y en qué materia faltó es otra cosa y viene de otro sitio: del
/// boletín, que sí trae las filas de cada asignatura. Se pide después y aparte
/// porque el boletín SÍ se bloquea —cuando el colegio apaga las notas o cuando
/// la familia debe en tesorería— y las cuentas de arriba no dependen de eso:
/// retener un boletín es una cosa y esconder que el niño no fue a clase es
/// otra. Si no llega, se dice y lo demás se queda.
class MiAsistenciaScreen extends StatefulWidget {
  const MiAsistenciaScreen({super.key});

  @override
  State<MiAsistenciaScreen> createState() => _MiAsistenciaScreenState();
}

class _MiAsistenciaScreenState extends State<MiAsistenciaScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  List<AsistenciaPeriodoModel> periodos = const [];
  String? deQuien;
  bool cargando = true;
  String? error;

  /// Lo que trajo el panel, entero.
  ///
  /// Ahí vienen ya las faltas de todos los acudidos, así que cambiar de hijo
  /// es mirar otra parte de lo que se tiene y no volver a pedir nada.
  MuroCargado? muro;

  /// De quién es lo que se está viendo. Hace falta para pedir su boletín.
  int? alumnoId;

  /// El detalle por materia. Null mientras se trae o si no se pudo.
  NotasAlumnoModel? boletin;
  String? avisoDetalle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
      boletin = null;
      avisoDetalle = null;
    });

    try {
      final traido = await traerMuro(server);
      if (!mounted) return;

      setState(() => muro = traido);

      if (AuthService.user.esAcudiente) {
        await _deUnAcudido(traido);
        return;
      }

      setState(() {
        periodos = traido.asistenciaPropia;
        deQuien = AuthService.user.nombreVisible;
        alumnoId = AuthService.user.personaId;
        cargando = false;
      });

      await _cargarDetalle();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        error = '$err';
        cargando = false;
      });
    }
  }

  Future<void> _deUnAcudido(MuroCargado muro) async {
    if (muro.acudidos.isEmpty) {
      setState(() {
        cargando = false;
        error = 'No hay ningún alumno a tu cargo este año.';
      });
      return;
    }

    final elegido = await pedirAcudido(
      context,
      muro.acudidos,
      titulo: '¿De quién quieres ver la asistencia?',
    );

    if (!mounted) return;

    if (elegido == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/muro', (_) => false);
      return;
    }

    await _ponerAcudido(elegido);
  }

  /// Deja la pantalla mirando a un acudido, y pide su detalle.
  Future<void> _ponerAcudido(AcudidoModel elegido) async {
    setState(() {
      periodos = elegido.asistencia;
      deQuien = elegido.nombreCompleto;
      alumnoId = elegido.alumnoId;
      boletin = null;
      avisoDetalle = null;
      cargando = false;
    });

    await _cargarDetalle();
  }

  /// Cambia de acudido sin salir de la pantalla ni volver a pedir el resumen.
  ///
  /// Un acudiente con tres hijos tenía que volver al menú y entrar otra vez
  /// para ver al segundo. Las faltas de los tres vinieron en la misma
  /// respuesta, así que esto es inmediato; lo único que se vuelve a pedir es
  /// el boletín, que sí es de un alumno concreto.
  Future<void> _cambiarAcudido() async {
    final acudidos = muro?.acudidos ?? const <AcudidoModel>[];
    if (acudidos.length < 2) return;

    final elegido = await pedirAcudido(
      context,
      acudidos,
      titulo: '¿De quién quieres ver la asistencia?',
    );

    if (!mounted || elegido == null || elegido.alumnoId == alumnoId) return;

    await _ponerAcudido(elegido);
  }

  /// El detalle por materia, que va aparte porque puede no llegar.
  ///
  /// Un bloqueo del boletín no es un error de esta pantalla: los contadores ya
  /// están pintados y siguen valiendo. Se dice qué falta y por qué, en vez de
  /// tapar todo con un aviso rojo.
  Future<void> _cargarDetalle() async {
    final id = alumnoId;
    if (id == null) return;

    try {
      final traido = await traerNotasDe(server, alumnoId: id);
      if (!mounted || id != alumnoId) return;

      setState(() => boletin = traido);
    } on NotasBloqueadas catch (parado) {
      if (!mounted || id != alumnoId) return;

      setState(() {
        avisoDetalle = parado.motivo == MotivoBloqueo.tesoreria
            ? 'En qué materias faltó va con el boletín, y el boletín está'
                ' retenido por tesorería. Las cuentas de arriba no dependen de'
                ' eso.'
            : 'En qué materias faltó va con el boletín, y el colegio lo tiene'
                ' cerrado ahora mismo. Las cuentas de arriba no dependen de'
                ' eso.';
      });
    } catch (err) {
      if (!mounted || id != alumnoId) return;

      setState(() => avisoDetalle = 'No se pudo traer el detalle por'
          ' materia: $err');
    }
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
          title: Text(deQuien ?? 'Asistencia'),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
          actions: [
            // Solo con más de un acudido: con uno solo no hay entre qué
            // elegir y el botón sobraría.
            if ((muro?.acudidos.length ?? 0) > 1)
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

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No se pudo traer la asistencia.',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _cargar, child: Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (periodos.isEmpty) {
      return Center(
        child: Text('No hay periodos en este año.',
            style: TextStyle(color: Colors.black54)),
      );
    }

    final year = ContextoAcademico.instancia.year;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (year != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Año $year',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ..._buildResumen(),
          ...periodos.map(_buildPeriodo),
          if (avisoDetalle != null) _buildAviso(avisoDetalle!),
        ],
      ),
    );
  }

  /// El año entero de un vistazo, antes de bajar periodo a periodo.
  List<Widget> _buildResumen() {
    final institucion = periodos.fold<int>(0, (a, p) => a + p.totalInstitucion);
    final clases = periodos.fold<int>(0, (a, p) => a + p.totalClases);

    if (institucion == 0 && clases == 0) {
      return [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Text('Sin faltas en todo el año.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _cuentaGrande('Frente al colegio', institucion),
            ),
            Container(width: 1, height: 40, color: Colors.black12),
            Expanded(child: _cuentaGrande('A clases', clases)),
          ],
        ),
      ),
    ];
  }

  Widget _cuentaGrande(String rotulo, int cuanto) {
    return Column(
      children: [
        Text('$cuanto',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cuanto == 0 ? Colors.black26 : kPrimaryColor)),
        Text(rotulo,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildPeriodo(AsistenciaPeriodoModel periodo) {
    final esElSuyo = periodo.id == ContextoAcademico.instancia.periodoId;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esElSuyo
              ? kPrimaryColor.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Periodo ${periodo.numero}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              if (esElSuyo) ...[
                const SizedBox(width: 8),
                Text('en curso',
                    style: TextStyle(fontSize: 11, color: kPrimaryColor)),
              ],
            ],
          ),
          if (periodo.sinNada) ...[
            const SizedBox(height: 10),
            const Text('Sin faltas.',
                style: TextStyle(color: Colors.black45, fontSize: 13)),
          ] else ...[
            const SizedBox(height: 12),
            _bloque(
              'Frente a la institución',
              'Llegó tarde al colegio o no vino',
              tardanzas: periodo.tardanzasInstitucion,
              ausencias: periodo.ausenciasInstitucion,
            ),
            const SizedBox(height: 12),
            _bloque(
              'A clases',
              'Por asignatura, dentro de la jornada',
              tardanzas: periodo.tardanzasClases,
              ausencias: periodo.ausenciasClases,
            ),
            ..._buildPorMateria(periodo),
          ],
        ],
      ),
    );
  }

  Widget _bloque(
    String titulo,
    String explicacion, {
    required int tardanzas,
    required int ausencias,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        Text(explicacion,
            style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
        const SizedBox(height: 8),
        Row(
          children: [
            _pastilla('Tardanzas', tardanzas, kColorTardanza),
            const SizedBox(width: 8),
            _pastilla('Ausencias', ausencias, kColorAusencia),
          ],
        ),
      ],
    );
  }

  /// En qué materias faltó, con el día de cada falta.
  ///
  /// Solo las materias en las que hay algo: en un periodo de doce asignaturas
  /// y dos faltas, listar las doce esconde justo lo que se busca. Y solo sale
  /// si el boletín llegó; si no, abajo se dice por qué.
  List<Widget> _buildPorMateria(AsistenciaPeriodoModel periodo) {
    final delPeriodo =
        boletin?.periodos.where((p) => p.id == periodo.id).toList() ?? const [];

    if (delPeriodo.isEmpty) return const [];

    final conFaltas =
        delPeriodo.first.asignaturas.where((a) => a.tieneFaltas).toList();
    if (conFaltas.isEmpty) return const [];

    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1),
      ),
      const Text('En qué materias',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ...conFaltas.map(_buildMateria),
    ];
  }

  Widget _buildMateria(AsignaturaNotaModel asignatura) {
    final dias = [
      ..._dias(asignatura, TipoFalta.tardanza),
      ..._dias(asignatura, TipoFalta.ausencia),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(asignatura.materia,
                    style: const TextStyle(fontSize: 13.5)),
              ),
              if (asignatura.totalTardanzas > 0)
                _pastillaChica(
                  TipoFalta.tardanza.contar(asignatura.totalTardanzas),
                  kColorTardanza,
                ),
              if (asignatura.totalAusencias > 0) ...[
                const SizedBox(width: 6),
                _pastillaChica(
                  TipoFalta.ausencia.contar(asignatura.totalAusencias),
                  kColorAusencia,
                ),
              ],
            ],
          ),
          if (dias.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                dias.join(' · '),
                style: const TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
            ),
          if (asignatura.faltasSinDia > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                asignatura.faltasSinDia == 1
                    ? 'y una sin día registrado'
                    : 'y ${asignatura.faltasSinDia} sin día registrado',
                style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black38,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  /// Los días de las faltas de un tipo, como se leen en una línea.
  ///
  /// Solo las que traen día. Las que no —una de cada nueve en la base del
  /// colegio— se quedan fuera de esta línea y se dicen aparte, contadas: el
  /// número de arriba sí las incluye, y sin explicar por qué no aparecen
  /// abajo parecería que falta información.
  List<String> _dias(AsignaturaNotaModel asignatura, TipoFalta tipo) {
    return asignatura
        .faltasConDiaDe(tipo)
        .map((f) => '${tipo.singular} el ${formatoDia(f.fecha)}')
        .toList();
  }

  Widget _pastillaChica(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAviso(String texto) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                  fontSize: 12.5, color: Colors.black87, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastilla(String rotulo, int cuanto, Color color) {
    final hay = cuanto > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hay ? color.withValues(alpha: 0.13) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$cuanto',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: hay ? color : Colors.black38,
              )),
          const SizedBox(width: 6),
          Text(rotulo,
              style: TextStyle(
                  fontSize: 12.5,
                  color: hay ? Colors.black87 : Colors.black38)),
        ],
      ),
    );
  }
}
