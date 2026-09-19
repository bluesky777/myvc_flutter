/// La escala de valoración del año en curso.
///
/// Es lo que traduce «85» a «Alto», y de paso lo que trae
/// [EscalaDeValoracion.descripcion]: el prefijo que el boletín por competencias
/// le pone delante a cada línea. La pantalla del docente la pide para enseñar
/// el previo de impresión mientras se escribe.
library;

import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';

/// Trae la escala del año, de la nota más alta a la más baja.
///
/// **`GET escalas` y no `GET years/colegio`**, aunque el segundo también las
/// traiga. `YearsController::getColegio` hace `SELECT * FROM years` **sin
/// filtrar por año** y luego, por cada año que el colegio haya tenido, dos
/// consultas más —sus periodos y sus escalas—, y encima los certificados y las
/// imágenes del usuario. Eso es la pantalla de configuración, que quiere verlo
/// todo. Aquí hace falta una sola escala, la del año en curso, y el servidor es
/// un hosting compartido de un núcleo: pedir ocho años de periodos para leer
/// cuatro bandas se paga en cada hoja que el docente abre.
///
/// **El año no se manda y no se puede elegir**: `EscalasDeValoracionController`
/// filtra por `$user->year_id`, que sale del token —de `users.periodo_id`, vía
/// la barra de año—. Desde aquí no hay forma de pedir la escala de otro año, y
/// la pantalla no lo ofrece.
///
/// El backend las devuelve por `orden asc`, que es la columna que el colegio
/// arrastra en su pantalla de configuración; se reordenan aquí **por nota
/// descendente**, igual que [YearDelColegio.fromJson], porque es como se lee
/// una escala y como la imprime el boletín. Las dos listas de la app tienen que
/// salir en el mismo orden o el docente ve dos escalas distintas.
Future<List<EscalaDeValoracion>> traerEscalasDelAnio(Server server) async {
  final res = await server.get('/escalas');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! List) return const [];

  return cuerpo
      .whereType<Map>()
      .map((e) => EscalaDeValoracion.fromJson(Map<String, dynamic>.from(e)))
      .toList()
    ..sort((a, b) => b.porcInicial.compareTo(a.porcInicial));
}
