import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Un ordinal del manual de convivencia: el artículo que tipifica una
/// situación.
///
/// El catálogo es del año y viene entero en `grupos/con-disciplina`. Aquí solo
/// se leen: crearlos y editarlos es otra pantalla de la web, y a propósito no
/// se trae a la app.
///
/// `tipo` y `ordinal` son texto libre, no números: cada colegio numera su
/// manual como quiere —«Tipo I» y «3», o «Capítulo 2» y «b»— y la base los
/// guarda como varchar. Ordenarlos como números los desordenaría.
class OrdinalModel {
  final int id;
  final int yearId;
  final String tipo;
  final String ordinal;
  final String descripcion;

  /// En qué página del manual está. El colegio la usa para citarlo.
  final String? pagina;

  OrdinalModel({
    required this.id,
    this.yearId = 0,
    this.tipo = '',
    this.ordinal = '',
    this.descripcion = '',
    this.pagina,
  });

  factory OrdinalModel.fromJson(Map<String, dynamic> json) {
    return OrdinalModel(
      id: enteroO(json['id']),
      yearId: enteroO(json['year_id']),
      tipo: '${json['tipo'] ?? ''}'.trim(),
      ordinal: '${json['ordinal'] ?? ''}'.trim(),
      descripcion: '${json['descripcion'] ?? ''}'.trim(),
      pagina: texto(json['pagina']),
    );
  }

  /// El número, como se cita: «Tipo I - 3».
  ///
  /// Sin el guion cuando falta una de las dos mitades, que las hay: el
  /// catálogo del colegio tiene ordinales sin tipo y tipos sin ordinal, y
  /// «Tipo I - » con el guion colgando se lee como un error.
  String get numero {
    if (tipo.isEmpty) return ordinal;
    if (ordinal.isEmpty) return tipo;
    return '$tipo - $ordinal';
  }

  /// Cómo se lee entero en la lista: «Tipo I - 3. No portar el uniforme».
  String get rotulo {
    if (numero.isEmpty) return descripcion;
    if (descripcion.isEmpty) return numero;
    return '$numero. $descripcion';
  }

  /// Si este ordinal responde a lo que se está escribiendo en el buscador.
  ///
  /// Busca en el número y en la descripción a la vez, sin acentos ni
  /// mayúsculas: el docente tanto escribe «uniforme» como «tipo I», y no tiene
  /// por qué saber cuál de los dos campos es.
  bool coincideCon(String busqueda) {
    final aguja = _plano(busqueda);
    if (aguja.isEmpty) return true;

    return _plano(rotulo).contains(aguja);
  }

  /// El texto sin acentos, en minúsculas y con los espacios apretados.
  ///
  /// Sin quitar acentos, buscar «situacion» no encontraría «Situación», que es
  /// justo como está escrito el manual.
  static String _plano(String texto) {
    var plano = texto.toLowerCase().trim();

    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    acentos.forEach((con, sin) => plano = plano.replaceAll(con, sin));

    return plano.replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  String toString() => '(OrdinalModel) $rotulo';
}
