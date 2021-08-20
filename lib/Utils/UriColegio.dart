import 'dart:convert';

import 'package:http/http.dart' as http;

class UriColegio {
  String nombre;
  String uri;
  String logo;

  UriColegio({this.nombre = '', this.uri = '', this.logo = ''});

  Future<http.Response> fetchLista() {
    Uri direccion =
        Uri.parse('https://micolevirtual.com/app/listado_colegios.php');
    var response = http.post(direccion);
    return response;
  }

  @override
  bool operator ==(Object other) =>
      other is UriColegio && this.nombre == other.nombre;

  String toRawJson() => json.encode(toJson());

  @override
  int get hashCode => super.hashCode;

  factory UriColegio.fromJson(Map<String, dynamic> parsedJson) {
    return UriColegio(
      nombre: parsedJson['nombre_colegio'].toString(),
      uri: parsedJson['url_colegio'].toString(),
      logo: parsedJson['logo'].toString(),
    );
  }

  @override
  String toString() {
    return "{nombre: $nombre, uri: $uri}";
  }

  Map<String, dynamic> toJson() => {
        "uri": uri,
        "nombre": nombre,
        "logo": logo,
      };
}
