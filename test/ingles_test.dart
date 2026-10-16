import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Screens/WebConSesionScreen.dart';

void main() {
  group('la sesión para la web', () {
    test('deja el token, quita el refresco y salta a la ruta', () {
      final pagina = paginaQueDejaLaSesion(
        token: '12|abc"def',
        destino: 'https://colegio.test/up2/ingles/racha',
        ahora: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(pagina, contains("setItem('xtoken', \"12|abc\\\"def\")"));
      expect(pagina, contains("removeItem('xrefresco')"));
      // Siete días: app2 renueva a la mitad y en una visita no llega.
      expect(pagina, contains('"604800000"'));
      expect(
          pagina,
          contains(
              'location.replace("https://colegio.test/up2/ingles/racha")'));
    });
  });
}
