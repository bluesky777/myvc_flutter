import 'package:myvc_flutter/Models/AsistenciaModel.dart';

/// Las dos faltas que se le ponen a un alumno frente a la institución.
///
/// Las dos son filas de la tabla ausencias con entrada=1 —lo que las separa de
/// las de cada asignatura, que van con entrada=0 y con asignatura_id—, y se
/// distinguen entre sí por la columna tipo. Es como las separa el backend en
/// /asistencias/detailed y como las cuenta en ausencias_total.
enum TipoFalta {
  tardanza(
    valor: 'tardanza',
    clave: 'tardanzas',
    claveTotal: 'cant_tardanzas_entrada',
    titulo: 'Tardanzas',
    explicacion: 'Llegó tarde al colegio',
    singular: 'tardanza',
    plural: 'tardanzas',
  ),
  ausencia(
    valor: 'ausencia',
    clave: 'ausencias',
    claveTotal: 'cant_ausencias_entrada',
    titulo: 'Ausencias',
    explicacion: 'No vino al colegio',
    singular: 'ausencia',
    plural: 'ausencias',
  );

  const TipoFalta({
    required this.valor,
    required this.clave,
    required this.claveTotal,
    required this.titulo,
    required this.explicacion,
    required this.singular,
    required this.plural,
  });

  /// Lo que espera la columna `tipo` del backend.
  final String valor;

  /// La clave con la que /asistencias/detailed devuelve la lista.
  final String clave;

  /// La clave del contador del periodo dentro de ausencias_total.
  final String claveTotal;

  final String titulo;
  final String explicacion;
  final String singular;
  final String plural;

  /// 'una tardanza', '3 ausencias'… como se dicen en una frase.
  String contar(int cantidad) =>
      '$cantidad ${cantidad == 1 ? singular : plural}';
}

/// Las faltas de un tipo dentro de una lista que trae de los dos.
///
/// Hace falta porque `tardanzas_perN`, de /disciplina/alumnos, filtra por
/// entrada=1 pero no por tipo: ahí vienen mezcladas las tardanzas y las
/// ausencias, pese al nombre. Lo que las separa es la columna `tipo` de cada
/// fila.
///
/// Las filas viejas pueden no traer `tipo`; cuentan como tardanzas, que es lo
/// que eran cuando esta parte de la plataforma solo registraba tardanzas.
List<AsistenciaModel> soloDelTipo(
  List<AsistenciaModel> faltas,
  TipoFalta tipo,
) {
  return faltas
      .where((f) => (f.tipo ?? TipoFalta.tardanza.valor) == tipo.valor)
      .toList();
}
