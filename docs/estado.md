# Dónde va todo, y qué sigue

El mapa para retomar el trabajo sin que nadie tenga que contar nada. Se
actualiza en el mismo commit que cambia el estado que describe: si esta página
miente, es un fallo tan real como una prueba en rojo.

**Última actualización: 23 de agosto de 2026.**

## Los frentes abiertos

```mermaid
flowchart LR
    D["Disciplina<br/>docs/disciplina.md"] --> D5["fases 1–5 ✓"]
    D --> D6["fase 6 ⛔<br/>falta endpoint"]
    N["Notas<br/>docs/notas.md"] --> N4["fases 1–4 ✓"]
    N --> N56["fases 5 y 6 ○"]
    C["Configuración<br/>docs/configuracion.md"] --> C0["sin empezar ○"]
    P["Notificaciones<br/>docs/notificaciones.md"] --> P0["⛔ necesita<br/>trabajo en el backend"]

    style D5 fill:#e8f4e8,stroke:#5a8f5a
    style N4 fill:#e8f4e8,stroke:#5a8f5a
    style D6 fill:#ffe6e6,stroke:#c04b4b
    style P0 fill:#ffe6e6,stroke:#c04b4b
    style N56 fill:#fff0e6,stroke:#c98a4b
    style C0 fill:#fff0e6,stroke:#c98a4b
```

✓ hecho · ○ pendiente y se puede hacer ya · ⛔ bloqueado por algo de fuera

## Qué sigue, en orden

1. **Notas, fase 5 — notas perdidas.** El backend está listo y no hay que
   tocarlo. Ver [notas.md §4](notas.md).
2. **Notas, fase 6 — frases, historial y borrar nota.** Ver [notas.md §1.9](notas.md).
3. **La pantalla de configuración.** El plan entero está en
   [configuracion.md](configuracion.md); no se ha escrito una línea de código.

## Lo que está bloqueado, y por qué

- **Disciplina, la pantalla del alumno y del acudiente.** Hace falta un
  `GET disciplina/mis-fichas` que hoy no existe: todas las rutas que tocan
  `dis_procesos` llevan `auth.personal`, que a un alumno le responde 403. El
  detalle, en [disciplina.md](disciplina.md) → «Lo que queda pendiente».
- **Notificaciones.** Todo el plan cuelga de tres cosas del servidor —un
  endpoint de temas, un comando de artisan y una entrada de cron— y el backend
  es de solo lectura para esta app. Antes de nada hay que comprobar que el
  hosting deje salir por HTTPS a Google. Ver
  [notificaciones.md](notificaciones.md).
- **Un `PUT notas/lote`.** No existe y sería la mejora de carga más grande de
  todo el plan de notas: convertiría treinta peticiones en una. Anotado en
  [notas.md §1.5](notas.md).

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
| 5 | Notas perdidas | **pendiente** |
| 6 | Frases, historial, borrar nota | **pendiente** |

El camino en la app: menú ▸ Notas → [NotasScreen](../lib/Screens/NotasScreen.dart)
→ [LibroAsignaturaScreen](../lib/Screens/LibroAsignaturaScreen.dart), que tiene
dos pestañas sobre el mismo libro ya cargado:

- **Por indicador** → [PlanillaScreen](../lib/Screens/PlanillaScreen.dart), el
  trabajo diario: una casilla y los treinta alumnos.
- **Por alumno** → [FichaAlumnoNotasScreen](../lib/Screens/FichaAlumnoNotasScreen.dart),
  el acudiente que pregunta y el nivelar de fin de periodo.

### Disciplina — [disciplina.md](disciplina.md)

Fases 1 a 5 hechas, la 4b incluida. Falta solo la pantalla del alumno y del
acudiente, bloqueada por el endpoint que no existe.

### Configuración — [configuracion.md](configuracion.md)

Solo el plan. Lo que se edita son siete ajustes; lo demás se ve en gris con «lo
demás se configura en la plataforma web».

### Notificaciones — [notificaciones.md](notificaciones.md)

Solo el plan, y bloqueado. El paso 0 es un `curl` desde el servidor.

### Publicación en Google Play

[publicacion-play.md](publicacion-play.md) tiene la guía, y
[ficha-play.md](ficha-play.md) y [politica-privacidad.md](politica-privacidad.md)
los borradores. Si algún día entran las notificaciones, los dos hay que
retocarlos: hay que declarar el identificador de dispositivo de FCM.
