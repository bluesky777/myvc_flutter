# Dónde va todo, y qué sigue

El mapa para retomar el trabajo sin que nadie tenga que contar nada. Se
actualiza en el mismo commit que cambia el estado que describe: si esta página
miente, es un fallo tan real como una prueba en rojo.

**Última actualización: 23 de agosto de 2026.** Lo último construido —las fases
4, 5 y 6 de notas y la pantalla de configuración— ya está fusionado en `main`,
y con ello **no queda trabajo pendiente que dependa solo de la app**: los tres
frentes abiertos esperan al backend.

## Los frentes abiertos

```mermaid
flowchart LR
    D["Disciplina<br/>docs/disciplina.md"] --> D5["fases 1–5 ✓"]
    D --> D6["fase 6 ⛔<br/>falta endpoint"]
    N["Notas<br/>docs/notas.md"] --> N4["las 6 fases ✓"]
    C["Configuración<br/>docs/configuracion.md"] --> C0["hecha ✓"]
    P["Notificaciones<br/>docs/notificaciones.md"] --> P0["paso 0 cerrado ✓<br/>falta el trabajo<br/>en el backend"]

    style D5 fill:#e8f4e8,stroke:#5a8f5a
    style N4 fill:#e8f4e8,stroke:#5a8f5a
    style D6 fill:#ffe6e6,stroke:#c04b4b
    style P0 fill:#ffe6e6,stroke:#c04b4b
    style C0 fill:#e8f4e8,stroke:#5a8f5a
```

✓ hecho · ○ pendiente y se puede hacer ya · ⛔ bloqueado por algo de fuera

## Qué sigue, en orden

**No queda nada pendiente que dependa solo de la app.** Los dos frentes que
siguen abiertos —la pantalla de disciplina del alumno y las notificaciones—
necesitan trabajo en el backend, y el backend es de solo lectura para esta app.
Ver «Lo que está bloqueado».

Cuando se desbloquee alguno, el orden es:

1. **Disciplina, la pantalla del alumno y del acudiente**, en cuanto exista
   `GET disciplina/mis-fichas`. Es corta: la ficha del alumno en modo lectura.
2. **Notificaciones**, en cuanto estén las tres piezas del servidor. El paso 0
   ya está cerrado, así que se entra directo por el tipo más tonto, el del
   muro, para probar la tubería entera antes de llenarla.

## Lo que está bloqueado, y por qué

Los tres, con su contrato ya escrito y la evidencia que lo justifica, están en
**[backend-pendiente.md](backend-pendiente.md)**: es lo que hay que aprobar para
desbloquearlos, y está redactado para poder decidir sin volver a investigar. Ahí
está también lo contrario —**«Lo que la app necesita que NO se rompa»**—, con el
mínimo de `contratos` para alumno y acudiente, que el backend está a punto de
recortar por seguridad.

- **Disciplina, la pantalla del alumno y del acudiente.** Hace falta un
  `GET disciplina/mis-fichas` que hoy no existe: todas las rutas que tocan
  `dis_procesos` llevan `auth.personal`, que a un alumno le responde 403. El
  detalle, en [disciplina.md](disciplina.md) → «Lo que queda pendiente».
- **Notificaciones.** Cuelgan de tres cosas del servidor: un endpoint de temas,
  un comando de artisan y una entrada de cron. **El paso 0 está cerrado y las
  cuatro comprobaciones salieron bien** (23 ago 2026): el hosting sale por HTTPS
  a Google, ejecuta artisan (Laravel 13.26.1 sobre PHP 8.4.24 en
  `/usr/local/bin/php`) y **el cron dispara**, comprobado con una tarea de
  prueba. El plan B sin push queda descartado. Lo que falta es escribir las tres
  piezas, y eso es trabajo de backend. Ver
  [notificaciones.md](notificaciones.md) → «Lo comprobado en el servidor».
- **Un `PUT notas/lote`.** No existe y es la mejora de carga más grande de todo
  el plan: no solo convierte treinta peticiones en una, sino **treinta agregados
  de la asignatura entera en uno**. Cada `notas/update` recalcula la definitiva,
  y ese recálculo agrega toda la asignatura antes de quedarse con un alumno. El
  contrato, en [backend-pendiente.md](backend-pendiente.md).

## Cómo se trabaja aquí

- **Rama por frente**, con el nombre de lo que hace: `feat/disciplina`,
  `feat/notas`. Un commit por fase, con el porqué en el cuerpo del mensaje.
- **El backend es de solo lectura.** Vive en `~/DESARROLLOS/8myvc` y se lee para
  saber qué devuelve cada endpoint; nunca se edita. Lo que haga falta allí se
  anota en el documento del frente y se pide.
- **Cada plan vive en `docs/`**, con sus diagramas en Mermaid dentro del propio
  `.md`, y se pone al día en el commit que lo cambia.
- **Las trampas del backend se escriben con su prueba al lado.** Los listados se
  arman con `DB::select` y SQL a pelo, así que los tipos los decide PDO: el lado
  Flutter lee el JSON con [JsonBackend](../lib/Utils/JsonBackend.dart) en vez de
  fiarse.
- **Antes de commitear**: `flutter analyze` sin avisos y `flutter test` en verde.
  Con `--concurrency=2` si la máquina va justa; a pelo se queda sin memoria.

## El estado de cada frente, en detalle

### Notas — [notas.md](notas.md)

| Fase | Qué | Estado |
|---|---|---|
| 1 | La sesión completa: [ConfiguracionColegio](../lib/Utils/ConfiguracionColegio.dart) | hecha |
| 2 | Asignaturas con filtro «Hoy» + tarjeta en el muro | hecha |
| 3 | La planilla del indicador (casos A y B) | hecha |
| 4 | La ficha del alumno (casos C y E) | hecha |
| 5 | Notas perdidas | hecha |
| 6 | Frases, historial, borrar nota | hecha |

El camino en la app: menú ▸ Notas → [NotasScreen](../lib/Screens/NotasScreen.dart)
→ [LibroAsignaturaScreen](../lib/Screens/LibroAsignaturaScreen.dart), que tiene
dos pestañas sobre el mismo libro ya cargado:

- **Por indicador** → [PlanillaScreen](../lib/Screens/PlanillaScreen.dart), el
  trabajo diario: una casilla y los treinta alumnos.
- **Por alumno** → [FichaAlumnoNotasScreen](../lib/Screens/FichaAlumnoNotasScreen.dart),
  el acudiente que pregunta y el nivelar de fin de periodo.

Dentro de las dos, manteniendo pulsada una nota se abre su historial y desde
ahí se borra ([HojaDetalleNota](../lib/Widgets/HojaDetalleNota.dart)).

Y aparte, menú ▸ Notas perdidas →
[NotasPerdidasScreen](../lib/Screens/NotasPerdidasScreen.dart): el árbol de lo
que llevan por debajo de la mínima, del año entero y en una sola petición.

### Disciplina — [disciplina.md](disciplina.md)

Fases 1 a 5 hechas, la 4b incluida. Falta solo la pantalla del alumno y del
acudiente, bloqueada por el endpoint que no existe.

### Configuración — [configuracion.md](configuracion.md)

Hecha: menú ▸ Configuración →
[ConfiguracionScreen](../lib/Screens/ConfiguracionScreen.dart). Se edita lo que
un directivo cambia estando de pie —siete ajustes— y lo demás se ve, con «lo
demás se configura en la plataforma web» al final. La ve todo el personal; los
interruptores solo los mueve un administrador, y eso es **alcance de la app, no
permiso del servidor**: sus endpoints llevan `auth.personal` y un docente
podría llamarlos.

### Notificaciones — [notificaciones.md](notificaciones.md)

Solo el plan, y bloqueado en el servidor. **El paso 0 está cerrado**: el
hosting sale a Google, ejecuta artisan y el cron dispara. Falta escribir el
endpoint de temas, el comando `notificaciones:enviar` y la línea de cron; el
lado Flutter —Firebase, permiso y suscripción— no se puede empezar sin el
endpoint que entrega los temas.

### Publicación en Google Play

[publicacion-play.md](publicacion-play.md) tiene la guía, y
[ficha-play.md](ficha-play.md) y [politica-privacidad.md](politica-privacidad.md)
los borradores. Si algún día entran las notificaciones, los dos hay que
retocarlos: hay que declarar el identificador de dispositivo de FCM.
