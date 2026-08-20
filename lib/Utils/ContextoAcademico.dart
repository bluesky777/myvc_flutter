import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/YearModel.dart';

/// El año y el periodo con los que trabaja el usuario ahora mismo.
///
/// Todo lo que la app pide al servidor cuelga de esta elección: las faltas son
/// las del periodo, las notas son las del periodo, y el listado de grupos es el
/// del año. El backend no la recibe en cada petición —la lee de la fila del
/// usuario—, así que cambiarla es escribir en el servidor y no solo en la app.
///
/// Y ojo con cómo la guarda el backend: en `users` solo hay `periodo_id`. El
/// año sale de a qué año pertenece ese periodo, de modo que cambiar de año es,
/// por debajo, elegir un periodo del año nuevo. Eso lo resuelve
/// `PUT years/useractive/{id}`, que busca el periodo del mismo número en el año
/// destino y, si no existe, se queda con el último.
class ContextoAcademico extends ChangeNotifier {
  ContextoAcademico._();

  static final ContextoAcademico instancia = ContextoAcademico._();

  int? yearId;
  String? year;
  int? periodoId;
  int? numeroPeriodo;

  /// Los años del colegio con sus periodos, para el cuadro de cambio.
  List<YearModel> years = [];

  bool get hayContexto => yearId != null && periodoId != null;

  /// Lo que se lee en la barra: «2026 · Periodo 3».
  String get titulo {
    if (year == null && numeroPeriodo == null) return 'Sin periodo';
    if (numeroPeriodo == null) return '$year';
    if (year == null) return 'Periodo $numeroPeriodo';
    return '$year · Periodo $numeroPeriodo';
  }

  /// Lo que vino en la respuesta de /login.
  void tomarDelLogin(Map<String, dynamic> datos) {
    yearId = _entero(datos['year_id']);
    year = datos['year']?.toString();
    periodoId = _entero(datos['periodo_id']);
    numeroPeriodo = _entero(datos['numero_periodo']);
    notifyListeners();
  }

  /// Deja el contexto como recién arrancada la app.
  void limpiar() {
    yearId = null;
    year = null;
    periodoId = null;
    numeroPeriodo = null;
    years = [];
    notifyListeners();
  }

  /// Trae los años con sus periodos, si no se han traído ya.
  Future<void> cargarYears(Server server, {bool forzar = false}) async {
    if (years.isNotEmpty && !forzar) return;

    final res = await server.get('/years');
    if (res.statusCode >= 300) {
      throw Exception('El servidor respondió ${res.statusCode}.');
    }

    final crudos = jsonDecode(res.body) as List;
    years = crudos
        .map((y) => YearModel.fromJson(y as Map<String, dynamic>))
        .where((y) => y.periodos.isNotEmpty)
        .toList()
      ..sort((a, b) => b.year.compareTo(a.year));

    notifyListeners();
  }

  /// Cambia el periodo del usuario, y con él el año si es de otro.
  ///
  /// Devuelve null si se guardó, o el mensaje de lo que pasó. El orden importa:
  /// primero el año —que mueve al usuario a un periodo cualquiera de ese año— y
  /// después el periodo exacto que se pidió, que es el que manda.
  Future<String?> cambiarA(
    Server server, {
    required YearModel yearNuevo,
    required PeriodoModel periodoNuevo,
  }) async {
    try {
      if (yearNuevo.id != yearId) {
        final res = await server.put('/years/useractive/${yearNuevo.id}', {});
        if (res.statusCode >= 300) {
          return _mensaje(res.statusCode, 'cambiar de año');
        }
      }

      final res =
          await server.put('/periodos/useractive/${periodoNuevo.id}', {});
      if (res.statusCode >= 300) {
        return _mensaje(res.statusCode, 'cambiar de periodo');
      }

      yearId = yearNuevo.id;
      year = yearNuevo.year;
      periodoId = periodoNuevo.id;
      numeroPeriodo = periodoNuevo.numero;
      notifyListeners();

      return null;
    } catch (err) {
      return 'No se pudo cambiar el periodo: $err';
    }
  }

  String _mensaje(int codigo, String accion) {
    if (codigo == 400 || codigo == 401 || codigo == 403) {
      return 'No tienes permiso para $accion.';
    }
    return 'No se pudo $accion (HTTP $codigo).';
  }

  static int? _entero(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString().trim());
  }
}
