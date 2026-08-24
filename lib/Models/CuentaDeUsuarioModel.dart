import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Un rol, tal como está escrito en la tabla `roles`.
///
/// El nombre se guarda tal cual: en la tabla conviven 'Admin' con 'admin' y
/// 'Profesor' con 'profesor'. Aquí se enseña como esté escrito —es lo que el
/// colegio ve en la plataforma web— y se compara por [clave], en minúsculas.
class RolDeUsuario {
  const RolDeUsuario({required this.id, required this.nombre});

  final int id;
  final String nombre;

  String get clave => nombre.trim().toLowerCase();

  factory RolDeUsuario.fromJson(Map<String, dynamic> json) => RolDeUsuario(
        id: enteroO(json['id']),
        nombre: '${json['name'] ?? json['nombre'] ?? ''}'.trim(),
      );

  @override
  bool operator ==(Object other) => other is RolDeUsuario && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Un acudido: el alumno del que alguien es acudiente.
///
/// **Hoy llega sin foto y sin su `alumno_id`.** La consulta del servidor que los
/// trae —`Acudiente::$consulta_alumnos_de_acudiente`— devuelve el nombre, el
/// grupo, el parentesco y el `user_id`, pero ni `a.id` ni la foto. Con el
/// `user_id` basta para abrir su cuenta y cambiarle la contraseña, que es lo que
/// hace esta pantalla; la foto queda en las iniciales hasta que el servidor la
/// mande. Está pedido, ver docs/usuarios.md.
class Acudido {
  const Acudido({
    required this.userId,
    required this.nombres,
    required this.apellidos,
    this.username,
    this.fotoNombre,
    this.parentesco,
    this.nombreGrupo,
  });

  final int userId;
  final String nombres;
  final String apellidos;
  final String? username;
  final String? fotoNombre;
  final String? parentesco;
  final String? nombreGrupo;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  bool get tieneCuenta => userId > 0;

  factory Acudido.fromJson(Map<String, dynamic> json) => Acudido(
        userId: enteroO(json['user_id']),
        nombres: '${json['nombres'] ?? ''}'.trim(),
        apellidos: '${json['apellidos'] ?? ''}'.trim(),
        username: texto(json['username']),
        fotoNombre: texto(json['foto_nombre']),
        parentesco: texto(json['parentesco']),
        nombreGrupo: texto(json['nombre_grupo']),
      );
}

/// De qué tabla cuelga una cuenta. Es lo que el backend llama `tipo`, y decide
/// qué se puede hacer con ella.
enum TipoDeCuenta { alumno, acudiente, docente, otro }

/// Una cuenta del colegio, vista desde la pantalla que las administra.
///
/// Es una sola clase para los cuatro tipos a propósito: lo que la pantalla hace
/// con ellas —enseñar quién es, cambiarle el usuario, ponerle contraseña, mirar
/// sus roles— es lo mismo en los cuatro casos, y lo que cambia son dos listas
/// que solo tiene uno de ellos: los acudidos de un acudiente y los años
/// contratados de un docente.
///
/// Los cuatro listados del servidor devuelven columnas distintas para lo mismo,
/// así que cada uno entra por su fábrica y aquí dentro ya son iguales.
class CuentaDeUsuario {
  const CuentaDeUsuario({
    required this.userId,
    required this.tipo,
    this.personaId,
    this.nombres = '',
    this.apellidos = '',
    this.username,
    this.fotoNombre,
    this.celular,
    this.documento,
    this.parentesco,
    this.roles = const [],
    this.ultimoAcceso,
    this.acudidos = const [],
    this.years = const [],
  });

  /// El id de la fila de `users`. **0 cuando la persona no tiene cuenta**, que
  /// pasa y no es un error: hay alumnos matriculados a los que nadie se la ha
  /// creado todavía. Sin cuenta no hay nada que cambiarle.
  final int userId;

  final TipoDeCuenta tipo;

  /// El id de la ficha —alumno, acudiente, profesor—, que no es el del usuario.
  final int? personaId;

  final String nombres;
  final String apellidos;
  final String? username;
  final String? fotoNombre;
  final String? celular;
  final String? documento;

  /// «Madre», «Tío». Solo los acudientes lo tienen.
  final String? parentesco;

  final List<RolDeUsuario> roles;
  final DateTime? ultimoAcceso;

  /// Los alumnos a cargo. Solo los acudientes.
  final List<Acudido> acudidos;

  /// Los años en que ha estado contratado. Solo los docentes.
  final List<String> years;

  bool get tieneCuenta => userId > 0;

  /// Cómo se nombra a esta persona, con la misma regla que el resto de la app:
  /// las cuentas que no cuelgan de una ficha no tienen nombres, y para ellas el
  /// nombre de usuario ES el nombre.
  String get nombreCompleto {
    final completo = '$nombres $apellidos'.trim();
    if (completo.isNotEmpty) return completo;
    return username ?? 'Sin nombre';
  }

  CuentaDeUsuario conUsername(String? nuevo) => _copia(username: nuevo);

  CuentaDeUsuario conRoles(List<RolDeUsuario> nuevos) => _copia(roles: nuevos);

  CuentaDeUsuario _copia({String? username, List<RolDeUsuario>? roles}) =>
      CuentaDeUsuario(
        userId: userId,
        tipo: tipo,
        personaId: personaId,
        nombres: nombres,
        apellidos: apellidos,
        username: username ?? this.username,
        fotoNombre: fotoNombre,
        celular: celular,
        documento: documento,
        parentesco: parentesco,
        roles: roles ?? this.roles,
        ultimoAcceso: ultimoAcceso,
        acudidos: acudidos,
        years: years,
      );

  /// Un alumno de `GET grupos/listado/{grupo_id}`.
  ///
  /// Ese listado no trae celular ni documento —los dos huecos que la pantalla
  /// deja vacíos, ver docs/usuarios.md—, y llama `alumno_id` a la persona.
  factory CuentaDeUsuario.deAlumnoDeGrupo(Map<String, dynamic> json) =>
      CuentaDeUsuario(
        userId: enteroO(json['user_id']),
        tipo: TipoDeCuenta.alumno,
        personaId: entero(json['alumno_id']) ?? entero(json['id']),
        nombres: '${json['nombres'] ?? ''}'.trim(),
        apellidos: '${json['apellidos'] ?? ''}'.trim(),
        username: texto(json['username']),
        fotoNombre: texto(json['foto_nombre']),
        celular: texto(json['celular']),
        documento: texto(json['documento']),
        ultimoAcceso: _fecha(json['ultimo_acceso']),
        roles: _roles(json['roles']),
      );

  /// Un acudiente de `PUT acudientes/datos`.
  ///
  /// **Los acudidos se leen de donde hoy están**, que es dentro de
  /// `subGridOptions.data`: los `columnDefs` de la rejilla de Angular del front
  /// web viajan dentro de cada acudiente, y los alumnos a su cargo van en el
  /// `data` de esa maqueta. Se lee así porque es lo que el servidor manda; el
  /// día que los mande como `acudidos`, esta fábrica los coge de ahí primero y
  /// no hay que tocar nada más.
  factory CuentaDeUsuario.deAcudiente(Map<String, dynamic> json) {
    final llanos = json['acudidos'];
    final rejilla = json['subGridOptions'];
    final dentro = rejilla is Map ? rejilla['data'] : null;

    final crudos = llanos is List ? llanos : (dentro is List ? dentro : const []);

    return CuentaDeUsuario(
      userId: enteroO(json['user_id']),
      tipo: TipoDeCuenta.acudiente,
      personaId: entero(json['id']) ?? entero(json['acudiente_id']),
      nombres: '${json['nombres'] ?? ''}'.trim(),
      apellidos: '${json['apellidos'] ?? ''}'.trim(),
      username: texto(json['username']),
      fotoNombre: texto(json['foto_nombre']),
      celular: texto(json['celular']) ?? texto(json['telefono']),
      documento: texto(json['documento']),
      parentesco: texto(json['parentesco']),
      ultimoAcceso: _fecha(json['ultimo_acceso']),
      roles: _roles(json['roles']),
      acudidos: crudos
          .whereType<Map>()
          .map((a) => Acudido.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }

  /// Un docente de `GET profesores/conyears`.
  ///
  /// Los años contratados vienen en `years`, cada uno con su columna `year`.
  /// Ese listado tampoco trae usuario ni celular; está pedido.
  factory CuentaDeUsuario.deDocente(Map<String, dynamic> json) {
    final crudos = json['years'];

    return CuentaDeUsuario(
      userId: enteroO(json['user_id']),
      tipo: TipoDeCuenta.docente,
      personaId: entero(json['id']) ?? entero(json['profesor_id']),
      nombres: '${json['nombres'] ?? ''}'.trim(),
      apellidos: '${json['apellidos'] ?? ''}'.trim(),
      username: texto(json['username']),
      fotoNombre: texto(json['foto_nombre']),
      celular: texto(json['celular']),
      documento: texto(json['num_doc']) ?? texto(json['documento']),
      ultimoAcceso: _fecha(json['ultimo_acceso']),
      roles: _roles(json['roles']),
      years: crudos is List
          ? [
              for (final y in crudos)
                if (_year(y) != null) _year(y)!,
            ]
          : const [],
    );
  }

  /// Una cuenta que no cuelga de ninguna ficha. Sin nombres: para ellas el
  /// nombre de usuario es el nombre.
  factory CuentaDeUsuario.deOtro(Map<String, dynamic> json) => CuentaDeUsuario(
        userId: enteroO(json['user_id']) == 0
            ? enteroO(json['id'])
            : enteroO(json['user_id']),
        tipo: TipoDeCuenta.otro,
        personaId: entero(json['persona_id']),
        nombres: '${json['nombres'] ?? ''}'.trim(),
        apellidos: '${json['apellidos'] ?? ''}'.trim(),
        username: texto(json['username']),
        fotoNombre: texto(json['foto_nombre']),
        ultimoAcceso: _fecha(json['ultimo_acceso']),
        roles: _roles(json['roles']),
      );

  static List<RolDeUsuario> _roles(dynamic crudos) {
    if (crudos is! List) return const [];

    return crudos
        .whereType<Map>()
        .map((r) => RolDeUsuario.fromJson(Map<String, dynamic>.from(r)))
        .where((r) => r.nombre.isNotEmpty)
        .toList();
  }

  /// El año de una fila de `years`, que puede llegar como número o como mapa.
  static String? _year(dynamic crudo) {
    if (crudo is Map) {
      final valor = crudo['year'] ?? crudo['nombre'];
      return valor == null ? null : '$valor'.trim();
    }
    final suelto = '${crudo ?? ''}'.trim();
    return suelto.isEmpty ? null : suelto;
  }

  /// Una fecha del backend, o null si no vino o no se puede leer.
  ///
  /// Nunca tira: un `ultimo_acceso` ilegible deja el dato vacío, no la lista
  /// entera sin pintar.
  static DateTime? _fecha(dynamic crudo) {
    final cadena = texto(crudo);
    if (cadena == null) return null;

    // Como en el resto de la app: los números tal cual, sin toLocal(). El
    // backend guarda la hora de Bogotá y la serializa con una Z, así que
    // convertirla la correría cinco horas. Ver Utils/FechaServidor.dart.
    return DateTime.tryParse(cadena.replaceFirst(' ', 'T'));
  }
}
