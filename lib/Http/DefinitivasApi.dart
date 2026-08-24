import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/MensajesDelServidor.dart';

/// Las definitivas del periodo: la nota consolidada de un alumno en una
/// asignatura, la que acaba en el boletín.
///
/// Son tres endpoints y **no son independientes entre sí**. El backend cruza
/// las dos banderas por su cuenta, así que después de cada llamada hay que
/// pintar lo que de verdad quedó, no lo que se pidió. Las tres trampas, sacadas
/// de `DefinitivasPeriodosController`:
///
///  1. **Cambiar la nota la vuelve manual.** `putUpdate` hace
///     `SET nota=?, manual=true` en la misma sentencia; no hay forma de
///     corregir el número dejándola automática. Y tiene sentido: si no fuera
///     manual, el siguiente `notas/detailed` la borraría y la volvería a
///     calcular —lo hace literalmente, con un DELETE y un INSERT—.
///  2. **Quitar «manual» quita también «recuperada»**, en la misma sentencia.
///     Una nota recuperada que dejara de ser manual se perdería al primer
///     recálculo, así que el backend no permite esa combinación.
///  3. **Marcar «recuperada» la vuelve manual**, por lo mismo del punto
///     anterior visto al derecho.
///
/// El permiso es `profes_pueden_nivelar`, que es **otro** distinto del de las
/// notas de subunidad, y se niega con un **400**, no con un 403. Ver
/// `User::pueden_modificar_definitivas`.
///
/// Ninguna de las tres devuelve la fila cambiada —contestan la cadena
/// 'Cambiada'—, y por eso quien llama actualiza su copia en memoria aplicando
/// estas mismas reglas. [NotaFinalDelLibro.trasCambiar…] las tiene escritas una
/// sola vez.

/// Cambia la nota definitiva. Devuelve null si entró, o el motivo si no.
///
/// **Deja la definitiva marcada como manual**, siempre. Ver la trampa 1.
Future<String?> guardarDefinitiva(
  Server server, {
  required int nfId,
  required double nota,
}) {
  return _pedir(
    server,
    ruta: '/definitivas_periodos/update',
    cuerpo: {'nf_id': nfId, 'nota': nota},
    accion: 'cambiar la definitiva',
  );
}

/// Marca o desmarca la definitiva como puesta a mano.
///
/// Desmarcarla **también le quita «recuperada»**. Ver la trampa 2.
Future<String?> alternarManual(
  Server server, {
  required int nfId,
  required bool manual,
}) {
  return _pedir(
    server,
    ruta: '/definitivas_periodos/toggle-manual',
    // Como 1 y 0 y no como true/false: el backend lo mete tal cual en un
    // `DB::update` contra una columna tinyint, y un booleano de JSON llega a
    // PHP como booleano pero a MySQL le entra mejor el número. Del lado del
    // `if ($manual)` que decide la rama, 0 y false valen igual.
    cuerpo: {'nf_id': nfId, 'manual': manual ? 1 : 0},
    accion: manual ? 'marcarla como manual' : 'devolverla a automática',
  );
}

/// Marca o desmarca que la definitiva viene de una recuperación.
///
/// Marcarla **la vuelve además manual**. Ver la trampa 3.
Future<String?> alternarRecuperada(
  Server server, {
  required int nfId,
  required bool recuperada,
}) {
  return _pedir(
    server,
    ruta: '/definitivas_periodos/toggle-recuperada',
    cuerpo: {'nf_id': nfId, 'recuperada': recuperada ? 1 : 0},
    accion: recuperada ? 'marcarla como recuperada' : 'quitarle la recuperación',
  );
}

Future<String?> _pedir(
  Server server, {
  required String ruta,
  required Map<String, dynamic> cuerpo,
  required String accion,
}) async {
  try {
    final res = await server.put(ruta, cuerpo);

    // 400 y no 403: `User::pueden_modificar_definitivas` aborta con 400, así
    // que aquí ese código no significa «petición mal hecha» sino «no te dejan».
    // El 403 lo dan los dos controladores por su cuenta cuando quien llama no
    // es profesor ni superusuario.
    if (res.statusCode == 400 || res.statusCode == 403) {
      return 'No tienes permiso para nivelar en este periodo.';
    }
    // 422 es la escala, y el motivo viene en el cuerpo. Aquí duele más que en
    // la planilla: nivelar se hace con el periodo cerrándose encima, y quedarse
    // mirando un número sin saber qué nota sí cabe es perder la tarde.
    if (res.statusCode == 422) {
      return motivoDeRechazo(
        res.body,
        respaldo: 'La nota no cabe en la escala del año.',
      );
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo $accion: $err';
  }
}
