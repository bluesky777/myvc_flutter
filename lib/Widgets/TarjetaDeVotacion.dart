import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Utils/EstiloVotaciones.dart';
import 'package:myvc_flutter/Utils/VotacionPendiente.dart';

/// **Pantalla 1** · La tarjeta de la votación, arriba de la portada.
///
/// Es lo primero que ve al entrar el día de la jornada, y el sitio no es un
/// detalle: el muro se recorre hacia abajo y lo que queda debajo del primer
/// pliegue no existe para quien entra a mirar si hay algo nuevo. La tarjeta va
/// **encima de las publicaciones**, no flotando: un botón flotante tapa
/// publicaciones, y en un muro largo estorba justo donde se está leyendo (mismo
/// motivo que el acceso a notas del docente, en `MuroScreen`).
///
/// **No cuesta ninguna petición.** Todo lo que pinta viene de la respuesta del
/// login, por [VotacionPendiente]: que hay elección abierta, cómo se llama, y si
/// a esta persona le falta votar.
///
/// ## Por qué el titular son las palabras del colegio y no «personero»
///
/// Porque los cargos **no vienen en el login**: el servicio del backend cuelga
/// filas de `vt_votaciones` sin sus `aspiraciones` dentro. Escribir «Hoy se elige
/// personero» sería cablear un cargo que esta tarjeta no ha leído, y hay colegios
/// que el mismo día eligen contralor, o representante de grupo, o los tres. Lo
/// que sí se sabe es el nombre que el colegio le puso a la elección, y es el que
/// se pinta — es la misma regla de `docs/estaciones.md` §2.8: *el vocabulario lo
/// pone el colegio y la app no lo cablea*.
///
/// Los cargos concretos salen en el aviso y en el tarjetón, que sí piden la
/// papeleta.
class TarjetaDeVotacion extends StatelessWidget {
  const TarjetaDeVotacion({
    super.key,
    required this.votacion,
    required this.alVotar,
  });

  final VotacionAbierta votacion;

  /// Qué hacer al tocar «Votar ahora». Lo decide quien la pinta para que esta
  /// tarjeta no sepa navegar: la misma tarjeta sirve dentro del muro y dentro de
  /// una prueba.
  final VoidCallback alVotar;

  /// La tarjeta si toca, y nada si no.
  ///
  /// **Devuelve `null` y no un `SizedBox`**: quien la pinta la mete en una lista
  /// y necesita saber si ocupa un sitio o no, como hace `MuroScreen` con el
  /// acceso a notas.
  static Widget? siToca({required VoidCallback alVotar}) {
    final pendiente = VotacionPendiente.instancia;
    if (!pendiente.hayQueVotar) return null;

    final votacion = pendiente.laDeHoy;
    if (votacion == null) return null;

    return TarjetaDeVotacion(votacion: votacion, alVotar: alVotar);
  }

  @override
  Widget build(BuildContext context) {
    final estado = EstadoDeLaUrna.de(
      enAccion: votacion.enAccion,
      bloqueada: votacion.bloqueada,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: EstiloVotaciones.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EstiloVotaciones.moradoSuave,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.how_to_vote_outlined,
                  color: EstiloVotaciones.moradoOscuro,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HOY SE VOTA',
                      style: TextStyle(
                        color: EstiloVotaciones.moradoOscuro,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      votacion.nombre,
                      style: const TextStyle(
                        color: EstiloVotaciones.tinta,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EtiquetaDeEstado.urna(estado),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.schedule,
                size: 15,
                color: EstiloVotaciones.tintaSuave,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  votacion.cuandoCierra(),
                  style: const TextStyle(
                    color: EstiloVotaciones.tintaSuave,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: EstiloVotaciones.alturaDeBoton,
            child: FilledButton.icon(
              onPressed: alVotar,
              style: FilledButton.styleFrom(
                backgroundColor: EstiloVotaciones.morado,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(EstiloVotaciones.radio),
                ),
              ),
              icon: const Icon(Icons.how_to_vote),
              label: const Text(
                'Votar ahora',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tu voto es secreto. Nadie del colegio puede ver por quién votaste.',
            style: TextStyle(
              color: EstiloVotaciones.tintaApagada,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
