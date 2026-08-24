import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/TecladoDeNota.dart';

void main() {
  const filtro = SinDecimales();

  TextEditingValue v(String texto) => TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      );

  String resultado(String antes, String despues) =>
      filtro.formatEditUpdate(v(antes), v(despues)).text;

  group('el campo de una nota', () {
    test('deja escribir dígitos', () {
      expect(resultado('8', '85'), '85');
      expect(resultado('', '9'), '9');
      expect(resultado('10', '100'), '100');
    });

    test('la coma no entra, y el campo se queda como estaba', () {
      // Es el arreglo: `notas.nota` es `int`, así que un 85,5 no se puede
      // guardar. Antes se dejaba escribir, se mandaba 85.5, el servidor
      // guardaba 85 y la pantalla seguía enseñando 85,5 hasta recargar.
      expect(resultado('85', '85,'), '85');
      expect(resultado('85', '85.'), '85');
      expect(resultado('85,', '85,5'), '85,');
    });

    test('pegar «85.5» NO deja un 855', () {
      // Es la razón de que esto no sea `FilteringTextInputFormatter.digitsOnly`:
      // aquél borra el punto y deja 855, que es una nota real, distinta y peor
      // que la que se pegó. Rechazando la edición entera, quien pega lo ve.
      expect(resultado('', '85.5'), '');
      expect(resultado('70', '85,5'), '70');
    });

    test('las letras tampoco', () {
      expect(resultado('8', '8a'), '8');
      expect(resultado('', 'ochenta'), '');
    });

    test('borrar siempre se puede, aunque lo escrito traiga una coma', () {
      // Si no, un valor con coma llegado por otro camino dejaría el campo
      // bloqueado y sin forma de arreglarlo.
      expect(resultado('85,5', '85,'), '85,');
      expect(resultado('85,', '85'), '85');
      expect(resultado('85', ''), '');
    });
  });
}
