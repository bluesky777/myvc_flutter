/// Cómo se escriben las fechas que van al backend.
///
/// La columna `fecha_hora` de ausencias es un datetime de MySQL: se manda
/// 'Y-m-d H:i:s', que es lo mismo que manda el front web al guardar cambios.
/// Ojo con toIso8601String(), que mete una T en medio.
///
/// `fecha_hora` es el día en que el alumno faltó. No es created_at —cuándo se
/// tecleó— ni updated_at —cuándo se corrigió—: esos los pone el backend solo.
String fechaHoraParaServidor(DateTime d) =>
    '${d.year}-${_dd(d.month)}-${_dd(d.day)} '
    '${_dd(d.hour)}:${_dd(d.minute)}:${_dd(d.second)}';

/// La falta de un día concreto, en formato de servidor.
///
/// Con la hora real cuando el día es hoy —en una tardanza la hora es el dato— y
/// a las 00:00 cuando se registra la de un día pasado, donde no hay hora que
/// reconstruir.
String faltaDelDiaParaServidor(DateTime dia, {DateTime? ahora}) {
  final momento = ahora ?? DateTime.now();

  return fechaHoraParaServidor(
    esElMismoDia(dia, momento)
        ? momento
        : DateTime(dia.year, dia.month, dia.day),
  );
}

/// Mismo año, mes y día, sin mirar la hora.
bool esElMismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// dd/mm/aaaa, como se lee una fecha aquí.
String formatoDia(DateTime? d) =>
    d == null ? '—' : '${_dd(d.day)}/${_dd(d.month)}/${d.year}';

/// Una columna `date` del backend, sin hora y sin zona.
///
/// `vt_votaciones.fecha_inicio` y `fecha_fin` son `date`, no `datetime`, y el
/// backend las compara recortando a `Y-m-d`. Pasarlas por `DateTime.parse` a
/// secas funciona, pero deja una medianoche que invita a restarle horas a algo
/// que **no tiene hora**. Esto devuelve el día a secas, en local, que es con lo
/// que se puede contar cuántos días faltan sin que la zona corra la cuenta.
DateTime? soloElDia(dynamic crudo) {
  final texto = crudo?.toString().trim() ?? '';
  if (texto.isEmpty || texto == 'null') return null;

  final leido = DateTime.tryParse(texto);
  if (leido == null) return null;

  return DateTime(leido.year, leido.month, leido.day);
}

/// La hora de un voto, pasada a hora de Bogotá.
///
/// **Es la excepción a la regla de [formatoDiaYHora], y es la única.**
/// `vt_votos.created_at` se sella en **UTC** mientras el resto del sistema
/// guarda hora de Bogotá; el backend lo dejó escrito a propósito
/// (`RelojUnicoTest::SELLAN_EN_UTC`) y decidió que **convertir es cosa del
/// front**, porque ponerle el reloj de Bogotá a esa columna metería dos relojes
/// en la misma columna
/// (`8myvc/docs/migracion/11-votaciones.md` §8, punto 2 de lo que queda).
///
/// Son cinco horas, y sin restarlas un voto de las 8:15 de la mañana se pinta
/// **a la 1:15 de la tarde**: una hora perfectamente creíble, que es lo que hace
/// que el error no se note.
///
/// **Se restan cinco a mano y no se llama a `toLocal()`.** La app la usan
/// dieciséis colegios colombianos, o sea UTC−5 siempre; `toLocal()` daría la
/// zona del teléfono, y el teléfono de alguien en viaje —o con la zona mal
/// puesta, que en una tablet compartida pasa— pintaría la hora de otro sitio.
/// Colombia no tiene horario de verano, así que el desplazamiento es fijo y no
/// hace falta una tabla de zonas.
///
/// Admite las dos formas en las que esa columna llega: `postStore` devuelve el
/// modelo y la serializa con Z (`2026-09-22T13:15:00.000000Z`), y la constancia
/// del 409 sale de `DB::select`, o sea el datetime crudo de MySQL
/// (`2026-09-22 13:15:00`) — sin Z, que Dart leería como local.
DateTime? horaDeUnVotoEnBogota(dynamic crudo) {
  final texto = crudo?.toString().trim() ?? '';
  if (texto.isEmpty || texto == 'null') return null;

  final leido = DateTime.tryParse(texto);
  if (leido == null) return null;

  // Lo que se guardó es UTC, venga con Z o sin ella: se reconstruye en UTC con
  // los mismos números y de ahí se pasa a Bogotá.
  final enUtc = DateTime.utc(leido.year, leido.month, leido.day, leido.hour,
      leido.minute, leido.second);

  return enUtc.subtract(const Duration(hours: 5));
}

/// dd/mm/aaaa - h:mm a. m., para cuando la hora también importa.
///
/// Se pintan los números tal cual vienen, sin pasar por toLocal(). El backend
/// guarda la hora de Bogotá y la serializa con una Z al final, así que Dart la
/// lee como UTC: leerla tal cual devuelve la hora que se guardó, y convertirla
/// a local la correría cinco horas.
String formatoDiaYHora(DateTime? d) =>
    d == null ? '—' : '${formatoDia(d)} - ${formatoHora12(d)}';

/// La hora en el reloj de doce, que es como se dice una hora aquí.
///
/// Las 24 horas se quedan para el servidor, en [fechaHoraParaServidor]: eso es
/// lo que espera la columna datetime de MySQL y no cambia.
String formatoHora12(DateTime d) => _hora12(d.hour, d.minute);

/// Lo mismo a partir de una hora suelta.
String formatoHora12De(int hora24, int minuto) => _hora12(hora24, minuto);

String _hora12(int hora24, int minuto) {
  final sufijo = hora24 < 12 ? 'a. m.' : 'p. m.';

  // Las 0 son las 12 de la noche y las 12 son las 12 del día: el módulo solo
  // no basta, deja las dos en 0.
  final doce = hora24 % 12 == 0 ? 12 : hora24 % 12;

  return '$doce:${_dd(minuto)} $sufijo';
}

/// De la hora que se teclea en el reloj de doce a la del servidor.
///
/// Las 12 a. m. son las 0 y las 12 p. m. son las 12; el resto se corre doce
/// horas por la tarde.
int hora24DesdeDoce({required int hora12, required bool esTarde}) {
  final base = hora12 % 12;
  return esTarde ? base + 12 : base;
}

String _dd(int n) => n.toString().padLeft(2, '0');

/// Cuánto hace que ocurrió algo, para leerlo de un vistazo en un muro.
///
/// En una lista que se recorre hacia abajo, «hace 5 min» dice más que
/// «19/08/2026 - 7:10 p. m.»: lo que importa es si es de ahora o de la semana
/// pasada. A partir de una semana ya se pone la fecha, que es cuando el «hace
/// N días» deja de significar nada.
String hace(DateTime? cuando, {DateTime? ahora}) {
  if (cuando == null) return '';

  final referencia = ahora ?? DateTime.now();
  final diferencia = referencia.difference(cuando);

  // Una publicación con fecha futura es un reloj mal puesto en el servidor o
  // en el teléfono. No se discute: se enseña como recién hecha.
  if (diferencia.isNegative || diferencia.inMinutes < 1) return 'ahora mismo';

  if (diferencia.inMinutes < 60) {
    final minutos = diferencia.inMinutes;
    return 'hace $minutos ${minutos == 1 ? 'minuto' : 'minutos'}';
  }

  if (diferencia.inHours < 24) {
    final horas = diferencia.inHours;
    return 'hace $horas ${horas == 1 ? 'hora' : 'horas'}';
  }

  if (diferencia.inDays == 1) return 'ayer';
  if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} días';

  return formatoDia(cuando);
}
