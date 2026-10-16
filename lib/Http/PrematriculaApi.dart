import 'package:myvc_flutter/Http/MensajesDelServidor.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// La prematrícula de los antiguos, la que hace la familia desde la portada.
///
/// Todo lo que hace falta para pintarla ya viene en el muro
/// (`ChangesAsked/to-me`), y **sólo cuando el colegio la abrió**: con
/// `years.prematr_antiguos` apagado el servidor no manda `grados_sig` ni
/// `prematricula`, y la tarjeta no sale. Ése es el interruptor, y es del
/// colegio, no de la app. Las decisiones están en myvc_front
/// `docs/pantallas/PANTALLAS-MATRICULA.md` §9.
///
/// Si el colegio exige el formulario de renovación pagado
/// (`prematr_antiguos_exige_pago`), cada hijo trae `falta_pago_renovacion` y
/// la tarjeta lo dice en vez de ofrecer el botón; el pago se hace en
/// tesorería, nunca en la app.

/// Un grupo del año que viene.
class GrupoSiguiente {
  const GrupoSiguiente({required this.id, required this.nombre});

  final int id;
  final String nombre;
}

/// Un hijo, visto desde la prematrícula.
class HijoAPrematricular {
  const HijoAPrematricular({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.grupoActual,
    this.estado,
    this.grupoSiguiente,
    this.faltaPago = false,
  });

  final int alumnoId;
  final String nombres;
  final String apellidos;
  final String? grupoActual;

  /// `PREM`, `PREA`, `MATR`, `ASIS`, `RETI`, `DESE`, o null si todavía no.
  final String? estado;

  /// El grupo donde quedó, cuando ya quedó.
  final String? grupoSiguiente;

  final bool faltaPago;

  String get primerNombre => nombres.trim().split(RegExp(r'\s+')).first;

  /// «Prematriculado en», «Matriculado en»… o null si todavía puede elegir.
  String? get comoQuedo => switch (estado) {
        'PREM' || 'PREA' => 'Prematriculado en',
        'MATR' => 'Matriculado en',
        'ASIS' => 'Asistente en',
        'RETI' => 'Retirado',
        'DESE' => 'Desertor',
        _ => null,
      };
}

class PrematriculaDeLaFamilia {
  const PrematriculaDeLaFamilia({required this.hijos, required this.grupos});

  final List<HijoAPrematricular> hijos;

  /// Los grupos del año siguiente. Vacío es «el colegio todavía no los abrió».
  final List<GrupoSiguiente> grupos;
}

/// Lee la prematrícula del cuerpo del muro, o null si el colegio no la abrió.
///
/// La señal es que algún hijo traiga `prematricula` o que venga `grados_sig`
/// con algo: el servidor sólo los pone con `prematr_antiguos` encendido.
PrematriculaDeLaFamilia? leerPrematricula(Map cuerpo) {
  final alumnos = cuerpo['alumnos'];
  if (alumnos is! List) return null;

  final abierta = alumnos.any((a) => a is Map && a['prematricula'] is Map) ||
      (cuerpo['grados_sig'] is List &&
          (cuerpo['grados_sig'] as List).isNotEmpty);
  if (!abierta) return null;

  final grupos = <GrupoSiguiente>[
    if (cuerpo['grados_sig'] is List)
      for (final g in cuerpo['grados_sig'] as List)
        if (g is Map && entero(g['id']) != null)
          GrupoSiguiente(
            id: entero(g['id'])!,
            nombre: texto(g['nombre']) ?? texto(g['abrev']) ?? '',
          ),
  ];

  final hijos = <HijoAPrematricular>[
    for (final a in alumnos)
      if (a is Map && entero(a['alumno_id']) != null) _hijo(a),
  ];

  return PrematriculaDeLaFamilia(hijos: hijos, grupos: grupos);
}

HijoAPrematricular _hijo(Map a) {
  final pre = a['prematricula'];
  final estado = pre is Map ? texto(pre['estado']) : null;

  return HijoAPrematricular(
    alumnoId: entero(a['alumno_id'])!,
    nombres: texto(a['nombres']) ?? '',
    apellidos: texto(a['apellidos']) ?? '',
    grupoActual: texto(a['nombre_grupo']),
    estado: estado,
    grupoSiguiente: pre is Map ? texto(pre['nombre_grupo']) : null,
    faltaPago: siONo(a['falta_pago_renovacion']) ?? false,
  );
}

/// Cómo terminó un intento de prematricular.
enum ResultadoPrematricula { hecho, faltaPago, fallo }

/// `PUT matriculas/prematricular` con `estado: PREA`, como la web.
///
/// - **409** es el colegio que exige el pago de la renovación y todavía no lo
///   tiene: la frase la escribe el servidor y se enseña tal cual.
/// - **404** es que escribió la matrícula pero no la encontró al releerla
///   (`putPrematricular` relee con `anio_sig`): **quedó guardada**, y el muro
///   recargado lo dirá.
Future<({ResultadoPrematricula resultado, String? mensaje})> prematricular(
  Server server, {
  required int alumnoId,
  required int grupoId,
}) async {
  final dynamic res;
  try {
    res = await server.put('/matriculas/prematricular', {
      'alumno_id': alumnoId,
      'grupo_id': grupoId,
      'estado': 'PREA',
    });
  } catch (err) {
    return (
      resultado: ResultadoPrematricula.fallo,
      mensaje: 'No se pudo prematricular: $err',
    );
  }

  final codigo = res.statusCode as int;
  if (codigo < 300 || codigo == 404) {
    return (resultado: ResultadoPrematricula.hecho, mensaje: null);
  }

  final dijo = codigo < 500 ? loQueDijoElServidor(res.body) : null;

  if (codigo == 409) {
    return (
      resultado: ResultadoPrematricula.faltaPago,
      mensaje: dijo ??
          'Para prematricular, primero tesorería tiene que registrar el pago '
              'del formulario de renovación.',
    );
  }

  return (
    resultado: ResultadoPrematricula.fallo,
    mensaje: dijo ?? 'No se pudo prematricular: el servidor respondió $codigo.',
  );
}
