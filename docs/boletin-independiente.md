# El boletín independiente — lo que esta app tiene que hacer

**Tarea pendiente, no trabajo hecho.** El backend ya lo tiene escrito y fusionado;
esta app **no sabe nada de esto todavía**, y eso se comprueba en un comando:

```bash
grep -rn "bol_independiente\|independientes" lib --include="*.dart"
# 1 sep 2026: cero apariciones que hablen de esto.
```

Escrito el **1 de septiembre de 2026** desde `~/DESARROLLOS/8myvc` con el módulo
recién terminado allí. El plan del backend, que es la fuente y **no se copia
aquí**, vive en `~/DESARROLLOS/8myvc/docs/migracion/19-boletin-independiente.md`.

---

## 1. Qué es, en una frase

**Un alumno puede llevar, en un periodo, un boletín con SU propia estructura de
unidades y subunidades**, distinta de la del resto del curso. Se usa con alumnos
que llegan a mitad de año, con adaptaciones, o con planes distintos al del grupo.

Dos cosas que cambian todo lo demás y conviene leer juntas:

- **La marca es por periodo, no por año.** Un alumno puede ir aparte en el
  periodo 2 y con el grupo en el 1, el 3 y el 4.
- **Marcar no borra nada.** Las notas que tenía en las subunidades del grupo se
  quedan donde están; simplemente dejan de usarse mientras la marca esté puesta.

## 2. Por qué le toca a esta app, y por qué es peor que en el front

`myvc_front` es **una copia por colegio**: un colegio actualiza y los demás
siguen como estaban. **Esta app es UNA sola para los quince**, y el despliegue
del backend va **colegio a colegio a lo largo de días**.

**O sea que durante esos días la misma app va a hablar con colegios que tienen el
código nuevo y con colegios que tienen el viejo, y tiene que estar bien con los
dos.** No es un detalle de compatibilidad: es la condición de entrada de todo lo
que sigue.

## 3. Lo que va a cambiar en las respuestas — medido, no supuesto

Los campos son **añadidos**: ninguna clave de hoy desaparece. Lo que sí cambia de
verdad es **quién viene en una lista**.

### 3.1 · `PUT notas/detailed` deja de traer a los marcados en `alumnos`

Es el cambio que muerde, y **la app no se rompe: enseña menos y no lo dice**.
[`LibroNotasApi`](../lib/Http/LibroNotasApi.dart) lee `alumnos` y nada más, así
que en un colegio ya desplegado un alumno marcado **desaparece de la planilla sin
ningún error**. El docente no ve un fallo: ve una planilla que parece completa.

La respuesta trae, para eso, un campo nuevo:

```jsonc
"independientes": [ { "alumno_id": 4711, "nombres": "…", "apellidos": "…" } ]
```

**Es «a quién NO estás viendo».** Y tiene una propiedad que conviene usar, porque
es la única forma limpia de saber contra qué backend estás hablando:

| `independientes` | Qué significa |
|---|---|
| **ausente** (la clave no viene) | **colegio sin desplegar todavía.** Nada que decir: la planilla de hoy es correcta |
| **`[]`** | desplegado, y **nadie va aparte** en este grupo y periodo |
| **con elementos** | desplegado, y **ésos no están en tu lista** |

**Ausente y vacío no son lo mismo**, y tratarlos igual es lo que haría que la app
callara justo donde tiene que hablar.

### 3.2 · `alumno.bol_independiente_datos` — el badge

`true` = este alumno **tiene un boletín aparte guardado en este periodo**, aunque
este periodo vaya con el grupo. Viene **dentro de `alumnos`**, o sea en gente que
sí está en la planilla.

Sirve para no asustar al docente cuando vea notas que no cuadran con lo que
recuerda: hay datos guardados que ahora mismo no se están usando.

### 3.3 · `POST /unidades` acepta `alumno_id`, y **contesta 422** si el alumno no va aparte

[`UnidadesApi`](../lib/Http/UnidadesApi.dart) hoy crea unidades **sin**
`alumno_id`, y eso **sigue siendo correcto**: son las del grupo. No hay que tocar
nada para que siga funcionando.

Lo que hay que saber antes de mandar ese campo algún día:

- **con `alumno_id` de un alumno marcado** → la unidad es **suya**;
- **con `alumno_id` de un alumno que NO está marcado en ese periodo** → **422**.
  No es un capricho: una unidad con dueño para quien va con el grupo **no le
  cuenta a nadie** y nacería muerta y en silencio;
- **sin `alumno_id`** → del grupo, como hoy.

### 3.4 · Los puestos vienen a `null`

Si el colegio tiene apagado el interruptor `puestos_con_bol_independiente`, el
puesto del alumno marcado viaja como **`null`**. **Se pinta `—`, no `0` y no
«sin puesto»**: no es que haya quedado último, es que no entra en esa
comparación.

### 3.5 · Los boletines rotulan la asignatura

`asignatura.bol_independiente: true` en los boletines. **En pantalla, no
impreso**, y **el rótulo no se inventa en el cliente**: si el campo no viene, no
se pinta nada.

## 4. La decisión que falta, y es de Joseth

**Qué hace la app con un alumno que va aparte.** Hay dos salidas y ninguna es
obviamente mejor:

| | Qué implica |
|---|---|
| **A · Ocultarlo y decirlo** | La planilla enseña sólo a los del grupo y añade una línea: *«2 alumnos llevan boletín aparte este periodo y no aparecen aquí»*, con sus nombres. **Es lo que ya hace el backend**, y la app sólo tiene que contarlo. **No permite ponerles nota desde la app.** |
| **B · Enseñarlo con aviso** | Los marcados aparecen con su propia estructura. Es una segunda planilla dentro de la pantalla, con sus unidades y subunidades distintas de las del resto — **es trabajo de verdad**, no un rótulo. |

**Mientras no se decida, A es lo que hay que escribir de todas formas**, porque
sin ella la app calla. B se puede construir encima después.

**Y la consecuencia práctica de A, dicha entera:** en un colegio desplegado, el
docente **no podrá ponerle notas desde la app** a un alumno marcado — tendrá que
hacerlo desde el navegador. Eso es lo que hay que decir en la pantalla, no
dejarlo para que lo descubra.

## 5. El riesgo que no avisa de ninguna forma

Un alumno **marcado y sin ni una unidad propia** tiene su definitiva en **0** y su
boletín **en blanco**, y nadie recibe un error: la consulta no falla, devuelve
cero filas, y cero filas se leen como cero.

Con la app en la salida A **ese alumno no aparece por ningún lado**: ni en la
planilla, ni en la línea de arriba con un problema. **Sale en la lista de
`independientes` como uno más.** Lo único que puede verlo en el servidor es
`tools/independientes-sin-estructura.php`, que se corre el día del despliegue.

**No hace falta que la app lo detecte** —no tiene con qué—, pero sí que **no
prometa** que un alumno de esa lista está bien atendido.

## 6. Cuándo se puede publicar

**No antes de que el backend esté DESPLEGADO en los quince**, no fusionado. Y con
la lección que ya está escrita en [backend-pendiente.md](backend-pendiente.md):
**«desplegado» se comprueba contra el hash de la tanda, no contra `main`.**

Estado del backend el 1 sep 2026: **fusionado en `main` (`1cb7092`), sin subir y
sin desplegar**. Las tres rutas nuevas son `PUT boletin-independiente/periodo`,
`PUT boletin-independiente/planilla` y `POST boletin-independiente/copiar`.

**Y el despliegue lleva migraciones bloqueantes**: en un colegio con el código
nuevo y la base sin migrar, **los tres boletines contestan 500**. Eso es del lado
del servidor y no de esta app, pero explica por qué la tanda va colegio a colegio
y por qué el periodo de convivencia entre las dos formas existe.

## 7. Lo que NO hay que hacer

- **No publicar la pantalla antes del despliegue.** En un colegio sin desplegar,
  `independientes` no viene y la app no debe inventarse nada.
- **No inventar el rótulo del boletín en el cliente.** Si el campo no viene, no
  se pinta.
- **No tratar `[]` como «no soportado».** Es la respuesta de un colegio
  desplegado sin nadie marcado, y confundirlas apaga el aviso justo donde ya
  funciona.
- **No pintar `0` donde el puesto es `null`.**
