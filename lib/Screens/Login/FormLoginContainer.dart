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
  final bool guardarDatos;
  final void Function(bool) onGuardarDatosChanged;

  const FormLoginContainer({
    required this.isLogin,
    required this.animationDuration,
    required this.size,
    required this.defaultLoginSize,
    required this.usenameController,
    required this.passwordController,
    required this.onSubmit,
    required this.guardarDatos,
    required this.onGuardarDatosChanged,
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
                // Altura mínima, no fija: así el Column sigue centrado cuando
                // sobra sitio, pero puede crecer y dejar que el
                // SingleChildScrollView lo desplace cuando no cabe. Con altura
                // fija, en pantallas cortas el formulario desbordaba y el botón
                // "Entrar" quedaba debajo de la barra del colegio, sin poder
                // pulsarse.
                constraints: BoxConstraints(minHeight: widget.defaultLoginSize),
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
                      // Se encoge donde no hay sitio: con 200 fijos, en una
                      // pantalla de 600px el botón "Entrar" terminaba debajo de
                      // la barra del colegio y no se podía pulsar.
                      height: (widget.size.height * 0.23).clamp(90.0, 200.0),
                    ),
                    SizedBox(
                      height: 20,
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
                    // Misma banda que InputContainer y RoundedButton: los dos
                    // usan size.width * 0.8 centrado.
                    SizedBox(
                      width: widget.size.width * 0.8,
                      child: CheckboxListTile(
                        value: widget.guardarDatos,
                        onChanged: (valor) =>
                            widget.onGuardarDatosChanged(valor ?? false),
                        title: Text('Recordar mis datos en este dispositivo'),
                        subtitle: Text(
                          'Desactívalo si el equipo es compartido',
                          style: TextStyle(fontSize: 12),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
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
