import 'package:flutter/material.dart';
import 'package:myvc_flutter/Models/VotacionModel.dart';
import 'package:myvc_flutter/Screens/ResultadosVotacionScreen.dart';
import 'package:myvc_flutter/Utils/EstiloVotaciones.dart';
import 'package:myvc_flutter/Utils/FechaServidor.dart';
import 'package:myvc_flutter/Utils/PaletaEstaciones.dart';

/// **Pantalla 5** · «Ya votaste»: la constancia, y lo que la app NO puede decir.
///
/// ## La frase difícil de esta pantalla
///
/// > *«Ni siquiera aquí aparece por quién votaste.»*
///
/// Y no es una forma de hablar: es el contrato. Ninguna ruta le dice a una
/// persona a quién votó. `candidatos/conaspiraciones` y
/// `votaciones/en-accion-inscrito` devuelven `votado` como **booleano** a
/// propósito —*«lo que se mira es si votó, nunca a quién»*—, `GET votos` está
/// borrada, y la lista nominal sale por una sola puerta, `auditoria/{id}`, que
/// exige `users.is_superuser` y **deja registrado quién miró**.
///
/// Decirlo en la pantalla no es adorno. Quien no sabe si el sistema guarda su
/// voto con su nombre **vota distinto**, y un sistema que es secreto y no lo
/// parece es un sistema que no es secreto para quien lo usa.
///
/// ## La hora sale de lo que pasó, no de una consulta
///
/// Por lo de arriba, tampoco hay ruta que devuelva a qué hora votó alguien. La
/// hora la trae `votos/store` al guardar —201, con la fila dentro— y la trae el
/// **409** cuando el servidor contesta que ya había votado, en su clave `voto`.
/// Así que aquí se pinta la hora de los cargos cuya constancia se conoce, y para
/// los que venían votados de antes se dice «Votado» sin hora — que es todo lo que
/// el contrato sabe, y decirlo a medias es mejor que inventarse un reloj.
///
/// Y la hora que llega está **en UTC**: `vt_votos.created_at` es la única columna
/// del sistema sellada así, y el resto guarda Bogotá. La convierte
/// [horaDeUnVotoEnBogota]; sin eso, un voto de las 8:15 de la mañana se pinta a la
/// 1:15 de la tarde, que es una hora perfectamente creíble.
class YaVotasteScreen extends StatelessWidget {
  const YaVotasteScreen({
    super.key,
    required this.votacion,
    required this.cargos,
    this.constancias = const {},
  });

  final VotacionAbierta votacion;

  /// Todos los cargos de la papeleta, votados y no votados.
  final List<CargoDeLaPapeleta> cargos;

  /// Lo que se sabe de cada voto, por `aspiracion_id`. Ver la cabecera.
  final Map<int, Constancia> constancias;

  @override
  Widget build(BuildContext context) {
    final cuando = _laHoraDeTodo();

    return Scaffold(
      backgroundColor: EstiloVotaciones.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: EstiloVotaciones.tinta,
        elevation: 0,
        title: const Text('Ya votaste'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: PaletaEstaciones.verdeFondo,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 58,
                color: PaletaEstaciones.verde,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Listo, tu voto quedó registrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: EstiloVotaciones.tinta,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cuando == null
                ? votacion.nombre
                : '${votacion.nombre}\n${formatoDiaYHora(cuando)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: EstiloVotaciones.tintaSuave,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: EstiloVotaciones.tarjeta,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final cargo in cargos) _renglonDeCargo(cargo),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _elSecreto(),
          const SizedBox(height: 12),
          _losResultados(context),
          const SizedBox(height: 18),
          SizedBox(
            height: EstiloVotaciones.alturaDeBoton,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: EstiloVotaciones.moradoOscuro,
                side: const BorderSide(color: EstiloVotaciones.borde),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EstiloVotaciones.radio),
                ),
              ),
              child: const Text(
                'Volver al inicio',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renglonDeCargo(CargoDeLaPapeleta cargo) {
    final constancia = constancias[cargo.id];
    final estado = EstadoDelCargo.de(cargo.votado || constancia != null);
    final hora = constancia?.cuando;

    return ListTile(
      dense: false,
      leading: Icon(estado.icono, color: estado.color),
      title: Text(
        cargo.comoSeLlama,
        style: const TextStyle(
          color: EstiloVotaciones.tinta,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: hora == null
          ? null
          : Text(
              'A las ${formatoHora12(hora)}',
              style: const TextStyle(
                color: EstiloVotaciones.tintaApagada,
                fontSize: 12,
              ),
            ),
      trailing: EtiquetaDeEstado.cargo(estado),
    );
  }

  /// El secreto del voto, dicho entero. Ver la cabecera de la clase.
  Widget _elSecreto() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: EstiloVotaciones.tarjeta,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 20,
            color: EstiloVotaciones.moradoOscuro,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tu voto es secreto. Nadie del colegio puede ver por quién'
              ' votaste, y ni siquiera en esta pantalla aparece: aquí sólo'
              ' queda que votaste, y cuándo.',
              style: TextStyle(
                color: EstiloVotaciones.tintaSuave,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Los resultados: el botón cuando el colegio los publicó, y el aviso cuando
  /// no.
  ///
  /// **Son dos cosas distintas y se dicen distinto.** `can_see_results` no es
  /// «todavía no hay datos»: es «rectoría no los ha publicado», que es una
  /// decisión de una persona y no un estado del sistema. Un botón que lleve a una
  /// pantalla vacía enseña que la app no sirve; una frase que diga quién los
  /// publica enseña a quién preguntarle.
  Widget _losResultados(BuildContext context) {
    if (!votacion.conteoPublicado) {
      return const AvisoAmbar(
        icono: Icons.hourglass_empty,
        texto: 'Los resultados salen cuando rectoría los publique. Mientras se'
            ' vota, nadie ve el conteo.',
      );
    }

    return SizedBox(
      height: EstiloVotaciones.alturaDeBoton,
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultadosVotacionScreen(
              votacionId: votacion.id,
              nombre: votacion.nombre,
            ),
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: EstiloVotaciones.morado,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EstiloVotaciones.radio),
          ),
        ),
        icon: const Icon(Icons.bar_chart),
        label: const Text(
          'Ver resultados',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// La hora que se pinta arriba: la del último voto que se conoce.
  ///
  /// **La última y no la primera**: lo que la pantalla dice es «acabaste», y de
  /// una papeleta de tres cargos lo que se acabó es el tercero.
  DateTime? _laHoraDeTodo() {
    DateTime? ultima;

    for (final constancia in constancias.values) {
      final cuando = constancia.cuando;
      if (cuando == null) continue;
      if (ultima == null || cuando.isAfter(ultima)) ultima = cuando;
    }

    return ultima;
  }
}
