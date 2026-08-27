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
    delColegio: _temasDelColegio(cuerpo['colegio']),
  );
}

/// Los temas del colegio, leyendo **las dos formas** que puede tener.
///
/// No es defensa por si acaso: son dos formas reales y las dos están vivas a la
/// vez mientras dura un despliegue.
///
///  - **Objeto** —`{"colegio_muro": "c_1a2b…"}`— es la forma buena: la clave es
///    el nombre lógico, estable, con el que se etiquetan las preferencias, y el
///    valor es el tema de verdad, derivado con el secreto del colegio.
///  - **Lista** —`["colegio_muro", "colegio_avisos"]`— es la que devuelven los
///    quince hoy, y es la del fallo: esos literales son el mismo tema para todos
///    los colegios. Se leen para no romper la lectura, con el nombre lógico como
///    tema; nadie se suscribe a ellos porque
///    [PendientesNotificaciones.temasDelColegio] está apagado.
///
/// **Esto no lleva interruptor a propósito**, igual que el número de contraseñas
/// cambiadas de `usuarios`: se lee de la respuesta tal como venga, así que vale
/// antes y después del despliegue y no hay nada que acordarse de encender.
Map<String, String> _temasDelColegio(dynamic crudo) {
  final temas = <String, String>{};

  if (crudo is Map) {
    crudo.forEach((clave, valor) {
      final tema = '$valor'.trim();
      if (tema.isNotEmpty) temas['$clave'] = tema;
    });
    return temas;
  }

  if (crudo is List) {
    for (final entrada in crudo) {
      final nombre = '$entrada'.trim();
      if (nombre.isNotEmpty) temas[nombre] = nombre;
    }
  }

  return temas;
}

/// Lo que devuelve el endpoint de temas.
class TemasDeNotificacion {
  const TemasDeNotificacion({
    this.alumnos = const [],
    this.delColegio = const {},
  });

  /// Un bloque por alumno: el propio si quien mira es alumno, o cada acudido
  /// si es acudiente. **Solo con matrícula viva**: el servidor filtra, porque
  /// un parentesco no caduca solo y el acudiente de quien se fue hace tres años
  /// seguiría recibiendo sus avisos.
  final List<TemasDeUnAlumno> alumnos;

  /// Los del colegio entero —muro y avisos—, que no cuelgan de ningún alumno.
  ///
  /// Del **nombre lógico** —`colegio_muro`, estable y con el que se etiqueta la
  /// preferencia— al **tema de verdad**, que el servidor compone. Ver
  /// [_temasDelColegio] para las dos formas en que puede llegar.
  ///
  /// **Hoy no se usan, y no es un olvido.** Ver
  /// [PendientesNotificaciones.temasDelColegio].
  final Map<String, String> delColegio;

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
  /// los devolvía como literales sin identificador de colegio, y el proyecto de
  /// Firebase **es uno solo para los quince**: una sola app, un solo
  /// `com.micolevirtual.app`, un solo `google-services.json`. O sea que
  /// `colegio_muro` era el mismo tema para los quince colegios, y una
  /// publicación del muro de uno le llegaría a las familias de los otros
  /// catorce.
  ///
  /// Los temas **por alumno** nunca tuvieron ese problema: llevan HMAC con el
  /// secreto del colegio, así que dos colegios no colisionan. Por eso ésos sí se
  /// usan y éstos no.
  ///
  /// **Arreglado en el backend el 26 de agosto de 2026** (`b369020`): ahora son
  /// `c_` + 32 hex de HMAC, derivados con el mismo secreto del colegio que los
  /// del alumno. No llevan el identificador del colegio, que es lo que se pidió,
  /// y con razón: el secreto **ya es distinto en cada colegio** —es su
  /// `APP_KEY`— así que el identificador sería un dato de más, y uno que hoy no
  /// existe en su `config/` y obligaría a editar quince `.env`.
  ///
  /// **Pero está en `main` y NO desplegado**, así que sigue apagado. Se enciende
  /// cuando entre en una tanda y esté en los quince, comprobado contra el hash y
  /// no contra `main` — que es la lección de esta semana. Ver
  /// docs/notificaciones.md.
  ///
  /// La letra pequeña que nos toca conocer: si dos colegios compartieran
  /// `APP_KEY` —un `.env` copiado al crear uno nuevo, que es como se crean—, sus
  /// temas colisionarían. **Eso no lo introduce el arreglo**: los temas de
  /// alumno dependen del mismo secreto desde el primer día.
  static bool temasDelColegio = false;
}
