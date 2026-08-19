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
  OverlayEntry? _avisoEntry;

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
    _ocultarAviso();
    if (animationController != null) animationController!.dispose();
    super.dispose();
  }

  /// Aviso de error arriba, y descartable arrastrándolo hacia arriba.
  ///
  /// Va en el Overlay y no en un SnackBar ni en un MaterialBanner. El SnackBar
  /// sale abajo, encima del botón del colegio, que es el dato que más falta
  /// hace cuando el login falla. El MaterialBanner sí sale arriba, pero no
  /// tiene gesto de descarte. Así se quedan las tres cosas: arriba, se arrastra
  /// para quitarlo, y se va solo si nadie lo toca.
  void _mostrarAviso(String mensaje) {
    _ocultarAviso();

    final entrada = OverlayEntry(
      builder: (_) => _AvisoSuperior(mensaje: mensaje, onCerrar: _ocultarAviso),
    );

    _avisoEntry = entrada;
    Overlay.of(context).insert(entrada);

    _temporizadorAviso = Timer(Duration(seconds: 12), _ocultarAviso);
  }

  void _ocultarAviso() {
    _temporizadorAviso?.cancel();
    _temporizadorAviso = null;

    // A null antes de nada: remove() solo admite una llamada, y aquí se entra
    // por tres sitios —el botón, el arrastre y el temporizador—.
    final entrada = _avisoEntry;
    _avisoEntry = null;
    entrada?.remove();
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

/// La barra roja de error. Se arrastra hacia arriba para quitarla, que es lo
/// que uno intenta por instinto con un aviso que estorba.
class _AvisoSuperior extends StatelessWidget {
  final String mensaje;
  final VoidCallback onCerrar;

  const _AvisoSuperior({required this.mensaje, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Dismissible(
        key: const ValueKey('aviso-login'),
        direction: DismissDirection.up,
        // Sin esto, al soltarlo intenta animar el hueco que deja, y aquí no hay
        // hueco: el aviso flota sobre la pantalla.
        resizeDuration: null,
        onDismissed: (_) => onCerrar(),
        child: Material(
          color: Colors.red.shade700,
          elevation: 6,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: onCerrar,
                    child: Text(
                      'Cerrar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
