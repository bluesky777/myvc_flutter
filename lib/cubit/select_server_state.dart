part of 'select_server_cubit.dart';

class SelectServerState extends Equatable {
  final bool mostrandoButtonSelectedUri;
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

  /// Tolerante con lo que dejó guardado una versión anterior.
  ///
  /// Esto lee del almacén de hydrated_bloc, que sobrevive a las
  /// actualizaciones de la app. Si falta una clave —'mostrando' no existía
  /// siempre— lo que antes ocurría era una excepción al arrancar, y con ella
  /// se perdía el colegio elegido.
  factory SelectServerState.fromMap(Map<String, dynamic> map) {
    final colegio = map['uriColegioSelected'];

    return SelectServerState(
        mostrandoButtonSelectedUri: map['mostrando'] as bool? ?? true,
        uriColegioSelected: colegio is Map
            ? UriColegio(
                nombre: '${colegio['nombre'] ?? ''}',
                uri: '${colegio['uri'] ?? ''}',
                logo: '${colegio['logo'] ?? ''}',
              )
            : UriColegio());
  }

  String toJson() => json.encode(toMap());

  factory SelectServerState.fromJson(String source) {
    return SelectServerState.fromMap(
      json.decode(source),
    );
  }
}
