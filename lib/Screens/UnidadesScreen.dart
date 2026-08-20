import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Http/UnidadesApi.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/ControlOcupado.dart';
import 'package:myvc_flutter/Widgets/SelectorDocente.dart';
import 'package:myvc_flutter/Widgets/TituloContexto.dart';
import 'package:myvc_flutter/constantes.dart';

/// Las unidades con las que un docente evalúa cada asignatura en el periodo.
///
/// Una asignatura se reparte en unidades y cada unidad en subunidades; las
/// notas se ponen en las subunidades y de ahí sube todo, ponderado por los
/// porcentajes. Por eso lo que esta pantalla vigila —y enseña en rojo— es que
/// las unidades sumen 100 y que las subunidades de cada unidad sumen 100:
/// mientras no cuadren, la definitiva que ve el alumno está mal repartida.
///
/// Todo es del periodo de la barra de arriba. No hay selector propio: el
/// backend no recibe el periodo en ninguna de estas llamadas, lo lee de la
/// ficha del usuario, así que un selector aquí sería un segundo sitio para lo
/// mismo y una forma de que discrepen.
///
/// Se arma con los endpoints del editor del front web:
///
///   GET    /asignaturas/listasignaturas[/{profesor_id}]   las asignaturas y su resumen
///   GET    /unidades/de-asignatura-periodo/{a}/{p}        el detalle para editar
///   POST   /unidades            {asignatura_id, definicion, porcentaje}
///   PUT    /unidades/update/{id}
///   DELETE /unidades/destroy/{id}
///   POST   /subunidades         {unidad_id, definicion, porcentaje, nota_default}
///   PUT    /subunidades/update/{id}
///   DELETE /subunidades/destroy/{id}
///
/// El orden de unidades y subunidades no se cambia aquí: lo renumera el propio
/// backend al abrir el detalle, y reordenar a mano es otra pantalla.
class UnidadesScreen extends StatefulWidget {
  const UnidadesScreen({super.key});

  @override
  State<UnidadesScreen> createState() => _UnidadesScreenState();
}

class _UnidadesScreenState extends State<UnidadesScreen> {
  final Server server = Server();
  final _drawerController = ZoomDrawerController();

  bool get esDocente => AuthService.user.esDocente;

  /// Solo para quien no es docente: de qué docente son las asignaturas.
  List<DocenteModel> docentes = [];
  DocenteModel? docenteElegido;

  List<AsignaturaConUnidades> asignaturas = [];

  /// La asignatura abierta ahora mismo. Una sola: son listas largas y con
  /// todas abiertas no se encuentra nada.
  int? abierta;

  /// Las asignaturas cuyo detalle se está trayendo o guardando, por id.
  final Set<int> ocupadas = {};

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _arrancar() async {
    setState(() {
      cargando = true;
      error = null;
      asignaturas = [];
      abierta = null;
    });

    try {
      if (esDocente) {
        await _cargarAsignaturas(null);
      } else {
        await _cargarDocentes();
      }
      setState(() => cargando = false);
    } catch (err) {
      setState(() {
        cargando = false;
        error = '$err';
      });
    }
  }

  Future<void> _cargarDocentes() async {
    final traidos = await traerDocentesDelColegio(server);

    setState(() {
      docentes = traidos;
      if (traidos.isEmpty) {
        error = 'Este año no hay docentes con contrato.';
      }
    });

    // Si ya había uno elegido —se volvió de cambiar el periodo—, se le
    // recargan sus asignaturas en vez de dejar la pantalla en blanco.
    final elegido = docenteElegido;
    if (elegido != null) await _cargarAsignaturas(elegido.profesorId);
  }

  Future<void> _cargarAsignaturas(int? profesorId) async {
    final traidas =
        await traerAsignaturasConUnidades(server, profesorId: profesorId);

    setState(() {
      asignaturas = traidas;
      abierta = null;
      error = traidas.isEmpty
          ? 'No hay asignaturas a nombre de este docente en el año.'
          : null;
    });
  }

  /// Abre una asignatura y, la primera vez, se trae su detalle.
  ///
  /// El detalle hace falta para poder guardar: el resumen del listado no trae
  /// la nota por defecto de cada subunidad, y guardar sin ella la pondría en
  /// cero. Ver [traerUnidadesDe], que además siembra las unidades del año
  /// cuando la asignatura no tiene ninguna.
  Future<void> _abrir(AsignaturaConUnidades fila) async {
    final id = fila.asignatura.id;

    if (abierta == id) {
      setState(() => abierta = null);
      return;
    }

    setState(() => abierta = id);

    if (!fila.detallado) await _recargarDetalle(id);
  }

  Future<void> _recargarDetalle(int asignaturaId) async {
    final periodoId = ContextoAcademico.instancia.periodoId;
    if (periodoId == null) return;

    setState(() => ocupadas.add(asignaturaId));

    try {
      final fila = _fila(asignaturaId);
      if (fila == null) return;

      final unidades = await traerUnidadesDe(
        server,
        asignaturaId: asignaturaId,
        periodoId: periodoId,
        // Cuántas notas lleva cada subunidad solo lo dice el resumen. Se
        // arrastra al detalle para poder avisar antes de borrar.
        notasPorSubunidad: fila.notasPorSubunidad,
      );

      _reemplazar(asignaturaId, fila.con(unidades: unidades, detallado: true));
    } catch (err) {
      _avisar('No se pudieron traer las unidades: $err');
    } finally {
      setState(() => ocupadas.remove(asignaturaId));
    }
  }

  AsignaturaConUnidades? _fila(int asignaturaId) {
    for (final fila in asignaturas) {
      if (fila.asignatura.id == asignaturaId) return fila;
    }
    return null;
  }

  void _reemplazar(int asignaturaId, AsignaturaConUnidades nueva) {
    setState(() {
      asignaturas = asignaturas
          .map((f) => f.asignatura.id == asignaturaId ? nueva : f)
          .toList();
    });
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Lo común a todo lo que escribe: ocupa la asignatura, guarda, y relee.
  ///
  /// Se relee siempre en vez de retocar la lista en memoria porque el backend
  /// hace más de lo que se le pide: al guardar recalcula la definitiva de la
  /// asignatura, y al leer renumera el orden. Lo que quedó guardado lo dice él.
  Future<void> _escribir(
    int asignaturaId,
    Future<String?> Function() peticion,
  ) async {
    setState(() => ocupadas.add(asignaturaId));

    final fallo = await peticion();

    setState(() => ocupadas.remove(asignaturaId));

    if (fallo != null) {
      _avisar(fallo);
      return;
    }

    await _recargarDetalle(asignaturaId);
  }

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: _drawerController,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          // Las unidades son del periodo, no de la asignatura: cambiarlo arriba
          // cambia todo lo que se ve y lo que se guarda.
          title: Text('Unidades'),
          bottom: BarraContexto(alCambiar: _arrancar),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: _buildCuerpo(),
      ),
    );
  }

  Widget _buildCuerpo() {
    // La rueda tapa la pantalla entera solo en la primera carga. Al cambiar de
    // docente el campo tiene que seguir ahí: es desde donde se cambia, y
    // hacerlo desaparecer mientras carga deja al usuario sin saber a quién
    // acaba de pedir.
    final primeraCarga = cargando && (esDocente || docentes.isEmpty);
    if (primeraCarga) return Center(child: CircularProgressIndicator());

    if (ContextoAcademico.instancia.periodoId == null) {
      return _buildMensaje(
        'No hay un periodo elegido, y las unidades son de un periodo.'
        ' Elige uno en la barra de arriba.',
      );
    }

    // El aviso va dentro de la lista y no en lugar de ella: para quien no es
    // docente, el selector tiene que seguir estando. Si «este docente no tiene
    // asignaturas» tapara la pantalla entera, no quedaría forma de elegir otro.
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (!esDocente) _buildSelectorDocente(),
        if (cargando)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (asignaturas.isEmpty)
          _buildMensaje(
            error ??
                (esDocente
                    ? 'No tienes asignaturas en este año.'
                    : 'Elige un docente para ver sus unidades.'),
            conReintento: error != null,
          )
        else
          ...asignaturas.map(_buildAsignatura),
      ],
    );
  }

  /// Quien no es docente no tiene asignaturas propias: mira las de otro.
  ///
  /// Con el mismo campo de fotos que la asistencia a clases, y no con un
  /// dropdown: la lista es el colegio entero y a un docente se le reconoce
  /// antes por la cara que por un nombre recortado a la mitad.
  Widget _buildSelectorDocente() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CampoDocente(
        docentes: docentes,
        elegido: docenteElegido,
        titulo: 'Docentes del colegio',
        alElegir: _cambiarDocente,
      ),
    );
  }

  Future<void> _cambiarDocente(DocenteModel elegido) async {
    setState(() {
      docenteElegido = elegido;
      cargando = true;
    });

    try {
      await _cargarAsignaturas(elegido.profesorId);
    } catch (err) {
      _avisar('No se pudieron traer sus asignaturas: $err');
    }

    setState(() => cargando = false);
  }

  Widget _buildAsignatura(AsignaturaConUnidades fila) {
    final abiertaEsta = abierta == fila.asignatura.id;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: ControlOcupado(
        ocupado: ocupadas.contains(fila.asignatura.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCabeceraAsignatura(fila, abiertaEsta),
            if (abiertaEsta) ...[
              const Divider(height: 1),
              ..._buildUnidades(fila),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCabeceraAsignatura(
      AsignaturaConUnidades fila, bool abiertaEsta) {
    return InkWell(
      onTap: () => _abrir(fila),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fila.asignatura.materia,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fila.asignatura.nombreGrupo,
                    style: const TextStyle(
                        fontSize: 12.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
            _buildEstado(fila),
            Icon(abiertaEsta ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }

  /// Cómo va el reparto: el total de las unidades y lo que chirría.
  Widget _buildEstado(AsignaturaConUnidades fila) {
    if (fila.unidades.isEmpty) {
      return _pastilla('Sin unidades', Colors.orange.shade700);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fila.subunidadesIncorrectas)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: 'Alguna unidad no reparte 100 entre sus subunidades',
              child: Icon(Icons.warning_amber_rounded,
                  size: 18, color: Colors.orange.shade700),
            ),
          ),
        _pastilla(
          porcentajeEscrito(fila.porcentaje),
          fila.cuadra ? Colors.green.shade700 : Colors.redAccent,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  List<Widget> _buildUnidades(AsignaturaConUnidades fila) {
    final puedeGuardar = fila.detallado;

    return [
      if (fila.unidades.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Text(
            'Esta asignatura todavía no tiene unidades en el periodo.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
      ...fila.unidades.map((u) => _buildUnidad(fila, u, puedeGuardar)),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: puedeGuardar ? () => _nuevaUnidad(fila) : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir unidad'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: puedeGuardar ? () => _verPapelera(fila) : null,
              icon: const Icon(Icons.restore_from_trash_outlined, size: 18),
              label: const Text('Papelera', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: Colors.black54),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildUnidad(
    AsignaturaConUnidades fila,
    UnidadModel unidad,
    bool puedeGuardar,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unidad.definicion.isEmpty ? 'Sin nombre' : unidad.definicion,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              _pastilla(porcentajeEscrito(unidad.porcentaje), kPrimaryColor),
              ..._flechas(
                puede: puedeGuardar,
                posicion: fila.unidades.indexOf(unidad),
                cuantos: fila.unidades.length,
                que: 'la unidad',
                mover: (desde, hasta) => _moverUnidad(fila, desde, hasta),
              ),
              _iconoChico(
                Icons.edit_outlined,
                'Editar la unidad',
                puedeGuardar ? () => _editarUnidad(fila, unidad) : null,
              ),
              _iconoChico(
                Icons.delete_outline,
                'Borrar la unidad',
                puedeGuardar ? () => _borrarUnidad(fila, unidad) : null,
                color: Colors.redAccent,
              ),
            ],
          ),
          if (!unidad.subunidadesCuadran)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text(
                unidad.subunidades.isEmpty
                    ? 'Sin subunidades: aquí no se puede poner ninguna nota.'
                    : 'Sus subunidades suman'
                        ' ${porcentajeEscrito(unidad.porcentajeSubunidades)},'
                        ' y tienen que sumar 100%.',
                style: TextStyle(
                    fontSize: 11.5, color: Colors.orange.shade800),
              ),
            ),
          ...unidad.subunidades
              .map((s) => _buildSubunidad(fila, unidad, s, puedeGuardar)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  puedeGuardar ? () => _nuevaSubunidad(fila, unidad) : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir subunidad',
                  style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubunidad(
    AsignaturaConUnidades fila,
    UnidadModel unidad,
    SubunidadModel subunidad,
    bool puedeGuardar,
  ) {
    final notas = subunidad.cantNotas;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.subdirectory_arrow_right,
                size: 16, color: Colors.black26),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subunidad.definicion.isEmpty
                      ? 'Sin nombre'
                      : subunidad.definicion,
                  style: const TextStyle(fontSize: 13),
                ),
                if (notas != null)
                  Text(
                    notas == 0
                        ? 'sin notas puestas'
                        : '$notas ${notas == 1 ? 'nota puesta' : 'notas puestas'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: notas == 0 ? Colors.orange.shade800 : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            porcentajeEscrito(subunidad.porcentaje),
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          ..._flechas(
            puede: puedeGuardar,
            posicion: unidad.subunidades.indexOf(subunidad),
            cuantos: unidad.subunidades.length,
            que: 'la subunidad',
            mover: (desde, hasta) =>
                _moverSubunidad(fila, unidad, desde, hasta),
          ),
          _iconoChico(
            Icons.edit_outlined,
            'Editar la subunidad',
            puedeGuardar ? () => _editarSubunidad(fila, unidad, subunidad) : null,
          ),
          _iconoChico(
            Icons.delete_outline,
            'Borrar la subunidad',
            puedeGuardar ? () => _borrarSubunidad(fila, subunidad) : null,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  // --- Lo que escribe -------------------------------------------------------

  Future<void> _nuevaUnidad(AsignaturaConUnidades fila) async {
    // Lo que falta para llegar a 100, que es lo que el docente va a teclear
    // nueve de cada diez veces.
    final resto = (100 - fila.porcentaje).clamp(0, 100).toDouble();

    final datos = await _pedirDatos(
      titulo: 'Nueva unidad',
      definicion: '',
      porcentaje: resto,
    );
    if (datos == null) return;

    await _escribir(
      fila.asignatura.id,
      () => crearUnidad(
        server,
        asignaturaId: fila.asignatura.id,
        definicion: datos.definicion,
        porcentaje: datos.porcentaje,
      ),
    );
  }

  Future<void> _editarUnidad(
      AsignaturaConUnidades fila, UnidadModel unidad) async {
    final datos = await _pedirDatos(
      titulo: 'Editar unidad',
      definicion: unidad.definicion,
      porcentaje: unidad.porcentaje,
    );
    if (datos == null) return;

    await _escribir(
      fila.asignatura.id,
      () => actualizarUnidad(
        server,
        id: unidad.id,
        definicion: datos.definicion,
        porcentaje: datos.porcentaje,
        asignaturaId: fila.asignatura.id,
        periodoId: ContextoAcademico.instancia.periodoId!,
        numeroPeriodo: ContextoAcademico.instancia.numeroPeriodo ?? 0,
      ),
    );
  }

  Future<void> _borrarUnidad(
      AsignaturaConUnidades fila, UnidadModel unidad) async {
    final notas = unidad.subunidades
        .fold<int>(0, (acc, s) => acc + (s.cantNotas ?? 0));

    final seguro = await _confirmar(
      titulo: '¿Borrar la unidad?',
      detalle: notas == 0
          ? 'Se va «${unidad.definicion}» con sus'
              ' ${unidad.subunidades.length} subunidades. Queda en la papelera'
              ' de la asignatura y desde ahí se puede devolver.'
          : 'Se va «${unidad.definicion}» con sus'
              ' ${unidad.subunidades.length} subunidades y con las $notas notas'
              ' que hay puestas en ellas. Queda en la papelera de la asignatura'
              ' y desde ahí se puede devolver.',
    );
    if (!seguro) return;

    await _escribir(
      fila.asignatura.id,
      () => borrarUnidad(
        server,
        id: unidad.id,
        asignaturaId: fila.asignatura.id,
        periodoId: ContextoAcademico.instancia.periodoId!,
        numeroPeriodo: ContextoAcademico.instancia.numeroPeriodo ?? 0,
      ),
    );
  }

  Future<void> _nuevaSubunidad(
      AsignaturaConUnidades fila, UnidadModel unidad) async {
    final resto =
        (100 - unidad.porcentajeSubunidades).clamp(0, 100).toDouble();

    final datos = await _pedirDatos(
      titulo: 'Nueva subunidad',
      definicion: '',
      porcentaje: resto,
      notaDefault: 0,
    );
    if (datos == null) return;

    await _escribir(
      fila.asignatura.id,
      () => crearSubunidad(
        server,
        unidadId: unidad.id,
        definicion: datos.definicion,
        porcentaje: datos.porcentaje,
        notaDefault: datos.notaDefault ?? 0,
      ),
    );
  }

  Future<void> _editarSubunidad(
    AsignaturaConUnidades fila,
    UnidadModel unidad,
    SubunidadModel subunidad,
  ) async {
    final datos = await _pedirDatos(
      titulo: 'Editar subunidad',
      definicion: subunidad.definicion,
      porcentaje: subunidad.porcentaje,
      notaDefault: subunidad.notaDefault,
    );
    if (datos == null) return;

    await _escribir(
      fila.asignatura.id,
      () => actualizarSubunidad(
        server,
        id: subunidad.id,
        definicion: datos.definicion,
        porcentaje: datos.porcentaje,
        notaDefault: datos.notaDefault ?? 0,
        asignaturaId: fila.asignatura.id,
        periodoId: ContextoAcademico.instancia.periodoId!,
        numeroPeriodo: ContextoAcademico.instancia.numeroPeriodo ?? 0,
      ),
    );
  }

  Future<void> _borrarSubunidad(
      AsignaturaConUnidades fila, SubunidadModel subunidad) async {
    final notas = subunidad.cantNotas ?? 0;

    final seguro = await _confirmar(
      titulo: '¿Borrar la subunidad?',
      detalle: notas == 0
          ? 'Se va «${subunidad.definicion}». No tiene ninguna nota puesta.'
          : 'Se va «${subunidad.definicion}» con las $notas notas que hay'
              ' puestas en ella. Queda en la papelera de la asignatura y desde'
              ' ahí se puede devolver.',
    );
    if (!seguro) return;

    await _escribir(
      fila.asignatura.id,
      () => borrarSubunidad(
        server,
        id: subunidad.id,
        asignaturaId: fila.asignatura.id,
        periodoId: ContextoAcademico.instancia.periodoId!,
        numeroPeriodo: ContextoAcademico.instancia.numeroPeriodo ?? 0,
      ),
    );
  }

  /// Las flechas de subir y bajar.
  ///
  /// Y no arrastrar y soltar, que es lo que hace el front web: aquí la lista
  /// va dentro de una tarjeta que a su vez está dentro de otra lista que
  /// scrollea, y un arrastre ahí pelea con el scroll de las dos. Dos flechas
  /// hacen lo mismo, en un dedo y sin ambigüedad.
  ///
  /// La de arriba se apaga en el primero y la de abajo en el último: enseñar
  /// un botón que no puede hacer nada es enseñar una avería.
  List<Widget> _flechas({
    required bool puede,
    required int posicion,
    required int cuantos,
    required String que,
    required Future<void> Function(int desde, int hasta) mover,
  }) {
    if (cuantos < 2) return const [];

    return [
      _iconoChico(
        Icons.keyboard_arrow_up,
        'Subir $que',
        puede && posicion > 0 ? () => mover(posicion, posicion - 1) : null,
      ),
      _iconoChico(
        Icons.keyboard_arrow_down,
        'Bajar $que',
        puede && posicion < cuantos - 1
            ? () => mover(posicion, posicion + 1)
            : null,
      ),
    ];
  }

  Future<void> _moverUnidad(
      AsignaturaConUnidades fila, int desde, int hasta) async {
    final orden = _intercambiadas(fila.unidades.map((u) => u.id).toList(),
        desde: desde, hasta: hasta);

    await _escribir(
      fila.asignatura.id,
      () => reordenarUnidades(server, idsEnOrden: orden),
    );
  }

  Future<void> _moverSubunidad(
    AsignaturaConUnidades fila,
    UnidadModel unidad,
    int desde,
    int hasta,
  ) async {
    final orden = _intercambiadas(
        unidad.subunidades.map((s) => s.id).toList(),
        desde: desde,
        hasta: hasta);

    await _escribir(
      fila.asignatura.id,
      () => reordenarSubunidades(server, idsEnOrden: orden),
    );
  }

  List<int> _intercambiadas(List<int> ids,
      {required int desde, required int hasta}) {
    final movidos = [...ids];
    final id = movidos.removeAt(desde);
    movidos.insert(hasta, id);
    return movidos;
  }

  /// Lo borrado del periodo, y de vuelta si hace falta.
  ///
  /// Antes esto solo se podía deshacer desde la plataforma web, y así lo decía
  /// el aviso de borrar. Deshacer donde se hizo es lo menos que puede pedirse
  /// de un botón que se lleva por delante las notas de un grupo entero.
  Future<void> _verPapelera(AsignaturaConUnidades fila) async {
    setState(() => ocupadas.add(fila.asignatura.id));

    PapeleraUnidades? papelera;
    try {
      papelera = await traerPapelera(server, asignaturaId: fila.asignatura.id);
    } catch (err) {
      _avisar('No se pudo abrir la papelera: $err');
    } finally {
      setState(() => ocupadas.remove(fila.asignatura.id));
    }

    if (papelera == null || !mounted) return;

    if (papelera.vacia) {
      _avisar('No hay nada borrado en esta asignatura en el periodo.');
      return;
    }

    final restaurar = await showModalBottomSheet<Future<String?> Function()>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (_) => _HojaPapelera(server: server, papelera: papelera!),
    );

    if (restaurar == null) return;

    await _escribir(fila.asignatura.id, restaurar);
  }

  // --- Los cuadros ----------------------------------------------------------

  /// El cuadro de crear y el de editar son el mismo: los datos son los mismos.
  ///
  /// Con [notaDefault] es una subunidad y sin él una unidad, que no la tiene.
  Future<_DatosUnidad?> _pedirDatos({
    required String titulo,
    required String definicion,
    required double porcentaje,
    double? notaDefault,
  }) {
    return showDialog<_DatosUnidad>(
      context: context,
      builder: (_) => _CuadroUnidad(
        titulo: titulo,
        definicion: definicion,
        porcentaje: porcentaje,
        notaDefault: notaDefault,
      ),
    );
  }

  Future<bool> _confirmar({
    required String titulo,
    required String detalle,
  }) async {
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Text(detalle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Borrar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    return respuesta ?? false;
  }

  // --- Piezas sueltas -------------------------------------------------------

  Widget _pastilla(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
            fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _iconoChico(
    IconData icono,
    String descripcion,
    VoidCallback? alTocar, {
    Color color = Colors.black45,
  }) {
    return IconButton(
      icon: Icon(icono, size: 18),
      color: color,
      tooltip: descripcion,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      onPressed: alTocar,
    );
  }

  Widget _buildMensaje(String texto, {bool conReintento = false}) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 44, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          if (conReintento) ...[
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _arrancar, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}

/// Lo que el docente teclea en el cuadro.
class _DatosUnidad {
  final String definicion;
  final double porcentaje;
  final double? notaDefault;

  _DatosUnidad({
    required this.definicion,
    required this.porcentaje,
    this.notaDefault,
  });
}

/// El cuadro de una unidad o de una subunidad.
///
/// El porcentaje no se acepta vacío ni fuera de 0–100: es un peso, y el
/// backend lo guarda tal cual sin mirarlo. Un 1000 ahí descuadra la definitiva
/// de todo el grupo sin decir nada.
class _CuadroUnidad extends StatefulWidget {
  const _CuadroUnidad({
    required this.titulo,
    required this.definicion,
    required this.porcentaje,
    this.notaDefault,
  });

  final String titulo;
  final String definicion;
  final double porcentaje;
  final double? notaDefault;

  @override
  State<_CuadroUnidad> createState() => _CuadroUnidadState();
}

class _CuadroUnidadState extends State<_CuadroUnidad> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _definicion;
  late final TextEditingController _porcentaje;
  late final TextEditingController _notaDefault;

  bool get esSubunidad => widget.notaDefault != null;

  @override
  void initState() {
    super.initState();
    _definicion = TextEditingController(text: widget.definicion);
    _porcentaje = TextEditingController(text: _sinCeros(widget.porcentaje));
    _notaDefault =
        TextEditingController(text: _sinCeros(widget.notaDefault ?? 0));
  }

  @override
  void dispose() {
    _definicion.dispose();
    _porcentaje.dispose();
    _notaDefault.dispose();
    super.dispose();
  }

  static String _sinCeros(double valor) => valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toString();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _definicion,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (valor) => (valor ?? '').trim().isEmpty
                  ? 'Ponle un nombre.'
                  : null,
            ),
            TextFormField(
              controller: _porcentaje,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Porcentaje',
                suffixText: '%',
              ),
              validator: (valor) => _numero(valor, maximo: 100),
            ),
            if (esSubunidad)
              TextFormField(
                controller: _notaDefault,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nota por defecto',
                  helperText: 'Con la que arranca cada alumno',
                ),
                validator: (valor) => _numero(valor, maximo: 100),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _aceptar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  String? _numero(String? valor, {required double maximo}) {
    final leido = double.tryParse((valor ?? '').trim().replaceAll(',', '.'));

    if (leido == null) return 'Escribe un número.';
    if (leido < 0 || leido > maximo) return 'Entre 0 y ${maximo.toInt()}.';
    return null;
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;

    Navigator.pop(
      context,
      _DatosUnidad(
        definicion: _definicion.text.trim(),
        porcentaje: _leer(_porcentaje),
        notaDefault: esSubunidad ? _leer(_notaDefault) : null,
      ),
    );
  }

  double _leer(TextEditingController control) =>
      double.tryParse(control.text.trim().replaceAll(',', '.')) ?? 0;
}

/// La hoja de la papelera: lo borrado, con un botón para devolverlo.
///
/// Devuelve la llamada que hay que hacer, no el resultado de hacerla: quien la
/// abrió es quien sabe recargar la asignatura después, y así el guardado pasa
/// por el mismo sitio que todos los demás de esta pantalla.
class _HojaPapelera extends StatelessWidget {
  const _HojaPapelera({required this.server, required this.papelera});

  final Server server;
  final PapeleraUnidades papelera;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Papelera del periodo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${papelera.cuantas}',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ...papelera.unidades.map((u) => ListTile(
                      leading: const Icon(Icons.folder_delete_outlined),
                      title: Text(
                        u.definicion.isEmpty ? 'Sin nombre' : u.definicion,
                      ),
                      subtitle: Text(
                        'Unidad de ${porcentajeEscrito(u.porcentaje)}'
                        ' · ${u.subunidades.length} subunidades',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          () => restaurarUnidad(server, id: u.id),
                        ),
                        child: const Text('Devolver'),
                      ),
                    )),
                ...papelera.subunidades.map((s) => ListTile(
                      leading: const Icon(Icons.subdirectory_arrow_right),
                      title: Text(
                        s.definicion.isEmpty ? 'Sin nombre' : s.definicion,
                      ),
                      subtitle: Text(
                        'Subunidad de ${porcentajeEscrito(s.porcentaje)}'
                        '${s.unidad.isEmpty ? '' : ' · en ${s.unidad}'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          () => restaurarSubunidad(server, id: s.id),
                        ),
                        child: const Text('Devolver'),
                      ),
                    )),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
