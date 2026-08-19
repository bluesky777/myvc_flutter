class AuthService {
  static UserAutenticado user = UserAutenticado();
  static setToken(String mytoken) => AuthService.user.token = mytoken;

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
  String? tipo;
  String username;
  String? nombres;
  String sexo;
  Map<String, dynamic>? periodo;

  UserAutenticado({
    this.token,
    this.id,
    this.tipo,
    this.username = '',
    this.sexo = 'M',
    this.nombres,
    this.periodo,
  });

  /// Cómo se nombra a este usuario, con la misma regla que el resto de la
  /// plataforma: los de tipo Usuario no tienen ficha con nombres, y ahí el
  /// nombre de usuario ES el nombre.
  String get nombreVisible =>
      (nombres != null && nombres!.trim().isNotEmpty) ? nombres! : username;
}
