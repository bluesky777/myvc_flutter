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

String _dd(int n) => n.toString().padLeft(2, '0');
