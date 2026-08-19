import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Bloc/login_bloc.dart';
import 'package:myvc_flutter/Screens/Login/FormSelectServidor.dart';
import 'package:myvc_flutter/Utils/PreferenciasSesion.dart';
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
  bool isLoading = false;
  bool guardarDatos = true;
  Timer? _temporizadorAviso;

  TextEditingController usenameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    animationController =
        AnimationController(vsync: this, duration: animationDuration);

    SharedPreferences.getInstance().then((SharedPreferences preferences) async {
      // Si el dispositivo no recuerda los datos, el formulario arranca vacío
      // aunque queden credenciales de una versión anterior.
      final recordar = await PreferenciasSesion.guardarDatos();
      String? guardadoUsername =
          preferences.getString(PreferenciasSesion.claveUsername);
      String? guardadoPassword =
          preferences.getString(PreferenciasSesion.clavePassword);

      setState(() {
        guardarDatos = recordar;
        usenameController.text =
            recordar && guardadoUsername != null ? guardadoUsername : '';
        passwordController.text =
            recordar && guardadoPassword != null ? guardadoPassword : '';
      });
    });
  }

  @override
  void dispose() {
    _temporizadorAviso?.cancel();
    if (animationController != null) animationController!.dispose();
    super.dispose();
  }

  /// Aviso de error arriba.
  ///
  /// Va en un MaterialBanner y no en un SnackBar porque el SnackBar sale abajo,
  /// justo encima del botón del colegio —el dato que más falta hace cuando algo
  /// falla—. El banner ocupa su sitio arriba y no tapa nada.
  void _mostrarAviso(String mensaje) {
    final mensajero = ScaffoldMessenger.of(context);

    _temporizadorAviso?.cancel();
    mensajero.hideCurrentMaterialBanner();

    mensajero.showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.red.shade700,
        leading: Icon(Icons.error_outline, color: Colors.white),
        content: Text(mensaje, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _ocultarAviso,
            child: Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // El banner no se va solo: si no lo cierran, se queda para siempre.
    _temporizadorAviso = Timer(Duration(seconds: 12), () {
      mensajero.hideCurrentMaterialBanner();
    });
  }

  void _ocultarAviso() {
    _temporizadorAviso?.cancel();
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
  }

  Future<void> _onSubmitFuture() async {
    String username = usenameController.text;
    String password = passwordController.text;

    // El servidor y si es local los resuelve LoginBloc desde SelectServerCubit,
    // que es donde vive la elección de colegio.
    BlocProvider.of<LoginBloc>(context).add(DoLoginEvent(username, password));

    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text('Error ${Server.urlApi}'),
    // ));
  }

  void _onSubmit() {
    _onSubmitFuture();
  }

  Future<void> _onGuardarDatosChanged(bool valor) async {
    setState(() {
      guardarDatos = valor;
    });

    await PreferenciasSesion.setGuardarDatos(valor);

    // Al desmarcar se limpia lo que ya estuviera puesto en pantalla.
    if (!valor && mounted) {
      setState(() {
        usenameController.text = '';
        passwordController.text = '';
      });
    }
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
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (BuildContext, login_state) {
          if (login_state is LoggedState) {
            // El banner es de la app, no de esta pantalla: sin esto viajaría
            // con el docente hasta el panel.
            _ocultarAviso();
            Navigator.pushNamed(context, '/panel');
          } else if (login_state is LoggingInState) {
            _ocultarAviso();
          } else if (login_state is LoginErrorState) {
            _mostrarAviso(login_state.mensaje);
          }
        },
        builder: (_, _login_state) {
          return BlocBuilder<SelectServerCubit, SelectServerState>(
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
                    isLogin: state.mostrandoButtonSelectedUri,
                    animationDuration: animationDuration,
                    size: size,
                    animationController: animationController!,
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
                    guardarDatos: guardarDatos,
                    onGuardarDatosChanged: _onGuardarDatosChanged,
                  ),

                  // BOTÓN PARA MOSTRAR SERVIDORES
                  AnimatedBuilder(
                    animation: animationController!,
                    builder: (context, child) {
                      bool isInLoginForm = state.mostrandoButtonSelectedUri;

                      if (viewInset == 0 && isInLoginForm) {
                        return ButtonSelectServidores(
                          animationController: animationController,
                          containerSize: containerSize,
                        );
                      } else if (!isInLoginForm) {
                        return ButtonSelectServidores(
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
          );
        },
      ),
    );
  }
}

class CloseServidoresButton extends StatelessWidget {
  final bool isLogin;
  final Duration animationDuration;
  final Size size;
  final AnimationController animationController;

  const CloseServidoresButton(
      {Key? key,
      required this.isLogin,
      required this.animationDuration,
      required this.size,
      required this.animationController})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: BlocProvider.of<SelectServerCubit>(context)
              .state
              .mostrandoButtonSelectedUri
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
    animationController.reverse();
    BlocProvider.of<SelectServerCubit>(context).toggleMostrar();
  }
}
