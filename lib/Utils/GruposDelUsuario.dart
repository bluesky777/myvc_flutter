import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';

/// Los grupos que le tocan a quien está mirando, de entre [todos].
///
/// Las rutas de grupos devuelven TODOS los del año —el backend no filtra—, así
/// que el recorte es de aquí:
///
///  - Quien es especial —superusuario, admin, coordinación— los ve todos.
///  - Un docente ve aquellos donde tiene asignatura, más el que sea suyo por
///    ser titular aunque no le dé ninguna clase.
///  - A quien no es ninguna de las dos cosas —una secretaría, sin rol de
///    coordinación— se le enseñan todos: no da clase en ninguno, así que
///    filtrar por asignaturas le dejaría la pantalla en blanco, y el backend
///    ya decidió que es personal del colegio al dejarle pasar.
///
/// Salió de `DisciplinaGrupoScreen` el 16 oct 2026, cuando los juegos y la
/// racha de inglés necesitaron el mismo recorte.
Future<List<GrupoModel>> gruposDelUsuario(
  Server server,
  List<GrupoModel> todos,
) async {
  final usuario = AuthService.user;

  if (usuario.esEspecial || !usuario.esDocente) return todos;

  final mios = <int>{};
  try {
    final asignaturas = await traerAsignaturasConUnidades(server);
    for (final asignatura in asignaturas) {
      mios.add(asignatura.asignatura.grupoId);
    }
  } catch (_) {
    // Sin sus asignaturas queda al menos el grupo del que es titular, que es
    // mejor que una pantalla vacía sin explicación.
  }

  final personaId = usuario.personaId;

  return todos
      .where((grupo) =>
          mios.contains(grupo.id) ||
          (personaId != null && grupo.titularId == personaId))
      .toList();
}
