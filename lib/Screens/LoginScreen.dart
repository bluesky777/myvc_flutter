import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Screens/ColegiosDropdownWidget.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'TxtFormField.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  List<DropdownMenuItem<UriColegio>> itemsUriColegios = [
    DropdownMenuItem(child: Text('Esperando...'))
  ];
  FocusNode focus = FocusNode();
  String servidorElegido = '';
  List<UriColegio> listaUrisColes = [];
  UriColegio uriColegioSeleccionada = UriColegio();
  bool isLoading = false;

  Future<void> _onSubmitFuture() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escriba correctamente.')));
    } else {
      String username = usenameController.text;
      String password = passwordController.text;
      print('Suerte: $username $password');

      bool isLocal = uriController.text.contains('192');
      if (isLocal) {
        bool hasHttp = uriController.text.contains('http');
        uriController.text =
            hasHttp ? uriController.text : 'http://' + uriController.text;
      }

      var server = Server();
      var response;
      String servidorUri = isLocal ? uriController.text : servidorElegido;

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
    }
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

    uriController.text = 'http://192.168.18.215';

    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? guardado = preferences.getString('uriColegio');
      print('guardado $guardado');
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
      uriController.text = guardadoCustomUri == null ? '' : guardadoCustomUri;
      // if(guardadoUsername != null && guardadoPassword != null) {
      //   _onSubmit();
      // }
    });
    uriController.text = 'http://192.168.18.215';

    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? guardado = preferences.getString('uriColegio');
      print('guardado $guardado');
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
      uriController.text = guardadoCustomUri == null ? '' : guardadoCustomUri;
      // if(guardadoUsername != null && guardadoPassword != null) {
      //   _onSubmit();
      // }
    });

    UriColegio().fetchLista().then((value) {
      final List listaResponse = jsonDecode(value.body);
      listaUrisColes = listaResponse.map((dato) {
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
        uriColegioSeleccionada = listaUrisColes[0];
      });
    });
  }

  _onSelectedColegio(dynamic value) {
    print('Cambiada uri... ${value.uri}');
    uriController.text = '';
    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      preferences.setString('uriColegio', json.encode(value.toJson()));
      setState(() {
        servidorElegido = value.uri;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ColegiosDropdownWidget(itemsUriColegios, _onSelectedColegio),
            _otroServidoTextField(),
            _txtUsername(),
            _txtPassword(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50)),
                  onPressed: _onSubmit,
                  child:
                      isLoading ? CircularProgressIndicator() : Text('Entrar')),
            )
          ],
        ),
      ),
    );
  }

  Widget _otroServidoTextField() {
    print('servidorElegido : en otroServido $servidorElegido');
    if (servidorElegido == 'otro') {
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
    } else {
      return Center(child: Text(servidorElegido));
    }
  }
}
