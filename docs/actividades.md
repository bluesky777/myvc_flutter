# Actividades — tareas, cuestionarios y encuestas en la app

La tanda 6 del contrato (`myvc_front/ACTIVIDADES-CONTRATO.md`): lo que ven el
**alumno** y el **acudiente**. Lo del docente (crear, preguntas, resultados,
calificar) vive en la web. Escrito el 26 sep 2026 contra la rama
`feat/actividades` de `8myvc` (tandas 1 a 3), que **manda sobre el contrato**
donde difieren.

## Estado

- **Apagado** detrás de `Interruptores.actividades`
  (`--dart-define=ACTIVIDADES=true` para probar). Se enciende cuando `act/*` y
  sus migraciones estén **desplegados en todos los colegios**: hoy ni siquiera
  están en `main` del backend.
- Sin endpoints nuevos. Cliente en `lib/Http/ActividadesApi.dart`, modelos en
  `lib/Models/ActividadModel.dart`.

## Pantallas

| Pantalla | Maqueta | Ruta / cómo se abre |
|---|---|---|
| `ActividadesScreen` — pendientes / hechas, selector de hijo | `FlutterLista` | `/actividades`, en el menú justo después de «Inicio» |
| `ResponderActividadScreen` — una pregunta por pantalla | `FlutterResponder` | push desde la lista |
| `EntregarTareaScreen` — foto, archivo, enlace, texto | `FlutterTarea` | push desde la lista |
| `MisRespuestasActividadScreen` — nota, correctas, entrega, resultados compartidos con «tú» | `MisRespuestas` | push desde la lista o al terminar |

## Decisiones que conviene conocer

- **El selector de hijo sale de la bandeja** (`por_alumno` de cada fila), no de
  los acudidos del muro: una petición menos, y un hijo sin nada que responder
  no aparece. Lo que el acudiente responde «una sola vez» sale con cualquier
  hijo elegido, marcado «Para ti, acudiente».
- **El recorrido se calcula en el teléfono** (`lib/Utils/RecorridoActividad.dart`,
  copia de `app/Services/Act/Recorrido.php`), no con `act/{id}/recorrido`: sería
  una petición por toque. El servidor vuelve a evaluar al enviar y, si falta una
  obligatoria, la pantalla salta a ella. **Sin probar con condiciones reales**:
  el docker no tenía ninguna actividad con condiciones el 26 sep.
- **Borrador en el servidor** en los tres anonimatos: 1,2 s después de cada
  cambio, al pasar de pregunta y al cerrar. Al reabrir sigue en la primera
  visible sin responder.
- **La foto se reduce en el teléfono** con `image_picker` (`maxWidth` y
  `maxHeight` iguales): Normal 1280 px / JPEG 80, Ligera 800 px / JPEG 70. Los
  documentos se eligen con `file_picker` (dependencia nueva), con las
  extensiones de `SafeUpload::EXTENSIONES_DOCUMENTO`. Más de 5 MB no se sube: se
  ofrece pegar un enlace si la tarea lo acepta.
- **El video de YouTube no se incrusta**: miniatura que abre YouTube desde el
  segundo elegido. Incrustarlo pide un `webview` nativo más.
- La escala lleva `texto_abajo` bajo el 1 y `texto_arriba` bajo el 5.

## Avisos: push y campana (tanda 5, 8myvc `311d07b`)

- **Temas.** `GET notificaciones/temas` trae `temas.actividad` por alumno y
  `usuario: {actividad}` (`u_…_actividad`, el de la persona: la encuesta que
  se le pide al acudiente no va al tema del hijo). `TipoDeAviso.actividad`
  —sexto tipo, con su interruptor en «Notificaciones»— apunta el teléfono a los
  dos; al cerrar sesión se sueltan con los demás, porque se anotan igual.
  Con `Interruptores.actividades` apagado el tipo no está `disponible`: ni sale
  su interruptor ni el teléfono se apunta.
- **El push** trae `pantalla: 'actividad'`, `actividad_id`, `clase` y, si es de
  un alumno, `alumno_id`. `Avisos` abre `/actividades` con un
  `AvisoDeActividad` y la lista abre esa actividad como si se tocara su fila
  (responder, entregar o mis respuestas, según su estado).
- **El acudiente con un aviso del tema de su hijo** sobre algo que responde el
  hijo no lo tiene en su bandeja: si es la nota o los resultados
  (`calificada`, `nota_cambiada`, `resultados`) se abre «mis respuestas» con
  el `alumno_id`; si es algo por responder, se le dice que lo hace el hijo
  desde su cuenta.
- **La campana** (`GET act/avisos`) va en la barra de «Actividades», con el
  número de no leídos. Abrirla los marca leídos (`POST act/avisos/leidos` con
  el `hasta_id` recibido) y tocar uno lleva a la actividad por el mismo camino
  que el push. Un colegio sin la tanda 5 contesta 404 y la campana no sale.

## Lo que se probó (26 sep 2026)

`flutter build web` con el interruptor encendido, contra el docker
(`localhost:8092`, `lalvirtual`), conducido con Chrome a 390×844:

- Alumno 2548: bandeja (pendientes y hechas), borrador guardado y retomado en
  el cuestionario 13 (**sin enviarlo**), mis respuestas del cuestionario 6 con
  correcta y puntaje parcial, la tarea 8 con su foto bajada por
  `act/archivos/1`, la tarea calificada 22 y los resultados compartidos de la
  encuesta 10.
- Acudiente 931: selector con sus dos hijas y **la encuesta 12 enviada por
  Nicole (465)**, y sus respuestas desde el servidor.
- `flutter build apk --debug` compila con `file_picker`.

- Campana: el número del alumno (8 sin leer; **no se abrió**, para no marcar
  leídos los avisos de prueba de la sesión del backend) y la del acudiente
  abierta, con el aviso llevando a la encuesta 11 por Nicole.

**No probado**: subir una foto o un archivo desde la app (la única tarea que
los pide en el docker ya estaba entregada, y subir otra foto reemplaza la
entregada), un Android real, y un push de verdad (FCM sólo está en Android: la
apertura se probó por la campana, que usa el mismo camino).
