import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Utils/ClasesDelDocente.dart';
import 'package:myvc_flutter/Utils/ConfiguracionColegio.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// El docente de las pruebas: la ficha 7, que es con la que casan las
/// asignaturas de abajo.
const int fichaDelDocente = 7;

/// Una asignatura como las que manda `asignaturas/listasignaturas`.
///
/// Por defecto trae los dos ids y es del docente 7, que es el caso del
/// backend ya desplegado; las pruebas que quieran lo contrario lo dicen.
AsignaturaModel asignatura({
  required int id,
  required int grupoId,
  String materia = 'Matemáticas',
  String alias = 'Mate',
  String abrev = '6.ºA',
  int? materiaId = 1,
  int? gradoId = 6,
  int? profesorId = fichaDelDocente,
}) {
  return AsignaturaModel(
    id: id,
    grupoId: grupoId,
    profesorId: profesorId,
    materia: materia,
    aliasMateria: alias,
    nombreGrupo: 'Sexto $abrev',
    abrevGrupo: abrev,
    materiaId: materiaId,
    gradoId: gradoId,
  );
}

/// Deja a quien mira como un docente de verdad: tipo 'Profesor' y con ficha.
void entraElDocente() {
  AuthService.user.tipo = 'Profesor';
  AuthService.user.personaId = fichaDelDocente;
}

/// El colegio con el periodo como lo deje coordinación.
ConfiguracionColegio conElPeriodo({required bool abierto}) {
  return ConfiguracionColegio.deLogin({
    'profes_pueden_editar_notas': abierto ? 1 : 0,
  });
}

ConfiguracionColegio get conElPeriodoAbierto => conElPeriodo(abierto: true);
ConfiguracionColegio get conElPeriodoCerrado => conElPeriodo(abierto: false);

void main() {
  setUp(() {
    AuthService.limpiar();
    ContextoAcademico.instancia.limpiar();
  });

  group('agrupar las asignaturas en clases', () {
    test('dos grupos del mismo grado son UNA clase con dos grupos', () {
      entraElDocente();

      final resultado = clasesDelDocente([
        asignatura(id: 11, grupoId: 101, abrev: '6.ºA'),
        asignatura(id: 12, grupoId: 102, abrev: '6.ºB'),
      ]);

      expect(resultado.clases, hasLength(1));
      expect(resultado.sinResolver, 0);

      final clase = resultado.clases.single;
      expect(clase.materiaId, 1);
      expect(clase.gradoId, 6);
      expect(clase.gruposIds, [101, 102]);
      expect(clase.gruposAbrev, ['6.ºA', '6.ºB']);
      expect(clase.asignaturaIds, [11, 12]);
    });

    test('la misma materia en dos grados son DOS clases', () {
      entraElDocente();

      final resultado = clasesDelDocente([
        asignatura(id: 11, grupoId: 101, gradoId: 6, abrev: '6.ºA'),
        asignatura(id: 21, grupoId: 201, gradoId: 7, abrev: '7.ºA'),
      ]);

      expect(resultado.clases, hasLength(2));
      expect(resultado.clases.map((c) => c.gradoId), [6, 7]);
      expect(resultado.clases.every((c) => c.materiaId == 1), isTrue);
    });

    test('un grupo repetido no se cuenta dos veces', () {
      // Dos asignaturas de la misma materia en el mismo grupo: pasa cuando el
      // colegio parte la materia en dos filas con distinto crédito.
      entraElDocente();

      final resultado = clasesDelDocente([
        asignatura(id: 11, grupoId: 101),
        asignatura(id: 12, grupoId: 101),
      ]);

      expect(resultado.clases.single.gruposIds, [101]);
      expect(resultado.clases.single.asignaturaIds, [11, 12]);
    });
  });

  group('las asignaturas que no se pueden resolver', () {
    test('sin materia_id ni grado_id se cuentan aparte y no revientan', () {
      // Es el backend de HOY: `fe95da8` está escrito, sin fundir y sin
      // desplegar, así que los dos ids llegan nulos en los dieciséis colegios.
      entraElDocente();

      final resultado = clasesDelDocente([
        asignatura(id: 11, grupoId: 101, materiaId: null, gradoId: null),
        asignatura(id: 12, grupoId: 102, materiaId: null, gradoId: null),
      ]);

      expect(resultado.clases, isEmpty);
      expect(resultado.sinResolver, 2);
      expect(resultado.todoSinResolver, isTrue);
      expect(resultado.hayClases, isFalse);
    });

    test('con uno solo de los dos ids tampoco vale', () {
      entraElDocente();

      final resultado = clasesDelDocente([
        asignatura(id: 11, grupoId: 101, gradoId: null),
        asignatura(id: 12, grupoId: 102, materiaId: null),
        asignatura(id: 13, grupoId: 103),
      ]);

      expect(resultado.sinResolver, 2);
      expect(resultado.clases, hasLength(1));
      expect(resultado.todoSinResolver, isFalse);
    });
  });

  group('el orden', () {
    test('por grado y luego por materia, con los números como números', () {
      entraElDocente();

      final resultado = clasesDelDocente([
        asignatura(id: 1, grupoId: 1, materiaId: 3, gradoId: 10),
        asignatura(id: 2, grupoId: 2, materiaId: 2, gradoId: 2),
        asignatura(id: 3, grupoId: 3, materiaId: 1, gradoId: 2),
      ]);

      // Sin nombre de grado —que esta ruta no trae— el desempate cae en
      // `grado_id`, o sea el orden en que el colegio creó los grados.
      expect(
        resultado.clases.map((c) => '${c.gradoId}-${c.materiaId}'),
        ['2-1', '2-2', '10-3'],
      );
    });
  });

  group('quién puede escribir el plan de área', () {
    test('el superusuario escribe aunque el periodo esté cerrado', () {
      AuthService.user.isSuperuser = true;

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101),
      ]).clases.single;

      final permiso = puedeEscribirEn(clase, config: conElPeriodoCerrado);

      expect(permiso.puede, isTrue);
      expect(permiso.porElColegio, isTrue);
      expect(permiso.motivo, isNull);
    });

    test('y también quien tenga can_edit_plantilla_notas', () {
      AuthService.user.perms = {permisoPlantillaNotas};

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101),
      ]).clases.single;

      final permiso = puedeEscribirEn(clase, config: conElPeriodoCerrado);

      expect(permiso.puede, isTrue);
      expect(permiso.porElColegio, isTrue);
    });

    test('el docente escribe en lo suyo con el periodo abierto', () {
      entraElDocente();

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101),
      ]).clases.single;

      final permiso = puedeEscribirEn(clase, config: conElPeriodoAbierto);

      expect(permiso.puede, isTrue);
      expect(permiso.porElColegio, isFalse);
    });

    test('con el periodo cerrado NO escribe, y el motivo es el periodo', () {
      entraElDocente();

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101),
      ]).clases.single;

      final permiso = puedeEscribirEn(clase, config: conElPeriodoCerrado);

      expect(permiso.puede, isFalse);
      expect(permiso.motivo, MotivoSinEscritura.periodoCerrado);
      expect(permiso.explicacion, isNotEmpty);
    });

    test('en una materia que no da NO escribe, y el motivo es que no es suya',
        () {
      // La lista es la de OTRO docente: es lo que pasa cuando un
      // administrativo abre `listasignaturas/{otro}`. El id de la ficha no casa
      // y la clase no es suya, aunque la tenga delante.
      entraElDocente();

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101, profesorId: 99),
      ]).clases.single;

      expect(clase.esMia, isFalse);

      final permiso = puedeEscribirEn(clase, config: conElPeriodoAbierto);

      expect(permiso.puede, isFalse);
      expect(permiso.motivo, MotivoSinEscritura.noEsMia);
    });

    test('el periodo cerrado no tapa al que no es suyo', () {
      // El orden importa: al revés, quien no da la materia leería «el periodo
      // está cerrado», que es verdad y no es su problema.
      entraElDocente();

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101, profesorId: 99),
      ]).clases.single;

      final permiso = puedeEscribirEn(clase, config: conElPeriodoCerrado);

      expect(permiso.motivo, MotivoSinEscritura.noEsMia);
    });

    test('el administrativo con el rol de profesor tampoco hereda la ficha',
        () {
      // `persona_id` de un 'Usuario' es `users.id`, no `profesores.id`: sin el
      // `tipo == 'Profesor'` el administrativo número 7 se quedaría con las
      // asignaturas del profesor número 7.
      AuthService.user.tipo = 'Usuario';
      AuthService.user.personaId = fichaDelDocente;
      AuthService.user.roles = {'profesor'};

      final clase = clasesDelDocente([
        asignatura(id: 11, grupoId: 101),
      ]).clases.single;

      expect(clase.esMia, isFalse);
      expect(
        puedeEscribirEn(clase, config: conElPeriodoAbierto).motivo,
        MotivoSinEscritura.noEsMia,
      );
    });

    group('las filas de «todos los grados»', () {
      const delColegio = ClaseDelDocente.todosLosGrados(
        materiaId: 1,
        materia: 'Matemáticas',
      );

      test('el docente NO las escribe aunque dé esa materia', () {
        // Alcanzan a grados que no da: dejárselas sería darle por la puerta de
        // atrás el alcance que el permiso le niega por la de delante.
        entraElDocente();

        final permiso =
            puedeEscribirEn(delColegio, config: conElPeriodoAbierto);

        expect(permiso.puede, isFalse);
        expect(permiso.motivo, MotivoSinEscritura.noEsMia);
      });

      test('ni nadie sin can_edit_plantilla_notas', () {
        AuthService.user.roles = {'coord académico', 'rector'};

        expect(
          puedeEscribirEn(delColegio, config: conElPeriodoAbierto).puede,
          isFalse,
        );
      });

      test('y con el permiso del colegio sí', () {
        AuthService.user.perms = {permisoPlantillaNotas};

        expect(
          puedeEscribirEn(delColegio, config: conElPeriodoAbierto).puede,
          isTrue,
        );
      });
    });
  });

  group('los permisos que manda el login', () {
    test('se leen de `perms`, en minúsculas y sin repetidos', () {
      LoginController.tomarUsuarioDe({
        'user_id': 3,
        'username': 'docente',
        'perms': [
          'can_edit_plantilla_notas',
          'CAN_VIEW_AUDITORIA',
          '  can_edit_plantilla_notas  ',
          '',
          null,
        ],
      });

      expect(AuthService.user.perms, {
        'can_edit_plantilla_notas',
        'can_view_auditoria',
      });
      expect(AuthService.user.tienePermiso('can_edit_plantilla_notas'), isTrue);
      expect(AuthService.user.tienePermiso('can_view_auditoria'), isTrue);
      expect(AuthService.user.tienePermiso('can_hacer_lo_que_sea'), isFalse);
    });

    test('un login sin `perms` deja el conjunto vacío, no revienta', () {
      LoginController.tomarUsuarioDe({'user_id': 3, 'username': 'docente'});

      expect(AuthService.user.perms, isEmpty);
      expect(AuthService.user.tienePermiso(permisoPlantillaNotas), isFalse);
    });

    test('cerrar la sesión se los lleva', () {
      AuthService.user.perms = {permisoPlantillaNotas};
      AuthService.limpiar();

      expect(AuthService.user.perms, isEmpty);
      expect(AuthService.user.tienePermiso(permisoPlantillaNotas), isFalse);
    });
  });
}
