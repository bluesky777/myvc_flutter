import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Screens/FichaDisciplinaScreen.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// Un servidor de mentira que apunta la ruta que le piden.
class ServidorFingido extends Server {
  ServidorFingido(this.respuesta);

  final http.Response respuesta;
  final List<String> rutas = [];

  @override
  Future get(String direccion) async {
    rutas.add(direccion);
    return respuesta;
  }
}

http.Response ficha({Object? config = const {}}) {
  return http.Response(
    jsonEncode({
      'alumno': {
        'alumno_id': 31,
        'nombres': 'Dámaris',
        'apellidos': 'Gómez Pico',
        'estado': 'MATR',
      },
      'config': config,
      'ordinales': [],
    }),
    200,
  );
}

AlumnoDisciplinaModel _alumno() {
  return AlumnoDisciplinaModel.fromJson({
    'alumno_id': 31,
    'nombres': 'Dámaris',
    'apellidos': 'Gómez Pico',
    'estado': 'MATR',
    'periodo3': [
      {
        'id': 700,
        'tipo': 1,
        'descripcion': 'Llegó tarde tres veces seguidas',
        'fecha': '2026-08-20',
        'periodo_id': 3,
      },
    ],
    'per3_cant_t1': 1,
  });
}

Future<void> _montar(WidgetTester tester, {required bool soloLectura}) async {
  await tester.pumpWidget(MaterialApp(
    home: FichaDisciplinaScreen(
      args: FichaDisciplinaArgs(
        alumno: _alumno(),
        datos: DatosDisciplina(),
        grupoId: 0,
        periodoInicial: 3,
        soloLectura: soloLectura,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUp(AuthService.limpiar);

  group('la ficha en modo lectura', () {
    testWidgets('no ofrece crear una situación', (WidgetTester tester) async {
      await _montar(tester, soloLectura: true);

      expect(find.text('Nueva situación'), findsNothing);
    });

    testWidgets('el personal sí lo ve, que es como estaba',
        (WidgetTester tester) async {
      // La misma pantalla, y por eso hay que comprobar que el modo lectura no
      // se le coló al docente: es la mitad del riesgo de reutilizarla.
      await _montar(tester, soloLectura: false);

      expect(find.text('Nueva situación'), findsOneWidget);
    });

    testWidgets('la situación se ve, pero no se puede abrir a editar',
        (WidgetTester tester) async {
      await _montar(tester, soloLectura: true);

      // Se ve: la familia viene justamente a leer esto.
      expect(find.textContaining('Llegó tarde'), findsOneWidget);

      // Y no lleva a ninguna parte. Un InkWell con onTap null no responde, así
      // que tocarlo no puede abrir el editor.
      final tocable = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.textContaining('Llegó tarde'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(tocable.onTap, isNull);
    });
  });

  group('de quién es la ficha que se pide', () {
    test('con id va en la ruta, que es lo que necesita un acudiente', () async {
      // **Un acudiente sin id recibe 400, no su ficha.** El backend solo
      // resuelve «lo mío» para `tipo == 'Alumno'`: «lo mío» no significa nada
      // para quien tiene varios acudidos. Por eso MiDisciplinaScreen pregunta
      // de qué acudido antes de llamar, y por eso esto se comprueba aquí.
      final servidor = ServidorFingido(ficha());

      await traerMisFichas(servidor, alumnoId: 31);

      expect(servidor.rutas, ['/disciplina/mis-fichas/31']);
    });

    test('sin id la ruta va pelada, y eso es sesión de alumno', () async {
      final servidor = ServidorFingido(ficha());

      await traerMisFichas(servidor);

      expect(servidor.rutas, ['/disciplina/mis-fichas']);
    });

    test('un año sin configuración llega como null y no revienta', () async {
      // `config` sale del backend como `$config[0] ?? null`: un año sin fila en
      // `dis_configuraciones` llega nulo, y esa lectura no crea la fila a
      // propósito. Leer `falta_tipoN_displayname` sin defensa reventaría en la
      // primera ficha de un año recién abierto.
      final servidor = ServidorFingido(ficha(config: null));

      final traida = await traerMisFichas(servidor, alumnoId: 31);

      expect(traida.alumno.alumnoId, 31);
      // Los nombres genéricos de los tres tipos, que es lo que hay que enseñar
      // cuando el colegio no los ha renombrado todavía.
      expect(traida.datos.config.nombre(1), isNotEmpty);
    });
  });

  group('la opción del menú', () {
    /// Monta el menú y recuerda a qué ruta manda lo que se toque.
    ///
    /// El lienzo va alto por lo mismo que en `menu_lateral_test`: un `ListView`
    /// no construye lo que no se ve, y una opción que no cabe falla con la cara
    /// de una opción que no está puesta.
    Future<List<String?>> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final visitadas = <String?>[];

      await tester.pumpWidget(MaterialApp(
        home: MenuLateral(),
        onGenerateRoute: (settings) {
          visitadas.add(settings.name);
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ));
      await tester.pump();

      return visitadas;
    }

    testWidgets('un alumno la ve, y lleva a la suya y no a la del personal',
        (WidgetTester tester) async {
      // El endpoint entró en el backend con `83bf717` y se desplegó el 25 ago
      // 2026 en los quince colegios dentro de la tanda `eb95cbc`. La ruta a la
      // que manda es la mitad del asunto: `/disciplina` es la del personal y
      // lleva `auth.personal`, que a un alumno le contesta 403.
      expect(Interruptores.disciplinaMisFichas, isTrue);

      AuthService.user = UserAutenticado(username: 'a', tipo: 'Alumno');

      final visitadas = await montar(tester);
      expect(find.text('Disciplina'), findsOneWidget);

      await tester.tap(find.text('Disciplina'));
      await tester.pumpAndSettle();

      expect(visitadas, contains('/mi-disciplina'));
      expect(visitadas, isNot(contains('/disciplina')));
    });

    testWidgets('un acudiente también', (WidgetTester tester) async {
      AuthService.user = UserAutenticado(username: 'b', tipo: 'Acudiente');

      final visitadas = await montar(tester);
      expect(find.text('Disciplina'), findsOneWidget);

      await tester.tap(find.text('Disciplina'));
      await tester.pumpAndSettle();

      expect(visitadas, contains('/mi-disciplina'));
    });

    testWidgets('y al personal se le sigue ofreciendo la suya, la de editar',
        (WidgetTester tester) async {
      // La misma palabra en el menú y dos pantallas distintas detrás. Que a un
      // docente no se le cuele la de sólo lectura es la otra mitad del riesgo
      // de compartir el nombre.
      AuthService.user = UserAutenticado(username: 'c', tipo: 'Profesor');

      final visitadas = await montar(tester);

      await tester.tap(find.text('Disciplina'));
      await tester.pumpAndSettle();

      expect(visitadas, contains('/disciplina'));
      expect(visitadas, isNot(contains('/mi-disciplina')));
    });
  });
}
