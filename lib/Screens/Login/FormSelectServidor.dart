import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'RoundedButton.dart';
import 'RoundedInput.dart';

class FormSelectServidor extends StatefulWidget {
  const FormSelectServidor({
    Key? key,
    required this.isLogin,
    required this.animationDuration,
    required this.size,
    required this.defaultLoginSize,
    required this.animationController,
  }) : super(key: key);

  final bool isLogin;
  final Duration animationDuration;
  final Size size;
  final double defaultLoginSize;
  final AnimationController? animationController;

  @override
  _FormSelectServidorState createState() => _FormSelectServidorState();
}

class _FormSelectServidorState extends State<FormSelectServidor> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectServerCubit, SelectServerState>(
      builder: (context, state) {
        return AnimatedOpacity(
          opacity: state.mostrando ? 0.0 : 1.0,
          duration: widget.animationDuration * 5,
          child: Visibility(
            visible: !state.mostrando,
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
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Container(
                        height: widget.size.height * 0.5,
                        child: SingleChildScrollView(
                          physics: ScrollPhysics(),
                          child: ListViewServidores(
                              animationController: widget.animationController),
                        ),
                      ),
                      RoundedInput(
                        icon: Icons.add_link,
                        hint: 'Dirección personalizada',
                      ),
                      RoundedButton(
                        title: 'Aceptar',
                        onTap: () {
                          print('Aceptando...');
                          widget.animationController?.reverse();
                          context.read<SelectServerCubit>().toggleMostrar();
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ListViewServidores extends StatefulWidget {
  const ListViewServidores({Key? key, required this.animationController})
      : super(key: key);

  final AnimationController? animationController;

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
        return UriColegio.fromJson(dato);
      }).toList();

      listaUrisColes.add(UriColegio(uri: 'otro', nombre: 'Otro'));
      setState(() {
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
          leading: uriColegio.nombre == 'Otro'
              ? CircleAvatar(
                  child: Text('NA'),
                )
              : CircleAvatar(
                  backgroundImage: NetworkImage(uriColegio.logo),
                ),
          onTap: () {
            print('Cambiada uri... ${uriColegio.uri}');
            uriController.text = '';
            SharedPreferences.getInstance()
                .then((SharedPreferences preferences) {
              preferences.setString(
                'uriColegio',
                json.encode(uriColegio.toJson()),
              );
              setState(() {
                servidorElegido = uriColegio.uri;
              });
              widget.animationController?.reverse();
              context.read<SelectServerCubit>().toggleMostrar();
            });
          },
          trailing: Icon(Icons.arrow_right),
        );
      },
    );
  }
}
