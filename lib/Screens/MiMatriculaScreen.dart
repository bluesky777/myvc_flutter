import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MiMatriculaApi.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/MiRecorridoModel.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/SelectorAcudido.dart';

/// «Mi proceso»: en qué va la matrícula, contado para la familia.
///
/// ## ES LA PANTALLA A LA QUE APUNTA EL AVISO
///
/// El aviso que le llega al acudiente dice **«Laura fue devuelta en Documentos.
/// Abre la app para ver por qué»** y no lleva el motivo dentro, a propósito: una
/// notificación se lee en la pantalla bloqueada de un bus. El motivo lo escribió
/// un docente **para que lo lea la familia**, y se lee aquí.
///
/// Por eso lo devuelto va arriba y con el motivo desplegado, no escondido tras
/// un toque: quien abre esto viene de un aviso que le dijo que algo pasó, y
/// hacerle buscar dónde es cobrarle dos veces el mismo susto.
///
/// ## POR QUÉ NO ES LA MISMA PANTALLA QUE LA DEL PERSONAL, SI ENSEÑA LOS MISMOS PASOS
///
/// «Mi disciplina» sí reutiliza la del personal en sólo lectura, y fue la
/// decisión correcta allí: `disciplina/mis-fichas` devuelve **la misma forma**
/// que la ruta del personal, así que una sola pantalla no puede desincronizarse.
///
/// Aquí el servidor devuelve **otra cosa**, y aposta: `mi-recorrido` no manda la
/// observación interna ni quién cerró cada paso. Reutilizar
/// [RecorridoDeMatriculaScreen] obligaría a pasarle media ficha vacía y a
/// apagarle trozos con condicionales — y el día que alguien añadiera un campo al
/// lado del personal, aparecería aquí sin que nadie lo decidiera. *El invariante
/// se sostiene separando las pantallas, igual que el servidor lo sostiene
/// separando las respuestas.*
///
/// ## Y EL ID HAY QUE MANDARLO SIEMPRE
///
/// A diferencia de «Mis notas» y «Mi disciplina», esta ruta **no acepta venir sin
/// alumno**: un alumno mirando lo suyo manda su propio `personaId`. Ver
/// [traerMiRecorrido].
class MiMatriculaScreen extends StatefulWidget {
  const MiMatriculaScreen({super.key});

  @override
  State<MiMatriculaScreen> createState() => _MiMatriculaScreenState();
}

class _MiMatriculaScreenState extends State<MiMatriculaScreen> {
  final _drawerController = ZoomDrawerController();
  final server = Server();

  bool cargando = true;
  String? error;
  MiRecorrido? recorrido;

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

    // Un alumno manda **su propio id de ficha**, no el de la cuenta. Es lo que
    // pide esta ruta y es lo que la distingue de las otras pantallas de familia.
    await _cargar(AuthService.user.personaId ?? 0);
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

      // Con un solo acudido no se pregunta: preguntar «¿de quién?» cuando solo
      // hay una respuesta es una pantalla de más entre el aviso y el motivo.
      if (muro.acudidos.length == 1) {
        await _cargar(muro.acudidos.single.alumnoId);
        return;
      }

      final elegido = await pedirAcudido(
        context,
        muro.acudidos,
        titulo: '¿De quién quieres ver el proceso?',
      );

      if (!mounted) return;

      if (elegido == null) {
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

  Future<void> _cargar(int alumnoId) async {
    setState(() {
      cargando = true;
      error = null;
      alumnoMostrado = alumnoId;
    });

    try {
      final traido = await traerMiRecorrido(server, alumnoId);
      if (!mounted) return;

      setState(() {
        recorrido = traido;
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

  Future<void> _cambiarAcudido() async {
    if (acudidos.length < 2) return;

    final elegido = await pedirAcudido(
      context,
      acudidos,
      titulo: '¿De quién quieres ver el proceso?',
    );

    if (!mounted || elegido == null || elegido.alumnoId == alumnoMostrado) {
      return;
    }

    await _cargar(elegido.alumnoId);
  }

  void _abrirMenu() => _drawerController.toggle?.call();

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: PaletaEstaciones.fondo,
        appBar: AppBar(
          title: const Text('Mi proceso'),
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
      ),
    );
  }

  Widget _cuerpo() {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return _aviso(Icons.error_outline, error!);
    }

    final traido = recorrido;

    // `null` sin error es el interruptor apagado: la ruta existe en `main` de
    // `8myvc` desde el merge `74d5028` pero **no está desplegada**. Se dice lo
    // que pasa y qué falta, porque quien lo lee es quien puede pedirlo.
    if (traido == null) {
      return _aviso(
        Icons.cloud_off_outlined,
        'Todavía no se puede ver el proceso desde la app.\n\n'
        'La pantalla está lista y espera a que el colegio actualice el '
        'servidor.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(alumnoMostrado ?? 0),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _cabecera(traido),
          const SizedBox(height: 16),
          for (final paso in traido.pasos) ...[
            _tarjeta(paso),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _cabecera(MiRecorrido traido) {
    // Lo devuelto manda sobre lo que falta: son las dos cosas que la familia
    // puede hacer algo por, y devolver es la urgente.
    final devueltos = traido.devueltos.length;

    final (texto, color, icono) = switch ((devueltos, traido.completo)) {
      (> 0, _) => (
          devueltos == 1
              ? 'Hay un paso devuelto. Mira abajo por qué.'
              : 'Hay $devueltos pasos devueltos. Mira abajo por qué.',
          PaletaEstaciones.rojo,
          Icons.assignment_return_outlined,
        ),
      (_, true) => (
          'La matrícula está completa.',
          PaletaEstaciones.verde,
          Icons.check_circle_outline,
        ),
      _ => (
          traido.faltan == 1
              ? 'Falta 1 paso por completar.'
              : 'Faltan ${traido.faltan} pasos por completar.',
          PaletaEstaciones.ambar,
          Icons.pending_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaletaEstaciones.borde),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  traido.alumno.nombreCompleto,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(PasoDeMiRecorrido paso) {
    // **Nunca solo el color.** Cada estado trae palabra e icono, por el sol del
    // patio y por quien no distingue el rojo del verde. Es la misma regla que
    // sujeta una prueba en el lado del personal.
    final (palabra, color, fondo, icono) = paso.devuelto
        ? (
            'Devuelto',
            PaletaEstaciones.rojo,
            PaletaEstaciones.rojoFondo,
            Icons.assignment_return_outlined,
          )
        : paso.cumplido
            ? (
                'Listo',
                PaletaEstaciones.verde,
                PaletaEstaciones.verdeFondo,
                Icons.check_circle_outline,
              )
            : (
                'Pendiente',
                PaletaEstaciones.gris,
                Colors.white,
                Icons.radio_button_unchecked,
              );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: paso.devuelto ? PaletaEstaciones.rojo : PaletaEstaciones.borde,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  paso.requisito,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
              ),
              Text(
                palabra,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),

          // Qué le piden. Sale de `requisitos_matricula.descripcion`, **no** de
          // la observación interna, que en esta ruta no viaja.
          if (paso.descripcion != null && paso.descripcion!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: Text(
                paso.descripcion!,
                style: const TextStyle(
                  fontSize: 14,
                  color: PaletaEstaciones.tintaSuave,
                ),
              ),
            ),

          // **El motivo, desplegado y no escondido.** Es lo único que el colegio
          // le escribe a la familia en todo el recorrido, y sin él «devuelto» es
          // una mala noticia sin instrucciones.
          if (paso.devuelto &&
              paso.motivoDevolucion != null &&
              paso.motivoDevolucion!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 32, top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PaletaEstaciones.rojo, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por qué te lo devolvieron',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PaletaEstaciones.rojoTinta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paso.motivoDevolucion!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: PaletaEstaciones.tinta,
                    ),
                  ),
                ],
              ),
            ),

          // Un paso devuelto SIN motivo escrito no se queda mudo: decir que no
          // se sabe y a dónde ir es más útil que un hueco que parece un fallo
          // de la app.
          if (paso.devuelto &&
              (paso.motivoDevolucion == null ||
                  paso.motivoDevolucion!.trim().isEmpty))
            const Padding(
              padding: EdgeInsets.only(left: 32, top: 8),
              child: Text(
                'No quedó escrito el motivo. Pregunta en la secretaría del '
                'colegio.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: PaletaEstaciones.tintaSuave,
                ),
              ),
            ),

          if (!paso.cumplido && !paso.devuelto && paso.bloquea)
            const Padding(
              padding: EdgeInsets.only(left: 32, top: 6),
              child: Text(
                'Sin este paso no se puede terminar la matrícula.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PaletaEstaciones.ambar,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _aviso(IconData icono, String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 46, color: PaletaEstaciones.tintaApagada),
            const SizedBox(height: 14),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: PaletaEstaciones.tintaSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
