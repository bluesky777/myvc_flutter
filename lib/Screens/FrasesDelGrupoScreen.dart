import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/FrasesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/FraseModel.dart';
import 'package:myvc_flutter/Models/YearModel.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/SelectorFrases.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';

/// Las frases del boletín de **todo el grupo** de una asignatura, en una
/// pantalla y en un guardado.
///
/// ## Qué arregla, medido
///
/// Hoy las frases se ponen desde [FichaAlumnoNotasScreen], **de una en una**
/// —`POST frases_asignatura/store`, una petición por frase— y **sin poder
/// elegir el periodo**, porque aquel controlador escribe siempre en
/// `$user->periodo_id`. Un periodo de «Transición» de 2018 —18 matriculados, 7
/// asignaturas— son **322 peticiones**; por aquí son **14**.
///
/// Las de una en una no se van: la ficha de **un** alumno no necesita el grupo
/// y allí siguen siendo lo correcto. Son dos granos para dos pantallas, no un
/// puente a medio cruzar.
///
/// ## El botón de guardar se pinta contra `puede_escribir`, y nada más
///
/// **No contra el periodo, y no contra el papel de quien entra.** Los tres
/// dicen cosas distintas y el servidor ya contestó cuál manda:
///
///  - un superusuario **escribe con el periodo cerrado** y un docente no
///    —`User::permiteEditarNotas` sólo mira la columna del periodo cuando quien
///    llama es docente—;
///  - un secretario sin `is_superuser` **lee** las frases de cualquier grupo y
///    **no escribe ninguna**, con el periodo abierto o cerrado.
///
/// O sea que [ConfiguracionColegio.puedeEditarNotas] —la copia que la app tiene
/// de la regla, y que sí usa «Mis competencias»— **aquí no se mira**: allí hace
/// falta porque no hay respuesta del servidor antes de llamar, y aquí el `GET`
/// ya trae la suya. Reconstruirla sería darle a esos dos usuarios la pantalla
/// del otro.
///
/// ## Elegir el periodo no tiene la trampa de A4, y es por el contrato
///
/// Copiar el plan a otro periodo (A4) tiene un agujero conocido: el backend
/// comprueba la bandera **del periodo destino** y la app sólo conoce la del
/// suyo. Aquí no pasa, y no por cuidado nuestro: el `GET` se pide **con el
/// periodo**, y `periodo_abierto` y `puede_escribir` que devuelve son **los de
/// ese periodo**. Cambiar de chip es volver a preguntar, y la respuesta trae su
/// propio permiso. Ver `docs/competencias.md` §9.
///
/// ## Se guarda sólo a quien se tocó
///
/// El `PUT` es declarativo **por alumno**: la lista que se manda es la completa
/// y lo que no venga en ella se borra — pero **un alumno que no viene en el
/// cuerpo no se mira**. Así que aquí se mandan únicamente los alumnos cuyo
/// borrador dejó de parecerse a lo que llegó, y a los demás no les puede pasar
/// nada. Ver [_loQueCambio].
class FrasesDelGrupoScreen extends StatefulWidget {
  const FrasesDelGrupoScreen({
    super.key,
    required this.asignaturaId,
    required this.materia,
    required this.nombreGrupo,
    this.servidor,
  });

  final int asignaturaId;
  final String materia;
  final String nombreGrupo;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  ///
  /// La misma costura que [LibroAsignaturaScreen] y [MisCompetenciasScreen], y
  /// aquí hace más falta que en ninguna: esta pantalla vive detrás de un
  /// interruptor apagado y de dos rutas sin desplegar, así que **en la app no
  /// hay forma de abrirla**. Con esto se mira en el banco de pruebas, con los
  /// casos que un colegio de verdad no enseña: sólo lectura con el periodo
  /// abierto, y frases de alumnos que ya no están en el grupo.
  final Server? servidor;

  @override
  State<FrasesDelGrupoScreen> createState() => _FrasesDelGrupoScreenState();
}

class _FrasesDelGrupoScreenState extends State<FrasesDelGrupoScreen> {
  late final Server server = widget.servidor ?? Server();

  /// El sobre de la última respuesta: en qué periodo se leyó y quién puede
  /// escribir. Es lo único contra lo que se pinta el botón.
  FrasesDelGrupo? grupo;

  /// La población **de lo leído**, que sólo viene en el `GET`.
  ///
  /// No se toca al guardar y no es un olvido: el `PUT` contesta otra población
  /// —la de lo escrito— que no lleva el renglón de las frases de fuera del
  /// grupo, y dejar que lo pisara haría que después de guardar la pantalla
  /// dijera que no hay retirados con frases. El `PUT` no toca esas filas, así
  /// que lo que dijo el `GET` sigue siendo verdad.
  PoblacionLeida? poblacion;

  /// Lo que se está escribiendo, por alumno. Se rehace entero en cada lectura.
  final Map<int, List<_Borrador>> borradores = {};

  /// Cómo estaba el cuerpo de cada alumno recién leído, para saber qué cambió.
  ///
  /// Se guarda la **codificación** y no las filas: así los dos lados de la
  /// comparación salen del mismo `paraElCuerpo()` y no hay forma de que un
  /// espacio de más en el texto del servidor cuente como un cambio.
  final Map<int, String> firmas = {};

  /// Los periodos del año, para poder escribir en otro sin mover la sesión.
  List<PeriodoModel> periodos = const [];

  /// El catálogo del colegio, traído la primera vez que alguien va a elegir una.
  List<FraseDelCatalogo>? catalogo;
  bool trayendoCatalogo = false;

  /// La casilla recién añadida, para abrirle el teclado sin tener que tocarla.
  _Borrador? recienAnadida;

  /// En qué periodo se llegó a escribir algo, si se escribió.
  ///
  /// Es lo único que esta pantalla devuelve, y existe para que el libro de
  /// notas sepa si su copia de las frases se quedó vieja **sin tener que
  /// suponerlo**: `notas/detailed` es la consulta más cara del proyecto y las
  /// trae dentro, así que volver a pedirla porque alguien entró aquí y salió
  /// —o porque escribió en el periodo 1 estando la sesión en el 3— sería
  /// pagarla para nada.
  int? periodoEscrito;

  bool cargando = true;
  bool guardando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    _soltarBorradores();
    super.dispose();
  }

  void _soltarBorradores() {
    for (final lista in borradores.values) {
      for (final borrador in lista) {
        borrador.soltar();
      }
    }
    borradores.clear();
  }

  List<AlumnoConFrases> get _alumnos => grupo?.alumnos ?? const [];

  bool get _puedeEscribir => grupo?.puedeEscribir ?? false;

  /// Trae el grupo, y con él el permiso del periodo que toque.
  ///
  /// [periodoId] null es «el de la sesión», que es lo que se pide al abrir. Cuál
  /// le tocó lo dice la respuesta, no la petición: por eso los chips se marcan
  /// con [FrasesDelGrupo.periodoId] y no con lo que se pidió.
  Future<void> _cargar({int? periodoId}) async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final leido = await traerFrasesDelGrupo(
        server,
        asignaturaId: widget.asignaturaId,
        periodoId: periodoId,
      );

      _soltarBorradores();
      firmas.clear();

      for (final alumno in leido.grupo.alumnos) {
        final suyos = alumno.frases.map(_Borrador.deLaFila).toList();
        borradores[alumno.alumnoId] = suyos;
        firmas[alumno.alumnoId] = _firmaDe(alumno.alumnoId, suyos);
      }

      setState(() {
        grupo = leido.grupo;
        poblacion = leido.poblacion;
        recienAnadida = null;
        cargando = false;
      });
    } catch (err) {
      setState(() {
        error = '$err';
        cargando = false;
      });
    }

    await _cargarPeriodos();
  }

  /// Los periodos del año, para el selector.
  ///
  /// **En su propio `try` y sin decir nada si falla**: sin ellos la pantalla
  /// funciona entera en el periodo de la sesión, que es el caso normal. Tumbarla
  /// —o poner un error encima de las frases que ya están pintadas— por no poder
  /// ofrecer un chip sería cambiar una función de más por la función entera.
  Future<void> _cargarPeriodos() async {
    if (periodos.isNotEmpty) return;

    try {
      await ContextoAcademico.instancia.cargarYears(server);
      setState(() => periodos = ContextoAcademico.instancia.periodosDelYear);
    } catch (_) {
      // Sin chips y a seguir.
    }
  }

  /// El catálogo del año, traído la primera vez que hace falta.
  ///
  /// Como en la ficha del alumno y por lo mismo: son más de cuatrocientas filas
  /// y la mayoría de las visitas a esta pantalla no llegan a abrir la hoja —lo
  /// normal es escribir a mano, 611 de las 686 frases del grupo 3 en la copia de
  /// desarrollo—. Una vez traído se queda mientras la pantalla viva.
  Future<void> _asegurarCatalogo() async {
    if (catalogo != null || trayendoCatalogo) return;

    setState(() => trayendoCatalogo = true);
    try {
      catalogo = await traerCatalogoDeFrases(server);
    } catch (err) {
      _avisar('No se pudo traer el catálogo de frases: $err');
      catalogo = const [];
    }
    setState(() => trayendoCatalogo = false);
  }

  // ---- qué cambió --------------------------------------------------------

  String _firmaDe(int alumnoId, List<_Borrador> suyos) {
    final cuerpo = FrasesDeUnAlumno(
      alumnoId: alumnoId,
      frases: suyos.where(_cuenta).map((b) => b.paraGuardar()).toList(),
    );

    return jsonEncode(cuerpo.paraElCuerpo());
  }

  /// Si esta casilla es algo que mandar.
  ///
  /// Una vacía **sin `id`** no es nada: el docente pulsó «Escribir» y no llegó a
  /// escribir. Mandarla sería una entrada que el servidor cuenta en `vacias` y
  /// que no escribe nada, y de paso haría que ese alumno pareciera tocado.
  ///
  /// Una vacía **con `id`** es lo contrario: es un borrado, y tiene que viajar.
  /// Es lo que pasa cuando se borra el texto de una frase que ya existía.
  bool _cuenta(_Borrador borrador) =>
      borrador.esDelCatalogo ||
      borrador.id != null ||
      borrador.textoActual.isNotEmpty;

  /// Los alumnos cuyo borrador dejó de parecerse a lo que llegó.
  ///
  /// **Los demás no se nombran**, que es lo que hace seguro guardar por partes:
  /// el `PUT` sólo mira a quien viene en el cuerpo.
  List<FrasesDeUnAlumno> _loQueCambio() {
    final cambios = <FrasesDeUnAlumno>[];

    for (final alumno in _alumnos) {
      final suyos = borradores[alumno.alumnoId] ?? const <_Borrador>[];
      if (_firmaDe(alumno.alumnoId, suyos) == firmas[alumno.alumnoId]) continue;

      cambios.add(FrasesDeUnAlumno(
        alumnoId: alumno.alumnoId,
        frases: suyos.where(_cuenta).map((b) => b.paraGuardar()).toList(),
      ));
    }

    return cambios;
  }

  int get _cuantosSinGuardar => _loQueCambio().length;

  // ---- escribir ----------------------------------------------------------

  /// Añade una casilla vacía y le abre el teclado.
  ///
  /// **Sin hoja de por medio, y es la diferencia que hace útil esta pantalla.**
  /// Lo que se hace aquí son dieciocho frases seguidas, y casi todas escritas a
  /// mano; meter un modal entre el dedo y el teclado en cada una convertiría un
  /// rato en una tarde. La hoja del catálogo sigue estando, en el otro botón,
  /// para cuando la frase que toca ya está escrita por el colegio.
  void _escribir(AlumnoConFrases alumno) {
    final nueva = _Borrador.aMano();

    setState(() {
      borradores.putIfAbsent(alumno.alumnoId, () => []).add(nueva);
      recienAnadida = nueva;
    });
  }

  Future<void> _delColegio(AlumnoConFrases alumno) async {
    await _asegurarCatalogo();
    if (!mounted) return;

    final elegida = await pedirFrase(context, catalogo ?? const []);
    if (elegida == null || !mounted) return;

    setState(() {
      final suyas = borradores.putIfAbsent(alumno.alumnoId, () => []);

      if (elegida.esDelCatalogo) {
        final delCatalogo = (catalogo ?? const <FraseDelCatalogo>[]).firstWhere(
          (f) => f.id == elegida.fraseId,
          orElse: () => const FraseDelCatalogo(id: 0, frase: ''),
        );

        suyas.add(_Borrador.delCatalogo(
          fraseId: elegida.fraseId!,
          // El texto es sólo para pintarla mientras no se guarda: al servidor
          // viaja el `frase_id` y nada más, para que el boletín la siga
          // resolviendo contra el catálogo vivo.
          texto: delCatalogo.frase,
          tipo: delCatalogo.tipo,
        ));
        recienAnadida = null;
      } else {
        final nueva = _Borrador.aMano(texto: elegida.texto ?? '');
        suyas.add(nueva);
        recienAnadida = nueva;
      }
    });
  }

  void _quitar(AlumnoConFrases alumno, _Borrador borrador) {
    setState(() {
      borradores[alumno.alumnoId]?.remove(borrador);
      if (identical(recienAnadida, borrador)) recienAnadida = null;
    });
    borrador.soltar();
  }

  Future<void> _guardar() async {
    final cambios = _loQueCambio();
    if (cambios.isEmpty) {
      _avisar('No hay nada que guardar.');
      return;
    }

    setState(() => guardando = true);

    // **El periodo que viaja es el que el `GET` dijo que leyó**, no el que se
    // pidió ni el de la sesión. Si entre abrir esto y guardar alguien cambió el
    // periodo de la sesión desde otra pantalla, omitirlo escribiría en un
    // periodo distinto del que se está mirando.
    final resultado = await guardarFrasesDelGrupo(
      server,
      asignaturaId: widget.asignaturaId,
      alumnos: cambios,
      periodoId: grupo?.periodoId,
    );

    if (!mounted) return;

    if (!resultado.entro) {
      setState(() => guardando = false);
      _avisar(resultado.motivo!);
      return;
    }

    final escrito = resultado.poblacion ?? const PoblacionGuardada();

    // Cuántos y cuántas, nunca de quién: a Analytics no va ni un `alumno_id`
    // ni el nombre de un grupo. Ver docs/analitica.md.
    Analitica.evento('frases_grupo_guardadas', datos: {
      'alumnos': escrito.alumnosRevisados,
      'filas': escrito.filasTocadas,
    });

    // El `PUT` devuelve el grupo releído **con las filas nuevas ya con su id**,
    // así que se repinta con eso y el guardado siguiente no necesita otra
    // lectura. La población de lo leído no se toca: ver [poblacion].
    final releido = resultado.grupo;
    if (releido != null) {
      _soltarBorradores();
      firmas.clear();

      for (final alumno in releido.alumnos) {
        final suyos = alumno.frases.map(_Borrador.deLaFila).toList();
        borradores[alumno.alumnoId] = suyos;
        firmas[alumno.alumnoId] = _firmaDe(alumno.alumnoId, suyos);
      }
    }

    setState(() {
      if (releido != null) grupo = releido;
      if (escrito.filasTocadas > 0) periodoEscrito = grupo?.periodoId;
      recienAnadida = null;
      guardando = false;
    });

    _avisar(_comoQuedo(escrito));
  }

  /// Qué pasó al guardar, dicho con los contadores del servidor.
  ///
  /// **«No cambió nada» se dice en voz alta** y no se calla: es exactamente la
  /// pregunta de quien cree que ha perdido el trabajo, y no es lo mismo que «no
  /// se guardó».
  String _comoQuedo(PoblacionGuardada escrito) {
    if (escrito.noCambioNada) return 'Se guardó y no cambió nada.';

    final partes = <String>[];
    if (escrito.escritas > 0) partes.add('${escrito.escritas} nuevas');
    if (escrito.cambiadas > 0) partes.add('${escrito.cambiadas} corregidas');
    if (escrito.borradas > 0) partes.add('${escrito.borradas} quitadas');

    return '${partes.join(', ')}.';
  }

  // ---- salir y cambiar de periodo ----------------------------------------

  Future<void> _elegirPeriodo(PeriodoModel periodo) async {
    if (periodo.id == grupo?.periodoId) return;
    if (!await _confirmarDescartar()) return;

    await _cargar(periodoId: periodo.id);
  }

  /// Qué hacer cuando quedan frases escritas sin guardar.
  ///
  /// Se pregunta en vez de guardar sin avisar, que es el mismo criterio de la
  /// planilla y del editor de situaciones: en el teléfono se sale mucho por el
  /// gesto de volver, sin querer.
  Future<bool> _confirmarDescartar() async {
    final cuantos = _cuantosSinGuardar;
    if (cuantos == 0) return true;

    final seguir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Quedan frases sin guardar'),
        content: Text(
          cuantos == 1
              ? 'Hay un alumno con frases escritas que no se han guardado.'
              : 'Hay $cuantos alumnos con frases escritas que no se han'
                  ' guardado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir aquí'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return seguir ?? false;
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ---- pintar ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final navegador = Navigator.of(context);

    return PopScope<int?>(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) async {
        if (yaSalio) return;
        if (!await _confirmarDescartar()) return;
        if (!mounted) return;
        navegador.pop(periodoEscrito);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: TituloPantalla(
            titulo: 'Frases del boletín',
            subtitulo: '${widget.materia} · ${widget.nombreGrupo}',
          ),
        ),
        body: ColumnaDeFicha(child: _buildCuerpo()),
        bottomNavigationBar:
            _puedeEscribir && !cargando ? _buildBarraGuardar() : null,
      ),
    );
  }

  Widget _buildCuerpo() {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _cargar(periodoId: grupo?.periodoId),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (periodos.length > 1) _buildBarraDePeriodos(),
        if (!_puedeEscribir) _buildSoloLectura(),
        if (poblacion?.hayFrasesFueraDelGrupo ?? false) _buildDeFuera(),
        if (_alumnos.isEmpty)
          _buildSinAlumnos()
        else
          ..._alumnos.map(_buildAlumno),
      ],
    );
  }

  /// Los periodos del año, para escribir en otro **sin mover la sesión**.
  ///
  /// Es la mitad de lo que esta pantalla arregla: el camino viejo escribe
  /// siempre en el periodo de la barra de arriba, así que poner las frases del
  /// periodo 1 en octubre obligaba a cambiarse de periodo entero —y a
  /// acordarse de volver—.
  ///
  /// Se marca el que **dijo el servidor** y no el que se pidió: sin
  /// `periodo_id` manda el de la sesión, y cuál fue sólo se sabe leyendo la
  /// respuesta.
  Widget _buildBarraDePeriodos() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          for (final periodo in periodos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                selected: periodo.id == grupo?.periodoId,
                onSelected: (_) => _elegirPeriodo(periodo),
                label: Text('P${periodo.numero}'),
              ),
            ),
        ],
      ),
    );
  }

  /// Por qué esto es de sólo lectura, dicho antes de tocar nada.
  ///
  /// **El motivo se describe, no se deduce.** El servidor manda un solo `false`
  /// y dos razones posibles, y lo único que la app sabe de verdad es la otra
  /// bandera que vino en la misma respuesta: con el periodo cerrado, eso es lo
  /// que lo explica; con el periodo abierto, lo que queda es la cuenta —un
  /// secretario sin `is_superuser`, o un docente al que ese grupo no le toca—.
  Widget _buildSoloLectura() {
    final cerrado = !(grupo?.periodoAbierto ?? false);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cerrado
                  ? 'Este periodo está cerrado: las frases se ven, pero no se'
                      ' pueden cambiar.'
                  : 'Tu cuenta puede ver estas frases pero no escribirlas.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  /// Las frases de alumnos que ya no están en el grupo.
  ///
  /// Un retirado, o uno que se cambió de grupo, puede tener frases vivas en
  /// esta asignatura y este periodo. **No salen en la lista y guardar no las
  /// toca**, así que si no se dice aquí no hay ningún sitio donde enterarse —y
  /// en el grupo 3 de la copia de desarrollo son 12 filas de 2 alumnos, o sea
  /// que el caso no es teórico—.
  Widget _buildDeFuera() {
    final cuantas = poblacion?.frasesFueraDelGrupo ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
              cuantas == 1
                  ? 'Hay una frase de un alumno que ya no está en el grupo. No'
                      ' sale aquí y guardar no la toca.'
                  : 'Hay $cuantas frases de alumnos que ya no están en el'
                      ' grupo. No salen aquí y guardar no las toca.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A4B00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinAlumnos() {
    return const Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 12),
          Text(
            'Este grupo no tiene alumnos matriculados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAlumno(AlumnoConFrases alumno) {
    final suyas = borradores[alumno.alumnoId] ?? const <_Borrador>[];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: Text(
              // Apellidos primero, como los ordena el servidor y como se busca
              // a un niño en una lista de clase.
              alumno.nombreCompleto,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (suyas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 6, bottom: 4),
              child: Text(
                'Sin frases en este periodo.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            )
          else
            ...suyas.map((borrador) => _buildFrase(alumno, borrador)),
          if (_puedeEscribir) _buildBotones(alumno),
        ],
      ),
    );
  }

  Widget _buildFrase(AlumnoConFrases alumno, _Borrador borrador) {
    return Padding(
      key: ObjectKey(borrador),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: borrador.esDelCatalogo
                ? _buildDelCatalogo(borrador)
                : _buildAMano(borrador),
          ),
          if (_puedeEscribir)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Quitar',
              onPressed: guardando ? null : () => _quitar(alumno, borrador),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }

  /// Una del catálogo: se enseña y no se edita.
  ///
  /// **Corregirla aquí sería corregírsela a todo el colegio**, porque la fila
  /// no guarda texto: apunta al catálogo y el boletín lo resuelve con un
  /// `IFNULL` contra lo que el colegio tenga escrito hoy. Quien la quiera
  /// distinta la quita y escribe una a mano.
  Widget _buildDelCatalogo(_Borrador borrador) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            borrador.texto,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          if (borrador.tipo.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                borrador.tipo.trim(),
                style: const TextStyle(fontSize: 11, color: kPrimaryColor),
              ),
            ),
        ],
      ),
    );
  }

  /// Una escrita a mano: se corrige donde está.
  ///
  /// **Vaciarla y guardar es quitarla.** El servidor cuenta una entrada sin
  /// texto en `vacias` y se lleva su fila con las que no vinieron, así que aquí
  /// no hace falta distinguir «la vacié» de «no la mandé»: son la misma cosa y
  /// significan lo mismo.
  Widget _buildAMano(_Borrador borrador) {
    return TextField(
      controller: borrador.campo,
      readOnly: !_puedeEscribir || guardando,
      autofocus: identical(recienAnadida, borrador),
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 13, height: 1.3),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: 'Escribe la frase de este alumno',
        hintStyle: TextStyle(fontSize: 13, color: Colors.black38),
      ),
      // Cada tecla mueve el contador de «sin guardar» de la barra de abajo, que
      // es lo único que dice cuánto trabajo hay pendiente.
      onChanged: (_) => setState(() {}),
    );
  }

  /// Los dos botones de añadir.
  ///
  /// **En un `Wrap` y apretados**, y no es estética: con el relleno normal de
  /// Material los dos no caben en la tarjeta de un teléfono —se desbordaba por
  /// dos píxeles en uno de 420 dp, y en uno de 360 por bastantes más—. Apretados
  /// caben en una línea en cualquier teléfono de hoy, y el `Wrap` es la red por
  /// si algún día el rótulo crece o alguien abre esto con la letra del sistema
  /// en grande.
  Widget _buildBotones(AlumnoConFrases alumno) {
    final apretado = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );

    return Wrap(
      children: [
        TextButton.icon(
          style: apretado,
          onPressed: guardando ? null : () => _escribir(alumno),
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Escribir'),
        ),
        TextButton.icon(
          style: apretado,
          onPressed:
              guardando || trayendoCatalogo ? null : () => _delColegio(alumno),
          icon: const Icon(Icons.list_alt_outlined, size: 17),
          label: const Text('Del colegio'),
        ),
      ],
    );
  }

  Widget _buildBarraGuardar() {
    final cuantos = _cuantosSinGuardar;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                guardando
                    ? 'Guardando…'
                    : cuantos == 0
                        ? 'Todo guardado'
                        : cuantos == 1
                            ? '1 alumno sin guardar'
                            : '$cuantos alumnos sin guardar',
                style: TextStyle(
                  fontSize: 13,
                  color: cuantos == 0 ? Colors.black54 : Colors.black87,
                  fontWeight:
                      cuantos == 0 ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: guardando || cuantos == 0 ? null : _guardar,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una frase mientras se está escribiendo, que no es lo mismo que una guardada.
///
/// [FraseDelGrupo] es lo que contestó el servidor y no se toca; esto es lo que
/// hay en la pantalla, que puede ser una fila que ya existe, una nueva, o una
/// que se acaba de vaciar. Lo que las separa al guardar es el [id]: con él el
/// servidor conserva la fila, y sin él la inserta.
class _Borrador {
  _Borrador._(
      {this.id, this.fraseId, this.texto = '', this.tipo = '', this.campo});

  /// Una del catálogo del colegio. No lleva casilla: no se edita aquí.
  factory _Borrador.delCatalogo({
    int? id,
    required int fraseId,
    required String texto,
    String tipo = '',
  }) {
    return _Borrador._(id: id, fraseId: fraseId, texto: texto, tipo: tipo);
  }

  /// Una escrita a mano, con su casilla.
  factory _Borrador.aMano({int? id, String texto = ''}) {
    return _Borrador._(id: id, campo: TextEditingController(text: texto));
  }

  /// La que ya estaba, tal como vino del `GET`.
  ///
  /// **El texto que se edita es el de la fila y no el del boletín**: una del
  /// catálogo no guarda texto ninguno, y meterlo en una casilla invitaría a
  /// corregir algo que no vive ahí. Ver [FraseDelGrupo.textoAMano].
  factory _Borrador.deLaFila(FraseDelGrupo fila) {
    final id = fila.id == 0 ? null : fila.id;

    return fila.esDelCatalogo
        ? _Borrador.delCatalogo(
            id: id,
            fraseId: fila.fraseId!,
            texto: fila.frase,
            tipo: fila.tipo,
          )
        : _Borrador.aMano(id: id, texto: fila.textoAMano);
  }

  /// La fila de `frases_asignatura`, o null si es nueva.
  final int? id;

  /// La frase del catálogo, o null si va texto.
  final int? fraseId;

  /// Sólo para las del catálogo: lo que imprime el boletín, para pintarla.
  ///
  /// **No viaja al servidor.** Si viajara con el `frase_id` ganaría el id de
  /// todas formas, y si viajara sola convertiría una del catálogo en escrita a
  /// mano — que es dejar de seguir al catálogo el día que el colegio lo
  /// corrija.
  final String texto;

  final String tipo;

  /// La casilla, sólo en las escritas a mano.
  final TextEditingController? campo;

  bool get esDelCatalogo => fraseId != null;

  String get textoActual => campo?.text.trim() ?? texto;

  FraseParaGuardar paraGuardar() {
    return esDelCatalogo
        ? FraseParaGuardar.delCatalogo(fraseId!, id: id)
        : FraseParaGuardar.aMano(textoActual, id: id);
  }

  void soltar() => campo?.dispose();
}
