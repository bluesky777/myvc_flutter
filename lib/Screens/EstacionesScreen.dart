import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/ColaDeEstacionScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Utils/PreferenciaEstacion.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// ¿Qué estación atiendes hoy? — pantalla 01 de `docs/estaciones.md`.
///
/// El día de matrículas, quien atiende una estación es **un docente de pie en un
/// aula, con una fila delante y papeles en la otra mano**. No tiene un
/// computador; tiene el teléfono con el que ya toma asistencia. Esta es la
/// puerta de entrada a ese trabajo.
///
/// ## Aquí ya no hay candados, y es un cambio del 20 de septiembre
///
/// La maqueta de esta pantalla pintaba un candado en las estaciones que «no
/// puedes cerrar tú», y el rótulo decía *«solo se abren las que puedes cerrar»*.
/// **Eso dejó de ser cierto**: Joseth decidió que cierra cualquiera del
/// personal, firmado con su nombre y su hora, y `rol_id` se descartó con motivo
/// escrito. Así que las cinco se abren, y *«la atiende Coordinación»* es
/// **información —a quién buscar— y no una puerta cerrada**. Ver
/// `docs/estaciones.md` §2.9.
///
/// ## Los tres vacíos de esta pantalla no son el mismo vacío
///
/// Y ésa es la mitad del diseño de aquí:
///
/// - **El módulo no existe todavía** ([Interruptores.estaciones] apagado). No se
///   llega: la entrada del menú ni siquiera sale.
/// - **Tu colegio no armó el recorrido.** Llega una lista vacía, y se dice eso.
/// - **Algo falló.** Se dice qué, y se ofrece reintentar.
///
/// Una lista vacía y «esto todavía no existe» se leen igual y no son lo mismo.
class EstacionesScreen extends StatefulWidget {
  const EstacionesScreen({super.key, this.servidor});

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  @override
  State<EstacionesScreen> createState() => _EstacionesScreenState();
}

class _EstacionesScreenState extends State<EstacionesScreen> {
  late final Server server = widget.servidor ?? Server();
  final _drawerController = ZoomDrawerController();

  List<Estacion> estaciones = [];
  int? miEstacion;

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    Analitica.evento('estaciones_abierta');
    _arrancar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _arrancar() async {
    miEstacion = await PreferenciaEstacion.leer();
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traidas = await traerLasEstaciones(server);
      setState(() {
        estaciones = traidas;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        error = '$err'.replaceFirst('Exception: ', '');
        cargando = false;
      });
    }
  }

  Future<void> _elegir(Estacion estacion) async {
    await PreferenciaEstacion.guardar(estacion.nro);
    setState(() => miEstacion = estacion.nro);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'cola-de-estacion'),
        builder: (_) => ColaDeEstacionScreen(
          estacion: estacion,
          servidor: widget.servidor,
        ),
      ),
    );

    // Al volver, la cola de cada estación pudo cambiar: se vuelve a preguntar.
    // Es la misma idea de §2.1 —una consulta, no una bandeja— aplicada a esta
    // pantalla: nada que vaciar, una pregunta que se repite.
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: PaletaEstaciones.fondo,
        appBar: AppBar(
          title: TituloPantalla(
            titulo: 'Estaciones',
            subtitulo: _subtitulo(),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: ColumnaDeFicha(child: _cuerpo()),
      ),
    );
  }

  String? _subtitulo() {
    if (cargando || error != null) return null;
    if (estaciones.isEmpty) return null;
    return estaciones.length == 1
        ? 'Una estación'
        : '${estaciones.length} estaciones';
  }

  Widget _cuerpo() {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    if (estaciones.isEmpty) {
      return const _Centrado(
        icono: Icons.route_outlined,
        // Se dice qué falta y no «no disponible»: quien lo lee es quien puede
        // pedirlo, y «no disponible» no se puede pedir ni arreglar.
        texto: 'Tu colegio todavía no armó el recorrido del día de '
            'matrículas.\n\nSe arma en la web, en la pantalla de requisitos: '
            'cada paso con su número y su nombre. Cuando esté, aparece aquí.',
      );
    }

    return RefreshIndicator(
      onRefresh: Analitica.refresco('estaciones', _cargar),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 12),
            child: Text(
              'Toca la que atiendes. Las demás también se abren: '
              'desde el 20 de septiembre cierra cualquiera del personal, '
              'y cada paso queda firmado con su nombre y su hora.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: PaletaEstaciones.tintaSuave,
              ),
            ),
          ),
          for (final estacion in estaciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaEstacion(
                estacion: estacion,
                esLaMia: estacion.nro == miEstacion,
                alTocar: () => _elegir(estacion),
              ),
            ),
          if (miEstacion != null) _elPie(),
        ],
      ),
    );
  }

  Widget _elPie() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      child: Column(
        children: [
          Text(
            'Mañana la app abre directo en tu estación.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: PaletaEstaciones.tintaApagada,
            ),
          ),
          TextButton(
            onPressed: () async {
              await PreferenciaEstacion.olvidar();
              setState(() => miEstacion = null);
            },
            child: const Text('Me movieron de puesto'),
          ),
        ],
      ),
    );
  }
}

/// Una estación de la lista.
///
/// El número va **grande y en blanco sobre el morado** porque el cartel impreso
/// del patio dice «2», y lo primero que hay que poder comprobar de un vistazo es
/// que estás en la estación que crees.
class _TarjetaEstacion extends StatelessWidget {
  const _TarjetaEstacion({
    required this.estacion,
    required this.esLaMia,
    required this.alTocar,
  });

  final Estacion estacion;
  final bool esLaMia;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  esLaMia ? PaletaEstaciones.primario : PaletaEstaciones.borde,
              width: esLaMia ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _ElNumero(nro: estacion.nro, destacado: esLaMia),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estacion.nombre,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: PaletaEstaciones.tinta,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _elSegundoRenglon(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: PaletaEstaciones.tintaSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LosQueEsperan(cuantos: estacion.esperando),
            ],
          ),
        ),
      ),
    );
  }

  /// Dónde está y quién suele atenderla. Lo segundo **no es un permiso**: es
  /// para saber a quién buscar si hay que preguntar algo.
  String _elSegundoRenglon() {
    final trozos = <String>[
      if (estacion.donde != null && estacion.donde!.isNotEmpty) estacion.donde!,
      if (esLaMia)
        'la tuya'
      else if (estacion.quienLaAtiende != null &&
          estacion.quienLaAtiende!.isNotEmpty)
        'la atiende ${estacion.quienLaAtiende}',
    ];
    if (trozos.isEmpty) return estacion.bloquea ? 'Frena el recorrido' : '';
    return trozos.join(' · ');
  }
}

class _ElNumero extends StatelessWidget {
  const _ElNumero({required this.nro, required this.destacado});

  final int nro;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: destacado
            ? PaletaEstaciones.primario
            : PaletaEstaciones.primarioSuave,
      ),
      child: Text(
        '$nro',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: destacado ? Colors.white : PaletaEstaciones.primarioOscuro,
        ),
      ),
    );
  }
}

/// Cuántos esperan. El número **nunca va solo**: lleva su palabra debajo.
class _LosQueEsperan extends StatelessWidget {
  const _LosQueEsperan({required this.cuantos});

  final int cuantos;

  @override
  Widget build(BuildContext context) {
    if (cuantos == 0) {
      return const Text(
        'libre',
        style: TextStyle(fontSize: 12, color: PaletaEstaciones.tintaApagada),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: PaletaEstaciones.primarioSuave,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$cuantos',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.primarioOscuro,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'esperando',
          style: TextStyle(fontSize: 11, color: PaletaEstaciones.tintaSuave),
        ),
      ],
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Anchos.formulario),
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
      ),
    );
  }
}
