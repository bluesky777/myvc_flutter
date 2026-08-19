/// Una asignatura: la materia que un docente da a un grupo.
///
/// Viene de `GET /asignaturas/listasignaturas[/{profesor_id}]`, que sin id
/// resuelve el profesor desde el token.
class AsignaturaModel {
  final int id;
  final int grupoId;
  final int? profesorId;
  final String materia;
  final String aliasMateria;
  final String nombreGrupo;
  final String abrevGrupo;

  AsignaturaModel({
    required this.id,
    required this.grupoId,
    this.profesorId,
    required this.materia,
    required this.aliasMateria,
    required this.nombreGrupo,
    required this.abrevGrupo,
  });

  factory AsignaturaModel.fromJson(Map<String, dynamic> json) {
    return AsignaturaModel(
      id: _entero(json['asignatura_id']) ?? 0,
      grupoId: _entero(json['grupo_id']) ?? 0,
      profesorId: _entero(json['profesor_id']),
      materia: '${json['materia'] ?? ''}',
      aliasMateria: '${json['alias_materia'] ?? ''}',
      nombreGrupo: '${json['nombre_grupo'] ?? ''}',
      abrevGrupo: '${json['abrev_grupo'] ?? ''}',
    );
  }

  @override
  String toString() => '$abrevGrupo. $materia';
}

/// Un docente que da clase a un grupo.
class DocenteModel {
  final int profesorId;
  final String nombre;

  DocenteModel({required this.profesorId, required this.nombre});
}

int? _entero(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}
