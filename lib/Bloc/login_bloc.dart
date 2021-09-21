import 'dart:async';

import 'package:bloc/bloc.dart';
import "package:equatable/equatable.dart";
import 'package:myvc_flutter/Controllers/LoginController.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginInitialState());

  @override
  Stream<LoginState> mapEventToState(
    LoginEvent event,
  ) async* {
    if (event is DoLoginEvent) {
      yield LoggingInState();

      LoginController loginController = LoginController();
      try {
        print('iniii');
        var token = await loginController.login(
          event.username,
          event.password,
          event.isLocal,
          event.textoUri,
          event.servidorElegido,
        );
        print('asdf $token');
        yield LoggedState(token);
      } on LoginException {
        yield LoginErrorState('No se pudo loguear');
      }
    }
  }
}
