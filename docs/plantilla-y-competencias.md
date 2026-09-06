# Plantilla de notas y competencias — lo que le toca a la app

> El diseño completo está en el backend:
> `8myvc/docs/migracion/28-competencias-e-indicadores.md`. Aquí sólo está lo que
> cambia en `myvc_flutter`.
>
> **Estado: propuesta. El backend no existe todavía.** Nada de esto se escribe
> hasta que las rutas estén desplegadas en los dieciséis colegios.

---

## 0. La regla que manda sobre todo lo demás

**Esta app es una sola para los dieciséis colegios, y una versión vieja convive con
el backend nuevo durante meses.** Por eso:

- Todo lo nuevo llega en **rutas nuevas** y en **campos opcionales**. Ninguna
  bandera sobre un endpoint que ya existe.
- Una versión de la app que **no sepa** de `numero_periodo`, de competencias ni de
  indicadores tiene que seguir viendo **exactamente la rejilla de siempre**. Eso lo
  garantiza el backend, pero se comprueba desde aquí: es la lección de
  `22-nivelaciones.md` §6.1, y allí el precio de olvidarla era un 95 guardado como
  70 sin un error.
- Los modelos ya toleran campos que no vienen (`enteroO`, `decimalO`,
  `SubunidadModel` acepta `id` y `subunidad_id`). Los campos nuevos entran por ahí,
  con su valor por defecto, y **no se hacen `required`**.

---

## 1. Lo que NO cambia

`UnidadesScreen.dart` (1189 líneas), `UnidadesApi.dart`, `UnidadModel.dart`,
`PlanillaScreen.dart` y `NotasScreen.dart` **siguen funcionando igual**. La plantilla
del colegio siembra filas en las mismas tablas de siempre: el docente sigue viendo
unidades y subunidades, con los mismos ids y los mismos porcentajes.

La regla que documenta `SubunidadModel` —*«los porcentajes de las subunidades de una
unidad tienen que sumar 100»*— **no cambia**, y la fórmula de la definitiva tampoco.

---

## 2. Lo que NO se construye aquí

**La pantalla de configuración de la plantilla no se hace en la app.** Es trabajo del
colegio —del rector o del coordinador, con un permiso nuevo
(`can_edit_plantilla_notas`)— y se hace en la web, donde ya está el resto de la
configuración del año: escalas, frases, periodos. Meterla aquí sería poner la
pantalla más peligrosa del sistema (`plantilla-notas/sembrar` reescribe la rejilla
del colegio entero) en el sitio donde se toca con el pulgar.

Lo mismo con el catálogo de competencias e indicadores: se escriben en la web.

---

## 3. Lo que sí le toca a la app

### 3.1 · La plantilla es por año: nada que hacer *(Entrega 1)*

Joseth decidió el 2 sep 2026 que **las unidades con sus porcentajes y las subunidades
se establecen para el año**, los dos niveles. Una versión anterior de este documento
avisaba de una columna `numero_periodo` que iba a hacer que la rejilla cambiara entre
periodos: **esa columna se retiró con la decisión**, y en la app no hay nada que
comprobar. La rejilla sigue llegando como hoy.

### 3.1.bis · El estudiante con boletín independiente llega con rejilla *(Entrega 4)*

Hoy, un estudiante marcado como independiente aparece con la rejilla **vacía** hasta
que alguien se la monta a mano desde la web. Con la Entrega 4, marcarlo la siembra
desde la plantilla del año.

Para la app eso no es un endpoint nuevo: es que **la pantalla de notas de ese
estudiante deja de salir vacía**. Lo que sí conviene comprobar es que `PlanillaScreen`
y `NotasScreen` no tengan ningún camino que dé por hecho que un independiente no tiene
unidades — un `if (unidades.isEmpty)` con un mensaje de «no configurado» que ahora
sería falso.

### 3.2 · Competencias en el boletín y en la ficha *(Entrega 2)*

Las competencias son **texto por asignatura, sin nota**. Salen encima de las
unidades en:

- `FichaAlumnoNotasScreen.dart` — donde el acudiente y el alumno ven sus notas.
- `LibroAsignaturaScreen.dart`, si el colegio quiere que el docente las tenga a
  mano.

Llegan en la respuesta que ya se pide, como lista opcional. **Si no vienen, no se
pinta nada** — que es lo que va a pasar en todos los años pasados y en todos los
colegios que no enciendan `show_competencias_bol`.

`ColegioModel` / `ConfiguracionColegio.dart` tienen que leer ese interruptor nuevo
con **`false` por defecto**, igual que los demás.

### 3.2.bis · El año que va por promedio *(Entrega 5)*

`years.reparto_subunidades` = `'porcentaje'` (lo de hoy y el defecto) o `'promedio'`.
Lo elige el colegio. **`ConfiguracionColegio.dart` y `ColegioModel` lo leen con
`'porcentaje'` por defecto**, como todos los demás: una app vieja, o una respuesta que
no traiga el campo, tiene que seguir comportándose exactamente como hoy.

Lo que cambia aquí es lo mismo que en la web — **un campo desaparece**:

| dónde | `porcentaje` | `promedio` |
|---|---|---|
| `UnidadesScreen`, campo `%` de la subunidad | se pide | **no se pinta** |
| el aviso de «las subunidades no suman 100» | se pinta | **no se pinta** |
| `HojaDetalleNota` / la celda de la planilla | `nota × %/100` | **la nota** |
| `%` de la **unidad** | se pide | **se sigue pidiendo** |

Ese aviso de «tienen que sumar 100» está hoy escrito en el docblock de
`SubunidadModel` como una regla del backend. **Con el año en modo promedio deja de ser
verdad**, así que ese comentario hay que corregirlo el día que esto entre — si no,
queda un comentario convincente que manda a quien lo lea a «arreglar» lo que funciona.

**El interruptor no se toca desde la app.** Cambiarlo mueve todas las definitivas
guardadas del año; eso se hace en la web, con su confirmación y sus números delante.

### 3.3 · Indicadores *(Entrega 3, esperando decisión)*

No se empieza. Si sale la opción recomendada, la subunidad traerá un
`indicador_id` opcional y su texto, y la app lo enseñará debajo del nombre de la
columna. Nada más.

---

## 4. Orden

1. Esperar el despliegue del backend en los dieciséis.
2. **Entrega 4**: comprobar que ninguna pantalla da por hecho que un independiente
   viene sin unidades. Es una revisión, no una feature.
3. Competencias, sólo lectura.
4. **Entrega 5**: leer el modo con `'porcentaje'` por defecto y **quitar** el campo de
   porcentaje cuando toque. Y corregir el docblock de `SubunidadModel`.
5. Indicadores, sólo con la decisión de Joseth tomada.
