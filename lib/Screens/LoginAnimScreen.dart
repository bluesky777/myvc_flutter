import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Screens/Login/RoundedPasswordInput.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Login/FormSelectServidor.dart';
import 'Login/RoundedButton.dart';
import 'Login/RoundedInput.dart';

class LoginAnimScreen extends StatefulWidget {
  const LoginAnimScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _LoginAnimScreenState createState() => _LoginAnimScreenState();
}

class _LoginAnimScreenState extends State<LoginAnimScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  Animation<double>? containerSize;
  AnimationController? animationController;
  Duration animationDuration = Duration(milliseconds: 270);
  //final _formKey = GlobalKey<FormState>();
  String textoUri = ''; // 'http://192.168.18.215'
  String servidorElegido = '';
  bool isLoading = false;

  TextEditingController usenameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);

    animationController =
        AnimationController(vsync: this, duration: animationDuration);

    //textoUri = 'http://192.168.18.215';

    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? guardado = preferences.getString('uriColegio');
      if (guardado != null) {
        servidorElegido = jsonDecode(guardado)['uri'];
      }
      String? guardadoUsername = preferences.getString('username');
      String? guardadoPassword = preferences.getString('password');
      String? guardadoCustomUri = preferences.getString('customUri');
      print('*******guardadoUsername $guardadoUsername');
      usenameController.text = guardadoUsername == null ? '' : guardadoUsername;
      passwordController.text =
          guardadoPassword == null ? '' : guardadoPassword;
      textoUri = guardadoCustomUri == null ? '' : guardadoCustomUri;
      // if(guardadoUsername != null && guardadoPassword != null) {
      //   _onSubmit();
      // }
    });
  }

  @override
  void dispose() {
    if (animationController != null) animationController!.dispose();
    super.dispose();
  }

  Future<void> _onSubmitFuture() async {
    print('_onSubmit');
    // if (!_formKey.currentState!.validate()) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Escriba correctamente.')));
    // } else {
    String username = usenameController.text;
    String password = passwordController.text;
    print('Suerte: $username $password');

    bool isLocal = textoUri.contains('192');
    if (isLocal) {
      bool hasHttp = textoUri.contains('http');
      textoUri = hasHttp ? textoUri : 'http://' + textoUri;
    }

    var server = Server();
    var response;
    String servidorUri = isLocal ? textoUri : servidorElegido;

    isLoading = true;
    try {
      response = await server.credentials(
        username,
        password,
        servidorUri,
        otro: isLocal,
      );

      Map<String, dynamic> parsed = jsonDecode(response.body);

      if (response.statusCode == 200) {
        AuthService.setToken(parsed['el_token']);
        var res = await server.login();
        print('res login $res');

        SharedPreferences.getInstance().then((SharedPreferences preferences) {
          preferences.setString('username', username);
          preferences.setString('password', password);
          preferences.setString('customUri', servidorUri);
        });

        Navigator.pushNamed(context, '/panel');
      } else {
        _snackDatosInvalidos();
      }
    } on Exception {
      print('***** Error: ${Server.urlApi}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error ${Server.urlApi}'),
      ));
    } finally {
      isLoading = false;
    }
    // } // Cierra condicional validator
  }

  void _onSubmit() {
    _onSubmitFuture();
  }

  void _snackDatosInvalidos() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Datos inválidos.'),
        action: SnackBarAction(
          label: 'Limpiar',
          onPressed: () {
            passwordController.text = '';
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    double viewInset = MediaQuery.of(context).viewInsets.bottom;
    double defaultLoginSize = size.height - (size.height * 0.2);
    double defaultRegisterSize = size.height - (size.height * 0.1);

    containerSize =
        Tween<double>(begin: size.height * 0.1, end: defaultRegisterSize)
            .animate(CurvedAnimation(
                parent: animationController!, curve: Curves.linear));

    return Scaffold(
      body: Stack(
        children: [
          // Circulo decoración derecho
          Positioned(
            top: 100,
            right: -50,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: kPrimaryColor),
            ),
          ),

          // Circulo decoración derecho
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: kPrimaryColor),
            ),
          ),

          // Cancel button
          CloseServidoresButton(
              isLogin: isLogin,
              animationDuration: animationDuration,
              size: size,
              animationController: animationController!,
              gestureTapCallback: isLogin ? null : _setIsLoginToTrue),

          // FORM Login
          AnimatedOpacity(
            opacity: isLogin ? 1.0 : 0.0,
            duration: animationDuration * 4,
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Container(
                  width: size.width,
                  height: defaultLoginSize,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bienvenido.',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Image(
                        image: AssetImage('assets/images/atComputer.png'),
                        height: 200,
                      ),
                      SizedBox(
                        height: 40,
                      ),
                      RoundedInput(
                        controller: usenameController,
                        icon: Icons.mail,
                        hint: 'Usuario',
                      ),
                      RoundedPasswordInput(
                        controller: passwordController,
                        hint: 'Contraseña',
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      RoundedButton(
                        title: 'Entrar',
                        onTap: _onSubmit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BOTÓN PARA MOSTRAR SERVIDORES
          AnimatedBuilder(
            animation: animationController!,
            builder: (context, child) {
              if (viewInset == 0 && isLogin) {
                return buildSelectServidoresContainer();
              } else if (!isLogin) {
                return buildSelectServidoresContainer();
              }
              return Container();
            },
          ),

          // FORM Seleccionar servidor
          FormSelectServidor(
            isLogin: isLogin,
            animationDuration: animationDuration,
            size: size,
            defaultLoginSize: defaultLoginSize,
            setIsLogin: _setIsLoginToTrue,
          ),
        ],
      ),
    );
  }

  Widget buildSelectServidoresContainer() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: !isLogin
            ? null
            : () {
                animationController?.forward();
                print('isLogin $isLogin');
                setState(() {
                  isLogin = !isLogin;
                });
              },
        child: Container(
          width: double.infinity,
          height: containerSize?.value,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(100),
              topRight: Radius.circular(100),
            ),
            color: KBackgroundColor,
          ),
          alignment: Alignment.center,
          child: isLogin
              ? Text(
                  servidorElegido != ''
                      ? servidorElegido
                      : 'Selecciona tu colegio',
                  style: TextStyle(
                    fontSize: 18,
                    color: kPrimaryColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _setIsLoginToTrue() {
    print('Setting login in true');
    animationController?.reverse();
    setState(() {
      isLogin = true;
      SharedPreferences.getInstance().then((SharedPreferences preferences) {
        String? guardado = preferences.getString('uriColegio');

        if (guardado != null) {
          servidorElegido = jsonDecode(guardado)['uri'];
        }

        print(' *******  servidorElegido $servidorElegido');
      });
    });
  }
}

class CloseServidoresButton extends StatelessWidget {
  final bool isLogin;
  final Duration animationDuration;
  final Size size;
  final AnimationController animationController;
  final GestureTapCallback? gestureTapCallback;

  const CloseServidoresButton(
      {Key? key,
      required this.isLogin,
      required this.animationDuration,
      required this.size,
      required this.animationController,
      required this.gestureTapCallback})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLogin ? 0.0 : 1.0,
      duration: animationDuration,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: size.width,
          height: size.height * 0.1,
          alignment: Alignment.bottomCenter,
          child: IconButton(
            icon: Icon(Icons.close),
            onPressed: gestureTapCallback,
            color: kPrimaryColor,
          ),
        ),
      ),
    );
  }
}
