import 'dart:convert';

import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/PublicacionModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Lo que trae el muro: las publicaciones y, si quien mira es acudiente, sus
/// acudidos.
class MuroCargado {
  final List<PublicacionModel> publicaciones;
  final List<AcudidoModel> acudidos;

  MuroCargado({required this.publicaciones, required this.acudidos});
}

/// Un alumno a cargo de un acudiente, tal como lo devuelve el muro.
class AcudidoModel {
  final int alumnoId;
  final String nombres;
  final String? apellidos;
  final String? fotoNombre;
  final String? grupo;
  final String? grupoAbrev;

  /// Si está a paz y salvo en tesorería. Cuando no lo está, sus notas van
  /// bloqueadas y hay que decírselo.
  final bool pazYSalvo;

  AcudidoModel({
    required this.alumnoId,
    required this.nombres,
    this.apellidos,
    this.fotoNombre,
    this.grupo,
    this.grupoAbrev,
    this.pazYSalvo = true,
  });

  String get nombreCompleto => '$nombres ${apellidos ?? ''}'.trim();

  factory AcudidoModel.fromJson(Map<String, dynamic> json) {
    return AcudidoModel(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}',
      apellidos: texto(json['apellidos']),
      fotoNombre: texto(json['foto_nombre']),
      grupo: texto(json['grupo_nombre']),
      grupoAbrev: texto(json['grupo_abrev']),
      // Viene como 1/0, y a veces sin venir: sin dato se asume que sí, que es
      // lo que hace el front —el aviso rojo solo sale cuando hay un 0—.
      pazYSalvo: entero(json['pazysalvo']) != 0,
    );
  }
}

/// Trae el muro del colegio.
///
/// Sale de `GET ChangesAsked/to-me`, que es de donde lo saca también el panel
/// del front web. No es un endpoint del muro: es el cajón de sastre del panel y
/// según el rol trae además historial de sesiones, intentos de login fallidos y
/// solicitudes de cambio, nada de lo cual mira esta app. Se usa igualmente
/// porque no hay otro —`publicaciones/ultimas` es el de la pantalla de login,
/// sin sesión— y el backend no se puede tocar por ahora. El día que se pueda,
/// aquí hay que apuntar a un endpoint que traiga solo esto.
Future<MuroCargado> traerMuro(Server server) async {
  final res = await server.get('/ChangesAsked/to-me');

  if (res.statusCode >= 300) {
    throw Exception('El servidor respondió ${res.statusCode}.');
  }

  final cuerpo = jsonDecode(res.body);
  if (cuerpo is! Map) {
    return MuroCargado(publicaciones: const [], acudidos: const []);
  }

  return MuroCargado(
    publicaciones: _publicaciones(cuerpo['publicaciones']),
    acudidos: _acudidos(cuerpo['alumnos']),
  );
}

List<PublicacionModel> _publicaciones(dynamic crudas) {
  if (crudas is! List) return const [];

  final leidas = <PublicacionModel>[];
  for (final cruda in crudas) {
    if (cruda is! Map) continue;

    // Las eliminadas siguen viniendo, con su deleted_at: el front las pinta
    // tachadas para que su dueño pueda restaurarlas. Aquí no se enseñan.
    if (cruda['deleted_at'] != null) continue;

    final publicacion =
        PublicacionModel.fromJson(Map<String, dynamic>.from(cruda));
    if (publicacion.tieneAlgo) leidas.add(publicacion);
  }
  return leidas;
}

List<AcudidoModel> _acudidos(dynamic crudos) {
  if (crudos is! List) return const [];

  return crudos
      .whereType<Map>()
      .map((a) => AcudidoModel.fromJson(Map<String, dynamic>.from(a)))
      .where((a) => a.alumnoId != 0)
      .toList();
}
