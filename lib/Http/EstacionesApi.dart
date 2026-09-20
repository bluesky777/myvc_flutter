import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// Las estaciones del día de matrículas.
///
/// **Nada de esto llama al servidor mientras [Interruptores.estaciones] esté
/// apagado**, y no por prudencia: las ocho rutas `estaciones/*` **no existen en
/// ningún colegio todavía**. Llamarlas sería gastar un 404 por apertura sobre un
/// hosting de un núcleo, que es justo lo que este proyecto lleva un año
/// evitando. Ver `docs/backend-pendiente.md` §8.
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
  /// **Decidido por Joseth el 20 sep 2026: entra.** Lo que falta es del lado de
  /// esta app — `pubspec.yaml` tiene `firebase_core` y `firebase_analytics` y
  /// **no tiene `firebase_messaging`**— y del lado del servidor, publicar en el
  /// momento en vez de por la tanda de quince minutos.
  ///
  /// **La cola sondeada no se retira cuando esto se encienda.** Un push se
  /// pierde, llega tarde o está apagado en los ajustes del teléfono, y la fila
  /// del patio no se puede parar por eso: el push **adelanta** el aviso, la cola
  /// **garantiza** que nadie se quede invisible.
  static bool pushInmediato = false;

  /// Dar por resuelta una nota pendiente.
  ///
  /// **Esto no espera a un despliegue: espera a una ruta que nadie ha pedido.**
  /// El permiso está decidido y escrito —quien la escribió, o `Admin`,
  /// `Secretario` o `Rector`— y la tabla `notas_estacion` tiene sus columnas
  /// `resuelta_por` y `resuelta_at`, pero **entre las ocho rutas del contrato no
  /// hay ninguna que las escriba**: `POST estaciones/{nro}/nota` crea, y no hay
  /// hermana que resuelva.
  ///
  /// Queda anotado aquí y en `docs/backend-pendiente.md` §8 porque un hueco de
  /// contrato que solo vive en la cabeza de alguien se descubre el día del
  /// despliegue.
  static bool resolverUnaNota = false;

  /// Deja los interruptores como vienen de fábrica. Para las pruebas.
  ///
  /// «De fábrica» es lo que hay escrito arriba, no «todo apagado»: si esto se
  /// desincroniza, las pruebas dejan de comprobar la app que se publica.
  static void comoDeFabrica() {
    marcarElPaso = false;
    devolverConMotivo = false;
    escanearElCodigo = false;
    pushInmediato = false;
    resolverUnaNota = false;
  }
}

/// El recorrido que armó este colegio.
///
/// **Una lista vacía y «este colegio no armó recorrido» no son lo mismo**, y por
/// eso esto devuelve la lista tal cual: quien la pinta decide qué decir. Ver
/// `docs/estaciones.md` §2.8.
Future<List<Estacion>> traerLasEstaciones(Server server) async {
  if (!Interruptores.estaciones) return const [];

  final crudo = _cuerpo(
    await server.get('/estaciones'),
    'las estaciones del colegio',
  );

  if (crudo is! Map) return const [];
  return _listaDe(crudo['estaciones'], Estacion.fromJson);
}

/// Los que me llegan: cerraron el paso anterior y no han cerrado el mío.
///
/// **Es una consulta, no una bandeja de avisos**, y ésa es la decisión que
/// sostiene todo el módulo. Un aviso perdido deja a la familia en la fila igual;
/// una bandeja con un aviso perdido la deja **invisible para siempre** y nadie
/// sabe que falta. Por eso no hay nada que marcar como leído: no hay nada que
/// vaciar, hay una pregunta que se vuelve a hacer.
Future<List<PersonaEnCola>> traerLaCola(Server server, int nroEstacion) async {
  if (!Interruptores.estaciones) return const [];

  final crudo = _cuerpo(
    await server.get('/estaciones/$nroEstacion/cola'),
    'la cola de tu estación',
  );

  if (crudo is! Map) return const [];
  return _listaDe(crudo['cola'], PersonaEnCola.fromJson);
}

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

  final crudo = _cuerpo(
    await server.get('/estaciones/huella'),
    'si cambió algo en tu estación',
  );

  if (crudo is! Map) return const {};
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
      huella[nro] = '${valor['n']}|${valor['ultimo_cambio']}';
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

List<T> _listaDe<T>(dynamic crudo, T Function(Map<String, dynamic>) haz) {
  if (crudo is! List) return const [];
  final salida = <T>[];
  for (final uno in crudo) {
    if (uno is Map) salida.add(haz(Map<String, dynamic>.from(uno)));
  }
  return salida;
}

/// Escrituras: nunca lanzan. Null si entró, o el motivo.
Future<String?> _mandar(Future peticion, {required String accion}) async {
  try {
    final res = await peticion;

    if (res.statusCode == 401 || res.statusCode == 403) {
      return 'No tienes permiso para $accion.';
    }
    if (res.statusCode == 400 || res.statusCode == 422) {
      return 'El servidor no aceptó $accion.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}
