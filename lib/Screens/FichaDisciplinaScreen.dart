import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/DisciplinaApi.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Models/ConfigDisciplinaModel.dart';
import 'package:myvc_flutter/Models/OrdinalModel.dart';
import 'package:myvc_flutter/Models/SituacionModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Models/UniformeModel.dart';
import 'package:myvc_flutter/Screens/FaltasAlumnoScreen.dart';
import 'package:myvc_flutter/Screens/SituacionEditorScreen.dart';
import 'package:myvc_flutter/Screens/UniformesAlumnoScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/constantes.dart';

/// Con qué se abre la ficha.
class FichaDisciplinaArgs {
  final AlumnoDisciplinaModel alumno;
  final DatosDisciplina datos;
  final List<DocenteModel> docentes;

  /// user_id -> nombre, para decir quién registró cada situación.
  final Map<int, String> nombresPorUsuario;

  final int grupoId;
  final int periodoInicial;

  FichaDisciplinaArgs({
    required this.alumno,
    required this.datos,
    required this.grupoId,
    required this.periodoInicial,
    this.docentes = const [],
    this.nombresPorUsuario = const {},
  });
}

/// La ficha de disciplina de un alumno: su año entero, periodo a periodo.
///
/// Es la columna de la tabla del front web puesta de pie. Allí los cuatro
/// periodos van uno al lado de otro y cada celda despliega su detalle; aquí se
/// elige el periodo arriba y debajo va todo lo suyo, porque cuatro columnas de
/// contadores en un teléfono se quedan en cuatro columnas de nada.
///
/// Nada de lo que se ve se vuelve a pedir: el alumno llega entero desde el
/// listado, y las escrituras devuelven el alumno recalculado. La única
/// excepción son los uniformes, cuyos endpoints no devuelven al alumno; esa
/// pantalla devuelve su lista y se mete en su sitio.
///
/// Al cerrarse devuelve el alumno como quedó, o null si no cambió nada.
class FichaDisciplinaScreen extends StatefulWidget {
  final FichaDisciplinaArgs args;

  const FichaDisciplinaScreen({super.key, required this.args});

  @override
  State<FichaDisciplinaScreen> createState() => _FichaDisciplinaScreenState();
}

class _FichaDisciplinaScreenState extends State<FichaDisciplinaScreen> {
  late AlumnoDisciplinaModel alumno;
  late int periodo;

  /// Si algo cambió, para no despertar al listado sin motivo.
  bool huboCambios = false;

  ConfigDisciplinaModel get config => widget.args.datos.config;

  List<OrdinalModel> get catalogo => widget.args.datos.ordinales;

  @override
  void initState() {
    super.initState();
    alumno = widget.args.alumno;
    periodo = widget.args.periodoInicial;
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Los periodos que se pueden mirar.
  ///
  /// Los del alumno cuando el backend mandó alguno; si no, los del año. Un
  /// alumno recién matriculado puede no traer ninguno y la barra de periodos
  /// no puede quedarse vacía.
  List<int> get _periodos {
    final suyos = alumno.periodos;
    if (suyos.isNotEmpty) return suyos;

    final delYear = ContextoAcademico.instancia.periodosDelYear;
    if (delYear.isNotEmpty) return delYear.map((p) => p.numero).toList();

    return const [1, 2, 3, 4];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<AlumnoDisciplinaModel>(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) {
        if (yaSalio) return;
        Navigator.pop(context, huboCambios ? alumno : null);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              AvatarPersona(
                nombre: alumno.nombreCompleto,
                fotoNombre: alumno.fotoNombre,
                radio: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TituloPantalla(
                  titulo: alumno.nombreCompleto,
                  subtitulo: 'Ficha de disciplina',
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirEditor(),
          icon: Icon(Icons.add),
          label: Text('Nueva situación'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _cabecera(),
            _barraDePeriodos(),
            Divider(height: 1),
            _resumenDelPeriodo(),
            Divider(height: 1),
            for (final tipo in ConfigDisciplinaModel.tipos) _bloqueDeTipo(tipo),
          ],
        ),
      ),
    );
  }

  /// Solo el aviso de que es asistente, que cambia cómo se lee su ficha. El
  /// nombre y la foto están arriba, en la barra.
  Widget _cabecera() {
    if (!alumno.esAsistente) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: Colors.black45),
          const SizedBox(width: 6),
          Text(
            'Asistente · no matriculado',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Los periodos, con lo que lleva cada uno.
  Widget _barraDePeriodos() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          for (final numero in _periodos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                selected: numero == periodo,
                onSelected: (_) => setState(() => periodo = numero),
                label: Text(
                  'P$numero · ${alumno.totalDe(numero)}',
                ),
                avatar: alumno.tieneGravesEn(numero)
                    ? Icon(Icons.priority_high, size: 16)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  /// Lo que no son situaciones del manual: uniforme y faltas a la institución.
  Widget _resumenDelPeriodo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: _Ficha(
              icono: Icons.checkroom_outlined,
              rotulo: 'Uniforme',
              cuantos: alumno.cuantosUniformes(periodo),
              alTocar: _abrirUniformes,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Ficha(
              icono: Icons.schedule_outlined,
              rotulo: 'Tardanzas',
              color: kColorTardanza,
              cuantos: alumno.cuantasFaltas(periodo, TipoFalta.tardanza),
              alTocar: _abrirFaltas,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Ficha(
              icono: Icons.event_busy_outlined,
              rotulo: 'Ausencias',
              color: kColorAusencia,
              cuantos: alumno.cuantasFaltas(periodo, TipoFalta.ausencia),
              alTocar: _abrirFaltas,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueDeTipo(int tipo) {
    final situaciones = alumno.situacionesDeTipo(periodo, tipo);
    final cuantas = alumno.cuantasSituaciones(periodo, tipo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.black.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  config.nombres(tipo),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$cuantas',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cuantas == 0 ? Colors.black38 : kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
        if (situaciones.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              'Ninguna en el periodo $periodo.',
              style: TextStyle(
                  color: Colors.black45, fontStyle: FontStyle.italic),
            ),
          )
        else
          for (final situacion in situaciones) _fila(situacion),
      ],
    );
  }

  Widget _fila(SituacionModel situacion) {
    final ordinales = situacion.ordinalesDe(catalogo);
    final registro = _quienRegistro(situacion);
    final absorbidas = alumno.absorbidasPor(situacion.id).length;

    return InkWell(
      onTap: () => _abrirEditor(situacion: situacion),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  situacion.fecha == null
                      ? 'Sin día'
                      : formatoDia(situacion.fecha),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(situacion.descripcion)),
                Icon(Icons.chevron_right, size: 18, color: Colors.black26),
              ],
            ),
            if (situacion.absorbida)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Nota(
                  icono: Icons.call_merge,
                  texto: 'Derivó en otra situación, así que no cuenta aparte',
                ),
              ),
            if (situacion.derivaDeTardanzas)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Nota(
                  icono: Icons.schedule,
                  texto: 'Se puso por acumular tardanzas al colegio',
                ),
              ),
            if (absorbidas > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Nota(
                  icono: Icons.call_received,
                  // De dónde viene esta: se llevó por delante a otras, que
                  // por eso dejaron de contar en su propio periodo.
                  texto: absorbidas == 1
                      ? 'Viene de otra situación, que ya no cuenta aparte'
                      : 'Viene de $absorbidas situaciones, que ya no cuentan '
                          'aparte',
                ),
              ),
            if (situacion.profesorNombre != null)
              _Detalle(rotulo: 'Docente', texto: situacion.profesorNombre!),
            if (situacion.testigos != null)
              _Detalle(rotulo: 'Testigos', texto: situacion.testigos!),
            if (situacion.descargo != null)
              _Detalle(rotulo: 'Descargo', texto: situacion.descargo!),
            if (registro != null)
              _Detalle(rotulo: 'Registró', texto: registro),
            if (ordinales.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final ordinal in ordinales)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.gavel,
                                size: 13, color: Colors.black45),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ordinal.rotulo,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Divider(height: 20),
          ],
        ),
      ),
    );
  }

  /// Quién la anotó y cuándo, si se sabe.
  ///
  /// `added_by` es un `user_id`; el nombre sale del cruce que trajo el
  /// listado. Cuando ese usuario no está entre los docentes con contrato del
  /// año —una secretaría, alguien que ya no está— se queda el número, que al
  /// menos permite preguntar.
  String? _quienRegistro(SituacionModel situacion) {
    final id = situacion.registradaPor;
    if (id == null) return null;

    final nombre = widget.args.nombresPorUsuario[id] ?? 'Usuario $id';
    final cuando = situacion.registradaEl;

    return cuando == null ? nombre : '$nombre · ${formatoDia(cuando)}';
  }

  Future<void> _abrirEditor({SituacionModel? situacion}) async {
    final periodoId = ContextoAcademico.instancia.periodoIdDe(periodo);

    if (periodoId == null) {
      _avisar('No se sabe cuál es el periodo $periodo de este año.');
      return;
    }

    final actualizado = await Navigator.push<AlumnoDisciplinaModel>(
      context,
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'situacion-editor'),
        builder: (_) => SituacionEditorScreen(
          args: SituacionEditorArgs(
            alumno: alumno,
            datos: widget.args.datos,
            numeroPeriodo: periodo,
            periodoId: periodoId,
            docentes: widget.args.docentes,
            situacion: situacion,
          ),
        ),
      ),
    );

    if (actualizado == null) return;

    setState(() {
      alumno = actualizado;
      huboCambios = true;
    });
  }

  Future<void> _abrirUniformes() async {
    final periodoId = ContextoAcademico.instancia.periodoIdDe(periodo);

    if (periodoId == null) {
      _avisar('No se sabe cuál es el periodo $periodo de este año.');
      return;
    }

    final devueltas = await Navigator.push<List<UniformeModel>>(
      context,
      MaterialPageRoute(
        // Con nombre para que la analítica no la vea como un hueco: el
        // observador de pantallas solo registra las rutas que lo tienen.
        settings: const RouteSettings(name: 'disciplina-uniformes'),
        builder: (_) => UniformesAlumnoScreen(
          args: UniformesAlumnoArgs(
            alumnoId: alumno.alumnoId,
            nombre: alumno.nombreCompleto,
            fotoNombre: alumno.fotoNombre,
            numeroPeriodo: periodo,
            periodoId: periodoId,
            uniformes: alumno.uniformesDe(periodo),
          ),
        ),
      ),
    );

    if (devueltas == null) return;

    setState(() {
      alumno = alumno.conUniformesDe(periodo, devueltas);
      huboCambios = true;
    });
  }

  /// Las tardanzas y ausencias a la institución se corrigen donde ya se
  /// corregían: en la pantalla que hay desde antes, que enseña el año entero y
  /// deja arreglar el día de cada una.
  Future<void> _abrirFaltas() async {
    await Navigator.pushNamed(
      context,
      '/faltas-alumno',
      arguments: FaltasAlumnoArgs(
        alumnoId: alumno.alumnoId,
        nombre: alumno.nombreCompleto,
        grupoId: widget.args.grupoId,
        fotoNombre: alumno.fotoNombre,
      ),
    );
  }
}

/// Uno de los tres contadores de arriba.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.icono,
    required this.rotulo,
    required this.cuantos,
    required this.alTocar,
    this.color,
  });

  final IconData icono;
  final String rotulo;
  final int cuantos;
  final VoidCallback alTocar;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tono = color ?? kPrimaryColor;
    final hay = cuantos > 0;

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: hay ? tono.withValues(alpha: 0.10) : Colors.transparent,
          border: Border.all(
            color: hay ? tono.withValues(alpha: 0.5) : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icono, size: 20, color: hay ? tono : Colors.black38),
            const SizedBox(height: 4),
            Text(
              '$cuantos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: hay ? tono : Colors.black38,
              ),
            ),
            Text(
              rotulo,
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una línea de «rótulo: texto» dentro de una situación.
class _Detalle extends StatelessWidget {
  const _Detalle({required this.rotulo, required this.texto});

  final String rotulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.black54),
          children: [
            TextSpan(
              text: '$rotulo: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: texto),
          ],
        ),
      ),
    );
  }
}

/// Un aviso corto dentro de una situación.
class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 14, color: Colors.orange[800]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12, color: Colors.orange[800]),
          ),
        ),
      ],
    );
  }
}
