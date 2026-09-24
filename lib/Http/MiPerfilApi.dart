/// Lo que cada persona cambia de su propia cuenta: la contraseña, la foto y,
/// si es titular, la firma del boletín.
///
/// **No hay ningún contrato nuevo aquí.** Son las mismas rutas que usa el front
/// web —`perfiles/cambiarpassword` en su página de perfil, `myimages/store` y
/// `images-users/cambiar-imagen-perfil` en la galería, `firmas-del-titular/*` en
/// `/mi-firma`—, leídas en `8myvc` el 24 sep 2026.
///
/// Lo de administrar cuentas ajenas vive en `UsuariosApi`, y no se mezcla: allí
/// la contraseña se pone sin pedir la anterior, y aquí se pide siempre.
library;

import 'dart:convert';

import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Cambia la contraseña propia. Null si entró, o el motivo.
///
/// `PUT perfiles/cambiarpassword/{user_id}` con `oldpassword` y `password`.
/// El servidor comprueba la anterior con `Hash::check` y corta con
/// `abort(400, 'Contraseña antigua es incorrecta')`; la nueva solo tiene que no
/// venir vacía. Si va bien contesta el texto `Password cambiado`, no JSON.
///
/// **No se manda `email_restore`**, igual que en la web: si viaja, el servidor
/// sobrescribe con él el correo de la cuenta.
Future<String?> cambiarMiContrasena(
  Server server, {
  required int userId,
  required String anterior,
  required String nueva,
}) async {
  try {
    final res = await server.put('/perfiles/cambiarpassword/$userId', {
      'oldpassword': anterior,
      'password': nueva,
    });

    if (res.statusCode == 400) {
      return loQueDijoElServidor(res.body) ??
          'La contraseña actual no es correcta.';
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      return loQueDijoElServidor(res.body) ??
          'El servidor no te deja cambiar esta contraseña.';
    }
    if (res.statusCode == 422) {
      return loQueDijoElServidor(res.body) ?? 'Falta la contraseña nueva.';
    }
    if (res.statusCode >= 300) {
      return 'El servidor respondió ${res.statusCode}.';
    }
    return null;
  } catch (err) {
    return 'No se pudo cambiar la contraseña: $err';
  }
}

/// Lo que pasó al cambiar la foto.
class FotoCambiada {
  /// La foto subida, con su carpeta: `user_12/foto.jpg`.
  final String nombre;

  /// Si ya es la de la cuenta, o si quedó pedida y la tiene que aceptar alguien.
  ///
  /// **Lo decide lo que contesta el servidor, no el rol de quien la pide**,
  /// igual que en la galería web: un superusuario la cambia en el acto y
  /// devuelve la cuenta, cualquier otro abre un pedido y devuelve `{pedido}`.
  final bool aplicada;

  const FotoCambiada({required this.nombre, required this.aplicada});
}

/// Sube una foto y la pone de imagen de perfil. Dos pasos, como en la web.
///
/// 1. `POST myimages/store`, multipart en `file`. El servidor la endereza y la
///    recorta a 200×200 desde el centro; a un alumno o acudiente con tres
///    imágenes ya subidas le contesta 400 con el motivo.
/// 2. `PUT images-users/cambiar-imagen-perfil/{user_id}` con su `imagen_id`.
///
/// Devuelve la foto o lanza [MotivoDePerfil] con una frase que se puede
/// enseñar tal cual.
Future<FotoCambiada> cambiarMiFoto(
  Server server, {
  required int userId,
  required List<int> bytes,
  required String nombreArchivo,
}) async {
  final subida = await server.subir('/myimages/store', bytes, nombreArchivo);
  final imagen = _mapaO(subida, 'subir la foto');

  final imagenId = entero(imagen['id']);
  final nombre = texto(imagen['nombre']);
  if (imagenId == null || nombre == null) {
    throw const MotivoDePerfil('El servidor no devolvió la foto subida.');
  }

  final res = await server.put(
      '/images-users/cambiar-imagen-perfil/$userId', {'imagen_id': imagenId});
  final cuerpo = _mapaO(res, 'ponerla de foto de perfil');

  return FotoCambiada(
    nombre: nombre,
    aplicada: cuerpo.containsKey('imagen_id'),
  );
}

/// Una frase para enseñar cuando algo de «Mi perfil» no salió.
class MotivoDePerfil implements Exception {
  final String mensaje;
  const MotivoDePerfil(this.mensaje);

  @override
  String toString() => mensaje;
}

/// El JSON de una respuesta como mapa, o [MotivoDePerfil] con lo que dijo el
/// servidor.
Map<String, dynamic> _mapaO(dynamic res, String accion) {
  if (res.statusCode >= 300) {
    throw MotivoDePerfil(loQueDijoElServidor(res.body) ??
        'No se pudo $accion: el servidor respondió ${res.statusCode}.');
  }
  try {
    final leido = jsonDecode(res.body);
    if (leido is Map) return Map<String, dynamic>.from(leido);
  } catch (_) {}
  throw MotivoDePerfil('No se pudo $accion: respuesta inesperada.');
}

// ── La firma del titular ────────────────────────────────────────────────────

/// En qué va la firma que pidió.
enum EstadoDeFirma { pendiente, aprobada, rechazada }

/// La última firma que pidió el titular y no retiró.
class SolicitudDeFirma {
  final int askedId;
  final String? firmaNombre;
  final EstadoDeFirma estado;

  /// Fechas tal como las guarda MySQL: `2026-09-24 10:00:00`.
  final String? enviada;
  final String? respondida;

  /// Quien la aprobó o la rechazó: el nombre del docente o su usuario.
  final String? respondidaPor;

  /// Por qué se rechazó. Solo en las rechazadas.
  final String? motivo;

  const SolicitudDeFirma({
    required this.askedId,
    required this.estado,
    this.firmaNombre,
    this.enviada,
    this.respondida,
    this.respondidaPor,
    this.motivo,
  });

  factory SolicitudDeFirma.fromJson(Map<String, dynamic> j) {
    final estado = switch (texto(j['estado'])) {
      'aprobada' => EstadoDeFirma.aprobada,
      'rechazada' => EstadoDeFirma.rechazada,
      _ => EstadoDeFirma.pendiente,
    };
    return SolicitudDeFirma(
      askedId: enteroO(j['asked_id']),
      estado: estado,
      firmaNombre: texto(j['firma_nombre']),
      enviada: texto(j['created_at']),
      respondida: texto(estado == EstadoDeFirma.aprobada
          ? j['accepted_at']
          : j['rechazado_at']),
      respondidaPor: texto(j['respondida_por']),
      motivo: texto(j['motivo']),
    );
  }
}

/// `GET firmas-del-titular/mia`.
class MiFirma {
  /// Titular este año de algún grupo. Si no, no puede pedir nada.
  final bool esTitular;

  /// Los grupos que dirige, por su nombre: «Sexto A».
  final List<String> grupos;

  /// La que sale hoy en el boletín. Null si sale el renglón en blanco.
  final String? vigente;

  final SolicitudDeFirma? solicitud;

  const MiFirma({
    required this.esTitular,
    required this.grupos,
    this.vigente,
    this.solicitud,
  });

  factory MiFirma.fromJson(Map<String, dynamic> j) {
    final vigente = j['vigente'];
    final solicitud = j['solicitud'];
    return MiFirma(
      esTitular: siONo(j['es_titular']) ?? false,
      grupos: (j['grupos'] is List ? j['grupos'] as List : const [])
          .whereType<Map>()
          .map((g) => texto(g['nombre']))
          .whereType<String>()
          .toList(),
      vigente: vigente is Map ? texto(vigente['firma_nombre']) : null,
      solicitud: solicitud is Map
          ? SolicitudDeFirma.fromJson(Map<String, dynamic>.from(solicitud))
          : null,
    );
  }

  MiFirma conSolicitud(SolicitudDeFirma? nueva) => MiFirma(
        esTitular: esTitular,
        grupos: grupos,
        vigente: vigente,
        solicitud: nueva,
      );
}

Future<MiFirma> traerMiFirma(Server server) async {
  final res = await server.get('/firmas-del-titular/mia');
  return MiFirma.fromJson(_mapaO(res, 'cargar tu firma'));
}

/// Manda una firma para que la aprueben. Reemplaza a la pendiente, si había.
///
/// `POST firmas-del-titular/solicitar`, multipart en `file`, PNG o JPG. 201 con
/// `{solicitud}`. El servidor contesta 403 si no es titular y 422 si el archivo
/// no es una imagen de esas dos.
Future<SolicitudDeFirma> pedirFirma(
  Server server, {
  required List<int> bytes,
  required String nombreArchivo,
}) async {
  final res =
      await server.subir('/firmas-del-titular/solicitar', bytes, nombreArchivo);
  final cuerpo = _mapaO(res, 'enviar la firma');
  final solicitud = cuerpo['solicitud'];
  if (solicitud is! Map) {
    throw const MotivoDePerfil('El servidor no devolvió la firma enviada.');
  }
  return SolicitudDeFirma.fromJson(Map<String, dynamic>.from(solicitud));
}

/// Retira la pendiente. Devuelve la anterior que no se retiró, o null.
///
/// `PUT firmas-del-titular/retirar`, sin cuerpo. 404 si no había pendiente.
Future<SolicitudDeFirma?> retirarFirma(Server server) async {
  final res = await server.put('/firmas-del-titular/retirar', const {});
  final solicitud = _mapaO(res, 'retirar la firma')['solicitud'];
  return solicitud is Map
      ? SolicitudDeFirma.fromJson(Map<String, dynamic>.from(solicitud))
      : null;
}
