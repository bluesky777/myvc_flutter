import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';

import '../../constantes.dart';

class ButtonSelectServidores extends StatefulWidget {
  final AnimationController? animationController;
  final Animation<double>? containerSize;
  final String servidorElegido;

  const ButtonSelectServidores({
    required this.animationController,
    required this.containerSize,
    required this.servidorElegido,
  }) : super();

  @override
  _ButtonSelectServidoresState createState() => _ButtonSelectServidoresState();
}

class _ButtonSelectServidoresState extends State<ButtonSelectServidores> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectServerCubit, SelectServerState>(
      builder: (context, state) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: !state.mostrando
                ? null
                : () {
                    widget.animationController?.forward();
                    BlocProvider.of<SelectServerCubit>(context).toggleMostrar();
                  },
            child: Container(
              width: double.infinity,
              height: widget.containerSize?.value,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(100),
                  topRight: Radius.circular(100),
                ),
                color: KBackgroundColor,
              ),
              alignment: Alignment.center,
              child: state.mostrando
                  ? Text(
                      widget.servidorElegido != ''
                          ? widget.servidorElegido
                          : 'Selecciona tu colegio',
                      style: TextStyle(
                        fontSize: 18,
                        color: kPrimaryColor,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
