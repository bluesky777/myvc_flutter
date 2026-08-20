import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// El año y el periodo, en la barra de arriba y tocables.
///
/// Va donde iría el título de la pantalla porque no es un adorno: es el filtro
/// del que cuelga todo lo que se ve debajo. Que se pueda tocar lo dice la
/// flechita; sin ella parecería un rótulo más.
class TituloContexto extends StatelessWidget {
  const TituloContexto({super.key, this.alCambiar});

  /// Qué hacer cuando el usuario cambia de periodo: normalmente, recargar.
  final VoidCallback? alCambiar;

  @override
  Widget build(BuildContext context) {
    final contexto = ContextoAcademico.instancia;

    return ListenableBuilder(
      listenable: contexto,
      builder: (context, _) {
        return InkWell(
          onTap: () => _abrirSelector(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    contexto.titulo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirSelector(BuildContext context) async {
    final cambiado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _SelectorContexto(),
    );

    if (cambiado == true) alCambiar?.call();
  }
}

class _SelectorContexto extends StatefulWidget {
  const _SelectorContexto();

  @override
  State<_SelectorContexto> createState() => _SelectorContextoState();
}

class _SelectorContextoState extends State<_SelectorContexto> {
  final Server server = Server();
  final contexto = ContextoAcademico.instancia;

  YearModel? yearMostrado;
  bool cargando = true;
  bool guardando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      await contexto.cargarYears(server);
      if (!mounted) return;

      setState(() {
        yearMostrado = contexto.years.firstWhere(
          (y) => y.id == contexto.yearId,
          orElse: () => contexto.years.first,
        );
        cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        error = '$err';
        cargando = false;
      });
    }
  }

  Future<void> _elegir(PeriodoModel periodo) async {
    if (guardando || yearMostrado == null) return;

    setState(() => guardando = true);

    final problema = await contexto.cambiarA(
      server,
      yearNuevo: yearMostrado!,
      periodoNuevo: periodo,
    );

    if (!mounted) return;

    if (problema != null) {
      setState(() {
        guardando = false;
        error = problema;
      });
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Año y periodo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lo que se elija aquí manda en todas las pantallas.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 18),
            ..._cuerpo(),
          ],
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (error != null && contexto.years.isEmpty) {
      return [
        Text(error!),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ];
    }

    return [
      DropdownButtonFormField<YearModel>(
        initialValue: yearMostrado,
        decoration: const InputDecoration(
          labelText: 'Año',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: contexto.years
            .map((y) => DropdownMenuItem(
                  value: y,
                  child: Text(y.actual ? '${y.year} (actual)' : y.year),
                ))
            .toList(),
        onChanged: guardando
            ? null
            : (nuevo) => setState(() => yearMostrado = nuevo),
      ),
      const SizedBox(height: 16),
      // Los periodos, en fila: son tres o cuatro, y un desplegable dentro de
      // otro desplegable se hace pesado para elegir entre cuatro números.
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (yearMostrado?.periodos ?? [])
            .map((p) => _botonPeriodo(p))
            .toList(),
      ),
      if (error != null) ...[
        const SizedBox(height: 14),
        Text(error!, style: const TextStyle(color: Colors.redAccent)),
      ],
      if (guardando) ...[
        const SizedBox(height: 16),
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    ];
  }

  Widget _botonPeriodo(PeriodoModel periodo) {
    final esElActual = periodo.id == contexto.periodoId;

    return ChoiceChip(
      label: Text('Periodo ${periodo.numero}'),
      selected: esElActual,
      onSelected: guardando ? null : (_) => _elegir(periodo),
    );
  }
}
