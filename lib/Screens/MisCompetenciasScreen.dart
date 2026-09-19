import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/CompetenciasApi.dart';
import 'package:myvc_flutter/Http/EscalasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/ColegioModel.dart';
import 'package:myvc_flutter/Models/CompetenciaModel.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/ClasesDelDocente.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/BarraPlegable.dart';
import 'package:myvc_flutter/Widgets/HojaCompetencia.dart';
import 'package:myvc_flutter/Widgets/HojaTraerPlan.dart';
import 'package:myvc_flutter/Widgets/SelectorDocente.dart';
import 'package:myvc_flutter/constantes.dart';

/// Las competencias que el docente escribe para sus clases.
///
/// ## Por qué esta pantalla se agrupa por (materia, grado) y no por asignatura
///
/// Es **la decisión que ordena todo lo demás**, y va contra la forma que tienen
/// las otras dos pantallas del docente ([NotasScreen] y [UnidadesScreen]), que
/// listan asignaturas.
///
/// El plan de área se escribe por **(materia, grado, periodo)**: un docente con
/// «6.ºA Matemáticas» y «6.ºB Matemáticas» tiene dos asignaturas y **una sola
/// fila** de competencias. Si esta pantalla listara asignaturas, vería las
/// mismas cuatro competencias dos veces, editaría una y la otra cambiaría sola
/// — que no es un fallo que se explique después, es el informe de error que
/// llega el primer mes.
///
/// Así que las asignaturas se colapsan en sus pares y **la tarjeta dice a qué
/// grupos alcanza**. En `simonbolivar` ese renglón no sale nunca —trece grupos y
/// trece grados, uno por grado—, o sea que **el colegio con el que se prueba es
/// justo el que no enseña el caso**. Está escrito aquí porque quien lo pruebe va
/// a concluir que el renglón sobra.
///
/// ## Lo que esta pantalla NO hace, y no es por falta de tiempo
///
///  - **No reordena.** El orden viene hecho del servidor y **las dos rutas usan
///    expresiones distintas que agrupan igual**: `GET desempenos` ordena por
///    `materia_id, grado_id, periodo_id, orden, id` y el boletín por
///    `grado_id IS NOT NULL, orden, id`. Coinciden en lo que importa porque
///    **MySQL pone los `NULL` delante en un `ASC`**, así que las del colegio
///    salen arriba en los dos sitios y el papel se lee como la pantalla. Un
///    cliente que reordene rompe justo eso. Y `PUT desempenos/orden` reordena
///    **el conjunto entero**, que incluye filas que el docente no puede
///    escribir, así que un arrastre sería un 403 en la pantalla más delicada.
///  - **No adopta del Ministerio.** Son 43 peticiones en fila desde el cliente y
///    es trabajo de coordinación: va en la web.
///  - **No edita las filas de «todos los grados».** Ver [_buildBloqueDelColegio].
///
/// ## Tres peticiones al abrir, y por qué el catálogo se pide entero
///
/// `listasignaturas` (las clases), `GET desempenos?periodo_id=` (el catálogo del
/// periodo) y `GET escalas` (para el previo de impresión).
///
/// El catálogo se pide **del periodo entero y se filtra aquí**, pudiendo pedirse
/// por (materia, grado): serían cinco o seis peticiones en vez de una. Se elige
/// una porque **lo que escasea en este servidor es CPU, no ancho de banda** —un
/// hosting compartido de un núcleo, y una notificación abre cientos de teléfonos
/// en el mismo medio minuto—. Si algún día el catálogo de un colegio pesa de
/// verdad, la salida está escrita en `docs/backend-pendiente.md` §6 y es un
/// `?mias=1`, no seis peticiones.
class MisCompetenciasScreen extends StatefulWidget {
  const MisCompetenciasScreen({super.key, this.servidor});

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  ///
  /// La misma costura que [LibroAsignaturaScreen], y por el mismo motivo: sin
  /// ella, mirar cómo queda esta pantalla —con dos grupos en un grado, con el
  /// periodo cerrado, sin los ids que el backend aún no manda— obligaría a
  /// entrar con las credenciales de un colegio de verdad y a leer datos de
  /// alumnos reales para decidir un ancho.
  final Server? servidor;

  @override
  State<MisCompetenciasScreen> createState() => _MisCompetenciasScreenState();
}

class _MisCompetenciasScreenState extends State<MisCompetenciasScreen> {
  late final Server server = widget.servidor ?? Server();
  final _drawerController = ZoomDrawerController();

  bool get esDocente => AuthService.user.esDocente;

  /// Solo para quien no es docente: de qué docente son las clases.
  List<DocenteModel> docentes = [];
  DocenteModel? docenteElegido;

  ClasesYRestos clases = const ClasesYRestos(clases: [], sinResolver: 0);
  List<Competencia> catalogo = const [];
  List<EscalaDeValoracion> escalas = const [];

  /// La clase abierta. Una sola, como en [UnidadesScreen]: son listas largas y
  /// con todas abiertas no se encuentra nada.
  String? abierta;

  /// Las clases cuyo catálogo se está escribiendo, por clave.
  final Set<String> ocupadas = {};

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      if (!esDocente && docentes.isEmpty) {
        docentes = await traerDocentesDelColegio(server);
        docenteElegido ??= docentes.isEmpty ? null : docentes.first;
      }

      final profesorId = esDocente ? null : docenteElegido?.profesorId;

      if (!esDocente && profesorId == null) {
        setState(() {
          clases = const ClasesYRestos(clases: [], sinResolver: 0);
          cargando = false;
        });
        return;
      }

      final asignaturas = await traerAsignaturasConUnidades(
        server,
        profesorId: profesorId,
      );

      final periodoId = ContextoAcademico.instancia.periodoId;

      final nuevas = clasesDelDocente(
        asignaturas.map((a) => a.asignatura).toList(),
      );

      final traidas = await traerCompetencias(server, periodoId: periodoId);
      final bandas = await traerEscalasDelAnio(server);

      if (!mounted) return;

      setState(() {
        clases = nuevas;
        catalogo = traidas;
        escalas = bandas;
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

  /// Las del catálogo que le tocan a esta clase.
  ///
  /// Las de su grado **y las de «todos los grados»** (D25). No se ordena nada:
  /// el servidor ya las manda agrupadas como se imprimen, y filtrar conserva ese
  /// orden.
  ///
  /// **Y por eso el catálogo se pide sin `grado_id`.** Medido en
  /// `DesempenosController::getPlantilla`: pedirlo **con** un grado devuelve
  /// sólo las de ese grado, **no** las de «todos los grados» —el filtro es
  /// `d.grado_id <=> ?`, o sea igualdad exacta—. Una tarjeta pedida por su par
  /// necesitaría **dos** llamadas y perdería la mitad del bloque de arriba si
  /// alguien hiciera sólo una.
  List<Competencia> _deLaClase(ClaseDelDocente clase) {
    return catalogo
        .where((c) =>
            c.materiaId == clase.materiaId &&
            (c.gradoId == null || c.gradoId == clase.gradoId))
        .toList();
  }

  /// Las marcas que este colegio ya escribió, para sugerirlas y no inventarlas.
  List<String> get _marcasUsadas {
    final vistas = <String>{};
    for (final c in catalogo) {
      final marca = (c.tipo ?? '').trim();
      if (marca.isNotEmpty) vistas.add(marca);
    }
    return vistas.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final config = ContextoAcademico.instancia.config;

    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: BarraPlegable(
          // El rótulo es el del colegio y no una palabra de la app: unos las
          // llaman «Competencias» y otros «Desempeños». Ver
          // `ConfiguracionColegio.competencias`.
          titulo: config.competencias,
          alAbrirMenu: () => _drawerController.toggle!(),
          alCambiarContexto: _arrancar,
          child: _buildCuerpo(),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _buildAviso(
        icono: Icons.cloud_off,
        titulo: 'No se pudieron traer las competencias.',
        detalle: error,
        accion: _arrancar,
      );
    }

    final lista = <Widget>[];

    if (!esDocente) {
      lista.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: CampoDocente(
            docentes: docentes,
            elegido: docenteElegido,
            alElegir: (docente) {
              setState(() => docenteElegido = docente);
              _arrancar();
            },
          ),
        ),
      );
    }

    if (clases.clases.isEmpty) {
      lista.add(_buildSinClases());
      return ListView(children: lista);
    }

    if (clases.sinResolver > 0) lista.add(_buildParcial());

    if (_hayEspacioParaLosDos(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...lista,
          Expanded(child: _buildMaestroDetalle()),
        ],
      );
    }

    lista.addAll(clases.clases.map(_buildTarjeta));
    lista.add(const SizedBox(height: 24));

    return RefreshIndicator(
      onRefresh: _arrancar,
      child: ListView(children: lista),
    );
  }

  bool _hayEspacioParaLosDos(BuildContext context) =>
      MediaQuery.of(context).size.width >= Anchos.maestroDetalle;

  /// La lista de clases a un lado y el catálogo de la elegida al otro.
  ///
  /// Mismo patrón que el libro de notas en tablet: lo que crece con la pantalla
  /// es el detalle, que es donde se escribe.
  Widget _buildMaestroDetalle() {
    // **Con espacio para las dos, siempre hay una elegida.** En el teléfono
    // `abierta` en null significa «todas plegadas», que es un estado útil; aquí
    // significaría media pantalla en blanco pidiendo un toque que no hace falta,
    // porque la lista ya está a la vista. Se elige la primera y no se escribe
    // `abierta`: escribirla desde `build` sería un `setState` en mitad del
    // pintado, y además dejaría el teléfono con una tarjeta abierta al girar.
    final elegida = clases.clases.firstWhere(
      (c) => _clave(c) == abierta,
      orElse: () => clases.clases.first,
    );
    final claveElegida = _clave(elegida);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: Anchos.maestro,
          child: ListView(
            children: clases.clases
                .map((c) => _buildFilaDeLista(c, claveElegida))
                .toList(),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: _buildDetalle(elegida),
          ),
        ),
      ],
    );
  }

  Widget _buildFilaDeLista(ClaseDelDocente clase, String claveElegida) {
    final cuantas = _deLaClase(clase).length;
    final elegida = _clave(clase) == claveElegida;

    return ListTile(
      selected: elegida,
      selectedTileColor: kPrimaryColor.withValues(alpha: 0.08),
      title: Text(
        _tituloDe(clase),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: _buildAlcance(clase, cuantas),
      onTap: () => setState(() => abierta = _clave(clase)),
    );
  }

  Widget _buildTarjeta(ClaseDelDocente clase) {
    final abiertaEsta = _clave(clase) == abierta;
    final cuantas = _deLaClase(clase).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(
              () => abierta = abiertaEsta ? null : _clave(clase),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tituloDe(clase),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildAlcance(clase, cuantas),
                      ],
                    ),
                  ),
                  Icon(
                    abiertaEsta ? Icons.expand_less : Icons.expand_more,
                    color: Colors.black38,
                  ),
                ],
              ),
            ),
          ),
          if (abiertaEsta)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildDetalle(clase),
              ),
            ),
        ],
      ),
    );
  }

  /// El renglón de debajo del título: a qué grupos alcanza y cuántas hay.
  ///
  /// **Los grupos se nombran cuando son más de uno** —con uno solo, decir «vale
  /// para 6.ºA» es ruido: el docente ya sabe cuál es— **y también cuando no se
  /// sabe el nombre del grado**, que hoy es siempre.
  ///
  /// Eso segundo no es una precaución: `Profesor::asignaturas` **no trae el
  /// nombre del grado** —junta `grados` sólo por `nivel_educativo_id`—, así que
  /// [ClaseDelDocente.grado] llega null y el título de la tarjeta se queda en
  /// «MATEMÁTICAS» a secas. Un docente que dé Matemáticas en 6.º y en 7.º vería
  /// **dos tarjetas idénticas**. Los grupos sí vienen, y son justo lo que las
  /// distingue.
  ///
  /// Se arregla del todo el día que el nombre del grado llegue —`fe95da8` añade
  /// el id, no el nombre—; mientras tanto esto no es un apaño, es la
  /// información que el docente necesita para saber cuál es cuál.
  Widget _buildAlcance(ClaseDelDocente clase, int cuantas) {
    final partes = <String>[];
    final sinNombreDeGrado = (clase.grado ?? '').trim().isEmpty;

    if (clase.gruposAbrev.length > 1 ||
        (sinNombreDeGrado && clase.gruposAbrev.isNotEmpty)) {
      partes.add('vale para ${_enumerar(clase.gruposAbrev)}');
    }

    partes.add(cuantas == 0
        ? 'sin escribir todavía'
        : '$cuantas ${cuantas == 1 ? 'escrita' : 'escritas'}');

    return Text(
      partes.join(' · '),
      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
    );
  }

  List<Widget> _buildDetalle(ClaseDelDocente clase) {
    final config = ContextoAcademico.instancia.config;
    final permiso = puedeEscribirEn(clase, config: config);
    final todas = _deLaClase(clase);

    final delColegio = todas.where((c) => c.esDelColegio).toList();
    final delGrado = todas.where((c) => !c.esDelColegio).toList();

    return [
      if (delColegio.isNotEmpty) _buildBloqueDelColegio(delColegio),
      _buildBloqueDelGrado(clase, delGrado, permiso),
      if (!permiso.puede) _buildCandado(permiso),
    ];
  }

  /// Las filas de «todos los grados», que son del colegio.
  ///
  /// **El candado es una cabecera y no un icono por fila**, y no es estética.
  /// Una fila con `grado_id NULL` alcanza a grados que este docente no da, así
  /// que dejársela editar sería darle por la puerta de atrás el alcance que el
  /// permiso le niega por la de delante — y el servidor contesta 403. Pintarlas
  /// mezcladas con un candadito invita a pulsarlas con el pulgar y a recibir un
  /// error que parece un fallo del sistema. Agrupadas bajo su rótulo, **el
  /// candado se explica una vez** y ninguna fila de este bloque lleva botones.
  ///
  /// Van arriba porque el servidor las manda primero, y eso también es a
  /// propósito: es el orden en que salen impresas.
  Widget _buildBloqueDelColegio(List<Competencia> filas) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 15, color: Colors.black38),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Del colegio · para todos los grados',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...filas.map((c) => _buildFila(c, editable: false)),
        ],
      ),
    );
  }

  Widget _buildBloqueDelGrado(
    ClaseDelDocente clase,
    List<Competencia> filas,
    PermisoDeEscritura permiso,
  ) {
    final ocupada = ocupadas.contains(_clave(clase));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filas.isNotEmpty) ...[
          Text(
            'De ${clase.grado ?? 'este grado'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          ...filas.map((c) => _buildFila(c, editable: permiso.puede)),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Nadie ha escrito competencias para esta clase en este periodo.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
        // En un `Wrap` y apretados: dos botones con el relleno normal de
        // Material no caben en la tarjeta de un teléfono. Es la misma medida
        // que se pagó en `FrasesDelGrupoScreen`, donde se desbordaba por dos
        // píxeles a 420 dp.
        if (permiso.puede)
          Wrap(
            children: [
              TextButton.icon(
                style: _apretado,
                onPressed: ocupada ? null : () => _agregar(clase),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
              TextButton.icon(
                style: _apretado,
                onPressed: ocupada ? null : () => _traerDeOtro(clase),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Traer de…'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFila(Competencia competencia, {required bool editable}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  competencia.definicion,
                  style: const TextStyle(fontSize: 13.5, height: 1.3),
                ),
                // La marca sólo si la tiene. Un «—» donde no hay nada es ruido,
                // y además sugeriría que falta algo: `tipo` es opcional y lo
                // normal es que esté vacía.
                if ((competencia.tipo ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      competencia.tipo!.trim(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (editable) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Corregir',
              onPressed: () => _corregir(competencia),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Quitar',
              onPressed: () => _quitar(competencia),
            ),
          ],
        ],
      ),
    );
  }

  /// Por qué no se puede escribir, dicho antes de pulsar nada.
  ///
  /// Se pinta la lista y **no se pintan los botones**, con el motivo encima.
  /// Pintar el botón y dejar que el 403 lo explique es lo que hace que un
  /// candado parezca una avería.
  Widget _buildCandado(PermisoDeEscritura permiso) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 15, color: Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              permiso.explicacion,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  /// Cuando el docente tiene asignaturas pero no se pudieron resolver.
  ///
  /// **Es el caso de HOY en todos los colegios**, y por eso no es una lista
  /// vacía: `asignaturas/listasignaturas` todavía no manda `materia_id` ni
  /// `grado_id` —están escritas en el backend y sin desplegar—, y sin ellos no
  /// hay par al que dirigir el plan de área. Una lista vacía y «tu colegio aún
  /// no tiene esto» se leen igual y no son lo mismo.
  Widget _buildSinClases() {
    if (clases.sinResolver > 0) {
      return _buildAviso(
        icono: Icons.hourglass_empty,
        titulo: 'Esto todavía no está en tu colegio.',
        detalle: 'Tus ${clases.sinResolver} asignaturas están, pero el servidor'
            ' aún no manda con qué materia y qué grado se corresponden. En'
            ' cuanto tu colegio se actualice, aparecerán aquí.',
      );
    }

    return _buildAviso(
      icono: Icons.menu_book_outlined,
      titulo: 'No hay clases que mostrar.',
      detalle: esDocente
          ? 'No tienes asignaturas en este año.'
          : 'Ese docente no tiene asignaturas en este año.',
    );
  }

  /// Algunas clases salieron y otras no. Se enseñan las que sí y se dice cuántas
  /// faltan: callarlo convertiría una limitación nuestra en «me faltan clases».
  Widget _buildParcial() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB26A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${clases.sinResolver} de tus asignaturas no se pudieron'
              ' identificar y no salen aquí.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A4B00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAviso({
    required IconData icono,
    required String titulo,
    String? detalle,
    Future<void> Function()? accion,
  }) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 40, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ],
          if (accion != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => accion(),
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }

  static final ButtonStyle _apretado = TextButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 10),
  );

  // ---- escribir ----------------------------------------------------------

  /// Trae a esta clase el plan de otro periodo o de otro año.
  ///
  /// **El destino es siempre el periodo de la barra**, que es lo que hace que
  /// la bandera con la que se pintó el botón —`permiso`, calculado sobre
  /// `profes_pueden_editar_notas` de la sesión— sea la misma que el backend va
  /// a comprobar. Ver el docblock de [copiarCompetencias].
  ///
  /// La respuesta trae contadores y **no las filas nuevas**, así que después
  /// se relee el catálogo. Es una petición, y sólo cuando algo entró: un
  /// «ya las tenías todas» no cambia nada que repintar.
  Future<void> _traerDeOtro(ClaseDelDocente clase) async {
    final periodoId = ContextoAcademico.instancia.periodoId;
    if (periodoId == null) return;

    await _asegurarYears();
    if (!mounted) return;

    final origen = await pedirOrigenDelPlan(
      context,
      titulo: _tituloDe(clase),
      periodos: ContextoAcademico.instancia.periodosDelYear,
      periodoDestino: periodoId,
      years: ContextoAcademico.instancia.years,
      yearDestino: ContextoAcademico.instancia.yearId,
    );

    if (origen == null || !mounted) return;

    setState(() => ocupadas.add(_clave(clase)));

    final resultado = await copiarCompetencias(
      server,
      materiaId: clase.materiaId,
      gradoId: clase.gradoId,
      periodoId: periodoId,
      desdePeriodoId: origen.periodoId,
      desdeYearId: origen.yearId,
    );

    if (!mounted) return;
    setState(() => ocupadas.remove(_clave(clase)));

    if (!resultado.entro) {
      _avisar(resultado.motivo!);
      return;
    }

    final copia = resultado.copia ?? const CopiaDelPlan();
    _avisar(_comoFueLaCopia(copia, origen.comoSeLlama));

    if (copia.copiados > 0) await _recargarCatalogo();
  }

  /// Qué pasó al copiar, con los tres desenlaces dichos distinto.
  ///
  /// **Los tres son un 200 y dos de ellos traen `copiados: 0`**, que es
  /// exactamente lo que no se puede aplanar en «no se copió nada»: «ahí no
  /// había nada» manda a mirar si se eligió mal el periodo, y «ya las tenías»
  /// dice que el trabajo está hecho. El backend se tomó el trabajo de
  /// separarlos; la pantalla no los vuelve a juntar.
  String _comoFueLaCopia(CopiaDelPlan copia, String origen) {
    if (copia.origenVacio) return 'En $origen no hay nada escrito.';

    if (copia.copiados == 0) {
      return copia.saltadosPorDuplicado == 1
          ? 'Ya la tenías. No se añadió ninguna.'
          : 'Ya tenías las ${copia.saltadosPorDuplicado}.'
              ' No se añadió ninguna.';
    }

    final traidas = copia.copiados == 1
        ? 'Se trajo 1 de $origen'
        : 'Se trajeron ${copia.copiados} de $origen';

    return copia.saltadosPorDuplicado == 0
        ? '$traidas.'
        : '$traidas · ${copia.saltadosPorDuplicado} ya estaban.';
  }

  /// Los años con sus periodos, para la hoja de traer.
  ///
  /// No se piden al abrir la pantalla: la mayoría de las visitas no van a
  /// copiar nada, y `GET /years` es una petición que no hace falta pagar por
  /// si acaso. Si falla, la hoja sale diciendo que no hay de dónde traer, que
  /// es cierto desde el punto de vista de quien mira.
  Future<void> _asegurarYears() async {
    try {
      await ContextoAcademico.instancia.cargarYears(server);
    } catch (_) {
      // Sin listas, y la hoja lo dice.
    }
  }

  /// Relee el catálogo del periodo, sin volver a pedir clases ni escalas.
  Future<void> _recargarCatalogo() async {
    try {
      final traidas = await traerCompetencias(
        server,
        periodoId: ContextoAcademico.instancia.periodoId,
      );
      if (!mounted) return;
      setState(() => catalogo = traidas);
    } catch (err) {
      _avisar('Se copió, pero no se pudo releer la lista: $err');
    }
  }

  Future<void> _agregar(ClaseDelDocente clase) async {
    final escrita = await pedirCompetencia(
      context,
      titulo: _tituloDe(clase),
      escalas: escalas,
      marcasUsadas: _marcasUsadas,
    );

    if (escrita == null || !mounted) return;

    final periodoId = ContextoAcademico.instancia.periodoId;
    if (periodoId == null) return;

    setState(() => ocupadas.add(_clave(clase)));

    final resultado = await crearCompetencia(
      server,
      materiaId: clase.materiaId,
      gradoId: clase.gradoId,
      periodoId: periodoId,
      definicion: escrita.definicion,
      tipo: escrita.tipo,
    );

    if (!mounted) return;
    setState(() => ocupadas.remove(_clave(clase)));

    if (!resultado.entro) {
      _avisar(resultado.motivo!);
      return;
    }

    final creada = resultado.competencia;
    if (creada == null) {
      // El servidor dijo que sí y no devolvió la fila. Se recarga en vez de
      // inventarse un id: una fila de mentira en la lista se puede editar, y
      // ese `PUT` iría a ninguna parte.
      await _arrancar();
      return;
    }

    setState(() => catalogo = [...catalogo, creada]);
  }

  Future<void> _corregir(Competencia competencia) async {
    final escrita = await pedirCompetencia(
      context,
      titulo: 'Corregir',
      escalas: escalas,
      definicionInicial: competencia.definicion,
      tipoInicial: competencia.tipo,
      marcasUsadas: _marcasUsadas,
    );

    if (escrita == null || !mounted) return;

    final resultado = await editarCompetencia(
      server,
      id: competencia.id,
      definicion: escrita.definicion,
      tipo: escrita.tipo,
    );

    if (!mounted) return;

    if (!resultado.entro) {
      _avisar(resultado.motivo!);
      return;
    }

    setState(() {
      catalogo = catalogo
          .map((c) => c.id == competencia.id
              ? (resultado.competencia ??
                  c.con(definicion: escrita.definicion, tipo: escrita.tipo))
              : c)
          .toList();
    });
  }

  Future<void> _quitar(Competencia competencia) async {
    final confirmado = await _confirmarBorrado(competencia);
    if (confirmado != true || !mounted) return;

    final motivo = await borrarCompetencia(server, id: competencia.id);

    if (!mounted) return;

    if (motivo != null) {
      _avisar(motivo);
      return;
    }

    setState(() {
      catalogo = catalogo.where((c) => c.id != competencia.id).toList();
    });
  }

  /// La confirmación nombra **a quién más le afecta**, que es lo que no es
  /// obvio: estas filas las comparte el colegio y el otro docente del mismo
  /// grado, así que borrar aquí borra allí.
  Future<bool?> _confirmarBorrado(Competencia competencia) {
    return showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Quitar esta competencia?'),
        content: Text(
          '«${competencia.definicion}»\n\n'
          'Se quita para todos los grupos de este grado y también la deja de'
          ' ver coordinación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // ---- ayudas ------------------------------------------------------------

  String _clave(ClaseDelDocente clase) =>
      '${clase.materiaId}|${clase.gradoId ?? ''}';

  String _tituloDe(ClaseDelDocente clase) {
    final materia = (clase.aliasMateria ?? '').trim().isNotEmpty
        ? clase.aliasMateria!.trim()
        : clase.materia;
    final grado = (clase.grado ?? '').trim();

    return grado.isEmpty ? materia : '$materia · $grado';
  }

  /// «6.ºA y 6.ºB», «6.ºA, 6.ºB y 6.ºC».
  String _enumerar(List<String> nombres) {
    if (nombres.length < 2) return nombres.join();
    final todos = [...nombres];
    final ultimo = todos.removeLast();
    return '${todos.join(', ')} y $ultimo';
  }
}
