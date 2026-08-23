import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// Cómo está configurado el colegio, tal como lo devuelve `GET years/colegio`.
///
/// **No es [YearModel], y son cosas distintas a propósito.** Aquel es el año
/// que pinta el selector de la barra de arriba y por eso es flaco: id, año,
/// periodos y poco más. Este trae la configuración entera de cada año —los
/// interruptores, la nota mínima, cómo llama el colegio a las unidades— y las
/// escalas de valoración, y solo lo necesita la pantalla de configuración.
/// Engordar el otro haría que toda la app cargara con esto.
class YearDelColegio {
  final int id;
  final String year;
  final String nombreColegio;
  final bool actual;

  /// A partir de qué nota se aprueba.
  final int? notaMinimaAceptada;

  /// Si alumnos y acudientes pueden ver sus notas ahora mismo. Es el
  /// interruptor de urgencia: se apaga mientras se cuadran los boletines.
  final bool alumnosPuedenVerNotas;

  /// Lo que se les enseña mientras está apagado, si el colegio escribió algo.
  final String? mensajeBloqueadas;

  /// **Ojo con el nombre: la columna dice lo contrario que el interruptor.**
  /// `solo_escalas_valorativas` en 1 significa que el alumno NO ve números,
  /// solo «Alto», «Superior». La pantalla pregunta si los ve, que es como se
  /// piensa, así que en algún sitio hay que invertirlo; se hace aquí, una vez.
  final bool alumnosVenNumeros;

  /// Si al docente se le enseñan todas sus asignaturas ignorando el horario.
  final bool mostrarTodasLasMaterias;

  /// Los de solo lectura: explican cosas que el usuario nota, pero no se
  /// cambian estando de pie.
  final bool docentesPuedenEditarAlumnos;
  final bool puestoEnBoletin;
  final bool notaComportamientoEnBoletin;
  final bool anioPasadoEnBoletin;
  final bool recuperarEximeDeNivelar;

  /// Cómo llama el colegio a las unidades y a las subunidades.
  final String unidad;
  final String subunidad;

  final List<PeriodoDelColegio> periodos;
  final List<EscalaDeValoracion> escalas;

  const YearDelColegio({
    required this.id,
    required this.year,
    this.nombreColegio = '',
    this.actual = false,
    this.notaMinimaAceptada,
    this.alumnosPuedenVerNotas = true,
    this.mensajeBloqueadas,
    this.alumnosVenNumeros = true,
    this.mostrarTodasLasMaterias = false,
    this.docentesPuedenEditarAlumnos = false,
    this.puestoEnBoletin = false,
    this.notaComportamientoEnBoletin = false,
    this.anioPasadoEnBoletin = false,
    this.recuperarEximeDeNivelar = false,
    this.unidad = 'Unidad',
    this.subunidad = 'Subunidad',
    this.periodos = const [],
    this.escalas = const [],
  });

  /// El mismo año con un interruptor movido, para repintar sin volver a pedir.
  YearDelColegio copiaCon({
    bool? alumnosPuedenVerNotas,
    bool? alumnosVenNumeros,
    bool? mostrarTodasLasMaterias,
    List<PeriodoDelColegio>? periodos,
  }) {
    return YearDelColegio(
      id: id,
      year: year,
      nombreColegio: nombreColegio,
      actual: actual,
      notaMinimaAceptada: notaMinimaAceptada,
      alumnosPuedenVerNotas:
          alumnosPuedenVerNotas ?? this.alumnosPuedenVerNotas,
      mensajeBloqueadas: mensajeBloqueadas,
      alumnosVenNumeros: alumnosVenNumeros ?? this.alumnosVenNumeros,
      mostrarTodasLasMaterias:
          mostrarTodasLasMaterias ?? this.mostrarTodasLasMaterias,
      docentesPuedenEditarAlumnos: docentesPuedenEditarAlumnos,
      puestoEnBoletin: puestoEnBoletin,
      notaComportamientoEnBoletin: notaComportamientoEnBoletin,
      anioPasadoEnBoletin: anioPasadoEnBoletin,
      recuperarEximeDeNivelar: recuperarEximeDeNivelar,
      unidad: unidad,
      subunidad: subunidad,
      periodos: periodos ?? this.periodos,
      escalas: escalas,
    );
  }

  /// El mismo año con un periodo cambiado, partiendo del que hay **ahora**.
  ///
  /// Recibe una función y no un periodo ya hecho, y esto no es capricho: los
  /// interruptores de un periodo se pueden tocar mientras otro del mismo
  /// periodo sigue en vuelo. Con un periodo capturado antes de la petición, el
  /// segundo en responder escribiría encima con los valores de antes y borraría
  /// el cambio del primero. Aplicándolo sobre el que hay en ese momento, cada
  /// respuesta toca solo su campo.
  YearDelColegio cambiandoPeriodo(
    int periodoId,
    PeriodoDelColegio Function(PeriodoDelColegio) comoQueda,
  ) {
    return copiaCon(periodos: [
      for (final periodo in periodos)
        periodo.id == periodoId ? comoQueda(periodo) : periodo,
    ]);
  }

  /// El mismo año con otro periodo marcado como el actual del colegio.
  ///
  /// Los demás se apagan aquí porque el backend hace exactamente eso: recorre
  /// los del año poniéndoles `actual = 0` antes de encender el elegido. Si la
  /// app solo encendiera el nuevo, quedarían dos en pantalla.
  YearDelColegio conActual(int periodoId) {
    return copiaCon(periodos: [
      for (final periodo in periodos)
        periodo.copiaCon(actual: periodo.id == periodoId),
    ]);
  }

  factory YearDelColegio.fromJson(Map<String, dynamic> json) {
    final periodos = json['periodos'];
    final escalas = json['escalas'];

    return YearDelColegio(
      id: enteroO(json['id']),
      year: '${json['year'] ?? ''}',
      nombreColegio: '${json['nombre_colegio'] ?? ''}',
      actual: entero(json['actual']) == 1,
      notaMinimaAceptada: entero(json['nota_minima_aceptada']),
      alumnosPuedenVerNotas: _si(json['alumnos_can_see_notas'], true),
      mensajeBloqueadas: texto(json['msg_when_students_blocked']),
      alumnosVenNumeros: !_si(json['solo_escalas_valorativas'], false),
      mostrarTodasLasMaterias: _si(json['show_materias_todas'], false),
      docentesPuedenEditarAlumnos: _si(json['profes_can_edit_alumnos'], false),
      puestoEnBoletin: _si(json['mostrar_puesto_boletin'], false),
      notaComportamientoEnBoletin:
          _si(json['mostrar_nota_comport_boletin'], false),
      anioPasadoEnBoletin: _si(json['year_pasado_en_bol'], false),
      recuperarEximeDeNivelar:
          _si(json['si_recupera_materia_recup_indicador'], false),
      unidad: _nombre(json['unidad_displayname'], 'Unidad'),
      subunidad: _nombre(json['subunidad_displayname'], 'Subunidad'),
      periodos: periodos is List
          ? (periodos
              .whereType<Map>()
              .map((p) =>
                  PeriodoDelColegio.fromJson(Map<String, dynamic>.from(p)))
              .toList()
            ..sort((a, b) => a.numero.compareTo(b.numero)))
          : const [],
      escalas: escalas is List
          ? (escalas
              .whereType<Map>()
              .map((e) =>
                  EscalaDeValoracion.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            // De la nota más alta a la más baja, que es como se lee una escala
            // y como la imprime el boletín.
            ..sort((a, b) => b.porcInicial.compareTo(a.porcInicial)))
          : const [],
    );
  }
}

/// Un periodo del año, con lo que decide si los docentes pueden escribir.
class PeriodoDelColegio {
  final int id;
  final int numero;

  /// Si es el periodo actual **del colegio**, que no es el periodo en el que
  /// está mirando el usuario. Ver la nota de la pantalla.
  final bool actual;

  final DateTime? inicio;
  final DateTime? fin;

  /// Si los docentes pueden editar notas, indicadores, tardanzas y
  /// comportamientos en este periodo.
  final bool puedenEditarNotas;

  /// Si los docentes pueden nivelar o modificar las notas finales. Es un
  /// permiso aparte y se abre en otro momento.
  final bool puedenNivelar;

  const PeriodoDelColegio({
    required this.id,
    required this.numero,
    this.actual = false,
    this.inicio,
    this.fin,
    this.puedenEditarNotas = true,
    this.puedenNivelar = true,
  });

  PeriodoDelColegio copiaCon({
    bool? actual,
    DateTime? inicio,
    DateTime? fin,
    bool? puedenEditarNotas,
    bool? puedenNivelar,
  }) {
    return PeriodoDelColegio(
      id: id,
      numero: numero,
      actual: actual ?? this.actual,
      inicio: inicio ?? this.inicio,
      fin: fin ?? this.fin,
      puedenEditarNotas: puedenEditarNotas ?? this.puedenEditarNotas,
      puedenNivelar: puedenNivelar ?? this.puedenNivelar,
    );
  }

  factory PeriodoDelColegio.fromJson(Map<String, dynamic> json) {
    return PeriodoDelColegio(
      id: enteroO(json['id']),
      numero: enteroO(json['numero']),
      actual: entero(json['actual']) == 1,
      inicio: DateTime.tryParse('${json['fecha_inicio'] ?? ''}'),
      fin: DateTime.tryParse('${json['fecha_fin'] ?? ''}'),
      puedenEditarNotas: _si(json['profes_pueden_editar_notas'], true),
      puedenNivelar: _si(json['profes_pueden_nivelar'], true),
    );
  }
}

/// Un tramo de la escala de valoración: lo que traduce «85» a «Alto».
///
/// Solo se lee. Montarla es cosa de una vez al año y de una pantalla grande,
/// pero consultarla la consulta un docente más de lo que uno cree.
class EscalaDeValoracion {
  final int id;
  final String desempenio;
  final String valoracion;
  final double porcInicial;
  final double porcFinal;

  /// Si este tramo cuenta como perdido.
  final bool perdido;

  const EscalaDeValoracion({
    required this.id,
    this.desempenio = '',
    this.valoracion = '',
    this.porcInicial = 0,
    this.porcFinal = 0,
    this.perdido = false,
  });

  /// El tramo como se lee: «91 a 100».
  String get rango =>
      '${_sinDecimalesSiEsRedondo(porcInicial)} a'
      ' ${_sinDecimalesSiEsRedondo(porcFinal)}';

  factory EscalaDeValoracion.fromJson(Map<String, dynamic> json) {
    return EscalaDeValoracion(
      id: enteroO(json['id']),
      desempenio: '${json['desempenio'] ?? ''}',
      valoracion: '${json['valoracion'] ?? ''}',
      porcInicial: _numero(json['porc_inicial']),
      porcFinal: _numero(json['porc_final']),
      perdido: _si(json['perdido'], false),
    );
  }
}

/// Una bandera 0/1 del backend, con respaldo si no vino.
///
/// Solo un 0 explícito significa «no»: lo que no llega no es un no. Y con
/// [entero] porque estas columnas viajan por `DB::select` a pelo y, según el
/// driver de PDO, pueden llegar como número o como cadena.
bool _si(dynamic valor, bool respaldo) {
  final numero = entero(valor);
  return numero == null ? respaldo : numero != 0;
}

String _nombre(dynamic valor, String respaldo) {
  final crudo = texto(valor)?.trim();
  return (crudo == null || crudo.isEmpty) ? respaldo : crudo;
}

double _numero(dynamic valor) {
  if (valor == null) return 0;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.')) ?? 0;
}

String _sinDecimalesSiEsRedondo(double valor) => valor == valor.roundToDouble()
    ? valor.toStringAsFixed(0)
    : valor.toStringAsFixed(1);
