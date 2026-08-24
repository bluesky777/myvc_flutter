/// Lo que está escrito en la app pero todavía no se puede encender.
///
/// **Por qué existe este archivo, que es lo que hay que entender antes de tocar
/// un valor de aquí.** El backend vive en `app/`, que es **una copia por
/// colegio**, y `myvc_flutter` es **una sola app para los dieciséis**. O sea que
/// entre que un endpoint nuevo se fusiona y está en los dieciséis servidores hay
/// una ventana en la que existe para unos colegios y no para otros — y en esa
/// ventana la app es la misma para todos.
///
/// Llamar «a ver si está» es la respuesta equivocada: gasta un 404 antes de caer
/// al camino viejo, y multiplicado por los colegios que aún no lo tengan es
/// exactamente la carga que este proyecto lleva un año evitando en un hosting
/// compartido.
///
/// Así que el camino viejo sigue siendo el que corre, el nuevo queda escrito y
/// probado, y **encenderlo es cambiar un `false` por un `true` aquí**.
///
/// ## Cómo se enciende uno
///
/// 1. Que el endpoint esté **desplegado en los dieciséis colegios**. No
///    fusionado en el backend: desplegado. Es la única condición, y no se puede
///    comprobar desde la app.
/// 2. Cambiar el valor aquí.
/// 3. Publicar la app.
///
/// Los tres pasos, en ese orden. Encender antes del despliegue rompe a los
/// colegios que van rezagados, y para ellos el fallo sale en la pantalla que
/// usan todos los días.
class Interruptores {
  Interruptores._();

  /// Guardar una columna de notas con `PUT notas/lote` en vez de una a una.
  ///
  /// Lo que ahorra **no son las peticiones**: cada `notas/update` llama al
  /// recalculador, que agrega **todas** las notas de la asignatura y el periodo
  /// y sólo después se queda con un alumno. Una columna de treinta notas son
  /// treinta agregados de la asignatura entera, veintinueve para tirarlos. El
  /// lote recalcula **una vez** por par (asignatura, periodo).
  ///
  /// Ver docs/backend-pendiente.md §1.
  static const bool notasLote = false;

  /// La ficha de disciplina para el alumno y el acudiente,
  /// con `GET disciplina/mis-fichas`.
  ///
  /// Ver docs/backend-pendiente.md §2 y docs/disciplina.md → «Lo que queda
  /// pendiente».
  static const bool disciplinaMisFichas = false;
}
