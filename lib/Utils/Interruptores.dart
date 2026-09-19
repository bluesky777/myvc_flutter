/// Lo que está escrito en la app pero todavía no se puede encender.
///
/// **Por qué existe este archivo, que es lo que hay que entender antes de tocar
/// un valor de aquí.** El backend vive en `app/`, que es **una copia por
/// colegio**, y `myvc_flutter` es **una sola app para todos**. O sea que entre
/// que un endpoint nuevo se fusiona y está en todos los servidores hay una
/// ventana en la que existe para unos colegios y no para otros — y en esa
/// ventana la app es la misma para todos.
///
/// ## La condición NO lleva un número, y eso se aprendió por las malas
///
/// Aquí ponía **«los quince»**, con su fecha y su porqué, y **estuvo mal desde
/// el 30 de agosto de 2026**: ese día entró `lal` —montado en la otra cuenta de
/// cPanel, `lalvirtual.edu.co`— y volvieron a ser **dieciséis**. Antes habían
/// sido dieciséis, luego quince durante cinco días por una baja, y luego
/// dieciséis otra vez. Lo levantó la sesión de la API el 19 sep 2026 y se
/// comprobó desde aquí en `8myvc/docs/DESPLIEGUE.md:966` y `:143`: **el bucle de
/// despliegue devuelve 17 carpetas — dieciséis colegios y `demo`**.
///
/// **Así que el número se quita de la condición.** Un recuento escrito en un
/// docblock envejece en silencio y **falla del lado peligroso**: quien verifique
/// «los quince» habiendo dieciséis enciende un interruptor con un colegio sin
/// desplegar, y el fallo le sale a ése en la pantalla que usa todos los días.
/// La condición buena es **«todos los que recorre el bucle de despliegue»**, que
/// no hay que mantener al día porque se lee del servidor cada vez.
///
/// Y ojo con la segunda cuenta: el `for` de `micolev1` **no alcanza a `lal`**.
/// Un despliegue que sólo corra ese bucle deja un colegio atrás sin avisar.
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
/// 1. Que el endpoint esté **desplegado en todos los colegios** —los que
///    devuelve el bucle, las dos cuentas de cPanel incluidas—. No fusionado en
///    el backend: desplegado. Es la única condición, y no se puede comprobar
///    desde la app.
///
///    Y «desplegado» se comprueba por el **hash de la tanda**, no por `main`:
///    lo que corre es el commit que Joseth verificó igual en todos, y `main` va
///    por delante. La pregunta no es «¿está en `main`?» sino «¿el commit que
///    trae esto es ancestro del hash desplegado?».
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
  /// **Encendido el 26 de agosto de 2026.** La ruta entró en el backend con el
  /// commit `83bf717` (23 ago), que es ancestro de `eb95cbc`, la tanda que
  /// Joseth desplegó el 25 ago **con el mismo hash en todos** (quince ese día:
  /// `lal` entró el 30 ago). Y
  /// `git diff eb95cbc HEAD` no toca ni una línea de `getMisFichas`, así que lo
  /// que corre es lo mismo que se leyó para escribir esto.
  ///
  /// Ver docs/backend-pendiente.md §2 y docs/disciplina.md → «La ficha del
  /// alumno y del acudiente».
  static const bool disciplinaMisFichas = true;

  /// La pantalla «Mis competencias» del docente, del modelo plano por
  /// competencias. Ver `docs/competencias.md`.
  ///
  /// **Lo que espera no es una ruta: son dos columnas.** La pantalla agrupa las
  /// asignaturas del docente en pares (materia, grado) —porque el plan de área
  /// se escribe por ahí y no por asignatura— y para eso necesita `materia_id` y
  /// `grado_id`, que `asignaturas/listasignaturas` **no manda todavía**.
  ///
  /// Están escritas en el backend desde el 19 sep 2026 —`fe95da8`, rama
  /// `feat/materia-id-y-grado-id-en-asignaturas`, con el gemelo de
  /// `PiarsAsignaturasController` tocado en el mismo commit— pero **sin fundir a
  /// `main` y sin desplegar**, que son dos pasos más y los da Joseth.
  ///
  /// **Sin ellas la pantalla no sale vacía: sale diciendo que no las tiene.**
  /// `clasesDelDocente` cuenta aparte las asignaturas que no puede resolver, y
  /// eso es a propósito — una lista vacía y «tu colegio aún no tiene esto» se
  /// leen igual, y no son lo mismo.
  ///
  /// Las siete rutas de `desempenos/` tampoco están desplegadas: están en `main`
  /// de `8myvc` (`8329718`). O sea que este interruptor espera a **dos** cosas,
  /// y las dos se comprueban por el hash de la tanda.
  static const bool competenciasDocente = false;
}
