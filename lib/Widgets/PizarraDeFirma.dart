import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// El color de la tinta: el mismo azul oscuro que la pizarra de la web
/// (`pedir-firma.ts`), para que una firma dibujada aquí y otra dibujada allí
/// salgan iguales en el boletín.
const Color tintaDeFirma = Color(0xFF0D1B4C);

/// Los trazos de una firma, y cómo convertirlos en el PNG que se sube.
class TrazosDeFirma extends ChangeNotifier {
  final List<List<Offset>> _trazos = [];

  /// El grosor en la pantalla. En el PNG se multiplica por la escala.
  static const double grosor = 3;

  List<List<Offset>> get trazos => _trazos;

  bool get vacia => _trazos.every((t) => t.isEmpty);

  void empezar(Offset punto) {
    _trazos.add([punto]);
    notifyListeners();
  }

  void seguir(Offset punto) {
    if (_trazos.isEmpty) return;
    _trazos.last.add(punto);
    notifyListeners();
  }

  void borrar() {
    _trazos.clear();
    notifyListeners();
  }

  /// El PNG de la firma, **ya recortado y con el fondo transparente**.
  ///
  /// Es lo que en la web hace `normalizarFirma` sobre el lienzo: recortar el
  /// papel que sobra y quitar el blanco. Aquí sale gratis porque se pinta desde
  /// los trazos y no desde una foto: el recorte es la caja de los puntos, y el
  /// fondo nunca se pintó.
  ///
  /// La [escala] sube la resolución: en la pantalla de un teléfono la pizarra
  /// mide unos 350 px de ancho, y una firma de 350 px se ve borrosa impresa.
  /// Null si no hay trazos.
  Future<Uint8List?> aPng({double escala = 3}) async {
    final puntos = _trazos.expand((t) => t).toList();
    if (puntos.isEmpty) return null;

    var caja = Rect.fromPoints(puntos.first, puntos.first);
    for (final p in puntos) {
      caja = caja.expandToInclude(Rect.fromPoints(p, p));
    }
    caja = caja.inflate(grosor * 2);

    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    lienzo.scale(escala);
    lienzo.translate(-caja.left, -caja.top);
    PintorDeFirma.pintar(lienzo, _trazos);

    final imagen = await grabadora.endRecording().toImage(
          (caja.width * escala).ceil(),
          (caja.height * escala).ceil(),
        );
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();

    return datos?.buffer.asUint8List();
  }
}

/// Donde se firma con el dedo.
class PizarraDeFirma extends StatelessWidget {
  final TrazosDeFirma trazos;

  const PizarraDeFirma({super.key, required this.trazos});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          // `pan` y no `onTap…`: un punto suelto —el de una i— también es un
          // trazo, y con el arrastre llega igual por `onPanStart`.
          onPanStart: (d) => trazos.empezar(d.localPosition),
          onPanUpdate: (d) => trazos.seguir(d.localPosition),
          child: ListenableBuilder(
            listenable: trazos,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (trazos.vacia)
                  const Center(
                    child: Text('Firma aquí',
                        style: TextStyle(color: Colors.black26, fontSize: 18)),
                  ),
                // La línea de apoyo, como en un papel.
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: Container(height: 1, color: Colors.black12),
                ),
                CustomPaint(painter: PintorDeFirma(trazos.trazos)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PintorDeFirma extends CustomPainter {
  final List<List<Offset>> trazos;

  PintorDeFirma(this.trazos);

  static void pintar(Canvas lienzo, List<List<Offset>> trazos) {
    final pincel = Paint()
      ..color = tintaDeFirma
      ..strokeWidth = TrazosDeFirma.grosor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final trazo in trazos) {
      if (trazo.isEmpty) continue;
      if (trazo.length == 1) {
        lienzo.drawCircle(trazo.first, TrazosDeFirma.grosor / 2,
            Paint()..color = tintaDeFirma);
        continue;
      }
      final camino = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (final p in trazo.skip(1)) {
        camino.lineTo(p.dx, p.dy);
      }
      lienzo.drawPath(camino, pincel);
    }
  }

  @override
  void paint(Canvas canvas, Size size) => pintar(canvas, trazos);

  // Los trazos son la misma lista que crece por dentro, así que no hay forma
  // barata de saber si cambió: se repinta siempre, y el ListenableBuilder de
  // arriba es quien decide cuándo.
  @override
  bool shouldRepaint(PintorDeFirma oldDelegate) => true;
}
