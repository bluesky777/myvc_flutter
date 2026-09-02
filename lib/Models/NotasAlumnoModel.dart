import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Utils/FormatoDeNota.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Las notas de un alumno en una asignatura, en un periodo.
class AsignaturaNotaModel {
  final int asignaturaId;
  final String materia;
  final String? alias;
  final String? area;

  final int? profesorId;
  final String docente;
  final String? fotoDocente;

  /// La definitiva del periodo. Null cuando el docente aún no la ha puesto.
  final double? nota;

  /// El nombre que el colegio le da a esa nota: «Superior», «Bajo»…
  final String? desempenio;

  /// Si la nota viene de una recuperación o la puso el docente a mano.
  final bool recuperada;
  final bool manual;

  /// Las faltas del alumno a ESTA clase en ESTE periodo, con su día.
  ///
  /// Son las de entrada=0 —las de la asignatura—: el backend las saca con
  /// `Ausencia::deAlumno`, que filtra por asignatura_id, así que las faltas al
  /// colegio, que no tienen asignatura, no vienen aquí. Esas se cuentan aparte,
  /// en el resumen por periodo de AsistenciaAlumnoApi.
  final List<AsistenciaModel> faltas;

  /// Los totales tal como los suma el backend.
  ///
  /// No es lo mismo que `faltas.length`: cada fila lleva `cantidad_ausencia` o
  /// `cantidad_tardanza` y el backend suma esas cantidades, no las filas. Se
  /// respeta su cuenta, que es la que ve el docente en su planilla.
  final int totalAusencias;
  final int totalTardanzas;

  AsignaturaNotaModel({
    required this.asignaturaId,
    required this.materia,
    required this.docente,
    this.alias,
    this.area,
    this.profesorId,
    this.fotoDocente,
    this.nota,
    this.desempenio,
    this.recuperada = false,
    this.manual = false,
    this.faltas = const [],
    this.totalAusencias = 0,
    this.totalTardanzas = 0,
  });

  bool get tieneNota => nota != null;

  bool get tieneFaltas => totalAusencias + totalTardanzas > 0;

  /// Las faltas de un tipo, de la más reciente a la más vieja.
  List<AsistenciaModel> faltasDe(TipoFalta tipo) {
    return soloDelTipo(faltas, tipo)
      ..sort((a, b) =>
          (b.fecha ?? DateTime(1900)).compareTo(a.fecha ?? DateTime(1900)));
  }

  /// Las que además dicen qué día fue.
  ///
  /// Once de cada cien filas de la tabla ausencias no tienen `fecha_hora` —en
  /// la base del colegio, 5.068 de 46.457—: son las que se subieron desde la
  /// planilla web y las de antes de que se guardara el día. Contarlas, se
  /// cuentan; lo que no se puede es decir cuándo fueron, y escribir «el —»
  /// doce veces seguidas no es decirlo, es ensuciarlo.
  List<AsistenciaModel> faltasConDiaDe(TipoFalta tipo) =>
      faltasDe(tipo).where((f) => f.fecha != null).toList();

  /// Cuántas faltas no dicen de qué día son.
  int get faltasSinDia => faltas.where((f) => f.fecha == null).length;

  /// La nota como se escribe en un boletín: **entera**.
  ///
  /// La regla y su porqué están en [notaPintada], que es de donde sale. Aquí
  /// era `toStringAsFixed(1)` cuando la definitiva era un entero en la base y
  /// el decimal no podía aparecer; desde que es `DECIMAL(7,4)` sí aparece, y
  /// «43.8» no es lo que imprime el boletín.
  String get notaEscrita => notaPintada(nota);

  factory AsignaturaNotaModel.fromJson(Map<String, dynamic> json) {
    final nombres = '${json['nombres_profesor'] ?? ''}'.trim();
    final apellidos = '${json['apellidos_profesor'] ?? ''}'.trim();

    return AsignaturaNotaModel(
      asignaturaId: enteroO(json['asignatura_id']),
      materia: '${json['materia'] ?? ''}',
      alias: texto(json['alias_materia']),
      area: texto(json['area_nombre']),
      profesorId: entero(json['profesor_id']),
      docente: '$nombres $apellidos'.trim(),
      fotoDocente: texto(json['foto_nombre']),
      nota: _decimal(json['nota_asignatura']),
      desempenio: texto(json['desempenio']),
      recuperada: entero(json['recuperada']) == 1,
      manual: entero(json['manual']) == 1,
      faltas: _faltas(json['ausencias']),
      totalAusencias: enteroO(json['total_ausencias']),
      totalTardanzas: enteroO(json['total_tardanzas']),
    );
  }
}

/// Un periodo del año, con las asignaturas del alumno.
class PeriodoNotasModel {
  final int id;
  final int numero;
  final List<AsignaturaNotaModel> asignaturas;

  PeriodoNotasModel({
    required this.id,
    required this.numero,
    required this.asignaturas,
  });

  /// El promedio del periodo, contado **como lo cuenta el boletín**.
  ///
  /// O sea: se divide entre **todas** las asignaturas del periodo, tengan nota
  /// o no, y una asignatura sin definitiva suma cero. Baja el promedio. Es la
  /// decisión de Joseth del 28 de agosto de 2026, y la tomó sabiendo lo que
  /// implica: baja igual **cuando nadie montó el periodo en esa asignatura**,
  /// así que a los treinta del grupo les baja por algo que no hizo ninguno.
  /// Descartó expresamente las dos alternativas —«si no hay unidades, no
  /// cuenta» y marcarlo en la casilla—, y descartó también dejar que la app
  /// contara a su manera.
  ///
  /// Antes esto promediaba sólo las que tenían nota, y daba un número más alto.
  /// El motivo de cambiarlo no es que aquél estuviera mal calculado: es que
  /// **el boletín es el papel que se imprime y se firma**, y dos números
  /// distintos para el mismo alumno según mire la pantalla o el papel es peor
  /// que un número discutible. El del papel divide entre todas desde hace años.
  ///
  /// **El divisor son las asignaturas de la respuesta, no las filas que traen
  /// definitiva.** Parece lo mismo y no lo es: el servidor arma este listado
  /// con un `left join notas_finales` —`Grupo::detailed_materias_notafinal`—,
  /// así que la asignatura viene igual cuando no hay definitiva, sólo que con
  /// sus campos a null. Contar filas presentes volvería a excluir justo las que
  /// tienen que contar.
  ///
  /// Null sólo cuando no hay ni una asignatura: ahí no hay nada que promediar,
  /// que no es lo mismo que promediar ceros.
  ///
  /// Hoy no lo pinta ninguna pantalla. Se deja correcto para cuando lo pinte.
  double? get promedio {
    if (asignaturas.isEmpty) return null;

    final suma = asignaturas.fold<double>(0, (acc, a) => acc + (a.nota ?? 0));
    return suma / asignaturas.length;
  }

  factory PeriodoNotasModel.fromJson(Map<String, dynamic> json) {
    final crudas = json['asignaturas'];

    return PeriodoNotasModel(
      id: enteroO(json['id']),
      numero: enteroO(json['numero']),
      asignaturas: crudas is List
          ? crudas
              .whereType<Map>()
              .map((a) =>
                  AsignaturaNotaModel.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
    );
  }
}

/// El boletín de un alumno: quién es, dónde está y sus periodos.
class NotasAlumnoModel {
  final int alumnoId;
  final String nombres;
  final String? apellidos;
  final String? fotoNombre;

  final int? grupoId;
  final String? grupo;
  final String? abrevGrupo;

  /// El id del docente titular. Su nombre no viene aquí: se resuelve aparte,
  /// contra /contratos, que es de donde lo saca el resto de la app.
  final int? titularId;

  final bool pazYSalvo;
  final double? deuda;

  final List<PeriodoNotasModel> periodos;

  NotasAlumnoModel({
    required this.alumnoId,
    required this.nombres,
    this.apellidos,
    this.fotoNombre,
    this.grupoId,
    this.grupo,
    this.abrevGrupo,
    this.titularId,
    this.pazYSalvo = true,
    this.deuda,
    this.periodos = const [],
  });

  String get nombreCompleto => '$nombres ${apellidos ?? ''}'.trim();

  factory NotasAlumnoModel.fromJson(Map<String, dynamic> json) {
    final crudos = json['periodos'];

    final periodos = crudos is List
        ? (crudos
            .whereType<Map>()
            .map((p) => PeriodoNotasModel.fromJson(Map<String, dynamic>.from(p)))
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero)))
        : <PeriodoNotasModel>[];

    return NotasAlumnoModel(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: texto(json['apellidos']),
      fotoNombre: texto(json['foto_nombre']),
      grupoId: entero(json['grupo_id']),
      grupo: texto(json['nombre_grupo']),
      abrevGrupo: texto(json['abrev_grupo']),
      titularId: entero(json['titular_id']),
      pazYSalvo: entero(json['pazysalvo']) != 0,
      deuda: _decimal(json['deuda']),
      periodos: periodos,
    );
  }
}

/// La clave se llama `ausencias` pero trae los dos tipos: dentro van también
/// las tardanzas, y lo que las separa es la columna `tipo` de cada fila.
List<AsistenciaModel> _faltas(dynamic crudas) {
  if (crudas is! List) return const [];

  return crudas
      .whereType<Map>()
      .map((f) => AsistenciaModel.fromJson(Map<String, dynamic>.from(f)))
      .toList();
}

double? _decimal(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.'));
}
