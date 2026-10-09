# Portería y «Mi carné»

Pedido por Joseth el 9 oct 2026. El documento de la función entera, con lo que se decidió y lo que
se comprobó contra el docker, está en `myvc_front/docs/funciones/PORTERIA.md`. Aquí sólo va lo que
es de la app.

## Las dos pantallas

- **Portería** (`/porteria`, `PorteriaScreen`). La ven los docentes, coordinación, administración y
  la cuenta con el rol «Portería» (`PermisosPorteria`).
  - Arriba va la cámara y abajo el buscador de todo el colegio.
  - Escanear pone la tardanza al instante, con «Deshacer» durante 10 s.
  - Un carné que no es de nadie abre «¿De quién es este carné?» y queda guardado.
  - La lista de alumnos se baja una vez al entrar y el buscador filtra en el teléfono.
- **Mi carné / Carnés** (`/mi-carne`, `MiCarneScreen`). Es para el alumno y el acudiente: el QR que
  se enseña en portería, uno por hijo.

**La cuenta que sólo es de portería** cae en la portería al entrar (`/muro` la redirige), y el
menú no le ofrece nada más que Portería, Mi perfil y Privacidad. El servidor tampoco la deja salir
de `porteria/*` (`CuentaDePorteria`).

Todo va detrás de `Interruptores.porteria`. Para probarlo: `--dart-define=PORTERIA=true`.

## La cámara, y la decisión del 20 sep que se revirtió

El 20 sep 2026 Joseth decidió no meter escáner, para no tocar los permisos de las tiendas (ver
`CodigoDeLaHojaScreen.dart` y `seguridad-datos-play.md`). **El 9 oct lo revirtió para la
portería.** Lo que cuesta, y cómo se cubre:

- **«Cámara» sale en la lista de permisos de la ficha de Play.** No se evita. El permiso se pide al
  abrir la portería y nunca antes, así que un acudiente o un docente que no entra ahí no ve la
  pregunta.
- **Que Play deje de ofrecer la app a las tablets sin cámara.** Pedir `CAMERA` hace que Play
  suponga obligatorias la cámara trasera **y el autoenfoque**.
  - `mobile_scanner` ya declara la cámara con `required="false"`.
  - El autoenfoque no lo declaraba nadie: va en `AndroidManifest.xml`.
  - Se comprueba en el APK con
    `aapt dump badging app-debug.apk | grep -i feature`: **no tiene que salir ningún
    `uses-feature: name='android.hardware.camera…'` sin `not-required`, ni ningún
    `uses-implied-feature` de cámara**.
- **iOS** ya tenía `NSCameraUsageDescription`, por la foto de perfil. Se amplió el texto para
  mencionar los carnés.

## Antes de publicar la app: la política de privacidad

Lo cazó la sesión de cartera el 9 oct 2026. `docs/politica-privacidad.md` y `docs/privacidad.html`
dicen «La aplicación no accede a su cámara» y «El único permiso que la aplicación le pedirá es el
de mostrarle avisos». Con la portería, las dos frases dejan de ser ciertas. **La versión que lleve
este código no se publica sin corregirlas**, ni sin revisar la ficha de seguridad de datos de Play
(`seguridad-datos-play.md`).

Los hechos que hay que contar:

- La cámara sólo la usa Portería, que es del personal.
- Sale del teléfono el texto del código leído, no la imagen.
- En Android, ML Kit (dentro de mobile_scanner) manda métricas de uso a Google: dispositivo, app,
  un identificador por instalación y rendimiento. Va por HTTPS y sin terceros. Fuente:
  developers.google.com/ml-kit/android-data-disclosure.
- «Fotos» no se declara.
