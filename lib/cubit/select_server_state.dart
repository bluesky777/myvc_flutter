part of 'select_server_cubit.dart';

class SelectServerState extends Equatable {
  bool mostrando;

  SelectServerState({this.mostrando = true});

  @override
  List<Object> get props => [mostrando];
}
