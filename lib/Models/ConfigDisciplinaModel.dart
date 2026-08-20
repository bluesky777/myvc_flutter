import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Cómo llama este colegio a las tres clases de situación, y cuántas hacen
/// falta para pasar de una a la siguiente.
///
/// Es la fila de `dis_configuraciones` del año. El backend la crea vacía la
/// primera vez que alguien abre la pantalla, así que siempre viene alguna.
/// Desde la app no se escribe: eso se configura en la web, junto a los
/// ordinales.
///
/// Los nombres importan más de lo que parece. Un colegio llama «Leve, Grave,
/// Gravísima» a lo que otro llama «Situación tipo I, II, III», y el manual de
/// convivencia de cada uno usa sus palabras. Escribir «Tipo 1» a pelo en la
/// pantalla es contradecir el documento que el colegio le entrega a las
/// familias, así que todo lo que se lee sale de aquí.
class ConfigDisciplinaModel {
  final int id;
  final int yearId;

  /// En singular, para el botón que elige el tipo al crear una situación.
  /// Tres posiciones, tipos 1, 2 y 3.
  final List<String> singular;

  /// En plural, para el título del bloque que las agrupa.
  final List<String> plural;

  /// Con cuántas tardanzas se llega a una situación de tipo 1.
  final int tardanzasParaTipo1;

  /// Con cuántas de tipo 1 se llega a una de tipo 2, y de tipo 2 a tipo 3.
  final int tipo1ParaTipo2;
  final int tipo2ParaTipo3;

  /// Si la cuenta vuelve a cero al empezar cada periodo.
  final bool reiniciaPorPeriodo;

  ConfigDisciplinaModel({
    this.id = 0,
    this.yearId = 0,
    List<String>? singular,
    List<String>? plural,
    this.tardanzasParaTipo1 = 5,
    this.tipo1ParaTipo2 = 3,
    this.tipo2ParaTipo3 = 3,
    this.reiniciaPorPeriodo = false,
  })  : singular = singular ?? _porDefecto('Situación tipo'),
        plural = plural ?? _porDefecto('Situaciones tipo');

  /// Los tres números de tipo que existen. En un solo sitio porque se recorren
  /// en media docena de sitios y son siempre estos.
  static const tipos = [1, 2, 3];

  static List<String> _porDefecto(String base) =>
      [for (final tipo in tipos) '$base $tipo'];

  factory ConfigDisciplinaModel.fromJson(Map<String, dynamic> json) {
    return ConfigDisciplinaModel(
      id: enteroO(json['id']),
      yearId: enteroO(json['year_id']),
      singular: _nombres(json, 'falta_tipo', 'Situación tipo'),
      plural: _nombres(json, 'faltas_tipo', 'Situaciones tipo'),
      tardanzasParaTipo1: entero(json['cant_tard_to_ft1']) ?? 5,
      tipo1ParaTipo2: entero(json['cant_ft1_to_ft2']) ?? 3,
      tipo2ParaTipo3: entero(json['cant_ft2_to_ft3']) ?? 3,
      reiniciaPorPeriodo: enteroO(json['reinicia_por_periodo']) == 1,
    );
  }

  /// Los tres nombres, con el de por defecto donde el colegio no puso ninguno.
  ///
  /// La columna tiene DEFAULT en la base, pero una fila creada a mano o una
  /// migración vieja puede traerla vacía, y un botón sin texto no se puede
  /// pulsar a ciegas.
  static List<String> _nombres(
    Map<String, dynamic> json,
    String prefijo,
    String base,
  ) {
    return [
      for (final tipo in tipos)
        (texto(json['$prefijo${tipo}_displayname'])?.trim().isNotEmpty ?? false)
            ? '${json['$prefijo${tipo}_displayname']}'.trim()
            : '$base $tipo'
    ];
  }

  /// Cómo se llama una situación de este tipo. «Una situación tipo 1.»
  String nombre(int tipo) => _de(singular, tipo);

  /// Cómo se llaman varias. «Las situaciones tipo 1.»
  String nombres(int tipo) => _de(plural, tipo);

  String _de(List<String> lista, int tipo) {
    final indice = tipo - 1;
    if (indice < 0 || indice >= lista.length) return 'Tipo $tipo';
    return lista[indice];
  }

  /// Un nombre corto para las fichas de la lista, donde no cabe «Situaciones
  /// tipo 1» tres veces seguidas.
  ///
  /// Se queda con la última palabra cuando el nombre es de la forma
  /// «Situación tipo 1» —«tipo 1» ya no distingue nada si va debajo de otras
  /// dos iguales— y con el nombre entero cuando el colegio le puso uno propio,
  /// que suele ser una sola palabra: «Leve», «Grave».
  String abreviado(int tipo) {
    final completo = nombres(tipo);
    final palabras = completo.split(RegExp(r'\s+'));

    if (palabras.length <= 2) return completo;
    return palabras.sublist(palabras.length - 2).join(' ');
  }
}
