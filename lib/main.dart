import 'package:flutter/material.dart';
import 'package:myvc_flutter/RouteGenerator.dart';
import 'package:myvc_flutter/Screens/LoginAnimScreen.dart';
import 'package:myvc_flutter/Screens/LoginScreen.dart';

void main() {
  runApp(MyApp());
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
      home: LoginAnimScreen(
        title: 'Bienvenido',
      ),

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
