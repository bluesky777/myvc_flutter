import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// El año y el periodo en su propia franja, debajo del título de la pantalla.
///
/// Se monta en el hueco `bottom:` de la barra, así:
///
///     AppBar(
///       title: Text('Disciplina'),
///       bottom: BarraContexto(alCambiar: _arrancar),
///     )
///
/// Nació de intentar lo contrario: meter el nombre de la pantalla y el periodo
/// en un título de dos líneas dejaba el periodo en letra pequeña, y es el dato
/// que más se mira y el único que se toca. Aquí va a tamaño de leerse,
/// ocupando el ancho, y se ve que es un control y no un rótulo.
///
/// Centrado, y no pegado a la izquierda como el título de encima: así se lee
/// como una cosa aparte y no como una segunda línea del título. Es el mismo
/// control en las tres pantallas del menú y conviene que esté siempre en el
/// mismo sitio, se llame la pantalla «Inicio» o «Disciplina».
class BarraContexto extends StatelessWidget implements PreferredSizeWidget {
  const BarraContexto({super.key, this.alCambiar});

  final VoidCallback? alCambiar;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final contexto = ContextoAcademico.instancia;

    return ListenableBuilder(
      listenable: contexto,
      builder: (context, _) {
        return SizedBox(
          height: preferredSize.height,
          width: double.infinity,
          child: Material(
            // Transparente para quedarse con el color de la barra: pintarle un
            // fondo propio la separaría en dos bloques de colores distintos.
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  abrirSelectorDeContexto(context, alCambiar: alCambiar),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_note_outlined, size: 19),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        contexto.titulo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
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
