# Política de privacidad — Mi Cole Virtual

**Borrador.** Google Play exige una URL pública y viva con este texto antes de
enviar la app a revisión; sin ella, la revisión se rechaza. Lo natural es
publicarlo en `https://micolevirtual.com/privacidad`.

Los campos entre `⟨corchetes⟩` hay que llenarlos antes de publicar. Y como esto
toca datos de menores de edad, **que lo revise quien lleve el tema legal del
colegio** antes de subirlo: aquí se describe con fidelidad lo que la app hace,
pero quién responde legalmente por esos datos es una decisión que no está en el
código.

> **La analítica ya está dentro de la app** y este texto la describe: ver «Datos
> de uso de la aplicación», que además dice cómo apagarla, porque el
> interruptor existe —menú ▸ Privacidad—.
>
> **Queda una cosa por hacer para que lo escrito aquí sea verdad y no una
> intención:** en la consola de Analytics, poner la retención a nivel de usuario
> en 2 meses (*Administrar ▸ Configuración de datos ▸ Retención de datos*). El
> texto promete dos meses; por defecto Google trae ese valor, pero conviene
> confirmarlo y no fiarse.
>
> **Falta todavía lo de las notificaciones**, que cuando entren añaden el
> identificador de dispositivo de FCM ([notificaciones.md](notificaciones.md)).

---

## Política de privacidad de Mi Cole Virtual

*Última actualización: ⟨fecha⟩*

### Quiénes somos

Mi Cole Virtual es una aplicación para la comunidad educativa —docentes,
acudientes y alumnos— que permite consultar y registrar información académica
del colegio.

El responsable del tratamiento de los datos es ⟨nombre legal del responsable⟩,
identificado con ⟨NIT o documento⟩, con domicilio en ⟨dirección⟩, y correo de
contacto ⟨correo⟩.

Cada colegio que usa Mi Cole Virtual es responsable de la información de sus
estudiantes. La aplicación es el medio por el que esa información se consulta.

### Qué datos tratamos

**Datos de acceso.** Su nombre de usuario y contraseña, que usted teclea para
entrar. La contraseña se envía al servidor de su colegio para verificarla y
**no se guarda en el teléfono**.

**Datos de su perfil.** Nombre, tipo de usuario (alumno, acudiente, docente o
administrador), los roles que tenga asignados, y el año y periodo académico con
el que trabaja.

**Datos académicos.** Según su rol, la aplicación muestra y —en el caso de los
docentes— permite registrar: calificaciones, asistencia a clase, tardanzas y
ausencias a la institución, anotaciones de disciplina y porte del uniforme.

**Datos de uso de la aplicación.** Para saber qué partes de la aplicación se
usan de verdad y cuáles no, y poder mejorarla, recogemos estadísticas de uso con
Google Analytics para Firebase, un servicio de Google. Se registra qué pantallas
se abren y cuándo, acciones contadas —por ejemplo, que se guardaron veintiocho
calificaciones de una vez, o que se abrió la planilla de un indicador— y los
datos técnicos que Google recoge por su cuenta: el modelo del dispositivo, la
versión de Android, el idioma, el país y un identificador aleatorio que Google
asigna a esa instalación de la aplicación.

**Estas estadísticas no dicen quién es usted.** No se envía su nombre, su
documento, su nombre de usuario, ninguna calificación, ninguna anotación de
disciplina ni el nombre de su grupo. Los únicos dos rasgos que se guardan junto
a ellas son **el tipo de usuario** —alumno, acudiente, docente o
administrador— y **de qué colegio se trata**, y son los que permiten distinguir,
por ejemplo, si son los docentes o los acudientes quienes no encuentran una
pantalla. Ni Google ni nosotros podemos saber, a partir de esas estadísticas, a
qué persona corresponden.

Ese identificador aleatorio **no es el identificador de publicidad de Android**:
la aplicación lo tiene desactivado y ni siquiera pide el permiso para leerlo. El
identificador de la instalación desaparece si usted borra los datos de la
aplicación o la desinstala.

**Puede desactivarlas cuando quiera.** En el menú de la aplicación, en
**Privacidad**, hay un interruptor para dejar de enviar estadísticas de uso.
Apagarlo tiene efecto inmediato y la aplicación lo recuerda; el resto de la
aplicación sigue funcionando igual. El ajuste es **de ese dispositivo**: si
usted usa la aplicación en el teléfono y en una tableta, tendrá que apagarlo en
cada uno.

**Lo que NO recogemos.** La aplicación no accede a su cámara, micrófono,
contactos, ubicación, archivos ni agenda, y no le pedirá permiso para ninguna de
esas cosas: los permisos que declara son técnicos —comprobar si hay conexión,
por ejemplo— y ninguno da acceso a información personal guardada en su
dispositivo. **No hay publicidad, no se lee el identificador de publicidad y no
se crean perfiles publicitarios.** Tampoco vendemos ni cedemos a nadie la
información académica.

### Para qué los usamos

**Los datos académicos y de su perfil, únicamente para prestar el servicio
académico**: mostrarle la información que le corresponde según su rol y permitir
a los docentes registrar la que la institución les pide llevar. No se usan para
ningún otro fin.

**Las estadísticas de uso, únicamente para mejorar la aplicación**: saber qué
pantallas se usan, cuáles sobran y dónde la gente se atasca, para decidir qué
corregir y qué construir después. No se usan para evaluar ni supervisar a
ninguna persona —no llevan datos que permitan identificarla—, no se cruzan con
la información académica y no se emplean con fines publicitarios.

### Con quién los compartimos

**La información académica, con nadie fuera de su colegio.** Sus calificaciones,
su asistencia, sus anotaciones de disciplina y sus datos de perfil viajan
exclusivamente entre la aplicación y el servidor de la institución educativa a
la que usted pertenece. No los vendemos, no los alquilamos y no los cedemos a
terceros.

**Las estadísticas de uso, con Google.** Es el único tercero que interviene, y
solo para eso: recibe lo descrito en «Datos de uso de la aplicación» y las
procesa por encargo nuestro, sujeto a sus propias condiciones de tratamiento de
datos. Google no recibe ninguna calificación, ningún nombre y ningún dato que
permita identificar a un estudiante.

No hay servicios de publicidad ni de redes sociales integrados en la
aplicación.

### Cómo los protegemos

Toda la comunicación entre la aplicación y el servidor viaja cifrada mediante
HTTPS.

Al entrar, la aplicación puede guardar en el teléfono una credencial temporal
(un *token* de sesión) para no pedirle la contraseña en cada uso. **Esto solo
ocurre si usted deja marcada la casilla de recordar sesión.** Si la desmarca
—recomendado en equipos compartidos, como el de la portería del colegio— no se
guarda nada en el dispositivo. Al cerrar sesión, esa credencial se borra.

La contraseña nunca se almacena en el teléfono.

### Cuánto tiempo los conservamos

Los datos académicos los conserva el colegio según sus propias políticas y las
obligaciones legales de archivo que le apliquen. La credencial de sesión
guardada en el teléfono se borra al cerrar sesión o al desinstalar la
aplicación.

Las estadísticas de uso asociadas a una instalación se conservan **dos meses**,
que es el plazo más corto que permite el servicio; pasado ese tiempo solo quedan
totales agregados, en los que ya no se distingue ninguna instalación.

### Datos de menores de edad

Buena parte de la información que la aplicación muestra corresponde a
estudiantes que pueden ser menores de edad. Esa información la aporta el
colegio como parte del proceso de matrícula, y su tratamiento se ampara en la
autorización que el padre, madre o acudiente otorga a la institución en ese
momento.

Los estudiantes menores de edad no crean cuentas por su cuenta: las credenciales
las entrega el colegio.

Las estadísticas de uso descritas arriba se recogen igual en el teléfono de un
estudiante que en el de un docente, y en ninguno de los dos casos llevan datos
que permitan identificar a la persona. **No se elabora ningún perfil de un
menor, no se le muestra publicidad y no se lee ningún identificador
publicitario de su dispositivo.**

⟨Si el colegio tiene un aviso de privacidad o un formato de autorización
firmado por los acudientes, enlazarlo aquí.⟩

### Sus derechos

Usted puede pedir que le informemos qué datos suyos tratamos, que los
corrijamos si están errados, que los actualicemos, o que los suprimamos cuando
no exista un deber legal o contractual que obligue a conservarlos. También
puede revocar la autorización que haya otorgado.

Como los datos académicos los administra su institución educativa, **estas
solicitudes se tramitan a través del colegio**, escribiendo a ⟨correo de
contacto del colegio o del responsable⟩. Le responderemos dentro de los plazos
que fija la ley.

⟨Para Colombia: este tratamiento se rige por la Ley 1581 de 2012 y el Decreto
1074 de 2015, y usted puede acudir a la Superintendencia de Industria y
Comercio si considera que sus derechos no fueron atendidos. Confirmar con el
colegio si esta es la normativa aplicable.⟩

### Cambios en esta política

Si modificamos esta política, publicaremos la nueva versión en esta misma
dirección y actualizaremos la fecha del encabezado. Los cambios importantes se
avisarán dentro de la aplicación.

### Contacto

⟨correo⟩ — ⟨teléfono, si aplica⟩ — ⟨dirección⟩
