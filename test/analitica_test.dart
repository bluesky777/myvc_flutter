import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';

void main() {
  group('la analítica', () {
    test('arrancar sin Firebase detrás la deja apagada, no reventada', () {
      // Este es el caso que de verdad ocurre: `FirebaseAnalytics.instance`
      // lanza `[core/no-app]` en cuanto se toca sin haber inicializado. Pasa en
      // las pruebas y pasaría en un arranque donde `initializeApp` fallara —sin
      // red, o con un google-services.json que no llegó al build—, y entonces
      // lo que se cae es la app entera antes de pintar el login.
      expect(Analitica.arrancar, returnsNormally);
      expect(Analitica.observadores, isEmpty);
    });

    test('sin arrancar no ofrece observadores', () {
      // `navigatorObservers` recibe esto tal cual en main.dart. Si devolviera
      // un observador sin instancia detrás, cada cambio de pantalla reventaría.
      expect(Analitica.observadores, isEmpty);
    });

    test('ninguna de sus llamadas tira, aunque no esté arrancada', () {
      // Es la regla que la hace segura de usar en cualquier sitio: se llama
      // desde initState y desde el guardado de notas, y una métrica perdida
      // jamás puede ser el motivo de que una pantalla se caiga o de que un
      // docente pierda lo que acaba de teclear.
      expect(() {
        Analitica.arrancar();
        Analitica.sesion(rol: 'docente', servidor: 'https://x.example.com');
        Analitica.pantalla('planilla');
        Analitica.evento('notas_guardadas', datos: {'cuantas': 28});
        Analitica.evento('sin_datos');
        Analitica.olvidar();
      }, returnsNormally);
    });
  });
}
