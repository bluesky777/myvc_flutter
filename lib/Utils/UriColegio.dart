import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class UriColegio {
  String nombre;
  String uri;

  UriColegio({this.nombre='', this.uri=''});

  Future<http.Response> fetchLista () {
    Uri direccion = Uri.parse('https://micolevirtual.com/app/listado_colegios.php');
    var response = http.post(direccion);
    return response;
  }

  factory UriColegio.fromJson(Map<String, dynamic> parsedJson) {
    return UriColegio(
      nombre: parsedJson['nombre_colegio'].toString(),
      uri: parsedJson['url_colegio'].toString(),
    );
  }

  @override
  String toString() {
    return "{nombre: $nombre, uri: $uri}";
  }

  Map<String, dynamic> toJson() => {
    "uri": uri,
    "nombre": nombre,
  };

}


List<DropdownMenuItem> getItemsUriColegios () {
  List<UriColegio> listaUriColegios = [
    UriColegio(nombre: 'Localhost', uri: 'http://localhost'),
    UriColegio(nombre: 'LICADLI Tame', uri: 'https://lalvirtual.edu.co'),
    UriColegio(nombre: 'COAB Saravena', uri: 'https://coab.micolevirtual.com'),
  ];

  List<DropdownMenuItem> itemsUriColegios = listaUriColegios.map((item) {
    return DropdownMenuItem<UriColegio>(
      child: Text(item.nombre),
      value: item,
    );
  }).toList();

  return itemsUriColegios;
}
