import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/MuroApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Screens/TarjetonScreen.dart';
import 'package:myvc_flutter/Utils/HorarioDeHoy.dart';
import 'package:myvc_flutter/Utils/VotacionPendiente.dart';
import 'package:myvc_flutter/Widgets/HojaHoySeVota.dart';
import 'package:myvc_flutter/Widgets/TarjetaDeVotacion.dart';
import 'package:myvc_flutter/Widgets/Publicacion.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Widgets/OfrecerAvisos.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// Lo primero que se ve al entrar: el muro del colegio.
///
/// Es la misma pared para todos —docentes, alumnos y acudientes—, y se recorre
/// hacia abajo como cualquier muro. Lo que cambia según quién mira es el menú
/// lateral, no esto.
class MuroScreen extends StatefulWidget {
  const MuroScreen({super.key});

  @override
  State<MuroScreen> createState() => _MuroScreenState();
}

class _MuroScreenState extends State<MuroScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  MuroCargado? muro;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Las siglas del colegio pueden llegar después —`/years` no se pide hasta
    // que alguien abre el selector de periodo—, y entonces el título tiene que
    // cambiar solo. Sin esto la barra se quedaría con las iniciales calculadas
    // hasta la siguiente vez que esta pantalla se reconstruyera por otra cosa.
    ContextoAcademico.instancia.addListener(_alCambiarElContexto);
  }

  @override
  void dispose() {
    ContextoAcademico.instancia.removeListener(_alCambiarElContexto);
    super.dispose();
  }

  void _alCambiarElContexto() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    setState(() {
      error = null;
      muro = null;
    });

    try {
      // Siempre fresco, nunca de la caché. Es la pantalla que enseña las
      // publicaciones, y quien entra al muro —o desliza para recargar— viene
      // justamente a ver si hay algo nuevo. Que las otras tres pantallas se
      // sirvan de lo guardado depende de que ésta lo llene de verdad. Ver
      // MuroEnMemoria.
      final traido = await traerMuro(server, refrescar: true);
      if (!mounted) return;
      setState(() => muro = traido);

      // Y una sola vez en la vida de este teléfono, la oferta de los avisos.
      // Aquí y no al abrir la app: con el muro ya pintado delante se entiende
      // de qué colegio y de quién va lo que se está ofreciendo, y Android solo
      // deja preguntar una vez. Ver OfrecerAvisos.
      if (mounted) await OfrecerAvisos.siToca(context, server);

      // Y si hoy hay elección abierta y le falta votar, el aviso. Va después de
      // los avisos y no antes porque los dos son hojas encima del muro y dos a la
      // vez no se pueden leer; y va aquí, con el muro pintado detrás, por lo
      // mismo que aquél. El dato no cuesta ninguna petición: viene del login.
      // Ver HojaHoySeVota y VotacionPendiente.
      if (mounted) await HojaHoySeVota.siToca(context, server);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  /// Las siglas del colegio, que es lo que va donde antes decía «Inicio».
  ///
  /// «Inicio» no decía nada que la pantalla no dijera ya —es la primera, se
  /// llega sola— y ahora comparte fila con el periodo, así que ese sitio vale.
  ///
  /// **Las siglas son las del colegio o no hay siglas.** Se intentó calcularlas
  /// del nombre cuando no llegaban, y salió mal: el único nombre que la app
  /// tiene antes de entrar viene de `listado_colegios.php`, y esa lista no
  /// guarda nombres de colegio sino sitios —«Libertad Tame», «Arauca»,
  /// «Fortul»—, así que el Liceo Adventista Libertad salía `LT`. **Una sigla
  /// equivocada es peor que ninguna**: se lee como un dato y no como un hueco,
  /// y nadie la reporta porque parece una decisión. Así que mientras no lleguen
  /// las de verdad, «Inicio», que al menos es cierto.
  String _siglas() {
    final abrev = ContextoAcademico.instancia.abrevColegio;

    return abrev.isEmpty ? 'Inicio' : abrev;
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        // Un gris muy claro detrás: es lo que hace que cada publicación se lea
        // como una tarjeta y no como un trozo suelto de la pantalla.
        backgroundColor: const Color(0xFFF4F5F7),
        // El nombre de la pantalla arriba y el periodo en su propia franja
        // debajo. Antes iba solo el periodo, con el argumento de que el muro se
        // reconoce solo; pero las unidades y la disciplina llevaban ese mismo
        // título, así que las tres barras decían lo mismo y ninguna decía dónde
        // estabas. «Inicio» y no «Muro», que es como lo llama el menú.
        body: BarraPlegable(
          titulo: _siglas(),
          // El logo solo aquí: es la pantalla cuyo título son las siglas del
          // colegio, y las dos cosas se leen juntas. Ver BarraPlegable.conLogo.
          conLogo: true,
          alAbrirMenu: () => _drawerController.toggle!(),
          alCambiarContexto: _cargar,
          child: _buildCuerpo(),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudieron traer las publicaciones.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargar,
                child: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (muro == null) {
      return Center(child: CircularProgressIndicator());
    }

    final publicaciones = muro!.publicaciones;

    // Lo que va por encima de las publicaciones, en orden. La votación primero:
    // es de un día y el acceso a notas es de todo el año.
    final laVotacion = TarjetaDeVotacion.siToca(alVotar: _abrirElTarjeton);
    final acceso = _buildAccesoANotas();

    final encabezados = <Widget>[
      if (laVotacion != null) laVotacion,
      if (acceso != null) acceso,
    ];

    return RefreshIndicator(
      onRefresh: Analitica.refresco('muro', _cargar),
      child: publicaciones.isEmpty
          ? _muroVacio(encabezados)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // Los encabezados van dentro de la lista y no flotando encima:
              // un botón flotante tapa publicaciones, y en un muro largo eso
              // estorba justo donde se está leyendo.
              itemCount: publicaciones.length + encabezados.length,
              itemBuilder: (context, i) {
                if (i < encabezados.length) return encabezados[i];
                return Publicacion(
                  publicacion: publicaciones[i - encabezados.length],
                );
              },
            ),
    );
  }

  /// Entrar a votar desde la tarjeta de la portada.
  ///
  /// **Sin la papeleta dentro, al revés que desde el aviso**: quien toca la
  /// tarjeta puede llevar horas con el muro abierto, así que el tarjetón la pide
  /// fresca. Desde el aviso sí viaja, porque allí se acaba de traer para poder
  /// listar los cargos. Ver [TarjetonScreen].
  Future<void> _abrirElTarjeton() async {
    final votacion = VotacionPendiente.instancia.laDeHoy;
    if (votacion == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TarjetonScreen(votacion: votacion),
      ),
    );

    // Al volver, la tarjeta puede tener que desaparecer: el tarjetón avisa a
    // VotacionPendiente cuando la papeleta se acaba.
    if (mounted) setState(() {});
  }

  /// La puerta a las notas, para el docente, encima de las publicaciones.
  ///
  /// Con las clases de hoy dentro y no como un botón a secas: ese dato ya viene
  /// en la misma respuesta del muro —no cuesta ninguna petición, ver
  /// [HorarioDeHoy]— y convierte el botón en información. Cuando no se sabe
  /// cuántas son, se dice «Notas» y ya.
  Widget? _buildAccesoANotas() {
    if (!AuthService.user.esDocente) return null;

    final horario = HorarioDeHoy.instancia;
    final cuantas = horario.cuantas;

    final grupos = horario.clases
        .map((c) => c.asignatura.abrevGrupo)
        .where((abrev) => abrev.isNotEmpty)
        .toSet()
        .join(', ');

    final String detalle;
    if (!horario.seSabe) {
      detalle = 'Poner y corregir notas';
    } else if (cuantas == 0) {
      detalle = 'Hoy no tienes clases';
    } else {
      detalle = '$cuantas ${cuantas == 1 ? 'clase' : 'clases'} hoy'
          '${grupos.isEmpty ? '' : ' · $grupos'}';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, '/notas'),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.edit_note_outlined, color: kPrimaryColor),
        ),
        title: const Text(
          'Notas',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detalle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  /// Un muro sin nada. Tiene que poder tirarse hacia abajo igual, o el docente
  /// que entra el primer día del año se queda sin forma de recargar.
  Widget _muroVacio(List<Widget> encabezados) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ...encabezados,
        SizedBox(height: 120),
        Icon(Icons.forum_outlined, size: 56, color: Colors.black26),
        SizedBox(height: 12),
        Center(
          child: Text(
            AuthService.user.puedeComentar
                ? 'Todavía no hay publicaciones.'
                : 'Todavía no hay publicaciones del colegio.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
