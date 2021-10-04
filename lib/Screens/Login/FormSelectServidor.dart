import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';

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
  TextEditingController uriTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectServerCubit, SelectServerState>(
      builder: (context, state) {
        uriTextController.text = state.uriColegioSelected.uri;

        return AnimatedOpacity(
          opacity: state.mostrandoButtonSelectedUri ? 0.0 : 1.0,
          duration: widget.animationDuration * 5,
          child: Visibility(
            visible: !state.mostrandoButtonSelectedUri,
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
                        controller: uriTextController,
                      ),
                      RoundedButton(
                        title: 'Aceptar',
                        onTap: () {
                          print('Aceptando... ${uriTextController.text}');
                          context
                              .read<SelectServerCubit>()
                              .setOtroUriColegio(uriTextController.text);
                          widget.animationController?.reverse();
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
  List<UriColegio> listaUrisColes = [];
  UriColegio uriColegioSeleccionada = UriColegio();

  @override
  void initState() {
    super.initState();

    UriColegio().fetchLista().then((value) {
      listaUrisColes = value;

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
            BlocProvider.of<SelectServerCubit>(context)
                .selectUriColegio(uriColegio);

            if (uriColegio.nombre != 'Otro') {
              widget.animationController?.reverse();
              context.read<SelectServerCubit>().toggleMostrar();
            }
          },
          trailing: Icon(Icons.arrow_right),
        );
      },
    );
  }
}
