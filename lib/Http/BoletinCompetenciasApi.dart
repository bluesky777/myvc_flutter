import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/NotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/LineaDeBoletinModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// El boletín por competencias de un alumno: **sus líneas, las que van debajo
/// de la nota de cada asignatura**.
///
/// `PUT boletines-competencias/detailed-notas/{grupo_id}`, con el alumno en el
/// cuerpo. Es una ruta de **informe** —la familia de los cuatro boletines—, no
/// de notas, y eso decide tres cosas que no se parecen a las de [NotasApi]: el
/// verbo es PUT aunque no escriba nada, el grupo va en la URL y quien se pide va
/// en `requested_alumnos`.
///
/// Hay una segunda ruta, `…/detailed-notas-group/{grupo_id}`, que es el grupo
/// entero. **No se implementa aquí**: a un alumno y a un acudiente el guard les
/// contesta 403 —«Pedis más de lo que debes»— porque no nombra a nadie, así que
/// en esta app es una llamada que no puede salir bien. Quien la necesita es la
/// web administrativa.
///
/// ## La forma de la respuesta, medida y no supuesta
///
/// El controlador devuelve **una tupla de cinco elementos**, o sea que el cuerpo
/// es un **array JSON posicional** y no un objeto con claves
/// (`BoletinPorCompetenciasController::boletinDelGrupo`, l. 249, `return
/// [$grupo, $year, $respuesta, $this->escalasVal(), $poblacion]`):
///
///   0. **`grupo`** — `Grupo::datos`: `grupo_id`, `nombre_grupo`, `abrev_grupo`,
///      `titular_id`, `grado_id`, el titular con su foto y su firma, y
///      **`caritas`**, que es el único que se lee aquí. Más
///      `cantidad_alumnos`, que el controlador le añade y que es el del grupo
///      entero, no el de lo que se pidió.
///   1. **`year`** — `Year::datos` más `periodo`, que es el **número** del
///      periodo impreso (1..4). Es donde se comprueba qué periodo salió.
///   2. **`alumnos`** — la lista de boletines, **uno por alumno**. Cada uno es
///      la fila de la matrícula (`alumno_id`, `matricula_id`, `nombres`,
///      `apellidos`, foto, estado…) con cuatro cosas colgadas: `asignaturas`
///      —y dentro de cada una su `desempenos`, que son las líneas—, `promedio`,
///      `promedio_desempenio`, `comportamiento` y `situaciones`. **Es el único
///      elemento que esta capa desmonta.**
///   3. **`escalas`** — `escalas_de_valoracion` del año enteras y ordenadas
///      (`SELECT *`, `ORDER BY orden, id`). Es la leyenda del pie del papel. No
///      se lee aquí: las líneas ya vienen con su prefijo y su nivel puestos, así
///      que la app no necesita la escala para pintarlas.
///   4. **`poblacion`** — el recuento de lo que se imprimió, **con la clave
///      `caritas` repetida dentro**: `alumnos`, `asignaturas`,
///      `asignaturas_sin_catalogo`, `desempenos_impresos`, `frases_sueltas`,
///      `con_nivel`, `sin_nivel`, `asignaturas_sin_definitiva`,
///      `asignaturas_sin_banda`, `definitivas_reparadas`,
///      `definitivas_atrasadas` y `definitivas_que_faltan`. Es el panel del
///      coordinador; en el teléfono de una familia no pinta nada.
///
/// Cada línea de `asignaturas[].desempenos[]` trae
/// `desempeno_id · frase_asignatura_id · texto · tipo · orden · grado_id ·
/// escala_id · nivel · icono_infantil · icono_adolescente · origen`, y lo que
/// significa cada campo está en [LineaDeBoletin].
///
/// ## Se pide UN alumno, y además se filtra aquí
///
/// `requested_alumnos` es una lista de `{alumno_id, matricula_id?}` y aquí
/// siempre lleva **un solo elemento**: es lo que exige el guard, que con más de
/// uno responde 403.
///
/// **Y lo que vuelve se vuelve a filtrar por `alumno_id`.** Medido, el servidor
/// ya filtra —`soloLosPedidos`, l. 412, que el controlador llama antes de
/// devolver—, así que esto **no** está tapando un agujero abierto: está
/// cerrando el mismo por el otro lado. El filtro de allí es condicional —si
/// `requested_alumnos` no llega como array de mapas con `alumno_id`, devuelve
/// **la lista entera**, y `Grupo::alumnos` con ese parámetro ya devuelve de por
/// sí un superconjunto: todos los matriculados vigentes más los retirados que se
/// pidan— y lo que cuesta que esa condición falle un día, en una ruta
/// `boletin.propio`, es **el boletín de los treinta compañeros dentro de la
/// cuenta de un acudiente**. Dos líneas aquí valen eso.
///
/// ## Los dos bloqueos, y por qué se reutilizan los de [NotasApi]
///
/// El guard de la ruta es `boletin.propio` (`ExigirBoletinPropio`), que a
/// alumnos y acudientes les aplica además **el paz y salvo**: un acudiente al
/// día ve el boletín de su acudido y uno con deuda recibe **403 «No está a paz y
/// salvo. Lo siento.»**. Eso no es un fallo de red y no se puede enseñar como
/// tal: a un padre cuya única deuda es con tesorería, «no se pudo conectar» le
/// manda a reiniciar el teléfono en vez de al colegio.
///
/// Por eso se lanza el mismo [NotasBloqueadas] con [MotivoBloqueo.tesoreria] que
/// ya lanza `traerNotasDe`, y no un tipo nuevo: la pantalla de notas ya sabe
/// pintarlo —`MisNotasScreen._buildBloqueo`— y un segundo mecanismo para el
/// mismo bloqueo acabaría con dos avisos distintos para la misma deuda.
///
/// **Se reconoce por el texto y no por el código**, porque los cuatro rechazos
/// del guard son 403 y sólo uno es la deuda: «Pedis más de lo que debes», «No
/// puedes ver el de otros», «No es acudiente de este alumno» y el del paz y
/// salvo. Se busca `paz y salvo` —que es ASCII, así que sobrevive a que el
/// servidor conteste su página de error en HTML y a que el `http` de Dart
/// decodifique un JSON sin `charset` como latin1—. Los otros tres 403 salen como
/// excepción normal: son fallos de programación de quien llama o cuentas mal
/// emparejadas, no algo que explicarle a una familia.
///
/// **[MotivoBloqueo.colegio] no aparece aquí, y no es un olvido**: el
/// «Sistema bloqueado» de `alumnos_can_see_notas` lo comprueba
/// `NotasController::getAlumno` y **sólo él** —comprobado, es su única aparición
/// en el backend—. Esta ruta no lo mira, así que un colegio con las notas
/// cerradas sigue entregando este boletín. Quien pinte las dos cosas en la misma
/// pantalla debería saberlo.
///
/// ## Nada de esto está desplegado todavía
///
/// Las dos rutas están en `main` de `8myvc` y sin subir a los colegios, como el
/// resto de la familia de competencias. Llamar a esto contra un colegio de hoy
/// es un 404.

/// Trae el boletín por competencias de **un** alumno.
///
/// [grupoId] es el grupo en el que se le imprime —de ahí salen las asignaturas—
/// y [alumnoId] el alumno. [matriculaId] sólo hace falta cuando el alumno está
/// **retirado**: `Grupo::alumnos` trae a los vigentes siempre, y a un retirado
/// únicamente si se le pide por su matrícula. Mandarla cuando se sabe no cuesta
/// nada y es lo que hacen los otros clientes de la familia.
///
/// [periodoId] imprime un periodo que no es el activo, que es la única forma que
/// tiene una familia de ver el boletín de un periodo cerrado: `periodos/useractive`
/// es `auth.personal`. Sin él, el periodo activo del colegio. Tiene que ser del
/// año del token o el servidor contesta 422.
///
/// Lanza [NotasBloqueadas] con [MotivoBloqueo.tesoreria] si el colegio retiene
/// el boletín por deuda, y una [Exception] con el texto del servidor en lo
/// demás. Quien llama ya tiene un `try` alrededor de la carga: con esto vacío no
/// hay bloque que pintar.
Future<BoletinDeCompetencias> traerBoletinPorCompetencias(
  Server server, {
  required int grupoId,
  required int alumnoId,
  int? matriculaId,
  int? periodoId,
}) async {
  // `grupo_id` no viaja dentro del elemento aunque algún cliente viejo lo
  // mande: el grupo ya va en la URL, y de este mapa el servidor lee
  // `alumno_id` —el guard y el filtro— y `matricula_id` —los retirados—, nada
  // más.
  final res = await server.put(
    '/boletines-competencias/detailed-notas/$grupoId',
    {
      'requested_alumnos': [
        {
          'alumno_id': alumnoId,
          if (matriculaId != null) 'matricula_id': matriculaId,
        },
      ],
      if (periodoId != null) 'periodo_id': periodoId,
    },
  );

  if (res.statusCode >= 300) {
    throw _loQuePasoAlPedirlo(res);
  }

  final cuerpo = jsonDecode(res.body);

  // La tupla de cinco. Se comprueba la longitud y no sólo el tipo: un array
  // más corto es otra versión del servidor, y leer `[2]` a pelo de una lista
  // de dos sería un error de rango en vez de un aviso.
  if (cuerpo is! List || cuerpo.length < 5) {
    throw Exception('El servidor no devolvió el boletín por competencias.');
  }

  final grupo = cuerpo[0];
  final caritas = grupo is Map && (entero(grupo['caritas']) ?? 0) != 0;

  final alumnos = cuerpo[2];
  if (alumnos is! List) {
    throw Exception('El servidor no devolvió el boletín por competencias.');
  }

  final mio = _soloEl(alumnos, alumnoId);

  if (mio == null) {
    // Puede pasar sin que nadie haya hecho nada mal: el alumno está retirado y
    // no se mandó su `matricula_id`. Decirlo es mejor que devolver un boletín
    // vacío, que se lee como «no tiene notas».
    throw Exception('El boletín no trae a este alumno.');
  }

  return BoletinDeCompetencias.fromJson(mio, caritas: caritas);
}

/// El alumno que se pidió, descartando a los que el servidor mande de más.
///
/// El porqué está arriba, en la nota de la ruta. Lo importante de esta función
/// es que **no coge el primero**: coge el que tiene ese `alumno_id`, que en una
/// lista de compañeros ordenada por apellido no es lo mismo, y que devuelve null
/// en vez de inventarse uno cuando no está.
///
/// El id se compara con [entero] porque llega por `DB::select` y PDO puede
/// mandarlo como cadena: comparar `'31'` con `31` a pelo descarta al alumno
/// correcto y deja pasar a los demás, que es exactamente al revés de lo que hace
/// falta.
Map<String, dynamic>? _soloEl(List<dynamic> alumnos, int alumnoId) {
  for (final alumno in alumnos) {
    if (alumno is Map && entero(alumno['alumno_id']) == alumnoId) {
      return Map<String, dynamic>.from(alumno);
    }
  }

  return null;
}

/// Qué excepción lanzar cuando el servidor no contesta 200.
///
/// El paz y salvo sale como [NotasBloqueadas] y todo lo demás como [Exception]
/// con el texto del servidor si lo hay. Ver la nota de los bloqueos, arriba.
Exception _loQuePasoAlPedirlo(dynamic res) {
  final cuerpo = '${res.body}';

  if (res.statusCode == 403 && cuerpo.toLowerCase().contains('paz y salvo')) {
    return NotasBloqueadas(
      MotivoBloqueo.tesoreria,
      loQueDijoElServidor(cuerpo) ?? 'No está a paz y salvo.',
    );
  }

  return Exception(motivoDeRechazo(
    cuerpo,
    respaldo: 'El servidor respondió ${res.statusCode}.',
  ));
}
