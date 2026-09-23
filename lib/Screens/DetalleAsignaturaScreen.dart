import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Utils/ConfiguracionColegio.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FormatoDeNota.dart';

/// Los argumentos de la pantalla. Van juntos porque sin el periodo el título
/// no sabe de cuál de los cuatro está enseñando las notas.
class DetalleAsignaturaArgs {
  const DetalleAsignaturaArgs({
    required this.asignatura,
    required this.alumno,
    this.numeroPeriodo,
  });

  final AsignaturaNotaModel asignatura;

  /// De quién son. Lo pinta el subtítulo: un acudiente con dos hijos llega aquí
  /// desde un aviso y tiene que poder confirmar que está mirando al que cree.
  final String alumno;

  final int? numeroPeriodo;
}

/// De qué notas sale la definitiva de una asignatura.
///
/// **La pantalla que el aviso push llevaba prometiendo desde el primer día.**
/// El aviso dice «Laura tiene 3 notas nuevas en Matemáticas» y hasta ahora
/// llevaba a la definitiva del periodo, que sí había cambiado pero no decía
/// cuáles eran las tres. Aquí están.
///
/// **El dato no costó una petición.** `GET notas/alumno/{id}/{grupo}` —la que
/// «Mis notas» ya llamaba— devuelve `unidades` → `subunidades` → `nota` dentro
/// de cada asignatura, y el parser lo descartaba. Ver
/// [AsignaturaNotaModel.unidades].
///
/// **Cómo se llaman las dos cosas lo decide el colegio**, en
/// `unidad_displayname` y `subunidad_displayname`: «Logro» e «Indicador» en
/// uno, «Desempeño» e «Instrumento de Evaluación» en otro. Aquí no se escribe
/// ninguno a mano.
class DetalleAsignaturaScreen extends StatelessWidget {
  const DetalleAsignaturaScreen({super.key, required this.args});

  final DetalleAsignaturaArgs args;

  ConfiguracionColegio get _config => ContextoAcademico.instancia.config;

  @override
  Widget build(BuildContext context) {
    final asignatura = args.asignatura;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(asignatura.alias?.isNotEmpty == true
            ? asignatura.alias!
            : asignatura.materia),
        // El alumno y el periodo debajo del nombre: quien llega desde un aviso
        // no eligió esta pantalla, la abrió un cartel, y conviene que sepa
        // dónde está sin volver atrás a comprobarlo.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  args.alumno,
                  if (args.numeroPeriodo != null)
                    'Periodo ${args.numeroPeriodo}',
                ].where((t) => t.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ),
      ),
      body: asignatura.hayDesglose
          ? ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              children: [
                _definitiva(context),
                for (final unidad in asignatura.unidades) _unidad(unidad),
              ],
            )
          : _sinDesglose(context),
    );
  }

  /// La definitiva arriba, que es de donde se viene.
  Widget _definitiva(BuildContext context) {
    final asignatura = args.asignatura;

    return _tarjeta(
      child: ListTile(
        title: const Text('Definitiva del periodo'),
        subtitle: asignatura.desempenio == null
            ? null
            : Text(asignatura.desempenio!,
                style: const TextStyle(fontSize: 12)),
        trailing: Text(
          asignatura.tieneNota ? asignatura.notaEscrita : '—',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _colorDe(asignatura.nota),
          ),
        ),
      ),
    );
  }

  Widget _unidad(UnidadNotaModel unidad) {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    unidad.definicion.isEmpty
                        ? '${_config.unidad} sin descripción'
                        : unidad.definicion,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                // El peso solo cuando el colegio reparte por porcentaje. En el
                // que promedia, ese número no significa nada y estorba.
                if (unidad.porcentaje != null && unidad.porcentaje! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text('${notaPintada(unidad.porcentaje)} %',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (unidad.subunidades.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Sin ${_config.subunidades.toLowerCase()} todavía.',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          for (final sub in unidad.subunidades) _subunidad(sub),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _subunidad(SubunidadNotaModel sub) {
    return ListTile(
      dense: true,
      title: Text(
        sub.definicion.isEmpty
            ? '${_config.subunidad} sin descripción'
            : sub.definicion,
        style: const TextStyle(fontSize: 13.5),
      ),
      subtitle: sub.desempenio == null || sub.desempenio!.isEmpty
          ? null
          : Text(sub.desempenio!, style: const TextStyle(fontSize: 11.5)),
      // **Sin calificar y cero no se pintan igual**, y es lo único que esta
      // pantalla no puede equivocar: un cero donde nadie ha corregido le dice
      // a una familia que su hijo perdió algo que ni siquiera se ha revisado.
      trailing: sub.tieneNota
          ? Text(
              sub.notaEscrita,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _colorDe(sub.nota),
              ),
            )
          : const Text(
              'sin calificar',
              style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
    );
  }

  /// Rojo si está perdida; si no, el de siempre. Sin calificar no llega aquí:
  /// [ConfiguracionColegio.esPerdida] da falso con la nota nula.
  Color? _colorDe(num? nota) =>
      _config.esPerdida(nota) ? Colors.red[700] : null;

  /// Cuando el docente no montó nada ese periodo.
  ///
  /// Se dice en vez de dejar la pantalla vacía, porque «no hay nada» y «no
  /// cargó» se ven igual y solo uno de los dos es culpa de la app.
  Widget _sinDesglose(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 52, color: Colors.black26),
            const SizedBox(height: 14),
            Text(
              'Todavía no hay ${_config.unidades.toLowerCase()} en esta'
              ' asignatura para este periodo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando el docente las monte y califique, aparecen aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }
}
