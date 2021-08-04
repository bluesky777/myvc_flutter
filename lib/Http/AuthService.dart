class AuthService {
  static UserAutenticado user = UserAutenticado();
  static setToken(String mytoken) => AuthService.user.token = mytoken;
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
