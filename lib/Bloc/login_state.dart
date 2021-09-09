part of 'login_bloc.dart';

abstract class LoginState extends Equatable {
  const LoginState();
}

class LoginInitialState extends LoginState {
  @override
  List<Object> get props => [];
}

class LoggingInState extends LoginState {
  @override
  List<Object?> get props => [];
}

class LoggedState extends LoginState {
  final String token;

  LoggedState(this.token);

  @override
  List<Object?> get props => [token];

}

class LoginErrorState extends LoginState {
  final String mensaje;

  LoginErrorState(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}