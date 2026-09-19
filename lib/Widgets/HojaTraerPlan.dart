import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/YearModel.dart';

/// De dónde se trae el plan: otro periodo de este año, u otro año.
///
/// Son excluyentes y por eso son dos constructores y no dos campos que alguien
/// pueda rellenar a la vez. El backend los distingue por `origen.tipo`, y
/// mandar los dos sería pedirle que elija él.
class OrigenDelPlan {
  const OrigenDelPlan.periodo(int this.periodoId, {required this.comoSeLlama})
      : yearId = null;

  const OrigenDelPlan.year(int this.yearId, {required this.comoSeLlama})
      : periodoId = null;

  final int? periodoId;
  final int? yearId;

  /// Cómo se llamaba en la lista, para poder decirlo en el aviso de después.
  ///
  /// Se guarda aquí y no se vuelve a buscar: el aviso sale cuando la hoja ya
  /// se cerró, y «se trajeron 4 del Periodo 1» dice bastante más que «se
  /// trajeron 4».
  final String comoSeLlama;
}

/// La hoja para traer a esta clase un plan que ya está escrito en otro sitio.
///
/// ## Lo que dice arriba no es relleno
///
/// **«Se añaden las que falten. No se borra ni se cambia nada.»** Es cierto
/// —el servidor sólo inserta, y se salta las que ya estén comparando el texto
/// sin acentos ni mayúsculas— y es justo lo que alguien necesita saber antes
/// de pulsar un botón que dice «traer» sobre un trabajo que ya tiene hecho a
/// medias. Sin esa línea, el docente con tres competencias escritas no lo
/// toca, por si le pisa las suyas.
///
/// ## Por qué no hay un selector de grado
///
/// El backend admite traer de **otro grado** y aquí no se ofrece:
/// `Profesor::asignaturas` no manda el nombre del grado, así que esa lista
/// saldría con los grados sin nombre. Elegir a ciegas dónde va a escribir es
/// peor que no poder elegir. Ver el docblock de `copiarCompetencias`.
///
/// ## Y por qué el periodo de destino no se elige
///
/// Porque es siempre en el que se está. El permiso del backend mira la bandera
/// **del periodo en el que escribe**, y la que la app tiene a mano es la del
/// periodo de la sesión: fijando el destino ahí, las dos son la misma.
Future<OrigenDelPlan?> pedirOrigenDelPlan(
  BuildContext context, {
  required String titulo,
  required List<PeriodoModel> periodos,
  required int periodoDestino,
  required List<YearModel> years,
  required int? yearDestino,
}) {
  // El origen no puede ser el destino: el servidor contesta 422 y tiene razón
  // —copiar un grupo sobre sí mismo daría «revisados N, copiados 0», un 200 que
  // parece que funcionó—. Se quita de la lista en vez de dejar pulsarlo.
  final otrosPeriodos = periodos.where((p) => p.id != periodoDestino).toList();
  final otrosYears = years.where((y) => y.id != yearDestino).toList();

  return showModalBottomSheet<OrigenDelPlan>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.8,
    ),
    builder: (_) => _HojaTraerPlan(
      titulo: titulo,
      periodos: otrosPeriodos,
      years: otrosYears,
    ),
  );
}

class _HojaTraerPlan extends StatelessWidget {
  const _HojaTraerPlan({
    required this.titulo,
    required this.periodos,
    required this.years,
  });

  final String titulo;
  final List<PeriodoModel> periodos;
  final List<YearModel> years;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Traer a $titulo',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Se añaden las que falten. No se borra ni se cambia nada de lo'
              ' que ya tengas escrito.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
          const Divider(height: 1),
          Flexible(child: _buildLista(context)),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    if (periodos.isEmpty && years.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'No hay otro periodo ni otro año de donde traer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        if (periodos.isNotEmpty) ...[
          _rotulo('De otro periodo de este año'),
          ...periodos.map((periodo) {
            final nombre = 'Periodo ${periodo.numero}';

            return ListTile(
              dense: true,
              title: Text(nombre, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.pop(
                context,
                OrigenDelPlan.periodo(periodo.id, comoSeLlama: nombre),
              ),
            );
          }),
        ],
        if (years.isNotEmpty) ...[
          _rotulo('Del mismo periodo de otro año'),
          ...years.map((year) {
            return ListTile(
              dense: true,
              title: Text(year.year, style: const TextStyle(fontSize: 14)),
              // Lo que se trae es el periodo del **mismo número**, no el que
              // se esté mirando allí. Decirlo aquí evita la pregunta de «¿de
              // qué periodo de 2025?», que es la primera que sale.
              subtitle: const Text(
                'el periodo del mismo número',
                style: TextStyle(fontSize: 11.5),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.pop(
                context,
                OrigenDelPlan.year(year.id, comoSeLlama: year.year),
              ),
            );
          }),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.black45,
          ),
        ),
      );
}
