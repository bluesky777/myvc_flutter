# Notificaciones para alumnos y acudientes

Plan para que un acudiente se entere de que a su hijo le pusieron notas, faltó a
clase o le anotaron una situación, sin abrir la app a ver si hay algo nuevo — y
sin que el hosting compartido lo pague. Escrito el 23 de agosto de 2026.

## El problema, dicho en una línea

Hay dos maneras de que un teléfono se entere de algo: **preguntar** o **que le
avisen**. Preguntar es sondeo, y el sondeo es exactamente lo que un hosting
compartido no aguanta: 400 acudientes preguntando cada cinco minutos son 115.000
peticiones al día para decir «no, nada nuevo» el 99 % de las veces.

Que le avisen es push, y el push **no lo entrega el servidor del colegio**: lo
entrega Google. El servidor solo le dice a Google «avisa a estos», una vez.

Todo este documento va de que esa frase —«una vez»— siga siendo verdad cuando
haya 400 acudientes.

## Qué se avisa

Cinco tipos. Cada uno se puede apagar por separado, que es lo que se pidió.

| Tipo | Se dispara con | Ejemplo del aviso |
|---|---|---|
| **Notas** | notas nuevas o cambiadas de ese alumno | «Laura tiene 4 notas nuevas en Matemáticas» |
| **Asistencia** | una ausencia o una tardanza registrada hoy | «Se registró una ausencia de Juan hoy» |
| **Disciplina** | una situación anotada | «Se anotó una situación de Juan. Ábrela para verla» |
| **Muro** | una publicación nueva del colegio | «Nueva publicación: Salida pedagógica» |
| **Colegio** | cierre de periodo, boletines listos, materias en riesgo | «El periodo cierra el viernes» |

**Ninguna notificación lleva la nota dentro.** «Laura tiene 4 notas nuevas en
Matemáticas», nunca «Laura sacó 45 en Matemáticas». Una notificación se ve en la
pantalla bloqueada, en el bus, con gente al lado; y una nota de un menor no es
algo que deba aparecer ahí. Para verla hay que abrir la app y estar
identificado. Esto además evita el caso feo: el push llega aunque el colegio
tenga las notas bloqueadas (`alumnos_can_see_notas = 0`), y sería absurdo que la
notificación enseñara lo que la app niega.

## Cómo se entrega: temas, no lista de dispositivos

Firebase Cloud Messaging (gratis, sin cuota que preocupe) ofrece dos formas:

**Por dispositivo.** El servidor guarda el token de cada teléfono en una tabla y
envía a cada uno. Con 400 acudientes con dos dispositivos son 800 tokens que
guardar, refrescar cuando caducan y limpiar cuando dejan de valer; y cada aviso
es un lote de peticiones.

**Por tema (*topic*).** El teléfono **se apunta él mismo** a un tema. El
servidor publica en el tema y Google reparte. Una petición, tenga el tema tres
dispositivos o tres mil. Cero tablas, cero tokens, cero limpieza.

**Se usan temas.** No es solo más barato: es que la parte cara de la otra opción
—guardar y mantener los tokens— caería justo sobre lo que hay que proteger.

### Y aquí está el detalle que hay que hacer bien

Si el tema se llamara `alumno_345`, cualquiera con la app podría apuntarse al
`alumno_346` y recibir los avisos de un menor que no es suyo. El nombre del tema
es, en la práctica, la única puerta.

Por eso **el nombre del tema no se calcula en el teléfono: lo entrega el
servidor al identificarse**, y es opaco:

```
tema = "a_" + HMAC-SHA256(alumno_id, secreto_del_colegio)   →   a_9f3c1e...
```

El acudiente recibe al entrar la lista de temas de sus acudidos, y nada más.
Nadie puede derivar el de otro alumno sin el secreto, que vive en el servidor.
Y como el contenido del aviso no dice nada —punto anterior—, incluso el peor
caso, que se filtre un nombre de tema, entrega ruido y no datos.

El tipo va como sufijo, y ahí está la clave de las preferencias:

```
a_9f3c1e…_notas        a_9f3c1e…_asistencia      a_9f3c1e…_disciplina
c_4b2d7a…_muro         c_4b2d7a…_avisos
```

### Los temas del colegio también llevan prefijo

Los dos últimos no son de un alumno sino de todo el colegio, y aun así **no
pueden llamarse `colegio_muro` a secas**. El motivo es que los temas viven en el
proyecto de Firebase, y **el proyecto es uno solo para los quince colegios**:
es una sola app, un solo `com.micolevirtual.app`, un solo `google-services.json`.
Un tema llamado `colegio_muro` sería el mismo tema para los quince, y una
publicación del muro de un colegio le llegaría a las familias de los otros
quince.

Así que llevan el identificador del colegio, derivado igual que el del alumno
—`c_` + HMAC del identificador del colegio— y entregado por el mismo endpoint de
temas. No es secreto como el del alumno —qué colegio es no lo esconde nadie—,
pero derivarlo igual evita tener dos formas de nombrar temas.

### Las preferencias viven en el teléfono

Apagar «Notas» es `unsubscribeFromTopic`: una llamada a Google, **cero
peticiones al servidor del colegio, cero filas en la base de datos, cero
consultas al enviar**. El envío no tiene que filtrar por preferencias porque
quien no quiere el aviso ya no está en el tema.

El efecto secundario es correcto, además: las preferencias son **por
dispositivo**. El acudiente puede querer los avisos de notas en su teléfono y no
en la tableta que usa el niño. Con preferencias guardadas en el servidor eso no
se puede.

Una pantalla «Notificaciones» en el menú lateral, con cinco interruptores y una
línea explicando qué manda cada uno.

## Cuándo se envía: por cron, agrupado, nunca dentro de una petición

Dos cosas que **no** se pueden hacer:

**No enviar dentro de la petición del docente.** Si al guardar una nota el
servidor llama a Google, el docente espera a que Google responda. Pasar una
columna de 30 notas serían 30 llamadas a Google metidas en el camino crítico de
30 peticiones. La app se sentiría rota y el servidor estaría ocupado
esperando a un tercero.

**No usar colas.** `QUEUE_CONNECTION` está en `sync`, que significa «ejecuta
ahora mismo, aquí» — o sea, exactamente el problema de arriba con otro nombre.
Una cola de verdad necesita un proceso vivo escuchando, y en hosting compartido
no lo hay.

Queda el cron, que casi todos los hostings compartidos sí dan:

```mermaid
sequenceDiagram
    participant D as Docente
    participant S as Servidor
    participant BD as Base de datos
    participant C as Cron (cada 15 min)
    participant G as Firebase
    participant T as Teléfono del acudiente

    D->>S: PUT notas/update/{id} × 30
    S->>BD: UPDATE notas + INSERT bitacoras
    Note over S,D: responde ya; no habla con nadie más

    C->>BD: SELECT de bitacoras desde la última marca
    BD-->>C: 30 filas → 1 alumno, 1 asignatura
    C->>G: 1 POST: tema a_9f3c1e…_notas
    G->>T: «Laura tiene 4 notas nuevas en Matemáticas»
    C->>BD: guarda la marca nueva
```

**Agrupar es lo que hace esto viable, y de paso lo hace mejor.** Un docente que
pasa una columna genera 30 cambios en dos minutos. Sin agrupar son 30 avisos y
el acudiente apaga las notificaciones para siempre. Agrupado por alumno y
asignatura es uno: «4 notas nuevas en Matemáticas». Menos peticiones y menos
molestia, la misma decisión.

### De dónde salen los cambios sin inventar tablas

Ya está todo registrado:

| Tipo | Fuente | Consulta |
|---|---|---|
| Notas | `bitacoras` — cada `PUT notas/update/{id}` inserta una fila con `affected_element_type = 'Nota'`, `affected_user_id = alumno_id` y `created_at` | `WHERE id > :marca AND affected_element_type IN ('Nota','NF_UPDATE') GROUP BY affected_user_id` |
| Asistencia | `ausencias.created_at` | agrupada por `alumno_id` |
| Disciplina | las situaciones, por `created_at` | agrupada por `alumno_id` |
| Muro | `publicaciones.created_at` | una fila basta |

Una consulta agrupada por tipo, cuatro por ejecución. La marca —el último `id`
de `bitacoras` procesado— es una fila en una tabla nueva de dos columnas, o un
archivo; con `CACHE_DRIVER=file` sirve el propio caché de Laravel.

### Lo que le cuesta al servidor

Cada 15 minutos: cuatro `SELECT` con índice y **entre cero y unas pocas**
llamadas a Google. En una jornada normal, con clases entre las 7 y las 14, la
mayoría de ejecuciones no manda nada.

96 ejecuciones al día. Comparado con los 115.000 sondeos del primer párrafo, es
otra escala. Si 15 minutos resulta mucha espera para asistencia, ese tipo se
puede subir a 5 minutos y dejar los demás en 15; sigue sin acercarse a nada
preocupante.

## Lo que hay que construir

### El backend ya está — desplegado desde el 25 de agosto de 2026

**Y este documento no se enteró hasta el 26.** Las tres piezas entraron en el
commit `98e6311`, que es ancestro de `eb95cbc`, la tanda que se desplegó con el
mismo hash en los quince colegios:

| Pieza | Dónde |
|---|---|
| `GET notificaciones/temas` | `routes/api/notificaciones.php:25` |
| `notificaciones:enviar` | `app/Console/Commands/EnviarNotificaciones.php` |
| El disparo cada quince minutos | `app/Console/Kernel.php:58` — **en el scheduler, no un cron nuevo**: viaja en el `schedule:run` de cada minuto que ya existía |
| La configuración | `config/notificaciones.php` |

Se comprueba con `git merge-base --is-ancestor <commit> eb95cbc`, no leyendo un
documento. Es la misma lección que dejó apagada la ficha de disciplina tres días
de más; ver [estado.md](estado.md) → «La lección de los tres días».

### ⛔ Un fallo del servidor que hay que arreglar antes de encender el muro

**`colegio_muro` y `colegio_avisos` no llevan identificador de colegio.**
`TemasDeNotificacion::DEL_COLEGIO` son literales, y `avisosDelMuro()` publica en
el literal `'colegio_muro'`.

El proyecto de Firebase **es uno solo para los quince colegios** —una sola app,
un solo `com.micolevirtual.app`, un solo `google-services.json`—, así que ese
tema es el mismo para los quince: en cuanto dos colegios tengan la app, una
publicación del muro de uno le llega a las familias de los otros catorce.

Es justo lo que este documento avisaba en «Los temas del colegio también llevan
prefijo». Por qué se escapó, que es lo que merece la pena guardar: el docblock
del backend razona que ese tema «no lleva HMAC porque es público a propósito: no
dice nada de ningún menor». Eso es cierto y es **otra pregunta**. El HMAC del
tema del alumno hace dos cosas a la vez —esconder de quién es, y separar un
colegio de otro—; ahí se descartó la primera, que no hacía falta, y con ella se
fue la segunda, que sí.

Hoy no rompe nada porque la app no está publicada. **No es fuga de contenido**
—el cuerpo es genérico, «hay 3 publicaciones nuevas»— pero sí es el aviso
equivocado a la familia equivocada, multiplicado por quince.

**Arreglado el mismo día** (`b369020`), y con una forma mejor que la que se
pidió: `c_` + 32 hex de HMAC, derivado con el mismo secreto del colegio que los
temas de alumno. **No lleva el identificador del colegio, y con razón** — el
secreto ya *es* distinto en cada colegio, porque es su `APP_KEY`, así que el
identificador sería un dato de más; y uno que hoy no existe en su `config/` y
obligaría a editar quince `.env`, que es justo lo que su propio documento dice
que no se le puede pedir a un despliegue.

**Está en `main` y NO desplegado**, así que en la app
`PendientesNotificaciones.temasDelColegio` sigue **apagado** y solo se usan los
temas por alumno. Se enciende cuando entre en una tanda y esté en los quince,
comprobado contra el hash.

**Y cambia la forma de la respuesta, no solo el valor.** El campo `colegio` pasa
de lista a objeto:

```
ANTES  "colegio": ["colegio_muro", "colegio_avisos"]
AHORA  "colegio": {"colegio_muro": "c_1a2b…", "colegio_avisos": "c_3c4d…"}
```

La clave es el nombre lógico —estable, y es con lo que se etiqueta la
preferencia— y el valor el tema de verdad. `alumnos` no se toca.

[NotificacionesApi](../lib/Http/NotificacionesApi.dart) **lee las dos formas, y
eso no lleva interruptor a propósito**: las dos están vivas a la vez mientras
dura un despliegue, y leer de la respuesta tal como venga vale antes y después
sin que nadie tenga que acordarse de encender nada. Es el mismo criterio que el
número de contraseñas cambiadas en [usuarios.md](usuarios.md).

**La letra pequeña, que nos toca conocer:** si dos colegios compartieran
`APP_KEY` —un `.env` copiado al crear uno nuevo, que es como se crean— sus temas
colisionarían. Eso no lo introduce el arreglo: los temas de alumno dependen del
mismo secreto desde el primer día. Lo que cambia es que ahora el fallo sería el
mismo en los dos sitios y no solo en uno.

**`colegio_avisos` se queda declarado** aunque no lo publique nadie todavía. Si
esa función no va a existir se retira **de los dos lados a la vez**, y esa es una
pregunta para Joseth y no para ninguna de las dos sesiones.

**Y esto reordena el plan de abajo:** el paso 3 era probar la tubería con el
tipo más tonto, el del muro, y ése es precisamente el roto. Hasta que lleve
prefijo, la prueba de punta a punta tiene que hacerse con uno de los tres tipos
por alumno.

### Lo que se pidió en su día, y que ya está hecho

Se conserva porque explica por qué el backend quedó como quedó.

1. Un endpoint que, al identificarse, devuelva **los temas** que le tocan a ese
   usuario (los suyos y los de sus acudidos). Es la pieza de seguridad: la
   derivación con HMAC vive aquí y en ningún otro sitio.
2. Un comando de artisan, `notificaciones:enviar`, con las cuatro consultas, la
   marca y el envío.
3. La entrada de cron: `*/15 * * * * php artisan notificaciones:enviar`.
4. Las credenciales: una cuenta de servicio de Firebase (un JSON) y su secreto
   fuera del repositorio.

Sobre el envío: la API HTTP v1 de FCM pide un token de OAuth firmado con la
cuenta de servicio. **No hace falta añadir el SDK de Google**: se firma un JWT
con `openssl_sign` y se pide el token con Guzzle —que ya está en el
`composer.json`—, y el token se cachea la hora que dura. Una dependencia menos
que mantener en un hosting donde actualizar es incómodo.

### Lo comprobado en el servidor — 23 de agosto de 2026

El paso 0 del plan, cerrado. Las cuatro respuestas están, y las cuatro son que
sí:

| Pregunta | Comprobación | Resultado |
|---|---|---|
| ¿Sale el servidor por HTTPS a Google? | `curl` a `oauth2.googleapis.com/token` y a `fcm.googleapis.com` | **sí** — los dos contestan `404` |
| ¿Ejecuta artisan? | `php artisan --version` | **sí** — Laravel 13.26.1 |
| ¿Puede programar cron? | una tarea de prueba de cada minuto | **sí** — programada por consola, visible en cPanel y **ejecutada**: cuatro pasadas en el log |
| ¿Con qué PHP? | `which php` · `php -v` | `/usr/local/bin/php`, **PHP 8.4.24** — el mismo del shell, y la versión que pide el backend |

Sobre el `404`: **es la respuesta correcta para esta comprobación.** Un 404 es
Google contestando —hubo DNS, handshake TLS y conversación—, y eso es justo lo
que se quería saber. Lo que delataría un bloqueo sería que se quedara colgado, o
un `Could not resolve host`, o un `Connection refused`. Pedir esas URLs sin
credenciales y sin el método correcto **tiene** que dar 404.

**Las cuatro son que sí, así que este plan sale entero y el plan B del final
queda descartado como camino principal.**

El cron se confirmó programando una tarea de cada minuto y mirando que corriera
—que es lo único que lo demuestra: aparecer en la lista de cPanel solo prueba
que está apuntada—:

```
( crontab -l 2>/dev/null; echo 'MAILTO=""'; \
  echo '* * * * * /usr/local/bin/php -v >> $HOME/cron-prueba.log 2>&1' ) | crontab -
```

Sin `crontab -e`, que abre `vi` y es donde se atasca uno. A los dos minutos el
log tenía la versión de PHP cuatro veces. Después se borra la tarea, que es más
cómodo con el enlace *Delete* de cPanel → *Advanced* → **Cron Jobs**.

De paso quedó comprobado que **las dos vías valen**: una tarea metida por
consola con `crontab -` aparece en la interfaz de cPanel y se puede editar y
borrar desde ahí.

**La ruta absoluta del binario importa** —y por eso se midió—: cron arranca con
un `PATH` mínimo y casi nunca encuentra `php` a secas. Es el fallo clásico de
cron en cPanel. Aquí resultó ser el mismo binario del shell, así que no hay
sorpresa de versión; en otro colegio habría que volver a mirarlo.

### Y el cron no es uno, es un bucle

Esto salió al ver la ruta real del servidor, `~/coabsaravena.micolevirtual.com/8myvc`:
**cada colegio es un directorio con su propio `.env` y su propia base de datos**,
como dice el `CLAUDE.md` del backend. Así que el comando hay que ejecutarlo una
vez **por colegio**, y son quince.

Quince entradas de cron es la forma equivocada: muchos hostings limitan
cuántas se pueden tener, y disparadas a la misma hora son quince procesos PHP
a la vez, que es justo la carga que este documento entero intenta evitar. Una
sola entrada que los recorra en fila:

```
*/15 * * * * for d in $HOME/*.micolevirtual.com/8myvc; do /usr/local/bin/php "$d/artisan" notificaciones:enviar; done
```

`$HOME` y no `~`: cron ejecuta con `/bin/sh` y la expansión de la virgulilla ahí
no está garantizada, mientras que `HOME` sí lo pone cron.

Secuencial —un proceso cada vez— y añadir un colegio nuevo no obliga a tocar el
crontab.

Dos detalles más de cPanel: algunos no dejan bajar de los 15 minutos, que da
igual porque es la frecuencia del plan; y por defecto mandan **un correo por
ejecución**, que se apaga con `MAILTO=""` en la primera línea del crontab o
redirigiendo la salida.

### En Firebase — la consola, y lo que cuesta

**No cuesta nada.** Cloud Messaging figura como «sin coste» en los dos planes de
Firebase, el gratuito (Spark) y el de pago (Blaze), y **el gratuito no pide
método de pago**. No hay que activar facturación, no hay tarjeta que meter y no
hay tramo a partir del cual empiece a cobrar: enviar por temas es gratis tenga
el tema tres dispositivos o tres mil. Lo que sí se paga está fuera de Firebase y
ya estaba contado: los USD 25 de una vez de Play Console y, **solo si se quiere
iOS**, los USD 99 al año del programa de desarrollador de Apple, que es de donde
sale la clave de APNs.

**Un proyecto, no quince.** Es una sola app con un solo identificador,
`com.micolevirtual.app`, así que hay un proyecto de Firebase y un
`google-services.json`. Lo que separa a un colegio de otro es el nombre del
tema, no el proyecto — ver «Los temas del colegio también llevan prefijo».

Los pasos, en orden:

1. **Crear el proyecto** en `console.firebase.google.com`. Google Analytics se
   puede desactivar: es gratis, pero no lo usamos y añade condiciones que no
   hacen falta.
2. **Registrar la app de Android** con el paquete `com.micolevirtual.app`, y
   bajar el `google-services.json` a `android/app/`. La huella SHA-1 que pide es
   opcional aquí —hace falta para inicio de sesión con Google, no para FCM—,
   pero ya está medida en [publicacion-play.md](publicacion-play.md) §8.
3. **La cuenta de servicio**, que es lo que usa el servidor para firmar el
   token: *Configuración del proyecto ▸ Cuentas de servicio ▸ Generar nueva
   clave privada*. Sale un JSON. Ese archivo va **fuera del repositorio** y en
   los quince directorios de colegio hace falta el mismo, porque el proyecto
   de Firebase es uno.
4. **iOS, solo cuando haya cuenta de Apple.** Una clave de APNs (`.p8`) subida a
   Firebase y la app de iOS registrada con su *bundle id*. Sin eso, en iOS no
   llega nada; en Android sí, y por eso este plan sale primero en Android.

El `google-services.json` **no es un secreto** —va dentro del APK, cualquiera lo
puede sacar— y por eso no protege nada por sí mismo: lo que protege es que el
nombre del tema no se pueda adivinar. El JSON de la cuenta de servicio **sí** es
un secreto, y ese es el que nunca sale del servidor.

### En la app

**Empezado el 26 de agosto de 2026, por la mitad que no toca el manifiesto.**

Hecho y probado, sin dependencias nuevas:

- [NotificacionesApi](../lib/Http/NotificacionesApi.dart) — el cliente de
  `GET notificaciones/temas`, sus modelos y `PendientesNotificaciones`.
- [PreferenciasAvisos](../lib/Utils/PreferenciasAvisos.dart) — qué avisos quiere
  este teléfono, una clave por tipo, todas encendidas por defecto.
- Once pruebas en [notificaciones_test](../test/notificaciones_test.dart).

**Los temas no se derivan en la app, y es deliberado.** Se piden hechos y se usan
tal cual. Si la app supiera componer `a_` + HMAC habría dos sitios donde
escribirlo mal, y uno de ellos **no da error**: suscribirse a un tema que no
existe es válido en FCM, así que el aviso se perdería en silencio — el fallo más
caro de este diseño, y ya anotado en el propio código del backend.

**Lo que falta necesita una decisión, no más código.** `firebase_messaging` mete
`POST_NOTIFICATIONS` en el manifiesto y un identificador de dispositivo en lo
que hay que declarar, y **la app está en revisión de Google ahora mismo** con
`1.0.0 (3)` en prueba cerrada. Ver «Fuera del código», abajo: eso deja de ser
papeleo posterior y pasa a ser condición previa.

Dependencias que hará falta añadir ese día: `firebase_messaging` y
`flutter_local_notifications` — esta última porque FCM no pinta nada si la app
está abierta, y ahí hay que mostrarlo uno mismo. `firebase_core` ya está, y
`Firebase.initializeApp()` ya se llama en `main.dart` para la analítica.

Y lo demás:

- **Android**: `google-services.json`, y el permiso `POST_NOTIFICATIONS`, que
  desde Android 13 hay que **pedir** en tiempo de ejecución. Se pide después de
  entrar y con una frase que explique para qué, no a bocajarro al abrir por
  primera vez: preguntado a secas, mucha gente dice que no y no vuelve a
  aparecer.
- **iOS**: una clave de APNs, que requiere cuenta de desarrollador de Apple de
  pago. Si aún no la hay, esto sale primero en Android y en iOS después.
- **Al entrar**: pedir los temas al servidor y suscribirse a los que el usuario
  no haya apagado. **Al cerrar sesión**: desuscribirse de todos, sin falta —si
  no, el teléfono de un colegio o el que se presta sigue recibiendo avisos del
  alumno anterior—.
- **Al tocar el aviso**: abrir la pantalla que toca —notas, asistencia,
  disciplina, muro—, no solo la app. Es la diferencia entre un aviso útil y uno
  que obliga a buscar.

### Fuera del código

- **La política de privacidad** ([politica-privacidad.md](politica-privacidad.md))
  no menciona notificaciones y tendrá que decir que se usa Firebase Cloud
  Messaging, qué se manda (nada personal en el cuerpo) y cómo se apagan.
- **La ficha de Play** ([ficha-play.md](ficha-play.md)) y la sección de
  seguridad de datos: hay que declarar el identificador de dispositivo que FCM
  maneja.
- Son de menores. Merece la pena que el colegio lo comunique a las familias
  antes de encenderlo, aunque legalmente baste con la política.

## Orden de trabajo

```mermaid
flowchart LR
    V["0 · Verificar el hosting ✓<br/>salidas HTTPS, artisan<br/>y cron — cerrado"] --> B["1 · Backend<br/>temas + comando<br/>+ cron"]
    B --> A["2 · App<br/>Firebase + permiso<br/>+ suscripción"]
    A --> T["3 · Un solo tipo<br/>(Muro)<br/>de punta a punta"]
    T --> P["4 · Pantalla de<br/>preferencias"]
    P --> R["5 · Los otros<br/>cuatro tipos"]
    R --> D["6 · Política y<br/>ficha de Play"]
```

El paso 0 está cerrado, el cron incluido; ver «Lo comprobado en el servidor». El
paso 3 es a propósito el tipo **más tonto** —una publicación del muro, sin
datos de nadie— porque el objetivo de esa fase es probar la tubería entera, no
el contenido. Cuando llegue un aviso de muro a un teléfono real, los otros
cuatro son la misma cañería con otra consulta.

## Si el hosting no deja salir

> **Descartado como camino principal el 23 de agosto de 2026**, porque se
> comprobó que sí deja: ver «Lo comprobado en el servidor». Se conserva escrito
> por lo que dice el último párrafo —los puntos rojos siguen valiendo la pena
> aunque el push funcione— y porque el día que un colegio nuevo tenga otro
> hosting, esta es la salida.

Plan B, sin push y sin sondeo: **«novedades al abrir»**. Un solo endpoint
barato, `GET novedades`, que devuelve **contadores** desde la última vez que ese
usuario miró —«3 notas nuevas, 1 ausencia»— y que la app pide **solo al abrirse
o al volver del segundo plano**, nunca en un temporizador. Se pintan como puntos
rojos en el menú.

No avisa con el teléfono en el bolsillo, que es medio punto de todo esto. Pero
es una consulta por sesión y por usuario en vez de una cada cinco minutos, y se
puede montar sin Firebase, sin cron y sin cuenta de Apple.

Merece la pena tenerlo presente también como **complemento**: los puntos rojos
dentro de la app son útiles aunque el push funcione, porque contestan a «¿qué me
perdí?» cuando el aviso se descartó sin leerlo.
