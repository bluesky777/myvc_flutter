import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Models/NotaDeEstacionModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Las estaciones del día de matrículas.
///
/// **Nada de esto llama al servidor mientras [Interruptores.estaciones] esté
/// apagado**, y no por prudencia: las **nueve** rutas `estaciones/*` están
/// fundidas en `main` de `8myvc` y **no desplegadas en ningún colegio**.
/// Llamarlas sería gastar un 404 por apertura sobre un hosting de un núcleo,
/// que es justo lo que este proyecto lleva un año evitando. Ver
/// `docs/backend-pendiente.md` §8.
///
/// **Son nueve y no ocho desde el 20 sep 2026**: la novena,
/// `PUT estaciones/nota/{id}/resuelta`, salió de un hueco que encontró esta app
/// escribiendo las pantallas —sin ella, `resuelta_por` y `resuelta_at` no las
/// escribía nadie nunca—.
///
/// El contrato entero está en `8myvc/docs/migracion/46-las-estaciones-en-la-app.md`
/// y el diseño de las pantallas, en `docs/estaciones.md`.

/// Lo que estas pantallas saben hacer y todavía no pueden.
///
/// Mismo patrón que `PendientesUsuarios`: cada uno se enciende con una palabra
/// el día que su motivo desaparezca, y hasta entonces **la pantalla enseña en su
/// sitio por qué está apagado** — nunca «no disponible», que no se puede pedir
/// ni decidir. No son constantes para que las pruebas puedan encenderlos y
/// comprobar lo que sale.
class PendientesEstaciones {
  /// Cerrar el paso desde la ficha (pantallas 05 y 07 del diseño).
  ///
  /// La ruta está en el contrato —`PUT estaciones/{nro}/marcar`— pero **las
  /// pantallas que la usan no están escritas**: enseñar la consecuencia antes de
  /// confirmar, el deshacer de ocho segundos y el motivo obligatorio son la
  /// mitad de esa decisión, y un botón que cierre sin ellas sería peor que no
  /// tener botón.
  static bool marcarElPaso = false;

  /// Devolver con motivo (pantalla 06).
  ///
  /// Va con [marcarElPaso] y se apaga aparte porque su regla es distinta: el
  /// botón **no se enciende sin texto escrito**, y lo que se escriba **lo lee la
  /// familia**. Sin esa pantalla, devolver sería mandar a alguien a su casa sin
  /// decirle por qué.
  static bool devolverConMotivo = false;

  /// Mandar a otra estación al que llega salteado (pantalla 08).
  ///
  /// **La ruta hace algo distinto de lo que su nombre sugiere, y de ahí que
  /// tenga interruptor propio en vez de ir con [marcarElPaso]:**
  /// `PUT estaciones/{nro}/enviar-a/{destino}` **no escribe el paso**. Registra
  /// el intento en `envios_estacion` y contesta `paso_escrito: false`, que es lo
  /// que permite al rector leer *«en la 4 se presentan doce sin pasar por la
  /// 3 — el cartel está mal puesto»* **sin ensuciar el recorrido de esa
  /// familia** con un paso que no ocurrió.
  ///
  /// **La pantalla ya no es lo que falta: está escrita** —`SalteadoScreen`, la
  /// 08— y dice justo eso: **ni un chulo verde ni un aviso de que se guardó
  /// algo del recorrido**, porque no se guardó. Lo que queda por debajo de este
  /// `false` es el despliegue de las nueve rutas, como en todo el módulo.
  static bool mandarAlQueLlegaSalteado = false;

  /// **«Atenderlo de todas formas»** (pantalla 08).
  ///
  /// **Existe a propósito y hoy está apagado.** Un sistema que no puede
  /// saltarse su propia regla se salta **por fuera, en papel**, y entonces no
  /// queda registro de nada: ni de que pasó, ni de quién lo permitió. Por eso
  /// la salida está dibujada en la pantalla en vez de negada.
  ///
  /// **Lo levanta Coordinación caso por caso y queda con el nombre de quien lo
  /// autorizó** (`docs/estaciones.md` §2.5), y ahí está lo que le falta, que no
  /// es una pantalla: **el servidor no tiene dónde guardar ese nombre.**
  /// `envios_estacion` apunta `enviado_por` —quien mandó a la familia a la
  /// estación que le falta— y **no tiene columna para quien autoriza un salto**;
  /// `putMarcar` firma el paso con quien lo cierra, que es otra cosa. Encender
  /// esto sin esa columna sería exactamente el papel que se quiere evitar, pero
  /// con la app de coartada.
  ///
  /// Va aparte de [marcarElPaso] porque **no es el mismo botón**: aquél cierra
  /// un paso que toca, y éste cierra uno que **no** toca. Compartirlos haría que
  /// encender el cierre normal abriera la puerta de atrás sin que nadie lo
  /// decidiera.
  static bool atenderloDeTodasFormas = false;

  /// Abrir la ficha por el código tecleado de la hoja de ruta (pantalla 03).
  ///
  /// **Se separa de [escanearElCodigo] a propósito, y esa separación es la que
  /// hace barata la pantalla 03.** Aquel es una decisión sobre los permisos de
  /// las tiendas —la cámara— y éste es `GET estaciones/codigo/{codigo}`, o sea
  /// un despliegue. El código se puede teclear —`2027-4K7M2`, el mismo del
  /// formulario de inscripción—, así que la pantalla se escribe **entera sin
  /// cámara** y lo único que espera es la ruta.
  ///
  /// **Y esa ruta contesta dos cosas que no son un fallo y la pantalla tiene
  /// que saber pintar**: un **409** cuando el papel todavía no es de nadie —un
  /// formulario del modo `nuevos` nace sin alumno hasta que secretaría lo ata—,
  /// que se enseña como lo que hay que hacer y no como un error; y el
  /// `codigo_anterior`, que entra en la búsqueda **porque el papel viejo está en
  /// casa de una familia** y quien lo teclee tiene que llegar a su orden.
  static bool buscarPorElCodigo = false;

  /// Leer el QR de la hoja de ruta (pantalla 03).
  ///
  /// **DECIDIDO por Joseth el 20 sep 2026: el escáner no entra por ahora, para
  /// no tocar los permisos de las tiendas.** No es una postergación vaga: es una
  /// decisión con un precio medido detrás.
  ///
  /// Hoy esta app **no pide cámara en ninguna de las dos tiendas** —Android
  /// declara `INTERNET` y las dos de `AD_ID` que arrastra Analytics; iOS solo
  /// `NSLocalNetworkUsageDescription`—. Meter un escáner rompe eso:
  ///
  /// - `android.permission.CAMERA` es de las peligrosas: se pide en tiempo de
  ///   ejecución **y sale en la lista de permisos de la ficha**, que los
  ///   dieciséis colegios ven cambiar al actualizar.
  /// - **Y la que no avisa**: los paquetes de escáner meten solos un
  ///   `<uses-feature android:name="android.hardware.camera">`, y sin un
  ///   `required="false"` explícito **Play deja de ofrecer la app a los
  ///   aparatos sin cámara**. No falla nada y no llega ningún correo: se
  ///   desaparece de algunas tablets, que es justo el aparato del patio.
  /// - En iOS, `NSCameraUsageDescription` pasa a ser obligatorio: sin él la app
  ///   **se cae** al abrir la cámara, y un texto genérico se rechaza.
  ///
  /// Lo que **no** pasa, para que no se exagere el precio: la cámara no es de
  /// los permisos restringidos de Play, así que no hay formulario ni ronda extra
  /// de revisión. Y el público declarado es **13+**, así que esto no entra en la
  /// *Families Policy*.
  ///
  /// **La salida, cuando se retome:** el código se puede teclear —`2027-4K7M2`,
  /// el mismo del formulario de inscripción—, así que la pantalla 03 se puede
  /// escribir **entera sin cámara** y el escáner queda aparte. Lo que esa
  /// pantalla sigue esperando entonces no es un permiso: es
  /// `GET estaciones/codigo/{codigo}`, que es de las nueve rutas.
  static bool escanearElCodigo = false;

  /// El aviso inmediato cuando llega alguien a tu estación.
  ///
  /// **RECTIFICADO el 20 sep 2026: NO entra.** Esta casilla decía «entra» y
  /// mandaba a meter `firebase_messaging` en `pubspec.yaml` por ello. **No hay
  /// que hacerlo por esto.** Se le puso delante a Joseth que `notificaciones.md`
  /// prohíbe publicar dentro de una petición —y lo prohíbe con la medición
  /// hecha, *«el docente espera a que Google responda»*, que aquí muerde más
  /// porque quien atiende tiene una fila delante— y contestó: *«que llegue
  /// cuando tenga que llegar, no me voy a complicar con que le llegue de
  /// inmediato, por ahora no importa»*. El porqué entero, con lo medido y lo que
  /// quedó sin medir, en `docs/estaciones.md` §2.2.
  ///
  /// **Lo que eso cambió de lo que hay que construir aquí: nada.** El push era
  /// el último paso e iba después de la cola, así que quitarlo no dejó hueco —
  /// y que no lo dejara es lo que demuestra que el orden estaba bien puesto.
  ///
  /// Lo que falta sigue siendo de los dos lados, el día que se retome. De este:
  /// la app no tiene `firebase_messaging`, solo `firebase_core` y
  /// `firebase_analytics`. Y del otro, **algo que nadie sabe**: cuántos de los
  /// diecisiete colegios tienen credenciales de Firebase puestas. Sin ellas el
  /// envío no hace nada, y `8myvc/app/Console/Kernel.php` dice hoy que «cuántas
  /// las tienen HOY no se sabe desde aquí» — se mira en el `.env` de cada
  /// instalación y eso solo lo corre Joseth. **No lo des por hecho al encender
  /// esto, en ninguno de los dos sentidos.**
  ///
  /// **La cola sondeada no se retira si esto se enciende algún día.** Un push se
  /// pierde, llega tarde o está apagado en los ajustes del teléfono, y la fila
  /// del patio no se puede parar por eso: el push **adelanta** el aviso, la cola
  /// **garantiza** que nadie se quede invisible.
  static bool pushInmediato = false;

  /// Dar por resuelta una nota pendiente.
  ///
  /// **El hueco que esto describía está cerrado: la ruta existe desde el 20 sep
  /// 2026.** `PUT estaciones/nota/{id}/resuelta` →
  /// `EstacionesController::putNotaResuelta`, y el contrato pasó de ocho rutas a
  /// **nueve**. Sin ella, `resuelta_por` y `resuelta_at` no las escribía nadie y
  /// el globo ámbar no se apagaba nunca.
  ///
  /// **Y el permiso es el que decidió Joseth, comprobado en el código y no
  /// supuesto.** `Autoriza::puedeResolverNotaDeEstacion` (`Autoriza.php:883`)
  /// devuelve verdadero para **quien la escribió**, para un superusuario y para
  /// los roles `Admin`, `Secretario` y `Rector`. Ni uno más.
  ///
  /// > **Y esto hubo que comprobarlo contra una afirmación en contra.** La
  /// > sesión del backend avisó de que las nueve rutas llevan `auth.personal` y
  /// > que ésta **no** filtra por dentro, o sea que el botón lo vería todo el
  /// > personal. Mirando `routes/api/estaciones.php` esa lectura cuadra —las
  /// > nueve llevan el mismo `middleware`—, pero el permiso vive **dentro del
  /// > método**, que es la forma de esta casa: *«guard en la ruta, permiso
  /// > dentro»*. Es la misma trampa que tuvo el agujero de `putResetPassword`
  /// > abierto tres días de más. **Leer `routes/` y concluir es el error.**
  ///
  /// Así que esta pantalla **sí filtra el botón**, y lo apaga con el motivo
  /// escrito para quien no pueda: «esta nota puede darla por resuelta quien la
  /// escribió, o Secretaría, Rectoría o un administrador».
  ///
  /// Lo que queda apagado ya no es la ruta: es la **pantalla 12** —las notas
  /// entre estaciones—, que todavía no está escrita, y el despliegue.
  static bool resolverUnaNota = false;

  /// Deja los interruptores como vienen de fábrica. Para las pruebas.
  ///
  /// «De fábrica» es lo que hay escrito arriba, no «todo apagado»: si esto se
  /// desincroniza, las pruebas dejan de comprobar la app que se publica.
  static void comoDeFabrica() {
    marcarElPaso = false;
    devolverConMotivo = false;
    mandarAlQueLlegaSalteado = false;
    atenderloDeTodasFormas = false;
    buscarPorElCodigo = false;
    escanearElCodigo = false;
    pushInmediato = false;
    resolverUnaNota = false;
  }
}

/// El recorrido del colegio **y si la campaña está abierta**.
///
/// ## `campana.abierta` lo dice el servidor; hasta hoy lo adivinaba la app
///
/// `GET estaciones` contesta `{campana:{year_id, year, abierta}, estaciones,
/// mi_estacion}` y esta capa **se quedaba sólo con `estaciones`**. La pantalla
/// 01 deducía «este colegio no armó el recorrido» de que la lista viniera
/// vacía, que es una regla escrita en la app sobre un dato que el servidor ya
/// manda calculado.
///
/// **Hoy las dos respuestas coinciden** —`getIndex` calcula
/// `abierta = count($estaciones) > 0`, leído el 20 sep 2026— y **eso es
/// precisamente lo que hace barato leerlo ahora**: no cambia nada de lo que se
/// ve, y el día que el colegio pueda cerrar la campaña con las estaciones
/// puestas, o abrirla antes de armarlas, la app ya contesta lo que diga el
/// servidor **sin publicar una versión**. Una app vieja convive meses con un
/// servidor nuevo (`docs/estado.md`): la deducción envejece, el campo no.
///
/// ## Por qué es `bool?` y no `bool`
///
/// **Tres respuestas, no dos**, que es la misma regla de toda esta casa:
///
/// - `true` — el colegio tiene recorrido: atiéndelo.
/// - `false` — el servidor dice que **no hay campaña**: «tu colegio no armó el
///   recorrido», que es lo que se le puede arreglar.
/// - `null` — **el servidor no lo dijo** (una versión anterior a `campana`).
///   Entonces, y sólo entonces, se vuelve a la deducción de siempre. Convertir
///   esto en `false` diría «no armaste el recorrido» a un colegio que sí lo
///   armó, y con un servidor viejo lo diría **siempre**.
typedef LasEstacionesDelColegio = ({bool? abierta, List<Estacion> estaciones});

/// Lo que se contesta sin preguntar: ni lista, ni respuesta sobre la campaña.
const LasEstacionesDelColegio _sinRecorrido =
    (abierta: null, estaciones: <Estacion>[]);

/// El recorrido que armó este colegio, con la campaña.
///
/// **Una lista vacía y «este colegio no armó recorrido» no son lo mismo**, y por
/// eso esto devuelve la lista tal cual: quien la pinta decide qué decir. Ver
/// `docs/estaciones.md` §2.8 y [LasEstacionesDelColegio].
Future<LasEstacionesDelColegio> traerLasEstacionesDelColegio(
  Server server,
) async {
  if (!Interruptores.estaciones) return _sinRecorrido;

  return leerLasEstaciones(
    _cuerpo(await server.get('/estaciones'), 'las estaciones del colegio'),
  );
}

/// Sólo la lista, para quien no necesita la campaña.
///
/// **Se queda —en vez de cambiarle la forma a [traerLasEstacionesDelColegio]—
/// porque la pantalla 01 y sus pruebas la llaman así**, y romperles la firma a
/// cambio de nada sería pagar un roce en tres ficheros por un dato que ellas no
/// usan todavía. El día que la 01 lea la campaña, esto se borra en una línea.
Future<List<Estacion>> traerLasEstaciones(Server server) async =>
    (await traerLasEstacionesDelColegio(server)).estaciones;

/// Lee la respuesta de `GET estaciones`.
///
/// **Pública y separada de la petición a propósito**: con
/// [Interruptores.estaciones] en `const false`, todo lo que hay detrás de la
/// guarda es código que **ninguna prueba alcanza**, y la diferencia entre
/// `abierta: false` y `abierta: null` es justo la que no se puede descubrir el
/// día del despliegue. Es el mismo motivo de [leerElPasoMarcado].
LasEstacionesDelColegio leerLasEstaciones(dynamic cuerpo) {
  final crudo = _comoMapa(cuerpo);
  if (crudo == null) return _sinRecorrido;

  final campana = crudo['campana'];

  return (
    abierta: campana is Map ? _siONo(campana['abierta']) : null,
    estaciones: _listaDe(crudo['estaciones'], Estacion.fromJson),
  );
}

/// Un aviso que el servidor calculó para alguien de la fila.
///
/// ## El texto lo escribe el SERVIDOR, y aquí no se reescribe
///
/// `getCola` manda `avisos: [{tipo, texto}]` por persona, con la frase ya hecha
/// —*«Cerró una estación posterior sin pasar por ésta»*, *«Ya estuvo aquí y se
/// le devolvió»*—. La app pinta **ese** texto y no uno propio, por el mismo
/// motivo que [motivoDeUnaEscritura] enseña el del `abort`: quien calcula la
/// regla es quien sabe decirla, y **una frase escrita en la app envejece en
/// silencio** el día que la regla del servidor cambie. Son dieciséis colegios
/// con una sola app y versiones viejas conviviendo meses.
///
/// [tipo] sirve para elegir el icono, **no para traducir el texto**. Un tipo
/// que esta versión no conozca se pinta igual, con su frase y un icono
/// genérico: es la regla de `docs/estaciones.md` §2.8 —el vocabulario lo pone
/// el colegio y la app no lo cablea—, y es la diferencia entre que un aviso
/// nuevo se vea y que desaparezca sin que nadie se entere.
typedef AvisoDeLaCola = ({String tipo, String texto});

/// Alguien de la fila, con los avisos que el servidor le calculó.
///
/// **Van al lado de la persona y no dentro** porque `PersonaEnCola` es del
/// modelo y esto se lee aquí: el modelo no tiene campo para los avisos, y
/// escribirlo no es de esta capa. Ver el informe del 20 sep 2026 — es el campo
/// que hay que pedirle a `PersonaEnCola`.
typedef EnLaCola = ({PersonaEnCola persona, List<AvisoDeLaCola> avisos});

/// La cola de una estación **entera**: la cabecera y la fila.
///
/// ## Tres cifras arriba, y una de ellas no existe
///
/// La cabecera del diseño (§1, pantalla 02) enseña **atendidos hoy, esperando y
/// espera media**. Medido contra `getCola` el 20 sep 2026:
///
/// - **atendidos hoy** — `atendidos_hoy`, **ya llega** y hasta hoy se tiraba.
///   Lo cuenta `atendidosHoy()`: alumnos distintos con un `cerrado_at` de hoy
///   en los requisitos de esta estación.
/// - **esperando** — no hace falta pedirlo: es lo que mide la fila que viene en
///   la misma respuesta.
/// - **espera media** — **NO EXISTE EN EL SERVIDOR**, y no se inventa aquí.
///   Calcularla con lo que hay —`llego_at` de los que siguen esperando— daría
///   *«cuánto llevan de pie los que aún no atiendo»*, que **no es** el tiempo
///   medio de espera y además **baja cuando la cosa va mal**: al atender a los
///   más viejos, la media de los que quedan cae. Una cifra que mejora cuando el
///   tapón empeora es peor que un hueco. Queda el hueco dicho, que es lo que
///   se puede pedir.
///
/// [nro] y [nombre] son los de la estación tal como los llama el servidor, y
/// [alDiaAt] el sello de lo último que se movió en esta cola.
typedef LaCola = ({
  int? nro,
  String? nombre,
  String? alDiaAt,
  int? atendidosHoy,
  List<EnLaCola> fila,
});

/// Una cola que no se ha llegado a pedir. **`atendidosHoy` es `null` y no `0`**:
/// cero es «hoy no ha pasado nadie todavía», que es una noticia, y null es «no
/// lo sé». Pintar un cero que nadie contó es mentir barato.
const LaCola _sinCola = (
  nro: null,
  nombre: null,
  alDiaAt: null,
  atendidosHoy: null,
  fila: <EnLaCola>[],
);

/// Los que me llegan, con la cabecera del día.
///
/// **Es una consulta, no una bandeja de avisos**, y ésa es la decisión que
/// sostiene todo el módulo. Un aviso perdido deja a la familia en la fila igual;
/// una bandeja con un aviso perdido la deja **invisible para siempre** y nadie
/// sabe que falta. Por eso no hay nada que marcar como leído: no hay nada que
/// vaciar, hay una pregunta que se vuelve a hacer.
Future<LaCola> traerLaColaEntera(Server server, int nroEstacion) async {
  if (!Interruptores.estaciones) return _sinCola;

  return leerLaCola(
    _cuerpo(
      await server.get('/estaciones/$nroEstacion/cola'),
      'la cola de tu estación',
    ),
  );
}

/// Sólo la fila, sin la cabecera ni los avisos.
///
/// Se queda por el mismo motivo que [traerLasEstaciones]: hay pruebas y código
/// que la llaman así, y cambiarle la forma no les daría nada.
Future<List<PersonaEnCola>> traerLaCola(
  Server server,
  int nroEstacion,
) async =>
    (await traerLaColaEntera(server, nroEstacion))
        .fila
        .map((uno) => uno.persona)
        .toList();

/// Lee la respuesta de `GET estaciones/{nro}/cola`.
///
/// **Pública a propósito**, como [leerElPasoMarcado]: detrás de la guarda del
/// interruptor no llega ninguna prueba, y lo que aquí se lee mal —un
/// `atendidos_hoy` tirado, unos avisos que no se pintan— **no falla: se ve
/// vacío**, que es la manera de equivocarse que no avisa.
LaCola leerLaCola(dynamic cuerpo) {
  final crudo = _comoMapa(cuerpo);
  if (crudo == null) return _sinCola;

  final fila = <EnLaCola>[];
  final cola = crudo['cola'];

  if (cola is List) {
    for (final uno in cola) {
      if (uno is! Map) continue;
      final persona = Map<String, dynamic>.from(uno);
      fila.add((
        persona: PersonaEnCola.fromJson(persona),
        avisos: leerLosAvisos(persona['avisos']),
      ));
    }
  }

  return (
    nro: entero(crudo['nro']),
    nombre: texto(crudo['nombre']),
    alDiaAt: texto(crudo['al_dia_at']),
    atendidosHoy: entero(crudo['atendidos_hoy']),
    fila: fila,
  );
}

/// Los `[{tipo, texto}]` de una fila de la cola.
///
/// **Sin texto no hay aviso.** Un chip vacío ocupa sitio en una tarjeta que se
/// mira de pie y no dice nada; y un aviso cuyo texto el servidor no escribió no
/// se puede suplir desde aquí sin inventarlo. El `tipo` sí puede faltar: se
/// pinta igual con el icono genérico.
List<AvisoDeLaCola> leerLosAvisos(dynamic crudo) {
  if (crudo is! List) return const [];

  final avisos = <AvisoDeLaCola>[];

  for (final uno in crudo) {
    if (uno is! Map) continue;
    final dice = texto(uno['texto'])?.trim();
    if (dice == null || dice.isEmpty) continue;
    avisos.add((
      tipo: texto(uno['tipo'])?.trim().toLowerCase() ?? '',
      texto: dice,
    ));
  }

  return avisos;
}

/// Si el servidor dijo que esta persona **no vino en orden**.
///
/// Es `tipo == 'salteado'`, el que calcula `quienesEsperan` y pone el texto
/// *«Cerró una estación posterior sin pasar por ésta»*. Vive aquí y no dentro
/// de la pantalla porque es una lectura del contrato —y porque así se puede
/// fijar en una prueba con el interruptor apagado—.
///
/// **Que esto sea `true` no significa «no lo atiendas»**, y confundir las dos
/// cosas era el error fácil: este aviso lo levanta la **primera** estación, y
/// ahí el que llega sí tiene que ser atendido. Quien decide si hay que parar es
/// la ficha, con `leFalta`. Ver `SalteadoScreen`.
bool dicenQueSeSaltoElOrden(List<AvisoDeLaCola> avisos) =>
    avisos.any((aviso) => aviso.tipo == 'salteado');

/// ¿Ha cambiado algo? Unos 300 bytes.
///
/// La pantalla de la estación pregunta esto cada ~20 segundos durante ocho
/// horas, y **ninguna de las lecturas manda `ETag` ni `Last-Modified`**, así que
/// hoy preguntar barato no se puede sin esta ruta. Es el patrón medido de
/// `8myvc/docs/migracion/34`: sondea la huella, y **solo cuando se mueve** pide
/// la cola de verdad.
///
/// Devuelve `(cuántos, cuándo cambió)` por estación. **Las dos hacen falta**:
/// una fecha no ve que alguien salió de la cola, y el conteo sí.
Future<Map<int, String>> traerLaHuella(Server server) async {
  if (!Interruptores.estaciones) return const {};

  return leerLaHuella(
    _cuerpo(
      await server.get('/estaciones/huella'),
      'si cambió algo en tu estación',
    ),
  );
}

/// Lee la respuesta de `GET estaciones/huella`. **Pública para que las tres
/// cifras las pueda fijar una prueba**, que es lo único que impide que la
/// tercera se vuelva a caer: detrás de la guarda del interruptor no llega
/// ninguna, y una huella de dos cifras no falla — esconde una nota.
Map<int, String> leerLaHuella(dynamic cuerpo) {
  final crudo = _comoMapa(cuerpo);
  if (crudo == null) return const {};
  final porEstacion = crudo['por_estacion'];
  if (porEstacion is! Map) return const {};

  final huella = <int, String>{};
  porEstacion.forEach((clave, valor) {
    final nro = int.tryParse('$clave');
    if (nro == null) return;
    // Se guarda como texto —«cuántos + cuándo» pegados— porque lo único que
    // esta pantalla hace con la huella es **comparar si cambió**. Interpretarla
    // sería inventarle un significado que el contrato no promete.
    if (valor is Map) {
      // **LAS TRES CIFRAS, Y LA DE `notas` ES LA QUE SE OLVIDA.**
      //
      // Esto guardaba solo `n` y `ultimo_cambio`, y tirar la tercera reabría el
      // agujero exacto que el controlador se molestó en cerrar: `ultimo_cambio`
      // es un `timestamp` con precisión de **segundo**, así que una nota escrita
      // en el mismo segundo en que se cerró el paso anterior **no mueve el
      // `MAX`** —y tampoco mueve el conteo de la cola, porque una nota no
      // cambia quién está en la fila—. Sin `notas` en la comparación, ese globo
      // no aparece hasta el siguiente cambio de la cola, **o nunca**.
      //
      // Y es justo el caso que el globo existe para cubrir: el tesorero deja la
      // nota mientras la estación anterior cierra el paso.
      huella[nro] = '${valor['n']}|${valor['notas']}|${valor['ultimo_cambio']}';
    }
  });
  return huella;
}

/// La ficha de una persona, con sus N pasos.
Future<FichaDeEstacion?> traerLaFicha(Server server, int personaId) async {
  if (!Interruptores.estaciones) return null;

  final crudo = _cuerpo(
    await server.get('/estaciones/alumno/$personaId'),
    'la ficha de esa persona',
  );

  if (crudo is! Map) return null;
  return FichaDeEstacion.fromJson(Map<String, dynamic>.from(crudo));
}

/// La misma ficha, buscada por el código de la hoja de ruta. Pantalla 03.
///
/// **Es el código del formulario de inscripción que ya existe**, no uno nuevo:
/// acuñar otro habría sido un segundo papel para la misma familia. Y busca
/// también por `codigo_anterior`, porque **el papel viejo está en casa de una
/// familia** y quien lo teclee tiene que llegar a su orden.
///
/// ## Los dos cortes que esta lectura trata distinto que sus hermanas
///
/// **El 409 no es un fallo: es lo que hay que hacer.** Un formulario del modo
/// `nuevos` nace **sin alumno**, y hasta que secretaría lo ata con
/// `PUT formularios-inscripcion/codigo/{codigo}/alumno` no hay recorrido que
/// enseñar. El servidor manda el texto dentro y **gana el suyo**: la pantalla lo
/// convierte en un botón.
///
/// **Y el 404 de aquí NO quiere decir «tu colegio no tiene estaciones».** En
/// todas las demás lecturas sí —`_cuerpo` lo dice así— porque las nueve rutas
/// están sin desplegar; pero a ésta solo se llega con
/// [Interruptores.estaciones] encendido, y encenderlo quiere decir, por la regla
/// de la casa, que la ruta ya está en los diecisiete. Con la ruta puesta, un 404
/// es **un código que no existe**, que es lo más común de una pantalla donde se
/// teclea: decirle «tu colegio no tiene el día de matrículas» a quien se
/// equivocó de dígito lo manda a buscar un problema que no tiene.
Future<FichaDeEstacion?> traerLaFichaPorCodigo(
  Server server,
  String codigo,
) async {
  if (!Interruptores.estaciones) return null;

  final limpio = codigo.trim();

  // Ni una petición por una casilla vacía: es la misma regla que
  // [letrasMinimasParaBuscar], y el servidor contestaría 422 para decir lo que
  // ya se sabe aquí.
  if (limpio.isEmpty) return null;

  final res =
      await server.get('/estaciones/codigo/${Uri.encodeComponent(limpio)}');

  if (res.statusCode == 404 || res.statusCode == 409) {
    // Gana lo que diga el servidor —sabe si el código no existe o si el papel
    // todavía no es de nadie—, y lo de aquí es el respaldo para cuando contesta
    // su página de error en HTML en vez de JSON.
    throw Exception(
      loQueDijoElServidor(res.body) ??
          (res.statusCode == 409
              ? 'Ese formulario todavía no está atado a ningún alumno. Hay que '
                  'asignárselo antes de empezar el recorrido.'
              : 'No hay ninguna hoja de ruta con ese código.'),
    );
  }

  final crudo = _cuerpo(res, 'la ficha de ese código');

  if (crudo is! Map) return null;
  return FichaDeEstacion.fromJson(Map<String, dynamic>.from(crudo));
}

/// El **texto** de las notas de una persona, por estación.
///
/// Las notas viajan dentro de la ficha —`pasos[].notas_detalle`— y [FichaDeEstacion]
/// hoy guarda sólo los contadores de `pasos[].notas`, así que esto lee la misma
/// respuesta con [notasDeLaFicha] y devuelve lo que allí se pierde. **El día que
/// `PasoDelRecorrido` lleve sus notas dentro, esta función sobra**; se escribe
/// aparte y no ahí porque `EstacionModel.dart` lo está tocando otra sesión.
///
/// La clave es el número de la estación, y **todas** las estaciones vienen: es
/// la razón de ser del módulo —el tesorero deja la nota el lunes en la 5 y la
/// estación 2 la atiende el sábado—.
Future<Map<int, List<NotaDeEstacion>>> traerLasNotasDeLaFicha(
  Server server,
  int personaId,
) async {
  if (!Interruptores.estaciones) return const {};

  final crudo = _cuerpo(
    await server.get('/estaciones/alumno/$personaId'),
    'las notas de esa persona',
  );

  return notasDeLaFicha(crudo);
}

/// Deja una nota en **cualquier** estación, la tuya o no. Null si entró.
///
/// Es la contrapartida exacta de «ver todo, cerrar solo lo tuyo»: el tesorero
/// puede dejar escrito el lunes que esa familia tiene un saldo pendiente, y la
/// estación 5 se atiende el sábado. Entre esas dos fechas el dato existe y no lo
/// ve nadie.
Future<String?> dejarUnaNota(
  Server server, {
  required int nroEstacion,
  required int personaId,
  required String texto,
  bool pendiente = false,
  bool reservada = false,
}) {
  if (!Interruptores.estaciones) {
    return Future.value('Las estaciones todavía no están disponibles.');
  }

  return _mandar(
    server.post('/estaciones/$nroEstacion/nota', {
      'alumno_id': personaId,
      'texto': texto,
      'pendiente': pendiente,
      'reservada': reservada,
    }),
    accion: 'dejar esa nota',
  );
}

/// Lo que se puede contestar al cerrar un paso, y **es una lista cerrada**.
///
/// Las tres palabras son las de `EstacionesController::RESULTADOS`, tal cual y
/// en minúscula: el servidor las compara con `mb_strtolower` y **contesta 422 a
/// cualquier otra cosa**. Se escriben aquí una vez para que ninguna pantalla
/// teclee la cadena.
///
/// **No es [EstadoDelPaso]**, que tiene cuatro valores y sirve para *pintar* lo
/// que llega —incluido `pendiente`, que no se puede mandar—. Éste es lo que se
/// *manda*. Llevan nombre distinto para que nadie los cruce, que es la misma
/// precaución que separó `estadoMatricula` de `estado`.
enum ResultadoDelPaso {
  cumple('cumple'),
  observado('observado'),
  devuelto('devuelto');

  const ResultadoDelPaso(this.comoLoEsperaElServidor);

  /// La palabra exacta que viaja en el cuerpo.
  final String comoLoEsperaElServidor;
}

/// Lo que queda después de cerrar un paso.
///
/// **Es un registro y no un `String?` como el resto de las escrituras, y el
/// motivo está en la respuesta del servidor**: `putMarcar` no contesta «vale»,
/// contesta la ficha entera (`recorrido`) más a qué estación pasa la familia
/// (`siguiente`). Tirarlo obligaría a la pantalla 07 a pedir la ficha otra vez
/// **justo después de escribirla**, o sea una petición de más por cada paso
/// cerrado, ocho horas, sobre un hosting de un núcleo.
///
/// Sigue cumpliendo la regla de las escrituras: **no lanza nunca** y [fallo] es
/// null cuando entró. Es la misma forma que `contrasenaParaElGrupo` en
/// `UsuariosApi.dart`, que devuelve `(fallo, cambiadas)` por lo mismo.
typedef PasoMarcado = ({
  /// Null si entró; si no, el motivo ya escrito para enseñarlo tal cual.
  String? fallo,

  /// Cómo quedó el paso, **con la mayúscula del servidor** (`Cumple`,
  /// `Observado`, `Devuelto`): es lo que se guardó en `requisitos_alumno.estado`.
  String? resultado,

  /// Quién firma el paso. Es `cerrado_por`, **no `updated_by`**: corregir una
  /// observación después no reescribe la firma.
  String? cerradoPor,

  /// Cuándo se cerró, **o null cuando se devolvió**: devolver reabre el paso,
  /// así que no hay hora de cierre que enseñar.
  String? cerradoAt,

  /// A qué estación pasa la familia, si queda alguna. Null es «ya terminó».
  int? siguienteNro,

  /// El nombre de esa estación, que es lo que se le dice a la familia. La clave
  /// del servidor es `donde`.
  String? siguienteDonde,

  /// La ficha entera, ya recalculada. Ahorra la relectura.
  FichaDeEstacion? recorrido,
});

/// **Cierra el paso.** Pantallas 05, 06 y 07. Null en `fallo` si entró.
///
/// ## Lo que el servidor exige, comprobado en el controlador y no supuesto
///
/// - `resultado` es una de las tres de [ResultadoDelPaso]; cualquier otra cosa
///   es **422**.
/// - **`devuelto` sin motivo escrito es 422**, y no es una validación de
///   cortesía: *«lo que escribas aquí lo lee la familia, tal cual, en su
///   celular»*. Se comprueba también aquí para no gastar una petición en
///   averiguar lo que ya se sabe, igual que [letrasMinimasParaBuscar].
/// - [requisitos] es **opcional**: sin lista se cierra la estación entera, que
///   es lo que hace la pantalla cuando el paso tiene un solo requisito —o sea
///   casi siempre—. Lo que se mande que no sea de esta estación, el servidor lo
///   descarta; si no queda ninguno, **422**.
///
/// ## `motivo` y `observacion` NO son el mismo campo, y confundirlos se ve en
/// el celular de una mamá
///
/// [motivo] va a `requisitos_alumno.motivo_devolucion` y **el servidor sólo lo
/// escribe cuando se devuelve**: mandarlo con `cumple` u `observado` se pierde
/// en silencio. [observacion] va a `requisitos_alumno.descripcion`, que es la
/// casilla de siempre de la pantalla vieja de requisitos.
///
/// Y **`observacion` se manda sólo si no es null**, porque el controlador
/// pregunta por `Request::has`: mandar cadena vacía **borra** la observación
/// que hubiera. Null es «no la toques».
///
/// ## Devolver NO cierra, y la pantalla tiene que contarlo así
///
/// Un paso devuelto sigue debiéndose: el servidor limpia `cerrado_at` y
/// `cerrado_por` para que **la cola de esta estación siga viendo a esa persona**
/// y la de la siguiente no. Por eso [PasoMarcado.cerradoAt] vuelve en null y
/// pintar un chulo verde sería mentir.
Future<PasoMarcado> marcarElPaso(
  Server server, {
  required int nroEstacion,
  required int personaId,
  required ResultadoDelPaso resultado,
  String motivo = '',
  String? observacion,
  List<int> requisitos = const [],
}) async {
  if (!Interruptores.estaciones) return _sinCerrarElPaso(_todaviaNo);

  final falta = loQueLeFaltaAlCierre(resultado, motivo);

  if (falta != null) return _sinCerrarElPaso(falta);

  final elMotivo = motivo.trim();

  final cuerpo = <String, dynamic>{
    'alumno_id': personaId,
    'resultado': resultado.comoLoEsperaElServidor,
  };

  if (elMotivo.isNotEmpty) cuerpo['motivo'] = elMotivo;
  if (observacion != null) cuerpo['observacion'] = observacion;
  if (requisitos.isNotEmpty) cuerpo['requisitos'] = requisitos;

  // La respuesta se lee dos veces —el fallo y lo que quedó—, así que se guarda:
  // un Future se espera cuantas veces haga falta, pero la petición no se manda
  // dos.
  final dynamic res;

  try {
    res = await server.put('/estaciones/$nroEstacion/marcar', cuerpo);
  } catch (err) {
    return _sinCerrarElPaso('No se pudo cerrar ese paso: $err');
  }

  final fallo = await _mandar(
    Future.value(res),
    accion: 'cerrar ese paso',
    // De respaldo nada más, y a propósito sin nombrar a nadie: desde el 20 sep
    // 2026 **cierra cualquiera del personal**, así que un 403 aquí sólo puede
    // venir de `auth.personal` —un alumno o un acudiente— o de una regla que el
    // servidor estrene mañana. Quien lo sabe de verdad es él.
    sinPermiso: 'El servidor no te deja cerrar pasos del día de matrículas.',
  );

  if (fallo != null) return _sinCerrarElPaso(fallo);

  return leerElPasoMarcado(res.body);
}

/// Lo que le falta a un cierre para poder mandarse, o null si puede irse ya.
///
/// **Sólo hay una regla y es la del motivo**, que el servidor también comprueba
/// —422— pero que se adelanta aquí para no gastar una petición en averiguar algo
/// que ya se sabe, igual que [letrasMinimasParaBuscar].
///
/// Y esa regla no se puede aflojar: *«lo que escribas aquí lo lee la familia,
/// tal cual, en su celular»*. Devolver a alguien sin decirle por qué es mandarlo
/// a su casa a adivinar.
///
/// Pública por lo mismo que [motivoDeUnaEscritura]: detrás de un `const false`
/// no la alcanzaría ninguna prueba.
String? loQueLeFaltaAlCierre(ResultadoDelPaso resultado, String motivo) {
  if (resultado == ResultadoDelPaso.devuelto && motivo.trim().isEmpty) {
    return 'Para devolver hace falta escribir el motivo: lo lee la familia.';
  }
  return null;
}

/// Lee la respuesta de `PUT estaciones/{nro}/marcar`.
///
/// **Se deja pública y separada de [marcarElPaso] a propósito**: mientras
/// [Interruptores.estaciones] sea `const false`, todo lo que hay después de la
/// guarda es código **inalcanzable desde una prueba**, y sin esto nadie
/// comprobaría que la respuesta se lee bien hasta el día del despliegue — que es
/// el peor día para descubrirlo. Es el mismo motivo de [motivoDeUnaEscritura].
PasoMarcado leerElPasoMarcado(dynamic cuerpo) {
  dynamic crudo;

  try {
    crudo = cuerpo is String && cuerpo.trim().isNotEmpty
        ? jsonDecode(cuerpo)
        : cuerpo;
  } catch (_) {
    crudo = null;
  }

  if (crudo is! Map) {
    // Entró —el estado era 2xx— pero no se entiende la respuesta. **No es un
    // fallo**: el paso se cerró, y decir que no se cerró sería peor que quedarse
    // sin los renglones de después.
    return (
      fallo: null,
      resultado: null,
      cerradoPor: null,
      cerradoAt: null,
      siguienteNro: null,
      siguienteDonde: null,
      recorrido: null,
    );
  }

  final siguiente = crudo['siguiente'];
  final recorrido = crudo['recorrido'];

  return (
    fallo: null,
    resultado: texto(crudo['resultado']),
    cerradoPor: texto(crudo['cerrado_por']),
    cerradoAt: texto(crudo['cerrado_at']),
    siguienteNro: siguiente is Map ? entero(siguiente['nro']) : null,
    siguienteDonde: siguiente is Map ? texto(siguiente['donde']) : null,
    recorrido: recorrido is Map
        ? FichaDeEstacion.fromJson(Map<String, dynamic>.from(recorrido))
        : null,
  );
}

/// **El que llega salteado: registra el intento y NO escribe el paso.**
/// Pantalla 08. Null si entró, o el motivo.
///
/// *«No lo atiendas todavía: le falta la 1»* **lo dice la pantalla, no el
/// profesor**: hoy eso depende de que quien atiende mire bien la hoja, y con
/// fila detrás no mira.
///
/// ## Que no escriba el paso es lo que la hace útil
///
/// El que llega a la 4 sin haber pasado por la 3 no deja marca en el paso 4: el
/// intento se apunta en `envios_estacion`, que es una tabla aparte **para que no
/// cuente en el globo de notas de esa familia**. Así el tablero del rector puede
/// decir *«en la 4 se presentan doce sin pasar por la 3»* sin ensuciar el
/// recorrido de nadie con un paso que no ocurrió.
///
/// Por eso la respuesta trae `paso_escrito: false` y **la pantalla no debe
/// pintar un chulo verde por esto**. Ver [PendientesEstaciones.mandarAlQueLlegaSalteado].
Future<String?> mandarALaEstacionQueFalta(
  Server server, {
  required int desdeLaEstacion,
  required int haciaLaEstacion,
  required int personaId,
}) {
  if (!Interruptores.estaciones) return Future.value(_todaviaNo);

  return _mandar(
    server.put(
      '/estaciones/$desdeLaEstacion/enviar-a/$haciaLaEstacion',
      {'alumno_id': personaId},
    ),
    accion: 'apuntar que hay que mandarlo a otra estación',
    // Las dos estaciones tienen que existir en el recorrido de este año, y el
    // servidor dice **cuál** de las dos falla. Su texto gana.
    porElCuerpo: 'El servidor no aceptó ese envío.',
  );
}

/// **Da por resuelta una nota pendiente.** Null si entró, o el motivo.
///
/// ## Es LA ÚNICA de las nueve con permiso dentro del método, y por eso el
/// motivo lo escribe el servidor y no esta función
///
/// Las nueve rutas llevan `auth.personal` en `routes/api/estaciones.php` y nada
/// más; ésta además llama a `Autoriza::puedeResolverNotaDeEstacion` **dentro**
/// —quien escribió la nota, un superusuario, o los roles `Admin`, `Secretario` o
/// `Rector`— y corta con **403 y el criterio escrito en el cuerpo**.
///
/// **Leer `routes/` y concluir que no filtra es el error**, y no es hipotético:
/// es la misma trampa que tuvo el agujero de `putResetPassword` abierto tres
/// días de más, y la que casi deja este botón encendido para todo el personal.
///
/// Así que aquí se devuelve **lo que dijo el servidor**, con
/// [loQueDijoElServidor], y la pantalla lo pinta tal cual: *«esta nota puede
/// darla por resuelta quien la escribió, o Secretaría, Rectoría o un
/// administrador»* — que es lo que convierte un botón muerto en una instrucción.
/// El respaldo de aquí **no nombra a nadie a propósito**: quién puede cambia con
/// el despliegue —los roles no son los mismos ids en todos los colegios, y la
/// regla se ensanchó a los superusuarios el 20 sep—, y una frase escrita en la
/// app envejece sin avisar. Es lo mismo que hace `contrasenaParaElGrupo`.
///
/// **Y el botón no se enciende para todos**: la ficha ya trae
/// `puedo_resolverla` por nota ([NotaDeEstacion.puedeDarsePorResuelta]), así que
/// la pantalla lo apaga **con el motivo a la vista** en vez de esconderlo y
/// esperar al 403.
///
/// Una segunda pulsación no rompe nada ni le quita el nombre a quien la resolvió
/// de verdad: el servidor escribe `resuelta_por` con `COALESCE`.
Future<String?> darPorResueltaLaNota(
  Server server, {
  required int notaId,
}) {
  if (!Interruptores.estaciones) return Future.value(_todaviaNo);

  return _mandar(
    // Sin cuerpo: el id va en la ruta y el servidor no lee nada más. `Server.put`
    // pide los parámetros, así que va el mapa vacío.
    server.put('/estaciones/nota/$notaId/resuelta', const <String, dynamic>{}),
    accion: 'dar esa nota por resuelta',
    sinPermiso: 'El servidor no te deja dar esa nota por resuelta.',
    // 404 es «esa nota no existe» —o es de otro año, que el servidor comprueba
    // con el `year_id` de la sesión—, y lo dice él con esas palabras.
    porElCuerpo: 'El servidor no aceptó dar esa nota por resuelta.',
  );
}

/// Cuántas letras hacen falta antes de preguntarle al servidor.
///
/// **No es una manía de interfaz: `buscar/por-nombre` hace `LIKE '%texto%'` sin
/// límite de filas**, así que buscar «a» devolvería el colegio entero —más de
/// dos mil personas— por cada tecla. Sobre un hosting de un núcleo eso no es
/// lento: es una caída.
const int letrasMinimasParaBuscar = 3;

/// Busca en TODO el colegio, no solo en una cola.
///
/// Es la pantalla que contesta *«¿y mi hija en qué va?»* a quien se acerca a
/// preguntar, y **funciona hoy**: `PUT buscar/por-nombre` y `por-apellido`
/// llevan desplegadas desde mucho antes que nada del día de matrículas. Por eso
/// esto **no lleva interruptor**.
///
/// **Se piden las dos y se juntan**, porque son dos endpoints y quien busca
/// escribe un nombre sin pensar en cuál de los dos campos es. Buscar «Mejía» por
/// nombre no devuelve nada, y quien lo escribió no tiene por qué saberlo.
Future<List<PersonaEncontrada>> buscarPersonas(
    Server server, String texto) async {
  final limpio = texto.trim();
  if (limpio.length < letrasMinimasParaBuscar) return const [];

  // Las dos a la vez: son independientes, y en serie se nota con mala señal.
  final respuestas = await Future.wait([
    server.put('/buscar/por-nombre', {'texto_a_buscar': limpio}),
    server.put('/buscar/por-apellido', {'texto_a_buscar': limpio}),
  ]);

  // Quien se llame «Laura Laura» saldría dos veces: se junta por id.
  final porId = <int, PersonaEncontrada>{};
  for (final res in respuestas) {
    final crudo = _cuerpo(res, 'las personas del colegio');
    for (final persona in _listaDe(crudo, PersonaEncontrada.fromJson)) {
      if (persona.alumnoId != 0) porId[persona.alumnoId] = persona;
    }
  }

  final salida = porId.values.toList();
  salida.sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
  return salida;
}

/// El recorrido de matrícula de una persona: los N pasos, con quién y cuándo.
///
/// **Esta ruta NO es de las ocho.** `GET requisitos/recorrido/{alumno_id}` la
/// entregó Joseth el 20 sep 2026 y está en `main` de `8myvc`, así que espera
/// solo a un despliegue y no a que se autorice el contrato de estaciones. De ahí
/// que lleve su propio interruptor.
///
/// > **⚠️ NO la llames desde una pantalla de familia, y no confundas su nombre
/// > con el de su vecina.** Existirá `GET requisitos/mi-recorrido/{alumno_id}`
/// > —hoy en una rama sin fundir— para el acudiente. Se diferencian en tres
/// > caracteres y **son para públicos opuestos**:
/// >
/// > - **Ésta** lleva `auth.personal` y trae la observación interna y el nombre
/// >   de quien cerró cada paso. Es **entre el personal**.
/// > - **`mi-recorrido`** lleva `boletin.propio` y **no** trae ni `observacion`
/// >   ni `cerrado_por`. Sí trae `descripcion` —**la del requisito**, que es lo
/// >   que se le pide a la familia—, y ojo con eso: `requisitos_matricula` y
/// >   `requisitos_alumno` **tienen las dos una columna `descripcion`**, y la
/// >   interna es la que en esta ruta sale con el alias `observacion`.
/// >
/// > **Equivocarse no duele igual en los dos sentidos.** Una pantalla de familia
/// > que llame a ésta recibe **403 siempre**: ruidoso y seguro. Pero una de
/// > personal cableada a `mi-recorrido` recibe **200 siempre** —el guard deja
/// > pasar de largo a quien no es `Alumno` ni `Acudiente`, a propósito, para que
/// > secretaría pueda enseñarle la vista a una madre— y el síntoma no es un
/// > error: son **dos campos que faltan**. Eso no lo caza ninguna prueba.
/// >
/// > El contrato entero y lo medido, en `docs/backend-pendiente.md` §7.bis.
Future<RecorridoDeMatricula?> traerElRecorrido(
  Server server,
  int alumnoId,
) async {
  if (!Interruptores.recorridoDeMatricula) return null;

  final crudo = _cuerpo(
    await server.get('/requisitos/recorrido/$alumnoId'),
    'el recorrido de esa persona',
  );

  if (crudo == null) return null;
  return RecorridoDeMatricula.fromJson(crudo);
}

// ---------------------------------------------------------------------------
// Los ayudantes, con la misma forma que en el resto de `lib/Http/`.
// ---------------------------------------------------------------------------

/// Lo que contesta cualquier escritura con el interruptor apagado.
///
/// **No es «no disponible»**: quien lee esto es personal del colegio, y lo que
/// le sirve es saber que falta un despliegue y no que la app está rota. Es la
/// misma frase para las cuatro escrituras a propósito, para que no se
/// multipliquen las maneras de decir lo mismo.
const String _todaviaNo = 'Las estaciones todavía no están disponibles.';

/// Un [PasoMarcado] que dice por qué no se cerró nada.
PasoMarcado _sinCerrarElPaso(String fallo) => (
      fallo: fallo,
      resultado: null,
      cerradoPor: null,
      cerradoAt: null,
      siguienteNro: null,
      siguienteDonde: null,
      recorrido: null,
    );

/// Lecturas: lanzan con el motivo ya escrito en español, para enseñarlo tal cual.
dynamic _cuerpo(dynamic res, String que) {
  if (res.statusCode == 401 || res.statusCode == 403) {
    throw Exception('No tienes permiso para ver $que.');
  }
  if (res.statusCode == 404) {
    // Se dice qué falta y no «no disponible»: quien lo lee es quien puede
    // pedirlo. Ver `docs/backend-pendiente.md` §8.
    throw Exception(
      'Tu colegio todavía no tiene las estaciones del día de matrículas.',
    );
  }
  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }
  final cuerpo = res.body;
  if (cuerpo is! String || cuerpo.trim().isEmpty) return null;
  return jsonDecode(cuerpo);
}

/// El cuerpo de una respuesta como mapa, venga ya decodificado o en texto.
///
/// Las funciones que piden usan [_cuerpo], que ya decodifica; las que leen son
/// públicas para que una prueba pueda llamarlas **con el JSON crudo del
/// contrato**, que es como está escrito en el `.md` del servidor y por tanto lo
/// que de verdad se quiere comprobar. Un texto que no es JSON no revienta: no
/// hay respuesta que leer.
Map<String, dynamic>? _comoMapa(dynamic cuerpo) {
  dynamic crudo = cuerpo;

  if (crudo is String) {
    if (crudo.trim().isEmpty) return null;
    try {
      crudo = jsonDecode(crudo);
    } catch (_) {
      return null;
    }
  }

  return crudo is Map ? Map<String, dynamic>.from(crudo) : null;
}

/// Sí, no, o **no lo dijo**.
///
/// Los `tinyint` de esta casa llegan `1`, `'1'`, `true` o `'true'` según la
/// ruta y el driver de PDO (ver `JsonBackend`). Lo que esto añade sobre un
/// `_verdad` de toda la vida es el tercer caso: **una clave que no vino
/// devuelve `null` y no `false`**, porque «el servidor dice que no» y «este
/// servidor no sabe de esto» mandan a la pantalla a decir cosas distintas.
bool? _siONo(dynamic valor) {
  if (valor == null) return null;
  if (valor is bool) return valor;

  final crudo = '$valor'.trim().toLowerCase();
  if (crudo.isEmpty || crudo == 'null') return null;

  return crudo == '1' || crudo == 'true' || crudo == 'si' || crudo == 'sí';
}

List<T> _listaDe<T>(dynamic crudo, T Function(Map<String, dynamic>) haz) {
  if (crudo is! List) return const [];
  final salida = <T>[];
  for (final uno in crudo) {
    if (uno is Map) salida.add(haz(Map<String, dynamic>.from(uno)));
  }
  return salida;
}

/// Escrituras: nunca lanzan. Null si entró, o el motivo.
Future<String?> _mandar(
  Future peticion, {
  required String accion,
  String? sinPermiso,
  String? porElCuerpo,
}) async {
  try {
    return motivoDeUnaEscritura(
      await peticion,
      accion: accion,
      sinPermiso: sinPermiso,
      porElCuerpo: porElCuerpo,
    );
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}

/// Por qué el servidor no aceptó una escritura, **con sus palabras si las tiene**.
///
/// ## Cuando el servidor explica por qué dijo que no, gana su explicación
///
/// `Autoriza::exigir` corta con un `abort(403, '…')` que trae escrito **el
/// criterio exacto**, y aquí eso no es un lujo: `putNotaResuelta` es la única de
/// las nueve con permiso dentro, y su 403 dice *«esta nota puede darla por
/// resuelta quien la escribió, o Secretaría, Rectoría o un administrador»*. Esa
/// frase es lo que convierte un botón muerto en una instrucción, y **escribirla
/// en la app la dejaría envejecer en silencio**: los ids de los roles no son los
/// mismos en los dieciséis colegios y la regla ya se ensanchó una vez —a los
/// superusuarios, el 20 sep 2026—.
///
/// Los mensajes de aquí son el respaldo para cuando el servidor no se explica o
/// contesta su página de error en HTML en vez de JSON, que pasa siempre que la
/// petición no manda `Accept: application/json` — o sea, en esta app, siempre.
///
/// ## Lo que NO se enseña, y es la mitad de [loQueDijoElServidor]
///
/// Un volcado de excepción con su traza es JSON perfectamente válido, así que el
/// recorte por largo y por saltos de línea de allí es lo que impide enseñárselo
/// a un docente. Y a partir de **500 ni se mira**: ahí ya no hay un motivo
/// escrito para nadie, hay un servidor roto.
///
/// **Se deja pública** —no `_privada`— porque mientras
/// [Interruptores.estaciones] sea `const false` las escrituras vuelven antes de
/// llegar aquí, y sin esto **ninguna prueba podría comprobar que el 403 con el
/// motivo dentro llega hasta la pantalla**. Comprobarlo el día del despliegue es
/// tarde.
String? motivoDeUnaEscritura(
  dynamic res, {
  required String accion,
  String? sinPermiso,
  String? porElCuerpo,
}) {
  final codigo = res.statusCode as int;

  if (codigo < 300) return null;

  if (codigo >= 500) return 'El servidor respondió $codigo.';

  final dijo = loQueDijoElServidor(res.body);

  if (codigo == 401 || codigo == 403) {
    return dijo ?? sinPermiso ?? 'No tienes permiso para $accion.';
  }

  // El 404 entra aquí y no en el saco de «respondió 404» porque en estas rutas
  // **es una frase y no un número**: «esa estación no existe en el recorrido de
  // este año», «ese alumno no existe», «esa nota no existe». Y el 409 de
  // `codigo/{codigo}` es directamente lo que hay que hacer.
  if (codigo == 400 || codigo == 404 || codigo == 409 || codigo == 422) {
    return dijo ?? porElCuerpo ?? 'El servidor no aceptó $accion.';
  }

  return dijo ?? 'El servidor respondió $codigo.';
}
