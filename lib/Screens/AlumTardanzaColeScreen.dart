import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/Widgets/ControlOcupado.dart';
import 'package:myvc_flutter/Widgets/FondoFalta.dart';
import 'package:myvc_flutter/constantes.dart';
import 'package:myvc_flutter/Screens/AsistenciaClaseScreen.dart';
import 'package:myvc_flutter/Screens/FaltasAlumnoScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlumTardanzaColeScreen extends StatefulWidget {
  const AlumTardanzaColeScreen({super.key});

  @override
  _AlumTardanzaColeScreen createState() => _AlumTardanzaColeScreen();
}

class _AlumTardanzaColeScreen extends State<AlumTardanzaColeScreen> {
  Server server = Server();
  List<AlumnoModel>? alumnos;
  GrupoModel? grupo;

  /// Los alumnos del grupo, pedidos una sola vez.
  ///
  /// El Future vive aquí y no dentro de `build()`: creado allí, cada setState
  /// —poner una falta, quitarla, cambiar el día— fabricaba uno nuevo, el
  /// FutureBuilder lo veía cambiar y volvía a `waiting`. Se cerraba el panel
  /// del alumno que estuviera abierto, salía la rueda de carga y se disparaba
  /// una petición PUT /asistencias/detailed de más por cada botón pulsado.
  ///
  /// Cambiar de día no lo recarga: el backend manda las faltas de todo el
  /// periodo y el día se filtra aquí.
  Future<List<AlumnoModel>>? _alumnosFuture;
  /// Los contadores que están esperando respuesta del servidor.
  ///
  /// Uno por alumno y tipo de falta, no uno para toda la pantalla: mientras se
  /// guarda la tardanza de un alumno, los botones de los demás siguen vivos.
  final Set<String> _guardando = {};

  DateTime? today; // la cambio en init
  DateTime? _selectedDate;
  final _drawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    _selectedDate = today;

    traerGrupo();
  }

  Future<void> _selectDate() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void traerGrupo() {
    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      String? grupoString = preferences.getString('grupoSelected');

      if (!mounted) return;

      if (grupoString != null) {
        setState(() {
          grupo = GrupoModel.fromRawJson(grupoString);
          _alumnosFuture = traerAlumnosModel();
        });
      } else {
        Navigator.pushNamed(context, '/panel');
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El mismo menú y la misma forma de abrirlo que en el inicio.
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
        appBar: AppBar(
          // El grupo solo no dice a qué se ha entrado: el mismo 10-B sale en
          // asistencias, en disciplina y en notas.
          title: TituloPantalla(
            titulo: 'Asistencia al colegio',
            subtitulo: grupo?.nombre,
          ),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () => _drawerController.toggle!(),
          ),
        ),
        body: grupo == null
            ? Text('Esperando alumnos en build...')
            : _buildFutureBuilder(),
      ),
    );
  }

  Widget _buildFutureBuilder() {
    return FutureBuilder<List<AlumnoModel>>(
      future: _alumnosFuture,
      builder: (BuildContext context, AsyncSnapshot<List<AlumnoModel>> snapshot) {
        if (snapshot.hasError) {
          return _errorAlTraer('${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        // Tirar hacia abajo recarga: es la única forma de volver a pedir la
        // lista ahora que ya no se rehace sola en cada toque.
        return RefreshIndicator(
          onRefresh: _recargarAlumnos,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildListaGrupos(),
          ),
        );
      },
    );
  }

  Future<void> _recargarAlumnos() async {
    final pedido = traerAlumnosModel();
    setState(() => _alumnosFuture = pedido);
    await pedido;
  }

  Widget _errorAlTraer(String detalle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudieron traer los alumnos del grupo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _recargarAlumnos,
              child: Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<AlumnoModel>> traerAlumnosModel() async {
    var argum = {'grupo_id': '${grupo!.id}', 'con_grupos': false};

    var response = await server.put('/asistencias/detailed', argum);
    final List alumnosList = jsonDecode(response.body)['alumnos'];
    List<AlumnoModel> alumnosTemp =
        alumnosList.map((e) => AlumnoModel.fromJson(e)).toList();

    alumnos = alumnosTemp;

    return alumnos as List<AlumnoModel>;
  }

  /// La fila del alumno, con el color de lo que tenga ese día.
  ///
  /// El color se pinta aquí y no en el `backgroundColor` del panel: ese tiñe la
  /// tarjeta entera y se llevaba por delante el formulario de dentro. Así la
  /// franja de color se queda en la cabecera, que es lo que hay que ver de un
  /// vistazo recorriendo la lista.
  Widget buildTile(AlumnoModel alumno, DateTime dia) {
    return Container(
      decoration: _fondoDelDia(alumno, dia),
      child: ListTile(
        dense: false,
        title: Text('${alumno.apellidos} ${alumno.nombres}'),
        subtitle: Text(_resumenDelDia(alumno, dia)),
        leading: AvatarPersona(
          nombre: '${alumno.nombres} ${alumno.apellidos ?? ''}',
          fotoNombre: alumno.fotoNombre,
        ),
      ),
    );
  }

  BoxDecoration? _fondoDelDia(AlumnoModel alumno, DateTime dia) => fondoDeFaltas(
        tardanza: alumno.tieneTardanzaEn(dia),
        ausencia: alumno.tieneAusenciaEn(dia),
      );

  Color? _colorTrasLaFlecha(AlumnoModel alumno, DateTime dia) =>
      colorFinalDeFaltas(
        tardanza: alumno.tieneTardanzaEn(dia),
        ausencia: alumno.tieneAusenciaEn(dia),
      );

  Widget _buildListaGrupos() {
    final dia = _selectedDate ?? today!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Fecha: ${formatoDia(dia)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: _selectDate,
              ),
            ],
          ),
        ),
        ExpansionPanelList.radio(
          children: alumnos!
              .map((AlumnoModel alumno) => ExpansionPanelRadio(
                    // El color del día va en la cabecera, no aquí: este tiñe
                    // toda la tarjeta. Lo único que se le deja es el extremo
                    // derecho, donde vive la flecha de abrir, para que la
                    // franja de la cabecera no se corte antes de tiempo.
                    backgroundColor: _colorTrasLaFlecha(alumno, dia),
                    canTapOnHeader: true,
                    value: '${alumno.apellidos} ${alumno.nombres}',
                    headerBuilder: (context, isExpanded) =>
                        buildTile(alumno, dia),
                    // Fondo propio: sin esto el cuerpo hereda el color de la
                    // cabecera y el formulario queda ilegible.
                    body: Container(
                      color: Colors.white,
                      child: _buildCuerpoAlumno(alumno, dia),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// El cuerpo del panel del alumno.
  ///
  /// Dos secciones, porque son dos cosas distintas y antes estaban revueltas:
  ///
  ///   - La institución: llegó tarde al colegio, o no vino en todo el día.
  ///     Se pone aquí mismo, referido al día elegido arriba.
  ///   - Cada asignatura: las faltas de una clase concreta, que dependen del
  ///     docente y del horario. Eso vive en su propia pantalla.
  Widget _buildCuerpoAlumno(AlumnoModel alumno, DateTime dia) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotulo('En la institución', 'El ${formatoDia(dia)}'),
          _filaContador(alumno, dia, TipoFalta.tardanza),
          const SizedBox(height: 8),
          _filaContador(alumno, dia, TipoFalta.ausencia),
          const SizedBox(height: 14),
          Text(
            'En el periodo: '
            '${TipoFalta.tardanza.contar(_totalDe(alumno, TipoFalta.tardanza))}'
            ' · '
            '${TipoFalta.ausencia.contar(_totalDe(alumno, TipoFalta.ausencia))}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _botonAncho(
            icono: Icons.history,
            texto: 'Ver histórico del año',
            onPressed: () => _verHistorico(alumno),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _rotulo('En cada asignatura', 'Las faltas de cada clase, por materia'),
          const SizedBox(height: 4),
          _botonAncho(
            icono: Icons.class_outlined,
            texto: 'Asistencia a clases',
            onPressed: () => _verAsistenciaClases(alumno),
          ),
        ],
      ),
    );
  }

  Widget _rotulo(String titulo, String detalle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(
            detalle,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Una línea de contador: el rótulo a la izquierda y los botones a la derecha.
  ///
  /// Lo que cuenta es lo del día elegido, no el total del periodo: el botón de
  /// quitar borra una falta de ese día, y si no hay ninguna lo dice en vez de
  /// llevarse por delante la última de otra fecha.
  Widget _filaContador(AlumnoModel alumno, DateTime dia, TipoFalta tipo) {
    final delDia = _faltasDelDia(alumno, dia, tipo).length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tipo.titulo,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                tipo.explicacion,
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
        ),
        // Los tres van dentro del mismo envoltorio: mientras se guarda, el
        // número que se ve todavía es el de antes, así que tampoco tiene
        // sentido dejarlo nítido.
        ControlOcupado(
          ocupado: _guardando.contains(_claveContador(alumno, tipo)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _botonContador(
                icono: Icons.remove,
                color: delDia == 0 ? Colors.grey.shade400 : Colors.redAccent,
                onPressed: () => _mientrasGuarda(alumno, tipo,
                    () => _quitarFalta(alumno, dia, tipo)),
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '$delDia',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              _botonContador(
                icono: Icons.add,
                color: Colors.green,
                onPressed: () => _mientrasGuarda(alumno, tipo,
                    () => _agregarFalta(alumno, dia, tipo)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonAncho({
    required IconData icono,
    required String texto,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: kPrimaryColor),
        foregroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  String _claveContador(AlumnoModel alumno, TipoFalta tipo) =>
      '${alumno.id}-${tipo.valor}';

  /// Marca el contador como ocupado mientras corre [tarea].
  ///
  /// El `finally` es lo que importa: si la petición falla, los botones tienen
  /// que volver, o el docente se queda sin poder reintentar.
  Future<void> _mientrasGuarda(
      AlumnoModel alumno, TipoFalta tipo, Future<void> Function() tarea) async {
    final clave = _claveContador(alumno, tipo);
    if (_guardando.contains(clave)) return;

    setState(() => _guardando.add(clave));
    try {
      await tarea();
    } finally {
      setState(() => _guardando.remove(clave));
    }
  }

  Widget _botonContador({
    required IconData icono,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
      ),
      child: Icon(icono, size: 22),
    );
  }

  /// Lo que tiene el alumno ese día, para la línea de debajo del nombre.
  String _resumenDelDia(AlumnoModel alumno, DateTime dia) {
    final tardanzas = alumno.tardanzasDelDia(dia).length;
    final ausencias = alumno.ausenciasDelDia(dia).length;

    if (tardanzas == 0 && ausencias == 0) {
      return 'Sin faltas el ${formatoDia(dia)}';
    }

    final partes = <String>[
      if (ausencias > 0) TipoFalta.ausencia.contar(ausencias),
      if (tardanzas > 0) TipoFalta.tardanza.contar(tardanzas),
    ];

    return '${partes.join(' · ')} el ${formatoDia(dia)}';
  }

  List<AsistenciaModel> _faltasDelDia(
      AlumnoModel alumno, DateTime dia, TipoFalta tipo) {
    return tipo == TipoFalta.tardanza
        ? alumno.tardanzasDelDia(dia)
        : alumno.ausenciasDelDia(dia);
  }

  /// La lista donde vive ese tipo de falta, creada si aún no existía.
  List<AsistenciaModel> _listaDe(AlumnoModel alumno, TipoFalta tipo) {
    if (tipo == TipoFalta.tardanza) {
      return alumno.tardanzasEntrada ??= [];
    }
    return alumno.ausenciasEntrada ??= [];
  }

  int _totalDe(AlumnoModel alumno, TipoFalta tipo) =>
      alumno.ausenciasTotal?[tipo.claveTotal] ?? 0;

  Future<void> _agregarFalta(
      AlumnoModel alumno, DateTime dia, TipoFalta tipo) async {
    final dynamic res;
    try {
      // entrada: 1 es lo que la marca como falta a la institución y no a una
      // clase; el tipo separa la tardanza de la ausencia. Es lo mismo que manda
      // la pantalla de asistencias del front web.
      res = await server.post('/ausencias/store', {
        'alumno_id': alumno.id,
        'entrada': 1,
        'tipo': tipo.valor,
        'fecha_hora': faltaDelDiaParaServidor(dia),
      });
    } catch (err) {
      _aviso('No se pudo registrar la ${tipo.singular}: $err');
      return;
    }

    if (res.statusCode >= 300) {
      _aviso('No se pudo registrar la ${tipo.singular}'
          ' (HTTP ${res.statusCode}).');
      return;
    }

    // De aquí en adelante el servidor ya la guardó. Lo que falle al leer su
    // respuesta es un problema de pintar la pantalla, no de registrar la
    // falta: decir «error» aquí hace que el docente vuelva a pulsar y queden
    // dos filas por la misma tardanza.
    //
    // POST /ausencias/store devuelve la fila recién creada —el controlador
    // hace `return $aus` sobre el modelo de Eloquent—, así que lo normal es
    // que se lea entera; pero viene de SQL a pelo, sin casts, y los tipos los
    // decide el driver.
    AsistenciaModel? creada;
    try {
      creada = AsistenciaModel.fromJson(jsonDecode(res.body));
    } catch (_) {
      creada = null;
    }

    if (creada == null) {
      _aviso(
        '${_conMayuscula(tipo.singular)} registrada el ${formatoDia(dia)},'
        ' pero la lista no pudo actualizarse sola: tira hacia abajo para'
        ' refrescar.',
        error: false,
      );
      return;
    }

    setState(() {
      _listaDe(alumno, tipo).add(creada!);
      alumno.ausenciasTotal?[tipo.claveTotal] = _totalDe(alumno, tipo) + 1;
    });

    _aviso('${_conMayuscula(tipo.singular)} registrada el ${formatoDia(dia)}.',
        error: false);
  }

  Future<void> _quitarFalta(
      AlumnoModel alumno, DateTime dia, TipoFalta tipo) async {
    final delDia = _faltasDelDia(alumno, dia, tipo);

    if (delDia.isEmpty) {
      _aviso('No hay ${tipo.plural} del ${formatoDia(dia)} para quitar.');
      return;
    }

    final falta = delDia.last;

    try {
      final res = await server.delete('/ausencias/destroy/${falta.id}');

      if (res.statusCode >= 300) {
        _aviso('No se pudo eliminar la ${tipo.singular}'
            ' (HTTP ${res.statusCode}).');
        return;
      }

      setState(() {
        _listaDe(alumno, tipo).remove(falta);
        alumno.ausenciasTotal?[tipo.claveTotal] = _totalDe(alumno, tipo) - 1;
      });

      _aviso(
          '${_conMayuscula(tipo.singular)} del ${formatoDia(dia)} eliminada.',
          error: false);
    } catch (err) {
      _aviso('Error eliminando la ${tipo.singular}: $err');
    }
  }

  String _conMayuscula(String palabra) =>
      palabra.isEmpty ? palabra : palabra[0].toUpperCase() + palabra.substring(1);

  void _verAsistenciaClases(AlumnoModel alumno) {
    Navigator.pushNamed(
      context,
      '/asistencia-clase',
      arguments: AsistenciaClaseArgs(
        alumnoId: alumno.id,
        nombre: '${alumno.apellidos} ${alumno.nombres}',
        grupoId: grupo!.id,
        fotoNombre: alumno.fotoNombre,
      ),
    );
  }

  /// El histórico por periodos: tardanzas y ausencias de todo un año.
  void _verHistorico(AlumnoModel alumno) {
    Navigator.pushNamed(
      context,
      '/faltas-alumno',
      arguments: FaltasAlumnoArgs(
        alumnoId: alumno.id,
        nombre: '${alumno.apellidos} ${alumno.nombres}',
        grupoId: grupo!.id,
        fotoNombre: alumno.fotoNombre,
      ),
    );
  }

  void _aviso(String mensaje, {bool error = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? Colors.red.shade700 : Colors.lightBlueAccent,
        ),
      );
  }
}
