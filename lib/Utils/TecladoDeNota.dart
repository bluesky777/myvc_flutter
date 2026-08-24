import 'package:flutter/services.dart';

/// Cómo se teclea una nota en esta app: números enteros y nada más.
///
/// **Porque un decimal no existe en ninguna parte del sistema.** No es que se
/// pierda al guardarlo: `notas.nota`, `notas_finales.nota`,
/// `unidades.porcentaje`, `subunidades.porcentaje` y `subunidades.nota_default`
/// son **`int` en el esquema**, las cinco. Un 85,5 nunca fue un 85,5.
///
/// Hasta el 23 de agosto de 2026 los campos de nota traían el teclado con coma
/// y dejaban escribirla. Lo que pasaba entonces es lo peor de las tres cosas
/// que podían pasar: la app aceptaba «85,5», lo mandaba como `85.5`, el
/// servidor lo metía en una columna entera —donde queda 85— y **la app seguía
/// enseñando 85,5 hasta que alguien recargaba**. O sea que el docente veía una
/// nota que no estaba guardada, y se enteraba al día siguiente o nunca. El
/// mismo fallo estaba medido en el front web, que además anunciaba «Cambiada:
/// 85,5» con la columna guardando 85.
///
/// Se arregla por el teclado y no redondeando al guardar, y eso lo decidió
/// Joseth el 23 de agosto de 2026: **redondear es la app cambiando un número
/// que escribió una persona**. Si un 85,5 tiene que ser 86, lo decide quien
/// pone la nota, no nosotros. Es la misma regla que ya estaba escrita en
/// `notaLeida`: mejor no guardar que mandar un número inventado.
const tecladoDeNota = TextInputType.number;

/// El filtro que acompaña a [tecladoDeNota].
const formateadoresDeNota = [SinDecimales()];

/// Deja pasar solo dígitos, **rechazando la edición entera** cuando no lo son.
///
/// La diferencia con `FilteringTextInputFormatter.digitsOnly` es la que importa
/// aquí, y no es de estilo: aquél **borra** los caracteres que no valen, así
/// que pegar «85.5» en la casilla la deja en **855**, que es una nota real,
/// distinta y peor que la que se pegó. Rechazando la edición, la casilla se
/// queda como estaba y quien pega lo ve.
///
/// Borrar siempre se permite, incluso si lo que hay escrito trae una coma: si
/// no, un valor con coma que hubiera llegado por otro camino dejaría el campo
/// bloqueado sin forma de arreglarlo.
class SinDecimales extends TextInputFormatter {
  const SinDecimales();

  static final _soloDigitos = RegExp(r'^[0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    if (nuevo.text.length < anterior.text.length) return nuevo;

    return _soloDigitos.hasMatch(nuevo.text) ? nuevo : anterior;
  }
}
