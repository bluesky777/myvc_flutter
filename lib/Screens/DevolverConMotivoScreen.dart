import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/EstacionesApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/EstacionModel.dart';
import 'package:myvc_flutter/Screens/PasoCerradoScreen.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';
import 'package:myvc_flutter/Widgets/ColumnaDeFicha.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';

/// Las tres de siempre, **botones y no un desplegable**.
///
/// `docs/estaciones.md` §2.4: *«un motivo de un toque es un motivo que sí se
/// escribe»*. Con una fila delante, lo que compite con escribir el motivo no es
/// escribir otro: es **no escribir ninguno** y decírselo de viva voz.
///
/// **Y no son un desplegable de motivos cerrados**, que es la forma en que esto
/// se hace mal: el día que el caso no esté en la lista se elige el más parecido
/// y **la familia recibe una mentira** en su celular. Aquí son un atajo que
/// rellena la casilla, y la casilla se sigue pudiendo editar entera.
///
/// Van sin punto final porque [conLaFrase] las encadena, y dos puntos seguidos
/// en el celular de una mamá se leen como un fallo.
const List<String> lasTresFrasesDeSiempre = [
  'Falta el certificado',
  'La copia no se lee',
  'Falta la firma',
];

/// Añade una de las frases de un toque a lo que ya hubiera escrito.
///
/// **Añade en vez de reemplazar**, y eso es a propósito: los casos reales se
/// suman —falta la firma **y** la copia no se lee— y reemplazar castigaría a
/// quien ya había escrito algo suyo borrándoselo de un toque, que es la forma
/// de que nadie vuelva a tocar los atajos.
///
/// Tocar dos veces la misma frase no la repite: quien atiende está de pie y con
/// prisa, y un «Falta la firma. Falta la firma» lo lee la familia tal cual.
///
/// Suelta y pública para poder probarla: es una regla, no un adorno.
String conLaFrase(String actual, String frase) {
  final limpio = actual.trim();

  if (limpio.isEmpty) return frase;
  if (limpio.toLowerCase().contains(frase.toLowerCase())) return limpio;

  final sinPuntoFinal =
      limpio.endsWith('.') ? limpio.substring(0, limpio.length - 1) : limpio;

  return '$sinPuntoFinal. $frase';
}

/// **Devolver con motivo** — pantalla 06 de `docs/estaciones.md`.
///
/// ## El botón no se enciende sin texto, y esa regla no se puede aflojar
///
/// §2.4: el botón está **apagado** hasta que hay texto, y lo dice —*«sin motivo
/// escrito, el botón no se enciende»*—. No es una validación de cortesía:
/// devolver a alguien sin decirle por qué es mandarlo a su casa a adivinar, y
/// volver al día siguiente con el mismo papel mal.
///
/// La comprueba [loQueLeFaltaAlCierre], que es **la misma función que usa la
/// capa de datos** para no gastar una petición en averiguar lo que ya se sabe,
/// y que el servidor vuelve a comprobar con un 422. Tres sitios, una regla
/// escrita una vez.
///
/// ## Arriba, en rojo: lo que escribas LO LEE LA FAMILIA
///
/// Y no es una advertencia genérica. `requisitos_alumno.motivo_devolucion` es
/// **la única casilla de todo el módulo que sale de la app y llega a una
/// familia**; lo que se escribe entre el personal son las notas, que van en
/// otra tabla justamente para que un comentario interno no acabe en el celular
/// de una mamá. Quien no sepa eso escribirá «falta doc» y colgará.
///
/// ## Devolver NO cierra el paso
///
/// El servidor limpia `cerrado_at` y `cerrado_por` para que **la cola de esta
/// estación siga viendo a esa persona** y la de la siguiente no. Lo dice esta
/// pantalla antes de confirmar y lo vuelve a decir la 07 después, porque es lo
/// contrario de lo que la palabra «marcar» sugiere.
class DevolverConMotivoScreen extends StatefulWidget {
  const DevolverConMotivoScreen({
    super.key,
    required this.estacion,
    required this.ficha,
    this.requisitos = const [],
    this.recorridoDelColegio = const [],
    this.servidor,
  });

  final Estacion estacion;
  final FichaDeEstacion ficha;

  /// Qué requisitos se devuelven. Vacío es la estación entera.
  final List<int> requisitos;

  /// El recorrido del colegio, que la 07 usa para decir cuántos esperan. Se
  /// pasa de largo: pedirlo otra vez aquí sería una petición por devolución.
  final List<Estacion> recorridoDelColegio;

  /// Con qué servidor hablar. Null es el de verdad, que es lo normal.
  final Server? servidor;

  @override
  State<DevolverConMotivoScreen> createState() =>
      _DevolverConMotivoScreenState();
}

class _DevolverConMotivoScreenState extends State<DevolverConMotivoScreen> {
  final TextEditingController motivo = TextEditingController();

  @override
  void initState() {
    super.initState();
    Analitica.evento('estacion_devolver_abierta');
    // Repinta el pie en cada tecla: es lo que enciende y apaga el botón.
    motivo.addListener(_repintar);
  }

  @override
  void dispose() {
    motivo.removeListener(_repintar);
    motivo.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _repintar() => setState(() {});

  /// Qué le falta a esto para poder mandarse. Null es «ya puede irse».
  String? get _loQueFalta =>
      loQueLeFaltaAlCierre(ResultadoDelPaso.devuelto, motivo.text);

  void _tocarFrase(String frase) {
    final juntas = conLaFrase(motivo.text, frase);

    motivo.value = TextEditingValue(
      text: juntas,
      // El cursor al final, que es donde sigue escribiendo quien quiera añadir
      // algo suyo. Sin esto salta al principio y la siguiente letra se cuela
      // delante del motivo.
      selection: TextSelection.collapsed(offset: juntas.length),
    );
  }

  /// Abre la 07 y, cuando ella conteste, se quita de en medio.
  ///
  /// **Se apila y se despila en cadena en vez de reemplazarse**, y esa es la
  /// diferencia que importa: `pushReplacement` cierra esta pantalla en el
  /// momento de abrir la siguiente, así que quien la abrió —la 05, o la ficha—
  /// recibiría un «no pasó nada» **antes** de que pasara nada, y la ficha de
  /// atrás no se recargaría. Apilando, lo que conteste la 07 sube de una en una
  /// hasta la ficha, que es la que tiene que enterarse de que el recorrido
  /// cambió.
  Future<void> _devolver() async {
    if (_loQueFalta != null) return;

    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'paso-cerrado'),
        builder: (_) => PasoCerradoScreen(
          estacion: widget.estacion,
          ficha: widget.ficha,
          resultado: ResultadoDelPaso.devuelto,
          escrito: motivo.text,
          requisitos: widget.requisitos,
          recorridoDelColegio: widget.recorridoDelColegio,
          servidor: widget.servidor,
        ),
      ),
    );

    // Null es que la 07 se cerró sin decir nada —con el botón de atrás del
    // sistema—, y entonces ésta se queda abierta con el motivo escrito: quien
    // atiende no tiene que volver a teclearlo.
    if (resultado == null || !mounted) return;

    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaletaEstaciones.fondo,
      appBar: AppBar(
        title: TituloPantalla(
          titulo: 'Devolver',
          subtitulo: comoSeLlamaLaEstacion(
            widget.estacion.nro,
            widget.estacion.nombre,
          ),
          conFlecha: true,
        ),
      ),
      body: ColumnaDeFicha(child: _cuerpo()),
      bottomNavigationBar: _elPie(),
    );
  }

  Widget _cuerpo() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        const _ElAvisoRojo(),
        const SizedBox(height: 12),
        Text(
          'Devuelves a ${widget.ficha.persona.nombreCompleto}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: PaletaEstaciones.tinta,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Las de siempre, de un toque',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: PaletaEstaciones.tinta,
          ),
        ),
        const SizedBox(height: 8),
        for (final frase in lasTresFrasesDeSiempre)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              height: PaletaEstaciones.alturaDeBoton,
              child: OutlinedButton.icon(
                onPressed: () => _tocarFrase(frase),
                icon: const Icon(Icons.add, size: 18),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: PaletaEstaciones.primarioOscuro,
                  side: const BorderSide(color: PaletaEstaciones.borde),
                  backgroundColor: Colors.white,
                ),
                label: Text(
                  frase,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          'El motivo, con tus palabras',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: PaletaEstaciones.tinta,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: motivo,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Qué le falta y qué tiene que traer',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _LoQueVaALeer(
          nombres: widget.ficha.persona.nombres,
          estacion: comoSeLlamaLaEstacion(
            widget.estacion.nro,
            widget.estacion.nombre,
          ),
          motivo: motivo.text.trim(),
        ),
      ],
    );
  }

  Widget _elPie() {
    final falta = _loQueFalta;
    final apagadoPorElPendiente = !PendientesEstaciones.devolverConMotivo;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: PaletaEstaciones.alturaDeBoton,
              child: FilledButton.icon(
                onPressed:
                    falta == null && !apagadoPorElPendiente ? _devolver : null,
                icon: const Icon(Icons.undo),
                style: FilledButton.styleFrom(
                  backgroundColor: PaletaEstaciones.rojo,
                ),
                label: const Text('Devolver a la familia'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              apagadoPorElPendiente
                  // Nunca «no disponible»: quien lo lee es quien puede pedirlo.
                  ? 'Devolver está apagado hasta que las nueve rutas de '
                      'estaciones estén desplegadas en todos los colegios. La '
                      'pantalla ya está escrita; lo que falta es el despliegue.'
                  : falta ??
                      'El paso queda abierto: sigue en tu fila hasta que '
                          'vuelva con lo que falta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: falta == null && !apagadoPorElPendiente
                    ? PaletaEstaciones.tintaApagada
                    : PaletaEstaciones.ambar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El aviso de arriba. **En rojo, y el primero que se lee.**
class _ElAvisoRojo extends StatelessWidget {
  const _ElAvisoRojo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PaletaEstaciones.rojoFondo,
        border: Border.all(color: PaletaEstaciones.rojo, width: 1.5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono Y palabra: el rojo solo no lo ve todo el mundo, y menos con
          // sol en la cara.
          const Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: PaletaEstaciones.rojo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Lo que escribas aquí lo lee la familia',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PaletaEstaciones.rojoTinta,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Tal cual, en su celular. No es una nota entre nosotros: es '
                  'lo único que va a saber esa familia sobre por qué tiene '
                  'que volver.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: PaletaEstaciones.rojoTinta,
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

/// Lo que va a leer la familia, mientras se escribe.
///
/// Son **dos cosas distintas y se enseñan separadas**, porque §2.2 bis las
/// separa: el aviso del celular lleva el nombre y **no lleva el motivo** —se lee
/// en una pantalla bloqueada, con gente al lado—, y el motivo se lee dentro de
/// la app. Quien escribe tiene que ver las dos para entender que **el motivo
/// tiene que valerse solo**: nadie se lo va a explicar por encima.
class _LoQueVaALeer extends StatelessWidget {
  const _LoQueVaALeer({
    required this.nombres,
    required this.estacion,
    required this.motivo,
  });

  final String nombres;
  final String estacion;
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PaletaEstaciones.primarioSuave,
        border: Border.all(color: const Color(0xFFDDD7F4)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Le llega al celular',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.primarioOscuro,
            ),
          ),
          const SizedBox(height: 6),
          _caja(
            elAvisoParaLaFamilia(
              nombres: nombres,
              resultado: ResultadoDelPaso.devuelto,
              estacionActual: estacion,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Y al abrir la app, esto',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PaletaEstaciones.primarioOscuro,
            ),
          ),
          const SizedBox(height: 6),
          _caja(
            motivo.isEmpty ? 'Todavía no has escrito el motivo.' : motivo,
            apagado: motivo.isEmpty,
          ),
        ],
      ),
    );
  }

  Widget _caja(String texto, {bool apagado = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.35,
          fontStyle: apagado ? FontStyle.italic : FontStyle.normal,
          color:
              apagado ? PaletaEstaciones.tintaApagada : PaletaEstaciones.tinta,
        ),
      ),
    );
  }
}
