import 'dart:convert';

import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La cola de marcas que se hicieron en el patio y el servidor todavía no sabe.
///
/// Pantalla 09 de `docs/estaciones.md` y su decisión, la §2.6: *«el patio tiene
/// mala señal y la jornada no se puede parar, así que se sigue atendiendo con
/// la marca guardada en el teléfono»*. Esto es ese guardado, y nada más: **no
/// manda nada, no reintenta nada y no pinta nada**. Quien la use decide cuándo
/// vaciarla y cómo enseñarla.
///
/// ## Lo que esta cola existe para impedir, escrito para que no se pierda
///
/// Lo que **no** se puede hacer es pintar una marca de aquí igual que una
/// guardada de verdad:
///
/// - **reloj naranja** = marcado aquí, el servidor no lo sabe → [elServidorNoLoSabe]
/// - **chulo verde** = el servidor contestó → ya no está en esta cola
///
/// *«Un verde optimista ahorra un icono y cuesta que alguien jure que marcó a un
/// alumno que no está marcado»* (§2.6). Y la consecuencia se dice con todas las
/// letras, que es lo que va en [laConsecuencia]: la estación siguiente **no ve**
/// a esa familia hasta que esto salga de aquí, así que hay que decirle a dónde
/// va en vez de esperar al aviso.
///
/// ## Por qué la clave lleva dentro el id del usuario
///
/// Igual que [PreferenciaEstacion], y aquí el motivo pesa el doble. La tablet
/// del colegio **pasa de mano en mano entre estaciones** —decidido el 20 sep
/// 2026: se atiende con teléfono y con tablet—, y una cola guardada a secas se
/// la encontraría puesta quien cogiera el aparato después.
///
/// Y no es solo que vería marcas ajenas: desde el 20 sep **cierra cualquiera
/// del personal y el paso queda firmado con su nombre y su hora** (§2.9), así
/// que mandar la marca de otro la firmaría con el nombre de quien la mande. La
/// firma es lo único que protege el paso —no hay 403 por rol—, y una cola
/// compartida la falsearía en silencio.
///
/// ## Lo que NO hace, a propósito
///
/// - **No tiene tope.** Una cola que se recortara sola por largo tiraría
///   justamente la marca que alguien jura que hizo, que es el fallo que esta
///   pantalla entera existe para evitar. Si crece, es que lleva horas sin red y
///   eso hay que verlo, no taparlo.
/// - **No guarda la hora del servidor**, porque no la tiene: [MarcaSinMandar.marcadaAt]
///   es el reloj del teléfono del docente, que **no es fuente de verdad** —lo
///   dice `NotaDeEstacion.cuando` por lo mismo—. Sirve para ordenar la cola y
///   para decir «marcado aquí a las 10:32»; la hora que queda escrita en el
///   recorrido la pone el servidor cuando la marca llegue.
class MarcasSinMandar {
  MarcasSinMandar._();

  /// La línea que la pantalla 09 enseña, escrita una sola vez.
  ///
  /// Está aquí y no en la pantalla para que no se reescriba con otras palabras
  /// en el sitio siguiente donde haga falta: es una frase de `docs/estaciones.md`
  /// §2.6, no una redacción de una pantalla.
  static const String laConsecuencia =
      'La estación siguiente aún no lo ve: dile a la familia a dónde va, no '
      'esperes al aviso.';

  /// La clave de este usuario en `shared_preferences`.
  ///
  /// **Pública para que una prueba pueda comprobar que el id va dentro.** Esa
  /// comprobación no es de estilo: es la garantía de que la tablet compartida
  /// no cruza las marcas de dos docentes, y una prueba que solo mirara lo
  /// guardado no distinguiría una clave con id de una sin él.
  static String clave() => 'estaciones.sinmandar.${AuthService.user.id ?? 0}';

  /// Lo que está esperando a que haya señal, **en el orden en que se marcó**.
  ///
  /// El orden importa y por eso no se toca: es el orden de la fila del patio.
  /// Mandarlas desordenadas escribiría el recorrido en un orden que no ocurrió.
  ///
  /// Lista vacía si no hay nada **y también si lo guardado no se entiende**:
  /// una versión anterior pudo escribir otra forma, y reventar aquí dejaría sin
  /// abrir la pantalla que sirve justamente para cuando algo va mal.
  static Future<List<MarcaSinMandar>> pendientes() async {
    final preferences = await SharedPreferences.getInstance();
    return _leer(preferences);
  }

  /// Cuántas esperan. Para el contador de la pantalla, sin leerlas todas fuera.
  static Future<int> cuantas() async => (await pendientes()).length;

  /// Apunta una marca que no se pudo mandar. **Null si entró**, o el motivo.
  ///
  /// Devuelve el motivo en vez de lanzar, igual que las escrituras de
  /// `EstacionesApi`: quien llama a esto está en un patio sin señal y lo que
  /// necesita es una frase que enseñar, no una excepción que atrapar.
  ///
  /// **Una persona y una estación son una sola marca**: si ya había una suya
  /// esperando, se sustituye en vez de encolarse otra. Marcar dos veces a la
  /// misma persona en la misma estación es corregirse —lo que pasa cuando en
  /// una fila con dos hermanos apellidados igual se toca el renglón de al lado
  /// (§2.7)—, y mandar las dos escribiría el paso dos veces, la segunda con lo
  /// que ya se había corregido.
  ///
  /// La corregida **se queda en el sitio que tenía**: la cola es el orden de la
  /// fila, y corregir a alguien no lo pone detrás de los que llegaron después.
  ///
  /// ## La regla del motivo no se afloja por estar sin red
  ///
  /// Se comprueba con [loQueLeFaltaAlCierre], **la misma función que usa el
  /// cierre normal**, y no con una copia: *«lo que escribas aquí lo lee la
  /// familia, tal cual, en su celular»*. Una devolución sin motivo encolada
  /// aquí sería un 422 cuando vuelva la señal —o sea horas después, con la
  /// familia ya en su casa y sin saber por qué la mandaron—, que es el peor
  /// momento posible para enterarse.
  static Future<String?> apuntar(MarcaSinMandar marca) async {
    final falta = loQueLeFaltaAlCierre(marca.resultado, marca.motivo);
    if (falta != null) return falta;

    final preferences = await SharedPreferences.getInstance();
    final cola = _leer(preferences);

    final donde = cola.indexWhere(
      (una) =>
          una.personaId == marca.personaId &&
          una.nroEstacion == marca.nroEstacion,
    );

    if (donde >= 0) {
      cola[donde] = marca;
    } else {
      cola.add(marca);
    }

    await _guardar(preferences, cola);
    return null;
  }

  /// La marca que espera por esa persona en esa estación, o null si no hay.
  static Future<MarcaSinMandar?> laDe({
    required int personaId,
    required int nroEstacion,
  }) async {
    for (final una in await pendientes()) {
      if (una.personaId == personaId && una.nroEstacion == nroEstacion) {
        return una;
      }
    }
    return null;
  }

  /// **La pregunta que decide el icono**: ¿está marcado aquí y el servidor no
  /// lo sabe?
  ///
  /// Se llama así y no `estaPendiente` para que en la pantalla se lea lo que de
  /// verdad significa. Verdadero es reloj naranja **y la frase de
  /// [laConsecuencia]**; falso no es «guardado», es «esta cola no tiene nada
  /// suyo» — el chulo verde lo pinta quien sepa que el servidor contestó.
  static Future<bool> elServidorNoLoSabe({
    required int personaId,
    required int nroEstacion,
  }) async =>
      await laDe(personaId: personaId, nroEstacion: nroEstacion) != null;

  /// Sale de la cola porque el servidor ya la tiene. Ése es el único motivo.
  ///
  /// Se llama por lo que ocurrió y no `quitar`, para que borrar una marca sin
  /// que nadie la haya recibido cueste escribir una frase que no es verdad.
  static Future<void> yaLaTieneElServidor({
    required int personaId,
    required int nroEstacion,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final cola = _leer(preferences)
      ..removeWhere(
        (una) => una.personaId == personaId && una.nroEstacion == nroEstacion,
      );

    await _guardar(preferences, cola);
  }

  /// Tira la cola de este usuario.
  ///
  /// **No se llama al cerrar sesión sin más**: lo que hay aquí son pasos que
  /// alguien marcó y el colegio todavía no sabe. Es para cuando ya se mandaron
  /// todas, o para cuando quien las hizo decide a la vista que no valen.
  static Future<void> olvidarTodo() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(clave());
  }

  static List<MarcaSinMandar> _leer(SharedPreferences preferences) {
    final crudo = preferences.getString(clave());

    if (crudo == null || crudo.trim().isEmpty) return <MarcaSinMandar>[];

    dynamic leido;
    try {
      leido = jsonDecode(crudo);
    } catch (_) {
      return <MarcaSinMandar>[];
    }

    if (leido is! List) return <MarcaSinMandar>[];

    final salida = <MarcaSinMandar>[];
    for (final una in leido) {
      if (una is! Map) continue;
      final marca = MarcaSinMandar.deJson(Map<String, dynamic>.from(una));
      if (marca != null) salida.add(marca);
    }
    return salida;
  }

  static Future<void> _guardar(
    SharedPreferences preferences,
    List<MarcaSinMandar> cola,
  ) async {
    if (cola.isEmpty) {
      await preferences.remove(clave());
      return;
    }

    await preferences.setString(
      clave(),
      jsonEncode([for (final una in cola) una.aJson()]),
    );
  }
}

/// Un paso que se cerró en el patio y todavía no ha salido del teléfono.
///
/// Lleva **el nombre de la persona y el de la estación dentro**, y eso es a
/// propósito aunque los dos se puedan volver a pedir: sin señal no se pueden
/// pedir. Una cola que enseñara «alumno 4821 · estación 3» no sirve para lo
/// único que hay que hacer con ella, que es mirarla y saber a quién le falta
/// llegar al servidor.
class MarcaSinMandar {
  const MarcaSinMandar({
    required this.personaId,
    required this.nombre,
    required this.nroEstacion,
    required this.nombreEstacion,
    required this.resultado,
    required this.marcadaAt,
    this.motivo = '',
    this.observacion,
    this.requisitos = const [],
  });

  /// `alumno_id`, que es lo que pide `PUT estaciones/{nro}/marcar`.
  final int personaId;

  /// Cómo se llama, para poder enseñarla sin preguntarle a nadie.
  final String nombre;

  /// El número impreso en la cartulina, que es `requisitos_matricula.orden`.
  final int nroEstacion;

  /// El nombre que el colegio le puso a esa estación. Se guarda por lo mismo
  /// que [nombre]: sin señal no hay de dónde sacarlo.
  final String nombreEstacion;

  /// Cumple, observado o devuelto. **Es la lista cerrada del servidor**
  /// ([ResultadoDelPaso]) y no una cadena suelta: guardar aquí una palabra que
  /// el servidor rechaza con 422 sería guardar una marca que no se va a poder
  /// mandar nunca, y descubrirlo cuando vuelva la señal.
  final ResultadoDelPaso resultado;

  /// El motivo de la devolución, **que lo lee la familia tal cual**. Vacío en
  /// los otros dos resultados, donde el servidor lo descarta.
  ///
  /// Que viaje aquí es lo que permite devolver sin señal. Y la regla del botón
  /// no se afloja por estar sin red: sin motivo escrito no hay devolución que
  /// guardar, igual que la comprueba `loQueLeFaltaAlCierre`.
  final String motivo;

  /// La observación de `requisitos_alumno.descripcion`, o null para no tocarla.
  ///
  /// Null y cadena vacía **no son lo mismo** aguas abajo —la vacía borra lo que
  /// hubiera—, así que se guarda la diferencia en vez de normalizarla.
  final String? observacion;

  /// Qué requisitos de esa estación se cerraron, si no fue la estación entera.
  ///
  /// Vacía es «ciérrala entera», que es lo que hace la pantalla cuando el paso
  /// tiene un solo requisito —o sea casi siempre—. **Se guarda porque si no,
  /// una marca parcial se replicaría como total** cuando vuelva la señal: el
  /// docente habría chuleado dos de cuatro papeles y el servidor daría los
  /// cuatro por entregados, sin que nada fallara ni nadie se enterara.
  final List<int> requisitos;

  /// Cuándo se marcó **según el reloj de este teléfono**.
  ///
  /// No es la hora que quedará escrita en el recorrido: ésa la pone el servidor
  /// cuando la marca llegue. Sirve para ordenar y para decir en la pantalla
  /// desde cuándo espera.
  final DateTime marcadaAt;

  Map<String, dynamic> aJson() => {
        'persona_id': personaId,
        'nombre': nombre,
        'nro_estacion': nroEstacion,
        'nombre_estacion': nombreEstacion,
        'resultado': resultado.comoLoEsperaElServidor,
        'motivo': motivo,
        'observacion': observacion,
        'requisitos': requisitos,
        'marcada_at': marcadaAt.toIso8601String(),
      };

  /// Lee una marca guardada, **o null si no se entiende**.
  ///
  /// Devuelve null en vez de lanzar porque lo de fuera es una lista: una fila
  /// ilegible no puede llevarse por delante las otras nueve, que son nueve
  /// pasos que alguien marcó de verdad.
  static MarcaSinMandar? deJson(Map<String, dynamic> json) {
    final resultado = _elResultado(json['resultado']);
    final persona = json['persona_id'];
    final nro = json['nro_estacion'];

    if (resultado == null || persona is! int || nro is! int) return null;

    final cuando = DateTime.tryParse('${json['marcada_at']}');
    if (cuando == null) return null;

    return MarcaSinMandar(
      personaId: persona,
      nombre: '${json['nombre'] ?? ''}',
      nroEstacion: nro,
      nombreEstacion: '${json['nombre_estacion'] ?? ''}',
      resultado: resultado,
      motivo: '${json['motivo'] ?? ''}',
      observacion:
          json['observacion'] is String ? json['observacion'] as String : null,
      requisitos: _losRequisitos(json['requisitos']),
      marcadaAt: cuando,
    );
  }

  /// Los ids de los requisitos, saltándose lo que no sea un número.
  ///
  /// **Saltarse uno ilegible es lo correcto aquí y no en la marca entera**: un
  /// requisito que no se entiende es un papel que no se da por entregado, y
  /// quedarse corto se ve —el paso sigue abierto— mientras que pasarse no.
  static List<int> _losRequisitos(dynamic crudo) {
    if (crudo is! List) return const [];

    final salida = <int>[];
    for (final uno in crudo) {
      final id = entero(uno);
      if (id != null) salida.add(id);
    }
    return salida;
  }

  /// La palabra guardada, contra la lista cerrada del servidor.
  ///
  /// Null si no es ninguna de las tres. Pasa si otra versión de la app escribió
  /// algo distinto, y entonces la marca **no se puede mandar**: el servidor la
  /// rechazaría con 422. Guardarla igual sería dejar en la cola algo que no
  /// sale nunca, y eso es peor que no tenerla, porque el contador diría que
  /// falta una y nadie podría vaciarla.
  static ResultadoDelPaso? _elResultado(dynamic crudo) {
    final palabra = '$crudo'.trim().toLowerCase();

    for (final uno in ResultadoDelPaso.values) {
      if (uno.comoLoEsperaElServidor == palabra) return uno;
    }
    return null;
  }
}
