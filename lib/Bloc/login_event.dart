part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();
}

class DoLoginEvent extends LoginEvent {
  final String username;
  final String password;

  // El servidor no viaja en el evento: LoginBloc lo toma de SelectServerCubit,
  // que es el único sitio donde la elección de colegio está viva.
  DoLoginEvent(this.username, this.password);

  @override
  List<Object?> get props => [username, password];
}
