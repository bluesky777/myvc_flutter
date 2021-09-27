import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Bloc/login_bloc.dart';
import 'package:myvc_flutter/Screens/Login/FormSelectServidor.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ButtonSelectServidores.dart';
import 'FormLoginContainer.dart';

class LoginAnimScreen extends StatefulWidget {
  const LoginAnimScreen({Key? key}) : super(key: key);

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
    String username = usenameController.text;
    String password = passwordController.text;
    bool isLocal = textoUri.contains('192');

    BlocProvider.of<LoginBloc>(context).add(DoLoginEvent(
      username,
      password,
      isLocal,
      textoUri,
      servidorElegido,
    ));

    Navigator.pushNamed(context, '/panel');
    //
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text('Error ${Server.urlApi}'),
    // ));
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
      body: BlocProvider<SelectServerCubit>(
        create: (context) => SelectServerCubit(),
        child: BlocBuilder<SelectServerCubit, SelectServerState>(
          builder: (context, state) {
            return Stack(
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
                  isLogin: state.mostrando,
                  animationDuration: animationDuration,
                  size: size,
                  animationController: animationController!,
                  gestureTapCallback:
                      state.mostrando ? null : _setIsLoginToTrue,
                ),

                // FORM Login
                FormLoginContainer(
                  isLogin: isLogin,
                  animationDuration: animationDuration,
                  size: size,
                  defaultLoginSize: defaultLoginSize,
                  usenameController: usenameController,
                  passwordController: passwordController,
                  onSubmit: _onSubmit,
                ),

                // BOTÓN PARA MOSTRAR SERVIDORES
                AnimatedBuilder(
                  animation: animationController!,
                  builder: (context, child) {
                    bool isInLoginForm = state.mostrando;

                    if (viewInset == 0 && isInLoginForm) {
                      return ButtonSelectServidores(
                        servidorElegido: servidorElegido,
                        animationController: animationController,
                        containerSize: containerSize,
                      );
                    } else if (!isInLoginForm) {
                      return ButtonSelectServidores(
                        servidorElegido: servidorElegido,
                        animationController: animationController,
                        containerSize: containerSize,
                      );
                    }
                    return Container();
                  },
                ),

                // FORM Seleccionar servidor
                FormSelectServidor(
                  isLogin: isLogin,
                  animationController: animationController,
                  animationDuration: animationDuration,
                  size: size,
                  defaultLoginSize: defaultLoginSize,
                ),
              ],
            );
          },
        ),
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
                BlocProvider.of<SelectServerCubit>(context).toggleMostrar();
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
    // print('Setting login in true');
    // animationController?.reverse();
    // setState(() {
    //   isLogin = true;
    //   SharedPreferences.getInstance().then((SharedPreferences preferences) {
    //     String? guardado = preferences.getString('uriColegio');
    //     print('guardado $guardado');
    //     if (guardado != null) {
    //       servidorElegido = jsonDecode(guardado)['uri'];
    //     }
    //
    //     print(' *******  servidorElegido $servidorElegido');
    //   });
    // });
    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? guardado = preferences.getString('uriColegio');
      if (guardado != null) {
        servidorElegido = jsonDecode(guardado)['uri'];
      }

      print(' *******  servidorElegido $servidorElegido');
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
      opacity: BlocProvider.of<SelectServerCubit>(context).state.mostrando
          ? 0.0
          : 1.0,
      duration: animationDuration,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: size.width,
          height: size.height * 0.1,
          alignment: Alignment.bottomCenter,
          child: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => _setIsLoginToTrue(context),
            // onPressed: gestureTapCallback,
            color: kPrimaryColor,
          ),
        ),
      ),
    );
  }

  void _setIsLoginToTrue(context) {
    print('Setting login in true');
    if (animationController != null) animationController.reverse();
    BlocProvider.of<SelectServerCubit>(context).toggleMostrar();
    this.gestureTapCallback!();
  }
}
