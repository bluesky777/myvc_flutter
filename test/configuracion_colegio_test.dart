import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Utils/ConfiguracionColegio.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

void main() {
  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
  });

  group('las banderas 0/1 del backend', () {
    test('un 0 explícito es que no', () {
      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 0,
        'profes_pueden_nivelar': 0,
        'alumnos_can_see_notas': 0,
        'show_materias_todas': 0,
      });

      expect(config.profesPuedenEditarNotas, isFalse);
      expect(config.profesPuedenNivelar, isFalse);
      expect(config.alumnosPuedenVerNotas, isFalse);
      expect(config.mostrarTodasLasMaterias, isFalse);
    });

    test('y llega igual como cadena', () {
      // Las consultas son SQL a pelo: el tipo lo decide el driver de PDO.
      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': '0',
        'profes_pueden_nivelar': '1',
      });

      expect(config.profesPuedenEditarNotas, isFalse);
      expect(config.profesPuedenNivelar, isTrue);
    });

    test('lo que no viene no es un no', () {
      // Para un alumno o un acudiente estas columnas ni siquiera están en la
      // consulta del backend. Tratarlas como 0 dejaría media app en gris.
      final config = ConfiguracionColegio.deLogin({'year_id': 6});

      expect(config.profesPuedenEditarNotas, isTrue);
      expect(config.profesPuedenNivelar, isTrue);
      expect(config.alumnosPuedenVerNotas, isTrue);
    });
  });

  group('quién puede editar', () {
    test('con el periodo abierto, el docente', () {
      AuthService.user.tipo = 'Profesor';

      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 1,
        'profes_pueden_nivelar': 1,
      });

      expect(config.puedeEditarNotas, isTrue);
      expect(config.puedeNivelar, isTrue);
      expect(config.avisoDeBloqueo, isNull);
    });

    test('con el periodo cerrado, el docente no', () {
      AuthService.user.tipo = 'Profesor';

      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 0,
        'profes_pueden_nivelar': 0,
      });

      expect(config.puedeEditarNotas, isFalse);
      expect(config.puedeNivelar, isFalse);
    });

    test('el superusuario salta el bloqueo', () {
      AuthService.user.isSuperuser = true;

      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 0,
        'profes_pueden_nivelar': 0,
      });

      expect(config.puedeEditarNotas, isTrue);
      expect(config.puedeNivelar, isTrue);
      expect(config.avisoDeBloqueo, contains('superusuario'));
    });

    test('el rol de admin, por sí solo, no basta', () {
      // El backend compara `$user->tipo == 'Profesor'` o `is_superuser`, no el
      // rol. El front web mira el rol y por eso a un administrativo le enseña
      // campos editables que después dan 403 al guardar. Aquí, no.
      AuthService.user.tipo = 'Usuario';
      AuthService.user.roles = {'admin'};

      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 1,
        'profes_pueden_nivelar': 1,
      });

      expect(config.puedeEditarNotas, isFalse);
      expect(config.puedeNivelar, isFalse);
      expect(config.avisoDeBloqueo, contains('el docente de la asignatura'));
    });

    test('tener el rol de profesor tampoco basta', () {
      // Un usuario de tipo 'Usuario' con profesor_id y el rol 'profesor' pasa
      // por docente en la app —esDocente mira el rol— pero no en el backend.
      AuthService.user.tipo = 'Usuario';
      AuthService.user.roles = {'profesor'};

      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 1,
      });

      expect(AuthService.user.esDocente, isTrue);
      expect(config.puedeEditarNotas, isFalse);
    });

    test('los dos permisos son independientes', () {
      // Es el caso de fin de periodo: se cierra la edición de notas y se deja
      // abierto nivelar para cuadrar las definitivas.
      AuthService.user.tipo = 'Profesor';

      final config = ConfiguracionColegio.deLogin({
        'profes_pueden_editar_notas': 0,
        'profes_pueden_nivelar': 1,
      });

      expect(config.puedeEditarNotas, isFalse);
      expect(config.puedeNivelar, isTrue);
      expect(config.avisoDeBloqueo, contains('sí puedes nivelar'));
    });
  });

  group('la nota mínima', () {
    test('por debajo está perdida', () {
      final config = ConfiguracionColegio.deLogin({
        'nota_minima_aceptada': 60,
      });

      expect(config.esPerdida(59), isTrue);
      expect(config.esPerdida(60), isFalse);
      expect(config.esPerdida(85), isFalse);
    });

    test('sin mínima no se señala nada', () {
      // Más vale no pintar de rojo que pintar de rojo lo que no toca.
      final config = ConfiguracionColegio.deLogin({});

      expect(config.notaMinimaAceptada, isNull);
      expect(config.esPerdida(0), isFalse);
    });

    test('una nota que falta tampoco está perdida', () {
      final config = ConfiguracionColegio.deLogin({
        'nota_minima_aceptada': '60',
      });

      expect(config.notaMinimaAceptada, 60);
      expect(config.esPerdida(null), isFalse);
    });
  });

  group('cómo llama el colegio a las unidades', () {
    test('lo que diga el colegio, con su género', () {
      final config = ConfiguracionColegio.deLogin({
        'unidad_displayname': 'Logro',
        'unidades_displayname': 'Logros',
        'subunidad_displayname': 'Indicador',
        'subunidades_displayname': 'Indicadores',
        'genero_unidad': 'M',
        'genero_subunidad': 'M',
      });

      expect(config.unidad, 'Logro');
      expect(config.subunidades, 'Indicadores');
      expect(config.articuloUnidad, 'el');
      expect(config.deLaSubunidad, 'del');
    });

    test('si no lo dice, unidades y subunidades', () {
      final config = ConfiguracionColegio.deLogin({});

      expect(config.unidad, 'Unidad');
      expect(config.subunidades, 'Subunidades');
      expect(config.articuloUnidad, 'la');
    });

    test('un nombre en blanco no es un nombre', () {
      final config = ConfiguracionColegio.deLogin({
        'unidad_displayname': '   ',
      });

      expect(config.unidad, 'Unidad');
    });
  });

  group('colgada del contexto', () {
    test('se lee con el año y el periodo', () {
      ContextoAcademico.instancia.tomarDelLogin({
        'year_id': 6,
        'year': '2026',
        'periodo_id': 21,
        'numero_periodo': 3,
        'nota_minima_aceptada': 60,
        'profes_pueden_editar_notas': 0,
      });

      expect(ContextoAcademico.instancia.config.notaMinimaAceptada, 60);
      expect(
        ContextoAcademico.instancia.config.profesPuedenEditarNotas,
        isFalse,
      );
    });

    test('cambiar de periodo trae la configuración del nuevo', () {
      // Los dos permisos son del periodo, no del año: al moverse en la barra
      // de arriba tienen que cambiar con él.
      ContextoAcademico.instancia.tomarDelLogin({
        'periodo_id': 21,
        'numero_periodo': 3,
        'profes_pueden_editar_notas': 0,
      });

      ContextoAcademico.instancia.tomarDelLogin({
        'periodo_id': 22,
        'numero_periodo': 4,
        'profes_pueden_editar_notas': 1,
      });

      expect(
        ContextoAcademico.instancia.config.profesPuedenEditarNotas,
        isTrue,
      );
    });

    test('cerrar sesión se lleva la configuración', () {
      ContextoAcademico.instancia.tomarDelLogin({
        'nota_minima_aceptada': 60,
        'unidad_displayname': 'Logro',
      });

      ContextoAcademico.instancia.limpiar();

      expect(ContextoAcademico.instancia.config.notaMinimaAceptada, isNull);
      expect(ContextoAcademico.instancia.config.unidad, 'Unidad');
    });
  });
}
