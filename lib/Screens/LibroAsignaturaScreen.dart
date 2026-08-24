import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/LibroNotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/UnidadModel.dart';
import 'package:myvc_flutter/Screens/FichaAlumnoNotasScreen.dart';
import 'package:myvc_flutter/Screens/PlanillaScreen.dart';
import 'package:myvc_flutter/Utils/ConfiguracionColegio.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';

/// El libro de notas de una asignatura, por indicador.
///
/// **No es la tabla del front web, y a propósito.** Allí esto es una rejilla de
/// alumnos por subunidades —treinta filas por doce columnas, con scroll en los
/// dos ejes y cinco interruptores para domarla—. En un teléfono esa rejilla no
/// se estrecha: no cabe. Aquí la matriz se lee por un eje cada vez, y este es
/// el de los indicadores, que es el del trabajo diario: se acaba la clase, se
/// entra al indicador del quiz y se pasan las treinta notas de una columna.
///
/// El otro eje —un alumno y todas sus notas— es la segunda pestaña: la del
/// acudiente que pregunta y la de nivelar al cerrar el periodo. **Las dos
/// pestañas son la misma matriz leída por sus dos lados**, con los mismos datos
/// ya cargados: cambiar de pestaña no pide nada al servidor.
///
/// Todo cuelga de una sola llamada a `PUT notas/detailed`, que es cara: se pide
/// al abrir, se guarda en memoria y solo se vuelve a pedir tirando hacia abajo.
/// Volver de una planilla no la vuelve a pedir; lo que se guardó ya se sabe.
class LibroAsignaturaScreen extends StatefulWidget {
  const LibroAsignaturaScreen({
    super.key,
    required this.asignatura,
    this.profesorId,
  });

  final AsignaturaModel asignatura;

  /// De qué docente, cuando quien mira no es el dueño de la asignatura.
  final int? profesorId;

  @override
  State<LibroAsignaturaScreen> createState() => _LibroAsignaturaScreenState();
}

class _LibroAsignaturaScreenState extends State<LibroAsignaturaScreen> {
  final Server server = Server();

  LibroDeNotas? libro;
  bool cargando = true;
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

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final traido = await traerLibroDe(
        server,
        asignaturaId: widget.asignatura.id,
        profesorId: widget.profesorId,
      );
      setState(() => libro = traido);
    } catch (err) {
      setState(() => error = 'No se pudo traer el libro de notas: $err');
    }

    setState(() => cargando = false);
  }

  /// Abre la planilla de una casilla y aplica lo que se haya guardado allí.
  ///
  /// Sin volver a pedir `notas/detailed`: lo que quedó guardado es lo que la
  /// planilla mandó y el servidor aceptó, y esa consulta es demasiado cara para
  /// gastarla en refrescar un contador.
  Future<void> _abrirPlanilla(UnidadModel unidad, SubunidadModel subunidad) async {
    final actual = libro;
    if (actual == null) return;

    final guardadas = await Navigator.of(context).push<List<NotaPendiente>>(
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'planilla'),
        builder: (_) => PlanillaScreen(
          libro: actual,
          unidad: unidad,
          subunidad: subunidad,
        ),
      ),
    );

    if (guardadas == null || guardadas.isEmpty) return;
    setState(() => libro = actual.conNotas(guardadas));
  }

  /// Abre la ficha de un alumno y aplica lo que se haya guardado allí.
  ///
  /// Igual que con la planilla, sin volver a pedir `notas/detailed`: la ficha
  /// devuelve las notas que entraron y, si se tocó, la definitiva tal como
  /// quedó después de que el backend cruzara sus dos banderas.
  Future<void> _abrirFicha(AlumnoDelLibro alumno) async {
    final actual = libro;
    if (actual == null) return;

    final cambios = await Navigator.of(context).push<CambiosDeLaFicha>(
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'ficha-alumno-notas'),
        builder: (_) => FichaAlumnoNotasScreen(libro: actual, alumno: alumno),
      ),
    );

    if (cambios == null || !cambios.hayAlgo) return;

    setState(() {
      var nuevo = actual.conNotas(cambios.notas);
      if (cambios.notaFinal != null) {
        nuevo = nuevo.conNotaFinalDe(alumno.alumnoId, cambios.notaFinal!);
      }
      if (cambios.frases != null) {
        nuevo = nuevo.conFrasesDe(alumno.alumnoId, cambios.frases!);
      }
      libro = nuevo;
    });

    // Borrar una nota es lo único que deja al libro con datos que la app no
    // puede recalcular: el backend rehace la definitiva por su cuenta y no dice
    // con qué valor. Ahí sí toca pagar la consulta cara.
    if (cambios.hayQueRecargar) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    // Dos pestañas y no dos pantallas: es el mismo libro ya cargado, leído por
    // sus dos ejes. Separarlas en pantallas obligaría a traer `notas/detailed`
    // dos veces, y es la consulta más cara del proyecto.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: TituloPantalla(
            titulo: widget.asignatura.materia,
            subtitulo: widget.asignatura.nombreGrupo,
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Por ${_config.subunidad.toLowerCase()}'),
              const Tab(text: 'Por alumno'),
            ],
          ),
        ),
        body: _buildCuerpo(),
      ),
    );
  }

  ConfiguracionColegio get _config => ContextoAcademico.instancia.config;

  Widget _buildCuerpo() {
    if (cargando && libro == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (libro == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error ?? 'No hay libro de notas.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final actual = libro!;

    return TabBarView(
      children: [
        _buildPorIndicador(actual),
        _buildPorAlumno(actual),
      ],
    );
  }

  Widget _buildPorIndicador(LibroDeNotas actual) {
    final aviso = _config.avisoDeBloqueo;

    return RefreshIndicator(
      onRefresh: Analitica.refresco('libro-por-indicador', _cargar),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (aviso != null) _buildAviso(aviso),
          _buildResumen(actual),
          if (actual.unidades.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Esta asignatura no tiene ${_config.unidades.toLowerCase()}'
                ' en el periodo. Se crean en la pantalla de Unidades.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...actual.unidades.map((u) => _buildUnidad(actual, u)),
        ],
      ),
    );
  }

  /// El eje del alumno: cada uno con su promedio y su definitiva.
  ///
  /// Se enseñan los dos números y no solo la definitiva porque son cosas
  /// distintas y el docente decide mirándolos juntos: el promedio es lo que
  /// dan las notas y la definitiva es lo que va al boletín, que puede estar
  /// nivelada. Cuando difieren, la marca de al lado dice por qué.
  Widget _buildPorAlumno(LibroDeNotas actual) {
    if (actual.alumnos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Este grupo no tiene alumnos matriculados.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: Analitica.refresco('libro-por-alumno', _cargar),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: actual.alumnos.length,
        itemBuilder: (contexto, indice) =>
            _buildFilaAlumno(actual, actual.alumnos[indice]),
      ),
    );
  }

  Widget _buildFilaAlumno(LibroDeNotas actual, AlumnoDelLibro alumno) {
    final promedio = actual.promedioDe(alumno);
    final definitiva = alumno.notaFinal?.nota;
    final marcas = [
      if (alumno.notaFinal?.manual ?? false) 'a mano',
      if (alumno.notaFinal?.recuperada ?? false) 'recuperada',
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _abrirFicha(alumno),
        leading: AvatarPersona(
          nombre: alumno.nombreEnLista,
          fotoNombre: alumno.fotoNombre,
          radio: 20,
        ),
        title: Text(
          alumno.nombreEnLista,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            // Los asistentes en cursiva, como en el front web: no están
            // matriculados y conviene notarlo.
            fontStyle:
                alumno.estado == 'ASIS' ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        subtitle: Text(
          'Promedio ${promedio.toStringAsFixed(1)}'
          '${marcas.isEmpty ? '' : ' · ${marcas.join(' · ')}'}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(
          definitiva == null ? '—' : notaEscrita(definitiva),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _config.esPerdida(definitiva)
                ? Colors.red[700]
                : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// El periodo cerrado se avisa arriba y los campos se dejan en gris, en vez
  /// de esconderlos: un campo que desaparece parece un fallo de la app.
  Widget _buildAviso(String texto) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildResumen(LibroDeNotas actual) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '${actual.alumnos.length} alumnos',
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }

  Widget _buildUnidad(LibroDeNotas actual, UnidadModel unidad) {
    final numero = actual.unidades.indexOf(unidad) + 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$numero. ${unidad.definicion}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  porcentajeEscrito(unidad.porcentaje),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (unidad.subunidades.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'Sin ${_config.subunidades.toLowerCase()}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            ...unidad.subunidades.map(
              (s) => _buildSubunidad(actual, unidad, s),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildSubunidad(
    LibroDeNotas actual,
    UnidadModel unidad,
    SubunidadModel subunidad,
  ) {
    final total = actual.alumnos.length;
    final puestas = actual.notasPuestasEn(subunidad.id);
    final faltan = total - puestas;
    final numero = unidad.subunidades.indexOf(subunidad) + 1;

    return ListTile(
      dense: true,
      onTap: () => _abrirPlanilla(unidad, subunidad),
      title: Text(
        '$numero. ${subunidad.definicion}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        faltan > 0
            ? '${porcentajeEscrito(subunidad.porcentaje)} · faltan $faltan'
            : '${porcentajeEscrito(subunidad.porcentaje)} · $total notas',
        style: TextStyle(
          fontSize: 11,
          color: faltan > 0 ? Colors.orange[800] : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.edit_outlined,
        size: 18,
        color: kPrimaryColor.withValues(alpha: 0.7),
      ),
    );
  }
}
