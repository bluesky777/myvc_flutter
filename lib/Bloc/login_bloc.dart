import 'dart:async';

import 'package:bloc/bloc.dart';
import "package:equatable/equatable.dart";
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final SelectServerCubit selectServerCubit;

  LoginBloc({required this.selectServerCubit}) : super(LoginInitialState());

  @override
  Stream<LoginState> mapEventToState(
    LoginEvent event,
  ) async* {
    if (event is DoLoginEvent) {
      yield LoggingInState();

      final servidorElegido =
          this.selectServerCubit.state.uriColegioSelected.uri;
      final isLocal =
          this.selectServerCubit.state.uriColegioSelected.nombre == 'Otro'
              ? true
              : false;

      print('+++ servidorElegido $servidorElegido - ${event.textoUri}');

      LoginController loginController = LoginController();
      try {
        var token = await loginController.login(
          event.username,
          event.password,
          isLocal,
          servidorElegido,
        );

        yield LoggedState(token);
      } on LoginException {
        yield LoginErrorState('No se pudo loguear');
      }
    }
  }
}
