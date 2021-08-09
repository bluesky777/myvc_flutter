import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'TxtFormField.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  List<DropdownMenuItem> itemsUriColegios = [
    DropdownMenuItem(child: Text('Esperando...'))
  ];
  FocusNode focus = FocusNode();
  String servidorElegido = '';

  Future<void> _onSubmitFurture() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escriba correctamente.')));
    } else {
      String username = usenameController.text;
      String password = passwordController.text;
      print('Suerte: $username $password');

      var server = Server();
      var response;
      String servidorUri = servidorElegido == 'otro' ? uriController.text : servidorElegido;
      bool otro = servidorElegido == 'otro' ? true : false;
      print('servidorElegido $servidorUri --- otro $otro');
      try {
        response =
            await server.credentials(username, password, servidorUri, otro: otro);

        Map<String, dynamic> parsed = jsonDecode(response.body);

        if (response.statusCode == 200) {
          AuthService.setToken(parsed['el_token']);
          var res = await server.login();
          print(res.body);
          Navigator.pushNamed(context, '/panel');
        } else {
          _snackDatosInvalidos();
        }
      } on Exception {
        print('***** Error: ${Server.urlApi}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error ${Server.urlApi}'),
        ));
      }
    }
  }

  void _onSubmit() {
    _onSubmitFurture();
  }

  void _snackDatosInvalidos() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Datos inválidos.'),
        action: SnackBarAction(
          label: 'Limpiar',
          onPressed: () {
            passwordController.text = '';
            focus.requestFocus();
          },
        ),
      ),
    );
  }

  TextEditingController usenameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController uriController = TextEditingController();

  TxtFormField _txtUsername() => TxtFormField(
        hint: 'Usuario usado en la plataforma',
        label: 'Usuario',
        controller: usenameController,
        onSubmit: _onSubmit,
      );
  TxtFormField _txtPassword() => TxtFormField(
      hint: 'Escriba contraseña',
      label: 'Contraseña',
      controller: passwordController,
      onSubmit: _onSubmit,
      focus: focus);

  @override
  void initState() {
    super.initState();

    uriController.text = 'http://192.168.98.215';

    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? guardado = preferences.getString('uriColegio');
      print('guardado $guardado');
      if (guardado != null) {
        servidorElegido = jsonDecode(guardado)['uri'];
      }
      print('guardado $servidorElegido');
    });

    UriColegio().fetchLista().then((value) {
      final List listaResponse = jsonDecode(value.body);
      final List<UriColegio> listaUrisColes = listaResponse.map((dato) {
        print(dato['nombre_colegio']);
        return UriColegio.fromJson(dato);
      }).toList();

      listaUrisColes.add(UriColegio(uri: 'otro', nombre: 'Otro'));

      setState(() {
        itemsUriColegios = listaUrisColes.map((e) {
          return DropdownMenuItem(
            child: Text(e.nombre),
            value: e,
          );
        }).toList();
      });
    });
  }

  Padding _dropdownButton() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: Colors.grey),
            borderRadius: BorderRadius.circular(5),
          ),
          child: DropdownButtonFormField(
              decoration: InputDecoration(
                hintText: 'Este hint',
                labelText: 'Elija institución',
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)),
              ),
              onChanged: (dynamic value) {
                // ****** por qué no puedo ponerle UriColegio?? **********
                // Puedo poner en gradle.properties variables de entorno para distintos sistemas operativos?? org.gradle.java.home=C:\\Program Files\\Android\\Android Studio\\jre
                print('Cambiada uri... ${value.uri}');
                SharedPreferences.getInstance()
                    .then((SharedPreferences preferences) {
                  preferences.setString(
                      'uriColegio', json.encode(value.toJson()));
                  setState(() {
                    servidorElegido = value.uri;
                  });
                });
              },
              items: itemsUriColegios),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _dropdownButton(),
          _otroServido(),
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

  Widget _otroServido() {
    print('servidorElegido : en otroSercido $servidorElegido');
    if(servidorElegido == 'otro'){
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: TextFormField(
          controller: uriController,
          decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Servidor',
              labelText: 'Escriba página'),
        ),
      );
    }else {
      return Center(child: Text(servidorElegido));
    }
  }
}
