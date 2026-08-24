import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/UsuariosApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/CuentaDeUsuarioModel.dart';
import 'package:myvc_flutter/Screens/UsuariosScreen.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';

void main() {
  setUp(() {
    AuthService.limpiar();
    PendientesUsuarios.comoDeFabrica();
  });

  group('un alumno del listado de un grupo', () {
    test('se lee con su cuenta y su foto', () {
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': '31',
        'user_id': '412',
        'nombres': 'Dámaris',
        'apellidos': 'Gómez Pico',
        'username': 'damaris.gomez',
        'foto_nombre': 'user_2/damaris.jpg',
      });

      expect(cuenta.personaId, 31);
      expect(cuenta.userId, 412);
      expect(cuenta.nombreCompleto, 'Dámaris Gómez Pico');
      expect(cuenta.username, 'damaris.gomez');
      expect(cuenta.tipo, TipoDeCuenta.alumno);
      expect(cuenta.tieneCuenta, isTrue);
    });

    test('un alumno sin cuenta se lee igual, y dice que no la tiene', () {
      // Pasa y no es un error: hay matriculados a los que nadie se la ha
      // creado. `grupos/listado` hace LEFT JOIN con users, así que llega con
      // user_id y username en null.
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': 44,
        'user_id': null,
        'nombres': 'Juan',
        'apellidos': 'Pérez',
        'username': null,
      });

      expect(cuenta.tieneCuenta, isFalse);
      expect(cuenta.username, isNull);
      expect(cuenta.nombreCompleto, 'Juan Pérez');
    });

    test('el celular y el documento vienen vacíos, que es lo que hay hoy', () {
      // `grupos/listado` no los trae. No es un fallo de lectura: es el hueco
      // que está pedido al servidor, y la pantalla lo enseña vacío en vez de
      // inventárselo. Ver docs/usuarios.md.
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': 1,
        'user_id': 2,
        'nombres': 'X',
      });

      expect(cuenta.celular, isNull);
      expect(cuenta.documento, isNull);
    });
  });

  group('un acudiente', () {
    Map<String, dynamic> conRejilla() => {
          'id': '9',
          'user_id': '77',
          'nombres': 'Luz Marina',
          'apellidos': 'Ospina',
          'username': '43567890',
          'documento': '43567890',
          'celular': '3001234567',
          'parentesco': 'Madre',
          'foto_nombre': 'user_9/luz.jpg',
          // Tal como llega hoy: los acudidos viven dentro de la maqueta de la
          // rejilla de Angular que el servidor le manda al front web.
          'subGridOptions': {
            'enableCellEditOnFocus': false,
            'columnDefs': [
              {'name': 'Grupo', 'field': 'nombre_grupo'},
            ],
            'data': [
              {
                'user_id': '412',
                'nombres': 'Sara',
                'apellidos': 'Ospina',
                'username': 'sara.ospina',
                'nombre_grupo': 'Tercero A',
                'parentesco': 'Madre',
              },
              {
                'user_id': null,
                'nombres': 'Juan David',
                'apellidos': 'Ospina',
                'nombre_grupo': 'Noveno B',
              },
            ],
          },
        };

    test('se lee con su celular, su documento y su parentesco', () {
      final cuenta = CuentaDeUsuario.deAcudiente(conRejilla());

      expect(cuenta.tipo, TipoDeCuenta.acudiente);
      expect(cuenta.personaId, 9);
      expect(cuenta.userId, 77);
      expect(cuenta.celular, '3001234567');
      expect(cuenta.documento, '43567890');
      expect(cuenta.parentesco, 'Madre');
    });

    test('sus acudidos salen de dentro de la rejilla del front web', () {
      // Es la única forma de tenerlos hoy. El día que el servidor los mande
      // llanos, este test sigue valiendo y el de abajo también.
      final cuenta = CuentaDeUsuario.deAcudiente(conRejilla());

      expect(cuenta.acudidos, hasLength(2));
      expect(cuenta.acudidos.first.nombreCompleto, 'Sara Ospina');
      expect(cuenta.acudidos.first.nombreGrupo, 'Tercero A');
      expect(cuenta.acudidos.first.tieneCuenta, isTrue);
    });

    test('un acudido sin cuenta lo dice, en vez de fingir una', () {
      final cuenta = CuentaDeUsuario.deAcudiente(conRejilla());

      expect(cuenta.acudidos.last.tieneCuenta, isFalse);
      expect(cuenta.acudidos.last.username, isNull);
    });

    test('si el servidor los manda llanos, gana esa lista', () {
      // Lo pedido: `acudidos` como lista de verdad, sin la maqueta. Cuando
      // llegue, la fábrica la prefiere y no hay que tocar nada más.
      final crudo = conRejilla();
      crudo['acudidos'] = [
        {'user_id': 500, 'nombres': 'Sara', 'apellidos': 'Ospina'},
      ];

      final cuenta = CuentaDeUsuario.deAcudiente(crudo);

      expect(cuenta.acudidos, hasLength(1));
      expect(cuenta.acudidos.single.userId, 500);
    });

    test('sin acudidos no revienta: se queda con la lista vacía', () {
      final cuenta = CuentaDeUsuario.deAcudiente({
        'id': 3,
        'user_id': 4,
        'nombres': 'Sin',
        'apellidos': 'Hijos',
      });

      expect(cuenta.acudidos, isEmpty);
    });

    test('sin celular se cae al teléfono fijo, que es mejor que nada', () {
      final cuenta = CuentaDeUsuario.deAcudiente({
        'id': 3,
        'user_id': 4,
        'nombres': 'Sin',
        'apellidos': 'Celular',
        'telefono': '8901234',
      });

      expect(cuenta.celular, '8901234');
    });
  });

  group('un docente', () {
    test('se lee con los años en que ha estado contratado', () {
      final cuenta = CuentaDeUsuario.deDocente({
        'id': '5',
        'user_id': '18',
        'nombres': 'Ariolfo',
        'apellidos': 'Gómez',
        'foto_nombre': 'user_2/P Ariolfo.JPG',
        'years': [
          {'id': 1, 'year': '2024'},
          {'id': 2, 'year': 2025},
          {'id': 3, 'year': '2026'},
        ],
      });

      expect(cuenta.tipo, TipoDeCuenta.docente);
      expect(cuenta.years, ['2024', '2025', '2026']);
    });

    test('sin contratos la lista queda vacía, no nula', () {
      final cuenta = CuentaDeUsuario.deDocente({
        'id': 5,
        'user_id': 18,
        'nombres': 'Recién',
        'apellidos': 'Llegado',
      });

      expect(cuenta.years, isEmpty);
    });
  });

  group('una cuenta sin ficha', () {
    test('el nombre de usuario ES el nombre', () {
      // La regla del resto de la app: los de tipo Usuario no tienen ficha con
      // nombres, y decirles «Sin nombre» a quienes están identificados no
      // tiene sentido.
      final cuenta = CuentaDeUsuario.deOtro({
        'user_id': 1,
        'username': 'administrador',
        'nombres': '',
        'apellidos': '',
      });

      expect(cuenta.nombreCompleto, 'administrador');
    });

    test('cuando el listado la nombra por `id` y no por `user_id`', () {
      final cuenta = CuentaDeUsuario.deOtro({
        'id': 88,
        'username': 'enfermeria',
      });

      expect(cuenta.userId, 88);
    });
  });

  group('los roles', () {
    test('se leen del catálogo tal como estén escritos', () {
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': 1,
        'user_id': 2,
        'nombres': 'X',
        'roles': [
          {'id': '3', 'name': 'Admin'},
          {'id': 4, 'name': 'Coord disciplinario'},
        ],
      });

      expect(cuenta.roles.map((r) => r.nombre),
          ['Admin', 'Coord disciplinario']);
      expect(cuenta.roles.first.clave, 'admin');
    });

    test('lo que no sea una lista de roles se ignora sin tirar', () {
      // Los listados del backend se arman con SQL a pelo: más vale una lista
      // vacía que una excepción que deja al grupo entero sin pintar.
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': 1,
        'user_id': 2,
        'nombres': 'X',
        'roles': 'Admin',
      });

      expect(cuenta.roles, isEmpty);
    });
  });

  group('la última vez', () {
    test('se lee el datetime del servidor tal cual, sin correrlo de hora', () {
      // Como en el resto de la app: el backend guarda la hora de Bogotá, y
      // pasarla por toLocal() la correría cinco horas.
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': 1,
        'user_id': 2,
        'nombres': 'X',
        'ultimo_acceso': '2026-08-23 14:30:00',
      });

      expect(cuenta.ultimoAcceso!.hour, 14);
      expect(cuenta.ultimoAcceso!.day, 23);
    });

    test('una fecha ilegible deja el dato vacío, no la lista sin pintar', () {
      final cuenta = CuentaDeUsuario.deAlumnoDeGrupo({
        'alumno_id': 1,
        'user_id': 2,
        'nombres': 'X',
        'ultimo_acceso': 'nunca',
      });

      expect(cuenta.ultimoAcceso, isNull);
    });
  });

  group('los interruptores de lo que falta', () {
    test('vienen todos apagados', () {
      // El de `cambiarUsername` es el que importa: encendido, la pantalla se
      // convierte en el cliente cómodo de una ruta que hoy deja a cualquier
      // docente renombrar la cuenta de un superusuario. Ver docs/usuarios.md.
      expect(PendientesUsuarios.cambiarUsername, isFalse);
      expect(PendientesUsuarios.rolesPorPersona, isFalse);
      expect(PendientesUsuarios.ultimoAcceso, isFalse);
      expect(PendientesUsuarios.otrosUsuarios, isFalse);
      expect(PendientesUsuarios.masivasPorGrupoQueFaltan, isFalse);
    });

    test('encenderlos y volver a fábrica es una llamada', () {
      PendientesUsuarios.cambiarUsername = true;
      PendientesUsuarios.rolesPorPersona = true;

      PendientesUsuarios.comoDeFabrica();

      expect(PendientesUsuarios.cambiarUsername, isFalse);
      expect(PendientesUsuarios.rolesPorPersona, isFalse);
    });
  });

  group('lo que dijo el servidor cuando dice que no', () {
    // Quién puede hacer cada cosa cambia con el despliegue —la contraseña de un
    // grupo pasó de superusuario a superusuario o secretaría— y los dieciséis
    // colegios no se actualizan el mismo día. Una frase escrita en la app
    // envejece sin avisar; la del servidor llega siempre al día.
    test('se prefiere su explicación a la nuestra', () {
      expect(
        loQueDijoElServidor(
            '{"message":"Solo un administrativo puede cambiar las cuentas."}'),
        'Solo un administrativo puede cambiar las cuentas.',
      );
    });

    test('una página de error en HTML no es una explicación', () {
      // Sin `Accept: application/json`, Laravel puede contestar su página de
      // error. Enseñarla entera en un aviso sería peor que no decir nada.
      expect(loQueDijoElServidor('<!DOCTYPE html><html>...'), isNull);
    });

    test('un volcado de excepción tampoco', () {
      // Es JSON perfectamente válido, y no le dice nada a una secretaria; y de
      // paso enseña de más. El corte por largo no es cosmético.
      final traza = '{"message":"${'SQLSTATE[23000] en la línea ' * 20}"}';

      expect(loQueDijoElServidor(traza), isNull);
      expect(loQueDijoElServidor('{"message":"Error\\nen dos líneas"}'), isNull);
    });

    test('sin cuerpo, sin message o con basura, se cae a lo nuestro', () {
      expect(loQueDijoElServidor(''), isNull);
      expect(loQueDijoElServidor(null), isNull);
      expect(loQueDijoElServidor('{"otra":"cosa"}'), isNull);
      expect(loQueDijoElServidor('no es json'), isNull);
    });
  });

  group('cuántas contraseñas cambió', () {
    test('el número, cuando el servidor lo manda', () {
      expect(
        cuantasCambiaron('{"resultado":"Cambiadas","cambiadas":31}'),
        31,
      );
    });

    test('también si llega como cadena, que lo decide PDO', () {
      expect(cuantasCambiaron('{"cambiadas":"31"}'), 31);
    });

    test('la versión de hoy no lo dice, y eso no es un error', () {
      // Contesta la palabra «Cambiadas» y ya. Se pregunta por el número en vez
      // de exigirlo para que la app valga antes y después del despliegue.
      expect(cuantasCambiaron('"Cambiadas"'), isNull);
      expect(cuantasCambiaron('Cambiadas'), isNull);
      expect(cuantasCambiaron(''), isNull);
    });
  });

  group('quién administra cuentas', () {
    UserAutenticado con({Set<String> roles = const {}, bool superuser = false}) {
      return UserAutenticado(
        roles: roles.map((r) => r.toLowerCase()).toSet(),
        isSuperuser: superuser,
      );
    }

    test('un superusuario', () {
      expect(con(superuser: true).administraCuentas, isTrue);
    });

    test('un Admin, esté como esté escrito en la tabla', () {
      expect(con(roles: {'Admin'}).administraCuentas, isTrue);
      expect(con(roles: {'admin'}).administraCuentas, isTrue);
    });

    test('un Secretario, que es la razón de existir de ese rol', () {
      // Se creó el 21 de agosto de 2026 y no lo tiene nadie todavía: es
      // exactamente para una secretaria docente que arregla usuarios sin ser
      // superusuaria.
      expect(con(roles: {'secretario'}).administraCuentas, isTrue);
    });

    test('un docente cualquiera, no', () {
      expect(con(roles: {'profesor'}).administraCuentas, isFalse);
      expect(con(roles: {'coord disciplinario'}).administraCuentas, isFalse);
    });
  });

  group('la pantalla', () {
    // Se monta sin servidor detrás: `Server.urlServer` está vacío en las
    // pruebas, así que la primera petición falla y la pantalla cae en su estado
    // de error. Es a propósito — lo que se comprueba aquí es lo que la pantalla
    // dice **sin** datos: los cuatro tipos, y qué contesta cuando algo todavía
    // no se puede hacer.
    Future<void> montar(WidgetTester tester) async {
      AuthService.user = UserAutenticado(
        username: 'administrador',
        tipo: 'Usuario',
        isSuperuser: true,
      );

      await tester.pumpWidget(MaterialApp(home: const UsuariosScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('se entra eligiendo el tipo, y los cuatro están',
        (WidgetTester tester) async {
      await montar(tester);

      expect(find.widgetWithText(ChoiceChip, 'Alumnos'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Acudientes'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Profesores'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Otros'), findsOneWidget);
    });

    testWidgets('«Otros» explica qué falta en vez de decir «no disponible»',
        (WidgetTester tester) async {
      // Quien lee esto es quien puede pedirlo, y «no disponible» no se puede
      // pedir. Ver docs/usuarios.md.
      await montar(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Otros'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.279'), findsOneWidget);
      expect(find.textContaining('Está pedido'), findsOneWidget);
    });

    testWidgets('si los grupos no llegan, lo dice y deja reintentar',
        (WidgetTester tester) async {
      // Sin servidor detrás es lo que pasa, y es el estado que de verdad ve
      // alguien con el colegio caído o sin datos en el teléfono: el motivo
      // escrito y un botón, en vez de una lista vacía que parece un colegio
      // sin grupos.
      await montar(tester);

      expect(find.textContaining('No se pudieron traer los grupos'),
          findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('la opción del menú', () {
    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: MenuLateral()));
      await tester.pump();
    }

    testWidgets('la ve quien administra cuentas',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(
        username: 'administrador',
        tipo: 'Usuario',
        isSuperuser: true,
      );

      await montar(tester);

      expect(find.text('Usuarios'), findsOneWidget);
    });

    testWidgets('un docente no la ve', (WidgetTester tester) async {
      // Y no es pudor: dentro está el nombre de usuario y el celular de las
      // familias de un grupo entero.
      AuthService.user = UserAutenticado(username: 'agomez', tipo: 'Profesor');

      await montar(tester);

      expect(find.text('Usuarios'), findsNothing);
      expect(find.text('Configuración'), findsOneWidget,
          reason: 'esa sí la ve, en gris por dentro');
    });

    testWidgets('un acudiente tampoco, ni de lejos',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'luz', tipo: 'Acudiente');

      await montar(tester);

      expect(find.text('Usuarios'), findsNothing);
    });
  });
}
