import 'package:myvc_flutter/Http/AuthService.dart';

/// Quién entra a la portería, con el mismo criterio que
/// `Autoriza::puedeUsarPorteria` en el servidor (Joseth, 9 oct 2026):
///
///   - cualquier docente, con su cuenta de siempre;
///   - quien tenga el rol «Portería» —el celador, el de mantenimiento—;
///   - coordinación y administración.
///
/// Como el resto del menú, esto es alcance y no permiso: lo que niega de verdad
/// es el servidor.
extension PermisosPorteria on UserAutenticado {
  bool get puedeUsarPorteria =>
      esDocente ||
      isSuperuser ||
      esAdmin ||
      tieneRol('portería') ||
      tieneRol('secretario') ||
      tieneRol('rector') ||
      roles.any((rol) => rol.startsWith('coord'));

  /// La cuenta que SÓLO es de portería: tipo Usuario con «Portería» como único
  /// rol. El servidor no le deja salir de la portería (`CuentaDePorteria`), así
  /// que la app la lleva directo ahí y el menú no le ofrece nada más.
  bool get esSoloPorteria =>
      tipo == 'Usuario' &&
      !isSuperuser &&
      roles.isNotEmpty &&
      roles.every((rol) => rol == 'portería');
}
