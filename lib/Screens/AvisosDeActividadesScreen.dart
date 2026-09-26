import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Utils/EstiloActividades.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// La campana de actividades: los avisos de los últimos 60 días
/// (`GET act/avisos`, tanda 5).
///
/// Son las mismas filas que manda el push, así que quien tenga los avisos
/// apagados —o esté en la web, o en un iPhone, que todavía no recibe push—
/// se entera igual al abrir «Actividades». **Abrirla las marca leídas**
/// (`POST act/avisos/leidos` con el `hasta_id` que llegó): lo que se ve es lo
/// que se lee. Tocar una devuelve el aviso a quien la abrió, que sabe llevar a
/// la pantalla que toca.
class AvisosDeActividadesScreen extends StatefulWidget {
  const AvisosDeActividadesScreen({super.key, this.yaTraidos});

  /// Los que la bandeja ya trajo para pintar el número de la campana: no se
  /// piden dos veces.
  final AvisosAct? yaTraidos;

  @override
  State<AvisosDeActividadesScreen> createState() =>
      _AvisosDeActividadesScreenState();
}

class _AvisosDeActividadesScreenState extends State<AvisosDeActividadesScreen> {
  final _server = Server();
  AvisosAct? _avisos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _avisos = widget.yaTraidos;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final avisos =
          widget.yaTraidos ?? await traerAvisosDeActividades(_server);
      if (!mounted) return;
      setState(() => _avisos = avisos);
      if (avisos.noLeidos > 0) {
        // Si falla, la próxima vez vuelven a salir como nuevos: nada se
        // pierde, así que no se avisa.
        marcarAvisosLeidos(_server, avisos.hastaId).catchError((_) {});
      }
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avisos = _avisos;
    return Scaffold(
      backgroundColor: EstiloActividades.fondo,
      appBar: AppBar(
        backgroundColor: EstiloActividades.fondo,
        title:
            const Text('Avisos de actividades', style: TextStyle(fontSize: 17)),
      ),
      body: avisos == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
            )
          : avisos.avisos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No hay avisos de actividades.',
                        style: TextStyle(color: EstiloActividades.tintaSuave)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: avisos.avisos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _fila(avisos.avisos[i]),
                ),
    );
  }

  Widget _fila(AvisoAct a) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(EstiloActividades.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(EstiloActividades.radio),
        onTap: () => Navigator.pop(context, a),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EstiloActividades.chapaDelModo(a.modo, lado: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(a.titulo,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        if (!a.leido)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: EstiloActividades.primario,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(a.texto,
                        style: const TextStyle(
                            fontSize: 13, color: EstiloActividades.tintaSuave)),
                    if (a.creadoAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(hace(a.creadoAt),
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: EstiloActividades.tintaApagada)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
