# Votar desde la app

Escrito el 22 de septiembre de 2026, contra el rediseño del módulo de votaciones de `8myvc`
de ese mismo día: **`8myvc/docs/migracion/11-votaciones.md` §8**, `routes/api/votaciones.php`,
`VtVotacionesController`, `VtCandidatosController`, `VtVotosController` y
`VtResultadosController`.

**Hasta hoy esta app no tenía nada de votaciones**: cero pantallas, cero modelos, cero
llamadas, cero líneas en `docs/`. Los aciertos de `grep candidato` en el repo eran todos de
disciplina. Lo que hay ahora son **seis pantallas escritas y apagadas** detrás de
`Interruptores.votaciones`.

---

## 0. Por qué votar tiene que poder hacerse desde el teléfono

Quien vota es **un muchacho de sexto en un patio**, o una mamá desde el bus, o un docente entre
dos clases. La web de `app2` sirve para **armar** la elección —los cargos, los candidatos, el
censo, las mesas, las actas— y para el tablero de rectoría. No sirve para votar: nadie abre un
computador para marcar una casilla.

Y hay una consecuencia que no es de comodidad. El día de la elección, la participación se
decide en las dos primeras horas de la mañana, y lo que hay en la mano a esa hora es el
teléfono. **Una urna que no está donde está la gente es una urna a la que hay que arrear a la
gente**, y eso es lo que el colegio hace hoy a gritos por los salones.

El backend ya está del lado de esto: `votos/store` y `votaciones/en-accion-inscrito` son **las
dos únicas rutas del módulo sin `auth.personal`**, y su comentario en `routes/` lo dice con
todas las letras —*«lo que la pantalla de votar necesita y por eso se queda abierto»*—.

---

## 1. Las seis pantallas

Cada línea: **qué ve · qué toca · qué queda escrito.**

| # | Pantalla | Dónde vive | Qué pasa |
|---|---|---|---|
| 01 | **La tarjeta de la portada** | [TarjetaDeVotacion](../lib/Widgets/TarjetaDeVotacion.dart), dentro de [MuroScreen](../lib/Screens/MuroScreen.dart) | Arriba del muro: «Hoy se vota», el nombre de la elección, cuándo cierra, la etiqueta verde «Abierta» y un botón grande «Votar ahora». **No cuesta ninguna petición** |
| 02 | **El aviso que se abre solo** | [HojaHoySeVota](../lib/Widgets/HojaHoySeVota.dart) | Un `showModalBottomSheet` encima de la portada: icono grande, «Hoy se vota», **los cargos con su estado**, «Empezar» y «Ahora no» |
| 03 | **El tarjetón**, un cargo por pantalla | [TarjetonScreen](../lib/Screens/TarjetonScreen.dart) | Cabecera con el cargo, «Voto 1 de 2» y barra de progreso. Una tarjeta por candidato: avatar de 76 px, número en una chapa, nombre, grupo y plancha. Abajo, «Votar en blanco» y el aviso de que no se puede cambiar |
| 04 | **La confirmación** | [HojaConfirmarVoto](../lib/Widgets/HojaConfirmarVoto.dart) | Bottom sheet: avatar enorme, «¿Tu voto es para X?», el aviso ámbar de que no se puede cambiar ni repetir y que nadie del colegio puede verlo, y dos botones |
| 05 | **«Ya votaste»** | [YaVotasteScreen](../lib/Screens/YaVotasteScreen.dart) | ✓ verde grande, la hora, los cargos con su etiqueta «Votado», y la frase de que **ni siquiera ahí** aparece por quién votó. Más los resultados: el botón si están publicados, el aviso si no |
| 06 | **Los resultados** | [ResultadosVotacionScreen](../lib/Screens/ResultadosVotacionScreen.dart) | Dos cifras arriba —votos contados y participación— y, por cargo, barras horizontales moradas con avatar, nombre, número y porcentaje. El ganador con etiqueta, el blanco en gris, y el papel avisado aparte en ámbar |

Debajo: [VotacionesApi](../lib/Http/VotacionesApi.dart) (la capa de datos),
[VotacionModel](../lib/Models/VotacionModel.dart) (las nueve formas del contrato),
[VotacionPendiente](../lib/Utils/VotacionPendiente.dart) (el dato del login) y
[EstiloVotaciones](../lib/Utils/EstiloVotaciones.dart) (los tokens y las etiquetas).

---

## 2. Las doce decisiones de diseño, y por qué

### 2.1 · El aviso se dispara con un dato que ya está en la respuesta del login

Es la decisión que sostiene las dos primeras pantallas. La app **no pregunta** si hay elección
abierta: lo sabe.

`App\Services\VotacionesPendientes` —que llaman `POST /api/login` y `GET /api/auth/me`, el
mismo código en los dos a propósito— mira las elecciones abiertas en las que esta persona vota,
comprueba cargo por cargo si ya votó, y **cuelga del contexto del usuario sólo las que le
faltan**, en la clave `votaciones`. Y la clave **no aparece cuando no hay ninguna**; eso está
escrito como contrato en su docblock:

> *«No se pone a lista vacía cuando no las hay, y eso es contrato: el frontend comprueba la
> existencia de la clave, no su longitud.»*

Así que la pregunta *«¿hay que avisarle hoy?»* se contesta con **una clave de una respuesta que
la app ya pide para entrar**. Cero peticiones, cero rutas nuevas, y cero carga extra el día que
ochocientos teléfonos abren la app en el mismo medio minuto — que es justo el pico que este
proyecto lleva un año evitando en un hosting compartido (ver `backend-pendiente.md` §5).

La app lo toma en `LoginController.tomarUsuarioDe`, que es **el único sitio por el que pasan las
dos formas de entrar** —con contraseña y recuperando la sesión guardada—, así que ninguna se lo
salta. Es el mismo enganche que ya usan `ContextoAcademico` y `VersionMinima`.

### 2.2 · El aviso se abre solo, y no se vuelve una plaga por tres motivos

**Se abre solo** porque la jornada dura un día: una tarjeta en el muro la ve quien mira el muro,
un aviso encima lo ve quien abre la app. La diferencia entre las dos cosas es la participación,
que es el número que el colegio mira al final del día.

Y **no reaparece en bucle** por tres razones, ninguna de las cuales es un contador de días:

1. **Sólo si hay algo que votar**, y lo dice el servidor (§2.1), no una regla escrita aquí.
2. **Una vez por sesión, y la marca se pone AL ABRIRLO, no al cerrarlo.** Puesta al cerrarlo,
   un aviso que se cierra deslizando —sin tocar ninguno de los dos botones— volvería a salir en
   el siguiente refresco del muro. Ése es el bucle de verdad, y es el que se da en la práctica:
   la gente cierra las hojas deslizando.
3. **Al votar desaparece.** El tarjetón avisa a `VotacionPendiente` cuando la papeleta se acaba,
   así que no vuelve ni con la sesión abierta.

**La marca no se guarda en el teléfono**, al revés que la de `OfrecerAvisos`. Aquélla se gasta
una vez en la vida del aparato porque Android sólo deja preguntar una vez por el permiso; ésta
tiene que **volver mañana**, y volver cuando entre otra persona en la misma tablet.

Va **después** de `OfrecerAvisos.siToca` en `MuroScreen`, y no antes: las dos son hojas encima
del muro y dos a la vez no se pueden leer.

### 2.3 · El titular de la tarjeta son las palabras del colegio, no «personero»

El encargo pedía «Hoy se elige personero». **No se puede escribir eso, y el motivo es del
contrato**: las filas que cuelga el servicio del login son `vt_votaciones` **sin sus
`aspiraciones` dentro**. La tarjeta no ha leído ningún cargo.

Así que el titular es `HOY SE VOTA` y debajo va `vt_votaciones.nombre`, que es lo que el colegio
escribió. Hay colegios que el mismo día eligen contralor, o representante de grupo, o los tres;
cablear «personero» sería decirle a uno de ellos algo que no está pasando. Es la misma regla de
`estaciones.md` §2.8: **el vocabulario lo pone el colegio y la app no lo cablea**.

Los cargos concretos salen en el aviso (02) y en el tarjetón (03), que sí piden la papeleta.

### 2.4 · No hay cuenta atrás de horas, porque `fecha_fin` es un `date`

`vt_votaciones.fecha_inicio` y `fecha_fin` son columnas **`date`, no `datetime`**, y
`VtVotacion::exigirUrnaAbierta()` las compara contra `Reloj::ahora()->toDateString()` — o sea que
**el día entero cuenta y los dos extremos entran**: una elección con `fecha_fin` hoy se vota hoy
hasta la noche.

Con eso, lo más fino que se puede decir con verdad es el día: «Cierra hoy», «Cierra mañana»,
«Cierra en 3 días». Un «faltan 2 h 15 m» sería **inventarse una precisión que el servidor no
tiene**, y el día que el reloj del teléfono vaya adelantado, mentir con dos decimales.

Nulas significan «sin ventana», que no es «empieza y acaba hoy» — la versión vieja del backend
metía la fecha de hoy en las dos cuando no venían, y eso ya no pasa. Se dice «Sin fecha de
cierre».

### 2.5 · Un cargo por pantalla, y la confirmación antes y no el deshacer después

En las estaciones hay **deshacer durante ocho segundos** (`estaciones.md` §2.7). Aquí no lo hay,
y la ausencia es deliberada: **el voto es inmutable y lo garantiza la base de datos**, con el
índice único `vt_votos_un_voto_por_cargo`. `verificarNoVoto()` —que borraba el voto anterior y
dejaba cambiarlo, la avería del §3 de la 11— ya no existe.

**No hay nada que deshacer después, así que el paso va antes.** De ahí las dos cosas:

- **Un cargo por pantalla**, porque una lista larga con cuatro elecciones dentro invita a bajar
  deprisa y tocar de más. Y porque en un teléfono una rejilla de caras de 76 px con cuatro
  cargos encima no cabe sin hacer las caras pequeñas — **y la cara es el dato**: en sexto se
  reconoce a quien se vota por la foto antes que por el nombre.
- **La confirmación en su propia hoja**, con el avatar enorme, porque quien confirma ya eligió y
  lo que necesita es reconocer que es el que eligió.

### 2.6 · Las tres frases del aviso ámbar son tres cosas distintas

No es un párrafo de relleno: cada línea contesta una pregunta que se hace en voz alta el día de
la elección, y las tres se preguntan por separado.

1. **No se puede cambiar** — el índice único.
2. **No se puede repetir** — el mismo índice dicho al revés. *«Me equivoqué, ¿lo cambio?»* y *«ya
   voté, ¿puedo otra vez?»* son dos preguntas y las hacen dos personas distintas.
3. **Nadie del colegio puede ver por quién votaste** — y esto es **verdad del servidor**, no una
   promesa de la pantalla. Ver §2.7.

### 2.7 · El secreto del voto se dice en la pantalla porque es verdad en el servidor

> *«Ni siquiera aquí aparece por quién votaste.»*

Está en la 05 y se puede escribir porque el contrato lo sostiene, pieza por pieza:

- `candidatos/conaspiraciones` y `votaciones/en-accion-inscrito` devuelven `votado` como
  **booleano**, a propósito: *«lo que se mira es si votó, nunca a quién»*.
- **`GET votos` está borrada.** Entregaba la tabla entera de votos con el `user_id` de cada uno a
  cualquiera con `auth.personal`.
- La lista nominal sale por **una sola puerta**, `auditoria/{id}`, que exige
  `Autoriza::esSuperusuario()` —y no `puedeVerAuditoria()`, cuya migración siembra el permiso a
  rectoría y coordinación— y **queda registrada a nombre de quien miró**: la única lectura del
  sistema que se audita.

Decirlo no es adorno. **Quien no sabe si el sistema guarda su voto con su nombre vota distinto**,
y un sistema que es secreto y no lo parece no es secreto para quien lo usa.

### 2.8 · La hora del voto sale de lo que pasó, no de una consulta

Consecuencia directa del §2.7: **no hay ninguna ruta que le diga a una persona a qué hora
votó**. `votos/show` devuelve papeletas, los dos endpoints de la papeleta devuelven booleanos, y
la lista nominal es del superusuario.

La hora llega por dos caminos, los dos de `votos/store`:

- **201** — el voto entró, y vuelve la fila con su `created_at`.
- **409** — ya había votado ese cargo, y vuelve `voto` con la constancia dentro: `created_at`, el
  cargo, y la mesa y el asistente si lo condujo alguien.

Así que la 05 pinta la hora **de los cargos cuya constancia conoce**, y para los que venían
votados de antes dice «Votado» sin hora. Es todo lo que el contrato sabe, y **decirlo a medias es
mejor que inventarse un reloj**.

### 2.9 · La hora del voto llega en UTC, y es la única columna del sistema que lo hace

**`vt_votos.created_at` se sella en UTC** mientras el resto de la plataforma guarda hora de
Bogotá. Está escrito a propósito en el backend (`RelojUnicoTest::SELLAN_EN_UTC`) y su §8 decide
**no** arreglarlo allí —ponerle `SellaConElReloj` metería dos relojes en la misma columna— y dejar
la conversión al front: *«lo barato es convertir en el front»*.

Son **cinco horas**. Sin restarlas, un voto de las 8:15 de la mañana se pinta **a la 1:15 de la
tarde**: una hora perfectamente creíble, que es lo que hace que el error no se note.

Lo hace `horaDeUnVotoEnBogota` en [FechaServidor](../lib/Utils/FechaServidor.dart), y es
**la excepción a la regla que ese archivo ya tenía escrita** —*«el backend guarda la hora de
Bogotá y la serializa con una Z al final, así que Dart la lee como UTC: leerla tal cual devuelve
la hora que se guardó»*—. Dos detalles de esa función, los dos con motivo:

- **Se restan cinco a mano y no se llama a `toLocal()`.** Son dieciséis colegios colombianos, o
  sea UTC−5 siempre y sin horario de verano; `toLocal()` daría la zona del teléfono, y una tablet
  compartida con la zona mal puesta pintaría la hora de otro sitio.
- **Admite las dos formas** en las que esa columna llega: `postStore` devuelve el modelo y la
  serializa con Z, y la constancia del 409 sale de `DB::select`, o sea el datetime crudo de MySQL
  sin Z — que Dart leería como local.

### 2.10 · Los cuatro rechazos de `votos/store` hacen cuatro cosas distintas

`votos/store` **ya no devuelve 200 con un `msg` dentro**. Y esto ya se hizo mal una vez, en el
otro front: `app2` tenía una lista de códigos cuyo cuerpo se enseña al usuario y **no incluía 409
ni 423**, así que todos los mensajes que el rediseño escribió con cuidado salían como «No se pudo
guardar.» (11 §8) — el mismo modo de fallo que se vino a quitar del backend, reaparecido en la
pantalla.

Aquí **el texto que se lee es el del servidor**, siempre que lo haya, y cada código hace algo
distinto:

| Código | Qué es | Qué hace la pantalla |
|---|---|---|
| **201** | El voto entró | Apunta la constancia y pasa al cargo siguiente |
| **409** | Ya votó ese cargo | **No es una avería**: se dice, se apunta la constancia —con su hora— y **se sigue**. Reintentar no tiene sentido |
| **423** | Urna pausada, cerrada o fuera de fechas | Se sale del tarjetón con el motivo delante: reintentar no sirve hasta que el colegio la abra |
| **403** | No le corresponde | Su estamento no vota, no está en el censo, o su grupo vota en su mesa. Se sale con el motivo |
| **422** | Validación | El cargo o el candidato no son de esta votación. **Se queda donde está**: es lo único que puede arreglarse volviendo a intentar |

El respaldo por código sólo entra cuando el servidor cortó sin explicarse, por lo mismo que
`motivoDeRechazo` existe: **quien calcula la regla es quien sabe decirla**, y una frase escrita
en la app envejece en silencio el día que la regla del servidor cambie.

Y **se comprueba `== 201` y no «2xx»**: un 200 de un servidor sin desplegar significa otra
cosa —reemplazó el voto anterior— y leerlo como éxito sería lo peor que podría pasar aquí.

### 2.11 · El voto en blanco no es un candidato, y su foto es una trampa

El blanco es `aspiracion_id` **sin `candidato_id`**; `blanco_aspiracion_id`, la columna que lo
separaba, se fue con la migración del 22 de septiembre.

El servidor lo mete **en la misma lista de candidatos**, con `voto_blanco: true`. La app lo saca
de ahí y le da su propio botón abajo, por dos motivos: en el contrato tampoco es un candidato, y
puesto entre las caras es una opción más que se toca por descuido al bajar. Abajo es una decisión
que se toma.

**Y su `foto_nombre` es una trampa medida, no una precaución.** El servidor manda
`foto_nombre: 'voto_en_blanco.jpg'`, que es un archivo del front web y **no existe en
`images/perfil`**. Pasado a `AvatarPersona` eso no falla —y por eso es peligroso—: se cae a las
iniciales y pinta un círculo morado con **«VE»** dentro, que se lee como una persona que no
existe. Por eso el blanco tiene su propio círculo, gris y con icono, en
`CirculoDeCandidato`.

En los resultados va **al final y en gris**, y **cuenta en el total**: es una casilla de la urna,
como cuenta en una urna de verdad. Dejarlo fuera del total era la mitad del bug del módulo
viejo — un cargo con 40 votos y 8 blancos decía «total 32», y los porcentajes de los candidatos
salían de ese 32, o sea inflados uno por uno.

### 2.12 · Sin conteo publicado no se pintan ceros

`GET resultados/{id}` tiene **dos formas y las dos son correctas**. Con `conteo_visible: false`
devuelve la estructura —cargos y candidatos— y **ni un número**: ni el del candidato, ni el
blanco, ni el total, ni la participación.

Eso **no es una elección sin votos**: es una elección cuyo conteo **rectoría no ha publicado**, y
el campo existe justamente para que la pantalla sepa por qué no hay números. Un cero es una
afirmación: «Personero: 0 votos» le dice a un colegio de ochocientos que nadie fue a votar, y
eso, un día de elección, es la mentira más cara que esta pantalla podría contar.

Así que con `conteo_visible: false` se enseña **un aviso ámbar que dice quién los publica** —que
es enseñar a quién preguntarle— y la lista de cargos y candidatos, sin barras y sin cifras. Lo
mismo en la 05: botón «Ver resultados» cuando `can_see_results` está encendido, y el aviso cuando
no.

Y hay una excepción que es la mitad de la regla, que la app **no** implementa porque es del
servidor: al personal del colegio se le dan los conteos siempre. El interruptor existe para que
los alumnos no vean el marcador en vivo mientras se vota, no para que el rector no pueda mirar su
propia elección.

### 2.13 · Las dos cifras de arriba son dos cosas y por eso son dos

**Votos contados** son filas de la urna, y una persona echa varias —una por cargo—.
**Participación** son personas del censo. Enseñar sólo la primera hace que un colegio de
ochocientos lea «3.200 votos» y crea que votó cuatro veces su matrícula.

Y el papel se dice **aparte y en ámbar**, nunca escondido dentro del total, porque **63 papeletas
no son 63 personas**: de un montón de papeletas no se saca quién votó qué, así que el papel suma
en los votos y **no entra en el porcentaje de participación**. Un colegio que sume las columnas y
encuentre un descuadre tiene que poder leer de dónde sale. El desglose viaja además por
candidato: **un candidato con 63 votos de los que 60 son de una sola acta es un dato distinto** de
uno con 63 repartidos.

---

## 3. La forma, y por qué se ve así

- **Un solo morado para los dieciséis**, `#6A62B7`, que es el `kPrimaryColor` de siempre.
  **No hay color por colegio y no hay modo oscuro**, y ninguna de las dos ausencias es un
  olvido: una urna que cambia de color según el colegio hay que mantenerla dieciséis veces, y un
  modo oscuro que nadie ha pedido es una segunda pantalla que revisar entera cada vez que se toca
  la primera. **No se añade `ThemeData` ni `darkTheme`.**
- **Fondo `#F4F5F7`, tarjetas blancas de radio 12, borde `rgba(0,0,0,.07)` y sin sombra.** El
  borde y no la sombra está escrito en [PaletaEstaciones](../lib/Utils/PaletaEstaciones.dart) y
  vale igual aquí: se vota en el patio, y **una sombra a media luz no se ve, un borde sí**. El
  fondo es el del muro y no el de las estaciones, porque la tarjeta nace encima del muro: que
  compartan el gris es lo que hace que se lean como un sitio y no como dos apps.
- **Fuente del sistema.** No se añade ninguna.
- **Todo estado lleva color, icono y palabra**, nunca sólo color. Por eso `EstadoDeLaUrna` y
  `EstadoDelCargo` **no exponen un color suelto**: exponen los tres, y `EtiquetaDeEstado` los
  pinta juntos — quien los use no puede coger sólo uno sin darse cuenta.
- **Objetivos de toque de 56 px** en todo lo que decide algo. Y la tarjeta de un candidato es
  más grande que eso a propósito: apuntar a un círculo de 76 px con el pulgar, de pie, no es lo
  mismo que tocar una tarjeta de 100 px de alto.
- **El avatar del tarjetón, 76 px** (radio 38). La cara es el dato con el que un muchacho
  reconoce a quien vota, más que el nombre.
- **El número en una chapa redonda**, como la del pecho de una camiseta: en el tarjetón de papel
  el número es lo que se marca. Se pinta **como texto y no como entero** porque
  `vt_candidatos.numero` es `varchar` y un colegio puede escribir «01».
- **Avatares circulares con iniciales blancas sobre morado** cuando no hay foto, como hace
  [AvatarPersona](../lib/Widgets/AvatarPersona.dart). En los resultados **son siempre iniciales**,
  y no por descuido: el escrutinio no manda `foto_nombre` —`candidatosDe()` devuelve nombre,
  apellidos, plancha y número—, y pedir las fotos una por una serían veinte peticiones para
  adornar un recuento.
- **La tarjeta elegida cambia el BORDE, no el relleno.** Un relleno morado claro detrás de un
  nombre le quita contraste al texto justo cuando más falta hace leerlo; un borde de dos píxeles
  se ve a un metro y no toca la legibilidad.
- **Cargando**: `CircularProgressIndicator` centrado. **Vacío**: icono outline en `black26` y
  texto en `black54`. **Error**: título en negrita, el mensaje del servidor y un botón
  «Reintentar». **Listas con `RefreshIndicator`.**
- **El ganador sólo lleva etiqueta si hay uno.** Con empate arriba, o con todo a cero, no se
  pone: poner la etiqueta a uno de dos empatados es decir en la pantalla algo que el escrutinio no
  dice.

---

## 4. El contrato del servidor

### 4.1 · Cuatro rutas, y ninguna más

De las cuarenta y tantas del módulo, esta app usa cuatro:

```
GET   candidatos/conaspiraciones     la papeleta: cargos, candidatos y `votado`
POST  votos/store                    el voto
GET   resultados/{id}                el escrutinio
GET   votaciones/en-accion-inscrito  (leída, no usada — ver 4.3)
```

Las de configuración, censo, mesas, actas y auditoría **son de la web**: se arman sentado, no de
pie. Y `auditoria/{id}` rompe el secreto del voto y es del superusuario, así que no tiene nada
que hacer en una app de bolsillo.

### 4.2 · Las formas exactas, leídas del `return`

**`GET candidatos/conaspiraciones`** → una **lista de cargos** (`vt_aspiraciones`), cada uno con
`candidatos` y `votado` colgados. `votacion_id` viaja en la propia fila, y es de donde sale para
`votos/store`: **esta ruta no devuelve la votación**.

Cada candidato: `candidato_id`, `plancha`, `numero`, `persona_id`, `nombres`, `apellidos`,
`user_id`, `username`, `tipo`, `imagen_id`, `imagen_nombre`, `foto_id`, `foto_nombre`,
`nombre_grupo`, `abrev_grupo`. Más el blanco, que es
`{nombres: 'Voto en Blanco', voto_blanco: true, foto_nombre: 'voto_en_blanco.jpg'}`.

**`POST votos/store`** ← `{votacion_id, aspiracion_id, candidato_id?}`. **No se manda `origen`**,
porque el servidor no se lo cree del cuerpo —lo decide la marca firmada de la mesa, *«porque un
cliente que puede escribir `origen = 'mesa'` puede falsear de dónde salió un voto»*—, **ni
`sesion_mesa`** —conducir una mesa es una pantalla de la web, y de esta app todo voto es
`propio`—, **ni `segundos`**, que existe para la auditoría de las mesas y admite nulo como «no se
sabe».

→ **201** con la fila (`created_at`, y `completo` colgado para que la pantalla sepa si terminó la
papeleta). **409** con `{error: 409, message, voto: <constancia>}`. **423/403/422** con
`{message}`.

**`GET resultados/{id}`** → `{votacion:{id, nombre, year_id, can_see_results}, conteo_visible,
cargos:[...]}`, y con conteo además `origen:{propio, mesa, papel, actas}` y `participacion:{censo,
votantes, otros_votantes, porcentaje, por_grado, papel:{...}}`. Cada cargo:
`{aspiracion_id, aspiracion, abrev, candidatos:[...], blanco, total, origen}`; cada casilla,
`{candidato_id, nombres, apellidos, plancha, numero, blanco, total, origen:{propio,mesa,papel},
porcentaje}`.

**El porcentaje se lee tal cual y no se recalcula**: dos mitades que dividen por su cuenta acaban
enseñando dos porcentajes distintos del mismo cargo.

### 4.3 · Tres trampas de este contrato, y qué hace la app con cada una

1. **`conaspiraciones` devuelve una lista que a veces no es una lista de cargos.** Cuando esta
   persona no tiene elección contesta `[{sin_votaciones_propias: true}]`. Leída como cargos, eso
   da un cargo sin nombre, sin candidatos y con `votado` falso: **un tarjetón fantasma**. Y esa
   forma existe porque la alternativa —una lista vacía— **no distingue «no hay elección» de
   «elección sin cargos»**, que son dos cosas y hay que decirlas distinto. `Papeleta` las separa
   en `sinEleccion` y `cargos` vacío.
2. **`votado` fue `[]` hasta el 22 de septiembre**, y `[]` en JavaScript es cierto: el front web
   llevaba años creyendo que estaba todo votado. Ahora es un booleano de verdad, y aquí se lee con
   `siONo` —que no se cree el tipo— para que un `0`, un `"1"` o un `null` no se lean al revés.
3. **`votaciones/en-accion-inscrito` trae el conteo en vivo dentro** —`cantidad` y `total` por
   candidato—, aunque el colegio no haya publicado los resultados: es lo que queda del §1 de la
   11, recortado en `votos/show` pero no ahí. Por eso esta app **no usa esa ruta para la
   papeleta** y usa `conaspiraciones`, que no lo trae; y ningún modelo tiene sitio donde guardar
   esos dos campos, así que no hay forma de pintarlos por descuido.

Y una que no es trampa pero conviene saber: **`porAspiracion()` une sólo con `alumnos`**, así que
un profesor no puede salir en la papeleta aunque `votan_profes` exista (11 §8).

---

## 5. Por dónde se empieza

**Nada de esto se enciende hasta que las seis migraciones del rediseño estén corridas en los
dieciséis**, y eso es lo primero. `Interruptores.votaciones` es `false` y lo que espera **no es
una decisión: es un despliegue** — pero uno más delicado que los de siempre:

1. **El despliegue, colegio por colegio.** Seis migraciones, y **dos destructivas**: la `400000`
   tira `vt_participantes` y la `600000` borra filas de `vt_votos`. Autorizado por Joseth el 22 de
   septiembre —*«las votaciones se pueden ignorar, y si las llegan a necesitar las sacamos de un
   backup; ellos nunca miran las votaciones de años pasados»*—. Se comprueba **por el hash de la
   tanda, no por `main`**.
2. **Encender el interruptor y publicar la app.** En ese orden: encender antes del despliegue
   rompe a los colegios rezagados, y con `en-accion-inscrito` el fallo **no es un 404 sino un
   500**, porque hasta la migración esa ruta lee una columna tirada.
3. **Probarlo a mano**, con una elección de verdad en el docker o en `demo`: la papeleta, el voto,
   el 409 al repetir, y los resultados con y sin `can_see_results`.
4. **Y después, las pruebas.** Van al final por decisión de Joseth, y hay una razón técnica que
   las hace valer más aquí: con `Interruptores.votaciones` en `const false`, **todo lo que hay
   detrás de la guarda es código que ninguna prueba alcanza**. Las lecturas se dejaron públicas y
   separadas de la petición —`leerLaPapeleta`— justo para que se puedan probar sin encender nada,
   que es el mismo motivo por el que `leerLasEstaciones` está así.

**Lo que NO hace falta esperar:** ni push, ni cámara, ni un permiso nuevo, ni un paquete nuevo en
`pubspec.yaml`. El módulo entero son seis pantallas, cuatro rutas y lo que ya está en el login.

---

## 6. Lo que falta decidir, y no lo decide esta app

1. **`in_action` como candado, que está sin cerrar en el backend.** Hasta el 21 de agosto era
   *«un redirector del front, no un candado»*, con decisión escrita; el encargo del 22 de
   septiembre pidió lo contrario y hoy votar con eso apagado contesta **423**. Está preparado para
   revertirse —vive en un solo `if` de `VtVotacion::exigirUrnaAbierta()`— y **esta app no da por
   hecho que se queda**: `pareceAbierta` sirve para no ofrecer un botón condenado, pero **lo que
   niega de verdad es `votos/store`** y su mensaje es el que se enseña. Si el `if` se borra, aquí
   no hay que tocar nada.
2. **Las mesas no están en la app, y es una decisión pendiente, no un olvido.** `mesas/{id}/abrir`
   existe para el niño de preescolar que no teclea su contraseña: alguien le abre la papeleta, hay
   cuenta atrás para que se aparte, y el voto guarda **dos personas**. Eso es una pantalla de
   conducir y no de votar, con su cuenta atrás y su doble llave, y **nadie ha dicho todavía si la
   mesa la lleva un docente con su teléfono o con el computador del salón**. Cuando se decida, es
   un módulo aparte con su propio interruptor: el titular que conduce una mesa **no está votando**.
3. **Los resultados por grado no se pintan**, aunque `participacion.por_grado` viene en la
   respuesta. En una pantalla de teléfono son N barras más debajo de las que importan, y quien
   compara grados es rectoría, sentada, en la web. Está leído en el contrato y **no en el
   modelo**: el día que se pida, es un campo y una lista.
4. **Una elección sin `fecha_fin` no dice cuándo cierra**, y se dice así. Lo que haría falta para
   decir algo mejor es un dato que hoy no existe, no una pantalla.
