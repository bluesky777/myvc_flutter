import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// En qué falló el uniforme. Cada una es una columna `tinyint` de la tabla.
///
/// «Sin cámara» no va de ropa: viene de las clases a distancia, donde el
/// alumno que no encendía la cámara se anotaba en la misma planilla. El
/// colegio lo dejó ahí y se sigue usando.
enum MarcaUniforme {
  camara('camara', 'Sin cámara'),
  contrario('contrario', 'Contrario'),
  sinUniforme('sin_uniforme', 'Sin uniforme'),
  incompleto('incompleto', 'Incompleto'),
  cabello('cabello', 'Cabello'),
  accesorios('accesorios', 'Accesorios');

  const MarcaUniforme(this.clave, this.nombre);

  /// La columna del backend.
  final String clave;

  /// Cómo se lee en la pantalla.
  final String nombre;
}

/// Una falla de uniforme anotada a un alumno en un periodo.
///
/// No es una situación del manual de convivencia: es su propia tabla y sus
/// propios endpoints. Una falla de uniforme no se tipifica con ordinales ni
/// deriva en nada; se cuenta, y con suficientes el colegio abre una situación
/// aparte.
class UniformeModel {
  final int id;
  final int alumnoId;
  final int periodoId;

  /// Cuándo fue. Aquí la hora sí es un dato, no relleno: la planilla se pasa a
  /// la entrada y a media mañana.
  final DateTime? fechaHora;

  final String? descripcion;

  /// La asignatura en la que se anotó, cuando se anotó desde una clase. Desde
  /// esta pantalla no se pone: se registra a nombre del periodo.
  final String? materia;

  final Set<MarcaUniforme> marcas;

  /// El colegio le aceptó la excusa. Sigue contando como registro, pero se
  /// pinta aparte para que no se lea como una falla más.
  final bool excusado;

  UniformeModel({
    required this.id,
    this.alumnoId = 0,
    this.periodoId = 0,
    this.fechaHora,
    this.descripcion,
    this.materia,
    Set<MarcaUniforme>? marcas,
    this.excusado = false,
  }) : marcas = marcas ?? const {};

  factory UniformeModel.fromJson(Map<String, dynamic> json) {
    return UniformeModel(
      id: enteroO(json['id']),
      alumnoId: enteroO(json['alumno_id']),
      periodoId: enteroO(json['periodo_id']),
      fechaHora: _fecha(json['fecha_hora']),
      descripcion: texto(json['descripcion']),
      materia: texto(json['materia']),
      marcas: {
        for (final marca in MarcaUniforme.values)
          if (enteroO(json[marca.clave]) == 1) marca
      },
      excusado: enteroO(json['excusado']) == 1,
    );
  }

  static DateTime? _fecha(dynamic crudo) {
    final valor = texto(crudo);
    if (valor == null) return null;

    final fecha = DateTime.tryParse(valor);
    if (fecha == null || fecha.year < 1900) return null;

    return fecha;
  }

  /// Una copia con lo que se cambie. El modelo no se muta: la pantalla
  /// reemplaza la fila entera al guardar, como hace con todo lo demás.
  UniformeModel con({
    DateTime? fechaHora,
    String? descripcion,
    Set<MarcaUniforme>? marcas,
    bool? excusado,
  }) {
    return UniformeModel(
      id: id,
      alumnoId: alumnoId,
      periodoId: periodoId,
      fechaHora: fechaHora ?? this.fechaHora,
      descripcion: descripcion ?? this.descripcion,
      materia: materia,
      marcas: marcas ?? this.marcas,
      excusado: excusado ?? this.excusado,
    );
  }

  /// Lo que se manda al backend, con todas las marcas en 0 o en 1.
  ///
  /// Van TODAS, también las que están apagadas: `uniformes/actualizar`
  /// reescribe las siete columnas con lo que reciba, así que omitir una la
  /// dejaría en null y desaparecería del registro sin que nadie la quitara.
  Map<String, dynamic> aCuerpo() {
    return {
      for (final marca in MarcaUniforme.values)
        marca.clave: marcas.contains(marca) ? 1 : 0,
      'excusado': excusado ? 1 : 0,
      'descripcion': descripcion,
      if (fechaHora != null) 'fecha_hora': fechaHoraParaServidor(fechaHora!),
    };
  }

  /// Si no falló nada de nada. Se puede guardar así —el colegio a veces solo
  /// quiere dejar la nota escrita—, pero la pantalla lo avisa.
  bool get sinMarcas => marcas.isEmpty;

  /// Los nombres de las marcas, en el orden en que están declaradas, que es el
  /// mismo en el que salen en la planilla de la web.
  List<String> get nombresDeMarcas => [
        for (final marca in MarcaUniforme.values)
          if (marcas.contains(marca)) marca.nombre
      ];

  @override
  String toString() =>
      '(UniformeModel) $id ${formatoDia(fechaHora)} ${nombresDeMarcas.join(", ")}';
}
