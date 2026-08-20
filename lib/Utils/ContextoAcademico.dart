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

  /// Cambia el año del usuario.
  ///
  /// `PUT years/useractive/{id}`, que es exactamente lo que llama el front web
  /// desde su barra de arriba. El backend no guarda el año en ninguna parte:
  /// mueve al usuario al periodo del mismo número en el año destino y, si ese
  /// año no lo tiene, al último. O sea que el periodo cambia también, y no
  /// siempre al que uno esperaría: por eso después se relee, en vez de dar por
  /// hecho cuál quedó.
  Future<String?> cambiarYear(Server server, YearModel yearNuevo) async {
    return _cambiar(
      server,
      ruta: '/years/useractive/${yearNuevo.id}',
      accion: 'cambiar de año',
    );
  }

  /// Cambia el periodo del usuario.
  ///
  /// `PUT periodos/useractive/{id}`, el otro de la barra del front.
  Future<String?> cambiarPeriodo(Server server, PeriodoModel periodoNuevo) {
    return _cambiar(
      server,
      ruta: '/periodos/useractive/${periodoNuevo.id}',
      accion: 'cambiar de periodo',
    );
  }

  Future<String?> _cambiar(
    Server server, {
    required String ruta,
    required String accion,
  }) async {
    try {
      final res = await server.put(ruta, {});
      if (res.statusCode >= 300) return _mensaje(res.statusCode, accion);

      return await refrescar(server);
    } catch (err) {
      return 'No se pudo $accion: $err';
    }
  }

  /// Vuelve a leer del servidor con qué año y periodo quedó el usuario.
  ///
  /// Es la misma llamada que hace la app al entrar —`POST /login` con el
  /// token—, que devuelve el contexto ya resuelto. El front web consigue lo
  /// mismo recargando la página entera después de cambiar; aquí basta con
  /// releer, y así lo que se pinta arriba es lo que de verdad quedó guardado y
  /// no lo que la app supuso.
  Future<String?> refrescar(Server server) async {
    try {
      final res = await server.login();
      if (res.statusCode >= 300) {
        return 'Se cambió, pero no se pudo releer el periodo'
            ' (HTTP ${res.statusCode}).';
      }

      final datos = jsonDecode(res.body);
      if (datos is! Map) return 'Se cambió, pero el servidor no dijo con qué.';

      tomarDelLogin(Map<String, dynamic>.from(datos));
      return null;
    } catch (err) {
      return 'Se cambió, pero no se pudo releer el periodo: $err';
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
