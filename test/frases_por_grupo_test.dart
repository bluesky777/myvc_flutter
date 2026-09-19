import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/FrasesApi.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';

/// Las dos rutas del grupo entero: `GET` y
/// `PUT frases_asignatura/grupo/{asignatura_id}`.
///
/// Lo que se prueba aquí es el contrato, no el transporte: las cuatro cosas que
/// se pueden romper sin que nada deje de compilar —la población que se pierde,
/// los dos textos que se confunden, la lista vacía que se lee como ausente y el
/// botón que se pinta contra el campo que no es— y el número que llega como
/// cadena porque lo trae `DB::select`.
void main() {
  group('el grupo que contesta el GET', () {
    test('dice en qué periodo se leyó y quién puede escribir', () {
      // El periodo viaja en la respuesta porque es opcional en la petición: sin
      // él manda el de la sesión, y una pantalla que no sepa cuál le tocó no
      // puede avisar de que le tocó el que no era.
      final leido = LecturaDeFrasesDelGrupo.fromJson({
        'asignatura_id': 129,
        'grupo_id': 3,
        'year_id': 1,
        'periodo_id': 2,
        'periodo_abierto': true,
        'puede_escribir': true,
        'alumnos': [],
        'poblacion': {'alumnos': 0},
      });

      expect(leido.grupo.asignaturaId, 129);
      expect(leido.grupo.grupoId, 3);
      expect(leido.grupo.yearId, 1);
      expect(leido.grupo.periodoId, 2);
      expect(leido.grupo.puedeEscribir, isTrue);
    });

    test('puede_escribir no es periodo_abierto, y el botón va con el primero',
        () {
      // Un administrativo escribe con el periodo cerrado y un docente no.
      // Pintar el botón contra el periodo deja al administrativo sin pantalla y
      // al docente con un 403 que parece un fallo de la app.
      final administrativo = FrasesDelGrupo.fromJson({
        'periodo_abierto': false,
        'puede_escribir': true,
      });

      expect(administrativo.periodoAbierto, isFalse);
      expect(administrativo.puedeEscribir, isTrue);

      final docente = FrasesDelGrupo.fromJson({
        'periodo_abierto': false,
        'puede_escribir': false,
      });

      expect(docente.puedeEscribir, isFalse);
    });

    test('un sí que llega como 1 o como "1" también es un sí', () {
      // El backend los calcula en PHP, pero esta familia se arma con
      // `DB::select` y lo que salga de una columna lo decide PDO.
      expect(FrasesDelGrupo.fromJson({'puede_escribir': 1}).puedeEscribir,
          isTrue);
      expect(FrasesDelGrupo.fromJson({'puede_escribir': '1'}).puedeEscribir,
          isTrue);
      expect(FrasesDelGrupo.fromJson({'puede_escribir': '0'}).puedeEscribir,
          isFalse);
    });

    test('sin puede_escribir la pantalla se queda en lectura', () {
      // Una respuesta que no lo traiga —un colegio con el backend de antes— no
      // puede acabar en un botón que promete guardar lo que se va a perder.
      expect(FrasesDelGrupo.fromJson({'grupo_id': 3}).puedeEscribir, isFalse);
    });

    test('los alumnos vienen con sus frases, y los que no tienen con la vacía',
        () {
      final leido = LecturaDeFrasesDelGrupo.fromJson({
        'alumnos': [
          {
            'alumno_id': 12,
            'matricula_id': 31,
            'nombres': 'Ana',
            'apellidos': 'Pérez',
            'frases': [
              {
                'id': 8421,
                'frase': 'Comparte con sus compañeros.',
                'frase_escrita': 'Comparte con sus compañeros.',
                'frase_id': null,
                'tipo_frase': null,
                'created_at': '2018-04-02 10:11:12',
              },
            ],
          },
          {'alumno_id': 13, 'nombres': 'Luis', 'apellidos': 'Díaz'},
        ],
        'poblacion': {'alumnos': 2},
      });

      expect(leido.grupo.alumnos, hasLength(2));
      expect(leido.grupo.alumnos.first.nombreCompleto, 'Pérez Ana');
      expect(leido.grupo.alumnos.first.matriculaId, 31);
      expect(leido.grupo.alumnos.first.frases.single.creadaEl,
          '2018-04-02 10:11:12');
      expect(leido.grupo.alumnos.last.frases, isEmpty);
    });

    test('una fila sin id no se cuela como cero', () {
      // Un id 0 en el cuerpo del PUT es un 422, así que una fila así no puede
      // llegar a la pantalla como si fuera guardable.
      final alumno = AlumnoConFrases.fromJson({
        'alumno_id': 12,
        'frases': [
          {'frase': 'Sin id'},
          {'id': 9, 'frase': 'Con id'},
        ],
      });

      expect(alumno.frases.map((f) => f.id), [9]);
    });

    test('lo que no sea el sobre esperado no revienta', () {
      final leido = LecturaDeFrasesDelGrupo.fromJson({'alumnos': 'Sistema'});

      expect(leido.grupo.alumnos, isEmpty);
      expect(leido.poblacion.alumnos, 0);
    });
  });

  group('frase y frase_escrita, que no son el mismo texto', () {
    test('una del catálogo y una a mano que dicen lo mismo se distinguen', () {
      // Con un solo campo serían idénticas, y el PUT dejaría de saber si un
      // guardado cambia algo: el catálogo lo resuelve el boletín con un IFNULL
      // y la escrita a mano vive en su fila.
      final delCatalogo = FraseDelGrupo.fromJson({
        'id': 1,
        'frase': 'Reconoce las vocales.',
        'frase_escrita': null,
        'frase_id': 55,
        'tipo_frase': 'Fortaleza',
      });

      final aMano = FraseDelGrupo.fromJson({
        'id': 2,
        'frase': 'Reconoce las vocales.',
        'frase_escrita': 'Reconoce las vocales.',
        'frase_id': null,
      });

      expect(delCatalogo.frase, aMano.frase);
      expect(delCatalogo.fraseEscrita, isNull);
      expect(aMano.fraseEscrita, 'Reconoce las vocales.');
      expect(delCatalogo.esDelCatalogo, isTrue);
      expect(aMano.esDelCatalogo, isFalse);
      expect(delCatalogo.tipo, 'Fortaleza');
    });

    test('lo que se edita en la casilla es lo de la fila, no lo del boletín',
        () {
      // Enseñar el texto del catálogo en la casilla y volverlo a mandar
      // convertiría la frase en escrita a mano: dejaría de seguir al catálogo
      // el día que el colegio lo corrija.
      const delCatalogo = FraseDelGrupo(
        id: 1,
        frase: 'La del catálogo',
        fraseEscrita: null,
        fraseId: 55,
      );

      expect(delCatalogo.textoAMano, '');

      const sinFraseEscrita = FraseDelGrupo(id: 2, frase: 'La suya');

      expect(sinFraseEscrita.textoAMano, 'La suya');
    });
  });

  group('la población de lo leído', () {
    test('los contadores llegan como cadena y se leen como número', () {
      // `DB::select` y PDO: un COUNT(*) puede llegar de las dos formas según la
      // conexión del colegio.
      final poblacion = PoblacionLeida.fromJson({
        'alumnos': '18',
        'frases': '36',
        'alumnos_con_frases': '18',
        'alumnos_sin_frases': '0',
        'frases_fuera_del_grupo': '12',
      });

      expect(poblacion.alumnos, 18);
      expect(poblacion.frases, 36);
      expect(poblacion.alumnosConFrases, 18);
      expect(poblacion.frasesFueraDelGrupo, 12);
    });

    test('las frases de fuera del grupo no se pierden por el camino', () {
      // Frases vivas de alumnos que ya no están matriculados. La pantalla no
      // las enseña, pero un retirado con frases tiene que poder saberse.
      final leido = LecturaDeFrasesDelGrupo.fromJson({
        'alumnos': [],
        'poblacion': {'alumnos': 18, 'frases_fuera_del_grupo': 12},
      });

      expect(leido.poblacion.frasesFueraDelGrupo, 12);
      expect(leido.poblacion.hayFrasesFueraDelGrupo, isTrue);
    });

    test('«no hay ninguna» y «no se miró» no se leen igual', () {
      // Es la razón de que sea int? y no un cero de respaldo: con un cero, un
      // renglón que no vino se leería como un grupo sin retirados.
      final miradas = PoblacionLeida.fromJson({'frases_fuera_del_grupo': 0});
      final sinMirar = PoblacionLeida.fromJson({'alumnos': 18});

      expect(miradas.frasesFueraDelGrupo, 0);
      expect(miradas.seMiraronLasDeFuera, isTrue);
      expect(miradas.hayFrasesFueraDelGrupo, isFalse);

      expect(sinMirar.frasesFueraDelGrupo, isNull);
      expect(sinMirar.seMiraronLasDeFuera, isFalse);
      expect(sinMirar.hayFrasesFueraDelGrupo, isFalse);
    });
  });

  group('lo que viaja al guardar', () {
    test('la lista vacía dice «quítaselas todas» y la clave siempre sale', () {
      // `frases: []` y omitir la clave son cosas distintas —la segunda es un
      // 422— y el tipo las separa: `frases` es obligatorio y no admite null, de
      // modo que el cuerpo no se puede escribir sin la clave.
      final cuerpo = cuerpoDeGuardarFrasesDelGrupo(alumnos: [
        const FrasesDeUnAlumno(alumnoId: 13, frases: []),
      ]);

      final alumnos = cuerpo['alumnos'] as List;

      expect(alumnos.single.containsKey('frases'), isTrue);
      expect(alumnos.single['frases'], isEmpty);
    });

    test('mandar un alumno no nombra a los demás, y por eso no les borra nada',
        () {
      // Un alumno que no viene en el cuerpo no se mira: es lo que hace seguro
      // guardar de a poco o por páginas.
      final cuerpo = cuerpoDeGuardarFrasesDelGrupo(alumnos: [
        FrasesDeUnAlumno(alumnoId: 12, frases: [
          const FraseParaGuardar.aMano('Reconoce las vocales.'),
        ]),
      ]);

      final alumnos = cuerpo['alumnos'] as List;

      expect(alumnos, hasLength(1));
      expect(alumnos.single['alumno_id'], 12);
    });

    test('la del catálogo viaja con su frase_id y sin texto', () {
      // Si viajaran los dos ganaría el frase_id igual, pero mandar el texto es
      // pedir que alguien lo lea como la frase de la fila.
      expect(const FraseParaGuardar.delCatalogo(55).paraElCuerpo(),
          {'frase_id': 55});
    });

    test('la escrita a mano viaja con su texto y sin frase_id', () {
      expect(const FraseParaGuardar.aMano('Comparte.').paraElCuerpo(),
          {'frase': 'Comparte.'});
    });

    test('la que ya existía vuelve con su id, que es lo que la conserva', () {
      expect(const FraseParaGuardar.aMano('Comparte.', id: 8421).paraElCuerpo(),
          {'id': 8421, 'frase': 'Comparte.'});
    });

    test('vaciar la casilla es una entrada vacía con su id', () {
      // Es la forma de decir «esta fila se va» sin sacarla de la lista, y el
      // servidor la cuenta en `vacias`.
      expect(const FraseParaGuardar.aMano('', id: 8421).paraElCuerpo(),
          {'id': 8421, 'frase': ''});
    });

    test('devolver lo leído no convierte una del catálogo en escrita a mano',
        () {
      // El GET trae los dos textos; reenviar el del boletín le quitaría a la
      // frase su frase_id y dejaría de seguir al catálogo.
      final alumno = AlumnoConFrases.fromJson({
        'alumno_id': 12,
        'frases': [
          {
            'id': 8421,
            'frase': 'La del catálogo',
            'frase_escrita': null,
            'frase_id': 55,
          },
          {
            'id': 8422,
            'frase': 'La suya',
            'frase_escrita': 'La suya',
            'frase_id': null,
          },
        ],
      });

      final cuerpo = FrasesDeUnAlumno.deLoLeido(alumno).paraElCuerpo();

      expect(cuerpo['frases'], [
        {'id': 8421, 'frase_id': 55},
        {'id': 8422, 'frase': 'La suya'},
      ]);
    });

    test('el periodo sólo viaja si se pidió uno', () {
      // Sin la clave manda el periodo de la sesión, que es lo que hacen las
      // rutas de una en una.
      final conPeriodo = cuerpoDeGuardarFrasesDelGrupo(
        alumnos: [const FrasesDeUnAlumno(alumnoId: 12, frases: [])],
        periodoId: 2,
      );
      final sinPeriodo = cuerpoDeGuardarFrasesDelGrupo(
        alumnos: [const FrasesDeUnAlumno(alumnoId: 12, frases: [])],
      );

      expect(conPeriodo['periodo_id'], 2);
      expect(sinPeriodo.containsKey('periodo_id'), isFalse);
    });
  });

  group('la población de lo guardado', () {
    test('dice qué pasó, y «no cambió nada» no es «no se guardó»', () {
      // Es justo lo que pregunta quien cree que ha perdido el trabajo.
      final poblacion = PoblacionGuardada.fromJson({
        'alumnos_del_grupo': 18,
        'alumnos_revisados': 1,
        'frases_revisadas': 3,
        'escritas': 0,
        'cambiadas': 0,
        'sin_cambio': 3,
        'borradas': 0,
        'vacias': 0,
      });

      expect(poblacion.sinCambio, 3);
      expect(poblacion.noCambioNada, isTrue);
      expect(poblacion.filasTocadas, 0);
    });

    test('los contadores también llegan como cadena', () {
      final poblacion = PoblacionGuardada.fromJson({
        'alumnos_del_grupo': '18',
        'alumnos_revisados': '18',
        'frases_revisadas': '36',
        'escritas': '2',
        'cambiadas': '1',
        'sin_cambio': '30',
        'borradas': '4',
        'vacias': '3',
      });

      expect(poblacion.alumnosDelGrupo, 18);
      expect(poblacion.escritas, 2);
      expect(poblacion.cambiadas, 1);
      expect(poblacion.borradas, 4);
      expect(poblacion.vacias, 3);
      expect(poblacion.filasTocadas, 7);
      expect(poblacion.noCambioNada, isFalse);
    });

    test('una respuesta sin población no se inventa contadores', () {
      expect(PoblacionGuardada.fromJson(null).frasesRevisadas, 0);
      expect(PoblacionGuardada.fromJson('OK').alumnosRevisados, 0);
    });

    test('el grupo releído trae las filas nuevas ya con su id', () {
      // Es lo que le ahorra al front la petición de después: con esto el
      // guardado siguiente ya puede conservarlas.
      final grupo = FrasesDelGrupo.fromJson({
        'periodo_id': 2,
        'puede_escribir': true,
        'alumnos': [
          {
            'alumno_id': 12,
            'frases': [
              {'id': 9001, 'frase': 'Recién escrita', 'frase_escrita': 'Recién escrita'},
            ],
          },
        ],
      });

      expect(grupo.alumnos.single.frases.single.id, 9001);
      expect(
        FraseParaGuardar.deLaFila(grupo.alumnos.single.frases.single)
            .paraElCuerpo(),
        {'id': 9001, 'frase': 'Recién escrita'},
      );
    });
  });
}
