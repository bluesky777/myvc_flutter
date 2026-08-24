import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/Screens/RouteGenerator.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';
import 'package:path_provider/path_provider.dart';

import 'Bloc/login_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La analítica, antes de nada, para que el arranque también se cuente. Si
  // Firebase falla —sin red al abrir, un google-services.json que no llegó al
  // build— la app tiene que arrancar igual: saber cuánta gente la usa no puede
  // ser el motivo de que no se pueda usar. Ver docs/analitica.md.
  if (Analitica.disponible) {
    try {
      await Firebase.initializeApp();
      Analitica.arrancar();
    } catch (_) {
      // Sin analítica, y sin ruido para quien solo quiere entrar.
    }
  }

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getApplicationDocumentsDirectory()).path),
  );

  // Antes de pintar nada: si hay una sesión guardada y sigue valiendo, se
  // recupera. Es lo que hace que recargar la página en la web no tire al
  // usuario a la calle. Ver LoginController.restaurar().
  final haySesion = await LoginController().restaurar();

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
      child: MyApp(haySesion: haySesion),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key, this.haySesion = false});

  /// Si al arrancar se recuperó una sesión que el servidor da por buena.
  final bool haySesion;

  // Para las rutas
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyVC app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // En español, que es el idioma del colegio. Sin esto, lo que pinta
      // Material por su cuenta —el calendario, sus botones, los meses, los días
      // de la semana— salía en inglés en medio de pantallas en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Sin `home:` a propósito: con él, la ruta '/' era siempre el login y no
      // había forma de arrancar en otra pantalla. Ahora la primera ruta se
      // decide arriba, y '/' la resuelve RouteGenerator como el login.
      initialRoute: rutaDeArranque(
        ui.PlatformDispatcher.instance.defaultRouteName,
        haySesion: haySesion,
      ),
      // Una ruta, no una pila. Flutter, ante un initialRoute como
      // '/mis-notas', monta por debajo también '/' —parte la ruta por sus
      // tramos—, y eso dejaría el login montado debajo de la pantalla del
      // usuario: se vería al volver atrás, y se construiría de balde en cada
      // arranque.
      onGenerateInitialRoutes: (ruta) => [
        RouteGenerator.generateRoute(RouteSettings(name: ruta)),
      ],
      navigatorKey: navigatorKey,
      // Vacío cuando no hay analítica, que es siempre en web y en las pruebas.
      navigatorObservers: Analitica.observadores,
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}

/// Con qué pantalla abre la app.
///
/// En la web, el navegador dice en qué ruta estaba: al recargar en «Mis notas»,
/// `defaultRouteName` llega como '/mis-notas' y hay que volver ahí, no al
/// principio. En el móvil llega siempre '/'.
///
/// Sin sesión no se discute: al login, aunque el navegador pida otra cosa. Es
/// lo que faltaba y por lo que recargar acababa en una pantalla que pedía datos
/// con el token en null y recibía 404 de un servidor que ni siquiera era el del
/// colegio.
String rutaDeArranque(String delNavegador, {required bool haySesion}) {
  if (!haySesion) return '/login';

  return delNavegador == '/' ? '/muro' : delNavegador;
}
