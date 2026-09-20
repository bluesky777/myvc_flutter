import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// El recorrido completo — pantalla 11 de `docs/estaciones.md`.
///
/// Los N pasos de una persona, con **quién los cerró y cuándo**. Solo lectura.
///
/// ## Esta pantalla contesta la pregunta con la que nació todo, y llega antes
///
/// *«¿Y mi hija en qué va?»*, preguntado en la secretaría un lunes cualquiera.
/// Y es la única pieza del módulo que **no espera a las ocho rutas**: se apoya
/// en `GET requisitos/recorrido/{alumno_id}`, que Joseth entregó el 20 sep 2026
/// en la tanda del día de matrículas. Espera solo a un despliegue, así que puede
/// encenderse meses antes que el resto.
///
/// ## La barra va vertical aquí, y horizontal en la ficha
///
/// No es una manía: son dos preguntas distintas. En la ficha de la estación la
/// pregunta es *«¿dónde va?»* —de un vistazo, horizontal—; aquí es *«quién y
/// cuándo»*, que **es leer, no mirar**, y leer se hace en columna.
class RecorridoDeMatriculaScreen extends StatefulWidget {
  const RecorridoDeMatriculaScreen({
    super.key,
    required this.alumnoId,
    required this.nombre,
    this.fotoNombre,
    this.grupo,
    this.servidor,
    this.encajada = false,
  });

  final int alumnoId;
  final String nombre;
  final String? fotoNombre;
  final String? grupo;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  /// Si va dentro del panel derecho de un maestro-detalle.
  ///
  /// Encajada **no lleva `AppBar` propia**: ya está la de la pantalla que la
  /// contiene, y dos barras seguidas en una tablet son media pantalla perdida.
  final bool encajada;

  @override
  State<RecorridoDeMatriculaScreen> createState() =>
      _RecorridoDeMatriculaScreenState();
}

class _RecorridoDeMatriculaScreenState
    extends State<RecorridoDeMatriculaScreen> {
  late final Server server = widget.servidor ?? Server();

  RecorridoDeMatricula? recorrido;
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    Analitica.evento('recorrido_matricula_abierto');
    _cargar();
  }

  @override
  void didUpdateWidget(RecorridoDeMatriculaScreen anterior) {
    super.didUpdateWidget(anterior);
    // En maestro-detalle el panel derecho no se vuelve a crear al elegir a otra
    // persona: se le cambia el `alumnoId`. Sin esto, la tablet enseñaría el
    // recorrido del anterior con el nombre del nuevo, que es el peor error
    // posible aquí — y silencioso.
    if (anterior.alumnoId != widget.alumnoId) _cargar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traido = await traerElRecorrido(server, widget.alumnoId);
      setState(() {
        recorrido = traido;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        error = '$err'.replaceFirst('Exception: ', '');
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.encajada) {
      return Container(
        color: PaletaEstaciones.fondo,
        child: ColumnaDeFicha(child: _cuerpo()),
      );
    }

    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: widget.nombre,
          subtitulo: widget.grupo,
          conFlecha: true,
        ),
      ),
      body: ColumnaDeFicha(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (!Interruptores.recorridoDeMatricula) {
      return const _Centrado(
        icono: Icons.hourglass_empty,
        // Se dice qué falta y no «no disponible»: quien lo lee es quien puede
        // desplegarlo. Y se dice que ya está escrito, que es la mitad de la
        // información útil.
        texto: 'Ver el recorrido está apagado hasta que el servidor despliegue '
            '`requisitos/recorrido`.\n\nEsa ruta ya está escrita y fundida —del '
            '20 de septiembre—, así que esto no espera a las ocho rutas de las '
            'estaciones: espera a una tanda de despliegue.',
      );
    }

    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    final actual = recorrido;
    if (actual == null || actual.pasos.isEmpty) {
      return const _Centrado(
        icono: Icons.route_outlined,
        texto: 'Esta persona no tiene recorrido de matrícula este año.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _ElResumen(
            recorrido: actual, nombre: widget.nombre, foto: widget.fotoNombre),
        const SizedBox(height: 14),
        for (final paso in actual.pasos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _UnPasoEnVertical(paso: paso),
          ),
      ],
    );
  }
}

/// Cuántos lleva, y qué es lo que frena.
class _ElResumen extends StatelessWidget {
  const _ElResumen({
    required this.recorrido,
    required this.nombre,
    this.foto,
  });

  final RecorridoDeMatricula recorrido;
  final String nombre;
  final String? foto;

  @override
  Widget build(BuildContext context) {
    final frena = recorrido.loQueFrena;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaletaEstaciones.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarPersona(nombre: nombre, fotoNombre: foto, radio: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Lleva ${recorrido.cerrados} de ${recorrido.pasos.length} pasos',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PaletaEstaciones.tinta,
            ),
          ),
          const SizedBox(height: 6),
          // El número nunca va solo: debajo, qué significa.
          Text(
            frena.isEmpty
                ? 'No le falta ningún paso obligatorio.'
                : frena.length == 1
                    ? 'Le falta ${frena.first.nombre}, que frena el recorrido.'
                    : 'Le faltan ${frena.length} pasos obligatorios: '
                        '${frena.map((p) => p.nombre).join(', ')}.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: frena.isEmpty
                  ? PaletaEstaciones.verdeTinta
                  : PaletaEstaciones.ambar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un paso, en vertical: el estado, quién lo cerró y cuándo.
class _UnPasoEnVertical extends StatelessWidget {
  const _UnPasoEnVertical({required this.paso});

  final PasoDelRecorrido paso;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaletaEstaciones.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PaletaEstaciones.fondo,
              border: Border.all(color: PaletaEstaciones.borde),
            ),
            child: Text(
              '${paso.nro}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PaletaEstaciones.gris,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paso.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                const SizedBox(height: 4),
                // Icono Y color Y palabra: los tres, siempre.
                Row(
                  children: [
                    Icon(paso.estado.icono, size: 15, color: paso.estado.color),
                    const SizedBox(width: 5),
                    Text(
                      paso.estado.palabra,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: paso.estado.color,
                      ),
                    ),
                    if (!paso.obligatorio) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'no frena',
                        style: TextStyle(
                          fontSize: 12,
                          color: PaletaEstaciones.tintaApagada,
                        ),
                      ),
                    ],
                  ],
                ),
                if (paso.cerradoPor != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    paso.cerradoHace == null
                        ? 'Cerrado por ${paso.cerradoPor}'
                        : 'Cerrado por ${paso.cerradoPor} · ${paso.cerradoHace}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PaletaEstaciones.tintaSuave,
                    ),
                  ),
                ],
                if (paso.motivo != null && paso.motivo!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: PaletaEstaciones.ambarFondo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      paso.motivo!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF7A4300),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
