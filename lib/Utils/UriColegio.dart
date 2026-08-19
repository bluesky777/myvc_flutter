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

  /// Dos colegios son el mismo si se llaman igual.
  @override
  bool operator ==(Object other) =>
      other is UriColegio && this.nombre == other.nombre;

  /// El hash tiene que salir de lo mismo que compara ==.
  ///
  /// Devolvía `super.hashCode`, que es la identidad del objeto: dos colegios
  /// «iguales» daban hashes distintos, de modo que en un Set o como clave de
  /// un Map se colaban duplicados. SelectServerState hereda ese comparador a
  /// través de Equatable, así que el fallo llegaba hasta el estado guardado.
  @override
  int get hashCode => nombre.hashCode;

  String toRawJson() => json.encode(toJson());

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
