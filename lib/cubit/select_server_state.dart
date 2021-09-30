part of 'select_server_cubit.dart';

class SelectServerState extends Equatable {
  bool mostrando;
  String servidorElegidoString;

  SelectServerState({this.mostrando = true, this.servidorElegidoString = ''});

  @override
  List<Object> get props => [mostrando];

  Map<String, dynamic> toMap() {
    return {
      'mostrando': mostrando,
      'servidorElegidoString': servidorElegidoString
    };
  }

  factory SelectServerState.fromMap(Map<String, dynamic> map) {
    return SelectServerState(
        mostrando: map['mostrando'],
        servidorElegidoString: map['servidorElegidoString']);
  }

  String toJson() => json.encode(toMap());

  factory SelectServerState.fromJson(String source) =>
      SelectServerState.fromMap(
        json.decode(source),
      );
}
