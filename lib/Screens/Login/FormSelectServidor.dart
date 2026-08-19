import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';

import 'RoundedButton.dart';
import 'RoundedInput.dart';

class FormSelectServidor extends StatefulWidget {
  const FormSelectServidor({
    super.key,
    required this.isLogin,
    required this.animationDuration,
    required this.size,
    required this.defaultLoginSize,
    required this.animationController,
  });

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
                child: SizedBox(
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
                      SizedBox(
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
  const ListViewServidores({super.key, required this.animationController});

  final AnimationController? animationController;

  @override
  _ListViewServidoresState createState() => _ListViewServidoresState();
}

class _ListViewServidoresState extends State<ListViewServidores> {
  List<UriColegio> listaUrisColes = [];
  String? errorLista;

  @override
  void initState() {
    super.initState();

    UriColegio().fetchLista().then((value) {
      if (!mounted) return;
      setState(() {
        listaUrisColes = value;
        errorLista = null;
      });
    }).catchError((err) {
      if (!mounted) return;

      // Sin este catchError el fallo moría en un Future que nadie esperaba: la
      // lista se quedaba vacía, sin "Otro" y sin decir por qué. Se deja "Otro"
      // para que aun sin lista se pueda escribir una dirección a mano.
      setState(() {
        listaUrisColes = [UriColegio(uri: 'otro', nombre: 'Otro')];
        errorLista = 'No se pudo cargar la lista de colegios.\n'
            'Escribe la dirección a mano en "Otro".';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errorLista != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              errorLista!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        _buildLista(),
      ],
    );
  }

  Widget _buildLista() {
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
