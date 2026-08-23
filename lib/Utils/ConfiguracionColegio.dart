import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Cómo está configurado el colegio, según la misma respuesta de `POST /login`.
///
/// El backend manda en el contexto del usuario bastante más de lo que la app
/// leía: junto al año y el periodo van los ajustes que deciden qué puede hacer
/// quien acaba de entrar —si los docentes pueden editar notas en este periodo,
/// a partir de qué nota se pierde, cómo llama el colegio a las unidades—. Todo
/// eso vivía en el JSON sin que nadie lo mirara, y cada pantalla que lo
/// necesitaba tenía que inventarse un valor.
///
/// Vive colgado de [ContextoAcademico] y no suelto, y esto es a propósito: dos
/// de estos ajustes son **del periodo**, no del año, así que cambian cuando el
/// usuario cambia de periodo en la barra de arriba. Al releerse ahí mismo
/// —`ContextoAcademico.refrescar()` vuelve a llamar a /login— no hay forma de
/// que se queden con los del periodo anterior.
///
/// No todos los campos llegan para todos: `profes_pueden_editar_notas`,
/// `profes_pueden_nivelar` y `show_materias_todas` solo salen en las consultas
/// de Profesor y de Usuario (ver `app/Services/ContextoDeUsuario.php`). Para un
/// alumno o un acudiente no vienen, y no pasa nada: son ajustes sobre lo que
/// hace un docente.
class ConfiguracionColegio {
  const ConfiguracionColegio({
    this.notaMinimaAceptada,
    this.profesPuedenEditarNotas = true,
    this.profesPuedenNivelar = true,
    this.mostrarTodasLasMaterias = false,
    this.alumnosPuedenVerNotas = true,
    this.unidad = 'Unidad',
    this.unidades = 'Unidades',
    this.subunidad = 'Subunidad',
    this.subunidades = 'Subunidades',
    this.unidadEsFemenina = true,
    this.subunidadEsFemenina = true,
  });

  /// La de antes de que nadie haya entrado, y la de cuando el contexto se
  /// limpia al cerrar sesión.
  const ConfiguracionColegio.vacia() : this();

  /// A partir de qué nota se aprueba. Por debajo, la nota está perdida.
  ///
  /// Nula cuando no vino, y entonces [esPerdida] no pinta nada de rojo: es
  /// mejor no señalar que señalar mal. El front web la usa a pelo y por eso
  /// allí un campo que falte deja todas las notas en negro, que viene a ser lo
  /// mismo por accidente.
  final int? notaMinimaAceptada;

  /// Si los docentes pueden editar notas, indicadores, tardanzas y
  /// comportamientos **en este periodo**.
  final bool profesPuedenEditarNotas;

  /// Si los docentes pueden nivelar o modificar las notas finales **en este
  /// periodo**. Es un permiso aparte del anterior y se abre en otro momento:
  /// primero se cierra la edición de notas y después se nivela.
  final bool profesPuedenNivelar;

  /// Si al docente se le enseñan todas sus asignaturas, ignorando los días que
  /// tenga configurados cada una. Es la salida para los colegios que no montan
  /// el horario.
  final bool mostrarTodasLasMaterias;

  /// Si alumnos y acudientes pueden ver sus notas ahora mismo. El colegio lo
  /// apaga mientras cuadra los boletines.
  final bool alumnosPuedenVerNotas;

  /// Cómo llama este colegio a las unidades y a las subunidades. Hay quien las
  /// llama «Logro» e «Indicador», y rotular «Unidad» a secas es hablarle al
  /// docente en un idioma que no es el suyo.
  final String unidad;
  final String unidades;
  final String subunidad;
  final String subunidades;

  /// El género de esos nombres, para concordar los artículos: «el logro» pero
  /// «la unidad». El backend lo manda como 'M' o 'F'.
  final bool unidadEsFemenina;
  final bool subunidadEsFemenina;

  /// Lee lo que venga, con lo que ya hay por defecto para lo que no venga.
  ///
  /// Con [entero] y no leyendo el campo a pelo porque estas columnas viajan
  /// como 0/1 y, según la conexión de PDO, pueden llegar como número o como
  /// cadena. Ver [JsonBackend].
  factory ConfiguracionColegio.deLogin(Map<String, dynamic> datos) {
    const porDefecto = ConfiguracionColegio.vacia();

    return ConfiguracionColegio(
      notaMinimaAceptada: entero(datos['nota_minima_aceptada']),
      profesPuedenEditarNotas: _bandera(
        datos['profes_pueden_editar_notas'],
        porDefecto.profesPuedenEditarNotas,
      ),
      profesPuedenNivelar: _bandera(
        datos['profes_pueden_nivelar'],
        porDefecto.profesPuedenNivelar,
      ),
      mostrarTodasLasMaterias: _bandera(
        datos['show_materias_todas'],
        porDefecto.mostrarTodasLasMaterias,
      ),
      alumnosPuedenVerNotas: _bandera(
        datos['alumnos_can_see_notas'],
        porDefecto.alumnosPuedenVerNotas,
      ),
      unidad: _nombre(datos['unidad_displayname'], porDefecto.unidad),
      unidades: _nombre(datos['unidades_displayname'], porDefecto.unidades),
      subunidad: _nombre(datos['subunidad_displayname'], porDefecto.subunidad),
      subunidades:
          _nombre(datos['subunidades_displayname'], porDefecto.subunidades),
      unidadEsFemenina: _esFemenina(
        datos['genero_unidad'],
        porDefecto.unidadEsFemenina,
      ),
      subunidadEsFemenina: _esFemenina(
        datos['genero_subunidad'],
        porDefecto.subunidadEsFemenina,
      ),
    );
  }

  /// Si quien está mirando puede editar notas ahora mismo.
  ///
  /// Esto es lo que decide si el campo se pinta gris. Quien decide de verdad es
  /// el backend, en `User::pueden_editar_notas`, y su regla es **más estrecha
  /// que la del front web**: solo pasan los usuarios de tipo 'Profesor' —con la
  /// bandera del periodo en 1— y los superusuarios. Cualquier otro recibe un
  /// 403, tenga el rol que tenga.
  ///
  /// El front web comprueba `hasRoleOrPerm('Admin')`, o sea el ROL, y por eso a
  /// un administrativo con rol de admin que no sea superusuario le enseña los
  /// campos editables y le da un error al guardar. Aquí se copia la regla del
  /// backend y no la del front: es mejor un campo gris con su motivo que un
  /// campo que acepta lo que después se pierde.
  ///
  /// Cuando la bandera del periodo no viene se supone que sí. No venir no es un
  /// no: para un alumno esa columna ni siquiera está en la consulta.
  bool get puedeEditarNotas {
    if (AuthService.user.isSuperuser) return true;
    if (!_esProfesorDeVerdad) return false;
    return profesPuedenEditarNotas;
  }

  /// Si quien está mirando puede tocar las definitivas: nivelarlas, marcarlas
  /// manuales o marcarlas recuperadas. Misma regla, otra bandera —el backend
  /// las separa en `User::pueden_modificar_definitivas`—.
  bool get puedeNivelar {
    if (AuthService.user.isSuperuser) return true;
    if (!_esProfesorDeVerdad) return false;
    return profesPuedenNivelar;
  }

  /// Si el backend lo tiene por docente, que no es lo mismo que tener el rol.
  ///
  /// `User::pueden_editar_notas` compara `$user->tipo == 'Profesor'`, o sea la
  /// columna de la tabla `users`. Un usuario de tipo 'Usuario' con un
  /// `profesor_id` asociado y el rol 'profesor' encima no la pasa, así que
  /// `AuthService.user.esDocente` —que sí mira el rol— diría que sí donde el
  /// servidor dice que no.
  bool get _esProfesorDeVerdad => AuthService.user.tipo == 'Profesor';

  /// Si esa nota está perdida. Falso mientras no se sepa la mínima.
  bool esPerdida(num? nota) {
    final minima = notaMinimaAceptada;
    if (nota == null || minima == null) return false;
    return nota < minima;
  }

  /// Qué decir arriba cuando el periodo está cerrado, o null si no lo está.
  ///
  /// Se avisa y los campos se dejan en gris, en vez de esconderlos: un campo
  /// que desaparece parece un fallo de la app; uno gris con el motivo al lado
  /// es una respuesta. Son cuatro frases y no una porque los dos permisos son
  /// independientes y al docente le importa cuál de los dos le falta.
  String? get avisoDeBloqueo {
    // Quien no es docente ni superusuario no edita nunca, esté el periodo como
    // esté, así que el motivo no es el periodo y decirlo sería mentir.
    if (!AuthService.user.isSuperuser && !_esProfesorDeVerdad) {
      return 'Las notas las edita el docente de la asignatura.';
    }

    if (profesPuedenEditarNotas && profesPuedenNivelar) return null;

    if (AuthService.user.isSuperuser) {
      return 'Este periodo está bloqueado, pero como superusuario puedes'
          ' editarlo.';
    }

    if (!profesPuedenEditarNotas && !profesPuedenNivelar) {
      return 'Este periodo está bloqueado: no puedes editar notas ni nivelar'
          ' las definitivas.';
    }

    if (!profesPuedenEditarNotas) {
      return 'Este periodo está bloqueado para editar notas, pero sí puedes'
          ' nivelar las definitivas.';
    }

    return 'En este periodo no puedes nivelar las definitivas.';
  }

  /// 'la' o 'el', para concordar con el nombre que el colegio les dé.
  String get articuloUnidad => unidadEsFemenina ? 'la' : 'el';
  String get articuloSubunidad => subunidadEsFemenina ? 'la' : 'el';

  /// 'de la' o 'del'.
  String get deLaUnidad => unidadEsFemenina ? 'de la' : 'del';
  String get deLaSubunidad => subunidadEsFemenina ? 'de la' : 'del';

  /// Una bandera 0/1 del backend, con respaldo si no vino.
  ///
  /// Solo un 0 explícito significa «no». Lo que no llega no es un no: para un
  /// alumno estas columnas ni siquiera están en la consulta.
  static bool _bandera(dynamic valor, bool respaldo) {
    final numero = entero(valor);
    return numero == null ? respaldo : numero != 0;
  }

  static String _nombre(dynamic valor, String respaldo) {
    final crudo = texto(valor)?.trim();
    return (crudo == null || crudo.isEmpty) ? respaldo : crudo;
  }

  static bool _esFemenina(dynamic valor, bool respaldo) {
    final crudo = texto(valor)?.trim().toUpperCase();
    if (crudo == 'F') return true;
    if (crudo == 'M') return false;
    return respaldo;
  }
}
