import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// El recorrido de matrícula **tal como lo ve la familia**.
///
/// ## POR QUÉ ESTO NO REUTILIZA `PasoDelRecorrido`
///
/// Porque no es lo mismo con menos campos: es otra cosa. `getRecorrido` —el del
/// personal— manda `estado` como texto libre, `marca_id`, `observacion` y quién
/// cerró cada paso, y la app tiene que interpretarlo. `getMiRecorrido` manda
/// **`cumplido` y `devuelto` ya resueltos** y no manda ninguno de los otros.
///
/// El servidor lo dejó escrito al separar los dos métodos: *«un `if ($esFamilia)`
/// dentro del otro habría puesto las dos respuestas en un solo sitio, y el día
/// que alguien añada un campo tendría que acordarse de que hay un lector que no
/// puede verlo»*. **Si aquí se reutilizara el modelo del personal, esa
/// separación se desharía en el cliente**: un campo nuevo tendría un hueco donde
/// caer y alguien acabaría rellenándolo.
///
/// ## Y `cumplido` NO SE RECALCULA AQUÍ
///
/// El servidor lo calcula como `marca_id != null && cerrado_at != null`, **no
/// desde `estado`**, y el motivo está escrito allí: `estado` lo escriben tres
/// pantallas con tres vocabularios y `cerrado_at` lo escribe una sola rama de
/// código. Esta app ya se quemó con eso —`falta` contra `Falta`—, así que aquí
/// se lee el booleano y no se vuelve a deducir. Deducirlo otra vez sería tener
/// dos verdades y esperar que coincidan.
class MiRecorrido {
  const MiRecorrido({
    required this.alumno,
    required this.pasos,
    required this.faltan,
    required this.completo,
  });

  final AlumnoDeMiRecorrido alumno;
  final List<PasoDeMiRecorrido> pasos;

  /// Cuántos pasos quedan por cerrar, **contados por el servidor**.
  final int faltan;

  /// `true` cuando no falta ninguno. Viene calculado, no se deduce de [faltan]:
  /// si algún día dejaran de coincidir, el que manda es el servidor.
  final bool completo;

  /// Los que fueron devueltos y todavía no se han vuelto a cerrar.
  ///
  /// Es lo primero que hay que enseñar: un paso devuelto es el único que pide
  /// que la familia **haga algo**, y el motivo dice qué.
  List<PasoDeMiRecorrido> get devueltos =>
      pasos.where((p) => p.devuelto).toList();

  factory MiRecorrido.fromJson(Map<String, dynamic> json) {
    final crudos = json['pasos'];
    final pasos = <PasoDeMiRecorrido>[];

    if (crudos is List) {
      for (final crudo in crudos) {
        if (crudo is Map<String, dynamic>) {
          pasos.add(PasoDeMiRecorrido.fromJson(crudo));
        }
      }
    }

    final alumno = json['alumno'];

    return MiRecorrido(
      alumno: AlumnoDeMiRecorrido.fromJson(
        alumno is Map<String, dynamic> ? alumno : const {},
      ),
      pasos: pasos,
      faltan: enteroO(json['faltan']),
      // Sin la clave, se prefiere «no está completo»: enseñarle a una familia
      // que ya terminó cuando no ha terminado la manda a su casa.
      completo: json['completo'] == true,
    );
  }
}

/// Quién es, y nada más.
///
/// **Sin documento y sin teléfonos, y eso es del servidor.** Lo dejó escrito al
/// construir la respuesta: *«quien pregunta ya sabe quién es, y ésta no tiene
/// por qué ser un sitio más donde vive el documento de un menor»*.
class AlumnoDeMiRecorrido {
  const AlumnoDeMiRecorrido({
    required this.id,
    required this.nombres,
    required this.apellidos,
  });

  final int id;
  final String nombres;
  final String apellidos;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory AlumnoDeMiRecorrido.fromJson(Map<String, dynamic> json) {
    return AlumnoDeMiRecorrido(
      id: enteroO(json['id']),
      nombres: texto(json['nombres']) ?? '',
      apellidos: texto(json['apellidos']) ?? '',
    );
  }
}

/// Un paso del recorrido, con lo único que el colegio le escribe a la familia.
class PasoDeMiRecorrido {
  const PasoDeMiRecorrido({
    required this.estacion,
    required this.requisito,
    required this.descripcion,
    required this.bloquea,
    required this.cumplido,
    required this.devuelto,
    required this.motivoDevolucion,
    required this.cerradoAt,
  });

  /// El orden dentro del recorrido: 1, 2, 3…
  final int estacion;

  /// Cómo se llama el paso. «Tesorería», «Documentos».
  final String requisito;

  /// **Qué le piden.** Sale de `requisitos_matricula.descripcion`.
  ///
  /// ⚠️ **Ojo con el nombre**, que es la trampa de este contrato:
  /// `requisitos_matricula` y `requisitos_alumno` **tienen las dos una columna
  /// `descripcion`**. Ésta es la del requisito —la que le dice a la familia qué
  /// tiene que llevar—. La otra es la **observación interna del personal**, que
  /// en la ruta del personal viaja con el alias `observacion` y **aquí no
  /// viaja**. No son intercambiables y confundirlas enseñaría a una madre una
  /// nota escrita entre docentes.
  final String? descripcion;

  /// Si este paso frena la matrícula o solo la acompaña.
  final bool bloquea;

  /// Ya está cerrado. **Calculado por el servidor**, ver [MiRecorrido].
  final bool cumplido;

  /// Se lo devolvieron y hay algo que hacer.
  final bool devuelto;

  /// **Lo único que el colegio le escribe a la familia en todo el recorrido.**
  ///
  /// Sin esto, «devuelto» es una mala noticia sin instrucciones. Por eso se
  /// escribió en su propia columna: para poder salir por aquí sin arrastrar la
  /// observación interna.
  final String? motivoDevolucion;

  /// Cruda, como la manda el servidor. La frase la arma la pantalla al pintar.
  final String? cerradoAt;

  /// Nadie lo ha tocado todavía: ni cerrado ni devuelto.
  bool get pendiente => !cumplido && !devuelto;

  factory PasoDeMiRecorrido.fromJson(Map<String, dynamic> json) {
    return PasoDeMiRecorrido(
      estacion: enteroO(json['estacion']),
      // Un paso sin nombre sale con su número antes que en blanco: un renglón
      // vacío en una lista de ocho no se puede señalar con el dedo.
      requisito:
          texto(json['requisito']) ?? 'Paso ${enteroO(json['estacion'])}',
      descripcion: texto(json['descripcion']),
      // `bloquea` viaja como bool desde el servidor, pero `DB::select` devuelve
      // lo que PDO decida y esta app ya se quemó una vez leyendo `1` como si
      // fuera `true` solo en algunas rutas. Se lee ancho a propósito.
      bloquea: _siNoEsFalso(json['bloquea']),
      cumplido: _siNoEsFalso(json['cumplido'], siFalta: false),
      devuelto: _siNoEsFalso(json['devuelto'], siFalta: false),
      motivoDevolucion: texto(json['motivo_devolucion']),
      cerradoAt: texto(json['cerrado_at']),
    );
  }
}

/// Lee un booleano que puede llegar como `true`, `1`, `'1'` o `'true'`.
///
/// [siFalta] decide qué pasa cuando la clave no viene. Para `bloquea` es `true`
/// —lo prudente es dar por obligatorio lo que no se sabe— y para `cumplido` y
/// `devuelto` es `false`, por lo contrario: dar por hecho un paso que nadie ha
/// confirmado mandaría a una familia a su casa creyendo que terminó.
bool _siNoEsFalso(dynamic crudo, {bool siFalta = true}) {
  if (crudo == null) return siFalta;
  if (crudo is bool) return crudo;
  if (crudo is num) return crudo != 0;

  final comoTexto = crudo.toString().trim().toLowerCase();
  if (comoTexto.isEmpty) return siFalta;
  return comoTexto != '0' && comoTexto != 'false';
}
