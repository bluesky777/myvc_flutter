import 'dart:async';

import 'package:bloc/bloc.dart';
import "package:equatable/equatable.dart";

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

      // hacer el login
      await Future.delayed(Duration(seconds: 3));

      yield LoginErrorState('No se pudo loguear');
    }
  }
}
