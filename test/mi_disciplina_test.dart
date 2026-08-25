import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Screens/FichaDisciplinaScreen.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

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

  group('la opción del menú', () {
    testWidgets('no se le ofrece a un alumno mientras el endpoint no esté',
        (WidgetTester tester) async {
      // `disciplina/mis-fichas` está fusionado en el backend pero no desplegado
      // en los dieciséis colegios. Una opción de menú que termina en 404 es
      // peor que no tenerla, y el fallo saldría en dieciséis sitios a la vez.
      expect(Interruptores.disciplinaMisFichas, isFalse);

      AuthService.user = UserAutenticado(username: 'a', tipo: 'Alumno');

      await tester.pumpWidget(MaterialApp(home: MenuLateral()));
      await tester.pump();

      expect(find.text('Disciplina'), findsNothing);
    });

    testWidgets('y al personal se le sigue sin ofrecer la suya por error',
        (WidgetTester tester) async {
      // La de disciplina del personal es otra ruta y otra pantalla; que un
      // alumno no vea ninguna de las dos es el fondo del asunto.
      AuthService.user = UserAutenticado(username: 'b', tipo: 'Acudiente');

      await tester.pumpWidget(MaterialApp(home: MenuLateral()));
      await tester.pump();

      expect(find.text('Disciplina'), findsNothing);
    });
  });
}
