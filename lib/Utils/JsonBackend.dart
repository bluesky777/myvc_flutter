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

/// El texto, o null si no vino. Nunca la cadena 'null'.
String? texto(dynamic valor) {
  if (valor == null) return null;
  final crudo = valor.toString();
  return crudo.isEmpty ? null : crudo;
}
