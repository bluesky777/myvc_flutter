import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';
import 'package:myvc_flutter/Utils/PrefijoDeBanda.dart';

/// Una banda de la escala, con la frase del SIEE que el boletín le pone
/// delante a cada competencia.
EscalaDeValoracion banda(String desempenio, String descripcion, double desde) {
  return EscalaDeValoracion(
    id: desde.toInt(),
    desempenio: desempenio,
    porcInicial: desde,
    descripcion: descripcion,
  );
}

/// Lo que tienen hoy todos los colegios: cuatro bandas y ninguna descripción.
final escalaDeHoy = [
  banda('Superior', '', 91),
  banda('Alto', '', 76),
  banda('Básico', '', 60),
  banda('Bajo', '', 0),
];

/// Un colegio que sí escribió su SIEE, pero solo en dos bandas.
final escalaAMedias = [
  banda('Superior', 'Excelencia en', 91),
  banda('Alto', 'Fortaleza en', 76),
  banda('Básico', '', 60),
  banda('Bajo', 'Dificultad en', 0),
];

void main() {
  group('qué bandas salen', () {
    test('solo las que tienen frase escrita', () {
      final previo = previoDeImpresion('interpretar gráficas', escalaAMedias);

      // Tres de cuatro: «Básico» no tiene frase y no aparece. No es que salga
      // sin prefijo, es que no sale.
      expect(previo, hasLength(3));
      expect(previo.any((l) => l.contains('Básico')), isFalse);
    });

    test('con dos bandas escritas de cuatro, dos líneas', () {
      final escalas = [
        banda('Superior', 'Excelencia en', 91),
        banda('Alto', '', 76),
        banda('Básico', 'Avance en', 60),
        banda('Bajo', '', 0),
      ];

      expect(previoDeImpresion('sumar', escalas), [
        'Excelencia en sumar',
        'Avance en sumar',
      ]);
    });

    test('en el orden en que vienen las escalas', () {
      // De la nota más alta a la más baja, que es como las ordenan
      // ColegioModel y traerEscalasDelAnio y como las imprime el boletín.
      final previo = previoDeImpresion('leer', escalaAMedias);

      expect(previo.first, startsWith('Excelencia en'));
      expect(previo.last, startsWith('Dificultad en'));
    });
  });

  group('cuándo no se pinta nada', () {
    test('ninguna banda con frase, lista vacía', () {
      // El caso de todos los colegios hoy: el 17 sep 2026 las 36 escalas vivas
      // del colegio de desarrollo tenían la descripción a NULL o vacía. La
      // pantalla no pinta el bloque: ni un marco vacío ni un «(sin prefijo)».
      expect(previoDeImpresion('interpretar gráficas', escalaDeHoy), isEmpty);
    });

    test('sin escalas, lista vacía', () {
      expect(previoDeImpresion('interpretar gráficas', const []), isEmpty);
    });

    test('texto vacío, lista vacía', () {
      // Aquí NO se replica el backend a propósito: `conElPrefijo` no mira el
      // texto e imprimiría «Fortaleza en » con el espacio colgando. El campo
      // en blanco no es un caso del boletín, y un previo de nada no es nada.
      expect(previoDeImpresion('', escalaAMedias), isEmpty);
    });

    test('texto de solo espacios, lista vacía', () {
      expect(previoDeImpresion('   ', escalaAMedias), isEmpty);
    });

    test('una frase de solo espacios no es una frase', () {
      // El `trim` del backend la deja en '' y con eso imprime el texto pelado.
      final escalas = [banda('Alto', '   ', 76)];

      expect(previoDeImpresion('sumar', escalas), isEmpty);
    });
  });

  group('el montaje es el del backend', () {
    // `BoletinPorCompetenciasController::conElPrefijo`, entero:
    //
    //   $prefijo = $banda === null ? '' : trim((string) $banda->descripcion);
    //   return $prefijo === '' ? $texto : $prefijo.' '.$texto;

    test('un solo espacio entre la frase y el texto', () {
      final escalas = [banda('Alto', 'Fortaleza en', 76)];

      expect(previoDeImpresion('interpretar gráficas', escalas), [
        'Fortaleza en interpretar gráficas',
      ]);
    });

    test('la frase se recorta, el texto no', () {
      // El `trim` del backend es solo del prefijo: `$texto` se concatena tal
      // cual, así que dos espacios en el texto salen impresos.
      final escalas = [banda('Alto', '  Fortaleza en  ', 76)];

      expect(previoDeImpresion('  interpretar gráficas', escalas), [
        'Fortaleza en   interpretar gráficas',
      ]);
    });

    test('no se toca ninguna mayúscula', () {
      // Ni se baja la del texto ni se sube la del prefijo. El boletín imprime
      // la I en medio, y el previo está para que el docente lo vea.
      final escalas = [banda('Alto', 'fortaleza en', 76)];

      expect(previoDeImpresion('Interpretar gráficas', escalas), [
        'fortaleza en Interpretar gráficas',
      ]);
    });
  });

  group('lo que llega del backend', () {
    test('una descripción a NULL no rompe', () {
      // 5 de las 36 escalas vivas la tienen a NULL y 31 a cadena vacía: para
      // el `trim` del boletín significan lo mismo, y aquí también.
      final escala = EscalaDeValoracion.fromJson({
        'id': 1,
        'desempenio': 'Alto',
        'porc_inicial': 76,
        'porc_final': 90,
        'descripcion': null,
      });

      expect(escala.descripcion, '');
      expect(previoDeImpresion('sumar', [escala]), isEmpty);
    });

    test('una descripción escrita llega y se usa', () {
      final escala = EscalaDeValoracion.fromJson({
        'id': 1,
        'desempenio': 'Alto',
        'porc_inicial': 76,
        'porc_final': 90,
        'descripcion': 'Fortaleza en',
      });

      expect(previoDeImpresion('sumar', [escala]), ['Fortaleza en sumar']);
    });

    test('sin la clave descripcion tampoco rompe', () {
      // Un backend viejo, o un `SELECT` que no la traiga.
      final escala = EscalaDeValoracion.fromJson({'id': 1, 'porc_inicial': 76});

      expect(escala.descripcion, '');
      expect(previoDeImpresion('sumar', [escala]), isEmpty);
    });
  });
}
