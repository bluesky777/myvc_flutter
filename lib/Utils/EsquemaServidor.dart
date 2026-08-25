/// Le pone esquema a la dirección que se escribe en el «Otro» del login.
///
/// **https salvo en la red local.** La política de privacidad promete que todo
/// viaja cifrado, y Android bloquea el tráfico en claro desde la versión 9: un
/// `http://` por defecto haría mentir al documento y además no llegaría a
/// ninguna parte. Pero un servidor de desarrollo —`localhost`, una IP de la red
/// de casa— no tiene certificado, y obligar a escribir el esquema a mano cada
/// vez sería cambiar una molestia real por una seguridad que ahí no aplica:
/// esas direcciones no salen del equipo ni de la LAN.
///
/// Quien quiera forzar uno u otro lo escribe entero, que es lo que gana siempre.
String conEsquema(String direccion) {
  final limpia = direccion.trim();
  if (limpia.isEmpty) return limpia;
  if (limpia.startsWith('http://') || limpia.startsWith('https://')) {
    return limpia;
  }
  return esDeRedLocal(limpia) ? 'http://$limpia' : 'https://$limpia';
}

/// Si la dirección apunta a este equipo o a la red privada de quien lo usa.
bool esDeRedLocal(String direccion) {
  // Se queda con el host: fuera la ruta y fuera el puerto.
  var host = direccion.split('/').first.toLowerCase();

  // El loopback de IPv6 se escribe con dos puntos, así que se mira antes de
  // usarlos para separar el puerto.
  if (host == '::1' || host == '[::1]') return true;

  host = host.split(':').first;

  if (host == 'localhost' || host == '127.0.0.1') return true;

  // Los nombres que reparte Bonjour en la red de casa: mi-mac.local.
  if (host.endsWith('.local')) return true;

  // Los tres rangos privados de la RFC 1918.
  if (host.startsWith('10.') || host.startsWith('192.168.')) return true;

  final enElRango172 = RegExp(r'^172\.(\d{1,3})\.').firstMatch(host);
  if (enElRango172 != null) {
    final segundo = int.tryParse(enElRango172.group(1)!) ?? -1;
    return segundo >= 16 && segundo <= 31;
  }

  return false;
}
