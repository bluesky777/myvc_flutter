import 'package:myvc_flutter/Utils/JsonBackend.dart';

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
      id: entero(json['asignatura_id']) ?? 0,
      grupoId: entero(json['grupo_id']) ?? 0,
      profesorId: entero(json['profesor_id']),
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

  /// El archivo de su foto, tal como lo da /contratos. Cuando el docente no
  /// tiene foto propia, el backend ya devuelve el default según el sexo.
  final String? fotoNombre;

  DocenteModel({
    required this.profesorId,
    required this.nombre,
    this.fotoNombre,
  });
}
