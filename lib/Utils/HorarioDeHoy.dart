import 'package:myvc_flutter/Http/UnidadesApi.dart';

/// Qué clases dicta hoy el docente que tiene la sesión abierta.
///
/// El colegio puede configurar, asignatura por asignatura, qué días de la
/// semana se dicta —son las columnas `lunes` … `sabado` de `asignaturas`, que
/// se editan en la plataforma web—. Cuando están puestas, de doce asignaturas
/// hoy tocan tres, y enseñar las doce al entrar es hacerle buscar la suya entre
/// nueve que no le sirven.
///
/// **Esto no cuesta ninguna petición.** El backend ya calcula el horario del
/// día y lo devuelve dentro de `GET ChangesAsked/to-me`, que es lo que la app
/// pide para pintar el muro: la clave `horario_hoy`, ya filtrada por el
/// servidor y respetando `show_materias_todas`. Hasta ahora la app la tiraba.
/// Aquí se guarda al leer el muro y la pantalla de notas la aprovecha.
///
/// Y por eso mismo puede no saberse nada: para un alumno esa clave no viene, y
/// si el muro todavía no se ha cargado no hay horario que consultar. La
/// diferencia entre «hoy no hay clases» y «no se sabe» importa —una cosa es
/// enseñar una lista vacía y la otra es esconder el filtro—, así que
/// [seSabe] las distingue en vez de tratar las dos como una lista vacía.
class HorarioDeHoy {
  HorarioDeHoy._();

  static final HorarioDeHoy instancia = HorarioDeHoy._();

  /// Las asignaturas de hoy, o null mientras no se haya leído el muro.
  ///
  /// Vienen con sus unidades y subunidades ya dentro: `asignaturas_dia` las
  /// cuelga de cada asignatura. No traen `cantNotas`, que solo la cuenta el
  /// listado de asignaturas.
  List<AsignaturaConUnidades>? _clases;

  /// Si se sabe algo del horario de hoy. Falso hasta que el muro se lea una vez.
  bool get seSabe => _clases != null;

  List<AsignaturaConUnidades> get clases => _clases ?? const [];

  /// Los ids de las asignaturas de hoy, que es con lo que se filtra el listado
  /// completo. Se filtra por id y no quedándose con estas asignaturas porque el
  /// listado completo trae además cuántas notas lleva puesta cada subunidad.
  Set<int> get asignaturaIds =>
      clases.map((c) => c.asignatura.id).where((id) => id != 0).toSet();

  /// Cuántas clases tocan hoy, para decirlo en el muro.
  int get cuantas => clases.length;

  void tomar(List<AsignaturaConUnidades> clasesDeHoy) {
    _clases = clasesDeHoy;
  }

  /// Deja el horario como recién arrancada la app.
  ///
  /// Al cerrar sesión, sin falta: son las clases de quien se va, y el docente
  /// siguiente no tiene por qué ver en el muro cuántas clases tenía el anterior.
  void limpiar() {
    _clases = null;
  }
}
