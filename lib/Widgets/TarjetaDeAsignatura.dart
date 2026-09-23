import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/LineaDeBoletinModel.dart';
import 'package:myvc_flutter/Models/NotasAlumnoModel.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Widgets/AvatarPersona.dart';
import 'package:myvc_flutter/constantes.dart';

/// Una asignatura en el boletín de la familia: su nota y, si las hay, sus
/// competencias.
///
/// **Vivía dentro de `MisNotasScreen` y se sacó el 19 sep 2026**, y no por
/// tamaño: es que la tarjeta pasó a tener una decisión dentro —dónde va el
/// nombre de la banda— y **esa decisión no se podía probar desde la pantalla**.
/// Las competencias llegan detrás de `Interruptores.competenciasDocente`, que es
/// un `const false`: desde la pantalla, el caso «con líneas» es inalcanzable
/// para una prueba. Aquí las líneas entran por parámetro y los dos casos se
/// miran de frente.
class TarjetaDeAsignatura extends StatelessWidget {
  const TarjetaDeAsignatura({
    super.key,
    required this.asignatura,
    this.lineas = const [],
    this.alTocar,
  });

  final AsignaturaNotaModel asignatura;

  /// Las competencias de esta asignatura en el periodo que se mira.
  ///
  /// Vacía es el caso de hoy en todos los colegios, y entonces la tarjeta es
  /// **exactamente** la de siempre.
  final List<LineaDeBoletin> lineas;

  /// Abrir el desglose: de qué notas sale esta definitiva.
  ///
  /// Opcional, y sin él la tarjeta es exactamente la de siempre. Lo pasa «Mis
  /// notas»; las pantallas que enseñan la tarjeta sin poder abrir nada —un
  /// boletín en sólo lectura— lo dejan en null y no se pinta ni la flecha, que
  /// sería prometer un toque que no hace nada.
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tarjeta = Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarPersona(
                nombre: asignatura.docente,
                fotoNombre: asignatura.fotoDocente,
                radio: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asignatura.materia,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asignatura.docente.isEmpty
                          ? 'Sin docente asignado'
                          : asignatura.docente,
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54),
                    ),
                    // **La banda se queda aquí cuando NO hay líneas**, que es
                    // como lleva estando siempre. Ver [_buildNota].
                    if (lineas.isEmpty && asignatura.desempenio != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        asignatura.desempenio!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ],
                ),
              ),
              _buildNota(conLineas: lineas.isNotEmpty),
            ],
          ),
          if (lineas.isNotEmpty) _buildLineas(lineas),
        ],
      ),
    );

    if (alTocar == null) return tarjeta;

    // El `InkWell` por fuera y no dentro del Container: así el resalte al
    // tocar cubre la tarjeta entera, que es la zona que la gente toca, y no
    // sólo el texto.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: tarjeta,
      ),
    );
  }

  /// La nota, y con ella la banda **sólo cuando hay líneas debajo**.
  ///
  /// **Por qué se mueve.** Cada línea del catálogo llega con el nombre de la
  /// banda montado delante —«Fortaleza en…»—, así que con líneas debajo la
  /// palabra «Alto» aparecería una vez como rótulo y cuatro veces disfrazada. La
  /// banda es una propiedad de la nota, así que su sitio es al lado de la nota,
  /// y las líneas salen **exactamente** como vienen del servidor.
  ///
  /// **Y se mueve sólo entonces**, no siempre: la duplicación que justifica el
  /// cambio no existe sin líneas, y moverlo a secas cambiaría la pantalla de
  /// todos los colegios hoy sin que ninguno gane nada.
  Widget _buildNota({bool conLineas = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          asignatura.notaEscrita,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: !asignatura.tieneNota
                ? Colors.black26
                : ContextoAcademico.instancia.config.esPerdida(asignatura.nota)
                    ? Colors.red[700]
                    : kPrimaryColor,
          ),
        ),
        if (conLineas && asignatura.desempenio != null)
          Text(
            asignatura.desempenio!,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        if (asignatura.recuperada)
          Text('recuperada',
              style: TextStyle(fontSize: 10, color: Colors.black45)),
      ],
    );
  }

  /// Las competencias del periodo, enteras y sin plegar.
  ///
  /// **Todo visible, como el papel** (decisión de Joseth, 19 sep 2026). Con diez
  /// materias y cuatro competencias cada una son unas cuarenta líneas de scroll;
  /// se acepta, porque es exactamente lo que llega impreso a casa y **lo que se
  /// pliega en un teléfono no lo abre nadie**.
  ///
  /// **Sin rótulo, y a propósito**: el modelo es plano y el boletín no tiene
  /// cabecera. Poner «Competencias» y «Observaciones» sería inventar en la app
  /// una jerarquía que el papel no tiene.
  ///
  /// Las escritas a mano para ese alumno van al final, separadas por un filete y
  /// **sin prefijo** — el servidor ya las manda así, porque una frase sobre un
  /// niño concreto no es una fila de un plan de área.
  Widget _buildLineas(List<LineaDeBoletin> lineas) {
    final delCatalogo = lineas.where((l) => l.esDelCatalogo).toList();
    final aMano = lineas.where((l) => l.esFraseDelDocente).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 8),
          ...delCatalogo.map(_buildLinea),
          if (aMano.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.05)),
            const SizedBox(height: 8),
            ...aMano.map(_buildLinea),
          ],
        ],
      ),
    );
  }

  Widget _buildLinea(LineaDeBoletin linea) {
    // El icono **acompaña al texto y nunca lo sustituye** (D17): un boletín de
    // Jardín con cinco caritas y ni una palabra no se puede leer en voz alta.
    final icono = linea.icono(infantil: true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null) ...[
            Text(icono, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              // Tal cual viene: el prefijo lo montó el servidor.
              linea.texto,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
