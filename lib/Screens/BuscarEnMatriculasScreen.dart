import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/PantallaConMenu.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/RecorridoDeMatriculaScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Anchos.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Buscar en todo el colegio — pantalla 10 de `docs/estaciones.md`.
///
/// **Es la primera pieza de este módulo que funciona hoy, de verdad.**
/// `PUT buscar/por-nombre` y `por-apellido` llevan desplegadas desde mucho antes
/// que nada del día de matrículas, así que esta pantalla **no lleva
/// interruptor**: buscar funciona. Lo que espera a un despliegue es abrir el
/// recorrido de lo que se encuentre.
///
/// ## Todo el colegio, no solo la cola
///
/// Es lo que pidió la pregunta original: quien atiende una estación tiene que
/// poder mirar a **cualquiera**, no solo a los cuatro que tiene en la fila,
/// porque a mitad de mañana se acerca una mamá a preguntar *«¿y mi hija en qué
/// va?»* y no está en su cola: está en la de otro.
///
/// ## En tablet, la lista y el recorrido a la vez
///
/// Decidido el 20 sep 2026: **celular y tablet**. A partir de
/// `Anchos.maestroDetalle` (900 px) esto deja de navegar y se parte en dos —la
/// lista a la izquierda, el recorrido a la derecha—, que es el «problema 2» de
/// `docs/tablets.md`. Por debajo de 900 no cambia nada.
///
/// **Aquí eso vale más que en el libro de notas**: en una columna estirada, cada
/// persona que se mira cuesta ir y volver, y quien pregunta está de pie delante.
class BuscarEnMatriculasScreen extends StatefulWidget {
  const BuscarEnMatriculasScreen({super.key, this.servidor});

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  @override
  State<BuscarEnMatriculasScreen> createState() =>
      _BuscarEnMatriculasScreenState();
}

class _BuscarEnMatriculasScreenState extends State<BuscarEnMatriculasScreen> {
  late final Server server = widget.servidor ?? Server();
  final _drawerController = ZoomDrawerController();
  final _campo = TextEditingController();

  List<PersonaEncontrada> encontradas = [];
  PersonaEncontrada? elegida;

  bool buscando = false;
  String? error;
  bool yaBusco = false;

  Timer? _espera;

  /// Lo que se espera desde la última tecla antes de preguntar.
  ///
  /// Sin esto, escribir «Mejía» son cinco búsquedas y **cada una son dos
  /// peticiones** —nombre y apellido— con un `LIKE '%…%'` sin límite detrás.
  /// Diez son cien peticiones por una persona buscada, sobre un hosting de un
  /// núcleo.
  static const Duration _loQueSeEspera = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    Analitica.evento('buscar_matriculas_abierta');
  }

  @override
  void dispose() {
    _espera?.cancel();
    _campo.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(_loQueSeEspera, () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    if (texto.trim().length < letrasMinimasParaBuscar) {
      setState(() {
        encontradas = [];
        yaBusco = false;
        error = null;
      });
      return;
    }

    setState(() {
      buscando = true;
      error = null;
    });

    try {
      final salieron = await buscarPersonas(server, texto);
      setState(() {
        encontradas = salieron;
        buscando = false;
        yaBusco = true;
      });
    } catch (err) {
      setState(() {
        error = '$err'.replaceFirst('Exception: ', '');
        buscando = false;
        yaBusco = true;
      });
    }
  }

  bool _hayEspacioParaLosDos(BuildContext context) =>
      MediaQuery.of(context).size.width >= Anchos.maestroDetalle;

  @override
  Widget build(BuildContext context) {
    return PantallaConMenu(
      controller: _drawerController,
      pantalla: Scaffold(
        backgroundColor: PaletaEstaciones.fondo,
        appBar: AppBar(
          title: TituloPantalla(
            titulo: 'Buscar',
            subtitulo: _subtitulo(),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _drawerController.toggle!(),
          ),
        ),
        body: _hayEspacioParaLosDos(context)
            ? _maestroDetalle()
            : ColumnaDeFicha(child: _laColumna()),
      ),
    );
  }

  String? _subtitulo() {
    if (!yaBusco) return null;
    if (encontradas.isEmpty) return null;
    return encontradas.length == 1
        ? 'Una persona'
        : '${encontradas.length} personas';
  }

  /// Tablet: la lista a la izquierda y el recorrido a la derecha, sin navegar.
  Widget _maestroDetalle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: Anchos.maestro, child: _laColumna()),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _elDetalle()),
      ],
    );
  }

  Widget _elDetalle() {
    final quien = elegida;

    if (quien == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            encontradas.isEmpty
                ? 'Busca a alguien por su nombre o su apellido.'
                : 'Toca a alguien de la lista para ver su recorrido.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return ColumnaDeFicha(
      child: RecorridoDeMatriculaScreen(
        // La clave hace que Flutter reconozca que es otra persona. Sin ella, el
        // panel derecho reusaría el State del anterior.
        key: ValueKey(quien.alumnoId),
        alumnoId: quien.alumnoId,
        nombre: quien.nombreCompleto,
        fotoNombre: quien.fotoNombre,
        grupo: quien.grupo,
        servidor: widget.servidor,
        encajada: true,
      ),
    );
  }

  Widget _laColumna() {
    return Column(
      children: [
        _elCampo(),
        Expanded(child: _laLista()),
      ],
    );
  }

  Widget _elCampo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: TextField(
        controller: _campo,
        onChanged: _alEscribir,
        autofocus: false,
        textInputAction: TextInputAction.search,
        onSubmitted: _buscar,
        decoration: InputDecoration(
          hintText: 'Nombre o apellido',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _campo.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _campo.clear();
                    _buscar('');
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _laLista() {
    if (buscando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return _Centrado(
        icono: Icons.cloud_off,
        texto: error!,
        accion: TextButton(
          onPressed: () => _buscar(_campo.text),
          child: const Text('Reintentar'),
        ),
      );
    }

    if (!yaBusco) {
      return const _Centrado(
        icono: Icons.search,
        // Se dice el mínimo y POR QUÉ busca solo por esos dos campos: quien lo
        // lee es quien puede pedir que busque también por documento.
        texto: 'Escribe al menos tres letras del nombre o del apellido.\n\n'
            'Hoy el servidor solo sabe buscar por esos dos: por documento o por '
            'el código de la hoja todavía no. Está pedido.',
      );
    }

    if (encontradas.isEmpty) {
      return const _Centrado(
        icono: Icons.person_off_outlined,
        texto: 'Nadie con ese nombre en este año.\n\nPrueba con el apellido, o '
            'con menos letras.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: encontradas.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _TarjetaEncontrada(
          persona: encontradas[i],
          elegida: encontradas[i].alumnoId == elegida?.alumnoId,
          alTocar: () => _abrir(encontradas[i]),
        ),
      ),
    );
  }

  void _abrir(PersonaEncontrada persona) {
    if (_hayEspacioParaLosDos(context)) {
      // En tablet no se navega: cambia el panel de la derecha.
      setState(() => elegida = persona);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'recorrido-de-matricula'),
        builder: (_) => RecorridoDeMatriculaScreen(
          alumnoId: persona.alumnoId,
          nombre: persona.nombreCompleto,
          fotoNombre: persona.fotoNombre,
          grupo: persona.grupo,
          servidor: widget.servidor,
        ),
      ),
    );
  }
}

class _TarjetaEncontrada extends StatelessWidget {
  const _TarjetaEncontrada({
    required this.persona,
    required this.elegida,
    required this.alTocar,
  });

  final PersonaEncontrada persona;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida ? PaletaEstaciones.primarioSuave : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  elegida ? PaletaEstaciones.primario : PaletaEstaciones.borde,
            ),
          ),
          child: Row(
            children: [
              // La foto y no unas iniciales: en una fila con dos hermanos
              // apellidados igual, la cara es lo que distingue.
              AvatarPersona(
                nombre: persona.nombreCompleto,
                fotoNombre: persona.fotoNombre,
                radio: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: PaletaEstaciones.tinta,
                      ),
                    ),
                    if (persona.grupo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        persona.grupo!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PaletaEstaciones.tintaSuave,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: PaletaEstaciones.tintaApagada,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centrado extends StatelessWidget {
  const _Centrado({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Anchos.formulario),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 40, color: Colors.black26),
              const SizedBox(height: 12),
              Text(texto, textAlign: TextAlign.center),
              if (accion != null) ...[const SizedBox(height: 12), accion!],
            ],
          ),
        ),
      ),
    );
  }
}
