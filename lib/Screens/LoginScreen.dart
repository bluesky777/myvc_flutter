import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';

import 'txtFormField.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escriba correctamente.')));
    } else {
      String username = usenameController.text;
      String password = passwordController.text;
      print('Suerte: $username $password');

      var server = Server();
      var response = await server.credentials(username, password);

      Map<String, dynamic> parsed = jsonDecode(response.body);

      if (response.statusCode == 200) {
        AuthService.setToken(parsed['el_token']);
        var res = await server.login();
        print(res.body);
        Navigator.pushNamed(context, '/panel');
      } else {
        _snackDatosInvalidos();
      }
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
            //formPassword?.focalizar();
          },
        ),
      ),
    );
  }

  TextEditingController usenameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  txtFormField _txtUsername() => txtFormField(
        hint: 'Usuario usado en la plataforma',
        label: 'Usuario',
        controller: usenameController,
      );
  txtFormField _txtPassword() => txtFormField(
        hint: 'Escriba contraseña',
        label: 'Contraseña',
        controller: passwordController,
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _txtUsername(),
          _txtPassword(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50)),
                onPressed: _onSubmit,
                child: Text('Entrar')),
          )
        ],
      ),
    );
  }
}
