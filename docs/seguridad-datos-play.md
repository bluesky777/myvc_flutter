# Seguridad de los datos: qué contestar

Las respuestas del formulario **Política → Contenido de la app → Seguridad de
los datos**, sacadas de leer el código y no de recordarlo. Medido el 24 de
agosto de 2026, sobre `1.0.0+3`.

Play cruza este formulario con la ficha y con la política de privacidad: si
dicen cosas distintas, lo detecta. Por eso conviene contestarlo **después** de
tener publicada [privacidad.html](privacidad.html), y con ella delante.

## Lo que la app manda de verdad

```mermaid
flowchart LR
    U["Usuario"] -->|"usuario + contraseña"| S["Servidor del colegio<br/>HTTPS"]
    S -->|"token + perfil"| D["shared_preferences<br/>del teléfono"]
    D --> API["Notas, asistencia,<br/>disciplina, uniforme"]
    U -.->|"si no lo apagó"| G["Google Analytics<br/>pantallas y eventos"]

    style G fill:#fff0e6,stroke:#c98a4b
```

Dos destinos y nada más: **el servidor del colegio**, que recibe todo lo
académico, y **Google Analytics**, que recibe estadísticas de uso sin nada que
identifique a nadie. La línea punteada es porque hay un interruptor —menú ▸
Privacidad— y respetarlo es lo que hace que esa recolección sea *opcional* en el
formulario.

## Las respuestas

### Preguntas de cabecera

| Pregunta | Respuesta |
|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos requeridos? | **Sí** |
| ¿Todos los datos están cifrados en tránsito? | **Sí** — todo va por HTTPS; los quince colegios sirven con certificado |
| ¿Proporcionas una forma de solicitar la eliminación de datos? | **Sí**, a través del colegio (así lo dice la política) |

### Tipos de datos a marcar

| Categoría | Tipo | Recopilado | Compartido | Obligatorio | Para qué |
|---|---|---|---|---|---|
| Información personal | Nombre | ✔ | ✘ | Obligatorio | Funciones de la app |
| Información personal | Identificadores de usuario | ✔ | ✘ | Obligatorio | Funciones de la app |
| Información personal | Número de teléfono | ✔ | ✘ | Obligatorio | Funciones de la app |
| Información personal | Otra información | ✔ | ✘ | Obligatorio | Funciones de la app |
| Actividad en la app | Interacciones con la app | ✔ | ✘ | **Opcional** | Estadísticas |
| Dispositivo u otros IDs | ID del dispositivo | ✔ | ✘ | **Opcional** | Estadísticas |

**Por qué cada uno:**

- **Nombre e identificadores de usuario** — la respuesta de `POST /login` trae
  nombre, id y roles, y se guarda en el teléfono (`SesionGuardada`).
- **Número de teléfono** — la pantalla de cuentas muestra el `celular` de cada
  persona (`CuentaDeUsuarioModel`). Lo ve un secretario, no cualquiera, pero se
  transmite igual y hay que declararlo.
- **Otra información** — el cajón de sastre, y aquí lleva bastante: las notas,
  la asistencia, la disciplina y el uniforme, más la **fecha de nacimiento**, el
  **sexo** y la **ciudad de nacimiento** que `POST /login` devuelve (`fecha_nac`,
  `sexo`, `ciudad_nac`) y que se guardan en el teléfono. Play no tiene categoría
  propia para datos académicos ni para la fecha de nacimiento —sus nueve tipos de
  información personal no la incluyen—, así que todo cae aquí y se explica en la
  descripción del campo.
- **Interacciones e ID de dispositivo** — Google Analytics. El ID
  es el identificador aleatorio de instalación que asigna Firebase, **no** el de
  publicidad: `ACCESS_ADSERVICES_AD_ID` y `AD_ID` se quitan del manifiesto con
  `tools:node="remove"`.

### Lo que NO se marca

Contraseñas, ubicación, contactos, fotos y archivos, calendario, mensajes,
salud, información financiera, historial de navegación, historial de búsqueda,
**y toda la sección de rendimiento de la app**.

Lo del rendimiento merece su renglón porque es fácil marcarlo por inercia al ver
que hay analítica: **no hay Crashlytics ni registro de errores**. `Analitica`
solo llama a `logScreenView`, `logEvent` y `setUserProperty`; no hay
`recordError`, ni `FlutterError.onError`, ni `runZonedGuarded`. Sin nada de eso,
ni «Registros de fallos» ni «Diagnósticos» son ciertos.

Ojo con **contraseñas**, que es donde más se falla: el usuario la teclea y viaja
al servidor para verificarla, pero **desde `1.0.0+3` no se guarda en el
teléfono** y la app no la retransmite a ningún tercero. Play pregunta por datos
*recopilados*, es decir enviados fuera del dispositivo hacia ti; una credencial
que solo sirve para autenticar contra el servidor del propio colegio no se
declara. Si alguna vez se volviera a guardar en disco, esta respuesta cambia.

## La única decisión discutible: ¿«compartido» con Google?

En todas las filas puse **compartido: no**, y conviene saber por qué, porque la
intuición dice lo contrario.

Play define *compartir* como transferir datos a **un tercero**, y excluye
expresamente a los **proveedores de servicios** que procesan por encargo tuyo.
Firebase Analytics es exactamente eso: Google procesa las estadísticas siguiendo
sus condiciones de tratamiento de datos, por cuenta de quien publica la app.

La política de privacidad está redactada en consecuencia —dice que Google «las
procesa **por encargo nuestro**»—, así que las dos piezas concuerdan.

> Si prefieres el criterio conservador y marcas «compartido: sí» en las tres
> filas de estadísticas, **no es un error** y no te van a rechazar por eso. Pero
> entonces hay que ajustar la política para no decir que solo se comparte con el
> colegio.

## Lo que `POST /login` devuelve, medido

No es una lista corta, y conviene tenerla presente porque **todo esto acaba en
el teléfono**: `SesionGuardada` guarda el cuerpo entero tal como llegó.

Personales: `persona_id`, `nombres`, `apellidos`, `sexo`, `fecha_nac`,
`ciudad_nac`, `user_id`, `username`, `imagen_nombre`, `foto_id`, `foto_nombre`,
`firma_id`, `firma_nombre`.

De contexto académico: el grupo, el año, el periodo, y una veintena de ajustes
del colegio —qué puede editar un profesor, si los alumnos ven notas, cómo se
llaman las unidades—. Esos no son datos personales y no se declaran.

> **`version_minima_app` no viene**: es una función pendiente del backend
> ([backend-pendiente.md](backend-pendiente.md) §4), no algo mal configurado.
> Ningún servidor lo envía todavía, así que la comprobación de versión mínima
> no bloquea a nadie hoy.

## Lo que hay que revisar si algo cambia

- **Si entran las notificaciones** ([notificaciones.md](notificaciones.md)):
  añade el token de FCM como *ID del dispositivo*, y pasa a **obligatorio**,
  porque sin él no hay notificaciones.
- **Si se enciende algo que hoy está tras interruptor** —las notas por lote, por
  ejemplo— no cambia nada aquí: sigue siendo el servidor del colegio.
- **Si se vuelve a guardar la contraseña** en el dispositivo, hay que marcar
  *Contraseñas* y corregir la política.
