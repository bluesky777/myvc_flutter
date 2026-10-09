import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/PorteriaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/PorteriaModel.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/LogoDelColegio.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// «Mi carné»: el QR que se enseña en portería (Joseth, 9 oct 2026).
///
/// El alumno ve el suyo; el acudiente, el de cada hijo, uno por página. Es el
/// mismo código que el colegio puede mandar imprimir en el carné físico, así
/// que da igual cuál se escanee.
class MiCarneScreen extends StatefulWidget {
  const MiCarneScreen({super.key});

  @override
  State<MiCarneScreen> createState() => _MiCarneScreenState();
}

class _MiCarneScreenState extends State<MiCarneScreen> {
  final _drawerController = ZoomDrawerController();
  final _paginas = PageController();
  late Future<List<CarneDeAlumno>> _carnes;
  int _pagina = 0;

  @override
  void initState() {
    super.initState();
    _carnes = misCarnes(Server());
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        appBar: AppBar(
          title: TituloPantalla(
            titulo: AuthService.user.esAcudiente ? 'Carnés' : 'Mi carné',
          ),
          leading: GestureDetector(
            child: const Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: FutureBuilder<List<CarneDeAlumno>>(
          future: _carnes,
          builder: (context, snap) {
            if (snap.hasError) {
              return _centrado('${snap.error}'.replaceFirst('Exception: ', ''));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final carnes = snap.data!;
            if (carnes.isEmpty) {
              return _centrado('No hay ningún alumno matriculado este año a tu nombre.');
            }
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _paginas,
                    itemCount: carnes.length,
                    onPageChanged: (i) => setState(() => _pagina = i),
                    itemBuilder: (context, i) => _Carne(carne: carnes[i]),
                  ),
                ),
                if (carnes.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < carnes.length; i++)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _pagina
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _centrado(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(texto, textAlign: TextAlign.center),
        ),
      );
}

class _Carne extends StatelessWidget {
  const _Carne({required this.carne});

  final CarneDeAlumno carne;

  @override
  Widget build(BuildContext context) {
    final a = carne.alumno;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                children: [
                  const LogoDelColegio(lado: 40),
                  const SizedBox(height: 16),
                  AvatarPersona(
                      fotoNombre: a.foto, nombre: a.nombreCompleto, radio: 44),
                  const SizedBox(height: 12),
                  Text(
                    a.nombreCompleto,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(a.grupo,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                  const SizedBox(height: 20),
                  // Fondo blanco aunque el teléfono esté en modo oscuro: un QR
                  // sin margen claro no lo lee ningún lector.
                  QrImageView(
                    data: carne.codigo,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    carne.codigo,
                    style: const TextStyle(
                        fontFamily: 'monospace', letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Muéstralo en portería. Si no lo lee, sube el brillo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
