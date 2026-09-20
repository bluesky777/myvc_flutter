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
class Estacion {
  const Estacion({
    required this.nro,
    required this.nombre,
    this.donde,
    this.quienLaAtiende,
    this.bloquea = false,
    this.esperando = 0,
  });

  /// El número que la familia ve impreso. **Es `requisitos_matricula.orden`**,
  /// que ya existía: el paso 3 se atiende en la estación 3, así que no hizo
  /// falta una columna nueva.
  final int nro;

  final String nombre;

  /// Dónde está: «Aula 101», «Portería». Puede no venir.
  final String? donde;

  /// Quién suele atenderla. **Es información, no un permiso.**
  ///
  /// Desde el 20 sep 2026 **cierra cualquiera del personal**, firmado con su
  /// nombre y su hora. Esto sirve para saber a quién buscar, no para cerrar una
  /// puerta: la maqueta original pintaba un candado aquí y ese candado ya no
  /// existe. Ver `docs/estaciones.md` §2.9.
  final String? quienLaAtiende;

  /// Si este paso frena el recorrido o solo informa.
  ///
  /// Nace apagado en el servidor a propósito: un colegio que actualiza no puede
  /// encontrarse el lunes con un recorrido que frena donde antes no frenaba.
  final bool bloquea;

  final int esperando;

  factory Estacion.fromJson(Map<String, dynamic> json) => Estacion(
        nro: enteroO(json['nro']),
        nombre: texto(json['nombre']) ?? 'Estación ${enteroO(json['nro'])}',
        donde: texto(json['donde']),
        quienLaAtiende: texto(json['rol']) ?? texto(json['quien_atiende']),
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
    this.fotoNombre,
    this.esAspirante = false,
    this.llegoHace,
    this.devueltoAntes = false,
    this.notasTotal = 0,
    this.notasPendientes = 0,
  });

  final int id;
  final String nombres;
  final String apellidos;
  final String? grupo;
  final String? fotoNombre;

  /// Un aspirante nuevo todavía no es alumno, y su id no sale de la misma
  /// tabla. La pantalla lo dice porque cambia lo que la familia trae en la mano.
  final bool esAspirante;

  /// «hace 2 min». Lo calcula el servidor: el reloj del teléfono de un docente
  /// en el patio no es una fuente de verdad.
  final String? llegoHace;

  final bool devueltoAntes;
  final int notasTotal;
  final int notasPendientes;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  bool get tieneNotas => notasTotal > 0;

  factory PersonaEnCola.fromJson(Map<String, dynamic> json) => PersonaEnCola(
        id: enteroO(json['alumno_id']) != 0
            ? enteroO(json['alumno_id'])
            : enteroO(json['aspirante_id']),
        nombres: texto(json['nombres']) ?? '',
        apellidos: texto(json['apellidos']) ?? '',
        grupo: texto(json['grupo']),
        fotoNombre: texto(json['foto_nombre']),
        esAspirante: enteroO(json['alumno_id']) == 0,
        llegoHace: texto(json['llego_hace']),
        devueltoAntes: _verdad(json['devuelto_antes']),
        notasTotal: enteroO(json['notas_total']),
        notasPendientes: enteroO(json['notas_pendientes']),
      );
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

  factory Requisito.fromJson(Map<String, dynamic> json) => Requisito(
        id: enteroO(json['id']),
        nombre: texto(json['requisito']) ?? texto(json['nombre']) ?? '',
        estado: EstadoDelPaso.deTexto(texto(json['estado'])),
        obligatorio: _verdad(json['obligatorio'], siFalta: true),
        detalle: texto(json['detalle']) ?? texto(json['descripcion']),
      );
}

/// Un paso del recorrido de una persona concreta.
class PasoDelRecorrido {
  const PasoDelRecorrido({
    required this.nro,
    required this.nombre,
    required this.estado,
    this.cerradoPor,
    this.cerradoHace,
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

  final String? cerradoHace;

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
      cerradoHace: texto(json['cerrado_hace']),
      motivo: texto(json['motivo']),
      obligatorio: _verdad(json['obligatorio'], siFalta: true),
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

  final String? acudiente;
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
      acudiente: texto(json['acudiente']),
      telefonoAcudiente: texto(json['telefono_acudiente']),
      leFalta: _primerObligatorioSinCerrar(pasos, json),
    );
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
        nombre: texto(dicho['nombre']) ?? 'Estación ${dicho['devolver_a_nro']}',
        estado: EstadoDelPaso.pendiente,
      );
    }
    return null;
  }
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
    cerradoHace: texto(json['cerrado_at']),
    motivo: texto(json['observacion']),
    obligatorio: _verdad(json['bloquea'], siFalta: true),
  );
}
