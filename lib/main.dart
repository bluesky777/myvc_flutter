import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myvc_flutter/Screens/Login/LoginAnimScreen.dart';
import 'package:myvc_flutter/Screens/RouteGenerator.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';
import 'package:path_provider/path_provider.dart';

import 'Bloc/login_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SelectServerCubit(UriColegio()),
        ),
        BlocProvider(
          create: (BuildContext buildContext) => LoginBloc(
            selectServerCubit: BlocProvider.of<SelectServerCubit>(buildContext),
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // Para las rutas
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyVC app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginAnimScreen(),
      navigatorKey: navigatorKey,
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
