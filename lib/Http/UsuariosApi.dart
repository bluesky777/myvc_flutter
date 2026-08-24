/// Las cuentas del colegio: traerlas por grupo y arreglarlas de una en una.
///
/// El plan entero, con lo que falta en el servidor y por qué, está en
/// [docs/usuarios.md](../../docs/usuarios.md).
///
/// **La regla de esta pantalla es no pedir nunca el colegio entero.** La
/// equivalente del front web trae las 2.279 personas de una vez con
/// `GET perfiles/usuariosall`, que además hace tres consultas por fila para sus
/// roles: unas 6.800 por pantallazo. Aquí nunca se pide más de un grupo, que son
/// treinta o cuarenta.
///
/// **Y la restricción a quien administra cuentas es de la app, no del
/// servidor.** Casi todo esto lleva `auth.personal`, que solo deja fuera a
/// alumnos y acudientes. Es alcance, no permiso; lo que niega de verdad es la
/// guarda del backend, y donde una guarda pide más que la app, la pantalla lo
/// dice en voz alta en vez de comerse un 403.
library;

import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/CuentaDeUsuarioModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';

/// Lo que la pantalla sabe hacer y todavía no puede.
///
/// Cada uno se enciende con una palabra el día que su motivo desaparezca, y
/// hasta entonces la pantalla enseña en su sitio por qué está apagado. No son
/// constantes para que las pruebas puedan encenderlos y comprobar lo que sale.
class PendientesUsuarios {
  /// Cambiar el nombre de usuario de otra persona.
  ///
  /// **Este no está apagado por falta de endpoint: está apagado porque el que
  /// hay es una puerta abierta.** `PUT perfiles/guardar-username/{id}` lleva
  /// `persona.propia:user_id`, y ese guard deja pasar de largo a todo el que no
  /// sea alumno ni acudiente; el controlador solo comprueba que el nombre no
  /// venga vacío. O sea que cualquiera de los 51 docentes le cambia el usuario a
  /// cualquier cuenta, incluida la de un superusuario, y como `users.username`
  /// es UNIQUE, eso deja a alguien fuera del sistema en una petición.
  ///
  /// El código de aquí está escrito y probado. Se enciende cuando el backend
  /// cierre la guarda, y no antes: la primera versión de esta pantalla no puede
  /// ser el cliente cómodo de una escalada de privilegios.
  static bool cambiarUsername = false;

  /// Ver y cambiar los roles de cada persona.
  ///
  /// Hoy los roles de alguien solo salen por `usuariosall`, o sea trayendo las
  /// 2.279 del colegio. Enseñar unas casillas sin saber cuáles están marcadas
  /// sería peor que no enseñarlas. Falta `PUT usuarios/roles-de` con
  /// `{user_ids: []}`.
  static bool rolesPorPersona = false;

  /// La fecha y hora de la última vez.
  ///
  /// No hay columna ni endpoint. Cuando lo haya será
  /// `GREATEST(MAX(historiales.created_at), MAX(personal_access_tokens.last_used_at))`:
  /// `historiales` solo anota cuándo se tecleó la contraseña, y el refresco dura
  /// catorce días y rota, así que quien abre la app cada semana no vuelve a
  /// hacer login nunca.
  static bool ultimoAcceso = false;

  /// «Otros»: las cuentas que no cuelgan de profesor, alumno ni acudiente.
  ///
  /// Son pocas, pero hoy solo se pueden sacar trayendo las 2.279.
  static bool otrosUsuarios = false;

  /// El documento como nombre de usuario, y la contraseña para un grupo de
  /// acudientes.
  ///
  /// Las de colegio entero existen —`cambiar-usuarios/*`— y no valen: esta
  /// pantalla trabaja por grupo. La de contraseña para un grupo de **alumnos**
  /// sí existe y está encendida: es `alumnos/cambiar-claves`.
  static bool masivasPorGrupoQueFaltan = false;

  /// El arreglo de `alumnos/cambiar-claves` ya está desplegado en los dieciséis.
  ///
  /// Mientras esté apagado, esa operación **alcanza a más gente de la que la
  /// pantalla enseña**: la consulta desplegada hoy no filtra el estado de la
  /// matrícula ni las cuentas de la papelera, así que además de los treinta que
  /// se ven, le cambia la contraseña a los retirados de ese grupo y a los
  /// borrados. Por eso la confirmación avisa de ello en vez de prometer un
  /// número.
  ///
  /// Encenderlo cambia una frase: la de la confirmación. El número de cuántas
  /// cambiaron no cuelga de aquí —se lee de la respuesta si viene—, así que
  /// olvidarse de encenderlo no oculta nada, solo deja un aviso de más.
  static bool cambiarClavesArreglado = false;

  /// Deja los interruptores como vienen de fábrica. Para las pruebas.
  static void comoDeFabrica() {
    cambiarUsername = false;
    rolesPorPersona = false;
    ultimoAcceso = false;
    otrosUsuarios = false;
    masivasPorGrupoQueFaltan = false;
    cambiarClavesArreglado = false;
  }
}

/// Los grupos del año en el que está el usuario.
///
/// El año no viaja en la petición: el backend lo lee de la fila del usuario.
Future<List<GrupoModel>> traerGruposDelColegio(Server server) async {
  final crudos = await _traerLista(server.get('/grupos'), 'los grupos');

  return crudos.map(GrupoModel.fromJson).toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
}

/// Los alumnos matriculados en un grupo, con su cuenta.
///
/// `grupos/listado` no trae celular ni documento. Salen vacíos a propósito y
/// están pedidos: los únicos sitios que hoy tienen el celular de un alumno son
/// de colegio entero, y pedir 1.280 filas para pintar treinta es justo lo que
/// esta pantalla existe para no hacer.
Future<List<CuentaDeUsuario>> traerAlumnosDeGrupo(
  Server server,
  int grupoId,
) async {
  final crudos = await _traerLista(
    server.get('/grupos/listado/$grupoId'),
    'los alumnos del grupo',
  );

  return crudos.map(CuentaDeUsuario.deAlumnoDeGrupo).toList();
}

/// Los acudientes de los alumnos de un grupo, cada uno con sus acudidos.
///
/// Se lee con PUT y con el grupo dentro de un mapa —`{grupo_actual: {id}}`—
/// porque es lo que espera el servidor, que recibía el objeto entero del grupo
/// desde el front web y solo mira su `id`.
Future<List<CuentaDeUsuario>> traerAcudientesDeGrupo(
  Server server,
  int grupoId,
) async {
  final res = await server.put('/acudientes/datos', {
    'grupo_actual': {'id': grupoId},
  });

  final cuerpo = _cuerpo(res, 'los acudientes del grupo');
  final lista = cuerpo is Map ? cuerpo['acudientes'] : cuerpo;

  if (lista is! List) return const [];

  return lista
      .whereType<Map>()
      .map((a) => CuentaDeUsuario.deAcudiente(Map<String, dynamic>.from(a)))
      .toList();
}

/// Los docentes del colegio con los años en que han estado contratados.
Future<List<CuentaDeUsuario>> traerDocentes(Server server) async {
  final crudos = await _traerLista(
    server.get('/profesores/conyears'),
    'los docentes',
  );

  return crudos.map(CuentaDeUsuario.deDocente).toList()
    ..sort((a, b) => a.nombreCompleto
        .toLowerCase()
        .compareTo(b.nombreCompleto.toLowerCase()));
}

/// El catálogo de roles del colegio.
Future<List<RolDeUsuario>> traerCatalogoDeRoles(Server server) async {
  final crudos = await _traerLista(server.get('/roles'), 'los roles');

  return crudos
      .map(RolDeUsuario.fromJson)
      .where((r) => r.nombre.isNotEmpty)
      .toList();
}

/// Le pone una contraseña a una persona. Null si entró, o el motivo.
///
/// Es la de un administrativo sobre otra cuenta, no la de cambiarse la propia:
/// esa es `perfiles/cambiarpassword`, que pide la anterior.
Future<String?> ponerContrasena(
  Server server, {
  required int userId,
  required String clave,
}) {
  return _mandar(
    server.put('/perfiles/reset-password/$userId', {'password': clave}),
    accion: 'cambiar esa contraseña',
    // El servidor deja pasar a un superusuario, y a un docente con la bandera
    // `profes_can_edit_alumnos` solo sobre alumnos.
    sinPermiso: 'Solo un superusuario puede cambiarle la contraseña a '
        'cualquiera. Un docente, solo la de un alumno.',
  );
}

/// Cambia el nombre de usuario de una persona. Null si entró, o el motivo.
///
/// Ver [PendientesUsuarios.cambiarUsername]: la pantalla no llama a esto
/// todavía, y no por falta de endpoint.
Future<String?> cambiarNombreDeUsuario(
  Server server, {
  required int userId,
  required String username,
}) {
  return _mandar(
    server.put('/perfiles/guardar-username/$userId', {'username': username}),
    accion: 'cambiar ese nombre de usuario',
    // De respaldo nada más: el servidor distingue los dos casos —400 si viene
    // vacío, 422 si ese nombre ya es de otra cuenta— y manda su propio texto,
    // que es el que se enseña. Antes el ocupado reventaba con un 500 de MySQL,
    // porque `users.username` es UNIQUE y no lo miraba nadie.
    porElCuerpo: 'El servidor no aceptó ese nombre de usuario.',
  );
}

/// Si ese nombre de usuario está libre.
///
/// Hace falta porque `users.username` es UNIQUE y el endpoint que lo escribe no
/// avisa: se cae con un 500 del `save()`. El servidor cuenta también los
/// borrados, y hace bien —el usuario de alguien borrado sigue ocupado—.
///
/// Ante la duda dice que no está libre: quien pregunta va a escribir encima de
/// una cuenta, y equivocarse hacia «no» solo cuesta un aviso de más.
Future<bool> estaLibreElNombreDeUsuario(Server server, String username) async {
  try {
    final res = await server.get(
      '/perfiles/comprobarusername/${Uri.encodeComponent(username)}',
    );

    if (res.statusCode >= 300) return false;

    final cuerpo = jsonDecode(res.body);
    final fila = cuerpo is List && cuerpo.isNotEmpty ? cuerpo.first : cuerpo;

    if (fila is! Map) return false;

    return fila['existe'] != true && fila['existe'] != 1;
  } catch (_) {
    return false;
  }
}

/// Le pone un rol a una persona. Null si entró, o el motivo.
Future<String?> ponerRol(
  Server server, {
  required int userId,
  required int rolId,
}) {
  return _mandar(
    server.put('/roles/addroletouser/$rolId', {'user_id': userId}),
    accion: 'poner ese rol',
  );
}

/// Le quita un rol a una persona. Null si entró, o el motivo.
Future<String?> quitarRol(
  Server server, {
  required int userId,
  required int rolId,
}) {
  return _mandar(
    server.put('/roles/removeroletouser/$rolId', {'user_id': userId}),
    accion: 'quitar ese rol',
  );
}

/// Una misma contraseña para todos los alumnos de un grupo.
///
/// **Alcanza a más gente de la que la pantalla enseña.** La consulta del
/// servidor no filtra el estado de la matrícula ni las cuentas en la papelera
/// (`AlumnosController.php:103-107`), al contrario que su vecina de colegio
/// entero, así que además de los matriculados alcanza a los retirados de ese
/// grupo y a los borrados. Confirmado como defecto y anotado para arreglo; hasta
/// entonces la confirmación de la pantalla no promete un número.
///
/// **Lo de arriba deja de ser verdad cuando el colegio actualice el servidor.**
/// El arreglo está escrito y probado en el backend —filtra MATR/ASIS y las
/// cuentas borradas, y contesta `{"resultado": "Cambiadas", "cambiadas": 31}`—,
/// pero vive en una rama sin fusionar y sin desplegar en los dieciséis. Ver
/// [PendientesUsuarios.cambiarClavesArreglado].
///
/// Devuelve el motivo del fallo, o cuántas cambió cuando el servidor lo dice.
/// Las dos cosas pueden venir vacías: en la versión de hoy no hay número que
/// contar, y eso no es un error.
Future<({String? fallo, int? cambiadas})> contrasenaParaElGrupo(
  Server server, {
  required int grupoId,
  required String clave,
}) async {
  final peticion = server.put('/alumnos/cambiar-claves', {
    'clave': clave,
    'grupo_id': grupoId,
  });

  // La respuesta hay que leerla dos veces —el fallo y el número—, así que se
  // guarda: un Future se espera cuantas veces haga falta, pero la petición no
  // se manda dos.
  final res = await peticion;

  final fallo = await _mandar(
    Future.value(res),
    accion: 'cambiar las contraseñas del grupo',
    // De respaldo, y a propósito sin nombrar a nadie: quién puede hacer esto
    // cambia con el despliegue, y quien lo sabe de verdad es el servidor. Ver
    // [_mandar].
    sinPermiso: 'El servidor no te deja cambiar las contraseñas de un grupo '
        'entero.',
  );

  return (fallo: fallo, cambiadas: fallo == null ? cuantasCambiaron(res.body) : null);
}

/// Cuántas contraseñas dice el servidor que cambió, o null si no lo dice.
///
/// Null en la versión desplegada hoy, que contesta la cadena «Cambiadas» y ya.
/// Se lee así —preguntando por el número en vez de exigirlo— para que la app
/// funcione igual antes y después del despliegue, sin un interruptor de por
/// medio: el número aparece en el aviso el día que el servidor lo mande.
int? cuantasCambiaron(dynamic cuerpo) {
  if (cuerpo is! String || cuerpo.trim().isEmpty) return null;

  try {
    final leido = jsonDecode(cuerpo);
    return leido is Map ? entero(leido['cambiadas']) : null;
  } catch (_) {
    return null;
  }
}

/// El cuerpo de una respuesta que tiene que traer datos, o una excepción con el
/// motivo escrito para que se pueda enseñar tal cual.
dynamic _cuerpo(dynamic res, String que) {
  if (res.statusCode == 401 || res.statusCode == 403) {
    throw Exception('No tienes permiso para ver $que.');
  }
  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = res.body;
  if (cuerpo is! String || cuerpo.trim().isEmpty) return null;

  return jsonDecode(cuerpo);
}

Future<List<Map<String, dynamic>>> _traerLista(
  Future peticion,
  String que,
) async {
  final cuerpo = _cuerpo(await peticion, que);

  if (cuerpo is! List) return const [];

  return cuerpo
      .whereType<Map>()
      .map((f) => Map<String, dynamic>.from(f))
      .toList();
}

/// Manda un cambio y devuelve null si entró, o el motivo si no.
///
/// **Cuando el servidor explica por qué dijo que no, gana su explicación.**
/// `Autoriza::exigir` corta con un `abort(403, '...')` que trae escrito el
/// criterio exacto —quién puede hacer eso—, y ese criterio cambia con el
/// despliegue: la contraseña de un grupo pasó de superusuario a superusuario o
/// secretaría, y los dieciséis colegios no se actualizan el mismo día. Una
/// frase escrita aquí envejece sin avisar; la suya llega siempre al día.
///
/// Los mensajes de aquí quedan de respaldo, para cuando no dice nada o contesta
/// una página de error en vez de JSON.
Future<String?> _mandar(
  Future peticion, {
  required String accion,
  String? sinPermiso,
  String? porElCuerpo,
}) async {
  try {
    final res = await peticion;

    if (res.statusCode == 401 || res.statusCode == 403) {
      return loQueDijoElServidor(res.body) ??
          sinPermiso ??
          'No tienes permiso para $accion.';
    }
    if (res.statusCode == 400 || res.statusCode == 422) {
      return loQueDijoElServidor(res.body) ??
          porElCuerpo ??
          'El servidor no aceptó $accion.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}

