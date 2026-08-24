import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Screens/FichaDisciplinaScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/SelectorAcudido.dart';

/// La ficha de disciplina propia: la del alumno, o la de uno de los acudidos.
///
/// **Es la misma pantalla que usa el personal, en modo lectura.** No se escribió
/// una nueva a propósito: `disciplina/mis-fichas` devuelve el alumno con la
/// misma forma que un elemento de `PUT disciplina/alumnos`, y ese fue el motivo
/// de pedirlo así. Una pantalla distinta para enseñar exactamente lo mismo son
/// dos sitios donde arreglar el mismo fallo.
///
/// Lo que aporta este envoltorio es lo que la ficha no sabe hacer: **resolver de
/// quién es**. Un alumno es él mismo y el backend lo deduce del token; un
/// acudiente tiene que elegir, porque sin id el servidor le responde 400 —no
/// sabe de cuál de sus acudidos hablarle—. Es la misma pregunta que ya hacen
/// «Mis notas» y «Asistencia», con la misma hoja.
class MiDisciplinaScreen extends StatefulWidget {
  const MiDisciplinaScreen({super.key});

  @override
  State<MiDisciplinaScreen> createState() => _MiDisciplinaScreenState();
}

class _MiDisciplinaScreenState extends State<MiDisciplinaScreen> {
  final _drawerController = ZoomDrawerController();
  final server = Server();

  bool cargando = true;
  String? error;
  MiFichaDisciplina? ficha;

  /// Los acudidos, si quien mira es acudiente. Para poder cambiar sin salir.
  List<AcudidoModel> acudidos = const [];
  int? alumnoMostrado;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    if (AuthService.user.esAcudiente) {
      await _porAcudido();
      return;
    }

    // Un alumno no manda id: el backend lo saca de su token. Mandarlo sería
    // pedirle a la app que sepa algo que el servidor ya sabe, y equivocarse.
    await _cargar(null);
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

      final elegido = await pedirAcudido(
        context,
        muro.acudidos,
        titulo: '¿De quién quieres ver la ficha?',
      );

      if (!mounted) return;

      if (elegido == null) {
        // Cerró la hoja sin elegir: se vuelve por donde vino, igual que en
        // «Mis notas». Quedarse en una pantalla vacía sería peor.
        Navigator.pushNamedAndRemoveUntil(context, '/muro', (_) => false);
        return;
      }

      await _cargar(elegido.alumnoId);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = '$err';
      });
    }
  }

  Future<void> _cargar(int? alumnoId) async {
    setState(() {
      cargando = true;
      error = null;
      alumnoMostrado = alumnoId;
    });

    try {
      final traida = await traerMisFichas(server, alumnoId: alumnoId);
      if (!mounted) return;

      setState(() {
        ficha = traida;
        cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = '$err';
      });
    }
  }

  /// Cambia de acudido sin salir de la pantalla.
  Future<void> _cambiarAcudido() async {
    if (acudidos.length < 2) return;

    final elegido = await pedirAcudido(
      context,
      acudidos,
      titulo: '¿De quién quieres ver la ficha?',
    );

    if (!mounted || elegido == null || elegido.alumnoId == alumnoMostrado) {
      return;
    }

    await _cargar(elegido.alumnoId);
  }

  void _abrirMenu() => _drawerController.toggle?.call();

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
      mainScreen: _pantalla(),
    );
  }

  Widget _pantalla() {
    final traida = ficha;

    if (traida != null && !cargando) {
      return FichaDisciplinaScreen(
        args: FichaDisciplinaArgs(
          alumno: traida.alumno,
          datos: traida.datos,
          soloLectura: true,
          alAbrirMenu: _abrirMenu,
          // Sólo lo usa «ver las faltas a la institución», y en modo lectura
          // ese camino está apagado porque `ausencias/*` responde 403 a un
          // alumno. Cero es honesto: aquí no se sabe ni hace falta.
          grupoId: 0,
          periodoInicial: ContextoAcademico.instancia.numeroPeriodo ?? 1,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Disciplina'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _abrirMenu,
        ),
        actions: [
          if (acudidos.length > 1)
            IconButton(
              icon: const Icon(Icons.switch_account_outlined),
              tooltip: 'Cambiar de acudido',
              onPressed: _cambiarAcudido,
            ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _cargar(alumnoMostrado),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return const Center(child: Text('No hay ficha que enseñar.'));
  }
}
