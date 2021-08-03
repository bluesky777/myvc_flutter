import 'package:flutter/material.dart';
import 'package:myvc_flutter/Screens/PanelScreen.dart';
import 'package:http/http.dart' as http;

import 'txtFormField.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _onSubmit() async {

    var url = Uri.parse('https://lalvirtual.edu.co/8myvc/public/api/publicaciones/ultimas');
    var response = await http.put(url);
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    //print(await http.read('https://example.com/foobar.txt'));


    // Navigator.pushNamed(
    //   context,
    //   '/panel',
    // );

    // if (_formKey.currentState!.validate()) {
    //   ScaffoldMessenger.of(context)
    //       .showSnackBar(const SnackBar(content: Text('Enviando...')));
    // }
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
