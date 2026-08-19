import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';

part 'select_server_state.dart';

class SelectServerCubit extends Cubit<SelectServerState> with HydratedMixin {
  final UriColegio uriColegio;

  SelectServerCubit(this.uriColegio)
      : super(SelectServerState(uriColegioSelected: UriColegio())) {
    // Obligatorio al usar HydratedMixin directamente: es hydrate() quien lee el
    // estado guardado y, de paso, quien inicializa el almacén interno. Sin esta
    // llamada el colegio elegido no se recuperaba al arrancar y, peor, el
    // primer emit reventaba con LateInitializationError.
    //
    // Hasta hydrated_bloc 7 el getter de state leía del almacén por su cuenta y
    // esto no hacía falta; en la 11 ya no.
    hydrate();
  }

  void toggleMostrar() {
    emit(
      SelectServerState(
        mostrandoButtonSelectedUri: !state.mostrandoButtonSelectedUri,
        uriColegioSelected: state.uriColegioSelected,
      ),
    );
  }

  void selectUriColegio(UriColegio uriColegioSelected) {
    emit(SelectServerState(
      mostrandoButtonSelectedUri: state.mostrandoButtonSelectedUri,
      uriColegioSelected: uriColegioSelected,
    ));
  }

  void setOtroUriColegio(String direccion) async {
    final UriColegio uriOtro = UriColegio(
      nombre: 'Otro',
      uri: direccion,
    );

    await Future<void>.delayed(Duration(milliseconds: 50));
    emit(SelectServerState(
      mostrandoButtonSelectedUri: true,
      uriColegioSelected: uriOtro,
    ));
  }

  @override
  SelectServerState? fromJson(Map<String, dynamic> json) {
    return SelectServerState.fromMap(json);
  }

  @override
  Map<String, dynamic>? toJson(SelectServerState state) {
    return state.toMap();
  }
}
