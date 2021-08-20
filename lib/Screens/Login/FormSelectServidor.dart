import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'RoundedButton.dart';
import 'RoundedInput.dart';

class FormSelectServidor extends StatefulWidget {
  const FormSelectServidor(
      {Key? key,
      required this.isLogin,
      required this.animationDuration,
      required this.size,
      required this.defaultLoginSize,
      required this.setIsLogin})
      : super(key: key);

  final bool isLogin;
  final Duration animationDuration;
  final Size size;
  final double defaultLoginSize;
  final void Function() setIsLogin;

  @override
  _FormSelectServidorState createState() => _FormSelectServidorState();
}

class _FormSelectServidorState extends State<FormSelectServidor> {
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.isLogin ? 0.0 : 1.0,
      duration: widget.animationDuration * 5,
      child: Visibility(
        visible: !widget.isLogin,
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
                    'Seleccione su colegio',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    height: widget.size.height * 0.5,
                    child: SingleChildScrollView(
                      physics: ScrollPhysics(),
                      child: ListViewServidores(),
                    ),
                  ),
                  RoundedInput(
                    icon: Icons.add_link,
                    hint: 'Dirección personalizada',
                  ),
                  RoundedButton(title: 'Aceptar', onTap: widget.setIsLogin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ListViewServidores extends StatefulWidget {
  const ListViewServidores({Key? key}) : super(key: key);

  @override
  _ListViewServidoresState createState() => _ListViewServidoresState();
}

class _ListViewServidoresState extends State<ListViewServidores> {
  TextEditingController uriController = TextEditingController();
  String servidorElegido = '';
  List<UriColegio> listaUrisColes = [];
  UriColegio uriColegioSeleccionada = UriColegio();

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
      String? guardadoCustomUri = preferences.getString('customUri');
      print('*******guardadoUsername $guardadoCustomUri');
      uriController.text = guardadoCustomUri == null ? '' : guardadoCustomUri;
    });

    UriColegio().fetchLista().then((value) {
      final List listaResponse = jsonDecode(value.body);
      listaUrisColes = listaResponse.map((dato) {
        print('${dato['nombre_colegio']} ${dato['logo']}');
        return UriColegio.fromJson(dato);
      }).toList();

      listaUrisColes.add(UriColegio(uri: 'otro', nombre: 'Otro'));
      setState(() {
        print('listaUrisColes.length: ${listaUrisColes.length}');
        uriColegioSeleccionada = listaUrisColes[0];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: listaUrisColes.length,
      itemBuilder: (context, index) {
        UriColegio uriColegio = listaUrisColes[index];
        return ListTile(
          dense: false,
          title: Text(uriColegio.nombre),
          leading: CircleAvatar(
            backgroundImage: NetworkImage(uriColegio.logo),
          ),
          onTap: () {
            print('Cambiada uri... ${uriColegio.uri}');
            uriController.text = '';
            SharedPreferences.getInstance()
                .then((SharedPreferences preferences) {
              preferences.setString(
                  'uriColegio', json.encode(uriColegio.toJson()));
              setState(() {
                servidorElegido = uriColegio.uri;
              });
            });
          },
          trailing: Icon(Icons.arrow_right),
        );
      },
    );
  }
}
