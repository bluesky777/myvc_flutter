import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Bloc/login_bloc.dart';

import 'RoundedButton.dart';
import 'RoundedInput.dart';
import 'RoundedPasswordInput.dart';

class FormLoginContainer extends StatefulWidget {
  final bool isLogin;
  final Duration animationDuration;
  final Size size;
  final double defaultLoginSize;
  final TextEditingController usenameController;
  final TextEditingController passwordController;
  final void Function() onSubmit;

  const FormLoginContainer({
    required this.isLogin,
    required this.animationDuration,
    required this.size,
    required this.defaultLoginSize,
    required this.usenameController,
    required this.passwordController,
    required this.onSubmit,
  });

  @override
  FormLoginContainerState createState() => FormLoginContainerState();
}

class FormLoginContainerState extends State<FormLoginContainer> {
  void _snackDatosInvalidos() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Datos inválidos.'),
        action: SnackBarAction(
          label: 'Limpiar',
          onPressed: () {
            widget.passwordController.text = '';
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        return AnimatedOpacity(
          opacity: widget.isLogin ? 1.0 : 0.0,
          duration: widget.animationDuration * 4,
          child: Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: Container(
                width: widget.size.width,
                height: widget.defaultLoginSize,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bienvenido',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Image(
                      image: AssetImage('assets/images/at_computer.png'),
                      height: 200,
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    RoundedInput(
                      controller: widget.usenameController,
                      icon: Icons.mail,
                      hint: 'Usuario',
                    ),
                    RoundedPasswordInput(
                      controller: widget.passwordController,
                      hint: 'Contraseña',
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    if (state is LoggingInState)
                      CircularProgressIndicator()
                    else
                      RoundedButton(
                        title: 'Entrar',
                        onTap: widget.onSubmit,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
