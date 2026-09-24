import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/BuscarEnMatriculasScreen.dart';
import 'package:myvc_flutter/Screens/EstacionesScreen.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un servidor que apunta qué le piden y no contesta nada útil.
///
/// Sirve para lo contrario de lo habitual: aquí lo que se comprueba es que
/// **no le pidan nada** mientras las ocho rutas no existan.
class ServidorQueApunta extends Server {
  final List<String> pedidos = [];

  @override
  Future get(String direccion) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  @override
  Future post(String direccion, params) async {
    pedidos.add(direccion);
    return http.Response('{}', 200);
  }

  /// `buscar/por-nombre` y `por-apellido` son PUT, no GET. Sin este `override`
  /// la prueba saldría por el `Server` de verdad, que en pruebas no tiene URL.
  @override
  Future put(String direccion, params) async {
    pedidos.add(direccion);
    return http.Response('[]', 200);
  }
}

/// Una marca de tiempo escrita como la manda el servidor: `Y-m-d H:i:s`.
///
/// Sin zona y sin la «T» de ISO, que es lo que sale de MySQL a través de
/// `Carbon::now('America/Bogota')`. Se escribe aquí y no se toma prestada de la
/// app para que una prueba falle si algún día el formato deja de ser ése.
String _comoLaMandaElServidor(DateTime cuando) {
  String dos(int numero) => numero.toString().padLeft(2, '0');
  return '${cuando.year}-${dos(cuando.month)}-${dos(cuando.day)} '
      '${dos(cuando.hour)}:${dos(cuando.minute)}:${dos(cuando.second)}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.limpiar();
    PendientesEstaciones.comoDeFabrica();
    SharedPreferences.setMockInitialValues({});
  });

  group('el estado de un paso, que llega como texto libre', () {
    test('«falta» y «Falta» son lo mismo, y eso no es una precaución', () {
      // Es un hecho medido en el backend el 20 sep 2026:
      // `requisitos_alumno.estado` es un varchar sin lista cerrada, el valor
      // por defecto de la tabla es 'Falta' con mayúscula y
      // `AlumnosController:899` inserta "falta" en minúscula. Las dos formas de
      // nacer una fila ya no se ponen de acuerdo, así que comparar tal cual
      // sería leer mal a la mitad de las filas.
      expect(EstadoDelPaso.deTexto('falta'), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto('Falta'), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto('  FALTA  '), EstadoDelPaso.pendiente);
    });

    test('sin texto y sin marca, pendiente', () {
      expect(EstadoDelPaso.deTexto(null), EstadoDelPaso.pendiente);
      expect(EstadoDelPaso.deTexto(''), EstadoDelPaso.pendiente);
      expect(
        EstadoDelPaso.deTexto('cumple', hayMarca: false),
        EstadoDelPaso.pendiente,
      );
    });

    test('NO es una lista blanca, y por eso «Entregado» cuenta', () {
      // Esta prueba existe por un error que tuvo esta función: empezó con una
      // lista blanca —cumple/cumplido/ok— y `RequisitosController::getRecorrido`
      // ya tenía escrito por qué eso está mal: «una lista blanca de estados
      // buenos se quedaría corta en silencio el día que un colegio escriba
      // "Entregado" con mayúscula». Ese colegio habría visto su paso en gris
      // para siempre sin que nada fallara.
      expect(EstadoDelPaso.deTexto('Entregado'), EstadoDelPaso.cumplido);
      expect(EstadoDelPaso.deTexto('recibido'), EstadoDelPaso.cumplido);
      // Y lo seguro sigue siendo seguro: «falta» es lo único que significa que
      // no está.
      expect(EstadoDelPaso.deTexto('falta'), EstadoDelPaso.pendiente);
    });

    test('los que sí se conocen se leen', () {
      expect(EstadoDelPaso.deTexto('cumple'), EstadoDelPaso.cumplido);
      expect(EstadoDelPaso.deTexto('Observado'), EstadoDelPaso.observado);
      expect(EstadoDelPaso.deTexto('DEVUELTO'), EstadoDelPaso.devuelto);
    });

    test('ninguno se distingue solo por el color: todos traen palabra e icono',
        () {
      // Es por el sol del patio y por quien no distingue el rojo del verde,
      // que en un claustro de cincuenta docentes es uno o dos.
      for (final estado in EstadoDelPaso.values) {
        expect(estado.palabra.trim(), isNotEmpty);
        expect(estado.icono, isNotNull);
      }
      // Y las cuatro palabras son distintas entre sí, que es lo que las hace
      // servir de algo.
      final palabras = EstadoDelPaso.values.map((e) => e.palabra).toSet();
      expect(palabras.length, EstadoDelPaso.values.length);
    });
  });

  group('lo que manda el servidor, leído sin fiarse del tipo', () {
    test('un tinyint que llega como «1», 1 o true se lee igual', () {
      // `DB::select` devuelve lo que PDO decida: el mismo campo llega int en
      // una ruta y String en otra.
      for (final crudo in [1, '1', true, 'true']) {
        final paso = PasoDelRecorrido.fromJson({
          'nro': 2,
          'nombre': 'Documentos',
          'estado': 'falta',
          'obligatorio': crudo,
        });
        expect(paso.obligatorio, isTrue, reason: 'con $crudo');
      }
      expect(
        PasoDelRecorrido.fromJson({'nro': 2, 'obligatorio': 0}).obligatorio,
        isFalse,
      );
    });

    test('una estación sin nombre no sale en blanco: sale con su número', () {
      final estacion = Estacion.fromJson({'nro': '3'});
      expect(estacion.nro, 3);
      expect(estacion.nombre, 'Estación 3');
    });

    test('un aspirante se distingue de un alumno por de dónde sale su id', () {
      final alumno = PersonaEnCola.fromJson({
        'alumno_id': 31,
        'nombres': 'Laura Sofía',
        'apellidos': 'Mejía Ariza',
      });
      final aspirante = PersonaEnCola.fromJson({
        'aspirante_id': 77,
        'nombres': 'Mariana',
        'apellidos': 'Castillo',
      });

      expect(alumno.id, 31);
      expect(alumno.esAspirante, isFalse);
      expect(aspirante.id, 77);
      expect(aspirante.esAspirante, isTrue);
    });

    test('la persona de la FICHA llega con «id», y no por eso es aspirante',
        () {
      // La cola manda `alumno_id` y la ficha manda la fila de `alumnos` tal
      // cual, o sea `id` (EstacionesController:1185). Leyendo solo `alumno_id`,
      // la persona de la ficha entraba con id 0 —y marcada como aspirante—:
      // un renglón que no lleva a ninguna parte y una etiqueta falsa encima.
      final deLaFicha = PersonaEnCola.fromJson({
        'id': 31,
        'nombres': 'Laura Sofía',
        'apellidos': 'Mejía Ariza',
        'documento': '1092345678',
      });

      expect(deLaFicha.id, 31);
      expect(deLaFicha.esAspirante, isFalse);
      expect(deLaFicha.documento, '1092345678');
    });
  });

  group('«hace 2 min», que lo calcula el teléfono y no el servidor', () {
    // Todo este grupo existe por lo mismo: el 20 sep 2026 se leyó campo por
    // campo `EstacionesController.php` y la cola manda `llego_at` y la ficha
    // `cerrado_at` —marcas de MySQL—, mientras que esta app leía `llego_hace`
    // y `cerrado_hace`, que NO EXISTEN en ninguna de las nueve rutas. O sea
    // que el «hace 2 min» de la fila no salía nunca y el «cerrado» del
    // recorrido salía en crudo: «2026-09-20 14:32:00».
    final ahora = DateTime(2026, 9, 20, 14, 32);

    test('dos minutos son «hace 2 min»', () {
      expect(haceCuanto('2026-09-20 14:30:00', ahora: ahora), 'hace 2 min');
    });

    test('pasada la hora se dicen las dos cifras: «hace 1 h 10 min»', () {
      // Quien atiende necesita saber si el de delante lleva diez minutos o
      // una hora: «hace 70 min» hay que convertirlo mentalmente, y esto se
      // lee de pie y con sol en la cara.
      expect(
          haceCuanto('2026-09-20 13:22:00', ahora: ahora), 'hace 1 h 10 min');
      expect(haceCuanto('2026-09-20 12:32:00', ahora: ahora), 'hace 2 h');
    });

    test('recién llegado no dice «hace 0 min»', () {
      // Cero minutos se lee como «no ha llegado» y es justo al revés: acaba
      // de llegar.
      expect(
        haceCuanto('2026-09-20 14:31:45', ahora: ahora),
        'hace menos de 1 min',
      );
    });

    test('un reloj adelantado NO produce «hace -3 min»: enseña la hora', () {
      // El reloj del teléfono de un docente en el patio no es una fuente de
      // verdad —la marca la pone el servidor en hora de Bogotá y la resta la
      // hace el aparato—. «a las 14:35» es verdad aunque el reloj vaya mal;
      // «hace -3 min» es mentira y además no dice qué está roto.
      expect(haceCuanto('2026-09-20 14:35:00', ahora: ahora), 'a las 14:35');
    });

    test('una marca de hace más de un día se enseña con su fecha', () {
      // El día de matrículas es un día: una marca de anteayer en la cola de
      // hoy es un dato raro, y «hace 54 h» no ayuda a nadie a entenderlo.
      expect(haceCuanto('2026-09-18 08:05:00', ahora: ahora), '18/09 08:05');
    });

    test('sin marca, o con una que no se puede leer, no se inventa nada', () {
      // La pantalla no pinta nada, que es mejor que pintar un hueco con
      // guiones donde debería ir una hora.
      expect(haceCuanto(null), isNull);
      expect(haceCuanto(''), isNull);
      expect(haceCuanto('   '), isNull);
      expect(haceCuanto('ayer por la tarde'), isNull);
    });

    test('la cola lo arma desde «llego_at», que es el campo que sí existe', () {
      // La prueba de que el arreglo llega hasta el modelo y no se queda en la
      // función suelta.
      final persona = PersonaEnCola.fromJson({
        'alumno_id': 31,
        'nombres': 'Laura Sofía',
        'apellidos': 'Mejía Ariza',
        'llego_at': _comoLaMandaElServidor(
          DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      });

      expect(persona.llegoHace, 'hace 5 min');
    });

    test('un paso cerrado ya no enseña la fila de la base de datos', () {
      // Esto es lo que se veía a simple vista en el recorrido: «Cerrado por
      // Nancy Ariza · 2026-09-20 14:32:00».
      final paso = PasoDelRecorrido.fromJson({
        'nro': 2,
        'nombre': 'Documentos',
        'estado': 'cumple',
        'cerrado_por': 'Nancy Ariza',
        'cerrado_at': _comoLaMandaElServidor(
          DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      });

      expect(paso.cerradoHace, 'hace 10 min');
      expect(paso.cerradoHace, isNot(contains(':')));
    });
  });

  group('una estación no tiene ni sitio ni dueño, y es del contrato', () {
    test('lo que llega por estación es «descripcion», y se lee con su nombre',
        () {
      // `donde` se quitó el 20 sep 2026 porque NO EXISTE: la única clave con
      // ese nombre en todo el controlador es la estación de DESTINO al
      // devolver a alguien (líneas 586, 1165 y 1306). Aquí se le manda
      // igualmente para dejar dicho que, aunque alguien lo mande, este modelo
      // ya no lo lee ni lo pinta como una ubicación.
      final estacion = Estacion.fromJson({
        'nro': 2,
        'nombre': 'Documentos',
        'descripcion': 'Fotocopia ampliada al 150%',
        'donde': 'Aula 101',
      });

      expect(estacion.nombre, 'Documentos');
      expect(estacion.descripcion, 'Fotocopia ampliada al 150%');
    });

    test('una descripción en blanco no deja un renglón con un separador', () {
      // La pantalla vieja de requisitos guarda `descripcion = ''` de verdad:
      // sin esto, la tarjeta pintaría « · la tuya».
      expect(
          Estacion.fromJson({'nro': 1, 'descripcion': ''}).descripcion, isNull);
      expect(Estacion.fromJson({'nro': 1, 'descripcion': '   '}).descripcion,
          isNull);
    });
  });

  group('la fila sin fotos, y el desempate que sí se puede hacer hoy', () {
    PersonaEnCola alguien(int id, String nombres, String apellidos,
            [String? documento]) =>
        PersonaEnCola.fromJson({
          'alumno_id': id,
          'nombres': nombres,
          'apellidos': apellidos,
          'documento': documento,
        });

    test('la cola no manda foto, y aquí no se inventa el campo', () {
      // `getCola` manda alumno_id, nombres, apellidos, documento, grupo,
      // llego_at, devuelto_antes, avisos, notas_total y notas_pendientes. Ni
      // `foto_nombre` ni `foto_id`. Un campo que la app lee y el servidor no
      // escribe es el error que este módulo acaba de pagar con `donde`.
      expect(alguien(31, 'Laura', 'Mejía').fotoNombre, isNull);
    });

    test('dos hermanas apellidadas igual se marcan; las demás, no', () {
      // Sin foto, esos dos renglones son idénticos: mismo círculo de
      // iniciales, mismo grupo, mismo nombre. Quien atiende abre el primero y
      // le marca el paso a la otra, y eso no se descubre hasta que la familia
      // vuelve.
      final cola = [
        alguien(31, 'Laura Sofía', 'Mejía Ariza', '1092345678'),
        alguien(32, 'Laura Sofía', 'Mejía Ariza', '1092399999'),
        alguien(33, 'Mariana', 'Castillo', '1092300000'),
      ];

      final repetidos = losNombresQueSeRepiten(cola);

      expect(repetidos, contains('laura sofía mejía ariza'));
      expect(repetidos, isNot(contains('mariana castillo')));
      expect(repetidos.length, 1);
    });

    test('una fila sin empates no enseña ningún documento', () {
      // El documento es un dato personal pintado en una pantalla que se mira
      // de pie en un patio: donde no hay empate, no distingue nada.
      final cola = [
        alguien(31, 'Laura Sofía', 'Mejía Ariza', '1092345678'),
        alguien(33, 'Mariana', 'Castillo', '1092300000'),
      ];

      expect(losNombresQueSeRepiten(cola), isEmpty);
    });
  });

  group('la ficha, leída contra lo que el servidor manda de verdad', () {
    test('el acudiente llega como OBJETO, no como un texto', () {
      // `acudienteDe()` devuelve la fila entera (línea 1262) y el modelo la
      // leía con `texto(...)`: en Dart eso no falla, devuelve el `toString`
      // del mapa. O sea que al lado del icono de teléfono se habría pintado
      // «{id: 4, nombres: Ana, ...}».
      final ficha = FichaDeEstacion.fromJson({
        'persona': {'id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'acudiente': {
          'id': 4,
          'nombres': 'Ana',
          'apellidos': 'Gómez Ariza',
          'celular': '3001234567',
          'telefono': '6012345',
        },
        'pasos': [],
      });

      expect(ficha.acudiente, 'Ana Gómez Ariza');
      expect(ficha.acudiente, isNot(contains('{')));
      // El celular antes que el fijo: el día de matrículas la familia está en
      // la calle, no en su casa.
      expect(ficha.telefonoAcudiente, '3001234567');
    });

    test('sin celular se llama al fijo, y sin ninguno no se pinta el renglón',
        () {
      final soloFijo = FichaDeEstacion.fromJson({
        'persona': {'id': 31},
        'acudiente': {
          'nombres': 'Ana',
          'apellidos': 'Gómez',
          'telefono': '6012345'
        },
        'pasos': [],
      });
      expect(soloFijo.telefonoAcudiente, '6012345');

      final sinNada = FichaDeEstacion.fromJson({
        'persona': {'id': 31},
        'pasos': [],
      });
      expect(sinNada.acudiente, isNull);
      expect(sinNada.telefonoAcudiente, isNull);
    });

    test('«si_no» dice a DÓNDE devolverla, y esa clave se llama «donde»', () {
      // Es el único `donde` que el servidor manda de verdad (línea 1165): el
      // nombre de la estación de destino. Se leía `nombre`, que ahí no viaja,
      // así que la banda del salteado decía «Le falta la Estación 1 ·
      // Estación 1» en vez de «· Recepción».
      final ficha = FichaDeEstacion.fromJson({
        'persona': {'id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'pasos': [
          {'nro': 1, 'nombre': 'Recepción', 'estado': 'falta'},
          {'nro': 2, 'nombre': 'Documentos', 'estado': 'falta'},
        ],
        'puede_atenderlo': false,
        'si_no': {'devolver_a_nro': 1, 'donde': 'Recepción'},
      });

      expect(ficha.leFalta?.nro, 1);
      expect(ficha.leFalta?.nombre, 'Recepción');
    });

    test('lo que frena llega como «bloquea»: «obligatorio» no viaja', () {
      // El propio controlador lo dice en el docblock de `getAlumno`:
      // «publicar los dos campos con el mismo valor invitaría a la app a
      // distinguir dos cosas que aquí son una». Leyendo solo `obligatorio`,
      // TODO salía obligatorio y el botón de cerrar se apagaba por un carné
      // de vacunas que el colegio marcó como opcional.
      final paso = PasoDelRecorrido.fromJson({
        'nro': 2,
        'nombre': 'Documentos',
        'estado': 'falta',
        'bloquea': true,
        'requisitos': [
          {
            'id': 1,
            'requisito': 'Registro civil',
            'estado': 'cumple',
            'bloquea': true,
          },
          {
            'id': 2,
            'requisito': 'Carné de vacunas',
            'estado': 'falta',
            'bloquea': false,
          },
        ],
      });

      expect(paso.obligatorio, isTrue);
      expect(paso.obligatoriosQueFaltan, 0);
    });

    test('la observación de un requisito llega como «observacion»', () {
      // Es `requisitos_alumno.descripcion` (línea 1154): lo que el personal
      // escribió sobre ESTE papel de ESTA persona. El modelo leía `detalle` o
      // `descripcion`, así que debajo del requisito salía la palabra del
      // estado en lugar de lo que alguien se molestó en escribir.
      final requisito = Requisito.fromJson({
        'id': 1,
        'requisito': 'Certificado de notas',
        'estado': 'Observado',
        'observacion': 'Lo trajo sin firmar, vuelve el lunes',
      });

      expect(requisito.detalle, 'Lo trajo sin firmar, vuelve el lunes');
    });
  });

  group('el globo de notas', () {
    test('el número cuenta las reservadas, y eso es a propósito', () {
      // Esconder que una nota existe es peor que esconder su contenido: quien
      // ve el globo y no puede abrirlo sabe a quién preguntarle; quien no ve
      // nada, no pregunta.
      final notas = NotasDelPaso.fromJson({
        'total': 3,
        'pendientes': 1,
        'reservadas': 2,
      });

      expect(notas.total, 3);
      expect(notas.reservadas, 2);
      expect(notas.hayAlgo, isTrue);
      expect(notas.algoSinResolver, isTrue);
    });

    test('ámbar solo si algo está sin resolver; si no, pizarra', () {
      const soloEscritas = NotasDelPaso(total: 2, pendientes: 0);
      const conPendiente = NotasDelPaso(total: 2, pendientes: 1);

      expect(soloEscritas.algoSinResolver, isFalse);
      expect(conPendiente.algoSinResolver, isTrue);
    });

    test('el número nunca va solo: hay la misma frase en palabras', () {
      const notas = NotasDelPaso(total: 2, pendientes: 1);
      expect(notas.enPalabras('Tesorería'),
          '2 notas en Tesorería, una sin resolver');

      const una = NotasDelPaso(total: 1, pendientes: 0);
      expect(una.enPalabras('Recepción'), '1 nota en Recepción');
    });

    test('la ficha suma las notas de TODAS las estaciones, no solo la tuya',
        () {
      // Es la razón de ser de §2.10: el tesorero deja la nota el lunes en la 5
      // y la estación 2 la atiende el sábado. Si esto sumara solo el paso
      // propio, quien atiende Documentos mandaría a la familia a hacer cuatro
      // colas sin enterarse.
      final ficha = FichaDeEstacion.fromJson({
        'persona': {'alumno_id': 31, 'nombres': 'Laura', 'apellidos': 'Mejía'},
        'pasos': [
          {
            'nro': 1,
            'nombre': 'Recepción',
            'estado': 'cumple',
            'notas': {'total': 1, 'pendientes': 0}
          },
          {'nro': 2, 'nombre': 'Documentos', 'estado': 'falta'},
          {
            'nro': 5,
            'nombre': 'Tesorería',
            'estado': 'falta',
            'notas': {'total': 2, 'pendientes': 1, 'reservadas': 1}
          },
        ],
      });

      final todas = ficha.notasDeTodoElRecorrido;
      expect(todas.total, 3);
      expect(todas.pendientes, 1);
      expect(todas.reservadas, 1);
    });
  });

  group('los requisitos de un paso', () {
    test('solo los obligatorios apagan el botón de cerrar', () {
      final paso = PasoDelRecorrido.fromJson({
        'nro': 2,
        'nombre': 'Documentos',
        'estado': 'falta',
        'requisitos': [
          {'id': 1, 'requisito': 'Registro civil', 'estado': 'cumple'},
          {
            'id': 2,
            'requisito': 'Carné de vacunas',
            'estado': 'falta',
            'obligatorio': 0
          },
        ],
      });

      expect(paso.requisitos.length, 2);
      // El opcional está sin cumplir y aun así no cuenta.
      expect(paso.obligatoriosQueFaltan, 0);
    });

    test('un obligatorio sin cumplir sí cuenta', () {
      final paso = PasoDelRecorrido.fromJson({
        'nro': 2,
        'requisitos': [
          {'id': 1, 'requisito': 'Certificado de notas', 'estado': 'falta'},
        ],
      });
      expect(paso.obligatoriosQueFaltan, 1);
    });
  });

  group('las ocho rutas no existen, y la app no las llama', () {
    test('el interruptor viene apagado, y así tiene que seguir', () {
      // Las ocho rutas `estaciones/*` no están en NINGÚN colegio. Encender esto
      // antes del despliegue gasta un 404 por apertura sobre un hosting de un
      // núcleo, que es justo la carga que este proyecto lleva un año evitando.
      // Ver docs/backend-pendiente.md §8.
      expect(Interruptores.estaciones, isFalse);
    });

    test('con el interruptor apagado no se le pide NADA al servidor', () async {
      final servidor = ServidorQueApunta();

      await traerLasEstaciones(servidor);
      await traerLaCola(servidor, 2);
      await traerLaHuella(servidor);
      await traerLaFicha(servidor, 31);

      // Lo que se comprueba es el silencio: ni un 404.
      expect(servidor.pedidos, isEmpty);
    });

    test('y contestan vacío en vez de reventar', () async {
      final servidor = ServidorQueApunta();

      expect(await traerLasEstaciones(servidor), isEmpty);
      expect(await traerLaCola(servidor, 2), isEmpty);
      expect(await traerLaHuella(servidor), isEmpty);
      expect(await traerLaFicha(servidor, 31), isNull);
    });

    test('dejar una nota contesta el motivo, no un fallo de red', () async {
      final servidor = ServidorQueApunta();
      final fallo = await dejarUnaNota(
        servidor,
        nroEstacion: 5,
        personaId: 31,
        texto: 'Tiene saldo pendiente',
      );

      expect(fallo, isNotNull);
      expect(servidor.pedidos, isEmpty);
    });
  });

  group('los pendientes de estas pantallas', () {
    test('encendidos los que tienen pantalla y ruta; apagados los decididos',
        () {
      // Desde el 24 sep 2026 lo que queda debajo de estos tres es sólo el
      // despliegue (`Interruptores.estaciones`).
      expect(PendientesEstaciones.marcarElPaso, isTrue);
      expect(PendientesEstaciones.devolverConMotivo, isTrue);
      expect(PendientesEstaciones.resolverUnaNota, isTrue);
      // Y estos dos los apagó Joseth el 20 sep 2026: el escáner, por los
      // permisos de las tiendas; el push, porque la cola sondeada basta.
      expect(PendientesEstaciones.escanearElCodigo, isFalse);
      expect(PendientesEstaciones.pushInmediato, isFalse);
    });

    test('volver a fábrica mueve los dos sentidos', () {
      // Si `comoDeFabrica` se desincroniza de los valores escritos, las pruebas
      // dejan de comprobar la app que se publica.
      PendientesEstaciones.marcarElPaso = false;
      PendientesEstaciones.pushInmediato = true;

      PendientesEstaciones.comoDeFabrica();

      expect(PendientesEstaciones.marcarElPaso, isTrue);
      expect(PendientesEstaciones.pushInmediato, isFalse);
    });
  });

  group('la pantalla de elegir estación', () {
    Future<void> montar(WidgetTester tester) async {
      AuthService.user = UserAutenticado(
        username: 'nancy.ariza',
        tipo: 'Profesor',
        id: 12,
      );

      await tester.pumpWidget(
        MaterialApp(home: EstacionesScreen(servidor: ServidorQueApunta())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin recorrido dice qué falta y dónde se arregla',
        (tester) async {
      // Una lista vacía y «esto todavía no existe» se leen igual y no son lo
      // mismo. Aquí se dice la tercera, que es la que le sirve al colegio:
      // «no armaste el recorrido, se arma en la web».
      await montar(tester);

      expect(find.textContaining('no armó el recorrido'), findsOneWidget);
      expect(find.textContaining('pantalla de requisitos'), findsOneWidget);
      // Nunca «no disponible»: quien lo lee es quien puede arreglarlo.
      expect(find.textContaining('no disponible'), findsNothing);
    });

    testWidgets('lleva el mismo nombre que el menú', (tester) async {
      // El título tiene que ser la misma palabra que la entrada del menú: si el
      // menú dice «Estaciones», la pantalla dice «Estaciones».
      await montar(tester);
      expect(find.text('Estaciones'), findsOneWidget);
    });
  });

  group('buscar en todo el colegio', () {
    test('con menos de tres letras no se le pregunta al servidor', () async {
      // `buscar/por-nombre` hace LIKE '%texto%' SIN límite de filas, así que
      // buscar «a» devolvería el colegio entero —más de dos mil— por cada
      // tecla. Sobre un hosting de un núcleo eso no es lento: es una caída.
      final servidor = ServidorQueApunta();

      expect(await buscarPersonas(servidor, 'a'), isEmpty);
      expect(await buscarPersonas(servidor, 'la'), isEmpty);
      expect(await buscarPersonas(servidor, '  '), isEmpty);
      expect(servidor.pedidos, isEmpty);
    });

    test('con tres o más pregunta por nombre Y por apellido', () async {
      // Son dos endpoints y quien busca escribe un nombre sin pensar en cuál
      // de los dos campos es: «Mejía» por nombre no devuelve nada, y quien lo
      // escribió no tiene por qué saberlo.
      final servidor = ServidorQueApunta();
      await buscarPersonas(servidor, 'Mejía');

      expect(servidor.pedidos, contains('/buscar/por-nombre'));
      expect(servidor.pedidos, contains('/buscar/por-apellido'));
    });

    test('esto NO lleva interruptor: buscar funciona hoy', () {
      // Las dos rutas llevan desplegadas desde mucho antes que el día de
      // matrículas. Lo que espera a un despliegue es el recorrido.
      expect(letrasMinimasParaBuscar, 3);
    });
  });

  group('el recorrido de matrícula', () {
    test('espera a SU despliegue, no a las ocho rutas', () async {
      // `requisitos/recorrido/{id}` la entregó Joseth el 20 sep y está en main
      // de 8myvc: no es de las ocho, así que puede encenderse mucho antes.
      expect(Interruptores.recorridoDeMatricula, isFalse);

      final servidor = ServidorQueApunta();
      expect(await traerElRecorrido(servidor, 31), isNull);
      expect(servidor.pedidos, isEmpty);
    });

    test('un requisito sin marca es pendiente, no «no está»', () {
      // El SQL del servidor usa LEFT JOIN a propósito: «un requisito que nadie
      // ha tocado todavía no tiene fila en requisitos_alumno, y es justo el que
      // hay que enseñar». Si `marca_id` es null, nadie lo ha mirado.
      final recorrido = RecorridoDeMatricula.fromJson({
        'pasos': [
          {'estacion': 1, 'requisito': 'Registro civil', 'marca_id': null},
          {
            'estacion': 2,
            'requisito': 'Certificado',
            'marca_id': 9,
            'estado': 'Entregado',
            'cerrado_por_nombres': 'Nancy',
            'cerrado_por_apellidos': 'Ariza',
          },
        ],
      });

      expect(recorrido.pasos.first.estado, EstadoDelPaso.pendiente);
      expect(recorrido.pasos.last.estado, EstadoDelPaso.cumplido);
      expect(recorrido.pasos.last.cerradoPor, 'Nancy Ariza');
      expect(recorrido.cerrados, 1);
    });

    test(
        'si cierra un administrativo no hay nombre, y eso es ausente y no vacío',
        () {
      // **Éste es el caso NORMAL en la ventanilla, no el raro.**
      // `cerrado_por_nombres` sale de `profesores`, y `8myvc-fc` midió el 20 sep
      // 2026 que **0 de las 22 cuentas de tipo `Usuario` tienen ficha ahí**. O
      // sea que cuando cierra el paso un administrativo —que es justo quien
      // atiende— las dos claves llegan NULL.
      //
      // Lo que esta prueba sujeta es el `.trim()` de `_pasoDelRecorridoViejo`:
      // sin él, juntar dos vacíos da `' '`, que **no es vacío**, `cerradoPor`
      // dejaría de ser null y las pantallas —que preguntan `!= null`— pintarían
      // «Cerrado por » con el hueco en blanco. Peor que no decir nada, porque
      // parece un dato perdido en vez de uno que no existe.
      final recorrido = RecorridoDeMatricula.fromJson({
        'pasos': [
          {
            'estacion': 1,
            'requisito': 'Tesorería',
            'marca_id': 7,
            'estado': 'Entregado',
            'cerrado_por': 44,
            'cerrado_por_nombres': null,
            'cerrado_por_apellidos': null,
          },
        ],
      });

      expect(recorrido.pasos.single.estado, EstadoDelPaso.cumplido);
      expect(recorrido.pasos.single.cerradoPor, isNull);
    });

    test('lo que frena se dice aparte de lo que falta', () {
      final recorrido = RecorridoDeMatricula.fromJson({
        'pasos': [
          {'estacion': 1, 'requisito': 'Registro civil', 'bloquea': 1},
          {'estacion': 2, 'requisito': 'Carné de vacunas', 'bloquea': 0},
        ],
      });

      // Los dos están pendientes, pero solo uno frena.
      expect(recorrido.cerrados, 0);
      expect(recorrido.loQueFrena.length, 1);
      expect(recorrido.loQueFrena.first.nombre, 'Registro civil');
    });

    test('acepta la lista pelada y el objeto con «pasos» dentro', () {
      // La ruta se entregó hoy: su envoltorio es lo único que podría moverse,
      // así que se aceptan las dos formas en vez de suponer una.
      final pelada = RecorridoDeMatricula.fromJson([
        {'estacion': 1, 'requisito': 'Registro civil'},
      ]);
      expect(pelada.pasos.length, 1);
    });
  });

  group('en tablet se ven los dos a la vez', () {
    testWidgets('la búsqueda parte la pantalla a partir de 900',
        (tester) async {
      // Decidido el 20 sep: celular y tablet. El maestro-detalle dejó de ser
      // mejora y pasó a ser requisito (docs/tablets.md, problema 2).
      AuthService.user =
          UserAutenticado(username: 'nancy', tipo: 'Profesor', id: 12);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
            home: BuscarEnMatriculasScreen(servidor: ServidorQueApunta())),
      );
      await tester.pumpAndSettle();

      // El panel derecho existe y dice qué hacer, en vez de estar en blanco.
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.textContaining('Busca a alguien'), findsOneWidget);
    });

    testWidgets('en celular no se parte: una sola columna', (tester) async {
      AuthService.user =
          UserAutenticado(username: 'nancy', tipo: 'Profesor', id: 12);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
            home: BuscarEnMatriculasScreen(servidor: ServidorQueApunta())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.textContaining('al menos tres letras'), findsOneWidget);
    });
  });

  group('la paleta', () {
    test('el morado de texto sobre claro no es el de marca, y hace falta', () {
      // El primario sobre blanco se queda en 3,9:1 y no llega al 4,5:1 que pide
      // el texto normal. No es un tono decorativo: es el que hace legible.
      expect(
        PaletaEstaciones.primarioOscuro,
        isNot(equals(PaletaEstaciones.primario)),
      );
    });

    test('los botones que deciden algo se tocan de pie, con guantes', () {
      expect(PaletaEstaciones.alturaDeBoton, greaterThanOrEqualTo(56));
    });
  });
}
