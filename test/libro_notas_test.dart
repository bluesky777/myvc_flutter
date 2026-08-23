import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';

void main() {
  group('un alumno del libro', () {
    test('sus notas se indexan por subunidad', () {
      final alumno = AlumnoDelLibro.fromJson({
        'alumno_id': 31,
        'nombres': 'Dámaris',
        'apellidos': 'Gómez Pico',
        'foto_nombre': 'user_2/damaris.jpg',
        'estado': 'MATR',
        'ausencias_count': 2,
        'tardanzas_count': 1,
        'notas': [
          {'id': 900, 'subunidad_id': 5, 'nota': 85},
          {'id': 901, 'subunidad_id': 6, 'nota': '40.0'},
        ],
      });

      expect(alumno.nombreEnLista, 'Gómez Pico Dámaris');
      expect(alumno.notaDe(5)?.nota, 85);
      expect(alumno.notaDe(5)?.id, 900);
      // Los decimales llegan como cadena según el driver de PDO.
      expect(alumno.notaDe(6)?.nota, 40);
      expect(alumno.notaDe(99), isNull);
      expect(alumno.ausenciasCount, 2);
    });

    test('una casilla sin nota no es un cero', () {
      // El cero es una nota; la ausencia de nota es otra cosa, y pintarlas
      // igual haría que un campo vacío se leyera como un alumno con cero.
      final alumno = AlumnoDelLibro.fromJson({
        'alumno_id': 31,
        'nombres': 'X',
        'apellidos': 'Y',
        'notas': [
          {'id': 900, 'subunidad_id': 5, 'nota': null},
          {'id': 901, 'subunidad_id': 6, 'nota': 0},
        ],
      });

      expect(alumno.notaDe(5)?.nota, isNull);
      expect(alumno.notaDe(5)?.puesta, isFalse);
      expect(alumno.notaDe(6)?.nota, 0);
      expect(alumno.notaDe(6)?.puesta, isTrue);
    });

    test('la definitiva viene con sus dos banderas', () {
      final alumno = AlumnoDelLibro.fromJson({
        'alumno_id': 31,
        'nombres': 'X',
        'apellidos': 'Y',
        'nota_final': {
          'nf_id': 77,
          'nota_final': 72,
          'def_materia_auto': '68.5',
          'manual': 1,
          'recuperada': 0,
        },
      });

      expect(alumno.notaFinal?.nfId, 77);
      expect(alumno.notaFinal?.nota, 72);
      expect(alumno.notaFinal?.automatica, 68.5);
      expect(alumno.notaFinal?.manual, isTrue);
      expect(alumno.notaFinal?.recuperada, isFalse);
    });
  });

  group('el libro', () {
    LibroDeNotas libroCon(List<double?> notas) {
      return LibroDeNotas(
        asignatura: AsignaturaModel.fromJson({
          'asignatura_id': 12,
          'grupo_id': 3,
          'materia': 'Matemáticas',
        }),
        alumnos: [
          for (var i = 0; i < notas.length; i++)
            AlumnoDelLibro(
              alumnoId: 100 + i,
              nombres: 'Alumno',
              apellidos: '$i',
              notas: {
                5: NotaDelLibro(id: 900 + i, subunidadId: 5, nota: notas[i]),
              },
            ),
        ],
      );
    }

    test('cuenta cuántas notas hay puestas en una casilla', () {
      final libro = libroCon([85, null, 40, null]);

      expect(libro.notasPuestasEn(5), 2);
      expect(libro.notasPuestasEn(6), 0);
    });

    test('aplicar lo guardado no vuelve a pedir nada', () {
      // Al volver de una planilla, lo que quedó guardado se sabe: es lo que se
      // mandó y el servidor aceptó. `notas/detailed` es demasiado cara para
      // gastarla en refrescar un contador.
      final libro = libroCon([null, null, null]);

      final despues = libro.conNotas([
        const NotaPendiente(notaId: 900, alumnoId: 100, nota: 90),
        const NotaPendiente(notaId: 902, alumnoId: 102, nota: 30),
      ]);

      expect(despues.notasPuestasEn(5), 2);
      expect(despues.alumnos[0].notaDe(5)?.nota, 90);
      expect(despues.alumnos[1].notaDe(5)?.nota, isNull);
      expect(despues.alumnos[2].notaDe(5)?.nota, 30);
    });

    test('sin nada guardado devuelve el mismo libro', () {
      final libro = libroCon([85]);

      expect(identical(libro.conNotas(const []), libro), isTrue);
    });

    test('el libro de antes no cambia', () {
      // Los modelos son inmutables: el que se aplicó sigue diciendo lo que
      // decía, y quien lo tuviera referenciado no ve cambios por sorpresa.
      final libro = libroCon([null]);
      libro.conNotas([
        const NotaPendiente(notaId: 900, alumnoId: 100, nota: 90),
      ]);

      expect(libro.alumnos[0].notaDe(5)?.nota, isNull);
    });
  });
}
