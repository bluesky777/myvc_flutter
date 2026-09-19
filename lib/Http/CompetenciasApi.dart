import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/CompetenciaModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// El plan de área por competencias: leerlo y escribirlo.
///
/// La familia del backend tiene siete rutas y aquí viven **cinco**:
/// `GET desempenos`, `POST desempenos`, `PUT desempenos/{id}`,
/// `DELETE desempenos/{id}` y `PUT desempenos/copiar`. Las otras dos no están
/// y ninguna por olvido:
///
///  - **`PUT desempenos/orden` no se implementa**: decidido que la app no
///    reordena. El orden lo hace el servidor y lo comparten la pantalla y el
///    boletín —ver `competenciasDeLista`—, así que un botón de subir y bajar
///    aquí sería la única forma de que los dos dejaran de coincidir;
///  - **`GET desempenos/catalogo-men`** es el catálogo de Estándares del MEN
///    para sugerir al escribir; no hace falta para la primera pantalla.
///
/// ## Y una corrección a lo que este archivo decía de `copiar`
///
/// Aquí ponía que copiar *«es trabajo de escritorio, de los que se hacen una
/// vez en agosto: va en la web administrativa, no en el teléfono»*. **Es
/// falso, y se cayó al abrir el controlador.** `putCopiarPlantilla` no copia el
/// catálogo del colegio: copia **un par (materia, grado) y un periodo** —su
/// `destino` son esos tres campos y su permiso es el mismo
/// `exigirEscrituraDelPlan` que usa escribir una a mano—. O sea que lo que
/// mueve es exactamente lo que el docente ya puede escribir en esta app, y
/// ahorrarle teclear cuatro frases que ya escribió el periodo pasado es trabajo
/// de pie y de todos los días.
///
/// Lo que sí se queda en la web es **el catálogo del colegio entero** y
/// **adoptar del MEN**, que son otra cosa. Ver `docs/competencias.md` §2.
///
/// **Nada de esto está desplegado todavía.** Las siete rutas están en `main` de
/// `8myvc` (`8329718`) y sin subir a los colegios, y la pantalla que las usa
/// vive detrás de `Interruptores.competenciasDocente`, que está apagado.
///
/// ## Quién puede escribir, que es lo que explica los dos 403 distintos
///
/// El guard de las siete es `auth.personal`, así que **leer lo puede cualquier
/// docente**: es la pantalla donde va a escribir, y cerrarle la lectura sería
/// cerrarle la pantalla. Escribir pasa por `Autoriza::puedeEscribirDesempenos`,
/// que es verdad por una de dos puertas: el permiso del colegio
/// (`can_edit_plantilla_notas`), o **dar esa materia en un grupo de ese grado**.
/// Y al docente —sólo a él— se le pide además el periodo abierto.
///
/// De ahí que un 403 signifique dos cosas muy distintas —«esa materia no es
/// tuya» y «ese periodo está cerrado»—, y que el texto del servidor sea lo
/// único que las separa. Ver [_motivoDelRechazo].
///
/// ## Por qué los motivos de aquí no dicen «competencia» ni «desempeño»
///
/// Esa palabra la elige cada colegio —`ConfiguracionColegio.competencia`, que es
/// una instancia que tiene la pantalla y no un valor global—, así que esta capa
/// no la conoce. Un aviso que diga «desempeño» en un colegio que las llama
/// competencias es peor que uno que no nombre la cosa.

/// Lo que devuelve crear o editar una: la fila entera ya guardada.
class ResultadoDeUnaCompetencia {
  const ResultadoDeUnaCompetencia({this.competencia, this.motivo});

  /// Cómo quedó la fila. Null cuando falló.
  final Competencia? competencia;

  /// Por qué no se pudo, o null si entró.
  final String? motivo;

  bool get entro => motivo == null;
}

/// El plan de área del año del token, filtrado.
///
/// **Lanza si el servidor no contesta 200, y no devuelve un motivo**, que es lo
/// que hace `traerCatalogoDeFrases` con el catálogo del año y por la misma
/// razón: esto se pide una vez al abrir la pantalla y con esto vacío no hay
/// pantalla, así que quien llama ya tiene un `try` alrededor de la carga y un
/// sitio donde pintar el fallo. Los tres que escriben sí devuelven motivo, que
/// es lo contrario: ahí hay algo pintado detrás del aviso. En lo que se lanza va
/// **el texto del servidor** cuando lo hay, por lo mismo que abajo.
///
/// **`grado_id` tiene tres estados y no dos**, porque el servidor filtra con
/// `d.grado_id <=> ?` y no con `= ?` (`getPlantilla`, y el `<=>` está puesto ahí
/// justamente para esto):
///
///  - **no mandarlo** —[gradoId] en null y [todosLosGrados] en false—: todas las
///    de esa materia, las de cada grado y las de «todos los grados» revueltas;
///  - **mandarlo vacío** —`grado_id=`, que es [todosLosGrados]—: **sólo** las de
///    «todos los grados», o sea las del colegio. Con `= NULL` no devolvería
///    ninguna, de ahí el `<=>`;
///  - **mandarlo con número** —[gradoId]—: sólo las de ese grado, y **no** las
///    del colegio.
///
/// Que el tercero no arrastre las del colegio es lo que hay que tener en cuenta
/// al pintar la tarjeta de un par (materia, grado): o se piden **dos veces** —una
/// con [gradoId] y otra con [todosLosGrados]—, o se pide sin grado y se separa
/// aquí, que es lo que hace la pantalla del docente porque de todas formas
/// necesita las de varias materias a la vez.
///
/// Los dos juntos no tienen sentido —vacío y con número son el mismo parámetro—
/// y manda [todosLosGrados].
///
/// **El año no se puede elegir**: el servidor filtra por el del token.
Future<List<Competencia>> traerCompetencias(
  Server server, {
  int? materiaId,
  int? gradoId,
  bool todosLosGrados = false,
  int? periodoId,
}) async {
  assert(!(todosLosGrados && gradoId != null),
      'grado_id es uno solo: o vacío o con número.');

  final filtros = <String>[
    if (materiaId != null) 'materia_id=$materiaId',
    if (todosLosGrados)
      'grado_id='
    else if (gradoId != null)
      'grado_id=$gradoId',
    if (periodoId != null) 'periodo_id=$periodoId',
  ];

  final res = await server.get(
    filtros.isEmpty ? '/desempenos' : '/desempenos?${filtros.join('&')}',
  );

  if (res.statusCode >= 300) {
    throw Exception(motivoDeRechazo(
      res.body,
      respaldo: 'El servidor respondió ${res.statusCode}.',
    ));
  }

  final cuerpo = jsonDecode(res.body);

  // La respuesta es un sobre: `{year_id, desempenos, grupos}`. `year_id` es el
  // del token, que la app ya sabe, y `grupos` es el recuento por (materia,
  // grado, periodo) que el front usa para pintar de un vistazo qué está vacío
  // — aquí no hace falta: lo vacío es una lista vacía. Se lee el sobre y
  // también una lista pelada, por si algún colegio corre una versión que
  // conteste sólo las filas.
  final filas = cuerpo is Map ? cuerpo['desempenos'] : cuerpo;

  return competenciasDeLista(filas);
}

/// Escribe una competencia nueva.
///
/// **[gradoId] es obligatorio de pasar y puede ser null, y esa incomodidad está
/// puesta a mano.** En `postPlantilla` un `grado_id` ausente no significa «déjalo
/// como estaba» sino **«para todos los grados»**, que es una fila del colegio:
/// quien la mande sin querer se lleva un 403 si es docente, y si es coordinador
/// se lleva algo peor —una fila que sale en el boletín de trece grados—. Así que
/// el llamante tiene que decirlo.
///
/// `orden` no se manda nunca: el servidor le pone `MAX(orden) + 1` de su grupo.
///
/// El 422 llega por `definicion` vacía o de más de 2000 caracteres, por [tipo]
/// de más de 60, o por una materia, un grado o un periodo que no existen —el
/// periodo, además, tiene que ser de este año—. El texto de todos ésos lo
/// escribe el servidor y se enseña tal cual.
Future<ResultadoDeUnaCompetencia> crearCompetencia(
  Server server, {
  required int materiaId,
  required int? gradoId,
  required int periodoId,
  required String definicion,
  String? tipo,
}) async {
  return _escribir(
    () => server.post('/desempenos', {
      'materia_id': materiaId,
      'grado_id': gradoId,
      'periodo_id': periodoId,
      'definicion': definicion,
      'tipo': tipo,
    }),
    accion: 'guardar',
  );
}

/// Cambia el texto y la marca de una.
///
/// **Viajan `definicion` y `tipo` y nada más, y eso es lo que impide que la fila
/// se mueva.** En `putPlantilla` cada campo ausente vale lo que ya hay guardado,
/// así que no mandar `materia_id`, `grado_id`, `periodo_id` ni `orden` es la
/// forma de decir «sigue donde estaba». Mandarlos sería darle a esta función el
/// poder de mover una fila de grado —incluso a «todos los grados»—, que es
/// justo la puerta de atrás que el permiso del backend vigila con dos
/// comprobaciones, la del alcance viejo y la del nuevo.
///
/// **[tipo] en null borra la marca**, no la deja como estaba: es lo que quiere
/// la hoja de editar cuando alguien vacía ese campo.
Future<ResultadoDeUnaCompetencia> editarCompetencia(
  Server server, {
  required int id,
  required String definicion,
  String? tipo,
}) async {
  return _escribir(
    () => server.put('/desempenos/$id', {
      'definicion': definicion,
      'tipo': tipo,
    }),
    accion: 'guardar',
  );
}

/// La manda a la papelera. Devuelve null si entró, o el motivo si no.
///
/// Es un borrado lógico, pero **no es un borrado de ayer**: con el modelo plano
/// el boletín lee el catálogo vivo al imprimir, así que la línea desaparece de
/// todo lo que se imprima desde ahora, también de periodos ya cerrados del mismo
/// año. Va aceptado a sabiendas en §3 del contrato del backend, y conviene que
/// lo sepa quien escriba el aviso de confirmación.
///
/// Contesta `{"id": …}` y no la fila, así que quien llama la quita de su lista.
Future<String?> borrarCompetencia(Server server, {required int id}) async {
  try {
    final res = await server.delete('/desempenos/$id');
    return _motivoDelRechazo(res, respaldo: 'No se pudo borrar.');
  } catch (err) {
    return 'No se pudo borrar: $err';
  }
}

/// Lo que dejó una copia, contado por el servidor.
///
/// **Los tres desenlaces de un 200 no se pueden contar igual**, y por eso esto
/// no es un booleano: «no había nada allí», «ya las tenías todas» y «se
/// trajeron cuatro» son tres respuestas distintas a la misma pulsación, y las
/// dos primeras dan `copiados: 0`. Aplanarlas en «no se copió nada» deja al
/// docente sin saber si se equivocó de periodo o si ya estaba hecho.
class CopiaDelPlan {
  const CopiaDelPlan({
    this.revisados = 0,
    this.copiados = 0,
    this.saltadosPorDuplicado = 0,
    this.origenVacio = false,
  });

  /// Cuántas filas tenía el origen.
  final int revisados;

  /// Cuántas se escribieron.
  final int copiados;

  /// Cuántas ya estaban en el destino, comparando el texto **normalizado**:
  /// el servidor baja a minúsculas, quita acentos y aprieta los espacios, así
  /// que «Interpreta gráficas» y «interpreta graficas» son la misma.
  final int saltadosPorDuplicado;

  /// Si el origen no tenía ni una fila.
  ///
  /// **Llega como `saltadas_sin_catalogo` y su nombre miente**: no es un
  /// recuento sino una bandera, `$candidatos === [] ? 1 : 0`. Se lee como lo
  /// que es para que nadie la sume con las otras.
  final bool origenVacio;

  factory CopiaDelPlan.fromJson(Map<String, dynamic> json) {
    return CopiaDelPlan(
      revisados: enteroO(json['revisados']),
      copiados: enteroO(json['copiados']),
      saltadosPorDuplicado: enteroO(json['saltados_por_duplicado']),
      origenVacio: enteroO(json['saltadas_sin_catalogo']) > 0,
    );
  }
}

/// Lo que devuelve copiar.
class ResultadoDeCopia {
  const ResultadoDeCopia({this.copia, this.motivo});

  final CopiaDelPlan? copia;
  final String? motivo;

  bool get entro => motivo == null;
}

/// Trae a esta clase el plan que ya está escrito en otro sitio.
///
/// `PUT desempenos/copiar`. El **destino** es siempre una clase de este año:
/// su materia, su grado y **el periodo en el que se está**. El **origen** es
/// una de dos, y son excluyentes:
///
///  - [desdePeriodoId] — otro periodo de este mismo año;
///  - [desdeYearId] — el periodo del mismo número de otro año.
///
/// ## Por qué el destino es siempre el periodo de la barra, y no uno a elegir
///
/// **Ahí está la trampa de esta entrega, y se esquiva en vez de resolverse.**
/// `exigirEscrituraDelPlan` comprueba `profes_pueden_editar_notas` **del
/// periodo en el que se escribe**, y lo único que la app tiene a mano —en
/// `ConfiguracionColegio`— es la bandera del periodo de la sesión. Dejar
/// elegir el periodo destino obligaría a traerse antes la suya, o a pintar un
/// botón contra la bandera equivocada y que el 403 lo explique después.
///
/// Con el destino fijado en el periodo actual, la bandera que la app tiene
/// **es** la del periodo en el que se escribe, y la pregunta desaparece. Y no
/// se pierde nada real: lo que se hace es «tráeme lo del periodo pasado»
/// estando en el nuevo, no colocar filas en un periodo que no se está mirando.
///
/// ## Copiando de otro año, el periodo NO viaja, y eso es a propósito
///
/// Los ids de `periodos` son **por año y disjuntos**, así que mandar el
/// `periodo_id` del destino como origen no casa ninguna fila del otro año: el
/// servidor contesta **200 con `copiados: 0`**, que no se distingue de «el año
/// pasado no tenía nada escrito». Omitiéndolo, el backend lo resuelve **por
/// número de periodo** y, si ese año no tiene ese número, contesta un 422 que
/// lo dice.
///
/// No es un caso de laboratorio: el front web escribió justo ese cuerpo y midió
/// las dos formas —0 copiadas con el malo, 2 y 3 con el bueno, sobre las mismas
/// filas—. Está contado en `DesempenosController::putCopiarPlantilla`.
///
/// ## Lo que no se ofrece
///
/// El backend admite un tercer origen —`origen.tipo: 'grado'` con
/// `origen.grado_id`, o sea traer de **otro grado**— y la app no lo pinta:
/// `Profesor::asignaturas` **no manda el nombre del grado**, así que esa lista
/// saldría con los grados sin nombre y nadie sabría cuál está eligiendo. El día
/// que el nombre llegue, es añadir una sección a la hoja.
///
/// Los 422 que se esperan van con el texto del servidor: el origen y el destino
/// son el mismo grupo, el año de origen no tiene ese número de periodo, o el
/// año no existe.
Future<ResultadoDeCopia> copiarCompetencias(
  Server server, {
  required int materiaId,
  required int? gradoId,
  required int periodoId,
  int? desdePeriodoId,
  int? desdeYearId,
}) async {
  assert((desdePeriodoId == null) != (desdeYearId == null),
      'El origen es uno: o un periodo de este año, o otro año.');
  assert(desdePeriodoId != periodoId,
      'Copiar un grupo sobre sí mismo es un 422: no se ofrece.');

  try {
    final res = await server.put('/desempenos/copiar', {
      'destino': {
        'materia_id': materiaId,
        'grado_id': gradoId,
        'periodo_id': periodoId,
      },
      'origen': {
        'tipo': desdeYearId != null ? 'year' : 'grado',
        if (desdeYearId != null) 'year_id': desdeYearId,
        // Del mismo año se nombra el periodo; de otro año **no**, para que lo
        // resuelva por número. Ver arriba.
        if (desdePeriodoId != null) 'periodo_id': desdePeriodoId,
      },
    });

    final motivo =
        _motivoDelRechazo(res, respaldo: 'No se pudo traer el plan.');
    if (motivo != null) return ResultadoDeCopia(motivo: motivo);

    final cuerpo = jsonDecode(res.body);
    if (cuerpo is! Map) {
      return const ResultadoDeCopia(
        motivo: 'El servidor contestó algo que no se entiende.',
      );
    }

    return ResultadoDeCopia(
      copia: CopiaDelPlan.fromJson(Map<String, dynamic>.from(cuerpo)),
    );
  } catch (err) {
    return ResultadoDeCopia(motivo: 'No se pudo traer el plan: $err');
  }
}

Future<ResultadoDeUnaCompetencia> _escribir(
  Future<dynamic> Function() peticion, {
  required String accion,
}) async {
  try {
    final res = await peticion();

    final motivo = _motivoDelRechazo(res, respaldo: 'No se pudo $accion.');
    if (motivo != null) return ResultadoDeUnaCompetencia(motivo: motivo);

    final cuerpo = jsonDecode(res.body);
    if (cuerpo is! Map) {
      return ResultadoDeUnaCompetencia(
        motivo: 'El servidor contestó algo que no se entiende.',
      );
    }

    return ResultadoDeUnaCompetencia(
      competencia: Competencia.fromJson(Map<String, dynamic>.from(cuerpo)),
    );
  } catch (err) {
    return ResultadoDeUnaCompetencia(motivo: 'No se pudo $accion: $err');
  }
}

/// El motivo de un rechazo, o null si la respuesta entró.
///
/// **Los códigos de aquí explican poco y los textos explican todo**, así que se
/// enseña el del servidor siempre que quepa en un aviso:
///
///  - **403** son dos cosas distintas con el mismo número: «No tiene permiso
///    para escribir el plan de área de esa materia y ese grado» —la fila es de
///    otro, o es del colegio— y «El periodo está cerrado: no se puede escribir
///    en él». La primera no se arregla; la segunda se pide al coordinador. Con
///    un texto propio se pierde justo la mitad que sirve;
///  - **422** es el cuerpo: qué campo falta, qué no cabe y en cuántos
///    caracteres;
///  - **404** es una fila que ya no está —otro la borró, o es de otro año—.
///
/// El recorte de [loQueDijoElServidor] —160 caracteres y sin saltos de línea—
/// es lo que evita que un volcado de excepción acabe en un `SnackBar`.
String? _motivoDelRechazo(dynamic res, {required String respaldo}) {
  final int codigo = res.statusCode;

  if (codigo < 300) return null;
  if (codigo == 403 || codigo == 404 || codigo == 422) {
    return motivoDeRechazo(res.body, respaldo: respaldo);
  }
  return 'El servidor respondió $codigo.';
}
