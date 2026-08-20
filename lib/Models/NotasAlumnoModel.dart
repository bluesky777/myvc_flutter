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
  });

  bool get tieneNota => nota != null;

  /// La nota como se escribe en un boletín: sin decimales cuando es redonda.
  String get notaEscrita {
    if (nota == null) return '—';
    return nota! == nota!.roundToDouble()
        ? nota!.toStringAsFixed(0)
        : nota!.toStringAsFixed(1);
  }

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

  /// El promedio de lo que ya tiene nota. Null si no hay ninguna todavía.
  double? get promedio {
    final puestas = asignaturas.where((a) => a.tieneNota).toList();
    if (puestas.isEmpty) return null;

    final suma = puestas.fold<double>(0, (acc, a) => acc + a.nota!);
    return suma / puestas.length;
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

double? _decimal(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.'));
}
