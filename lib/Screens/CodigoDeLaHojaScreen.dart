import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/NotasDeEstacionScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// El código de la hoja de ruta, **tecleado** — pantalla 03.
///
/// ## Aquí no hay cámara, y es una decisión con precio medido
///
/// **Decidido por Joseth el 20 sep 2026: el escáner no entra por ahora, para no
/// tocar los permisos de las dos tiendas.** Teclear `2027-4K7M2` no cuesta
/// nada; la cámara cuesta esto (`docs/seguridad-datos-play.md`):
///
/// - `android.permission.CAMERA` es de las peligrosas y **sale en la lista de
///   permisos de la ficha de Play**, que los dieciséis colegios ven cambiar.
/// - Y la que no avisa: los paquetes de escáner meten solos un
///   `<uses-feature android:name="android.hardware.camera">` y, sin
///   `required="false"`, **Play deja de ofrecer la app a los aparatos sin
///   cámara** — que es justo la tablet del patio. No falla nada y no llega
///   ningún correo: la app se desaparece.
/// - En iOS, sin `NSCameraUsageDescription` la app **se cae** al abrir la
///   cámara.
///
/// Así que esta pantalla es un campo de texto y nada más, y está **entera**: lo
/// único que espera es `GET estaciones/codigo/{codigo}`.
///
/// ## El código es el que ya existe, y también sirve el del papel viejo
///
/// Es el del formulario de inscripción (`docs/migracion/41`), no uno nuevo:
/// acuñar otro habría sido un segundo papel para la misma familia. Y el
/// servidor busca también por `codigo_anterior`, **porque el papel viejo está
/// en casa de una familia** y quien lo teclee tiene que llegar a su orden.
///
/// ## El 409 no es un error: es lo que hay que hacer
///
/// Un formulario del modo `nuevos` **nace sin alumno**, y hasta que secretaría
/// lo ata no hay recorrido que enseñar. El servidor manda escrito qué hacer y
/// **gana su texto**: se pinta como una instrucción, no como una pantalla roja
/// de red caída. Confundir las dos manda a alguien a buscar señal cuando lo que
/// falta es una firma en secretaría — y al revés, dar por bueno «ese código no
/// existe» cuando lo que pasó es que no hay red hace teclearlo cuatro veces.
class CodigoDeLaHojaScreen extends StatefulWidget {
  const CodigoDeLaHojaScreen({
    super.key,
    this.servidor,
    this.alEncontrar,
    this.estacion,
  });

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  /// Qué hacer con la ficha encontrada.
  ///
  /// Null es «enséñala aquí». Existe para que la cola pueda abrir esta pantalla
  /// y quedarse con la ficha **sin que esta pantalla tenga que saber a qué
  /// pantalla navegar**: quien la abre es quien sabe si hay un panel derecho
  /// donde ponerla.
  final void Function(FichaDeEstacion)? alEncontrar;

  /// La estación desde la que se teclea, si se teclea desde una.
  ///
  /// Solo para decirlo en el subtítulo y para proponerla al dejar una nota.
  /// **No filtra nada**: el código se puede teclear desde cualquier sitio.
  final Estacion? estacion;

  @override
  State<CodigoDeLaHojaScreen> createState() => _CodigoDeLaHojaScreenState();
}

class _CodigoDeLaHojaScreenState extends State<CodigoDeLaHojaScreen> {
  late final Server server = widget.servidor ?? Server();
  final TextEditingController _campo = TextEditingController();

  FichaDeEstacion? encontrada;
  bool preguntando = false;

  /// Lo que el servidor contestó **escrito**: el papel sin alumno atado, o que
  /// ese código no existe. Se pinta como instrucción, no como avería.
  String? loQueHayQueHacer;

  /// Que no se pudo ni preguntar. Eso sí es una avería, y lleva «Reintentar».
  String? sinSenal;

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_codigo_abierta');
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  /// Si se puede preguntar de verdad.
  ///
  /// Son **dos** puertas y no una, como en todo este módulo: el interruptor del
  /// día de matrículas y el de esta ruta. Apagado cualquiera, **no se llama al
  /// servidor**: las nueve rutas están escritas en el backend y sin desplegar,
  /// y una llamada por apertura son dieciséis colegios gastando un 404 sobre un
  /// hosting de un núcleo. Ver `docs/backend-pendiente.md` §8.
  bool get _sePuedePreguntar =>
      Interruptores.estaciones && PendientesEstaciones.buscarPorElCodigo;

  Future<void> _buscar() async {
    if (!_sePuedePreguntar) return;

    final codigo = elCodigoTecleado(_campo.text);
    if (codigo.isEmpty) return;

    setState(() {
      preguntando = true;
      encontrada = null;
      loQueHayQueHacer = null;
      sinSenal = null;
    });

    try {
      final ficha = await traerLaFichaPorCodigo(server, codigo);

      setState(() {
        preguntando = false;
        encontrada = ficha;
        if (ficha == null) {
          loQueHayQueHacer =
              'El servidor no mandó ninguna hoja de ruta con ese código.';
        }
      });

      if (ficha != null) widget.alEncontrar?.call(ficha);
    } catch (err) {
      setState(() {
        preguntando = false;
        if (pareceFaltaDeSenal(err)) {
          sinSenal = 'No se pudo preguntar por ese código: el teléfono no '
              'alcanzó el servidor. Vuelve a intentarlo.';
        } else {
          // Gana el texto del servidor, tal cual. Él sabe si el código no
          // existe o si el papel todavía no es de nadie.
          loQueHayQueHacer = '$err'.replaceFirst('Exception: ', '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: 'El código de la hoja',
          subtitulo: widget.estacion == null
              ? null
              : 'Estación ${widget.estacion!.nro} · ${widget.estacion!.nombre}',
          conFlecha: true,
        ),
      ),
      body: ColumnaDeFicha(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          children: [
            _elCampo(),
            if (!_sePuedePreguntar)
              _PorQueEstaApagado(
                esperaElModulo: !Interruptores.estaciones,
              ),
            if (preguntando)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (sinSenal != null)
              _LaSenal(texto: sinSenal!, alReintentar: _buscar),
            if (loQueHayQueHacer != null)
              _LoQueHayQueHacer(texto: loQueHayQueHacer!),
            if (encontrada != null)
              _LaHojaEncontrada(
                ficha: encontrada!,
                estacion: widget.estacion,
                servidor: widget.servidor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _elCampo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teclea el código de la hoja de ruta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.tinta,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'El mismo del formulario de inscripción, tal como está impreso. '
            'Sirve también el del papel viejo, si la familia trae ése.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: PaletaEstaciones.tintaSuave,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _campo,
            enabled: _sePuedePreguntar && !preguntando,
            autofocus: false,
            // Mayúsculas porque el papel viene en mayúsculas y el teclado del
            // teléfono empieza en minúscula; lo que se manda se normaliza igual
            // en [elCodigoTecleado], que es lo que de verdad lo garantiza.
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _buscar(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: '2027-4K7M2',
              hintStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
                color: PaletaEstaciones.tintaApagada,
              ),
              prefixIcon: const Icon(Icons.tag),
              suffixIcon: _campo.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _campo.clear();
                        encontrada = null;
                        loQueHayQueHacer = null;
                        sinSenal = null;
                      }),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: PaletaEstaciones.alturaDeBoton,
            child: FilledButton.icon(
              // Ni una petición por una casilla vacía: el servidor contestaría
              // 422 para decir lo que ya se sabe aquí.
              onPressed: !_sePuedePreguntar ||
                      preguntando ||
                      elCodigoTecleado(_campo.text).isEmpty
                  ? null
                  : _buscar,
              icon: const Icon(Icons.search),
              label: Text(preguntando ? 'Buscando…' : 'Buscar la hoja'),
            ),
          ),
        ],
      ),
    );
  }
}

/// El código tal como se manda: sin espacios sobrantes y en mayúsculas.
///
/// **No se le quitan ni se le ponen guiones.** El servidor compara contra
/// `codigo` y `codigo_anterior` tal cual están guardados, y un código
/// «arreglado» por la app sería un 404 que nadie sabría explicar. Lo que sí se
/// arregla es lo que el teclado del teléfono hace solo: la minúscula y el
/// espacio de más al pegar.
///
/// Pública para que una prueba la alcance: detrás de dos interruptores en
/// `false` no hay forma de llegar a ella por la pantalla.
String elCodigoTecleado(String crudo) => crudo.trim().toUpperCase();

/// Si el fallo es «no hubo forma de preguntar» y no «el servidor contestó».
///
/// ## Por qué esto se adivina aquí, y qué haría falta para no adivinarlo
///
/// `traerLaFichaPorCodigo` lanza un `Exception` con el texto ya escrito **tanto
/// para el 404 como para el 409**, así que **el código de estado no llega hasta
/// aquí**. Y los dos casos no se pintan igual: uno es una instrucción —ata el
/// papel en secretaría, comprueba el código— y el otro es una avería con
/// «Reintentar». Mientras el contrato de esa función no devuelva el corte, lo
/// único que distingue a una caída de red es **el tipo de la excepción**, que
/// es lo que se mira aquí: `http.ClientException` en web y en móvil, el
/// `SocketException` de `dart:io` —que no se puede importar en una app que
/// también compila a web, así que se reconoce por su nombre— y el plantón.
///
/// Está apuntado como desajuste del contrato: lo correcto es que la capa de
/// datos devuelva el 409 como lo que es.
bool pareceFaltaDeSenal(Object err) {
  if (err is http.ClientException) return true;
  if (err is TimeoutException) return true;

  final dicho = '$err';
  return dicho.contains('SocketException') ||
      dicho.contains('HandshakeException') ||
      dicho.contains('Failed host lookup') ||
      dicho.contains('Connection refused') ||
      dicho.contains('Connection closed');
}

/// El texto que mandó el servidor, pintado como lo que es: algo que hacer.
///
/// Sin icono rojo de avería y sin «Reintentar», porque volver a teclear el
/// mismo código no cambia nada: lo que cambia las cosas es ir a secretaría a
/// que aten el papel, o mirar bien el papel.
class _LoQueHayQueHacer extends StatelessWidget {
  const _LoQueHayQueHacer({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: PaletaEstaciones.ambarFondo,
        border: Border.all(color: const Color(0xFFF0DFC0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_late_outlined,
            size: 20,
            color: PaletaEstaciones.ambar,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta hoja todavía no se puede atender',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A4300),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF7A4300),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// No se pudo ni preguntar. Esto sí lleva «Reintentar».
class _LaSenal extends StatelessWidget {
  const _LaSenal({required this.texto, required this.alReintentar});

  final String texto;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PaletaEstaciones.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 20,
            color: PaletaEstaciones.tintaSuave,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: PaletaEstaciones.tintaSuave,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: alReintentar,
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quién trae esa hoja y en qué va su recorrido.
class _LaHojaEncontrada extends StatelessWidget {
  const _LaHojaEncontrada({
    required this.ficha,
    required this.estacion,
    required this.servidor,
  });

  final FichaDeEstacion ficha;
  final Estacion? estacion;
  final Server? servidor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              AvatarPersona(
                nombre: ficha.persona.nombreCompleto,
                fotoNombre: ficha.persona.fotoNombre,
                radio: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ficha.persona.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: PaletaEstaciones.tinta,
                      ),
                    ),
                    if (ficha.persona.grupo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        ficha.persona.grupo!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PaletaEstaciones.tintaSuave,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ficha.codigo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: PaletaEstaciones.primarioSuave,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ficha.codigo!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: PaletaEstaciones.primarioOscuro,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Su recorrido',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PaletaEstaciones.tinta,
                ),
              ),
              const SizedBox(height: 8),
              // Vertical y no la barra horizontal de la ficha: aquí se lee
              // —con quién y cuándo—, no se mira de un vistazo (§3).
              for (final paso in ficha.pasos) _UnPaso(paso: paso),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            width: double.infinity,
            height: PaletaEstaciones.alturaDeBoton,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'notas-de-estacion'),
                  builder: (_) => NotasDeEstacionScreen(
                    personaId: ficha.persona.id,
                    nombre: ficha.persona.nombreCompleto,
                    fotoNombre: ficha.persona.fotoNombre,
                    grupo: ficha.persona.grupo,
                    pasos: ficha.pasos,
                    nroDeMiEstacion: estacion?.nro,
                    servidor: servidor,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Ver las notas del personal'),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnPaso extends StatelessWidget {
  const _UnPaso({required this.paso});

  final PasoDelRecorrido paso;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono Y color Y palabra: ningún estado se distingue solo por el
          // color, que con sol en la cara es el mismo gris para todos.
          Icon(paso.estado.icono, size: 20, color: paso.estado.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${paso.nro} · ${paso.nombre}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                Text(
                  paso.cerradoPor == null
                      ? paso.estado.palabra
                      : '${paso.estado.palabra} · ${paso.cerradoPor}'
                          '${paso.cerradoAt == null ? '' : ' · ${paso.cerradoAt}'}',
                  style: TextStyle(fontSize: 12, color: paso.estado.color),
                ),
                if (paso.motivo != null) ...[
                  const SizedBox(height: 2),
                  // Se dice de quién es este texto, porque **no es una nota**:
                  // el motivo pertenece al paso y lo lee la familia tal cual.
                  Text(
                    'Motivo que lee la familia: ${paso.motivo}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: PaletaEstaciones.rojoTinta,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (paso.notas.hayAlgo) ...[
            const SizedBox(width: 8),
            GloboDeNotas(
              cuantas: paso.notas.total,
              algoSinResolver: paso.notas.algoSinResolver,
            ),
          ],
        ],
      ),
    );
  }
}

/// Por qué no se puede teclear todavía, con el motivo que toque.
///
/// **Los dos motivos son distintos y se dicen distintos.** Uno es el módulo
/// entero y el otro es esta ruta; decir «no disponible» para los dos sería
/// esconder cuál de las dos cosas hay que mover, que es lo único que quien lo
/// lee puede hacer.
class _PorQueEstaApagado extends StatelessWidget {
  const _PorQueEstaApagado({required this.esperaElModulo});

  final bool esperaElModulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PaletaEstaciones.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock,
            size: 20,
            color: PaletaEstaciones.tintaApagada,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buscar por el código todavía no está encendido',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.tinta,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  esperaElModulo
                      ? 'Tu colegio todavía no tiene instalado el día de '
                          'matrículas en el servidor. La pantalla está escrita '
                          'entera y se enciende cuando lo tenga; mientras '
                          'tanto la app no le pregunta nada, para no gastar '
                          'una llamada en balde en cada apertura.'
                      : 'Falta que el servidor del colegio sepa buscar una '
                          'hoja por su código. Lo demás de esta pantalla ya '
                          'está: se teclea el mismo código del formulario de '
                          'inscripción, y también vale el del papel viejo.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: PaletaEstaciones.tintaSuave,
                  ),
                ),
                const SizedBox(height: 8),
                // La otra mitad de la decisión, dicha donde se echa de menos:
                // quien abre esto esperando escanear tiene que saber que no es
                // un olvido.
                const Text(
                  'Y no hay escáner a propósito: pedir la cámara cambia los '
                  'permisos de la app en las tiendas y puede dejarla fuera de '
                  'las tablets sin cámara, que son las del patio.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: PaletaEstaciones.tintaApagada,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
