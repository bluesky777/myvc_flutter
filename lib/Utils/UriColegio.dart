import 'dart:convert';

import 'package:http/http.dart' as http;

class UriColegio {
  String nombre;
  String uri;
  String logo;

  List<UriColegio> listaUrisColes = [];

  UriColegio({this.nombre = '', this.uri = '', this.logo = ''});

  Future<List<UriColegio>> fetchLista() async {
    final path = 'https://micolevirtual.com/app/listado_colegios.php';
    Uri direccion = Uri.parse(path);

    return http.post(direccion).then((value) {
      final List listaResponse = jsonDecode(value.body);
      this.listaUrisColes = listaResponse.map((dato) {
        return UriColegio.fromJson(dato);
      }).toList();

      this.listaUrisColes.add(UriColegio(uri: 'otro', nombre: 'Otro'));
      return this.listaUrisColes;
    });
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
