# PQRS del acudiente

Pedido por Joseth el 9 oct 2026. El documento de la función entera —decisiones, permisos, tablas,
rutas y cómo probarla— está en `myvc_front/docs/funciones/PQRS.md`. Aquí sólo va lo que es de la app.

## Las pantallas

| Pantalla | Ruta | Qué hace |
|---|---|---|
| **PQRS** (`MisPqrsScreen`) | `/mis-pqrs` | Las suyas, abiertas arriba, con estado y semáforo del plazo. Botón «Radicar». |
| **Radicar una PQRS** (`RadicarPqrsScreen`) | push | Tipo, qué pide (sólo petición), sobre cuál hijo, asunto, descripción y una foto o un documento. |
| **Detalle** (`DetallePqrsScreen`) | push | Radicado y día que vence, la respuesta, la encuesta (1 a 5 estrellas y comentario) y lo que ha pasado. |

- Sólo las ve el **acudiente** (`usuario.esAcudiente`): el alumno no radica.
- Las tres van detrás de `Interruptores.pqrs`. Para probarlo: `--dart-define=PQRS=true`.
- El semáforo y su frase («Vence en 2 días hábiles») vienen del servidor, que es quien sabe de festivos.
- Los tipos, sus explicaciones y los plazos también vienen del servidor (`catalogo`): la app y la web
  dicen lo mismo.
- Lo interno del colegio (notas, a quién se asignó) no llega a la app. Del colegio sólo se ve quién
  firmó la respuesta.

## El aviso

Cuando el colegio responde, `EnviarNotificaciones::avisosDePqrs` publica en el tema de la persona
(`u_…_pqrs`), con `pantalla: 'pqrs'` y `pqrs_id`.

- `TipoDeAviso.pqrs` lo conoce y sale en «Notificaciones», pero sólo para el acudiente y con el
  interruptor encendido. El servidor manda `usuario.pqrs` a todo el mundo.
- Al tocarlo se abre `/mis-pqrs` con `AvisoDePqrs` y, encima, esa PQRS.
- El aviso no lleva el asunto ni la respuesta, sólo el radicado: una queja puede ser delicada y el
  aviso se ve con el teléfono bloqueado.

## Pendiente

- **Abrir un PDF o un Word adjunto.** Las imágenes se ven en el detalle; un documento sale con su
  nombre y la frase «todavía no se abre en la app». Abrirlo pide una dependencia nueva (`open_filex`
  o parecida), y hay que mirar qué permisos le mete al manifiesto antes de traerla.
- **Ficha de seguridad de datos de Play**: el acudiente ahora manda texto propio y, si quiere, una
  foto o un documento al colegio. Hay que revisar si `seguridad-datos-play.md` tiene que declarar
  «Otro contenido generado por el usuario» y «Fotos» / «Archivos y documentos».
- **Encender**: desplegar `8myvc` con la migración `2026_10_09_520000_pqrs` en todos los colegios,
  luego `Interruptores.pqrs = true` y publicar. En ese orden; ver la cabecera de `Interruptores.dart`.

## Lo que se comprobó (9 oct 2026)

- `flutter analyze` sobre el árbol entero: sin avisos.
- `flutter test` de `notificaciones_test`, `avisos_test`, `menu_lateral_test`, `route_generator_test` y
  `actividades_avisos_test`: verdes. Dos listas de `notificaciones_test` se actualizaron con `pqrs`:
  están para eso, para que un tipo nuevo no se olvide.
- **No probado en un teléfono.** El backend se probó con una prueba de humo contra la base de
  pruebas (ver el doc de la función); las pantallas no se han conducido.
