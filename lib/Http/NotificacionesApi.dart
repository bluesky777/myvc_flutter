import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';

/// A qué temas de Firebase tiene derecho quien pregunta.
///
/// `GET notificaciones/temas`. Es la única petición al servidor de todo el
/// frente de notificaciones: **las preferencias no viajan**. Apagar «Notas» es
/// desapuntarse de un tema, o sea una llamada a Google y **cero peticiones al
/// colegio, cero filas en la base y cero consultas al enviar** — quien no
/// quiere el aviso ya no está en el tema. Ver docs/notificaciones.md.
///
/// **Los temas no se derivan aquí, y eso es deliberado.** El del alumno es
/// `a_` + HMAC con el secreto del colegio; si la app supiera componerlo habría
/// dos sitios donde escribirlo mal, y uno de ellos **no da error**: publicar o
/// suscribirse a un tema que no existe es válido en FCM, así que el aviso se
/// perdería en silencio. Se piden hechos y se usan tal cual.
Future<TemasDeNotificacion> traerTemas(Server server) async {
  final res = await server.get('/notificaciones/temas');

  if (res.statusCode >= 300) {
    throw Exception(mensajeDeFallo(res.statusCode, 'ver los avisos'));
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió los temas.');
  }

  final crudos = cuerpo['alumnos'];

  return TemasDeNotificacion(
    alumnos: crudos is List
        ? crudos
            .whereType<Map>()
            .map((a) => TemasDeUnAlumno.fromJson(Map<String, dynamic>.from(a)))
            .where((a) => a.alumnoId != 0)
            .toList()
        : const [],
    delColegio: _textos(cuerpo['colegio']),
  );
}

List<String> _textos(dynamic crudo) {
  if (crudo is! List) return const [];

  return crudo
      .map((t) => '$t'.trim())
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
}

/// Lo que devuelve el endpoint de temas.
class TemasDeNotificacion {
  const TemasDeNotificacion({
    this.alumnos = const [],
    this.delColegio = const [],
  });

  /// Un bloque por alumno: el propio si quien mira es alumno, o cada acudido
  /// si es acudiente. **Solo con matrícula viva**: el servidor filtra, porque
  /// un parentesco no caduca solo y el acudiente de quien se fue hace tres años
  /// seguiría recibiendo sus avisos.
  final List<TemasDeUnAlumno> alumnos;

  /// Los del colegio entero — muro y avisos—, que no cuelgan de ningún alumno.
  ///
  /// **Hoy no se usan, y no es un olvido.** Ver
  /// [PendientesNotificaciones.temasDelColegio].
  final List<String> delColegio;

  bool get hayAlgo => alumnos.isNotEmpty;

  /// Todos los temas por alumno, de los tipos que se le pasen.
  ///
  /// Sirve para la suscripción y para lo contrario: al cerrar sesión hay que
  /// desapuntarse de **todos**, encendidos o no, porque el interruptor de la
  /// próxima persona que entre en ese teléfono no dice nada de esta.
  List<String> temasDe(Iterable<TipoDeAviso> tipos) => [
        for (final alumno in alumnos)
          for (final tipo in tipos)
            if (alumno.temas[tipo.clave] != null) alumno.temas[tipo.clave]!,
      ];
}

/// Los temas de un alumno, por tipo.
class TemasDeUnAlumno {
  const TemasDeUnAlumno({
    required this.alumnoId,
    required this.nombre,
    required this.temas,
  });

  final int alumnoId;
  final String nombre;

  /// Por clave de tipo —`notas`, `asistencia`, `disciplina`— al nombre del tema
  /// ya compuesto por el servidor.
  final Map<String, String> temas;

  factory TemasDeUnAlumno.fromJson(Map<String, dynamic> json) {
    final crudos = json['temas'];
    final temas = <String, String>{};

    if (crudos is Map) {
      crudos.forEach((clave, valor) {
        final tema = '$valor'.trim();
        if (tema.isNotEmpty) temas['$clave'] = tema;
      });
    }

    return TemasDeUnAlumno(
      // Los listados del backend se arman con `DB::select` y SQL a pelo, así
      // que los tipos los decide PDO: el id puede llegar como texto.
      alumnoId: int.tryParse('${json['alumno_id']}') ?? 0,
      nombre: '${json['nombre'] ?? ''}'.trim(),
      temas: temas,
    );
  }
}

/// Los tres tipos de aviso que cuelgan de un alumno.
///
/// La clave es la que usa el servidor y **no se traduce**: viaja dentro del
/// nombre del tema. El rótulo sí es nuestro, porque es lo que lee una familia.
enum TipoDeAviso {
  notas('notas', 'Notas', 'Cuando le publican una nota nueva.'),
  asistencia('asistencia', 'Asistencia',
      'Cuando le anotan una falta o una tardanza.'),
  disciplina('disciplina', 'Disciplina',
      'Cuando le registran una situación de convivencia.');

  const TipoDeAviso(this.clave, this.rotulo, this.explicacion);

  final String clave;
  final String rotulo;
  final String explicacion;
}

/// Lo que está escrito pero todavía no se puede encender.
///
/// Mismo criterio que [Interruptores](../Utils/Interruptores.dart): el camino
/// nuevo queda escrito y probado, y encenderlo es cambiar un `false`.
class PendientesNotificaciones {
  PendientesNotificaciones._();

  /// Suscribirse a `colegio_muro` y `colegio_avisos`.
  ///
  /// **Apagado por un fallo del servidor, no porque falte código.** El endpoint
  /// los devuelve como literales sin identificador de colegio, y el proyecto de
  /// Firebase **es uno solo para los quince**: una sola app, un solo
  /// `com.micolevirtual.app`, un solo `google-services.json`. O sea que
  /// `colegio_muro` es el mismo tema para los quince colegios, y una publicación
  /// del muro de uno le llegaría a las familias de los otros catorce.
  ///
  /// Los temas **por alumno** no tienen ese problema: llevan HMAC con el
  /// secreto del colegio, así que dos colegios nunca colisionan. Por eso ésos
  /// sí se usan y éstos no.
  ///
  /// Está avisado al backend con la forma que se pidió desde el plan —`c_` +
  /// HMAC del identificador del colegio, entregado ya compuesto—. Se enciende
  /// cuando eso esté **desplegado en los quince**, comprobado contra el hash de
  /// la tanda y no contra `main`. Ver docs/notificaciones.md.
  static bool temasDelColegio = false;
}
