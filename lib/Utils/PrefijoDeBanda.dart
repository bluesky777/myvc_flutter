/// Cómo va a salir impresa una competencia, banda por banda.
///
/// El boletín por competencias no imprime la frase del docente a secas: le pone
/// delante la frase del SIEE de la banda que le tocó al alumno —«Fortaleza
/// en…», «Dificultad en…»—. La misma frase, por tanto, se imprime distinta
/// según la nota, y el docente la escribe sin verla.
library;

import 'package:myvc_flutter/Models/ColegioModel.dart';

/// Las líneas tal como las imprimiría el boletín, una por banda con prefijo.
///
/// ## Todas las bandas, no una de ejemplo
///
/// El front web enseña **una** banda de muestra. Aquí salen **todas las que el
/// colegio tenga escritas**, y el motivo es concreto: una frase puede encajar
/// perfectamente detrás de «Fortaleza en…» y ser absurda detrás de «Dificultad
/// en…». Con un solo ejemplo el docente escribe las cuatro mal y se entera
/// cuando el boletín ya está en una casa. Cuesta tres renglones en pantalla.
///
/// ## El montaje es el del backend, carácter a carácter
///
/// `BoletinPorCompetenciasController::conElPrefijo` es esto entero:
///
/// ```php
/// $prefijo = $banda === null ? '' : trim((string) $banda->descripcion);
///
/// return $prefijo === '' ? $texto : $prefijo.' '.$texto;
/// ```
///
/// O sea: **el prefijo se recorta, el texto no**, va **un solo espacio** entre
/// los dos, y **no se toca ninguna mayúscula** — ni se baja la del texto ni se
/// sube la del prefijo. Si el docente escribe «Interpreta gráficas», el boletín
/// dice «Fortaleza en Interpreta gráficas», con la I mayúscula en medio; eso se
/// replica tal cual, porque el previo sirve precisamente para que lo vea y
/// decida. Y si el texto trae espacios delante, el boletín imprime dos espacios
/// y aquí también: es un previo, no un corrector.
///
/// `NULL` y `''` significan lo mismo, y es ese `trim` el que lo decide. El
/// backend lo dejó escrito: la columna reparte una cosa y otra según qué
/// versión del formulario la escribió, y tratarlas distinto imprimiría un
/// espacio de más en unos colegios y no en otros.
///
/// **Lo único que aquí no se replica** es el texto vacío: `conElPrefijo` no lo
/// mira, así que con la frase en blanco imprimiría «Fortaleza en » —el prefijo
/// y un espacio colgando—. Eso no es un caso del boletín, que nunca imprime una
/// competencia sin definición, sino del campo mientras todavía está vacío, y un
/// previo de nada no es nada: devuelve la lista vacía.
///
/// ## Lista vacía quiere decir «no pintes el bloque»
///
/// Si ninguna banda tiene descripción, o si el texto aún está en blanco, no hay
/// líneas. La pantalla entonces **no pinta nada**: ni un marco vacío ni un
/// «(sin prefijo)». No es un adorno de la regla, es el caso de **todos los
/// colegios hoy** —el 17 sep 2026 las 36 escalas vivas del colegio de
/// desarrollo tenían la descripción a `NULL` o vacía, ninguna con texto—, y un
/// hueco rotulado se lee como que algo falta cuando no falta nada.
///
/// Las bandas salen en el orden en que vengan [escalas], que es de la nota más
/// alta a la más baja tal como las ordenan [YearDelColegio.fromJson] y
/// `traerEscalasDelAnio`.
List<String> previoDeImpresion(String texto, List<EscalaDeValoracion> escalas) {
  if (texto.trim().isEmpty) return const [];

  final lineas = <String>[];

  for (final escala in escalas) {
    final prefijo = escala.descripcion.trim();
    if (prefijo.isEmpty) continue;

    lineas.add('$prefijo $texto');
  }

  return lineas;
}
