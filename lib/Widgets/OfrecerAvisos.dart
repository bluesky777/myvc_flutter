import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/Avisos.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La única vez que la app pide el permiso de avisos por su cuenta.
///
/// ## Por qué hay una frase antes del diálogo del sistema
///
/// Porque desde Android 13 **el sistema pregunta una sola vez**. Si se dice que
/// no, no vuelve a preguntar nunca: hay que ir a los ajustes del teléfono a
/// mano, y nadie lo hace. Preguntado a bocajarro al abrir la app por primera
/// vez —sin saber todavía qué es esto ni de quién— mucha gente dice que no por
/// defecto, y ahí se acaba el asunto para siempre.
///
/// Así que primero una frase que dice qué se va a avisar, y solo si dice que sí
/// se gasta la pregunta del sistema. Quien diga que no aquí no ha gastado nada:
/// puede activarlo después en la pantalla de Notificaciones.
///
/// ## Por qué solo a las familias
///
/// Los temas cuelgan de un alumno —los suyos o los de sus acudidos—, así que a
/// un docente el servidor no le devuelve ninguno y el permiso no le compraría
/// nada. Cuando se enciendan los temas del colegio esto se amplía; ver
/// `PendientesNotificaciones.temasDelColegio`.
class OfrecerAvisos {
  OfrecerAvisos._();

  /// Que no se vuelva a ofrecer. Es del teléfono, como las preferencias, y por
  /// eso no se borra al cerrar sesión: quien ya dijo que no en este aparato no
  /// tiene que volver a decirlo porque entre otra persona.
  static const String clave = 'avisos_ya_ofrecidos';

  /// Ofrece los avisos si toca, y no hace nada si no.
  ///
  /// No devuelve nada y no falla nunca: es un extra encima de una pantalla que
  /// ya cargó. Si algo sale mal, el muro se queda como estaba.
  static Future<void> siToca(BuildContext context, Server server) async {
    if (!Avisos.disponible) return;
    if (!AuthService.user.esAlumno && !AuthService.user.esAcudiente) return;

    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(clave) ?? false) return;

    // Ya concedido —reinstalación, o lo activó desde la pantalla de
    // Notificaciones—: no hay nada que ofrecer, pero sí que anotar.
    if (await Avisos.hayPermiso()) {
      await preferences.setBool(clave, true);
      await Avisos.sincronizar(server);
      return;
    }

    if (!context.mounted) return;

    final quiere = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Te avisamos cuando haya algo?'),
        content: const Text(
          'Podemos avisarte cuando le publiquen una nota, le anoten una falta o'
          ' le registren una situación de convivencia.\n\n'
          'El aviso nunca dice la nota: solo que hay algo nuevo. Para verlo hay'
          ' que abrir la app.\n\n'
          'Se puede apagar cuando quieras, entero o por tipo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Sí, avísame'),
          ),
        ],
      ),
    );

    // Se anota en los dos casos: la pregunta ya se hizo. Quien dijo «ahora no»
    // no la vuelve a ver, y tiene el interruptor en el menú.
    await preferences.setBool(clave, true);

    if (quiere != true) return;

    if (await Avisos.pedirPermiso()) {
      await Avisos.sincronizar(server);
    }
  }
}
