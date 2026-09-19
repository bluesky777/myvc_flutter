import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/CompetenciaModel.dart';

void main() {
  group('una fila de `GET desempenos`', () {
    test('se lee la carga que manda el servidor', () {
      // `catalogoConSusNombres` añade `materia` y `grado` a cada fila; el modelo
      // no los lee porque la pantalla ya tiene esos nombres de la asignatura,
      // pero vienen y no tienen que estorbar.
      final c = Competencia.fromJson({
        'id': 41,
        'definicion': 'Interpreta gráficas de barras.',
        'tipo': 'Saber',
        'orden': 1,
        'materia_id': 15,
        'materia': 'MATEMÁTICAS',
        'grado_id': 6,
        'grado': 'Sexto',
        'periodo_id': 91,
      });

      expect(c.id, 41);
      expect(c.definicion, 'Interpreta gráficas de barras.');
      expect(c.tipo, 'Saber');
      expect(c.orden, 1);
      expect(c.materiaId, 15);
      expect(c.gradoId, 6);
      expect(c.periodoId, 91);
    });

    test('la de «todos los grados» es del colegio y la de un grado no', () {
      final delColegio = Competencia.fromJson({
        'id': 7,
        'definicion': 'Resuelve problemas de proporcionalidad.',
        'grado_id': null,
        'materia_id': 15,
        'periodo_id': 91,
      });
      final deSexto = Competencia.fromJson({
        'id': 8,
        'definicion': 'Construye figuras planas.',
        'grado_id': 6,
        'materia_id': 15,
        'periodo_id': 91,
      });

      expect(delColegio.esDelColegio, isTrue);
      expect(delColegio.gradoId, isNull);
      expect(deSexto.esDelColegio, isFalse);
    });

    test('un `grado_id` que llega como cadena se lee como el número', () {
      // Los listados se arman con `DB::select`, así que el tipo lo decide PDO.
      final texto = Competencia.fromJson({
        'id': '9',
        'definicion': 'Analiza.',
        'orden': '2',
        'materia_id': '15',
        'grado_id': '11',
        'periodo_id': '91',
      });

      expect(texto.gradoId, 11);
      expect(texto.esDelColegio, isFalse);
      expect(texto.id, 9);
      expect(texto.orden, 2);
      expect(texto.materiaId, 15);
      expect(texto.periodoId, 91);
    });

    test('una respuesta sin `tipo` no rompe: la marca es opcional', () {
      final sinMarca = Competencia.fromJson({
        'id': 10,
        'definicion': 'Escribe textos narrativos.',
        'materia_id': 3,
        'grado_id': 6,
        'periodo_id': 91,
      });
      // `tipo()` en el servidor convierte a null la cadena vacía; si alguna vez
      // llega vacía de la base, aquí vale lo mismo.
      final marcaVacia = Competencia.fromJson({
        'id': 11,
        'definicion': 'Lee en voz alta.',
        'tipo': '',
        'materia_id': 3,
        'grado_id': 6,
        'periodo_id': 91,
      });

      expect(sinMarca.tipo, isNull);
      expect(marcaVacia.tipo, isNull);
      expect(sinMarca.orden, 0);
    });
    test('`con` cambia el texto y la marca y no mueve la fila', () {
      final c = Competencia.fromJson({
        'id': 41,
        'definicion': 'Vieja',
        'tipo': 'Saber',
        'orden': 3,
        'materia_id': 15,
        'grado_id': 6,
        'periodo_id': 91,
      });

      final corregida = c.con(definicion: 'Nueva', tipo: null);

      expect(corregida.definicion, 'Nueva');
      expect(corregida.tipo, isNull);
      expect(corregida.id, 41);
      expect(corregida.orden, 3);
      expect(corregida.gradoId, 6);
      expect(corregida.materiaId, 15);
      expect(corregida.periodoId, 91);
    });
  });

  group('la lista', () {
    test('sale en el orden en que vino: la app no reordena nunca', () {
      // Tal como las manda `getPlantilla`, que ordena por `d.grado_id` y en
      // MySQL los NULL van delante: primero las del colegio, luego las del
      // grado, y el `orden` dentro de cada bloque no tiene por qué ir seguido.
      final lista = competenciasDeLista([
        {'id': 7, 'definicion': 'Del colegio', 'grado_id': null, 'orden': 5},
        {
          'id': 9,
          'definicion': 'Del colegio, la otra',
          'grado_id': null,
          'orden': 9
        },
        {
          'id': 3,
          'definicion': 'De sexto, la segunda',
          'grado_id': 6,
          'orden': 0
        },
        {
          'id': 1,
          'definicion': 'De sexto, la primera',
          'grado_id': 6,
          'orden': 7
        },
      ]);

      expect(lista.map((c) => c.id).toList(), [7, 9, 3, 1]);
      expect(lista.map((c) => c.orden).toList(), [5, 9, 0, 7]);
      expect(lista.first.esDelColegio, isTrue);
      expect(lista.last.esDelColegio, isFalse);
    });

    test('se salta lo que no se puede ni editar ni borrar', () {
      final lista = competenciasDeLista([
        {'id': 41, 'definicion': 'Buena'},
        'esto no es una fila',
        {'definicion': 'Sin id'},
      ]);

      expect(lista.length, 1);
      expect(lista.single.id, 41);
    });

    test('un cuerpo que no es lista no revienta', () {
      expect(competenciasDeLista(null), isEmpty);
      expect(competenciasDeLista({'desempenos': []}), isEmpty);
    });
  });

  group('la asignatura con los ids del plan de área', () {
    test('sin las dos columnas nuevas sigue funcionando y las deja en null',
        () {
      // Es lo que contestan hoy los dieciséis colegios: `fe95da8` no está
      // fundido ni desplegado.
      final a = AsignaturaModel.fromJson({
        'asignatura_id': 1327,
        'grupo_id': 105,
        'profesor_id': 7,
        'materia': 'EDUCACION ARTÍSTICA',
        'alias_materia': 'ART',
        'nombre_grupo': 'Once',
        'abrev_grupo': '11',
      });

      expect(a.materiaId, isNull);
      expect(a.gradoId, isNull);
      expect(a.id, 1327);
      expect(a.materia, 'EDUCACION ARTÍSTICA');
    });

    test('cuando vienen se leen, también como cadena', () {
      final a = AsignaturaModel.fromJson({
        'asignatura_id': 1327,
        'grupo_id': 105,
        'materia': 'MATEMÁTICAS',
        'alias_materia': 'MAT',
        'nombre_grupo': 'Sexto A',
        'abrev_grupo': '6A',
        'materia_id': '15',
        'grado_id': 6,
      });

      expect(a.materiaId, 15);
      expect(a.gradoId, 6);
    });
  });
}
