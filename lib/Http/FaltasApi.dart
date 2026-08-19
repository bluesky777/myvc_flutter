import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// Las llamadas que cambian una falta ya registrada.
///
/// Están aquí y no en cada pantalla porque son las mismas desde la asistencia a
/// clases y desde el histórico por periodo, y el mensaje de error también.

/// Cambia el día de una falta.
///
/// Es PUT ausencias/guardar-cambios-ausencia, el mismo endpoint que usa la
/// plataforma web, con el mismo formato de fecha. Devuelve null si se guardó, o
/// el mensaje de lo que pasó.
Future<String?> cambiarFechaDeFalta({
  required Server server,
  required int faltaId,
  required DateTime nueva,
}) async {
  try {
    final res = await server.put('/ausencias/guardar-cambios-ausencia', {
      'ausencia_id': faltaId,
      'fecha_hora': fechaHoraParaServidor(nueva),
    });

    if (res.statusCode >= 300) {
      return mensajeDeFallo(res.statusCode, 'cambiar la fecha');
    }
    return null;
  } catch (err) {
    return 'Error cambiando la fecha: $err';
  }
}

/// Qué decirle al docente ante un código HTTP.
///
/// El backend responde 400 con 'No tienes permiso' cuando el periodo está
/// cerrado para docentes, que es el caso que más se da; el número suelto no le
/// dice nada a nadie.
String mensajeDeFallo(int codigo, String accion) {
  if (codigo == 400 || codigo == 401 || codigo == 403) {
    return 'No tienes permiso para $accion en este periodo.';
  }
  return 'No se pudo $accion (HTTP $codigo).';
}
