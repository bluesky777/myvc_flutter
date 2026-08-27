# Tablets

La app **funciona** en una tablet desde el primer día: nada se rompe, nada da
error, todo se puede tocar. Lo que no tiene es **un layout propio** — es la
interfaz de teléfono ocupando todo el ancho.

Este documento existe porque «se ve raro en tablet» no es una tarea: hay que
saber *dónde* se ve raro, *por qué*, y cuál de los dos problemas distintos que
se esconden ahí dentro es el que toca resolver.

Los diagramas son [Mermaid](https://mermaid.js.org). Para verlos dibujados en VS
Code, extensión `bierner.markdown-mermaid` y vista previa con `⌘K V`; en GitHub
se ven solos.

## Son dos problemas, no uno

Y confundirlos es la forma de hacer el doble de trabajo del necesario.

```mermaid
flowchart TD
    P["La interfaz de teléfono<br/>en 1.700 px de ancho"] --> A["1 · Lo que se estira<br/>y no debería"]
    P --> B["2 · El hueco que sobra<br/>y no se aprovecha"]

    A --> A1["un campo de texto de 1.300 px<br/>un botón de lado a lado<br/>una tarjeta de contador deformada"]
    A --> A2["Se arregla con <b>un número</b>:<br/>un ancho máximo"]

    B --> B1["cinco indicadores arriba<br/>y media pantalla en blanco"]
    B --> B2["Se arregla con <b>otro layout</b>:<br/>dos columnas o maestro-detalle"]

    style A2 fill:#e8f4e8,stroke:#5a8f5a
    style B2 fill:#fff0e6,stroke:#c98a4b
```

**El primero es barato y el segundo no.** El primero es un tope: se escribe una
vez, no cambia nada en el teléfono y se puede comprobar con una prueba. El
segundo es rediseñar una pantalla, y hay que hacerlo pantalla por pantalla
porque cada una aprovecha el hueco de una forma distinta.

Por eso el orden es ése, y por eso el primero no espera al segundo.

## Dónde se nota, medido y no supuesto

Salió al sacar las capturas de la ficha de Play el 25 de agosto de 2026, en un
emulador de Pixel Tablet.

| Pantalla | Cómo queda | Cuál de los dos problemas |
|---|---|---|
| Notas «por alumno», asistencia, disciplina | **Bien.** Son listas, y a lo ancho caben 15 alumnos en vez de 7 | ninguno |
| Detalle de una asignatura | **Mal.** Cinco indicadores arriba y media pantalla en blanco debajo | el 2 |
| Login | Regular. Los campos ocupan todo el ancho y quedan desproporcionados | el 1 |
| Ficha de disciplina de un alumno | Regular. Las tarjetas de contadores se estiran de más | el 1 |

**Las listas quedan bien y no hay que tocarlas.** Merece decirlo porque la
tentación al abordar «tablets» es rediseñarlo todo: una lista de alumnos a lo
ancho es *mejor* en tablet que en teléfono, sin hacer nada. Las capturas que se
subieron a Play son de las tres pantallas que ya quedan bien, a propósito — pero
eso quitó una etiqueta, no resolvió el fondo.

## Las fases

```mermaid
flowchart LR
    F1["1 · El tope ✓<br/>hecho 26 ago 2026<br/><i>login</i>"] --> F2["2 · El tope<br/>en las fichas ○"]
    F2 --> F3["3 · El detalle de<br/>una asignatura ○<br/><i>aprovechar el hueco</i>"]
    F3 --> F4["4 · Maestro-detalle ○<br/><i>si hace falta</i>"]

    style F1 fill:#e8f4e8,stroke:#5a8f5a
    style F2 fill:#f0f0f5,stroke:#8a8aa0
    style F3 fill:#f0f0f5,stroke:#8a8aa0
    style F4 fill:#f0f0f5,stroke:#8a8aa0
```

### Fase 1 — el tope, y el login. Hecha

**26 de agosto de 2026.** [Anchos](../lib/Utils/Anchos.dart), y los tres
controles del login pasan a pedirle a él cuánto miden.

La regla no es «proporcional» ni «fijo» sino **proporcional con tope**: en un
teléfono manda la proporción y **no cambia absolutamente nada**; en una tablet
manda el tope y el control se queda centrado con aire a los lados. El tope son
420 px, que es aproximadamente un teléfono grande — o sea que en tablet el
formulario se ve como se diseñó, centrado, en vez de como una versión estirada
de sí mismo.

De paso arregla algo que ya estaba mal antes de las tablets: **la banda del
login estaba escrita tres veces**. `InputContainer`, `RoundedButton` y la
casilla de «recordar mis datos» ponían cada uno su `size.width * 0.8`, y el
comentario de uno de ellos avisaba de que los otros dos hacían lo mismo. Los
tres tienen que medir igual o se ve un escalón entre ellos, así que eran tres
sitios donde cambiar una decisión que es una.

Cinco pruebas en [anchos_test](../test/anchos_test.dart), y la que más importa
es la primera: **en un teléfono la banda sigue siendo el 80% exacto de antes**.
Esto no puede tocar la pantalla que usa todo el mundo.

### Fase 2 — el tope en las fichas

Las tarjetas de contadores de la ficha de disciplina, y cualquier otra ficha que
se estire de más. Es el mismo número de la fase 1 aplicado en otro sitio, así
que es corta.

Ojo con una cosa: **una ficha no es un formulario**. 420 px es el ancho de un
campo de texto; una ficha con tres columnas de contadores aguanta más. Cuando se
aborde habrá que decidir si `Anchos` gana una segunda constante o si las
tarjetas se resuelven con un `Wrap` que las deje fluir, que probablemente es
mejor: dejar que quepan cuatro donde caben cuatro es aprovechar el hueco, y no
solo dejar de estirarse.

### Fase 3 — el detalle de una asignatura

**La única que está francamente mal**, y la única que no se arregla con un
número. Cinco indicadores arriba y media pantalla en blanco debajo: el problema
no es que algo se estire, es que el hueco no se usa.

Dos caminos, y hay que elegir mirando la pantalla y no en abstracto: dos
columnas, o el patrón maestro-detalle. La navegación de esta app
—grupo → alumno → ficha— pide a gritos el segundo, pero eso es la fase 4 y es
mucho más grande.

### Fase 4 — maestro-detalle, si hace falta

Enseñar la lista a la izquierda y la ficha del seleccionado a la derecha, en vez
de navegar de una pantalla a otra. Es lo que mejor aprovecha una tablet y es,
con diferencia, lo más caro: cambia la navegación, no el layout, así que toca el
router y el estado de cada pantalla que lo adopte.

**No se empieza sin haber hecho la 3.** Puede que con dos columnas ya sobre.

## Lo que este frente NO va a hacer

- **Un sistema de *breakpoints*.** `Anchos` es un número máximo, no un
  framework, y no hay que convertirlo en uno. La app tiene un problema concreto
  en un sitio concreto; un sistema de puntos de ruptura es la solución a un
  problema que esta app no tiene, y se paga en cada pantalla que se escriba
  después.
- **Tocar las listas.** Ya quedan bien. A lo ancho caben 15 alumnos en vez de 7,
  que es exactamente lo que se quiere de una tablet.
- **Un layout de escritorio.** La app es de teléfono y de tablet. La web
  administrativa es otra cosa y existe.

## Por qué esto no bloquea nada

Ninguna de las cuatro fases es condición de nada: ni de la publicación en Play,
ni del backend, ni de las notificaciones. La app funciona en tablet hoy. Esto es
mejorar algo que ya sirve, y por eso puede esperar y por eso se puede hacer a
trozos.
