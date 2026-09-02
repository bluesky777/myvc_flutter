/// Cómo se escribe una nota: **una regla para pintarla y otra para editarla**.
///
/// Las dos viven aquí juntas porque lo que las separa no se ve desde el sitio
/// donde se llaman —las dos reciben un `double?` y devuelven texto— y confundir
/// una con otra no da ningún error: da un número equivocado, que es peor.
///
/// ## Por qué hay dos, desde el 30 de agosto de 2026
///
/// El backend guardaba la definitiva de cada materia **redondeada a entero**
/// —`CAST(... AS DECIMAL(4,0))`—, así que los puestos del boletín empataban en
/// masa: el 77,1 % de las 125.352 definitivas de una base estaban redondeadas.
/// La migración `notas_finales_en_decimal` la pasa a `DECIMAL(7,4)` y quita el
/// redondeo, y a partir de ahí una nota puede valer 43,75.
///
/// Eso obliga a decidir qué se enseña, y son dos respuestas distintas:
///
///   · **pintar** una nota → entera, `43,75` se escribe «44»
///   · **editar o confirmar** una nota → el valor exacto, «43.75»
///
/// ## Pintar: entera, como el boletín
///
/// Decisión de Joseth del 30 de agosto de 2026, y es la misma que ya se aplicó
/// al promedio del periodo: **la app escribe como el papel que se firma**. El
/// boletín imprime la nota de una materia entera y lleva años haciéndolo; dos
/// números distintos para el mismo alumno según mire la pantalla o el papel es
/// peor que un número discutible.
///
/// Lo que **no** se redondea son las cuentas —el promedio y el puesto—, y ahí el
/// decimal es justo lo que se fue a buscar: sin él, dos alumnos distintos se
/// imprimen iguales y comparten un puesto que no comparten. Por eso los dos
/// promedios que la app pinta conservan su decimal y no pasan por aquí.
///
/// ## Editar: el valor exacto, y nunca redondeado
///
/// Dentro de un campo va el valor de verdad. Redondear ahí **guarda el
/// redondeo**: lo que hay escrito en la casilla es lo que se vuelve a mandar al
/// servidor, así que abrir la planilla y guardar convertiría un 43,75 en 44 —el
/// redondeo que la migración viene a quitar, reintroducido desde el cliente y
/// sin que nadie lo note—.
///
/// Y el mismo valor exacto en el aviso que confirma qué se guardó, que no es
/// pintar una nota sino decir lo que se acaba de escribir: «Guardada: 44»
/// después de guardar 43,75 es una confirmación falsa, y del único número que
/// esa persona está mirando en ese momento.
///
/// El reparto salió de leer los ocho llamantes uno a uno, con la sesión del
/// front web: **seis casillas, un eco y un solo sitio que pinta**. Agrupándolos
/// por su forma —`grep toStringAsFixed`— salían cinco sitios y tres de ellos ni
/// siquiera eran notas. Ver [docs/notas-decimales.md](../../docs/notas-decimales.md).
library;

/// Una nota como se **pinta**: entera, y una raya cuando no la hay.
///
/// La raya y no un cero: un cero es una nota y «sin poner» no lo es, y
/// confundirlos asusta a quien mira.
String notaPintada(double? nota) {
  if (nota == null) return '—';
  return nota.toStringAsFixed(0);
}

/// Una nota como se escribe **dentro de un campo**: su valor exacto, sin
/// decimales cuando es redonda, y vacío cuando no la hay.
///
/// Lo de quitar los decimales redondos no es cosmética: las notas llegan del
/// servidor como decimales —un 85 puede venir como '85.0', y desde la
/// migración como '85.0000'— y un campo que dice «85.0000» invita a borrar
/// medio número antes de escribir encima. Lo que **no** se toca es un 43,75:
/// ése se enseña entero, porque es el que se va a volver a guardar.
String notaEnCasilla(double? nota) {
  if (nota == null) return '';
  return nota == nota.roundToDouble()
      ? nota.toStringAsFixed(0)
      : nota.toString();
}
