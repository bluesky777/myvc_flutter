/// Lecturas tolerantes del JSON del backend.
///
/// Las columnas numéricas no llegan siempre con el mismo tipo. La razón está en
/// el servidor: los listados —/asistencias/detailed, /grupos, /contratos— se
/// arman con `DB::select` y SQL a pelo, sin modelos ni casts, de modo que el
/// tipo de cada columna lo decide el driver de PDO y no el código. Un `COUNT(*)`
/// puede llegar como número o como cadena según cómo esté configurada la
/// conexión, y lo mismo un id.
///
/// Antes cada modelo hacía `parsedJson['alumno_id']` a secas: bastaba con que
/// una fila trajera una cadena donde se esperaba un número para que reventara
/// el parseo entero y el docente viera «Ocurrió un error trayendo los alumnos»
/// en lugar de sus cuarenta alumnos.
library;

/// El valor como entero, o null si no hay forma de leerlo así.
int? entero(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is bool) return valor ? 1 : 0;
  return int.tryParse(valor.toString().trim());
}

/// El valor como entero, con un valor de respaldo si no se puede leer.
///
/// Para los campos que el modelo declara obligatorios: más vale un id 0 que
/// una excepción que tumba la lista entera.
int enteroO(dynamic valor, [int respaldo = 0]) => entero(valor) ?? respaldo;

/// Un mapa de contadores, saltándose lo que no sea legible como número.
///
/// Vacío si la clave no vino: es lo que pasa con `ausencias_total` cuando el
/// alumno no tiene ninguna falta.
Map<String, int> mapaDeEnteros(dynamic valor) {
  if (valor is! Map) return {};

  final resultado = <String, int>{};
  valor.forEach((clave, dato) {
    final numero = entero(dato);
    if (numero != null) resultado['$clave'] = numero;
  });
  return resultado;
}

/// El valor como decimal, con respaldo. Mismo motivo que [enteroO]: un
/// porcentaje calculado en SQL puede llegar `double`, `int` o `String` según la
/// conexión, y los tres son el mismo número.
double decimalO(dynamic valor, [double respaldo = 0]) {
  if (valor == null) return respaldo;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.')) ??
      respaldo;
}

/// Un booleano del backend, que casi nunca es un booleano.
///
/// Las columnas de interruptor son `tinyint(1)`, así que llegan **0 o 1**; y
/// según salgan por Eloquent o por `DB::select` pueden llegar como número o
/// como cadena. Devuelve null cuando **el servidor no lo dijo**, que es distinto
/// de que dijera que no: esa diferencia es la que deja que una app vieja hable
/// con un servidor nuevo sin inventarse la respuesta que falta.
///
/// **Y hay un caso que motivó tenerlo aquí**: `candidatos/conaspiraciones`
/// devolvía `votado: []` hasta el 22 de septiembre de 2026, y `[]` en JavaScript
/// es cierto — el front web llevaba años creyendo que estaba todo votado. Una
/// lectura que no se cree el tipo es lo que evita repetir eso en Dart.
bool? siONo(dynamic valor) {
  if (valor == null) return null;
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;

  final crudo = '$valor'.trim().toLowerCase();
  if (crudo.isEmpty || crudo == 'null') return null;

  return crudo == '1' || crudo == 'true' || crudo == 'si' || crudo == 'sí';
}

/// El texto, o null si no vino. Nunca la cadena 'null'.
String? texto(dynamic valor) {
  if (valor == null) return null;
  final crudo = valor.toString();
  return crudo.isEmpty ? null : crudo;
}
