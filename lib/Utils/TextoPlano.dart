/// El texto como se busca: sin acentos, en minúsculas y con los espacios
/// apretados.
///
/// Sin quitar acentos, buscar «situacion» no encontraría «Situación» y buscar
/// «pena» no encontraría «Peña», que es justo como están escritos el manual de
/// convivencia y los apellidos del colegio. Nadie escribe la tilde en un
/// buscador.
///
/// Es una tabla y no `Unicode normalization`: el `dart:core` no trae NFD, y
/// traer un paquete para siete letras del español sería pagar mantenimiento por
/// nada. Si algún día hace falta otro idioma, este es el sitio.
String textoPlano(String texto) {
  var plano = texto.toLowerCase().trim();

  const acentos = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  acentos.forEach((con, sin) => plano = plano.replaceAll(con, sin));

  return plano.replaceAll(RegExp(r'\s+'), ' ');
}

/// Si el texto responde a lo que se está escribiendo en un buscador.
///
/// Una búsqueda vacía responde que sí: en una hoja con buscador, lo que se ve
/// antes de escribir nada es la lista entera.
bool coincideConBusqueda(String texto, String busqueda) {
  final aguja = textoPlano(busqueda);
  if (aguja.isEmpty) return true;

  return textoPlano(texto).contains(aguja);
}
