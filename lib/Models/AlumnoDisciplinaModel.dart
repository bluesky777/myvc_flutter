import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/SituacionModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Models/UniformeModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Un alumno con todo su año de disciplina, tal como lo devuelve
/// `PUT disciplina/alumnos`.
///
/// El backend no anida los periodos: los cuelga del alumno como claves con el
/// número pegado —`periodo1`, `uniformes_per1`, `tardanzas_per1`,
/// `per1_cant_t1`—, una tanda por cada periodo que tenga el año. Aquí se
/// recogen en mapas por número de periodo, que es como se usan.
class AlumnoDisciplinaModel {
  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? fotoNombre;

  /// El estado de la matrícula. 'ASIS' es asistente: viene a clase pero no
  /// está matriculado, y la web lo pinta en cursiva para distinguirlo.
  final String? estado;

  /// Las situaciones de cada periodo, por número de periodo.
  final Map<int, List<SituacionModel>> situaciones;

  /// Las fallas de uniforme de cada periodo.
  final Map<int, List<UniformeModel>> uniformes;

  /// Las faltas A LA INSTITUCIÓN de cada periodo: tardanzas y ausencias
  /// mezcladas.
  ///
  /// El backend las devuelve bajo `tardanzas_perN`, pero el nombre engaña: esa
  /// consulta filtra por `entrada=1` y no por tipo, así que ahí vienen las dos
  /// clases. Se separan con [tardanzasDe] y [ausenciasDe].
  final Map<int, List<AsistenciaModel>> faltasInstitucion;

  /// Cuántas situaciones de cada tipo cuenta el backend en cada periodo:
  /// `perN_cant_t1`, `_t2` y `_t3`, indexadas por periodo y luego por tipo.
  ///
  /// Se guarda su cuenta y no se recuenta la lista porque no cuentan lo mismo:
  /// el backend salta las situaciones absorbidas por otra derivada de ellas
  /// —las de `become_id` no nulo—, que ya se contaron dentro de aquella.
  final Map<int, Map<int, int>> conteos;

  AlumnoDisciplinaModel({
    required this.alumnoId,
    this.nombres = '',
    this.apellidos = '',
    this.fotoNombre,
    this.estado,
    this.situaciones = const {},
    this.uniformes = const {},
    this.faltasInstitucion = const {},
    this.conteos = const {},
  });

  /// Los periodos que trajo la respuesta, ordenados.
  ///
  /// Se descubren de las propias claves en vez de dar por hecho que son
  /// cuatro: el año lo decide el colegio y hay quien trabaja con tres.
  static final RegExp _clavePeriodo = RegExp(r'^periodo(\d+)$');

  factory AlumnoDisciplinaModel.fromJson(Map<String, dynamic> json) {
    final numeros = <int>[];
    for (final clave in json.keys) {
      final coincidencia = _clavePeriodo.firstMatch(clave);
      final numero = coincidencia == null
          ? null
          : int.tryParse(coincidencia.group(1) ?? '');
      if (numero != null) numeros.add(numero);
    }
    numeros.sort();

    final situaciones = <int, List<SituacionModel>>{};
    final uniformes = <int, List<UniformeModel>>{};
    final faltas = <int, List<AsistenciaModel>>{};
    final conteos = <int, Map<int, int>>{};

    for (final numero in numeros) {
      situaciones[numero] = _lista(
        json['periodo$numero'],
        (mapa) => SituacionModel.fromJson(mapa),
      );

      uniformes[numero] = _lista(
        json['uniformes_per$numero'],
        (mapa) => UniformeModel.fromJson(mapa),
      );

      faltas[numero] = _lista(
        json['tardanzas_per$numero'],
        (mapa) => AsistenciaModel.fromJson(mapa),
      );

      conteos[numero] = {
        for (final tipo in [1, 2, 3])
          tipo: enteroO(json['per${numero}_cant_t$tipo'])
      };
    }

    return AlumnoDisciplinaModel(
      alumnoId: enteroO(json['alumno_id']),
      nombres: '${json['nombres'] ?? ''}'.trim(),
      apellidos: '${json['apellidos'] ?? ''}'.trim(),
      fotoNombre: texto(json['foto_nombre']),
      estado: texto(json['estado']),
      situaciones: situaciones,
      uniformes: uniformes,
      faltasInstitucion: faltas,
      conteos: conteos,
    );
  }

  /// Una lista del backend, saltándose lo que no sea un objeto.
  ///
  /// Una fila rota no puede tumbar la ficha entera del alumno: el docente
  /// vería «no se pudo traer» en vez de sus otras once situaciones.
  static List<T> _lista<T>(
    dynamic crudas,
    T Function(Map<String, dynamic>) construir,
  ) {
    if (crudas is! List) return const [];

    final resultado = <T>[];
    for (final cruda in crudas) {
      if (cruda is! Map) continue;
      resultado.add(construir(Map<String, dynamic>.from(cruda)));
    }
    return resultado;
  }

  /// Los periodos de los que se sabe algo, ordenados.
  List<int> get periodos => situaciones.keys.toList()..sort();

  /// Como se lista un alumno aquí: por apellidos, que es como los ordena el
  /// backend y como los busca el docente en una lista de cuarenta.
  String get nombreCompleto => '$apellidos $nombres'.trim();

  /// Es asistente, no matriculado.
  bool get esAsistente => estado == 'ASIS';

  List<SituacionModel> situacionesDe(int periodo) =>
      situaciones[periodo] ?? const [];

  /// Las situaciones de un tipo en un periodo, las que se pintan al desplegar.
  ///
  /// Aquí sí se filtra la lista, y salen también las absorbidas: al abrir el
  /// detalle el docente quiere ver las tres tardanzas que se volvieron una
  /// falta, no solo la falta. Lo que no se hace es CONTARLAS: para eso está
  /// [cuantasSituaciones], que respeta la cuenta del backend.
  List<SituacionModel> situacionesDeTipo(int periodo, int tipo) =>
      situacionesDe(periodo).where((s) => s.tipo == tipo).toList();

  /// Cuántas situaciones de un tipo, según las cuenta el backend.
  int cuantasSituaciones(int periodo, int tipo) =>
      conteos[periodo]?[tipo] ?? 0;

  List<UniformeModel> uniformesDe(int periodo) => uniformes[periodo] ?? const [];

  int cuantosUniformes(int periodo) => uniformesDe(periodo).length;

  /// Las faltas a la institución de un tipo: llegó tarde, o no vino.
  List<AsistenciaModel> faltasDe(int periodo, TipoFalta tipo) =>
      soloDelTipo(faltasInstitucion[periodo] ?? const [], tipo);

  int cuantasFaltas(int periodo, TipoFalta tipo) =>
      faltasDe(periodo, tipo).length;

  /// Todo lo del periodo sumado, que es el número de la tira de periodos.
  ///
  /// Uniformes, tardanzas, ausencias y las situaciones de los tres tipos. Un
  /// solo número no dice de qué son, y por eso al desplegar la tarjeta salen
  /// los seis por separado; para decidir a cuál de los cuatro periodos entrar,
  /// el total basta.
  int totalDe(int periodo) {
    var total = cuantosUniformes(periodo);

    for (final tipo in TipoFalta.values) {
      total += cuantasFaltas(periodo, tipo);
    }
    for (final tipo in [1, 2, 3]) {
      total += cuantasSituaciones(periodo, tipo);
    }
    return total;
  }

  /// Si el alumno no tiene absolutamente nada anotado en el año.
  bool get limpio => periodos.every((periodo) => totalDe(periodo) == 0);

  /// Si tiene alguna situación de tipo 2 o 3 en el periodo, que es lo que hace
  /// que la tarjeta se pinte con aviso.
  bool tieneGravesEn(int periodo) =>
      cuantasSituaciones(periodo, 2) > 0 || cuantasSituaciones(periodo, 3) > 0;

  @override
  String toString() => '(AlumnoDisciplinaModel) $alumnoId $nombreCompleto';
}
