import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myvc_flutter/RouteGenerator.dart';
import 'package:myvc_flutter/Screens/Login/LoginAnimScreen.dart';
import 'package:myvc_flutter/Screens/LoginScreen.dart';
import 'package:path_provider/path_provider.dart';

import 'Bloc/login_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );

  runApp(
    BlocProvider(
      create: (BuildContext buildContext) => LoginBloc(),
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
      //home: MyHomePage(title: 'Mi Cole Virtual'),
      home: LoginAnimScreen(),

      navigatorKey: navigatorKey,
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(child: LoginScreen()),
    );
  }
}
