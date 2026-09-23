import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/NotificacionesApi.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:myvc_flutter/Utils/AvisosGuardados.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un catálogo con dos acudidos y sus tres tipos cada uno.
String catalogoDeDos() => jsonEncode({
      'alumnos': [
        {
          'alumno_id': 31,
          'nombre': 'Dámaris Gómez Pico',
          'temas': {
            'notas': 'a_ab12_notas',
            'asistencia': 'a_ab12_asistencia',
            'disciplina': 'a_ab12_disciplina',
          },
        },
        {
          'alumno_id': 44,
          'nombre': 'Luis Bolaño Díaz',
          'temas': {
            'notas': 'a_cd34_notas',
            'asistencia': 'a_cd34_asistencia',
            'disciplina': 'a_cd34_disciplina',
          },
        },
      ],
      'colegio': {'colegio_muro': 'c_1a2b', 'colegio_avisos': 'c_3c4d'},
    });

/// El mismo, sin el segundo acudido: su matrícula terminó.
String catalogoDeUno() => jsonEncode({
      'alumnos': [
        {
          'alumno_id': 31,
          'nombre': 'Dámaris Gómez Pico',
          'temas': {
            'notas': 'a_ab12_notas',
            'asistencia': 'a_ab12_asistencia',
            'disciplina': 'a_ab12_disciplina',
          },
        },
      ],
      'colegio': {'colegio_muro': 'c_1a2b', 'colegio_avisos': 'c_3c4d'},
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PendientesNotificaciones.temasDelColegio = false;
  });

  group('qué temas hay que mover', () {
    test('el primer arranque coge todos los de los tipos encendidos', () {
      final cambio = Avisos.calcularCambio(
        catalogo: TemasDeNotificacion.deCuerpo(catalogoDeDos()),
        encendidos: TipoDeAviso.values,
        anotados: const {},
      );

      expect(cambio.coger, hasLength(6));
      expect(cambio.soltar, isEmpty);
      expect(cambio.quedan, hasLength(6));
    });

    test('apagar un tipo suelta solo ese, y de los dos acudidos', () {
      final cambio = Avisos.calcularCambio(
        catalogo: TemasDeNotificacion.deCuerpo(catalogoDeDos()),
        encendidos: const [TipoDeAviso.notas, TipoDeAviso.asistencia],
        anotados: const {
          'a_ab12_notas',
          'a_ab12_asistencia',
          'a_ab12_disciplina',
          'a_cd34_notas',
          'a_cd34_asistencia',
          'a_cd34_disciplina',
        },
      );

      expect(cambio.soltar, {'a_ab12_disciplina', 'a_cd34_disciplina'});
      expect(cambio.coger, isEmpty);
    });

    test('sin cambios no se mueve nada', () {
      // Lo que corre en cada arranque. Si esto moviera algo, cada apertura de
      // la app sería una ráfaga de llamadas a Google y una ventana sin avisos.
      final catalogo = TemasDeNotificacion.deCuerpo(catalogoDeDos());
      final anotados = catalogo.temasDe(TipoDeAviso.values).toSet();

      final cambio = Avisos.calcularCambio(
        catalogo: catalogo,
        encendidos: TipoDeAviso.values,
        anotados: anotados,
      );

      expect(cambio.coger, isEmpty);
      expect(cambio.soltar, isEmpty);
    });

    test('el acudido cuya matrícula terminó se suelta', () {
      // El caso que este método existe para cubrir: el servidor solo devuelve
      // matrículas vivas, así que un acudido que desaparece del catálogo es uno
      // del que hay que desapuntarse. Sin esto, el acudiente de quien se fue
      // hace tres años seguiría recibiendo sus avisos.
      final cambio = Avisos.calcularCambio(
        catalogo: TemasDeNotificacion.deCuerpo(catalogoDeUno()),
        encendidos: TipoDeAviso.values,
        anotados: const {
          'a_ab12_notas',
          'a_ab12_asistencia',
          'a_ab12_disciplina',
          'a_cd34_notas',
          'a_cd34_asistencia',
          'a_cd34_disciplina',
        },
      );

      expect(cambio.soltar,
          {'a_cd34_notas', 'a_cd34_asistencia', 'a_cd34_disciplina'});
      expect(cambio.quedan, hasLength(3));
    });

    test('lo que queda anotado es lo querido, no lo anotado más lo nuevo', () {
      // Si `quedan` fuese la unión, un tema soltado se quedaría en el apunte
      // para siempre — y al cerrar sesión se intentaría soltar algo que ya no
      // se tiene, que es inofensivo, pero el apunte dejaría de decir la verdad.
      final cambio = Avisos.calcularCambio(
        catalogo: TemasDeNotificacion.deCuerpo(catalogoDeUno()),
        encendidos: const [TipoDeAviso.notas],
        anotados: const {'a_cd34_notas', 'a_ab12_disciplina'},
      );

      expect(cambio.quedan, {'a_ab12_notas'});
    });

    test('los temas del colegio no entran mientras el interruptor esté apagado',
        () {
      final cambio = Avisos.calcularCambio(
        catalogo: TemasDeNotificacion.deCuerpo(catalogoDeDos()),
        encendidos: TipoDeAviso.values,
        anotados: const {},
      );

      expect(cambio.coger, isNot(contains('c_1a2b')));
    });

    test('y sí entran cuando se encienda', () {
      PendientesNotificaciones.temasDelColegio = true;

      final cambio = Avisos.calcularCambio(
        catalogo: TemasDeNotificacion.deCuerpo(catalogoDeDos()),
        encendidos: TipoDeAviso.values,
        anotados: const {},
      );

      expect(cambio.coger, containsAll(['c_1a2b', 'c_3c4d']));
      expect(cambio.coger, hasLength(8));
    });
  });

  group('a qué pantalla abre un aviso', () {
    // Los cinco valores que manda el servidor en `data.pantalla`; ver
    // EnviarNotificaciones.php en el backend.
    test('cada tipo abre la suya', () {
      expect(Avisos.abridorDe({'pantalla': 'notas'}), '/mis-notas');
      expect(Avisos.abridorDe({'pantalla': 'asistencia'}), '/mi-asistencia');
      expect(Avisos.abridorDe({'pantalla': 'disciplina'}), '/mi-disciplina');
      expect(Avisos.abridorDe({'pantalla': 'matricula'}), '/mi-matricula');
      expect(Avisos.abridorDe({'pantalla': 'muro'}), '/muro');
    });

    test('lo que no se reconoce abre el muro y no se queda quieto', () {
      // Un servidor más nuevo que la app puede mandar una pantalla que aquí no
      // existe. Tocar el aviso tiene que abrir algo.
      expect(Avisos.abridorDe({'pantalla': 'estaciones'}), '/muro');
      expect(Avisos.abridorDe(const {}), '/muro');
    });

    test('un aviso de notas dice de qué asignatura es', () {
      // Los dos textos de EnviarNotificaciones::avisosDeNotas.
      expect(
          Avisos.asignaturaDelTexto('Laura tiene 1 nota nueva en SOC.'), 'SOC');
      expect(
          Avisos.asignaturaDelTexto(
              'Laura tiene 4 notas nuevas en Ciencias Sociales.'),
          'Ciencias Sociales');
      // Otro formato: no se inventa una materia, se abre la lista.
      expect(Avisos.asignaturaDelTexto('Hay notas nuevas.'), isNull);
      expect(Avisos.asignaturaDelTexto(null), isNull);
    });

    test('la asignatura se reconoce por la materia o por su alias', () {
      final aviso = AvisoDeNotas.deDatos(
          {'pantalla': 'notas', 'alumno_id': '12', 'asignatura': 'soc '});
      expect(aviso.alumnoId, 12);
      expect(aviso.esDe(materia: 'Sociales', alias: 'SOC'), isTrue);
      expect(aviso.esDe(materia: 'SOC'), isTrue);
      expect(aviso.esDe(materia: 'Matemáticas', alias: 'MAT'), isFalse);
      expect(AvisoDeNotas.deDatos(const {}).esDe(materia: 'SOC'), isFalse);
    });
  });

  group('lo que el teléfono recuerda', () {
    test('el catálogo se guarda y se relee sin red', () async {
      await AvisosGuardados.guardarCatalogo(catalogoDeDos());

      final leido = await AvisosGuardados.catalogo();

      expect(leido, isNotNull);
      expect(leido!.alumnos, hasLength(2));
      expect(leido.alumnos.first.nombre, 'Dámaris Gómez Pico');
    });

    test('un catálogo que dejó de entenderse no revienta: es como no tenerlo',
        () async {
      SharedPreferences.setMockInitialValues(
          {AvisosGuardados.claveCatalogo: 'esto no es json'});

      expect(await AvisosGuardados.catalogo(), isNull);
    });

    test('recién guardado está al día', () async {
      await AvisosGuardados.guardarCatalogo(catalogoDeDos());

      expect(await AvisosGuardados.catalogoAlDia(), isTrue);
    });

    test('pasada la semana hay que volver a preguntar', () async {
      final hace8Dias = DateTime.now().subtract(const Duration(days: 8));
      SharedPreferences.setMockInitialValues({
        AvisosGuardados.claveCatalogo: catalogoDeDos(),
        AvisosGuardados.claveRefresco: hace8Dias.millisecondsSinceEpoch,
      });

      expect(await AvisosGuardados.catalogoAlDia(), isFalse);
    });

    test('sin catálogo nunca está al día, diga lo que diga la fecha', () async {
      SharedPreferences.setMockInitialValues({
        AvisosGuardados.claveRefresco: DateTime.now().millisecondsSinceEpoch,
      });

      expect(await AvisosGuardados.catalogoAlDia(), isFalse);
    });

    test('un reloj movido hacia atrás no deja el teléfono sin temas', () async {
      // Una fecha en el futuro daría una edad negativa, y `edad < una semana`
      // sería cierto para siempre: el catálogo no se refrescaría nunca más.
      final dentroDeUnAno = DateTime.now().add(const Duration(days: 365));
      SharedPreferences.setMockInitialValues({
        AvisosGuardados.claveCatalogo: catalogoDeDos(),
        AvisosGuardados.claveRefresco: dentroDeUnAno.millisecondsSinceEpoch,
      });

      expect(await AvisosGuardados.catalogoAlDia(), isFalse);
    });

    test('al cerrar sesión se olvida el catálogo, con los nombres dentro',
        () async {
      await AvisosGuardados.guardarCatalogo(catalogoDeDos());
      await AvisosGuardados.guardarSuscritos(['a_ab12_notas']);

      await AvisosGuardados.olvidar();

      expect(await AvisosGuardados.catalogo(), isNull);
      expect(await AvisosGuardados.suscritos(), isEmpty);
      expect(await AvisosGuardados.catalogoAlDia(), isFalse);
    });

    test('los suscritos se anotan para poder soltarlos sin token', () async {
      // El motivo entero de que esto se guarde: al cerrar sesión no hay con qué
      // preguntar al servidor de qué hay que desapuntarse, y Firebase no sabe
      // decir a qué está apuntado.
      await AvisosGuardados.guardarSuscritos(
          ['a_cd34_notas', 'a_ab12_notas', 'a_ab12_notas']);

      expect(
          await AvisosGuardados.suscritos(), {'a_ab12_notas', 'a_cd34_notas'});
    });
  });
}
