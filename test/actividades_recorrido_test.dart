import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Utils/RecorridoActividad.dart';

/// **El recorrido en Dart contra el contrato, §2.5.**
///
/// Es la copia de `8myvc/app/Services/Act/Recorrido.php`: si las dos dicen
/// cosas distintas, el alumno ve una pregunta de más o de menos, y el servidor
/// descarta o exige al enviar algo que la pantalla no enseñó. Cada prueba es
/// una frase del contrato.
PreguntaAct _p(
  int id,
  String tipo, {
  int? orden,
  List<List<CondicionAct>> condiciones = const [],
  List<int> opciones = const [],
}) =>
    PreguntaAct(
      id: id,
      orden: orden ?? id,
      tipo: tipo,
      enunciado: 'Pregunta $id',
      obligatoria: false,
      puntos: 0,
      opcionOtra: false,
      aleatorias: false,
      opciones: [
        for (final o in opciones) OpcionAct(id: o, definicion: 'Opción $o'),
      ],
      condiciones: condiciones,
    );

CondicionAct _c(int dependeDe, String operador, {int? opcion, String? valor}) =>
    CondicionAct(
      dependeDeId: dependeDe,
      operador: operador,
      opcionId: opcion,
      valor: valor,
    );

Map<int, RespuestaAct> _r(List<RespuestaAct> respuestas) =>
    {for (final r in respuestas) r.preguntaId: r};

void main() {
  group('sin condiciones', () {
    test('todas se ven, en orden y no en el orden en que llegaron', () {
      final preguntas = [
        _p(3, 'corta', orden: 2),
        _p(1, 'unica', orden: 1),
        _p(2, 'corta', orden: 2),
      ];

      // Mismo `orden`: desempata el id, como el `usort` del servidor.
      expect(preguntasVisibles(preguntas, const {}), [1, 2, 3]);
    });
  });

  group('es', () {
    final preguntas = [
      _p(1, 'unica', opciones: [10, 11]),
      _p(2, 'corta', condiciones: [
        [_c(1, 'es', opcion: 10)]
      ]),
    ];

    test('con la opción elegida aparece', () {
      final r = _r([const RespuestaAct(preguntaId: 1, opcionIds: [10])]);
      expect(preguntasVisibles(preguntas, r), [1, 2]);
    });

    test('con otra opción no', () {
      final r = _r([const RespuestaAct(preguntaId: 1, opcionIds: [11])]);
      expect(preguntasVisibles(preguntas, r), [1]);
    });

    test('sin responder no', () {
      expect(preguntasVisibles(preguntas, const {}), [1]);
    });

    test('la escala compara el valor como número', () {
      final escala = [
        _p(1, 'escala'),
        _p(2, 'corta', condiciones: [
          [_c(1, 'es', valor: ' 4 ')]
        ]),
      ];

      expect(
          preguntasVisibles(
              escala, _r([const RespuestaAct(preguntaId: 1, valor: 4)])),
          [1, 2]);
      expect(
          preguntasVisibles(
              escala, _r([const RespuestaAct(preguntaId: 1, valor: 5)])),
          [1]);
    });

    test('el texto se compara normalizado: tildes, mayúsculas y espacios', () {
      final corta = [
        _p(1, 'corta'),
        _p(2, 'corta', condiciones: [
          [_c(1, 'es', valor: 'Bogotá D.C.')]
        ]),
      ];

      expect(
          preguntasVisibles(corta,
              _r([const RespuestaAct(preguntaId: 1, texto: '  BOGOTA   d.c. ')])),
          [1, 2]);
      expect(
          preguntasVisibles(
              corta, _r([const RespuestaAct(preguntaId: 1, texto: 'Bogotá')])),
          [1]);
    });

    test('la fecha, igual al día', () {
      final fecha = [
        _p(1, 'fecha'),
        _p(2, 'corta', condiciones: [
          [_c(1, 'es', valor: '2026-10-12 ')]
        ]),
      ];

      expect(
          preguntasVisibles(fecha,
              _r([const RespuestaAct(preguntaId: 1, fecha: '2026-10-12')])),
          [1, 2]);
      expect(
          preguntasVisibles(fecha,
              _r([const RespuestaAct(preguntaId: 1, fecha: '2026-10-13')])),
          [1]);
    });
  });

  group('no_es', () {
    final preguntas = [
      _p(1, 'sino', opciones: [1, 2]),
      _p(2, 'parrafo', condiciones: [
        [_c(1, 'no_es', opcion: 1)]
      ]),
    ];

    test('respondida con otra cosa se cumple', () {
      final r = _r([const RespuestaAct(preguntaId: 1, opcionIds: [2])]);
      expect(preguntasVisibles(preguntas, r), [1, 2]);
    });

    test('respondida con esa no', () {
      final r = _r([const RespuestaAct(preguntaId: 1, opcionIds: [1])]);
      expect(preguntasVisibles(preguntas, r), [1]);
    });

    test('sin responder NO se cumple, aunque «no es» suene a que sí', () {
      // La decisión del contrato: una pregunta sin responder no dispara nada,
      // ni siquiera la condición negativa.
      expect(preguntasVisibles(preguntas, const {}), [1]);
      expect(
          preguntasVisibles(
              preguntas, _r([const RespuestaAct(preguntaId: 1)])),
          [1]);
    });
  });

  group('contiene', () {
    test('en un texto busca la subcadena normalizada', () {
      final preguntas = [
        _p(1, 'parrafo'),
        _p(2, 'corta', condiciones: [
          [_c(1, 'contiene', valor: 'Peña')]
        ]),
      ];

      expect(
          preguntasVisibles(preguntas,
              _r([const RespuestaAct(preguntaId: 1, texto: 'Vivo en LA PENA')])),
          [1, 2]);
      expect(
          preguntasVisibles(preguntas,
              _r([const RespuestaAct(preguntaId: 1, texto: 'Vivo en el centro')])),
          [1]);
    });

    test('en una múltiple es lo mismo que «es»', () {
      final preguntas = [
        _p(1, 'multiple', opciones: [5, 6, 7]),
        _p(2, 'corta', condiciones: [
          [_c(1, 'contiene', opcion: 6)]
        ]),
      ];

      expect(
          preguntasVisibles(preguntas,
              _r([const RespuestaAct(preguntaId: 1, opcionIds: [5, 6])])),
          [1, 2]);
      expect(
          preguntasVisibles(preguntas,
              _r([const RespuestaAct(preguntaId: 1, opcionIds: [5, 7])])),
          [1]);
    });

    test('un texto vacío no contiene nada, ni la cadena vacía', () {
      final preguntas = [
        _p(1, 'corta'),
        _p(2, 'corta', condiciones: [
          [_c(1, 'contiene', valor: '')]
        ]),
      ];

      expect(
          preguntasVisibles(
              preguntas, _r([const RespuestaAct(preguntaId: 1, texto: '   ')])),
          [1]);
    });
  });

  group('y dentro del grupo, o entre grupos', () {
    final preguntas = [
      _p(1, 'unica', opciones: [10, 11]),
      _p(2, 'unica', opciones: [20, 21]),
      _p(3, 'corta', condiciones: [
        [_c(1, 'es', opcion: 10), _c(2, 'es', opcion: 20)],
        [_c(2, 'es', opcion: 21)],
      ]),
    ];

    test('el grupo pide todas', () {
      expect(
          preguntasVisibles(
              preguntas,
              _r([
                const RespuestaAct(preguntaId: 1, opcionIds: [10]),
                const RespuestaAct(preguntaId: 2, opcionIds: [20]),
              ])),
          [1, 2, 3]);
      expect(
          preguntasVisibles(
              preguntas,
              _r([
                const RespuestaAct(preguntaId: 1, opcionIds: [11]),
                const RespuestaAct(preguntaId: 2, opcionIds: [20]),
              ])),
          [1, 2]);
    });

    test('basta con un grupo', () {
      expect(
          preguntasVisibles(
              preguntas,
              _r([
                const RespuestaAct(preguntaId: 1, opcionIds: [11]),
                const RespuestaAct(preguntaId: 2, opcionIds: [21]),
              ])),
          [1, 2, 3]);
    });

    test('un grupo vacío no se cumple solo', () {
      final vacio = [
        _p(1, 'corta'),
        _p(2, 'corta', condiciones: [[]]),
      ];
      expect(preguntasVisibles(vacio, const {}), [1]);
    });
  });

  group('en cadena', () {
    final preguntas = [
      _p(1, 'sino', opciones: [1, 2]),
      _p(2, 'corta', condiciones: [
        [_c(1, 'es', opcion: 1)]
      ]),
      _p(3, 'parrafo', condiciones: [
        [_c(2, 'contiene', valor: 'perro')]
      ]),
    ];

    test('una pregunta oculta no dispara las que dependen de ella', () {
      // La 2 tiene respuesta —el borrador la guardó cuando se veía—, pero la
      // 1 cambió y la ocultó. Su respuesta ya no cuenta: la 3 se va con ella.
      final r = _r([
        const RespuestaAct(preguntaId: 1, opcionIds: [2]),
        const RespuestaAct(preguntaId: 2, texto: 'mi perro'),
      ]);
      expect(preguntasVisibles(preguntas, r), [1]);
    });

    test('y vuelve cuando vuelve la de arriba', () {
      final r = _r([
        const RespuestaAct(preguntaId: 1, opcionIds: [1]),
        const RespuestaAct(preguntaId: 2, texto: 'mi perro'),
      ]);
      expect(preguntasVisibles(preguntas, r), [1, 2, 3]);
    });
  });

  group('qué cuenta como respondida', () {
    test('una de opciones con «otra» escrita cuenta', () {
      expect(
          respuestaDada('unica',
              const RespuestaAct(preguntaId: 1, texto: 'Mi abuela')),
          isTrue);
      expect(respuestaDada('unica', const RespuestaAct(preguntaId: 1)),
          isFalse);
    });

    test('espacios no son una respuesta', () {
      expect(respuestaDada('corta', const RespuestaAct(preguntaId: 1, texto: '  ')),
          isFalse);
    });

    test('el archivo, con su id; la escala, con su valor', () {
      expect(
          respuestaDada(
              'archivo', const RespuestaAct(preguntaId: 1, archivoId: 7)),
          isTrue);
      expect(respuestaDada('escala', const RespuestaAct(preguntaId: 1)),
          isFalse);
      expect(respuestaDada('escala', const RespuestaAct(preguntaId: 1, valor: 1)),
          isTrue);
    });
  });

  test('normalizar: recortar, minúsculas, sin tildes y espacios a uno', () {
    // Igual que `Recorrido::normalizar`, que también convierte la ñ en n.
    expect(normalizarRespuesta('  Peña   ÁLVAREZ\tGüiza '), 'pena alvarez guiza');
    expect(normalizarRespuesta(null), '');
  });
}
