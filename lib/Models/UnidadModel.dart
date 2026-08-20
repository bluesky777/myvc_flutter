import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Una subunidad: la casilla en la que el docente pone una nota.
///
/// La nota de la unidad es la suma de sus subunidades ponderada por el
/// `porcentaje` de cada una, así que los porcentajes de las subunidades de una
/// unidad tienen que sumar 100. Es la regla que comprueba el backend y la que
/// se enseña aquí.
class SubunidadModel {
  final int id;
  final int unidadId;
  final String definicion;
  final double porcentaje;
  final int orden;

  /// Con qué nota arranca cada alumno en esta casilla.
  ///
  /// Importa que viaje de vuelta al guardar: `subunidades/update` la reescribe
  /// con lo que reciba y, si no recibe nada, la deja en 0. Editar la
  /// definición sin mandarla borraría la que había.
  final double notaDefault;

  /// Cuántas notas hay puestas ya. Null cuando no se sabe.
  ///
  /// Solo la cuenta el resumen de `/asignaturas/listasignaturas`; el listado
  /// de detalle no la trae. Se usa para avisar antes de borrar: una subunidad
  /// con treinta notas puestas no se borra por descuido.
  final int? cantNotas;

  SubunidadModel({
    required this.id,
    required this.unidadId,
    required this.definicion,
    required this.porcentaje,
    this.orden = 0,
    this.notaDefault = 0,
    this.cantNotas,
  });

  factory SubunidadModel.fromJson(Map<String, dynamic> json, {int? notas}) {
    return SubunidadModel(
      // El detalle la llama `id` y el resumen también, pero el boletín la
      // llama `subunidad_id`: se aceptan las dos.
      id: enteroO(json['id'] ?? json['subunidad_id']),
      unidadId: enteroO(json['unidad_id']),
      definicion: '${json['definicion'] ?? ''}',
      porcentaje: decimalO(json['porcentaje']),
      orden: enteroO(json['orden']),
      notaDefault: decimalO(json['nota_default']),
      cantNotas: notas ?? entero(json['cantNotas']),
    );
  }
}

/// Una unidad del periodo: el bloque del que cuelgan las subunidades.
class UnidadModel {
  final int id;
  final int asignaturaId;
  final int periodoId;
  final String definicion;
  final double porcentaje;
  final int orden;
  final List<SubunidadModel> subunidades;

  UnidadModel({
    required this.id,
    required this.definicion,
    required this.porcentaje,
    this.asignaturaId = 0,
    this.periodoId = 0,
    this.orden = 0,
    this.subunidades = const [],
  });

  double get porcentajeSubunidades =>
      subunidades.fold<double>(0, (acc, s) => acc + s.porcentaje);

  /// Si sus subunidades suman 100, que es lo que el backend da por bueno.
  ///
  /// Con margen porque los porcentajes llegan como decimales del servidor y
  /// tres tercios de 33,33 nunca dan exactamente cien.
  bool get subunidadesCuadran =>
      subunidades.isNotEmpty && (porcentajeSubunidades - 100).abs() < 0.5;

  factory UnidadModel.fromJson(
    Map<String, dynamic> json, {
    Map<int, int> notasPorSubunidad = const {},
  }) {
    final crudas = json['subunidades'];

    final subunidades = crudas is List
        ? (crudas.whereType<Map>().map((s) {
            final mapa = Map<String, dynamic>.from(s);
            final id = enteroO(mapa['id'] ?? mapa['subunidad_id']);
            return SubunidadModel.fromJson(mapa,
                notas: notasPorSubunidad[id]);
          }).toList()
          ..sort((a, b) => a.orden.compareTo(b.orden)))
        : <SubunidadModel>[];

    return UnidadModel(
      id: enteroO(json['id'] ?? json['unidad_id']),
      asignaturaId: enteroO(json['asignatura_id']),
      periodoId: enteroO(json['periodo_id']),
      definicion: '${json['definicion'] ?? ''}',
      porcentaje: decimalO(json['porcentaje']),
      orden: enteroO(json['orden']),
      subunidades: subunidades,
    );
  }
}

/// Un porcentaje como se escribe: sin decimales cuando es redondo.
String porcentajeEscrito(double valor) {
  return valor == valor.roundToDouble()
      ? '${valor.toStringAsFixed(0)}%'
      : '${valor.toStringAsFixed(1)}%';
}

/// El número con el que llega un porcentaje, con cero por respaldo.
///
/// Los porcentajes salen de columnas decimales que PDO puede entregar como
/// cadena —'33.33'— o como número, y una unidad sin porcentaje no es un error:
/// es una unidad que todavía no vale nada.
double decimalO(dynamic valor) {
  if (valor == null) return 0;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.')) ?? 0;
}
