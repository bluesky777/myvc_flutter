import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/FormatoDeNota.dart';

/// Un libro de una unidad al 100 % con dos subunidades al 50 % cada una.
LibroDeNotas libroCon(Map<int, double?> notas) {
  return LibroDeNotas(
    asignatura: AsignaturaModel.fromJson({'asignatura_id': 12, 'grupo_id': 3}),
    unidades: [
      UnidadModel(
        id: 1,
        definicion: 'Unidad única',
        porcentaje: 100,
        subunidades: [
          SubunidadModel(
              id: 5, unidadId: 1, definicion: 'Quiz', porcentaje: 50),
          SubunidadModel(
              id: 6, unidadId: 1, definicion: 'Taller', porcentaje: 50),
        ],
      ),
    ],
    alumnos: [
      AlumnoDelLibro(
        alumnoId: 100,
        nombres: 'Ana',
        apellidos: 'Acosta',
        notas: {
          for (final entrada in notas.entries)
            entrada.key: NotaDelLibro(
              id: 900 + entrada.key,
              subunidadId: entrada.key,
              nota: entrada.value,
            ),
        },
      ),
    ],
  );
}

void main() {
  group('el promedio automático', () {
    test('pondera por la unidad y por la subunidad', () {
      final libro = libroCon({5: 80, 6: 60});

      // 100 % de la unidad × (50 % × 80 + 50 % × 60) = 70
      expect(libro.promedioDe(libro.alumnos.first), closeTo(70, 0.001));
    });

    test('una casilla sin nota no suma, no cuenta como cero al dividir', () {
      // Es lo que hace el SQL del backend: un NULL no entra en el SUM. Con 80
      // en una sola de las dos mitades el promedio es 40, no 80.
      final libro = libroCon({5: 80, 6: null});

      expect(libro.promedioDe(libro.alumnos.first), closeTo(40, 0.001));
    });

    test('lo escrito y sin guardar ya mueve el promedio', () {
      // La gracia de nivelar es ver a dónde llega el promedio ANTES de decidir
      // la definitiva. Un número que solo se refresca al recargar no sirve.
      final libro = libroCon({5: 80, 6: 60});

      expect(
        libro.promedioDe(libro.alumnos.first, sobrescritas: {6: 100}),
        closeTo(90, 0.001),
      );
    });

    test('vaciar una casilla la saca de la cuenta', () {
      // La clave está presente con valor nulo: es una casilla que se acaba de
      // borrar, no una que no se tocó. Por eso se mira containsKey.
      final libro = libroCon({5: 80, 6: 60});

      expect(
        libro.promedioDe(libro.alumnos.first, sobrescritas: {6: null}),
        closeTo(40, 0.001),
      );
    });

    test('una subunidad sin fila de nota tampoco suma', () {
      final libro = libroCon({5: 80});

      expect(libro.promedioDe(libro.alumnos.first), closeTo(40, 0.001));
    });
  });

  group('las dos banderas de la definitiva', () {
    const automatica = NotaFinalDelLibro(nfId: 77, nota: 70, manual: false);

    test('cambiar la nota la deja puesta a mano', () {
      // El backend hace `SET nota=?, manual=true` en la misma sentencia: no
      // existe corregir el número dejándola automática.
      final despues = automatica.trasCambiarLaNota(85);

      expect(despues.nota, 85);
      expect(despues.manual, isTrue);
    });

    test('cambiar la nota la pone al día', () {
      const vieja = NotaFinalDelLibro(
        nfId: 77,
        nota: 70,
        manual: true,
        desactualizada: true,
      );

      expect(vieja.trasCambiarLaNota(85).desactualizada, isFalse);
    });

    test('quitarle «a mano» le quita también «recuperada»', () {
      // Una recuperada que dejara de ser manual se perdería en el primer
      // recálculo, y el backend lo hace en la misma sentencia.
      const puesta = NotaFinalDelLibro(
        nfId: 77,
        nota: 70,
        manual: true,
        recuperada: true,
      );

      final despues = puesta.trasAlternarManual(false);

      expect(despues.manual, isFalse);
      expect(despues.recuperada, isFalse);
    });

    test('marcar «a mano» no toca «recuperada»', () {
      expect(automatica.trasAlternarManual(true).recuperada, isFalse);

      const recuperada =
          NotaFinalDelLibro(nfId: 77, manual: false, recuperada: true);
      expect(recuperada.trasAlternarManual(true).recuperada, isTrue);
    });

    test('marcar «recuperada» la vuelve además «a mano»', () {
      final despues = automatica.trasAlternarRecuperada(true);

      expect(despues.recuperada, isTrue);
      expect(despues.manual, isTrue);
    });

    test('desmarcar «recuperada» deja «a mano» como estaba', () {
      const puesta = NotaFinalDelLibro(
        nfId: 77,
        manual: true,
        recuperada: true,
      );

      expect(puesta.trasAlternarRecuperada(false).manual, isTrue);
    });

    test('sin fila en notas_finales no hay nada que nivelar', () {
      const sinFila = NotaFinalDelLibro(nfId: 0);

      expect(sinFila.existe, isFalse);
      expect(automatica.existe, isTrue);
    });

    test('«desactualizada» se lee con la polaridad del backend', () {
      // `IF(nf.updated_at > max(notas.updated_at), FALSE, TRUE)`: el 1 es la
      // definitiva vieja, y el 0 la que ya está al día.
      final vieja = NotaFinalDelLibro.fromJson({
        'nf_id': 1,
        'nfinal_desactualizada': 1,
      });
      final alDia = NotaFinalDelLibro.fromJson({
        'nf_id': 1,
        'nfinal_desactualizada': 0,
      });

      expect(vieja.desactualizada, isTrue);
      expect(alDia.desactualizada, isFalse);
    });
  });

  group('volver de la ficha', () {
    test('la definitiva nueva entra sin volver a pedir el libro', () {
      final libro = libroCon({5: 80, 6: 60});

      final despues = libro.conNotaFinalDe(
        100,
        const NotaFinalDelLibro(nfId: 77, nota: 95, manual: true),
      );

      expect(despues.alumnos.first.notaFinal?.nota, 95);
      // Y el de antes no cambia: los modelos son inmutables.
      expect(libro.alumnos.first.notaFinal, isNull);
    });

    test('a un alumno que no es no le cambia nada', () {
      final libro = libroCon({5: 80});

      final despues = libro.conNotaFinalDe(
        999,
        const NotaFinalDelLibro(nfId: 77, nota: 95),
      );

      expect(despues.alumnos.first.notaFinal, isNull);
    });
  });

  group('lo que se escribe y se lee en un campo de nota', () {
    test('una nota redonda se escribe sin decimales', () {
      // Un campo que dice «85.0» invita a borrar el punto antes de teclear.
      expect(notaEnCasilla(85), '85');
      expect(notaEnCasilla(85.5), '85.5');
      expect(notaEnCasilla(null), '');
    });

    test('en un campo la nota decimal va entera, no redondeada', () {
      // Lo que hay en la casilla es lo que se vuelve a guardar: redondear aquí
      // guardaría el redondeo, que es el que la migración vino a quitar.
      expect(notaEnCasilla(43.75), '43.75');
      expect(notaEnCasilla(43.7500), '43.75');
    });

    test('pintada, en cambio, va entera como en el boletín', () {
      // La otra mitad de la regla, y la razón de que sean dos funciones: el
      // mismo 43,75 se pinta «44» y se edita «43.75».
      expect(notaPintada(43.75), '44');
      expect(notaPintada(43.2), '43');
      expect(notaPintada(85), '85');
      expect(notaPintada(null), '—');
    });

    test('la coma vale como separador decimal', () {
      // Es la que trae el teclado en español.
      expect(notaLeida('85,5'), 85.5);
      expect(notaLeida(' 90 '), 90);
    });

    test('lo vacío y lo que no se entiende son null, no cero', () {
      expect(notaLeida(''), isNull);
      expect(notaLeida('   '), isNull);
      expect(notaLeida('ochenta'), isNull);
      expect(notaLeida('0'), 0);
    });
  });

  group('guardar una nota recalcula la definitiva', () {
    // `notas/update` no solo escribe la nota: al final llama a
    // DefinitivasDeAsignatura::recalcularPorNota. Si la app no lo apuntara, la
    // pestaña «Por alumno» seguiría enseñando la definitiva de antes.

    LibroDeNotas libroConDefinitiva(NotaFinalDelLibro definitiva) {
      final base = libroCon({5: 80, 6: 60});
      return base.conNotaFinalDe(100, definitiva);
    }

    test('la automática pasa a ser el promedio nuevo, SIN redondear', () {
      // Antes esto esperaba 86: el backend casteaba a DECIMAL(4,0) y la app le
      // copiaba el redondeo. Desde la migración guarda DECIMAL(7,4), así que
      // redondear aquí enseñaría 86 con 85,5 en la base hasta recargar.
      final libro = libroConDefinitiva(
        const NotaFinalDelLibro(nfId: 77, nota: 70),
      );

      final despues = libro.conNotas([
        const NotaPendiente(notaId: 906, alumnoId: 100, nota: 91),
      ]);

      // 50 % × 80 + 50 % × 91 = 85,5, y 85,5 es lo que se guarda
      expect(despues.promedioDe(despues.alumnos.first), closeTo(85.5, 0.001));
      expect(despues.alumnos.first.notaFinal?.nota, closeTo(85.5, 0.001));
    });

    test('la manual se respeta, que es lo que hace el backend', () {
      final libro = libroConDefinitiva(
        const NotaFinalDelLibro(nfId: 77, nota: 95, manual: true),
      );

      final despues = libro.conNotas([
        const NotaPendiente(notaId: 906, alumnoId: 100, nota: 91),
      ]);

      expect(despues.alumnos.first.notaFinal?.nota, 95);
    });

    test('la recuperada también se respeta', () {
      final libro = libroConDefinitiva(
        const NotaFinalDelLibro(nfId: 77, nota: 60, recuperada: true),
      );

      final despues = libro.conNotas([
        const NotaPendiente(notaId: 906, alumnoId: 100, nota: 91),
      ]);

      expect(despues.alumnos.first.notaFinal?.nota, 60);
    });

    test('a un alumno cuyas notas no cambiaron no se le toca la definitiva', () {
      final libro = libroConDefinitiva(
        const NotaFinalDelLibro(nfId: 77, nota: 70),
      );

      final despues = libro.conNotas(const []);

      expect(despues.alumnos.first.notaFinal?.nota, 70);
    });

    test('sin fila de definitiva no se inventa una', () {
      final libro = libroCon({5: 80, 6: 60});

      final despues = libro.conNotas([
        const NotaPendiente(notaId: 906, alumnoId: 100, nota: 91),
      ]);

      expect(despues.alumnos.first.notaFinal, isNull);
    });
  });
}
