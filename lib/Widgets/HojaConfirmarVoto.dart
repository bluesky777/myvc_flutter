import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Utils/EstiloVotaciones.dart';

/// **Pantalla 4** · La confirmación, antes de que el voto sea para siempre.
///
/// ## Por qué hay un paso más, con lo que cuesta un paso más
///
/// Porque **el voto es inmutable y lo garantiza la base de datos**: el índice
/// único `vt_votos_un_voto_por_cargo` impide una segunda fila del mismo cargo, y
/// `verificarNoVoto()` —que borraba el anterior y dejaba cambiar el voto— se fue
/// el 22 de septiembre de 2026. O sea que aquí no hay «deshacer durante ocho
/// segundos» como en las estaciones: **no hay nada que deshacer después**, y ésa
/// es justamente la razón de poner el paso antes.
///
/// Un toque de más en una rejilla de caras, en un teléfono, con la fila
/// avanzando, es un voto que no era. Esta hoja existe para eso y para nada más.
///
/// ## Y las tres frases del aviso ámbar son tres cosas distintas
///
/// No es un párrafo de relleno: cada línea contesta una pregunta que la gente
/// hace en voz alta el día de la elección.
///
///   1. **No se puede cambiar** — el índice único.
///   2. **No se puede repetir** — el mismo índice, dicho al revés, porque «ya
///      voté ¿puedo votar otra vez?» y «me equivoqué ¿lo cambio?» se preguntan
///      por separado.
///   3. **Nadie del colegio puede ver por quién votaste** — y esto es verdad del
///      servidor y no una promesa de la pantalla: `conaspiraciones` y
///      `en-accion-inscrito` devuelven **si** votó y nunca **a quién**, `GET
///      votos` —que entregaba la tabla entera con el `user_id` de cada voto a
///      cualquiera del personal— está borrada, y la lista nominal sale por una
///      sola puerta, `auditoria/{id}`, que exige `users.is_superuser` y **queda
///      registrada a nombre de quien miró**.
///
/// Devuelve `true` si confirma. `false` o `null` es «quiero escoger otro».
Future<bool> confirmarElVoto(
  BuildContext context, {
  required CargoDeLaPapeleta cargo,
  required CandidatoDelTarjeton candidato,
}) async {
  final confirmado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (hoja) => _HojaConfirmarVoto(cargo: cargo, candidato: candidato),
  );

  return confirmado ?? false;
}

class _HojaConfirmarVoto extends StatelessWidget {
  const _HojaConfirmarVoto({required this.cargo, required this.candidato});

  final CargoDeLaPapeleta cargo;
  final CandidatoDelTarjeton candidato;

  @override
  Widget build(BuildContext context) {
    final navegador = Navigator.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EstiloVotaciones.borde,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // El avatar enorme: lo que se está confirmando es una cara, no una
            // fila de una lista.
            Center(
              child: CirculoDeCandidato(
                nombre: candidato.nombre,
                fotoNombre: candidato.fotoNombre,
                blanco: candidato.blanco,
                radio: 52,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              candidato.blanco
                  ? '¿Votas en blanco para ${cargo.comoSeLlama}?'
                  : '¿Tu voto es para ${candidato.nombre}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EstiloVotaciones.tinta,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _elRenglonDeDebajo(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EstiloVotaciones.tintaSuave,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 18),
            const AvisoAmbar(
              texto: 'Este voto no se puede cambiar ni repetir.\n'
                  'Nadie del colegio puede ver por quién votaste: el voto es'
                  ' secreto.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: EstiloVotaciones.alturaDeBoton,
              child: FilledButton(
                onPressed: () => navegador.pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: EstiloVotaciones.morado,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EstiloVotaciones.radio),
                  ),
                ),
                child: const Text(
                  'Sí, este es mi voto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: EstiloVotaciones.alturaDeBoton,
              child: OutlinedButton(
                onPressed: () => navegador.pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EstiloVotaciones.moradoOscuro,
                  side: const BorderSide(color: EstiloVotaciones.borde),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EstiloVotaciones.radio),
                  ),
                ),
                child: const Text(
                  'No, quiero escoger otro',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El cargo, y el número y la plancha cuando los hay.
  ///
  /// Van aquí y no en el titular porque el titular tiene que poder leerse de un
  /// golpe: quien confirma ya eligió, lo que necesita es reconocer que es el que
  /// eligió.
  String _elRenglonDeDebajo() {
    final partes = <String>[cargo.comoSeLlama];

    if (candidato.numero != null && candidato.numero!.isNotEmpty) {
      partes.add('Número ${candidato.numero}');
    }
    if (candidato.plancha != null && candidato.plancha!.isNotEmpty) {
      partes.add('Plancha ${candidato.plancha}');
    }
    if (candidato.grupo != null && candidato.grupo!.isNotEmpty) {
      partes.add(candidato.grupo!);
    }

    return partes.join(' · ');
  }
}
