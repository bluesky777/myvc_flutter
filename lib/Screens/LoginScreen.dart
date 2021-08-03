import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';

import 'txtFormField.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  void _onSubmit() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => PanelScreen()));

    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enviando...')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          txtFormField(
            hint: 'Usuario usado en la página',
            label: 'Usuario',
          ),
          txtFormField(
            hint: 'Escriba contraseña',
            label: 'Contraseña',
          ),
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
