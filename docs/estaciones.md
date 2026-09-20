# Las estaciones de matrícula, desde la app

**Todo este documento es propuesta de diseño**, escrita el 20 de septiembre de 2026 sobre el
plan que ya existe: `myvc_front/INVESTIGACION-MATRICULAS.md` (el embudo y el modelo de datos)
y `myvc_front/PANTALLAS-MATRICULA.md` (las quince pantallas y los seis roles). Aquello puso
las estaciones **en `app2`, o sea en la web**. Esto contesta la pregunta que quedaba:
**cómo atiende una estación alguien que solo tiene el teléfono en la mano.**

**Maqueta navegable de las once pantallas:**
https://claude.ai/artifact/3fixY3xaQsjGT2V4LAWPbE

---

## 0. Por qué la estación tiene que ser la app y no la web

Lo contó Joseth y está citado en `PANTALLAS-MATRICULA.md` §0:

> *«Las siguientes estaciones están marcadas con números impresos. Cuando termina con la
> estación documentos, el profesor que atendió busca al alumno en el sistema y chulea el
> requisito "Documentos".»*

Quien atiende la estación 2 es **un docente de pie en un aula, con una fila delante y papeles
en la otra mano**. No tiene un computador; tiene el teléfono con el que ya toma asistencia.
La web de `app2` sirve para **armar** el recorrido y para el tablero del rector; no sirve para
el patio.

Y hay una consecuencia que no es de comodidad: **la app es una sola para los dieciséis
colegios** y una versión vieja convive meses (`docs/estado.md`). Lo que se diseñe aquí tiene
que funcionar cuando el colegio de al lado tiene otras estaciones, otros nombres y otro
número de pasos — y cuando el teléfono que lo abre es de hace tres versiones.

---

## 1. El recorrido del que atiende, en once pantallas

Cada línea: **qué ve · qué toca · qué queda escrito · a quién le pasa el turno.**

| # | Pantalla | Quién | Qué pasa |
|---|---|---|---|
| 01 | **Elegir estación** | cualquiera del personal | El colegio configuró N estaciones; solo se abren las que esa persona puede cerrar. Se recuerda: mañana la app abre ahí |
| 02 | **Mi estación · me llegan** | el que atiende | La cola acumulada: los que cerraron la estación anterior y no han cerrado la mía. Arriba, tres cifras: atendidos, esperando, espera media |
| 03 | **Escanear la hoja de ruta** | el que atiende | El QR del papel que trae la familia. O se teclea el código (`2027-4K7M2`), que es el de `docs/migracion/41` |
| 04 | **La ficha en la estación** | el que atiende | Quién es, la barra de los N pasos, y **solo lo que cierra él** con los controles grandes |
| 05 | **Cerrar el paso** | el que atiende | Cumple · cumple con observación · devolver. Y **a quién se va a avisar, antes de confirmar** |
| 06 | **Devolver con motivo** | el que atiende | El motivo es obligatorio: sin texto el botón no se enciende |
| 07 | **Listo** | el que atiende | A qué estación pasa, dónde queda, qué le llegó a la familia, y **deshacer durante 8 segundos** |
| 08 | **El que llega salteado** | cualquier estación | «No lo atiendas todavía: le falta la 1». Lo dice la pantalla, no el profesor |
| 09 | **Sin señal** | el que atiende | Se sigue atendiendo. Lo marcado espera en el teléfono, y **se ve que espera** |
| 10 | **Buscar** | cualquiera del personal | Todo el colegio, no solo la cola: nombre, apellido, documento o código |
| 11 | **El recorrido completo** | cualquiera del personal | Los N pasos de esa persona con quién los cerró y cuándo. Solo lectura |

---

## 2. Las nueve decisiones de diseño, y por qué

### 2.1 · La cola es una CONSULTA, no una bandeja de avisos

Es la decisión que sostiene todas las demás. La cola de la estación 3 no se llena con los
mensajes que le manda la estación 2: **se calcula** —«los que tienen cerrado el paso 2 y
abierto el 3»— cada vez que se pide.

La diferencia se ve el día que algo falla. Una bandeja de avisos con un aviso perdido deja a
una familia **invisible para siempre** y nadie sabe que falta; una consulta con un aviso
perdido deja a la familia en la fila **igual**, solo que la pantalla tardó en enterarse. Un
sistema que se repara solo contra uno que acumula agujeros en silencio.

Por eso la pantalla 02 no tiene «marcar como leído» ni nada que haya que vaciar: **no hay nada
que vaciar**, hay una pregunta que se vuelve a hacer.

### 2.2 · El aviso a la estación siguiente son DOS cosas, y hoy solo una es posible

**Medido el 20 sep 2026 en `pubspec.yaml`:** la app tiene `firebase_core` y
`firebase_analytics` y **no tiene `firebase_messaging`**. El lado del servidor sí está
—el endpoint de temas, el comando `notificaciones:enviar` y su disparo, desplegados desde el
25 ago (`98e6311`, ver `docs/estado.md`)—, pero **el lado Flutter no está empezado**, así que
hoy esta app **no puede recibir un push**.

Y hay un segundo hecho que importa más: **ese disparo va cada quince minutos**. Para avisarle
a un acudiente de que hay notas nuevas, quince minutos es perfecto. Para una fila en un patio,
quince minutos es no avisar.

Así que el aviso se parte en dos, y se dice cuál es cuál:

| | Qué es | Cuándo está |
|---|---|---|
| **La cola, dentro de la app** | La pantalla 02 vuelve a preguntar cada ~20 s mientras está abierta, y siempre al volver de marcar. Es lo que hace aparecer al recién llegado | **Es lo único que hace falta para que el día de matrículas funcione** |
| **El push** | Un tema por estación, publicado **en el momento**, no en la tanda de los quince minutos | Cuando entre el lado Flutter de `notificaciones.md`. No bloquea nada |

**Preguntar cada 20 segundos no puede costar lo que cuesta pedir la cola.** El patrón ya
existe en esta casa y está medido: `GET sincronizacion/huella`
(`8myvc/docs/migracion/34-la-huella-de-sincronizacion.md`) contesta en **345 bytes** si algo
cambió, en vez de los 121 KB que costaba preguntarlo trayéndose los datos. La estación hace lo
mismo: sondea la huella, y **solo cuando se mueve** pide la cola de verdad. Con diez
estaciones abiertas ocho horas son 14.400 peticiones de 300 bytes al día — menos que abrir la
app dos veces.

> **Y cuando el push exista, el que se manda a una estación NO lleva el nombre del menor
> dentro.** Es la regla que ya está escrita en `notificaciones.md`: una notificación se ve en
> la pantalla bloqueada, con gente al lado. «Llegó alguien a tu estación» y se abre la app.

### 2.3 · Antes de confirmar se enseña a quién se avisa

La pantalla 05 dedica un bloque entero a lo que va a pasar **después** de pulsar: a qué
estación pasa, en qué aula queda, cuántos hay delante y **el texto exacto** que le va a llegar
al celular de la mamá.

No es adorno. Quien atiende es responsable de lo que dispara y hoy no tiene forma de saberlo:
en la práctica se lo dice a la familia de viva voz y reza. Enseñar la consecuencia antes del
botón es lo que convierte «chulear un requisito» en «pasar a alguien a la estación 3».

### 2.4 · Devolver siempre lleva motivo escrito, y el botón lo hace cumplir

La pantalla 06 tiene el botón **apagado** hasta que hay texto, y lo dice: *«Sin motivo
escrito, el botón no se enciende»*. Arriba, en rojo: *«lo que escribas aquí lo lee la familia,
tal cual, en su celular»*.

Las tres frases de siempre —falta el certificado, la copia no se lee, falta la firma— son
botones, porque un motivo de un toque es un motivo que sí se escribe. Un desplegable de
motivos cerrados, no: el día que el caso no esté en la lista, se elige el más parecido y la
familia recibe una mentira.

### 2.5 · «Devuélvase a la estación 3» lo dice la pantalla, no el profesor

Pantalla 08. Hoy eso depende de que quien atiende mire bien la hoja; con fila detrás, no mira.
La banda roja ocupa el ancho entero **antes que la ficha**, con el número y el sitio: *«le
falta la Estación 1 · Recepción, en la portería»*.

Tres cosas de esa pantalla que no son evidentes:

- **No escribe nada en el paso.** Registra el intento, que es distinto: sirve para el tablero
  del rector —«en la 4 se presentan doce sin pasar por la 3, el cartel está mal puesto»— sin
  ensuciar el recorrido de la familia.
- **«Atenderlo de todas formas» existe y está apagado.** Un sistema que no puede saltarse su
  propia regla se salta por fuera, en papel, y entonces no hay registro de nada. Lo levanta
  Coordinación caso por caso, y **queda con el nombre de quien lo autorizó**.
- **Mandarlo a la 1 también avisa**: le entra a la cola de Recepción marcado como devuelto, y
  la familia recibe en el celular a dónde tiene que ir. Es el mismo mecanismo de la 2.1 en la
  otra dirección.

### 2.6 · «Marcado aquí» y «guardado» son dos estados distintos, y se ven distintos

Pantalla 09. El patio tiene mala señal y la jornada no se puede parar, así que se sigue
atendiendo con la marca guardada en el teléfono. Lo que **no** se puede hacer es pintarla
igual que una guardada:

- reloj naranja = **marcado aquí, el servidor no lo sabe**
- chulo verde = **el servidor contestó**

Y la pantalla dice la consecuencia en una línea: *«la estación siguiente aún no lo ve: dile a
la familia a dónde va, no esperes al aviso»*. Un verde optimista ahorra un icono y cuesta que
alguien jure que marcó a un alumno que no está marcado.

### 2.7 · Deshacer, ocho segundos

Pantalla 07. En una fila, con dos hermanos apellidados igual, tocar el renglón de al lado pasa
todos los días. Un deshacer de ocho segundos es infinitamente más barato que una corrección de
auditoría, que necesita a alguien con permisos y un rato de teléfono.

Pasados los ocho segundos, corregirlo es **devolver el paso con motivo**, que deja rastro —que
es lo correcto: ahí ya hay otra estación que lo vio.

### 2.8 · Los nombres y los números de las estaciones vienen del servidor. Siempre

*«Todo esto es personalizado por el colegio»* — Joseth. Un colegio tendrá cinco estaciones y
otro tres; uno llamará «Académico» a lo que otro llama «Coordinación». **La app no cablea ni
un nombre ni un número**, y el día que el servidor mande un tipo de paso que esta versión no
conoce, lo pinta con el control genérico —cumple / devolver— en vez de romperse.

Es la regla de siempre de esta app, y aquí muerde más que nunca: **una sola app, dieciséis
colegios, y las versiones viejas viven meses**. Si el colegio no configuró estaciones, la
entrada del menú **no aparece** — no una pantalla vacía que parezca rota.

### 2.9 · Ver todo, cerrar solo lo tuyo

La 10 y la 11 son las que pidió la pregunta original: **buscar en todo el sistema**, no solo
en la cola. Cualquiera del personal puede mirar el recorrido completo de cualquiera —es lo que
ya hace hoy quien se acerca a preguntar «¿y mi hija en qué va?»—, y la ficha se abre en modo
lectura con una línea que lo dice: *«tú atiendes Documentos, y ella ya lo pasó. Cerrar la 4 le
toca a Orientación»*.

**Ver no es cerrar.** Y esa frase hay que hacerla cumplir en el servidor, no en la pantalla:
la app es una sola para dieciséis colegios y el guard de la ruta es lo único que de verdad
protege.

---

## 3. La forma, y por qué se ve así

- **El color de la app** (`kPrimaryColor`, `#6A62B7`) manda; el número de la estación va
  **grande y en blanco sobre él**, porque el cartel impreso del patio dice «2» y lo primero
  que hay que poder comprobar de un vistazo es que estás en la estación que crees.
- **Cuatro estados, y ninguno se distingue solo por el color**: cada uno lleva icono y
  palabra. Verde `#1E7A55` cumplido, ámbar `#8A4B00` en revisión u observación, rojo
  `#B8342A` devuelto o bloqueado, gris `#6E6B7B` pendiente. Es por el sol del patio y por
  quien no distingue el rojo del verde, que en un claustro de cincuenta docentes es uno o dos.
- **Objetivos de toque de 56 px** en todo lo que decide algo, y los destructivos separados del
  principal. Se toca de pie, con una mano, a veces con guantes de frío en tierra fría.
- **La barra de pasos es horizontal en la ficha** (de un vistazo, ¿dónde va?) y **vertical en
  la consulta** (con quién y cuándo, que es leer, no mirar).
- **La tipografía**: Archivo para los números y los títulos —sus cifras se leen de lejos— y
  Source Sans 3 para el texto. En la app se resuelve con el peso y el tamaño; lo de la maqueta
  es para que el diseño se lea en pantalla grande.
- **En tablet** esto es maestro-detalle, no una columna estirada: la cola a la izquierda y la
  ficha a la derecha. Es el «problema 2» de `docs/tablets.md` y **la estación es el caso donde
  más se nota**, porque la tablet del colegio es justo lo que hay en el patio.

---

## 4. Lo que el servidor tiene que poner, y lo que ya está

### 4.1 · Lo que ya existe, medido el 20 sep 2026

- **Las dos tablas de la lista de chequeo**, en
  `8myvc/database/schema/mysql-schema.sql`: `requisitos_matricula`
  (`year_id, orden, requisito, descripcion, editable_por_profe_id`) y `requisitos_alumno`
  (`alumno_id, requisito_id, estado` por defecto `'Falta'`, `descripcion, updated_by`).
- **Seis rutas** de `requisitos/*` con `auth.personal`
  (`8myvc/app/Http/Controllers/Matriculas/RequisitosController.php`).
- **La búsqueda de personas**: `PUT buscar/por-nombre` y `PUT buscar/por-apellido`, las dos
  con `auth.personal`. La pantalla 10 se apoya en ellas.
- **El código del formulario y su QR**: `docs/migracion/41-el-formulario-de-inscripcion.md`,
  diez rutas ya escritas y probadas. La pantalla 03 lee **ese** código, no inventa otro.

### 4.2 · Un aviso que hay que resolver antes de construir la 02

**`requisitos_alumno.estado` es un `varchar` sin vocabulario cerrado, y `postAlumno` escribe
tal cual lo que venga en el cuerpo.** Hoy el valor por defecto es `'Falta'` y lo demás lo
decide cada llamante — hay tres pantallas escribiendo ahí. Una cola que pregunta *«¿está
cerrado el paso 2?»* **no se puede construir encima de una columna cuyo conjunto de valores no
está fijado**: el día que una pantalla vieja escriba `'cumple'` en minúscula, la persona
desaparece de la fila de la estación siguiente y nadie se entera.

Es lo primero que hay que cerrar, y es del backend: **fijar los estados, migrar lo que haya
escrito y rechazar lo que no esté en la lista**. No es trabajo de esta app.

### 4.3 · El contrato que la app necesita — siete rutas, PROPUESTA

Está escrito, con sus porqués y con lo que mueve, en
**`8myvc/docs/migracion/44-las-estaciones-en-la-app.md`**. En resumen:

```
GET  estaciones                     el recorrido del colegio y cuál atiendo yo
GET  estaciones/{n}/cola            los que me llegan
GET  estaciones/huella              ~300 bytes: ¿cambió algo?
GET  estaciones/alumno/{id}         la ficha: los N pasos + lo mío
GET  estaciones/codigo/{codigo}     lo mismo, por el QR de la hoja
PUT  estaciones/{n}/marcar          cumple | observación | devolver(motivo)
PUT  estaciones/{n}/enviar-a/{m}    el salteado: registra el intento y avisa
```

**Siete rutas son una decisión, no un efecto secundario**, y las autoriza Joseth con el precio
delante. Ninguna de las once pantallas de aquí arriba se puede empezar antes de eso.

---

## 5. Por dónde se empieza

**Nada de esto depende de la pasarela, ni del portal de la familia, ni del push.** Es la
Fase 1 de `INVESTIGACION-MATRICULAS.md` §9, rendida en el teléfono:

1. **El backend cierra el vocabulario de `estado`** (§4.2) y ensancha las dos tablas con
   `estacion_nro`, `rol_id`, `obligatorio` y `bloquea`.
2. **Las siete rutas** (§4.3).
3. **Pantallas 01, 02, 04, 05, 07** — con eso ya se atiende una estación entera, y el día de
   matrículas funciona.
4. **06, 08** — el motivo y el salteado, que son las que ahorran el tiempo de verdad.
5. **03** (el QR), **10 y 11** (buscar y mirar), **09** (sin señal).
6. El push inmediato por estación, cuando entre el lado Flutter de `notificaciones.md`.

## 6. Lo que falta decidir, y no lo decide esta app

1. **¿Quién puede atender una estación?** El plan dice «rol»; la tabla de hoy tiene
   `editable_por_profe_id`, que es **una persona**. Un docente que atiende Documentos el
   martes no es el mismo del miércoles.
2. **¿Se avisa al acudiente en cada estación, o solo cuando lo devuelven?** Cinco avisos por
   familia en una mañana es spam; uno solo cuando algo sale mal puede llegar tarde.
3. **¿Cuántas estaciones tiene un día de matrículas típico y cómo se llaman?** La misma
   pregunta que dejó abierta `PANTALLAS-MATRICULA.md` §5.3, y aquí decide cuántos pasos caben
   en la barra sin que haya que desplazarla.
4. **¿La estación la atiende un teléfono o la tablet del colegio?** Cambia el orden de
   `docs/tablets.md`: si es tablet, el maestro-detalle de §3 deja de ser mejora y pasa a ser
   requisito.
