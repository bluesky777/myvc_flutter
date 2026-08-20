import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/UniformeModel.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';

/// Las fallas de uniforme de un alumno.
///
/// Cuatro rutas, todas PUT y ninguna con id en la dirección: el backend lo lee
/// del cuerpo, también para el alta y para la baja. No es un descuido de esta
/// capa, es como está registrado allí.
///
/// Las tres escrituras pasan por `User::pueden_editar_notas`, así que con el
/// periodo cerrado para docentes responden 400. [mensajeDeFallo] ya lo cuenta
/// con esas palabras en vez de enseñar el número.
///
/// La lectura no está aquí: las fallas vienen dentro de `disciplina/alumnos`,
/// con el resto del año del alumno, y no hay endpoint que las traiga sueltas.

/// Registra una falla. `PUT uniformes/agregar`.
///
/// Devuelve la fila recién creada, que es la que se añade a la lista sin
/// recargar el grupo entero.
///
/// `asignatura_id` y `materia` se dejan fuera a propósito: esta pantalla anota
/// a nombre del periodo, no de una clase. La planilla de la web los rellena
/// porque se abre desde una asignatura.
Future<ResultadoUniforme> agregarUniforme(
  Server server, {
  required int alumnoId,
  required int periodoId,
  required UniformeModel uniforme,
}) async {
  try {
    final res = await server.put('/uniformes/agregar', {
      ...uniforme.aCuerpo(),
      'alumno_id': alumnoId,
      'periodo_id': periodoId,
      // Sin fecha la columna se queda en null y la falla no se puede situar en
      // el periodo al leerla. Se manda el momento en que se está registrando.
      'fecha_hora':
          fechaHoraParaServidor(uniforme.fechaHora ?? DateTime.now()),
    });

    if (res.statusCode >= 300) {
      return ResultadoUniforme.mal(
          mensajeDeFallo(res.statusCode, 'registrar la falla de uniforme'));
    }

    final cuerpo = jsonDecode(res.body);
    final cruda = cuerpo is Map ? cuerpo['uniforme'] : null;

    if (cruda is! Map) {
      return ResultadoUniforme.mal(
          'Se registró, pero el servidor no devolvió la falla.');
    }

    return ResultadoUniforme.bien(
      UniformeModel.fromJson(Map<String, dynamic>.from(cruda)),
    );
  } catch (err) {
    return ResultadoUniforme.mal(
        'No se pudo registrar la falla de uniforme: $err');
  }
}

/// Guarda los cambios de una falla. `PUT uniformes/actualizar`.
///
/// Van las siete marcas siempre, encendidas o apagadas: el backend reescribe
/// las siete columnas con lo que reciba y omitir una la dejaría en null. De
/// eso se encarga [UniformeModel.aCuerpo].
///
/// Devuelve cuántas filas tocó, no la falla; la pantalla se queda con la que
/// ya tiene editada.
Future<String?> actualizarUniforme(
  Server server, {
  required UniformeModel uniforme,
}) async {
  try {
    final res = await server.put('/uniformes/actualizar', {
      ...uniforme.aCuerpo(),
      'id': uniforme.id,
      // Aquí la fecha NO puede faltar: el backend hace Carbon::parse sobre lo
      // que reciba, y con null revienta con un 500 en vez de dejarla como
      // estaba.
      'fecha_hora':
          fechaHoraParaServidor(uniforme.fechaHora ?? DateTime.now()),
    });

    if (res.statusCode >= 300) {
      return mensajeDeFallo(res.statusCode, 'guardar la falla de uniforme');
    }
    return null;
  } catch (err) {
    return 'No se pudo guardar la falla de uniforme: $err';
  }
}

/// Borra una falla. `PUT uniformes/eliminar`, borrado blando.
///
/// El borrado en sí es correcto: se hace por `uniforme_id`. Lo que **no** se
/// puede usar es la lista que devuelve. Esa consulta filtra por
/// `asignatura_id` y por el periodo del USUARIO, así que desde esta pantalla
/// —donde las fallas se anotan sin asignatura— vuelve siempre vacía. Quien
/// llame a esto tiene que quitar la fila de su propia lista; fiarse de la
/// respuesta borraría de la pantalla las que siguen ahí.
Future<String?> eliminarUniforme(
  Server server, {
  required int uniformeId,
  required int alumnoId,
}) async {
  try {
    final res = await server.put('/uniformes/eliminar', {
      'uniforme_id': uniformeId,
      'alumno_id': alumnoId,
    });

    if (res.statusCode >= 300) {
      return mensajeDeFallo(res.statusCode, 'borrar la falla de uniforme');
    }
    return null;
  } catch (err) {
    return 'No se pudo borrar la falla de uniforme: $err';
  }
}

/// El alta devuelve la fila creada; lo demás, un mensaje o nada.
class ResultadoUniforme {
  final UniformeModel? uniforme;
  final String? error;

  const ResultadoUniforme.bien(UniformeModel this.uniforme) : error = null;

  const ResultadoUniforme.mal(String this.error) : uniforme = null;

  bool get correcto => error == null;
}
