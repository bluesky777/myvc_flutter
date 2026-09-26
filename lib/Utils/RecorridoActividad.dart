/// EL RECORRIDO: qué preguntas ve quien responde, según lo que ya respondió.
///
/// **Es la copia en Dart de `8myvc/app/Services/Act/Recorrido.php`**, y tiene
/// que dar lo mismo que ella (contrato §2.5). El servidor vuelve a evaluar al
/// enviar —descarta lo respondido en preguntas que no quedaron visibles y exige
/// las visibles obligatorias—, así que un desacuerdo aquí no guarda nada mal:
/// lo que hace es enseñar una pregunta de más o de menos. Por eso no se llama a
/// `POST act/{id}/recorrido` en cada toque: sería una petición por respuesta
/// para saber algo que se calcula aquí igual.
///
///   visible(P) = P sin condiciones, o ALGÚN grupo con TODAS sus condiciones.
///   cumple(c)  = la pregunta de la que depende es visible Y fue respondida Y
///                el operador acierta. Sin responder no se cumple —tampoco
///                `no_es`—.
///
/// Como `depende_de` siempre es anterior, basta una pasada en `orden`.
library;

import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Utils/TextoPlano.dart';

/// Los ids de las preguntas visibles, en orden.
List<int> preguntasVisibles(
    List<PreguntaAct> preguntas, Map<int, RespuestaAct> respuestas) {
  final ordenadas = [...preguntas]..sort((a, b) =>
      a.orden != b.orden ? a.orden.compareTo(b.orden) : a.id.compareTo(b.id));

  final tipos = {for (final p in ordenadas) p.id: p.tipo};
  final visible = <int, bool>{};

  for (final p in ordenadas) {
    if (p.condiciones.isEmpty) {
      visible[p.id] = true;
      continue;
    }

    var alguno = false;
    for (final grupo in p.condiciones) {
      var todas = grupo.isNotEmpty;
      for (final c in grupo) {
        final dep = c.dependeDeId;
        if (!(visible[dep] ?? false) ||
            !_cumple(c, tipos[dep] ?? '', respuestas[dep])) {
          todas = false;
          break;
        }
      }
      if (todas) {
        alguno = true;
        break;
      }
    }
    visible[p.id] = alguno;
  }

  return [
    for (final p in ordenadas)
      if (visible[p.id] ?? false) p.id
  ];
}

/// Si una respuesta dice algo; una vacía cuenta como no respondida.
bool respuestaDada(String tipo, RespuestaAct? r) {
  if (r == null) return false;

  if (PreguntaAct.tiposDeOpciones.contains(tipo)) {
    return r.opcionIds.isNotEmpty || (r.texto ?? '').trim().isNotEmpty;
  }

  switch (tipo) {
    case 'corta':
    case 'parrafo':
      return (r.texto ?? '').trim().isNotEmpty;
    case 'escala':
      return r.valor != null;
    case 'fecha':
      return (r.fecha ?? '').isNotEmpty;
    case 'archivo':
      return r.archivoId != null;
    default:
      return false;
  }
}

/// Recortar, minúsculas, sin tildes, espacios repetidos a uno (§2.4). Es
/// [textoPlano], que ya hacía exactamente eso para las búsquedas.
String normalizarRespuesta(String? t) => textoPlano(t ?? '');

bool _cumple(CondicionAct c, String tipo, RespuestaAct? r) {
  if (r == null || !respuestaDada(tipo, r)) return false;

  final es = _es(c, tipo, r);

  switch (c.operador) {
    case 'es':
      return es;
    case 'no_es':
      return !es;
    case 'contiene':
      return tipo == 'corta' || tipo == 'parrafo'
          ? normalizarRespuesta(r.texto).contains(normalizarRespuesta(c.valor))
          : es;
    default:
      return false;
  }
}

bool _es(CondicionAct c, String tipo, RespuestaAct r) {
  if (PreguntaAct.tiposDeOpciones.contains(tipo)) {
    return c.opcionId != null && r.opcionIds.contains(c.opcionId);
  }

  switch (tipo) {
    case 'escala':
      return r.valor == (int.tryParse((c.valor ?? '').trim()) ?? 0);
    case 'corta':
    case 'parrafo':
      return normalizarRespuesta(r.texto) == normalizarRespuesta(c.valor);
    case 'fecha':
      return (r.fecha ?? '') == (c.valor ?? '').trim();
    default:
      return false;
  }
}
