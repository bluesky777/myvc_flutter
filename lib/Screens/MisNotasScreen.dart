import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/NotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/SelectorAcudido.dart';
import 'package:myvc_flutter/constantes.dart';

/// Las notas de un alumno, periodo a periodo.
///
/// Entra aquí el alumno con las suyas y el acudiente con las de uno de sus
/// acudidos, que elige antes en un cuadro. El año es el del usuario —el de la
/// barra del muro—: el backend no lo recibe, lo lee de su ficha.
class MisNotasScreen extends StatefulWidget {
  const MisNotasScreen({super.key});

  @override
  State<MisNotasScreen> createState() => _MisNotasScreenState();
}

class _MisNotasScreenState extends State<MisNotasScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  NotasAlumnoModel? boletin;
  Map<int, String> docentes = {};
  PeriodoNotasModel? periodoMostrado;

  bool cargando = true;
  String? error;
  NotasBloqueadas? bloqueo;

  @override
  void initState() {
    super.initState();
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

  Future<void> _cargar(int alumnoId, int? grupoId) async {
    setState(() {
      cargando = true;
      error = null;
      bloqueo = null;
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
      });
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
          title: Text(boletin?.nombreCompleto ?? 'Notas'),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
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
    final titular = alumno.titularId == null
        ? null
        : docentes[alumno.titularId];

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
                onChanged: (nuevo) =>
                    setState(() => periodoMostrado = nuevo),
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

    return periodo.asignaturas.map(_buildAsignatura).toList();
  }

  Widget _buildAsignatura(AsignaturaNotaModel asignatura) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AvatarPersona(
            nombre: asignatura.docente,
            fotoNombre: asignatura.fotoDocente,
            radio: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asignatura.materia,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  asignatura.docente.isEmpty
                      ? 'Sin docente asignado'
                      : asignatura.docente,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                if (asignatura.desempenio != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    asignatura.desempenio!,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ],
            ),
          ),
          _buildNota(asignatura),
        ],
      ),
    );
  }

  Widget _buildNota(AsignaturaNotaModel asignatura) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          asignatura.notaEscrita,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: asignatura.tieneNota ? kPrimaryColor : Colors.black26,
          ),
        ),
        if (asignatura.recuperada)
          Text('recuperada',
              style: TextStyle(fontSize: 10, color: Colors.black45)),
      ],
    );
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
              esTesoreria ? Icons.account_balance_wallet_outlined : Icons.lock_outline,
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
