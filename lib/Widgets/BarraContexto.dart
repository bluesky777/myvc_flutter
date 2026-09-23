import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// El año y el periodo, a la derecha de la barra de arriba.
///
/// Se monta en `actions:` de la barra, así:
///
///     SliverAppBar(
///       title: Text('Disciplina'),
///       actions: [BarraContexto(alCambiar: _arrancar), ...],
///     )
///
/// **Tuvo franja propia y la perdió, y merece la pena saber por qué las dos
/// veces.** Nació de intentar meter el nombre de la pantalla y el periodo en un
/// título de dos líneas: el periodo quedaba en letra pequeña, y es el dato que
/// más se mira y el único que se toca. Así que se le dio una franja debajo, a
/// tamaño de leerse y ocupando el ancho, para que se viera que es un control y
/// no un rótulo.
///
/// El precio de aquello era **dos barras**: una con el nombre de la pantalla y
/// otra con el periodo, apiladas, comiéndose la parte de arriba de cada
/// pantalla. Se plegaba al desplazar, pero el primer golpe de vista —que es el
/// que decide si una app se siente ligera— eran siempre dos franjas para dos
/// datos cortos.
///
/// Ahora va **en la misma fila, a la derecha**. Sigue siendo un control y se
/// sigue viendo que lo es: lleva su icono, su flecha de desplegar y su efecto
/// al tocarlo. Lo que se perdió es el tamaño, y a cambio se ganó una franja
/// entera de pantalla. El texto va abreviado —«2026 · Per 4»— porque en una
/// fila compartida «Periodo» gasta su sitio contra el título; ver
/// [ContextoAcademico.tituloCorto].
class BarraContexto extends StatelessWidget {
  const BarraContexto({super.key, this.alCambiar});

  final VoidCallback? alCambiar;

  @override
  Widget build(BuildContext context) {
    final contexto = ContextoAcademico.instancia;

    return ListenableBuilder(
      listenable: contexto,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Material(
            // Transparente para quedarse con el color de la barra: pintarle un
            // fondo propio la separaría en dos bloques de colores distintos.
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  abrirSelectorDeContexto(context, alCambiar: alCambiar),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_note_outlined, size: 18),
                    const SizedBox(width: 6),
                    // Encogible: en una pantalla estrecha el que cede es el
                    // título, pero si aun así no cabe, esto se recorta antes de
                    // desbordar la fila.
                    Flexible(
                      child: Text(
                        contexto.tituloCorto,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Abre el cuadro donde se cambia de año y de periodo.
///
/// Suelto y no dentro de un widget porque lo abren los dos: el título y la
/// franja.
Future<void> abrirSelectorDeContexto(
  BuildContext context, {
  VoidCallback? alCambiar,
}) async {
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

  /// Cambiar el año se guarda al momento, no al elegir después un periodo.
  ///
  /// Era el fallo de la primera versión: el desplegable del año solo filtraba
  /// qué periodos se veían, así que quien elegía 2025 y cerraba el cuadro se
  /// quedaba igual que estaba, sin que nada se lo dijera. El front web tiene
  /// los dos menús y cada uno guarda al pulsarlo; aquí, lo mismo.
  Future<void> _elegirYear(YearModel year) async {
    if (guardando || year.id == contexto.yearId) {
      setState(() => yearMostrado = year);
      return;
    }

    setState(() {
      guardando = true;
      yearMostrado = year;
    });

    await _guardar(() => contexto.cambiarYear(server, year), cerrar: false);
  }

  Future<void> _elegirPeriodo(PeriodoModel periodo) async {
    if (guardando) return;

    setState(() => guardando = true);
    await _guardar(() => contexto.cambiarPeriodo(server, periodo));
  }

  Future<void> _guardar(Future<String?> Function() tarea,
      {bool cerrar = true}) async {
    final problema = await tarea();
    if (!mounted) return;

    if (problema != null) {
      setState(() {
        guardando = false;
        error = problema;
      });
      return;
    }

    // Al cambiar de año el backend elige el periodo por su cuenta, así que el
    // cuadro se queda abierto enseñando en cuál quedó: cerrarlo dejaría al
    // usuario adivinando.
    if (!cerrar) {
      setState(() {
        guardando = false;
        error = null;
        yearMostrado = contexto.years.firstWhere(
          (y) => y.id == contexto.yearId,
          orElse: () => yearMostrado ?? contexto.years.first,
        );
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
              'Se guarda en el momento, y manda en todas las pantallas.',
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
            : (nuevo) {
                if (nuevo != null) _elegirYear(nuevo);
              },
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
      onSelected: guardando ? null : (_) => _elegirPeriodo(periodo),
    );
  }
}
