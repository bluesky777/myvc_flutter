# Ficha de Play Store — textos

Lo que se pega en **Grow → Store presence → Main store listing**. Los límites
de caracteres son de Google y los cuenta él mismo; los de aquí ya están dentro.

Ver [publicacion-play.md](publicacion-play.md) para el proceso completo, y
[politica-privacidad.md](politica-privacidad.md) para el texto que hay que
publicar en la web antes de enviar a revisión.

**El formulario de seguridad de datos cambia** si entran la analítica o las
notificaciones: la primera obliga a declarar datos de uso y diagnóstico
compartidos con un tercero y no vinculados a la identidad
([analitica.md](analitica.md)); las segundas, el identificador de dispositivo de
FCM ([notificaciones.md](notificaciones.md)).

## Nombre de la app

*Máximo 30 caracteres.*

```
Mi Cole Virtual
```

## Descripción corta

*Máximo 80 caracteres. Es la que se ve sin desplegar, y en los resultados de
búsqueda. Es el texto que más se lee de toda la ficha.*

```
Notas, asistencia y disciplina del colegio, para docentes y acudientes.
```

Alternativas, por si prefieres otro énfasis:

```
El colegio en el bolsillo: notas, asistencia y disciplina al día.
```
```
Consulta y registra notas, asistencia y disciplina de tu colegio.
```

## Descripción larga

*Máximo 4.000 caracteres.*

```
Mi Cole Virtual acerca la información del colegio a quienes la necesitan todos
los días: los docentes que la registran y las familias que quieren estar al
tanto.

Entra con las credenciales que te dio tu institución y verás lo que te
corresponde según tu rol. Nada más, y nada menos.

SI ERES DOCENTE

• Registra la asistencia de tu clase en segundos, alumno por alumno.
• Lleva las anotaciones de disciplina del grupo y consulta la ficha completa de
  cada estudiante, periodo por periodo.
• Anota el porte del uniforme sin papeles de por medio.
• Consulta las unidades y los logros de tus asignaturas.

SI ERES ACUDIENTE

• Mira las notas de tu acudido cuando quieras, sin esperar a la entrega de
  boletines.
• Revisa su asistencia, sus tardanzas y sus ausencias a la institución.
• Entérate de las anotaciones de disciplina el mismo día, no al final del
  periodo.

SI ERES ALUMNO

• Consulta tus notas y tu asistencia en cualquier momento.
• Revisa tus anotaciones y el estado de tu uniforme.

TU COLEGIO, TUS DATOS

Mi Cole Virtual se conecta únicamente con el servidor de tu institución. Las
notas, la asistencia y las anotaciones no salen de ahí: no hay publicidad y no
se venden ni se comparten tus datos con terceros.

Para saber qué pantallas se usan y detectar fallos, la app usa Google
Analytics. No le manda tu nombre ni tus notas, y puedes apagarlo cuando quieras
desde el menú.

La app no pide acceso a tu cámara, tus contactos, tus archivos ni tu ubicación.

En equipos compartidos puedes desmarcar la casilla de recordar sesión, y
entonces no se guarda nada en el dispositivo.

PARA EMPEZAR

Necesitas que tu colegio use Mi Cole Virtual y que te haya entregado tu usuario
y contraseña. Si no los tienes, pídelos en la secretaría de tu institución.

Consulta nuestra política de privacidad en https://micolevirtual.com/privacidad.html
```

⚠️ **Con `.html`, y no sin él.** `micolevirtual.com/privacidad` a secas da
**404**; la página vive en `/privacidad.html` (comprobado el 25 ago 2026). La
ficha llegó a publicarse con la URL corta, que es un enlace muerto dentro de la
propia tienda. El día que se toque el sitio, lo limpio es una redirección de
`/privacidad` a `/privacidad.html` y volver a la URL bonita.

## Categoría y etiquetas

| Campo | Valor |
|---|---|
| Categoría de la app | **Educación** |
| Etiquetas | Educación · Herramientas para el aula · Familia y escuela |
| Público objetivo | **13+** (ver la advertencia en `publicacion-play.md` §6) |
| Correo de contacto | ⟨correo público⟩ |
| Sitio web | https://micolevirtual.com |
| Política de privacidad | https://micolevirtual.com/privacidad.html |

## Imágenes — subidas el 25 de agosto de 2026

| Recurso | Requisito | Estado |
|---|---|---|
| Ícono de ficha | 512×512 PNG 32-bit, **sin alfa** | ✅ `~/icono-play-512.png`, sacado del de iOS (`Icon-App-1024x1024@1x.png`, que Apple ya exige sin alfa) |
| Gráfico destacado | 1024×500 PNG o JPG | ✅ subido, **hecho con IA y etiquetado como tal** en la declaración de recursos |
| Capturas de teléfono | mín. 2, máx. 8; lado entre 320 y 3840 px | ✅ subidas, sacadas de la app corriendo en un emulador |
| Capturas de tablet | opcionales | ✅ subidas, las tres pantallas que quedan bien en tablet (ver [estado.md](estado.md) → «Tablets») |

Las capturas que más venden esta app, en este orden: el panel al entrar, las
notas de un alumno, el registro de asistencia de un grupo, y la ficha de
disciplina.

**La declaración de recursos de IA** pregunta por estas imágenes, no por la app
ni por los textos. Como el gráfico destacado se hizo con IA, la ficha va con
*«Etiquetar los recursos como creados o editados con IA»* y **solo ese recurso
marcado**: el ícono y las capturas no lo llevan. Si algún día se rehace el
gráfico sin IA, hay que volver aquí y cambiar la respuesta.

Con eso, la ficha quedó en **«Lista para enviar a revisión»**. Eso no la envía:
se revisa junto con la primera versión que se suba, así que lo que sigue no es
de la ficha sino de [publicacion-play.md](publicacion-play.md) §6 en adelante.
