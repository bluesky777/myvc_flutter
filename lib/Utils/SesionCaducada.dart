import 'package:flutter/widgets.dart';
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Utils/Navegador.dart';

/// Lo que pasa cuando el servidor dice 401 en mitad del uso.
///
/// El token de `login/credentials` dura 24 h fijas y la app no lo renueva, así
/// que al día siguiente cualquier pantalla se encontraba un 401 y lo pintaba
/// como un error suyo: «No se pudo abrir la disciplina. Exception: El servidor
/// respondió 401.» (Fortul, 21 oct 2026). Reintentar no arreglaba nada, y
/// [VerificacionSesion] no lo cazaba porque solo pregunta cada seis horas.
///
/// Ahora el 401 de cualquier petición con token llega aquí por
/// [Server.alCaducarSesion]: se tira la sesión igual que al arrancar con un
/// token muerto y se vuelve al login con el motivo arriba. Es el arreglo de
/// fondo que [VerificacionSesion] dejaba anotado.
///
/// El 403 no pasa por aquí: el servidor lo usa para «esto no te toca» —el
/// docente sin contrato, la cuenta de portería, el alumno en una ruta de
/// personal—, y la sesión de esa gente está bien.
class SesionCaducada {
  SesionCaducada._();

  static const String mensaje =
      'Tu sesión venció. Vuelve a entrar con tu usuario y contraseña.';

  static bool _saliendo = false;

  /// Lo engancha main.dart a [Server.alCaducarSesion].
  ///
  /// No hace nada:
  /// - si el token de la petición ya no es el de ahora —se salió, o se entró
  ///   con otra cuenta mientras la respuesta venía de camino—;
  /// - si no hay navegador montado, que es el arranque: ahí
  ///   `LoginController.restaurar` ya trata su propio 401;
  /// - si ya se está saliendo. Una pantalla pide varias cosas a la vez y
  ///   todas vuelven con 401; se sale una vez.
  static Future<void> notar(String? tokenUsado) async {
    if (_saliendo) return;
    if (tokenUsado == null || tokenUsado != AuthService.user.token) return;
    final NavigatorState? navegador = navegadorDeLaApp.currentState;
    if (navegador == null) return;

    _saliendo = true;
    try {
      await LoginController().cerrarSesionCaducada();
      navegador.pushNamedAndRemoveUntil('/login', (_) => false,
          arguments: mensaje);
    } finally {
      _saliendo = false;
    }
  }
}
