import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';

void main() {
  setUp(AuthService.limpiar);

  /// Monta el menú en un lienzo alto.
  ///
  /// Alto a propósito. En la pantalla de 800x600 que traen las pruebas, el menú
  /// de un administrativo ya no cabe —Inicio, Asistencias, Notas, Notas
  /// perdidas, Unidades, Disciplina, Usuarios, Configuración, Privacidad y
  /// cerrar sesión—, y un `ListView` no construye lo que no se ve: la última
  /// fila «no aparece» y la prueba falla con una cara engañosa, como si la
  /// opción no estuviera puesta.
  ///
  /// Pasó al añadir «Usuarios», y con un `drag` volvería a pasar en cuanto el
  /// menú creciera otra vez. Con el lienzo alto, estas pruebas vuelven a ser
  /// sobre quién ve qué y no sobre cuántos píxeles mide la lista.
  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: MenuLateral()));
    await tester.pump();
  }

  group('el nombre en la cabecera', () {
    testWidgets('el de quien tiene ficha con nombres',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(
        username: 'agomez',
        nombres: 'Ariolfo Gómez',
        tipo: 'Profesor',
      );

      await montar(tester);

      expect(find.text('Ariolfo Gómez'), findsOneWidget);
      expect(find.text('agomez'), findsOneWidget);
    });

    testWidgets('el nombre de usuario cuando no hay ficha con nombres',
        (WidgetTester tester) async {
      // Es el caso del administrador: tipo Usuario, sin nombres. Antes le
      // decía «Sin identificar» a alguien que está perfectamente identificado.
      AuthService.user = UserAutenticado(
        username: 'administrador',
        tipo: 'Usuario',
      );

      await montar(tester);

      expect(find.text('administrador'), findsWidgets);
      expect(find.text('Sin identificar'), findsNothing);
    });

    testWidgets('unos nombres en blanco cuentan como no tenerlos',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'agomez', nombres: '   ');

      await montar(tester);

      expect(find.text('agomez'), findsWidgets);
    });
  });

  group('el logo', () {
    testWidgets('es el fondo de la cabecera, no una fila del menú',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'administrador');

      await montar(tester);

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.fit, BoxFit.cover,
          reason: 'un fondo llena su hueco; una fila no');
    });
  });

  group('las opciones según quién entra', () {
    testWidgets('un docente ve Asistencias y Unidades',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'x', tipo: 'Profesor');

      await montar(tester);

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Asistencias'), findsOneWidget);
      expect(find.text('Unidades'), findsOneWidget);
      expect(find.text('Mis notas'), findsNothing);
    });

    testWidgets('un alumno ve Mis notas y Asistencia',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'x', tipo: 'Alumno');

      await montar(tester);

      expect(find.text('Mis notas'), findsOneWidget);
      expect(find.text('Asistencia'), findsOneWidget);
      expect(find.text('Unidades'), findsNothing);
      expect(find.text('Asistencias'), findsNothing);
    });

    testWidgets('el docente llega a Notas, a las perdidas y a Configuración',
        (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'x', tipo: 'Profesor');

      await montar(tester);

      expect(find.text('Notas'), findsOneWidget);
      expect(find.text('Notas perdidas'), findsOneWidget);
      expect(find.text('Disciplina'), findsOneWidget);
      // La ve todo el personal aunque solo un administrador pueda mover los
      // interruptores: la mitad de su gracia es explicarle a un docente por
      // qué hoy no puede editar notas.
      expect(find.text('Configuración'), findsOneWidget);
    });

    testWidgets('a un acudiente no se le ofrece nada del personal',
        (WidgetTester tester) async {
      // No es solo pudor: todas esas pantallas piden endpoints con
      // `auth.personal`, que a un acudiente le responden 403. Ofrecérselas
      // sería ofrecerle una pantalla de error.
      AuthService.user = UserAutenticado(username: 'x', tipo: 'Acudiente');

      await montar(tester);

      expect(find.text('Notas'), findsNothing);
      expect(find.text('Notas perdidas'), findsNothing);
      expect(find.text('Disciplina'), findsNothing);
      expect(find.text('Configuración'), findsNothing);
    });
  });
  group('Privacidad', () {
    // El interruptor de las estadísticas vive ahí dentro, y apagarlo no puede
    // ser un privilegio del personal: un acudiente es igual de dueño de su
    // teléfono que un coordinador. Configuración no servía —el menú corta
    // antes para alumnos y acudientes—, y por eso es una opción aparte.
    for (final caso in [
      ('un alumno', UserAutenticado(username: 'a', tipo: 'Alumno')),
      ('un acudiente', UserAutenticado(username: 'b', tipo: 'Acudiente')),
      ('un docente', UserAutenticado(username: 'c', tipo: 'Profesor')),
      ('un administrador',
          UserAutenticado(username: 'd', tipo: 'Usuario', isSuperuser: true)),
    ]) {
      testWidgets('la ve ${caso.$1}', (WidgetTester tester) async {
        AuthService.user = caso.$2;

        await montar(tester);

        expect(find.text('Privacidad'), findsOneWidget);
      });
    }

    testWidgets('y un alumno sigue sin ver lo que no es suyo',
        (WidgetTester tester) async {
      // Que Privacidad se cuele en la rama de alumno no puede haber abierto de
      // paso las opciones del personal.
      AuthService.user = UserAutenticado(username: 'a', tipo: 'Alumno');

      await montar(tester);

      expect(find.text('Privacidad'), findsOneWidget);
      expect(find.text('Disciplina'), findsNothing);
      expect(find.text('Configuración'), findsNothing);
      expect(find.text('Notas perdidas'), findsNothing);
    });
  });
}
