import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Utils/MarcasSinMandar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La cola de lo marcado sin señal — pantalla 09, `docs/estaciones.md` §2.6.
///
/// **Lo que aquí se vigila es que no se pierda ni se cruce una marca.** Una
/// marca de esta cola es un paso que alguien cerró de pie en el patio y que el
/// colegio todavía no sabe: si desaparece, la familia se queda invisible para
/// la estación siguiente y **nadie se entera de que falta**. Y si se cruza de
/// usuario, el paso acabaría firmado por quien no lo cerró, que es lo único que
/// protege el paso desde que cierra cualquiera del personal (§2.9).

MarcaSinMandar unaMarca({
  int personaId = 41,
  String nombre = 'Laura Mejía',
  int nroEstacion = 2,
  String nombreEstacion = 'Documentos',
  ResultadoDelPaso resultado = ResultadoDelPaso.cumple,
  String motivo = '',
  String? observacion,
  List<int> requisitos = const [],
  DateTime? marcadaAt,
}) =>
    MarcaSinMandar(
      personaId: personaId,
      nombre: nombre,
      nroEstacion: nroEstacion,
      nombreEstacion: nombreEstacion,
      resultado: resultado,
      motivo: motivo,
      observacion: observacion,
      requisitos: requisitos,
      marcadaAt: marcadaAt ?? DateTime(2026, 9, 20, 10, 32),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.limpiar();
    SharedPreferences.setMockInitialValues({});
  });

  group('lo marcado en el patio espera en el teléfono', () {
    test('se guarda entero y se vuelve a leer tal cual', () async {
      expect(
        await MarcasSinMandar.apuntar(
          unaMarca(
            resultado: ResultadoDelPaso.observado,
            observacion: 'Falta la copia del recibo',
          ),
        ),
        isNull,
      );

      final cola = await MarcasSinMandar.pendientes();

      expect(cola, hasLength(1));
      expect(cola.first.personaId, 41);
      // El nombre viaja dentro a propósito: sin señal no se puede pedir, y una
      // cola que dijera «alumno 41 · estación 2» no sirve para lo único que hay
      // que hacer con ella, que es mirarla y saber a quién le falta llegar.
      expect(cola.first.nombre, 'Laura Mejía');
      expect(cola.first.nombreEstacion, 'Documentos');
      expect(cola.first.resultado, ResultadoDelPaso.observado);
      expect(cola.first.observacion, 'Falta la copia del recibo');
      expect(cola.first.marcadaAt, DateTime(2026, 9, 20, 10, 32));
    });

    test('la cola sale en el orden en que se marcó, que es el de la fila',
        () async {
      await MarcasSinMandar.apuntar(unaMarca(personaId: 1, nombre: 'Primera'));
      await MarcasSinMandar.apuntar(unaMarca(personaId: 2, nombre: 'Segunda'));
      await MarcasSinMandar.apuntar(unaMarca(personaId: 3, nombre: 'Tercera'));

      final cola = await MarcasSinMandar.pendientes();

      expect([for (final una in cola) una.nombre],
          ['Primera', 'Segunda', 'Tercera']);
      expect(await MarcasSinMandar.cuantas(), 3);
    });

    test('sin nada guardado, la cola está vacía y no revienta', () async {
      expect(await MarcasSinMandar.pendientes(), isEmpty);
      expect(await MarcasSinMandar.cuantas(), 0);
    });
  });

  group('la tablet pasa de mano en mano, y las marcas no', () {
    test('la clave lleva dentro el id del usuario', () async {
      AuthService.user.id = 77;

      expect(MarcasSinMandar.clave(), contains('77'));
    });

    test('lo que marcó una persona no lo ve la siguiente que coge el aparato',
        () async {
      // Es el caso de todos los días en el patio: la tablet del colegio se
      // pasa entre estaciones. Y no es solo que vería marcas ajenas — desde el
      // 20 sep 2026 **el paso queda firmado con el nombre de quien lo cierra**,
      // así que mandar la marca de otro la firmaría con el nombre equivocado, y
      // la firma es lo único que protege el paso.
      AuthService.user.id = 10;
      await MarcasSinMandar.apuntar(unaMarca(nombre: 'La de la estación 2'));

      AuthService.user.id = 11;
      expect(await MarcasSinMandar.pendientes(), isEmpty);

      AuthService.user.id = 10;
      expect(await MarcasSinMandar.pendientes(), hasLength(1));
    });
  });

  group('una persona y una estación son una sola marca', () {
    test('marcar dos veces sustituye, no encola dos veces', () async {
      await MarcasSinMandar.apuntar(
        unaMarca(resultado: ResultadoDelPaso.cumple),
      );
      await MarcasSinMandar.apuntar(
        unaMarca(
          resultado: ResultadoDelPaso.devuelto,
          motivo: 'Falta el registro civil',
        ),
      );

      final cola = await MarcasSinMandar.pendientes();

      // Mandar las dos escribiría el paso dos veces, la segunda con lo que ya
      // se había corregido. En una fila con dos hermanos apellidados igual,
      // tocar el renglón de al lado pasa todos los días (§2.7).
      expect(cola, hasLength(1));
      expect(cola.first.resultado, ResultadoDelPaso.devuelto);
      expect(cola.first.motivo, 'Falta el registro civil');
    });

    test('la corregida se queda en el sitio que tenía en la fila', () async {
      await MarcasSinMandar.apuntar(unaMarca(personaId: 1, nombre: 'Primera'));
      await MarcasSinMandar.apuntar(unaMarca(personaId: 2, nombre: 'Segunda'));
      await MarcasSinMandar.apuntar(
        unaMarca(
          personaId: 1,
          nombre: 'Primera',
          resultado: ResultadoDelPaso.observado,
        ),
      );

      final cola = await MarcasSinMandar.pendientes();

      expect([for (final una in cola) una.nombre], ['Primera', 'Segunda']);
      expect(cola.first.resultado, ResultadoDelPaso.observado);
    });

    test('la misma persona en dos estaciones son dos marcas', () async {
      await MarcasSinMandar.apuntar(unaMarca(nroEstacion: 2));
      await MarcasSinMandar.apuntar(unaMarca(nroEstacion: 3));

      expect(await MarcasSinMandar.cuantas(), 2);
    });
  });

  group('reloj naranja hasta que el servidor conteste', () {
    test('elServidorNoLoSabe dice que sí mientras espera', () async {
      await MarcasSinMandar.apuntar(unaMarca(personaId: 41, nroEstacion: 2));

      expect(
        await MarcasSinMandar.elServidorNoLoSabe(personaId: 41, nroEstacion: 2),
        isTrue,
      );
      // Otra estación de la misma persona no está marcada aquí: pintarla con el
      // reloj sería el mismo error al revés.
      expect(
        await MarcasSinMandar.elServidorNoLoSabe(personaId: 41, nroEstacion: 5),
        isFalse,
      );
    });

    test('cuando el servidor ya la tiene, sale de la cola', () async {
      await MarcasSinMandar.apuntar(unaMarca(personaId: 41, nroEstacion: 2));
      await MarcasSinMandar.apuntar(unaMarca(personaId: 42, nroEstacion: 2));

      await MarcasSinMandar.yaLaTieneElServidor(personaId: 41, nroEstacion: 2);

      expect(
        await MarcasSinMandar.elServidorNoLoSabe(personaId: 41, nroEstacion: 2),
        isFalse,
      );
      // Y no se lleva por delante a los demás, que siguen esperando.
      expect(await MarcasSinMandar.cuantas(), 1);
      expect((await MarcasSinMandar.pendientes()).first.personaId, 42);
    });

    test('la marca que se está mirando se puede leer entera', () async {
      await MarcasSinMandar.apuntar(
        unaMarca(marcadaAt: DateTime(2026, 9, 20, 10, 32)),
      );

      final marca = await MarcasSinMandar.laDe(personaId: 41, nroEstacion: 2);

      expect(marca, isNotNull);
      expect(marca!.marcadaAt.hour, 10);
      expect(marca.marcadaAt.minute, 32);
    });

    test('olvidarTodo deja la cola vacía', () async {
      await MarcasSinMandar.apuntar(unaMarca());
      await MarcasSinMandar.olvidarTodo();

      expect(await MarcasSinMandar.pendientes(), isEmpty);
    });
  });

  group('devolver sin motivo no se encola', () {
    test('se rechaza aquí, con la misma regla que el cierre normal', () async {
      final fallo = await MarcasSinMandar.apuntar(
        unaMarca(resultado: ResultadoDelPaso.devuelto),
      );

      // Y se rechaza **ahora**, no cuando vuelva la señal: un 422 horas después
      // llega con la familia ya en su casa y sin saber por qué la mandaron.
      expect(fallo, isNotNull);
      expect(fallo, contains('motivo'));
      expect(await MarcasSinMandar.pendientes(), isEmpty);
    });

    test('con motivo escrito entra', () async {
      expect(
        await MarcasSinMandar.apuntar(
          unaMarca(
            resultado: ResultadoDelPaso.devuelto,
            motivo: 'Falta el registro civil',
          ),
        ),
        isNull,
      );
      expect(await MarcasSinMandar.cuantas(), 1);
    });
  });

  group('lo guardado por otra versión no tumba la cola', () {
    test('una cadena que no es JSON se lee como cola vacía', () async {
      AuthService.user.id = 5;
      SharedPreferences.setMockInitialValues({
        MarcasSinMandar.clave(): 'esto no es json',
      });

      // Reventar aquí dejaría sin abrir justamente la pantalla que sirve para
      // cuando algo va mal.
      expect(await MarcasSinMandar.pendientes(), isEmpty);
    });

    test('una fila ilegible no se lleva por delante a las buenas', () async {
      AuthService.user.id = 5;
      SharedPreferences.setMockInitialValues({
        MarcasSinMandar.clave(): jsonEncode([
          {'persona_id': 'no soy un numero'},
          unaMarca(personaId: 7, nombre: 'La buena').aJson(),
        ]),
      });

      final cola = await MarcasSinMandar.pendientes();

      expect(cola, hasLength(1));
      expect(cola.first.nombre, 'La buena');
    });

    test('un resultado que el servidor rechazaría no se queda encolado',
        () async {
      AuthService.user.id = 5;
      SharedPreferences.setMockInitialValues({
        MarcasSinMandar.clave(): jsonEncode([
          {
            ...unaMarca().aJson(),
            // `cumplido` no es de las tres de `EstacionesController::RESULTADOS`.
            'resultado': 'cumplido',
          },
        ]),
      });

      // Dejarla dentro sería tener un contador diciendo que falta una marca que
      // no sale nunca, porque el servidor la contestaría 422 cada vez.
      expect(await MarcasSinMandar.pendientes(), isEmpty);
    });

    test('las tres palabras del servidor sí se leen', () async {
      for (final resultado in ResultadoDelPaso.values) {
        SharedPreferences.setMockInitialValues({});
        await MarcasSinMandar.apuntar(
          unaMarca(
            resultado: resultado,
            motivo:
                resultado == ResultadoDelPaso.devuelto ? 'Le falta algo' : '',
          ),
        );

        final cola = await MarcasSinMandar.pendientes();
        expect(cola.single.resultado, resultado);
      }
    });
  });

  group('una marca parcial no se manda como si fuera entera', () {
    test('los requisitos chuleados viajan con la marca', () async {
      await MarcasSinMandar.apuntar(unaMarca(requisitos: [7, 9]));

      expect((await MarcasSinMandar.pendientes()).single.requisitos, [7, 9]);
    });

    test('sin lista es «ciérrala entera», que es lo de casi siempre', () async {
      await MarcasSinMandar.apuntar(unaMarca());

      expect((await MarcasSinMandar.pendientes()).single.requisitos, isEmpty);
    });

    test('un id ilegible se cae solo, y la marca sigue valiendo', () async {
      AuthService.user.id = 5;
      SharedPreferences.setMockInitialValues({
        MarcasSinMandar.clave(): jsonEncode([
          {
            ...unaMarca().aJson(),
            // PDO devuelve unas veces enteros y otras cadenas; y lo que no sea
            // un número no es un papel que nadie haya entregado.
            'requisitos': [7, '9', 'ninguno'],
          },
        ]),
      });

      // Quedarse corto se ve —el paso sigue abierto—; pasarse daría por
      // entregado un papel que nadie entregó, y eso no se ve.
      expect((await MarcasSinMandar.pendientes()).single.requisitos, [7, 9]);
    });
  });

  test('la consecuencia se escribe una sola vez, y es la del diseño', () {
    // §2.6, con sus palabras: lo que hay que decirle a la familia mientras la
    // marca espera. Está aquí para que no se reescriba con otras en el sitio
    // siguiente donde haga falta.
    expect(
      MarcasSinMandar.laConsecuencia,
      contains('La estación siguiente aún no lo ve'),
    );
    expect(MarcasSinMandar.laConsecuencia, contains('no esperes al aviso'));
  });
}
