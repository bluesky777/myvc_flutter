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
  String username;
  String? nombres;
  String sexo;
  Map<String, dynamic>? periodo;

  UserAutenticado({
    this.token,
    this.username = '',
    this.sexo = 'M',
    this.nombres,
    this.periodo,
  });
}
