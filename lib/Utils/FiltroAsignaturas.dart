import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué asignaturas ve el docente al entrar a notas.
enum FiltroAsignaturas {
  /// Solo las que dicta hoy, según los días configurados en cada asignatura.
  hoy,

  /// Todas las del año.
  todas,
}

/// Recuerda con qué filtro dejó la pantalla de notas cada quien.
///
/// Por defecto **hoy**: es lo que el docente viene a hacer al abrir la app
/// entre clase y clase. Quien prefiera verlas todas lo cambia una vez y no
/// vuelve a tocarlo.
///
/// La clave lleva dentro el id del usuario, y no es manía: la app se usa en el
/// equipo compartido de la entrada —por eso existe [PreferenciasSesion]—, y una
/// preferencia de pantalla guardada a secas se la habría encontrado puesta el
/// docente siguiente.
class PreferenciaFiltroAsignaturas {
  static String _clave() => 'asignaturas.filtro.${AuthService.user.id ?? 0}';

  static Future<FiltroAsignaturas> leer() async {
    final preferences = await SharedPreferences.getInstance();
    final guardado = preferences.getString(_clave());

    return guardado == FiltroAsignaturas.todas.name
        ? FiltroAsignaturas.todas
        : FiltroAsignaturas.hoy;
  }

  static Future<void> guardar(FiltroAsignaturas filtro) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_clave(), filtro.name);
  }
}
