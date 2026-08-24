import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// Un servidor de mentira que apunta lo que le mandan y contesta lo que se le
/// diga, tanda a tanda.
class ServidorFingido extends Server {
  ServidorFingido(this.respuestas);

  /// Una por tanda, en orden.
  final List<http.Response> respuestas;

  final List<String> rutas = [];
  final List<List<dynamic>> notasRecibidas = [];

  @override
  Future put(String direccion, params) async {
    rutas.add(direccion);
    notasRecibidas.add((params as Map)['notas'] as List);

    final cual = respuestas.length == 1 ? 0 : notasRecibidas.length - 1;
    return respuestas[cual];
  }
}

http.Response ok({
  int guardadas = 0,
  List<Map<String, dynamic>> fallidas = const [],
  List<Map<String, dynamic>> definitivas = const [],
}) {
  return http.Response(
    jsonEncode({
      'guardadas': guardadas,
      'fallidas': fallidas,
      'definitivas': definitivas,
    }),
    200,
  );
}

List<NotaPendiente> notas(int cuantas) {
  return [
    for (var i = 0; i < cuantas; i++)
      NotaPendiente(notaId: 900 + i, alumnoId: 30 + i, nota: 85),
  ];
}

void main() {
  test('el interruptor viene apagado, que es lo que protege a los rezagados',
      () {
    // Es una sola app para dieciséis colegios. Encender esto antes de que el
    // endpoint esté desplegado en TODOS gasta un 404 en los que van
    // rezagados, y el fallo sale en la pantalla que usan todos los días.
    expect(Interruptores.notasLote, isFalse);
    expect(Interruptores.disciplinaMisFichas, isFalse);
  });

  group('guardar en lote', () {
    test('manda id y nota, y a la ruta del lote', () async {
      final servidor = ServidorFingido([ok(guardadas: 2)]);

      await guardarNotas(servidor, notas(2), enLote: true);

      expect(servidor.rutas, ['/notas/lote']);
      expect(servidor.notasRecibidas.single, [
        {'id': 900, 'nota': 85.0},
        {'id': 901, 'nota': 85.0},
      ]);
    });

    test('trocea, porque pasarse del tope aborta el lote entero', () async {
      // El servidor corta en 200 y no recorta: devuelve 422 y no guarda nada.
      // Su propio controlador dejó escrito que daba por hecho que el cliente
      // partía en tandas, y el cliente no lo hacía. Ahora sí, y con margen por
      // debajo del tope para que bajarlo no nos rompa.
      final servidor = ServidorFingido([ok(guardadas: 100)]);

      await guardarNotas(servidor, notas(250), enLote: true);

      expect(servidor.rutas.length, 3);
      expect(
        servidor.notasRecibidas.map((t) => t.length).toList(),
        [100, 100, 50],
      );
    });

    test('una columna normal cabe en una sola petición', () async {
      // Cuarenta y cinco es un grupo grande. Que el troceo no convierta el
      // caso corriente en varias peticiones es medio sentido de todo esto.
      final servidor = ServidorFingido([ok(guardadas: 45)]);

      await guardarNotas(servidor, notas(45), enLote: true);

      expect(servidor.rutas.length, 1);
    });

    test('las fallidas del servidor vuelven con su nota, para reintentarlas',
        () async {
      final servidor = ServidorFingido([
        ok(
          guardadas: 2,
          fallidas: [
            {'id': 901, 'motivo': 'La nota 105 no cabe en la escala del año.'},
          ],
        ),
      ]);

      final resultado = await guardarNotas(servidor, notas(3), enLote: true);

      expect(resultado.guardadas, 2);
      expect(resultado.fallidas.map((f) => f.notaId), [901]);
      expect(resultado.fallidas.single.alumnoId, 31);
      expect(resultado.motivo, 'La nota 105 no cabe en la escala del año.');
      expect(resultado.todoBien, isFalse);
    });

    test('una tanda rechazada no se lleva por delante lo que ya entró',
        () async {
      // Es el caso que hace que troceando siga siendo seguro: si la segunda
      // tanda revienta, las cien de la primera están guardadas y solo se
      // reintentan las otras.
      final servidor = ServidorFingido([
        ok(guardadas: 100),
        http.Response(
          jsonEncode({'message': 'El lote no puede pasar de 200 notas.'}),
          422,
        ),
      ]);

      final resultado = await guardarNotas(servidor, notas(150), enLote: true);

      expect(resultado.guardadas, 100);
      expect(resultado.fallidas.length, 50);
      expect(resultado.motivo, 'El lote no puede pasar de 200 notas.');
    });

    test('un periodo cerrado se explica como permiso, no como número',
        () async {
      final servidor = ServidorFingido([http.Response('', 400)]);

      final resultado = await guardarNotas(servidor, notas(3), enLote: true);

      expect(resultado.guardadas, 0);
      expect(resultado.fallidas.length, 3);
      expect(resultado.motivo, contains('No tienes permiso'));
    });

    test('el avance cuenta también las tandas que fallaron', () async {
      // La barra la mira alguien que está esperando: si una tanda falla y no
      // se cuenta, se queda parada a media pantalla sin que nada haya pasado.
      final servidor = ServidorFingido([
        ok(guardadas: 100),
        http.Response('', 500),
      ]);

      final avances = <int>[];
      await guardarNotas(servidor, notas(150),
          enLote: true, avance: (hechas, _) => avances.add(hechas));

      expect(avances, [100, 150]);
    });
  });

  group('las definitivas que devuelve el lote', () {
    test('llegan con sus banderas, que son booleanos de verdad', () async {
      // El resto del archivo lee las banderas con `entero(x) == 1` porque los
      // listados salen de DB::select y PDO decide el tipo. Pero esta respuesta
      // la arma PHP con un (bool) delante, así que llega `true` y `entero(true)`
      // no es 1. Si esto se rompe, una definitiva manual se pintaría como
      // automática.
      final servidor = ServidorFingido([
        ok(guardadas: 1, definitivas: [
          {
            'alumno_id': 31,
            'asignatura_id': 7,
            'periodo_id': 3,
            'nota': 85,
            'manual': true,
            'recuperada': false,
          },
        ]),
      ]);

      final resultado = await guardarNotas(servidor, notas(1), enLote: true);

      final definitiva = resultado.definitivas.single;
      expect(definitiva.alumnoId, 31);
      expect(definitiva.nota, 85);
      expect(definitiva.manual, isTrue);
      expect(definitiva.recuperada, isFalse);
    });

    test('sin definitiva no es un cero', () async {
      // El alumno que todavía no tiene fila viaja con nota null a propósito, y
      // pintarlo como cero sería inventarle una nota perdida.
      final servidor = ServidorFingido([
        ok(guardadas: 1, definitivas: [
          {
            'alumno_id': 31,
            'asignatura_id': 7,
            'periodo_id': 3,
            'nota': null,
            'manual': false,
            'recuperada': false,
          },
        ]),
      ]);

      final resultado = await guardarNotas(servidor, notas(1), enLote: true);

      expect(resultado.definitivas.single.nota, isNull);
    });

    test('guardando de una en una no viene ninguna, y eso no es un fallo',
        () async {
      // Vacía significa «este camino no las trae», no «no hay definitivas».
      const resultado = ResultadoGuardado(guardadas: 3);

      expect(resultado.definitivas, isEmpty);
    });
  });

  group('aplicar una definitiva del lote sobre el libro', () {
    LibroDeNotas libroCon(NotaFinalDelLibro? notaFinal) {
      return LibroDeNotas(
        asignatura: AsignaturaModel(
          id: 7,
          grupoId: 2,
          materia: 'Matemáticas',
          aliasMateria: 'Mat',
          nombreGrupo: 'Décimo B',
          abrevGrupo: '10-B',
        ),
        unidades: const [],
        alumnos: [
          AlumnoDelLibro(
            alumnoId: 31,
            nombres: 'Dámaris',
            apellidos: 'Gómez Pico',
            notaFinal: notaFinal,
          ),
        ],
      );
    }

    const conFila = NotaFinalDelLibro(
      nfId: 4400,
      nota: 70,
      automatica: 70,
      actualizadaPor: 'agomez',
    );

    test('conserva el nf_id, o se pierde el botón de nivelar', () {
      // notas/lote no devuelve nf_id. Construir una NotaFinalDelLibro nueva
      // dejaría nf_id en cero, y `existe` mira justamente eso para apagar el
      // control: se habría perdido el botón por refrescar un número.
      final libro = libroCon(conFila).conDefinitivaDelLote(
        const DefinitivaDelLote(
          alumnoId: 31,
          asignaturaId: 7,
          periodoId: 3,
          nota: 85,
          manual: true,
        ),
      );

      final quedo = libro.alumnos.single.notaFinal!;
      expect(quedo.nota, 85);
      expect(quedo.manual, isTrue);
      expect(quedo.nfId, 4400, reason: 'el nf_id tiene que sobrevivir');
      expect(quedo.existe, isTrue);
      // Tampoco las pierde: el lote no las manda y la app ya las tenía.
      expect(quedo.automatica, 70);
      expect(quedo.actualizadaPor, 'agomez');
    });

    test('una definitiva sin nota no pisa la que había', () {
      // Después de escribir, el recalculador siempre deja fila. Un null ahí es
      // «no tiene definitiva», no «vale cero», y pisarla haría que una materia
      // pareciera perdida.
      final libro = libroCon(conFila).conDefinitivaDelLote(
        const DefinitivaDelLote(
          alumnoId: 31,
          asignaturaId: 7,
          periodoId: 3,
          nota: null,
        ),
      );

      expect(libro.alumnos.single.notaFinal!.nota, 70);
    });

    test('un alumno sin fila se queda como estaba', () {
      // Sin nf_id no hay nada que nivelar; notas/detailed la creará al recargar.
      final libro = libroCon(null).conDefinitivaDelLote(
        const DefinitivaDelLote(
          alumnoId: 31,
          asignaturaId: 7,
          periodoId: 3,
          nota: 85,
        ),
      );

      expect(libro.alumnos.single.notaFinal, isNull);
    });

    test('una definitiva de otro alumno no toca a este', () {
      final libro = libroCon(conFila).conDefinitivaDelLote(
        const DefinitivaDelLote(
          alumnoId: 999,
          asignaturaId: 7,
          periodoId: 3,
          nota: 10,
        ),
      );

      expect(libro.alumnos.single.notaFinal!.nota, 70);
    });
  });
}
