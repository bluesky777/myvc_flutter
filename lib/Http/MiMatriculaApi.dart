import 'dart:convert';

import 'package:myvc_flutter/Http/FaltasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/MiRecorridoModel.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// El recorrido de matrícula **de la familia**: `GET requisitos/mi-recorrido/{id}`.
///
/// ## POR QUÉ ESTE FICHERO EXISTE, EN VEZ DE UNA FUNCIÓN MÁS EN `EstacionesApi`
///
/// Porque la ruta de al lado —`requisitos/recorrido/{id}`, la del personal— se
/// llama casi igual y **es para el público contrario**, y equivocarse no falla
/// igual en los dos sentidos:
///
/// ```
/// familia   -> requisitos/recorrido      403 SIEMPRE                        ruidoso, seguro
/// personal  -> requisitos/mi-recorrido   200 SIEMPRE, con dos campos menos  SILENCIOSO
/// ```
///
/// El 200 mudo es el que muerde. `ExigirBoletinPropio:70` **deja pasar de largo
/// a todo el que no sea `Alumno` ni `Acudiente`** —a propósito, para que
/// secretaría pueda abrir la vista de la familia y enseñársela a una madre por
/// teléfono—, así que una pantalla del personal mal cableada aquí **no se cae
/// nunca**: devuelve 200 y lo único que pasa es que la observación interna y el
/// nombre de quien cerró **dejan de aparecer**. Eso no lo caza una prueba con
/// usuarios sintéticos; lo caza alguien en el patio preguntando por qué no ve
/// la observación.
///
/// Tenerlas en dos ficheros no lo impide, pero hace falta teclear el nombre del
/// otro fichero para equivocarse. Es la misma razón por la que el servidor
/// separó los dos métodos en vez de meter un `if ($esFamilia)`.
Future<MiRecorrido?> traerMiRecorrido(Server server, int alumnoId) async {
  if (!Interruptores.miMatricula) return null;

  // **El id no es opcional, y aquí no hay la salida que tienen las otras
  // pantallas de familia.** `disciplina/mis-fichas/{alumno_id?}` deja mandar
  // nada y el backend resuelve el alumno del token; `mi-recorrido` declara
  // `{alumno_id}` sin `?` y arranca con `if (! is_numeric($alumno_id)) abort(422)`.
  // O sea que **hasta un alumno mirando lo suyo tiene que mandar su propio id**,
  // que es `AuthService.user.personaId` —el de la ficha, no el de la cuenta—.
  //
  // Se comprueba aquí y no se manda un `0` a ver qué pasa: un `0` daría 404 y el
  // mensaje hablaría de un alumno que no existe, que es mentira y manda a quien
  // lo lea a buscar el fallo en el sitio equivocado.
  if (alumnoId <= 0) {
    throw Exception(
      'No se sabe de quién es el recorrido. Vuelve a entrar a la app.',
    );
  }

  final res = await server.get('/requisitos/mi-recorrido/$alumnoId');

  if (res.statusCode >= 300) {
    throw Exception(mensajeDeFallo(res.statusCode, 'ver el proceso'));
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    throw Exception('El servidor no devolvió el proceso.');
  }

  return MiRecorrido.fromJson(Map<String, dynamic>.from(cuerpo));
}
