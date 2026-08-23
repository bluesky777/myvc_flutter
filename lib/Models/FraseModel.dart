import 'package:myvc_flutter/Utils/JsonBackend.dart';
import 'package:myvc_flutter/Utils/TextoPlano.dart';

/// Una frase del catálogo del colegio: la información que se le pone a un
/// alumno en el boletín además de la nota.
///
/// El catálogo es del año y lo escribe el colegio a mano, una a una —en la
/// copia de producción son más de cuatrocientas—, así que la lista se busca
/// escribiendo y no se recorre. Aquí solo se leen: crearlas y editarlas es una
/// pantalla de la web.
class FraseDelCatalogo {
  final int id;
  final String frase;

  /// 'Fortaleza', 'Debilidad', 'Oportunidad' o 'Amenaza'. Son los cuatro que
  /// ofrece el desplegable de la web; el backend guarda la cadena tal cual, así
  /// que aquí no se traduce ni se valida, se enseña.
  final String tipo;

  const FraseDelCatalogo({
    required this.id,
    required this.frase,
    this.tipo = '',
  });

  bool coincideCon(String busqueda) =>
      coincideConBusqueda('$frase $tipo', busqueda);

  factory FraseDelCatalogo.fromJson(Map<String, dynamic> json) {
    return FraseDelCatalogo(
      id: enteroO(json['id']),
      frase: '${json['frase'] ?? ''}',
      tipo: '${json['tipo_frase'] ?? ''}',
    );
  }
}

/// Una frase ya puesta a un alumno en una asignatura y un periodo.
///
/// Puede venir de dos sitios y hay que distinguirlos: si tiene [fraseId] es una
/// del catálogo —y el backend resuelve su texto con un `IFNULL`, así que si
/// alguien la edita en la web cambia también aquí—, y si no, es una escrita a
/// mano para este alumno y solo vive en su fila.
class FraseDeAlumno {
  /// El id de la fila de `frases_asignatura`, que es lo que necesita
  /// `frases_asignatura/destroy/{id}`. **No es el id de la frase del catálogo.**
  final int id;

  final String frase;

  /// De qué frase del catálogo salió, o null si se escribió a mano.
  final int? fraseId;

  final String tipo;

  const FraseDeAlumno({
    required this.id,
    required this.frase,
    this.fraseId,
    this.tipo = '',
  });

  bool get esDelCatalogo => fraseId != null && fraseId != 0;

  factory FraseDeAlumno.fromJson(Map<String, dynamic> json) {
    return FraseDeAlumno(
      id: enteroO(json['id']),
      frase: '${json['frase'] ?? ''}',
      fraseId: entero(json['frase_id']),
      tipo: '${json['tipo_frase'] ?? ''}',
    );
  }
}

/// Las frases de una lista cruda del backend, saltándose lo que no sea un
/// objeto.
List<FraseDeAlumno> frasesDeLista(dynamic crudas) {
  if (crudas is! List) return const [];

  return crudas
      .whereType<Map>()
      .map((f) => FraseDeAlumno.fromJson(Map<String, dynamic>.from(f)))
      .where((f) => f.id != 0)
      .toList();
}
