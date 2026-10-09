import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/PqrsApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/PqrsModel.dart';
import 'package:myvc_flutter/Screens/DetallePqrsScreen.dart';
import 'package:myvc_flutter/Screens/RadicarPqrsScreen.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/EstiloPqrs.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// «PQRS» del acudiente (Joseth, 9 oct 2026): las que ha radicado, con su
/// estado y su plazo, y el botón para radicar otra. Ver `docs/pqrs.md`.
///
/// Las abiertas arriba, en el orden que manda el servidor (la que vence antes
/// primero); debajo, las respondidas y cerradas. Si se llega desde el aviso de
/// «el colegio respondió», se abre esa PQRS encima en cuanto carga la lista.
class MisPqrsScreen extends StatefulWidget {
  const MisPqrsScreen({super.key, this.aviso});

  final AvisoDePqrs? aviso;

  @override
  State<MisPqrsScreen> createState() => _MisPqrsScreenState();
}

class _MisPqrsScreenState extends State<MisPqrsScreen> {
  final _drawerController = ZoomDrawerController();
  ListaDePqrs? _lista;
  String? _error;
  bool _avisoAbierto = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final lista = await traerMisPqrs(Server());
      if (!mounted) return;
      setState(() => _lista = lista);
      _abrirElDelAviso();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _abrirElDelAviso() {
    final id = widget.aviso?.pqrsId;
    if (id == null || _avisoAbierto) return;
    _avisoAbierto = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrir(id));
  }

  Future<void> _abrir(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetallePqrsScreen(pqrsId: id)),
    );
    if (mounted) _cargar();
  }

  Future<void> _radicar() async {
    final lista = _lista;
    if (lista == null) return;
    final radicada = await Navigator.push<DetallePqrs>(
      context,
      MaterialPageRoute(builder: (_) => RadicarPqrsScreen(lista: lista)),
    );
    if (!mounted || radicada == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => DetallePqrsScreen(pqrsId: radicada.fila.id, recien: radicada)),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: EstiloPqrs.fondo,
        appBar: AppBar(
          title: const TituloPantalla(titulo: 'PQRS'),
          leading: GestureDetector(
            child: const Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        floatingActionButton: _lista == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _radicar,
                backgroundColor: EstiloPqrs.primario,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Radicar'),
              ),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final lista = _lista;
    if (lista == null) return const Center(child: CircularProgressIndicator());

    final abiertas = lista.filas.where((f) => f.abierta).toList();
    final hechas = lista.filas.where((f) => !f.abierta).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _explicacion(),
          const SizedBox(height: 16),
          if (lista.filas.isEmpty) _vacio(),
          if (abiertas.isNotEmpty) ...[
            EstiloPqrs.rotulo('Abiertas'),
            for (final f in abiertas) ...[_tarjeta(f), const SizedBox(height: 10)],
            const SizedBox(height: 8),
          ],
          if (hechas.isNotEmpty) ...[
            EstiloPqrs.rotulo('Respondidas y cerradas'),
            for (final f in hechas) ...[_tarjeta(f), const SizedBox(height: 10)],
          ],
        ],
      ),
    );
  }

  Widget _explicacion() => Container(
        padding: const EdgeInsets.all(14),
        decoration: EstiloPqrs.bloque(),
        child: const Text(
          'Peticiones, quejas, reclamos, sugerencias y felicitaciones al colegio. '
          'Por ley tiene 15 días hábiles para responder: 10 si pides un documento '
          'o una información, 30 si es una consulta.',
          style: TextStyle(fontSize: 13, height: 1.4, color: EstiloPqrs.tintaSuave),
        ),
      );

  Widget _vacio() => const Padding(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: Column(
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 48, color: EstiloPqrs.tintaApagada),
            SizedBox(height: 12),
            Text(
              'No has radicado ninguna PQRS.\nCon «Radicar» le escribes al colegio y te '
              'avisamos cuando responda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EstiloPqrs.tintaSuave),
            ),
          ],
        ),
      );

  Widget _tarjeta(FilaPqrs f) {
    final partes = [
      f.radicado,
      f.tipoTexto,
      if (f.alumno != null) f.alumno!.nombres,
    ];
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EstiloActividades.radio),
        child: InkWell(
          borderRadius: BorderRadius.circular(EstiloActividades.radio),
          onTap: () => _abrir(f.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: EstiloPqrs.primarioSuave,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(EstiloPqrs.iconoDelTipo(f.tipo), color: EstiloPqrs.primario, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partes.join(' · '),
                          style: const TextStyle(fontSize: 12, color: EstiloPqrs.tintaApagada)),
                      const SizedBox(height: 2),
                      Text(f.asunto,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: EstiloPqrs.tinta)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          EstiloPqrs.estado(f.estado, f.estadoTexto),
                          if (f.abierta || f.plazo.clave == 'respondida')
                            EstiloPqrs.plazo(f.plazo.texto, f.plazo.tono),
                          if (f.abierta && f.prorroga != null) EstiloPqrs.prorrogada(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
