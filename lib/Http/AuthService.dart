class AuthService {
  static UserAutenticado user = UserAutenticado();
  static void setToken(String mytoken) => AuthService.user.token = mytoken;

  /// Deja el servicio como recién arrancado.
  ///
  /// El token vive en un estático, así que sobrevivía a la navegación de vuelta
  /// al login: la sesión del docente anterior seguía abierta y era la que
  /// firmaba las tardanzas del siguiente.
  static void limpiar() => AuthService.user = UserAutenticado();
}

class UserAutenticado {
  String? token;
  int? id;

  /// Alumno, Profesor, Acudiente o Usuario. Lo decide el backend por la tabla
  /// de la que cuelga la cuenta, no por sus roles.
  String? tipo;

  String username;
  String? nombres;
  String sexo;
  Map<String, dynamic>? periodo;

  /// Los nombres de los roles, en minúsculas.
  ///
  /// El backend los manda tal como estén escritos en la tabla `roles`, y ahí
  /// conviven 'Admin' con 'admin' y 'Profesor' con 'profesor': el front web no
  /// lo nota porque su filtro de Angular compara sin distinguir mayúsculas.
  /// Aquí se normalizan al entrar para que la comparación sea una sola.
  Set<String> roles;

  bool isSuperuser;

  /// El id de la ficha —profesor, alumno, acudiente—, que no es el del usuario.
  int? personaId;

  UserAutenticado({
    this.token,
    this.id,
    this.tipo,
    this.username = '',
    this.sexo = 'M',
    this.nombres,
    this.periodo,
    Set<String>? roles,
    this.isSuperuser = false,
    this.personaId,
  }) : roles = roles ?? {};

  bool tieneRol(String nombre) => roles.contains(nombre.toLowerCase());

  bool get esAlumno => tipo == 'Alumno' || tieneRol('alumno');

  bool get esAcudiente => tipo == 'Acudiente' || tieneRol('acudiente');

  bool get esDocente => tipo == 'Profesor' || tieneRol('profesor');

  bool get esAdmin => isSuperuser || tieneRol('admin');

  /// Quien puede comentar una publicación del muro.
  ///
  /// Los alumnos y los acudientes leen; escriben los del colegio. Los cargos de
  /// coordinación se buscan por prefijo porque en la tabla aparecen con
  /// apellido —'Coord disciplinario', 'Coord académico'— y cada colegio puede
  /// tener los suyos.
  bool get puedeComentar {
    if (esAlumno || esAcudiente) return false;
    if (isSuperuser || esDocente || esAdmin) return true;

    const cargos = {'secretario', 'tesorero', 'rector'};
    return roles.any((rol) => cargos.contains(rol) || rol.startsWith('coord'));
  }

  /// Cómo se nombra a este usuario, con la misma regla que el resto de la
  /// plataforma: los de tipo Usuario no tienen ficha con nombres, y ahí el
  /// nombre de usuario ES el nombre.
  String get nombreVisible =>
      (nombres != null && nombres!.trim().isNotEmpty) ? nombres! : username;
}
