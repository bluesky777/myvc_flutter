import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El grupo que el docente eligió en el panel, para no volver a elegirlo.
///
/// La clave lleva dentro el id del usuario, por lo mismo que la de
/// [PreferenciaFiltroAsignaturas]: la app se usa en el equipo compartido de la
/// entrada, y una clave a secas se la encontraba puesta el docente siguiente
/// —con el nombre del grupo y el del titular del anterior— porque cerrar sesión
/// no la borraba.
class PreferenciaGrupo {
  static String _clave() => 'grupoSelected.${AuthService.user.id ?? 0}';

  static Future<void> guardar(GrupoModel grupo) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_clave(), grupo.toRawJson());
  }

  /// El grupo guardado por este usuario, o null si no eligió ninguno.
  static Future<GrupoModel?> leer() async {
    final preferences = await SharedPreferences.getInstance();
    final guardado = preferences.getString(_clave());
    if (guardado == null) return null;

    try {
      return GrupoModel.fromRawJson(guardado);
    } catch (_) {
      // Un JSON que ya no encaja con el modelo no vale más que no tener nada.
      return null;
    }
  }
}
