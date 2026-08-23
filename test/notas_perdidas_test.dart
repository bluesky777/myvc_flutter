import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/NotasPerdidasApi.dart';

/// El árbol tal como lo devuelve `notas-perdidas/profesor-grupos`.
List<GrupoConPerdidas> arbolDePrueba() {
  return [
    GrupoConPerdidas.fromJson({
      'grupo_id': 3,
      'nombre': 'Décimo B',
      'abrev': '10-B',
      'nombre_grado': 'Décimo',
      'asignaturas': [
        {
          'asignatura_id': 12,
          'materia': 'Matemáticas',
          'alias': 'Mate',
          'alumnos': [
            {
              'alumno_id': 100,
              'nombres': 'Ana',
              'apellidos': 'Acosta',
              'nee': 1,
              'userData': {'foto_nombre': 'user_2/ana.jpg'},
              'notas': [
                {
                  'nota_id': 900,
                  'nota': 40,
                  'numero_periodo': 1,
                  'orden_unidad': 1,
                  'orden_subunidad': 2,
                  'defin_subunidad': 'Quiz',
                  'defin_unidad': 'Fracciones',
                },
                {
                  'nota_id': 901,
                  'nota': '35.5',
                  'numero_periodo': 3,
                  'orden_unidad': 1,
                  'orden_subunidad': 1,
                  'defin_subunidad': 'Taller',
                  'defin_unidad': 'Fracciones',
                },
              ],
            },
            {
              'alumno_id': 101,
              'nombres': 'Luis',
              'apellidos': 'Bolaño',
              'userData': {'': null},
              'notas': [
                {'nota_id': 902, 'nota': 20, 'numero_periodo': 3},
              ],
            },
          ],
        },
        {
          'asignatura_id': 13,
          'materia': 'Física',
          'alias': '',
          'alumnos': [
            {
              'alumno_id': 100,
              'nombres': 'Ana',
              'apellidos': 'Acosta',
              'notas': [
                {'nota_id': 903, 'nota': 10, 'numero_periodo': 1},
              ],
            },
          ],
        },
      ],
    }),
  ];
}

void main() {
  group('leer el árbol', () {
    test('los recuentos suben de nivel en nivel', () {
      final grupo = arbolDePrueba().first;

      expect(grupo.asignaturas.length, 2);
      expect(grupo.cuantosAlumnos, 3);
      expect(grupo.cuantasNotas, 4);
      expect(grupo.asignaturas.first.cuantasNotas, 3);
    });

    test('la foto sale de userData, no de la fila del alumno', () {
      // La consulta de alumnos solo trae `foto_id`; el archivo, con su valor
      // por defecto según el sexo, viene dentro de userData.
      final alumno = arbolDePrueba().first.asignaturas.first.alumnos.first;

      expect(alumno.fotoNombre, 'user_2/ana.jpg');
      expect(alumno.nee, isTrue);
    });

    test('un alumno sin cuenta de usuario no revienta', () {
      // Ahí el backend devuelve `{"": null}` en vez de un objeto vacío.
      final alumno = arbolDePrueba().first.asignaturas.first.alumnos[1];

      expect(alumno.fotoNombre, isNull);
      expect(alumno.nee, isFalse);
    });

    test('las notas se ordenan por periodo antes que por unidad', () {
      // El periodo manda: lo del primero va arriba aunque sea de una unidad
      // posterior. Es como se lee un año, de principio a fin.
      final alumno = arbolDePrueba().first.asignaturas.first.alumnos.first;

      expect(alumno.notas.map((n) => n.notaId), [900, 901]);
    });

    test('dentro de un periodo mandan la unidad y luego la subunidad', () {
      final alumno = AlumnoConPerdidas.fromJson({
        'alumno_id': 1,
        'nombres': 'X',
        'apellidos': 'Y',
        'notas': [
          {'nota_id': 3, 'numero_periodo': 1, 'orden_unidad': 2, 'orden_subunidad': 1},
          {'nota_id': 2, 'numero_periodo': 1, 'orden_unidad': 1, 'orden_subunidad': 2},
          {'nota_id': 1, 'numero_periodo': 1, 'orden_unidad': 1, 'orden_subunidad': 1},
        ],
      });

      expect(alumno.notas.map((n) => n.notaId), [1, 2, 3]);
    });

    test('los decimales llegan como cadena según el driver', () {
      final alumno = arbolDePrueba().first.asignaturas.first.alumnos.first;

      expect(alumno.notas[0].nota, 40);
      expect(alumno.notas[1].nota, 35.5);
    });

    test('la asignatura se rotula con su alias, y si no lo tiene con la materia', () {
      final asignaturas = arbolDePrueba().first.asignaturas;

      expect(asignaturas[0].comoSeLlama, 'Mate');
      expect(asignaturas[1].comoSeLlama, 'Física');
    });
  });

  group('filtrar por periodo', () {
    test('sin periodo devuelve el árbol tal cual', () {
      final arbol = arbolDePrueba();

      expect(identical(soloDelPeriodo(arbol, null), arbol), isTrue);
    });

    test('el corte va de abajo arriba y no deja niveles vacíos', () {
      // Si solo se filtraran las notas, quedarían alumnos con cero notas,
      // asignaturas con cero alumnos y grupos con cero asignaturas. Una lista
      // de cajas vacías es peor que no filtrar.
      final soloTres = soloDelPeriodo(arbolDePrueba(), 3);

      expect(soloTres.length, 1);
      // Física solo tenía notas del periodo 1: desaparece entera.
      expect(soloTres.first.asignaturas.length, 1);
      expect(soloTres.first.asignaturas.first.alumnos.length, 2);
      expect(soloTres.first.cuantasNotas, 2);
    });

    test('un periodo sin nada perdido deja la lista vacía, no a medias', () {
      expect(soloDelPeriodo(arbolDePrueba(), 4), isEmpty);
    });

    test('filtrar no toca el árbol original', () {
      final arbol = arbolDePrueba();
      soloDelPeriodo(arbol, 3);

      expect(arbol.first.cuantasNotas, 4);
      expect(arbol.first.asignaturas.length, 2);
    });
  });

  group('los chips que se ofrecen', () {
    test('solo los periodos que tienen algo perdido', () {
      // Ofrecer los cuatro siempre sería ofrecer filtros que dejan la pantalla
      // en blanco, y eso se lee como un fallo de la app.
      expect(periodosConPerdidas(arbolDePrueba()), [1, 3]);
    });

    test('un árbol vacío no ofrece ninguno', () {
      expect(periodosConPerdidas(const []), isEmpty);
    });
  });

  test('pedir el año entero es un número de periodo que no existe', () {
    // El backend traduce el número a `p.numero <= :periodo`, así que un 10
    // —que ningún colegio tiene— significa «todos».
    expect(todosLosPeriodos, 10);
  });
}
