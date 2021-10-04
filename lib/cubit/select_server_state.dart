part of 'select_server_cubit.dart';

class SelectServerState extends Equatable {
  bool mostrandoButtonSelectedUri;
  final UriColegio uriColegioSelected;

  SelectServerState(
      {this.mostrandoButtonSelectedUri = true,
      required this.uriColegioSelected});

  @override
  List<Object> get props => [mostrandoButtonSelectedUri, uriColegioSelected];

  Map<String, dynamic> toMap() {
    return {
      'mostrando': mostrandoButtonSelectedUri,
      'uriColegioSelected': uriColegioSelected
    };
  }

  factory SelectServerState.fromMap(Map<String, dynamic> map) {
    return SelectServerState(
        mostrandoButtonSelectedUri: map['mostrando'],
        uriColegioSelected: UriColegio(
          nombre: map['uriColegioSelected']['nombre'],
          uri: map['uriColegioSelected']['uri'],
          logo: map['uriColegioSelected']['logo'],
        ));
  }

  String toJson() => json.encode(toMap());

  factory SelectServerState.fromJson(String source) {
    return SelectServerState.fromMap(
      json.decode(source),
    );
  }
}
