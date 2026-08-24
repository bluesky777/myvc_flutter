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

  /// Quien ve el colegio entero y no solo lo suyo.
  ///
  /// En disciplina decide algo concreto: si el selector de grupos trae todos
  /// los del año o solo aquellos en los que el docente da clase. La
  /// coordinación entra porque es la que lleva el observador de todos los
  /// grados; los cargos se buscan por prefijo porque en la tabla aparecen con
  /// apellido —'Coord disciplinario', 'Coord académico'— y cada colegio tiene
  /// los suyos.
  ///
  /// No sustituye a lo que comprueba el backend: allí la puerta es
  /// `auth.personal`, que solo deja fuera a alumnos y acudientes. Esto es
  /// alcance, no permiso.
  bool get esEspecial =>
      esAdmin || roles.any((rol) => rol.startsWith('coord'));

  /// Quien administra las cuentas del colegio.
  ///
  /// Es el mismo criterio que `Autoriza::esAdministrativo` en el servidor
  /// —superusuario, `Admin` o `Secretario`—, y por eso incluye un rol que hoy
  /// no tiene nadie: el `Secretario` se creó el 21 de agosto de 2026 sin
  /// dárselo a ninguna cuenta. La razón de existir de ese rol es justamente
  /// esto: una secretaria docente que arregla usuarios y contraseñas sin ser
  /// superusuaria.
  ///
  /// **Y como siempre, esto es alcance y no permiso.** Decide qué enseña el
  /// menú; lo que niega de verdad es la guarda del backend, que en algunas de
  /// estas operaciones pide más —ver docs/usuarios.md—.
  bool get administraCuentas =>
      isSuperuser || tieneRol('admin') || tieneRol('secretario');

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
