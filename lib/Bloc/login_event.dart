part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();
}

class DoLoginEvent extends LoginEvent {
  final String username;
  final String password;
  final bool isLocal;
  final String textoUri;
  final String servidorElegido;

  DoLoginEvent(
    this.username,
    this.password,
    this.isLocal,
    this.textoUri,
    this.servidorElegido,
  );

  @override
  List<Object?> get props => [username, password];
}
