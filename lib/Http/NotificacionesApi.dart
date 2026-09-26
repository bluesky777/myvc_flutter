import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

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

  return TemasDeNotificacion.deCuerpo(res.body);
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
    this.delUsuario = const {},
  });

  /// Del cuerpo de la respuesta, tal cual llega.
  ///
  /// Separado de [traerTemas] porque el mismo texto se guarda en el teléfono y
  /// se vuelve a leer sin red: apagar un interruptor en la pantalla de avisos
  /// no puede depender de que el colegio conteste. Ver `AvisosGuardados`.
  factory TemasDeNotificacion.deCuerpo(String cuerpoCrudo) {
    final cuerpo = jsonDecode(cuerpoCrudo);
    if (cuerpo is! Map) {
      throw Exception('El servidor no devolvió los temas.');
    }

    final crudos = cuerpo['alumnos'];

    return TemasDeNotificacion(
      alumnos: crudos is List
          ? crudos
              .whereType<Map>()
              .map(
                  (a) => TemasDeUnAlumno.fromJson(Map<String, dynamic>.from(a)))
              .where((a) => a.alumnoId != 0)
              .toList()
          : const [],
      delColegio: _temasDelColegio(cuerpo['colegio']),
      delUsuario: _temasDelColegio(cuerpo['usuario']),
    );
  }

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

  /// Los de la persona que entró, por tipo: hoy sólo `actividad`
  /// (`u_…_actividad`, 8myvc 311d07b, 26 sep 2026).
  ///
  /// Existen porque hay avisos que no son de ningún alumno: la encuesta que
  /// se le pide **al acudiente** iría al tema del hijo, y la vería el hijo,
  /// que comparte ese tema. El servidor lo deriva del token; un servidor sin
  /// la tanda 5 no manda la clave y esto queda vacío.
  final Map<String, String> delUsuario;

  bool get hayAlgo => alumnos.isNotEmpty;

  /// Todos los temas por alumno, de los tipos que se le pasen.
  ///
  /// Sirve para la suscripción y para lo contrario: al cerrar sesión hay que
  /// desapuntarse de **todos**, encendidos o no, porque el interruptor de la
  /// próxima persona que entre en ese teléfono no dice nada de esta.
  ///
  /// Incluye los de la persona ([delUsuario]) de esos mismos tipos, y salta
  /// los tipos que esta versión de la app todavía no enseña
  /// ([TipoDeAviso.disponible]): apuntarse a avisos que no se pueden abrir es
  /// peor que no recibirlos.
  List<String> temasDe(Iterable<TipoDeAviso> tipos) => [
        for (final alumno in alumnos)
          for (final tipo in tipos)
            if (tipo.disponible && alumno.temas[tipo.clave] != null)
              alumno.temas[tipo.clave]!,
        for (final tipo in tipos)
          if (tipo.disponible && delUsuario[tipo.clave] != null)
            delUsuario[tipo.clave]!,
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

/// Los cinco tipos de aviso que cuelgan de un alumno.
///
/// La clave es la que usa el servidor y **no se traduce**: viaja dentro del
/// nombre del tema. El rótulo sí es nuestro, porque es lo que lee una familia.
///
/// **Tiene que decir exactamente lo mismo que `TemasDeNotificacion::TIPOS` del
/// backend, y durante un mes no lo dijo.** Aquí había tres y allí cinco, así
/// que los avisos de `matricula` y de `compromiso` se publicaban y **no los
/// recibía nadie** — publicar en un tema sin suscriptores es válido en FCM y no
/// devuelve error, de modo que el servidor los daba por mandados y el teléfono
/// nunca supo que existían. Es el fallo más caro de este diseño y el que su
/// propio docblock avisaba: *«suscribirse a un tema que no existe es válido, así
/// que el aviso se perdería en silencio»*. Medido el 23 de septiembre de 2026.
///
/// El sexto, `actividad`, entró el 26 sep 2026 con la tanda 5 de actividades.
///
/// Si el backend añade un séptimo, esta lista se queda corta otra vez y **tampoco
/// dará error**. La forma de enterarse es comparar las dos listas, no esperar a
/// que algo falle.
enum TipoDeAviso {
  notas('notas', 'Notas', 'Cuando le publican una nota nueva.'),
  asistencia('asistencia', 'Asistencia',
      'Cuando le anotan una falta o una tardanza.'),
  disciplina('disciplina', 'Disciplina',
      'Cuando le registran una situación de convivencia.'),
  matricula('matricula', 'Matrícula',
      'Cuando avanza o se devuelve un paso de su matrícula.'),
  compromiso('compromiso', 'Compromisos',
      'Cuando le entregan un compromiso académico o su resultado.'),

  /// Tareas, cuestionarios y encuestas (tanda 5 de actividades). Llega por el
  /// tema del alumno y por el de la persona ([TemasDeNotificacion.delUsuario]).
  actividad('actividad', 'Actividades',
      'Tareas, cuestionarios y encuestas: cuando llega una, cuando está por '
          'cerrar, y su nota o sus resultados.');

  const TipoDeAviso(this.clave, this.rotulo, this.explicacion);

  final String clave;
  final String rotulo;
  final String explicacion;

  /// Si esta versión de la app lo enseña: las actividades sólo con
  /// [Interruptores.actividades]. Apagado, no sale su interruptor en
  /// «Notificaciones» y el teléfono no se apunta a su tema.
  bool get disponible => this != actividad || Interruptores.actividades;
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
