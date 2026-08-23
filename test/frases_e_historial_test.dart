import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/HistorialNotaApi.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';
import 'package:myvc_flutter/Utils/TextoPlano.dart';

void main() {
  group('las frases de un alumno', () {
    test('vienen dentro del libro, sin pedir nada aparte', () {
      final alumno = AlumnoDelLibro.fromJson({
        'alumno_id': 31,
        'nombres': 'Ana',
        'apellidos': 'Acosta',
        'frases': [
          {
            'id': 5,
            'frase': 'Participa con entusiasmo',
            'frase_id': 88,
            'tipo_frase': 'Fortaleza',
          },
          {'id': 6, 'frase': 'Le cuesta entregar a tiempo', 'frase_id': null},
        ],
      });

      expect(alumno.frases.length, 2);
      expect(alumno.frases.first.frase, 'Participa con entusiasmo');
      expect(alumno.frases.first.tipo, 'Fortaleza');
    });

    test('se distingue la del catálogo de la escrita a mano', () {
      // Importa: la del catálogo la resuelve el backend con un IFNULL, así que
      // si el colegio la edita en la web cambia también aquí; la escrita a mano
      // solo vive en su fila.
      final alumno = AlumnoDelLibro.fromJson({
        'alumno_id': 31,
        'nombres': 'X',
        'apellidos': 'Y',
        'frases': [
          {'id': 5, 'frase': 'Del catálogo', 'frase_id': 88},
          {'id': 6, 'frase': 'A mano', 'frase_id': null},
          {'id': 7, 'frase': 'A mano también', 'frase_id': 0},
        ],
      });

      expect(alumno.frases[0].esDelCatalogo, isTrue);
      expect(alumno.frases[1].esDelCatalogo, isFalse);
      expect(alumno.frases[2].esDelCatalogo, isFalse);
    });

    test('el id que se borra es el de la fila, no el del catálogo', () {
      // Confundirlos borraría otra frase de otro alumno.
      final frase = FraseDeAlumno.fromJson({
        'id': 5,
        'frase': 'Participa',
        'frase_id': 88,
      });

      expect(frase.id, 5);
      expect(frase.fraseId, 88);
    });

    test('sin frases no se inventa una lista nula', () {
      final alumno = AlumnoDelLibro.fromJson({
        'alumno_id': 31,
        'nombres': 'X',
        'apellidos': 'Y',
      });

      expect(alumno.frases, isEmpty);
    });

    test('una fila sin id se descarta en vez de colarse como cero', () {
      expect(frasesDeLista([
        {'frase': 'Sin id'},
        {'id': 9, 'frase': 'Con id'},
      ]).map((f) => f.id), [9]);
    });

    test('lo que no sea una lista de objetos no revienta', () {
      expect(frasesDeLista(null), isEmpty);
      expect(frasesDeLista('Sistema bloqueado'), isEmpty);
      expect(frasesDeLista([1, 'dos']), isEmpty);
    });

    test('volver de la ficha con otras frases no vuelve a pedir el libro', () {
      final libro = LibroDeNotas(
        asignatura: AsignaturaModel.fromJson({'asignatura_id': 12}),
        alumnos: [
          const AlumnoDelLibro(alumnoId: 100, nombres: 'A', apellidos: 'B'),
        ],
      );

      final despues = libro.conFrasesDe(100, [
        const FraseDeAlumno(id: 5, frase: 'Nueva'),
      ]);

      expect(despues.alumnos.first.frases.single.frase, 'Nueva');
      expect(libro.alumnos.first.frases, isEmpty);
    });
  });

  group('buscar en el catálogo', () {
    const frase = FraseDelCatalogo(
      id: 1,
      frase: 'Demuestra interés en la asignación',
      tipo: 'Fortaleza',
    );

    test('encuentra sin acentos ni mayúsculas', () {
      // Nadie escribe la tilde en un buscador.
      expect(frase.coincideCon('asignacion'), isTrue);
      expect(frase.coincideCon('INTERÉS'), isTrue);
    });

    test('busca también por el tipo', () {
      // El docente tanto piensa «fortaleza» como recuerda un trozo del texto,
      // y no tiene por qué saber cuál de los dos campos es.
      expect(frase.coincideCon('fortaleza'), isTrue);
    });

    test('una búsqueda vacía las deja todas', () {
      expect(frase.coincideCon(''), isTrue);
      expect(frase.coincideCon('   '), isTrue);
    });

    test('lo que no dice, no lo encuentra', () {
      expect(frase.coincideCon('debilidad'), isFalse);
    });
  });

  group('el texto como se busca', () {
    test('quita acentos, baja a minúsculas y aprieta los espacios', () {
      expect(textoPlano('  Peña   MUÑOZ '), 'pena munoz');
      expect(textoPlano('Situación'), 'situacion');
      expect(textoPlano('Güiro'), 'guiro');
    });

    test('lo vacío se queda vacío', () {
      expect(textoPlano('   '), '');
    });
  });

  group('el historial de una nota', () {
    test('los cambios se leen del más reciente al más viejo', () {
      // Lo que interesa primero es el último cambio: es el que explica lo que
      // se está viendo en pantalla.
      final historial = HistorialDeNota.fromJson({
        'cambios': [
          {'bit_id': 10, 'old_value': 40, 'new_value': 60, 'creado_por': 'Ana'},
          {'bit_id': 22, 'old_value': 60, 'new_value': 85, 'creado_por': 'Ana'},
        ],
        'nota': {'creado_por': 'Sistema', 'modificado_por': 'ana.perez'},
      });

      expect(historial.cambios.map((c) => c.id), [22, 10]);
      expect(historial.cambios.first.anterior, 60);
      expect(historial.cambios.first.nueva, 85);
      expect(historial.creadaPor, 'Sistema');
      expect(historial.modificadaPor, 'ana.perez');
      expect(historial.vacio, isFalse);
    });

    test('una nota que nadie tocó no tiene historial, y no es un error', () {
      final historial = HistorialDeNota.fromJson({
        'cambios': [],
        'nota': {'creado_por': 'Sistema'},
      });

      expect(historial.vacio, isTrue);
      expect(historial.modificadaPor, '');
    });

    test('cuando la nota no existe el backend manda una lista, no un objeto', () {
      // La consulta devuelve `[]` y el controlador lo pasa tal cual, así que
      // leerla como mapa reventaría.
      final historial = HistorialDeNota.fromJson({
        'cambios': [],
        'nota': [],
      });

      expect(historial.creadaPor, '');
      expect(historial.modificadaPor, '');
    });

    test('la fecha se entiende, y si no viene no se inventa', () {
      final historial = HistorialDeNota.fromJson({
        'cambios': [
          {'bit_id': 1, 'created_at': '2026-08-23 14:05:00'},
          {'bit_id': 2, 'created_at': ''},
        ],
      });

      expect(historial.cambios.last.cuando?.hour, 14);
      expect(historial.cambios.first.cuando, isNull);
    });
  });
}
