import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// Lo que el día de matrículas manda a la app.
///
/// **Nada de aquí lleva un nombre ni un número de estación cableado.** Es la
/// regla de `docs/estaciones.md` §2.8: una sola app para dieciséis colegios,
/// cada uno con su recorrido, sus nombres y su número de pasos. Un colegio
/// llamará «Académico» a lo que otro llama «Coordinación», y esta app **no
/// tiene opinión**: pinta lo que le manden.
///
/// Los enteros se leen con [enteroO] y no con `as int` porque los listados del
/// backend salen de `DB::select`, y ahí **PDO decide el tipo**: el mismo campo
/// llega `int` en una ruta y `String` en otra.

/// Cuántas notas hay en un paso, y cuántas piden algo.
///
/// Viaja **dentro** de la cola y de la ficha, nunca en una llamada aparte. Una
/// pantalla que preguntara «¿y notas?» alumno por alumno no dibujaría la cola:
/// la dibujaría cuatro segundos después, en un patio con mala señal.
class NotasDelPaso {
  const NotasDelPaso({
    this.total = 0,
    this.pendientes = 0,
    this.reservadas = 0,
  });

  final int total;
  final int pendientes;

  /// Las que cuentan para el globo y **no enseñan su texto**.
  ///
  /// Orientación tiene notas que solo ven orientación y rectoría. Que el número
  /// las incluya es una decisión, no un descuido: **esconder que una nota existe
  /// es peor que esconder su contenido** —quien ve el globo y no puede abrirlo
  /// sabe a quién preguntarle; quien no ve nada, no pregunta—.
  final int reservadas;

  factory NotasDelPaso.fromJson(dynamic json) {
    if (json is! Map) return const NotasDelPaso();
    return NotasDelPaso(
      total: enteroO(json['total']),
      pendientes: enteroO(json['pendientes']),
      reservadas: enteroO(json['reservadas']),
    );
  }

  bool get hayAlgo => total > 0;

  /// Ámbar si algo pide acción, pizarra si solo hay algo escrito.
  bool get algoSinResolver => pendientes > 0;

  /// La misma información en palabras, que es lo que se lee de verdad con sol
  /// en la cara. El número del globo nunca va solo.
  String enPalabras(String nombreDeLaEstacion) {
    if (!hayAlgo) return '';
    final cuantas = total == 1 ? '1 nota' : '$total notas';
    if (pendientes == 0) return '$cuantas en $nombreDeLaEstacion';
    final sin =
        pendientes == 1 ? 'una sin resolver' : '$pendientes sin resolver';
    return '$cuantas en $nombreDeLaEstacion, $sin';
  }
}

/// Una estación del recorrido: su número impreso en la cartulina y su nombre.
///
/// ## Aquí NO hay sitio ni dueño, y las dos ausencias son del contrato de verdad
///
/// Leído campo por campo el `getIndex` de
/// `8myvc/app/Http/Controllers/Matriculas/EstacionesController.php:174-183`
/// (20 sep 2026), una estación son siete claves: `nro`, `nombre`,
/// `descripcion`, `bloquea`, `requisitos`, `esperando` y `puedo_atender`. Ni
/// una más.
///
/// - **`donde` se quitó el 20 sep 2026 porque no existe.** La maqueta pintaba
///   «Aula 101» y este modelo leía `json['donde']`. La **única** clave `donde`
///   de todo el controlador es el **nombre de la estación de DESTINO** al
///   devolver o reenviar a alguien —líneas 586, 1165 y 1306—, que es otra cosa:
///   no es dónde está una estación, es a cuál tiene que ir la familia. Leído
///   como ubicación, ese renglón salía vacío en los dieciséis colegios **sin
///   que nada fallara**, que es la forma cara de equivocarse. Donde sí hace
///   falta ese `donde` es en `si_no`, y ahí se lee (ver
///   `FichaDeEstacion._primerObligatorioSinCerrar`).
/// - **Quién la atiende tampoco viaja, y se quitó el mismo día.** Se leía
///   `rol` / `quien_atiende` y el servidor no manda ninguno de los dos:
///   `mi_estacion` va en `null` a propósito y `editable_por_profe_id` **no la
///   escribe nadie** —0 filas medidas, y `YearsController` la excluye al copiar
///   un año—. Desde el 20 sep cierra cualquiera del personal firmando con su
///   nombre, así que **la estación no tiene dueño**: pintar uno era inventarlo.
///
/// Lo que el servidor sí manda por estación es [descripcion], y se lee con su
/// nombre y no con el del campo que no existe.
class Estacion {
  const Estacion({
    required this.nro,
    required this.nombre,
    this.descripcion,
    this.bloquea = false,
    this.esperando = 0,
  });

  /// El número que la familia ve impreso. **Es `requisitos_matricula.orden`**,
  /// que ya existía: el paso 3 se atiende en la estación 3, así que no hizo
  /// falta una columna nueva.
  final int nro;

  final String nombre;

  /// Lo que el colegio escribió sobre este paso. **No es una ubicación.**
  ///
  /// Es `requisitos_matricula.descripcion`, la misma casilla que la pantalla
  /// vieja de requisitos lleva años guardando al lado del nombre —en las
  /// pruebas del backend trae cosas como «Ampliada al 150%»—: o sea **una
  /// instrucción sobre el papel que se entrega**, no un aula. Se pinta tal cual
  /// y con su nombre; renombrarla a «donde» habría convertido «Ampliada al
  /// 150%» en la dirección de una estación.
  ///
  /// Y viaja la del **primer** requisito del grupo
  /// (`EstacionesController::recorrido`, líneas 762-790): una estación de dos
  /// papeles enseña la del primero y calla la del segundo. Por eso es un
  /// renglón de ayuda y nunca algo que decida nada.
  final String? descripcion;

  /// Si este paso frena el recorrido o solo informa.
  ///
  /// Nace apagado en el servidor a propósito: un colegio que actualiza no puede
  /// encontrarse el lunes con un recorrido que frena donde antes no frenaba.
  final bool bloquea;

  final int esperando;

  factory Estacion.fromJson(Map<String, dynamic> json) => Estacion(
        nro: enteroO(json['nro']),
        nombre: texto(json['nombre']) ?? 'Estación ${enteroO(json['nro'])}',
        descripcion: _sinBlancos(json['descripcion']),
        bloquea: _verdad(json['bloquea']),
        esperando: enteroO(json['esperando']),
      );
}

/// Alguien que está en la fila de una estación.
class PersonaEnCola {
  const PersonaEnCola({
    required this.id,
    required this.nombres,
    required this.apellidos,
    this.grupo,
    this.documento,
    this.fotoNombre,
    this.esAspirante = false,
    this.llegoAt,
    this.devueltoAntes = false,
    this.notasTotal = 0,
    this.notasPendientes = 0,
  });

  final int id;
  final String nombres;
  final String apellidos;
  final String? grupo;

  /// El documento de identidad, **para desempatar dos nombres iguales**.
  ///
  /// La cola lo manda desde el primer día (`getCola`, línea 253, y también la
  /// ficha) y este modelo no lo leía. No es un dato decorativo: en una fila
  /// puede haber dos hermanos apellidados igual, o dos primos que se llaman
  /// como el abuelo, y hasta que llegue [fotoNombre] **esto es lo único que
  /// distingue a uno del otro sin preguntar en voz alta delante de la fila**.
  ///
  /// Por eso la tarjeta lo enseña **solo cuando hace falta** —cuando otro de la
  /// lista tiene el mismo nombre completo—: un documento debajo de cada nombre
  /// es un dato personal pintado en la pantalla de alguien que está de pie en
  /// un patio, y sin empate no distingue nada.
  final String? documento;

  /// El nombre del archivo de la foto. **Hoy llega siempre null, y está pedido.**
  ///
  /// `getCola` (`EstacionesController.php:249-260`, leído el 20 sep 2026) manda
  /// `alumno_id`, `nombres`, `apellidos`, `documento`, `grupo`, `llego_at`,
  /// `devuelto_antes`, `avisos`, `notas_total` y `notas_pendientes`. **Ni
  /// `foto_nombre` ni `foto_id`**, y no se inventan aquí: un campo que la app
  /// lee y el servidor no escribe es el error que este mismo módulo acaba de
  /// pagar con `donde`.
  ///
  /// **Por qué importa y por qué se pide en vez de darlo por perdido:** en una
  /// fila con dos hermanos apellidados igual, con el mismo grupo y un
  /// documento que quien atiende no se sabe de memoria, **la cara es lo que
  /// distingue**. Las iniciales del avatar dan «M. C.» para los dos. La
  /// consulta ya pasa por `alumnos`, así que añadir `a.foto_nombre` al `SELECT`
  /// de `datosDeLosAlumnos` (línea 1046) es una columna más en una consulta que
  /// ya se hace — no una ruta nueva ni una petición por persona.
  ///
  /// Mientras tanto la tarjeta cae en iniciales **y enseña el documento cuando
  /// dos nombres coinciden**, que es el desempate que sí se puede hacer hoy.
  final String? fotoNombre;

  /// Un aspirante nuevo todavía no es alumno, y su id no sale de la misma
  /// tabla. La pantalla lo dice porque cambia lo que la familia trae en la mano.
  ///
  /// **Hoy no lo manda nadie, y eso está decidido, no pendiente**: la migración
  /// `2026_09_20_700000_las_estaciones_en_la_app.php` descarta `aspirante_id`
  /// con la medición escrita —una fila de `ordenes_inscripcion` en modo
  /// `nuevos` **no tiene nombre ni apellidos**, así que una cola de aspirantes
  /// serían renglones en blanco—. Se conserva la rama porque el camino queda
  /// abierto para cuando el portal de la familia capture esos datos.
  final bool esAspirante;

  /// Cuándo entró en esta cola, **tal como lo manda el servidor**: `llego_at`.
  ///
  /// Es una marca de tiempo (`Y-m-d H:i:s`, hora de Bogotá), no una frase. El
  /// texto lo arma [llegoHace] en el teléfono; ver ahí por qué.
  final String? llegoAt;

  final bool devueltoAntes;
  final int notasTotal;
  final int notasPendientes;

  /// «hace 2 min», calculado en la app a partir de [llegoAt].
  ///
  /// **Este modelo leía `llego_hace` y ese campo no existe.** `getCola` manda
  /// `llego_at` (línea 255) y nada más, así que el renglón de la derecha de
  /// cada tarjeta —el que dice quién lleva más rato de pie— **salía vacío en
  /// los dieciséis colegios sin que nada fallara**.
  ///
  /// Es un getter y no un campo a propósito: la cola se repinta cada veinte
  /// segundos con el sondeo de la huella, y así el «hace 2 min» envejece con
  /// ella en vez de quedarse congelado en el momento del `fromJson`.
  String? get llegoHace => haceCuanto(llegoAt);

  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// El nombre con el que se busca un empate en la fila. Ver
  /// [losNombresQueSeRepiten].
  String get claveDelNombre => nombreCompleto.toLowerCase();

  bool get tieneNotas => notasTotal > 0;

  factory PersonaEnCola.fromJson(Map<String, dynamic> json) {
    // La cola manda `alumno_id`; la **ficha** manda la fila de `alumnos` tal
    // cual, o sea `id` (`EstacionesController.php:1185`). Sin la segunda, la
    // persona de la ficha entraba con id 0 —y por tanto marcada como
    // aspirante—, que es un renglón que no lleva a ninguna parte.
    final deLaCola = enteroO(json['alumno_id']);
    final deLaFicha = enteroO(json['id']);
    final aspirante = enteroO(json['aspirante_id']);

    return PersonaEnCola(
      id: deLaCola != 0
          ? deLaCola
          : deLaFicha != 0
              ? deLaFicha
              : aspirante,
      nombres: texto(json['nombres']) ?? '',
      apellidos: texto(json['apellidos']) ?? '',
      grupo: texto(json['grupo']),
      documento: _sinBlancos(json['documento']),
      fotoNombre: texto(json['foto_nombre']),
      esAspirante: deLaCola == 0 && deLaFicha == 0 && aspirante != 0,
      llegoAt: texto(json['llego_at']),
      devueltoAntes: _verdad(json['devuelto_antes']),
      notasTotal: enteroO(json['notas_total']),
      notasPendientes: enteroO(json['notas_pendientes']),
    );
  }
}

/// Los nombres completos que aparecen **más de una vez** en una fila.
///
/// ## Es el desempate que sí se puede hacer hoy
///
/// La cola **no manda foto** —ni `foto_nombre` ni `foto_id`, comprobado campo
/// por campo en `getCola` el 20 sep 2026—, así que dos hermanos apellidados
/// igual salen con el mismo círculo de iniciales, el mismo grupo y el mismo
/// nombre: **dos renglones idénticos**. Quien atiende abre el primero y le
/// marca el paso a la otra, y eso no se descubre hasta que la familia vuelve.
///
/// Lo que la cola sí manda es `documento`, y la tarjeta lo enseña **solo en los
/// renglones que empatan**: debajo de cada nombre sería un dato personal
/// repartido por una pantalla que se mira de pie en un patio, y donde no hay
/// empate no distingue nada.
///
/// Vive aquí y no dentro de la pantalla para que se pueda probar: es una regla,
/// no un adorno.
Set<String> losNombresQueSeRepiten(List<PersonaEnCola> cola) {
  final vistos = <String>{};
  final repetidos = <String>{};

  for (final persona in cola) {
    if (!vistos.add(persona.claveDelNombre)) {
      repetidos.add(persona.claveDelNombre);
    }
  }

  return repetidos;
}

/// Una cosa concreta que hay que entregar o comprobar en un paso.
///
/// «Registro civil», «certificado de notas del año anterior». Lo que el colegio
/// escribió en `requisitos_matricula`, que existía desde antes de todo esto.
class Requisito {
  const Requisito({
    required this.id,
    required this.nombre,
    required this.estado,
    this.obligatorio = true,
    this.detalle,
  });

  final int id;
  final String nombre;
  final EstadoDelPaso estado;

  /// Si frena el paso o solo informa.
  ///
  /// **Joseth lo colapsó a un solo interruptor el 20 sep**: «obligatoria antes
  /// de continuar u opcional». El plan del front separaba *obligatorio* de
  /// *bloqueante* —la entrevista de orientación es lo primero y no lo segundo—
  /// y esa distinción se perdió a propósito. Queda dicho aquí y no re-litigado.
  final bool obligatorio;

  /// «Subido por la familia · 12 oct», «recibido en físico · por ti, hace 1 min».
  final String? detalle;

  /// **`bloquea` primero, y `obligatorio` solo de respaldo.**
  ///
  /// El contrato manda `bloquea` por requisito (`EstacionesController.php:1151`)
  /// y **`obligatorio` no viaja**: el propio controlador lo dice en el docblock
  /// de `getAlumno` —«publicar los dos campos con el mismo valor invitaría a la
  /// app a distinguir dos cosas que aquí son una»—. Leyendo solo `obligatorio`,
  /// todos los requisitos salían obligatorios y el botón de cerrar se apagaba
  /// por un carné de vacunas que el colegio marcó como opcional.
  ///
  /// El respaldo se queda porque `getRecorrido` es otra ruta y otro nombre, y
  /// porque una app vieja convive meses con un servidor nuevo.
  factory Requisito.fromJson(Map<String, dynamic> json) => Requisito(
        id: enteroO(json['id']),
        nombre: texto(json['requisito']) ?? texto(json['nombre']) ?? '',
        estado: EstadoDelPaso.deTexto(texto(json['estado'])),
        obligatorio: _verdad(
          json['bloquea'] ?? json['obligatorio'],
          siFalta: true,
        ),
        // `observacion` es como se llama en la ficha (línea 1154): es
        // `requisitos_alumno.descripcion`, o sea lo que escribió el personal
        // sobre ESTE papel de ESTA persona.
        detalle: texto(json['observacion']) ??
            texto(json['detalle']) ??
            texto(json['descripcion']),
      );
}

/// Un paso del recorrido de una persona concreta.
class PasoDelRecorrido {
  const PasoDelRecorrido({
    required this.nro,
    required this.nombre,
    required this.estado,
    this.cerradoPor,
    this.cerradoAt,
    this.motivo,
    this.obligatorio = true,
    this.notas = const NotasDelPaso(),
    this.requisitos = const [],
  });

  final int nro;
  final String nombre;
  final EstadoDelPaso estado;

  /// Quién lo chuleó, con su nombre. **No es `updated_by`**: ése cambia cada vez
  /// que alguien toca la fila —una observación, una tilde— y al final del día
  /// dice quién pasó por aquí el último, no quién cerró.
  final String? cerradoPor;

  /// Cuándo se cerró, **tal cual lo manda el servidor**: `cerrado_at`.
  ///
  /// Es una marca de tiempo de MySQL, no una frase. Guardarla cruda y convertir
  /// al pintar es lo que impide el renglón que había antes —«Cerrado por Nancy
  /// Ariza · 2026-09-20 14:32:00»—, que es una fecha de base de datos enseñada
  /// a un docente de pie en un patio.
  final String? cerradoAt;

  /// «hace 10 min», calculado en la app a partir de [cerradoAt].
  ///
  /// **Este modelo leía `cerrado_hace` y ese campo no existe en ninguna de las
  /// nueve rutas.** La ficha manda `cerrado_at` (línea 1174) y `getRecorrido`
  /// también, así que el renglón salía vacío en un sitio y con la marca cruda
  /// en el otro. Ver [haceCuanto] para qué pasa cuando el reloj del teléfono
  /// va mal.
  String? get cerradoHace => haceCuanto(cerradoAt);

  /// Por qué se devolvió. **Lo lee la familia, tal cual**, así que no es un
  /// comentario entre el personal: eso son las notas, y van aparte.
  final String? motivo;

  final bool obligatorio;
  final NotasDelPaso notas;

  /// Lo que hay que entregar en este paso. Puede venir vacío.
  final List<Requisito> requisitos;

  /// Cuántos obligatorios quedan sin cumplir.
  ///
  /// Es lo que decide si el botón de cerrar se enciende. **Los opcionales nunca
  /// lo apagan**, que es la mitad de para qué existe el interruptor.
  int get obligatoriosQueFaltan => requisitos
      .where((r) => r.obligatorio && r.estado != EstadoDelPaso.cumplido)
      .length;

  factory PasoDelRecorrido.fromJson(Map<String, dynamic> json) {
    final crudos = json['requisitos'];
    final requisitos = <Requisito>[];
    if (crudos is List) {
      for (final uno in crudos) {
        if (uno is Map) {
          requisitos.add(Requisito.fromJson(Map<String, dynamic>.from(uno)));
        }
      }
    }

    return PasoDelRecorrido(
      nro: enteroO(json['nro']),
      nombre: texto(json['nombre']) ?? 'Paso ${enteroO(json['nro'])}',
      estado: EstadoDelPaso.deTexto(texto(json['estado'])),
      cerradoPor: texto(json['cerrado_por']),
      cerradoAt: texto(json['cerrado_at']) ?? texto(json['cerrado_hace']),
      motivo: texto(json['motivo']),
      // `bloquea` es como se llama en la ficha; ver el porqué en
      // `Requisito.fromJson`, que tiene el mismo caso y el mismo respaldo.
      obligatorio: _verdad(
        json['bloquea'] ?? json['obligatorio'],
        siFalta: true,
      ),
      notas: NotasDelPaso.fromJson(json['notas']),
      requisitos: requisitos,
    );
  }
}

/// La ficha de una persona vista desde una estación.
class FichaDeEstacion {
  const FichaDeEstacion({
    required this.persona,
    required this.pasos,
    this.codigo,
    this.acudiente,
    this.telefonoAcudiente,
    this.leFalta,
  });

  final PersonaEnCola persona;

  /// Los N pasos del colegio, en orden. **Todos**, no solo el que se atiende:
  /// quien atiende Documentos tiene que poder ver que Tesorería escribió algo
  /// en la 5 antes de mandar a la familia a hacer cuatro colas.
  final List<PasoDelRecorrido> pasos;

  /// El código de la hoja de ruta, el mismo del formulario de inscripción.
  final String? codigo;

  /// A quién llamar, ya con nombre y apellidos pegados.
  ///
  /// **El servidor manda `acudiente` como un OBJETO, no como un texto**
  /// —`{id, nombres, apellidos, celular, telefono}`, `acudienteDe()` en la
  /// línea 1262—, y este modelo lo leía con `texto(...)`. En Dart eso no falla:
  /// devuelve el `toString` del mapa, así que el renglón del teléfono de la
  /// ficha habría pintado `{id: 4, nombres: Ana, apellidos: Gómez, celular:
  /// 300…}` al lado de un icono de teléfono. Se arma aquí, una vez, y no en la
  /// pantalla.
  final String? acudiente;

  /// El número al que se llama. **`telefono_acudiente` no existe**: el celular
  /// y el fijo vienen dentro del objeto de arriba, y se prefiere el celular
  /// porque el día de matrículas la familia está en la calle, no en su casa.
  final String? telefonoAcudiente;

  /// Si llegó salteado, qué paso le falta. Null si viene en orden.
  ///
  /// Lo dice la pantalla, no el profesor: hoy eso depende de que quien atiende
  /// mire bien la hoja, y con fila detrás no mira.
  final PasoDelRecorrido? leFalta;

  factory FichaDeEstacion.fromJson(Map<String, dynamic> json) {
    final crudos = json['pasos'];
    final pasos = <PasoDelRecorrido>[];
    if (crudos is List) {
      for (final uno in crudos) {
        if (uno is Map) {
          pasos.add(PasoDelRecorrido.fromJson(Map<String, dynamic>.from(uno)));
        }
      }
    }

    final persona = json['persona'];

    return FichaDeEstacion(
      persona: PersonaEnCola.fromJson(
        persona is Map ? Map<String, dynamic>.from(persona) : const {},
      ),
      pasos: pasos,
      codigo: texto(json['codigo']),
      acudiente: _nombreDelAcudiente(json['acudiente']),
      telefonoAcudiente: _telefonoDelAcudiente(json['acudiente']) ??
          _sinBlancos(json['telefono_acudiente']),
      leFalta: _primerObligatorioSinCerrar(pasos, json),
    );
  }

  /// El nombre del acudiente, venga como objeto o como texto.
  ///
  /// Las dos formas se aceptan porque cuestan tres líneas y porque **una app
  /// vieja convive meses con un servidor nuevo**: si mañana alguien aplana el
  /// campo, esto no se entera.
  static String? _nombreDelAcudiente(dynamic crudo) {
    if (crudo is Map) {
      final nombre = [
        texto(crudo['nombres']) ?? '',
        texto(crudo['apellidos']) ?? '',
      ].join(' ').trim();
      return nombre.isEmpty ? null : nombre;
    }
    return _sinBlancos(crudo);
  }

  static String? _telefonoDelAcudiente(dynamic crudo) {
    if (crudo is! Map) return null;
    return _sinBlancos(crudo['celular']) ?? _sinBlancos(crudo['telefono']);
  }

  /// Cuántas notas hay en todo el recorrido, de cualquier estación.
  NotasDelPaso get notasDeTodoElRecorrido => NotasDelPaso(
        total: pasos.fold(0, (suma, p) => suma + p.notas.total),
        pendientes: pasos.fold(0, (suma, p) => suma + p.notas.pendientes),
        reservadas: pasos.fold(0, (suma, p) => suma + p.notas.reservadas),
      );

  static PasoDelRecorrido? _primerObligatorioSinCerrar(
    List<PasoDelRecorrido> pasos,
    Map<String, dynamic> json,
  ) {
    // Si el servidor ya lo dijo, mandan sus palabras: sabe qué estación bloquea
    // y esta app no tiene por qué deducirlo.
    final dicho = json['si_no'];
    if (dicho is Map && enteroO(dicho['devolver_a_nro']) != 0) {
      return PasoDelRecorrido(
        nro: enteroO(dicho['devolver_a_nro']),
        // **Aquí `donde` SÍ existe, y es el único sitio donde existe**
        // (`EstacionesController.php:1165`): es el nombre de la estación a la
        // que hay que devolver a la familia. Se leía `nombre`, que no viaja en
        // `si_no`, así que la banda del salteado decía «Le falta la Estación 3
        // · Estación 3» en vez de «· Recepción».
        nombre: texto(dicho['donde']) ??
            texto(dicho['nombre']) ??
            'Estación ${enteroO(dicho['devolver_a_nro'])}',
        estado: EstadoDelPaso.pendiente,
      );
    }
    return null;
  }
}

/// «hace 2 min», «hace 1 h 10 min» — a partir de la marca que manda el servidor.
///
/// ## Esto se calcula en el teléfono porque el servidor NO manda la frase
///
/// El modelo leía `llego_hace` y `cerrado_hace`, y **ninguno de los dos existe
/// en las nueve rutas**: `getCola` manda `llego_at` y la ficha manda
/// `cerrado_at` (`EstacionesController.php:255` y `:1174`, leídas el 20 sep
/// 2026), las dos marcas de MySQL en `Y-m-d H:i:s`. O sea que el «hace 2 min»
/// de la cola **no salía nunca** y el «cerrado» del recorrido salía en crudo:
/// «2026-09-20 14:32:00», que es una fila de base de datos enseñada a un
/// docente con una familia delante.
///
/// ## Y EL RELOJ DEL TELÉFONO DEL PATIO NO ES UNA FUENTE DE VERDAD
///
/// Ésa es la razón por la que la frase la armaba el servidor, y **no
/// desaparece porque la cuenta se mude aquí**: la marca la pone el servidor en
/// hora de Bogotá y la resta la hace un teléfono que puede ir cinco minutos
/// adelantado, o con la fecha de fábrica después de quedarse sin batería.
///
/// Por eso la cuenta **se desconfía a sí misma**: si sale negativa —la marca
/// está en el futuro— o pasa de 24 horas, no se enseña ninguna frase relativa,
/// se enseña **la hora tal cual**. «a las 14:35» es verdad aunque el reloj vaya
/// mal; «hace -3 min» es una mentira y además delata que algo está roto sin
/// decir qué. Las 24 horas son el corte porque el día de matrículas es un día:
/// una marca de anteayer en una cola de hoy es un dato raro, y se enseña con su
/// fecha en vez de como «hace 41 h».
///
/// Devuelve null si no hay marca o no se puede leer, y entonces la pantalla no
/// pinta nada — que es mejor que pintar un hueco con guiones.
String? haceCuanto(String? marca, {DateTime? ahora}) {
  final cuando = _marcaDeTiempo(marca);
  if (cuando == null) return null;

  final reloj = ahora ?? DateTime.now();
  final diferencia = reloj.difference(cuando);

  if (diferencia.isNegative || diferencia.inHours >= 24) {
    return _laHoraTalCual(cuando, reloj);
  }

  if (diferencia.inMinutes < 1) return 'hace menos de 1 min';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';

  final horas = diferencia.inHours;
  final minutos = diferencia.inMinutes - horas * 60;
  return minutos == 0 ? 'hace $horas h' : 'hace $horas h $minutos min';
}

/// La marca de MySQL, leída como hora local.
///
/// El servidor la escribe con `Carbon::now('America/Bogota')` y la manda **sin
/// zona**: `2026-09-20 14:32:00`. Se lee como hora local a propósito, que es lo
/// correcto para los dieciséis colegios —todos en Colombia, sin horario de
/// verano—. Si algún día llegara con `Z` o con desfase, `DateTime.parse` lo
/// marca como UTC y aquí se pasa a local en vez de restar cinco horas de más.
DateTime? _marcaDeTiempo(String? marca) {
  final crudo = marca?.trim();
  if (crudo == null || crudo.isEmpty) return null;

  final leida = DateTime.tryParse(crudo);
  if (leida == null) return null;
  return leida.isUtc ? leida.toLocal() : leida;
}

String? _laHoraTalCual(DateTime cuando, DateTime reloj) {
  final hora = '${_dosCifras(cuando.hour)}:${_dosCifras(cuando.minute)}';

  final mismoDia = cuando.year == reloj.year &&
      cuando.month == reloj.month &&
      cuando.day == reloj.day;

  if (mismoDia) return 'a las $hora';
  return '${_dosCifras(cuando.day)}/${_dosCifras(cuando.month)} $hora';
}

String _dosCifras(int numero) => numero.toString().padLeft(2, '0');

/// El texto sin espacios de sobra, y null si no queda nada.
///
/// `texto()` ya devuelve null cuando la clave no vino, pero el backend manda
/// cadenas vacías de verdad —la pantalla vieja de requisitos guarda
/// `descripcion = ''`— y un `''` que llega hasta la pantalla se convierte en un
/// renglón en blanco con su separador al lado.
String? _sinBlancos(dynamic valor) {
  final crudo = texto(valor)?.trim();
  return (crudo == null || crudo.isEmpty) ? null : crudo;
}

/// Un booleano que puede llegar como `1`, `"1"`, `true` o `"true"`.
///
/// Es la misma razón que [enteroO]: `DB::select` devuelve lo que PDO decida, y
/// un `tinyint` llega unas veces entero y otras cadena.
bool _verdad(dynamic valor, {bool siFalta = false}) {
  if (valor == null) return siFalta;
  if (valor is bool) return valor;
  final crudo = '$valor'.trim().toLowerCase();
  if (crudo.isEmpty) return siFalta;
  return crudo == '1' || crudo == 'true' || crudo == 'si' || crudo == 'sí';
}

/// Alguien encontrado buscando en todo el colegio, no solo en una cola.
///
/// Sale de `PUT buscar/por-nombre` y `por-apellido`, que llevan desplegadas
/// desde mucho antes que nada de esto. **La forma la manda ese endpoint viejo**
/// y no el contrato nuevo, así que los nombres de clave son los suyos.
class PersonaEncontrada {
  const PersonaEncontrada({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.fotoNombre,
    this.grupo,
    this.noMatricula,
    this.estadoMatricula,
  });

  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? fotoNombre;
  final String? grupo;
  final String? noMatricula;

  /// El estado de la MATRÍCULA, que no es el de un requisito.
  ///
  /// Se llaman igual —`estado`— y vienen de tablas distintas: éste sale de
  /// `matriculas.estado` y el otro de `requisitos_alumno.estado`. Llevan nombre
  /// distinto aquí para que nadie los cruce.
  final String? estadoMatricula;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory PersonaEncontrada.fromJson(Map<String, dynamic> json) =>
      PersonaEncontrada(
        alumnoId: enteroO(json['alumno_id']),
        nombres: texto(json['nombres']) ?? '',
        apellidos: texto(json['apellidos']) ?? '',
        fotoNombre: texto(json['foto_nombre']),
        grupo: texto(json['nombre_grupo']) ?? texto(json['abrev_grupo']),
        noMatricula: texto(json['no_matricula']),
        estadoMatricula: texto(json['estado']),
      );
}

/// El recorrido de matrícula de una persona: los N pasos, con quién y cuándo.
///
/// Sale de `GET requisitos/recorrido/{alumno_id}`, entregada el 20 sep 2026.
/// **No es de las ocho rutas del contrato de estaciones**, así que esta pantalla
/// puede encenderse mucho antes que el resto del módulo.
class RecorridoDeMatricula {
  const RecorridoDeMatricula({
    required this.pasos,
    this.nombres,
    this.apellidos,
    this.documento,
    this.devolverALaEstacion,
  });

  final List<PasoDelRecorrido> pasos;
  final String? nombres;
  final String? apellidos;
  final String? documento;

  /// A qué estación hay que devolverlo, si el servidor lo dice.
  final int? devolverALaEstacion;

  int get cerrados =>
      pasos.where((p) => p.estado != EstadoDelPaso.pendiente).length;

  /// Los que frenan y todavía no están. Son los que importan de verdad.
  List<PasoDelRecorrido> get loQueFrena => pasos
      .where((p) => p.obligatorio && p.estado == EstadoDelPaso.pendiente)
      .toList();

  factory RecorridoDeMatricula.fromJson(dynamic json) {
    // El endpoint puede contestar la lista pelada o un objeto con `pasos`
    // dentro. Se aceptan las dos formas en vez de suponer una: la ruta se
    // entregó hoy y su envoltorio es lo único que podría moverse.
    final crudos = json is Map ? json['pasos'] : json;
    final alumno = json is Map ? json['alumno'] : null;

    final pasos = <PasoDelRecorrido>[];
    if (crudos is List) {
      for (final uno in crudos) {
        if (uno is Map) {
          pasos.add(_pasoDelRecorridoViejo(Map<String, dynamic>.from(uno)));
        }
      }
    }

    return RecorridoDeMatricula(
      pasos: pasos,
      nombres: alumno is Map ? texto(alumno['nombres']) : null,
      apellidos: alumno is Map ? texto(alumno['apellidos']) : null,
      documento: alumno is Map ? texto(alumno['documento']) : null,
      devolverALaEstacion: json is Map ? entero(json['devolver_a']) : null,
    );
  }
}

/// Un paso tal como lo manda `getRecorrido`, que usa otros nombres de clave.
///
/// `estacion` en vez de `nro`, `requisito` en vez de `nombre`, y **manda
/// `marca_id`**: si es null, nadie ha tocado ese requisito todavía. Esa columna
/// es la que distingue «no está» de «no se ha mirado», y por eso viaja hasta
/// [EstadoDelPaso.deTexto].
PasoDelRecorrido _pasoDelRecorridoViejo(Map<String, dynamic> json) {
  final quien = [
    texto(json['cerrado_por_nombres']) ?? '',
    texto(json['cerrado_por_apellidos']) ?? '',
  ].join(' ').trim();

  return PasoDelRecorrido(
    nro: enteroO(json['estacion']),
    nombre: texto(json['requisito']) ?? 'Paso ${enteroO(json['estacion'])}',
    estado: EstadoDelPaso.deTexto(
      texto(json['estado']),
      hayMarca: json['marca_id'] != null,
    ),
    cerradoPor: quien.isEmpty ? null : quien,
    // Cruda, como llega: la frase la arma [haceCuanto] al pintar. Aquí es donde
    // se veía el fallo a simple vista —el recorrido enseñaba «Cerrado por Nancy
    // Ariza · 2026-09-20 14:32:00»—.
    cerradoAt: texto(json['cerrado_at']),
    motivo: texto(json['observacion']),
    obligatorio: _verdad(json['bloquea'], siFalta: true),
  );
}
