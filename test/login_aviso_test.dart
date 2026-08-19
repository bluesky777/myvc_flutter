import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myvc_flutter/Bloc/login_bloc.dart';
import 'package:myvc_flutter/Screens/Login/LoginAnimScreen.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'select_server_cubit_test.dart' show AlmacenEnMemoria;

void main() {
  setUp(() {
    HydratedBloc.storage = AlmacenEnMemoria();
    SharedPreferences.setMockInitialValues({});
  });

  Widget pantalla() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SelectServerCubit(UriColegio())),
        BlocProvider(
          create: (ctx) =>
              LoginBloc(selectServerCubit: BlocProvider.of<SelectServerCubit>(ctx)),
        ),
      ],
      child: MaterialApp(home: LoginAnimScreen()),
    );
  }

  testWidgets('el aviso sale arriba, encima del botón del colegio no',
      (WidgetTester tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pump();

    // Sin colegio elegido, entrar falla sin tocar la red.
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump();

    final aviso = find.text('Elige primero tu colegio.');
    expect(aviso, findsOneWidget);

    final yAviso = tester.getTopLeft(aviso).dy;
    final yBotonColegio = tester.getTopLeft(find.text('Selecciona tu colegio')).dy;

    expect(yAviso, lessThan(yBotonColegio),
        reason: 'el aviso tiene que quedar por encima del botón del colegio');
  });

  testWidgets('el aviso se va solo a los 12 segundos',
      (WidgetTester tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Elige primero tu colegio.'), findsOneWidget);

    await tester.pump(Duration(seconds: 11));
    expect(find.text('Elige primero tu colegio.'), findsOneWidget,
        reason: 'a los 11s todavía debe estar');

    await tester.pump(Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Elige primero tu colegio.'), findsNothing);
  });
}
