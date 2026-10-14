import 'package:myvc_flutter/Utils/JsonBackend.dart';

/// El estado de cuenta de la familia: `GET mi-cuenta`
/// (`Cartera\MiCuentaController::getMiCuenta`).
///
/// La espejo en la web es `MiCuenta` de `app2/src/app/datos/tesoreria.ts`, y
/// la pantalla que la pinta, `cartera/familia/mi-cuenta`. **Sólo se lee**: los
/// valores los decide tesorería, y pagar en línea se queda en la web mientras
/// la pasarela no se haya probado con dinero de verdad.
///
/// Casi todo llega de `DB::select` sin casts —`pagos` y `mensajes` son filas
/// tal cual—, así que los números se leen con [JsonBackend] y no fiándose del
/// tipo.
class MiCuenta {
  const MiCuenta({
    required this.hijos,
    required this.cuentas,
  });

  /// Los acudidos, con matrícula o sin ella: `al_dia` y el boletín, nunca
  /// valores. Es lo único que ve el acudiente que no responde por el pago.
  final List<HijoEnCartera> hijos;

  /// Una por cada tercero que es esta persona —casi siempre una—. Vacía si
  /// quien mira no responde por ningún pago.
  final List<CuentaDeTercero> cuentas;

  bool get vacia => hijos.isEmpty && cuentas.isEmpty;

  factory MiCuenta.fromJson(Map<String, dynamic> json) => MiCuenta(
        hijos: _lista(json['hijos'], HijoEnCartera.fromJson),
        cuentas: _lista(json['cuentas'], CuentaDeTercero.fromJson),
      );
}

class HijoEnCartera {
  const HijoEnCartera({
    required this.alumnoId,
    required this.nombres,
    required this.apellidos,
    this.foto,
    this.grupo,
    required this.alDia,
    required this.boletinHabilitado,
  });

  final int alumnoId;
  final String nombres;
  final String apellidos;

  /// `images.nombre`, el mismo que [AvatarPersona] sabe pintar.
  final String? foto;
  final String? grupo;

  /// Sin nada vencido.
  final bool alDia;

  /// `alumnos.pazysalvo`: si la familia ve sus boletines.
  final bool boletinHabilitado;

  String get nombre => '$nombres $apellidos'.trim();

  factory HijoEnCartera.fromJson(Map<String, dynamic> json) => HijoEnCartera(
        alumnoId: enteroO(json['alumno_id']),
        nombres: texto(json['nombres']) ?? '',
        apellidos: texto(json['apellidos']) ?? '',
        foto: texto(json['foto']),
        grupo: texto(json['grupo']),
        alDia: siONo(json['al_dia']) ?? true,
        boletinHabilitado: siONo(json['boletin_habilitado']) ?? true,
      );
}

class CuentaDeTercero {
  const CuentaDeTercero({
    required this.terceroId,
    required this.nombre,
    this.referencia,
    required this.debe,
    required this.vencido,
    required this.aFavor,
    required this.cobros,
    required this.pagos,
    this.acuerdo,
    required this.mensajes,
  });

  final int terceroId;

  /// A nombre de quién va la cuenta: la persona, o una empresa que paga por
  /// ella.
  final String nombre;

  /// La que se escribe al consignar en el banco.
  final String? referencia;

  final int debe;
  final int vencido;
  final int aFavor;

  /// **Sólo lo pendiente**, ordenado por vencimiento: el servidor ya quitó lo
  /// pagado.
  final List<CobroPendiente> cobros;

  /// Los últimos 24, el más reciente primero.
  final List<PagoRecibido> pagos;

  /// El vigente, si hay.
  final AcuerdoDePago? acuerdo;

  /// Los últimos 10 que tesorería mandó, el más reciente primero. Es lo que
  /// anuncia el aviso: «Tiene un mensaje sobre su cuenta».
  final List<MensajeDeTesoreria> mensajes;

  List<CobroPendiente> get vencidos => [
        for (final c in cobros)
          if (c.estaVencido) c
      ];

  List<CobroPendiente> get porVencer => [
        for (final c in cobros)
          if (!c.estaVencido) c
      ];

  factory CuentaDeTercero.fromJson(Map<String, dynamic> json) {
    final tercero = json['tercero'] is Map
        ? Map<String, dynamic>.from(json['tercero'] as Map)
        : const <String, dynamic>{};
    final acuerdo = json['acuerdo'];

    return CuentaDeTercero(
      terceroId: enteroO(tercero['id']),
      nombre: texto(tercero['nombre']) ?? '',
      referencia: texto(tercero['referencia']),
      debe: enteroO(json['debe']),
      vencido: enteroO(json['vencido']),
      aFavor: enteroO(json['a_favor']),
      cobros: _lista(json['cobros'], CobroPendiente.fromJson),
      pagos: _lista(json['pagos'], PagoRecibido.fromJson),
      acuerdo: acuerdo is Map
          ? AcuerdoDePago.fromJson(Map<String, dynamic>.from(acuerdo))
          : null,
      mensajes: _lista(json['mensajes'], MensajeDeTesoreria.fromJson),
    );
  }
}

class CobroPendiente {
  const CobroPendiente({
    required this.id,
    required this.descripcion,
    required this.alumno,
    this.vence,
    required this.pendiente,
    required this.dias,
  });

  final int id;
  final String descripcion;

  /// El primer nombre del alumno, y nada más: es lo que manda el servidor.
  final String alumno;
  final DateTime? vence;
  final int pendiente;

  /// Mayor que cero: días que lleva vencido. Cero o menos: aún no vence.
  final int dias;

  bool get estaVencido => dias > 0;

  factory CobroPendiente.fromJson(Map<String, dynamic> json) => CobroPendiente(
        id: enteroO(json['id']),
        descripcion: texto(json['descripcion']) ?? '',
        alumno: texto(json['alumno']) ?? '',
        vence: fechaDelServidor(json['vence']),
        pendiente: enteroO(json['pendiente']),
        dias: enteroO(json['dias']),
      );
}

class PagoRecibido {
  const PagoRecibido({
    required this.id,
    required this.numero,
    this.fecha,
    required this.valor,
    required this.medio,
    required this.anulado,
  });

  final int id;
  final int numero;
  final DateTime? fecha;
  final int valor;
  final String medio;
  final bool anulado;

  factory PagoRecibido.fromJson(Map<String, dynamic> json) => PagoRecibido(
        id: enteroO(json['id']),
        numero: enteroO(json['numero']),
        fecha: fechaDelServidor(json['fecha']),
        valor: enteroO(json['valor']),
        medio: texto(json['medio']) ?? '',
        anulado: texto(json['anulado_at']) != null,
      );
}

class MensajeDeTesoreria {
  const MensajeDeTesoreria({
    required this.id,
    required this.mensaje,
    this.enviado,
  });

  final int id;
  final String mensaje;
  final DateTime? enviado;

  factory MensajeDeTesoreria.fromJson(Map<String, dynamic> json) =>
      MensajeDeTesoreria(
        id: enteroO(json['id']),
        mensaje: texto(json['mensaje']) ?? '',
        enviado: fechaDelServidor(json['enviado_at']),
      );
}

/// Lo que se pinta de un acuerdo: `Acuerdos::completo`, de lo que la familia
/// necesita. Las columnas de la tabla y los datos del tercero se ignoran.
class AcuerdoDePago {
  const AcuerdoDePago({
    required this.total,
    required this.numeroDeCuotas,
    this.pagado,
    this.proxima,
    this.atrasada,
  });

  final int total;
  final int numeroDeCuotas;

  /// Del seguimiento, que sólo viene si el acuerdo está vigente. Sin él no hay
  /// barra ni próxima cuota.
  final int? pagado;
  final CuotaDeAcuerdo? proxima;
  final CuotaDeAcuerdo? atrasada;

  bool get tieneSeguimiento => pagado != null;

  factory AcuerdoDePago.fromJson(Map<String, dynamic> json) {
    final seguimiento = json['seguimiento'] is Map
        ? Map<String, dynamic>.from(json['seguimiento'] as Map)
        : null;
    final cuotas = json['cuotas'];

    return AcuerdoDePago(
      total: enteroO(json['total']),
      numeroDeCuotas: cuotas is List ? cuotas.length : 0,
      pagado: seguimiento == null ? null : enteroO(seguimiento['pagado']),
      proxima: CuotaDeAcuerdo.deJson(seguimiento?['proxima']),
      atrasada: CuotaDeAcuerdo.deJson(seguimiento?['atrasada']),
    );
  }
}

class CuotaDeAcuerdo {
  const CuotaDeAcuerdo({
    required this.n,
    this.vence,
    required this.valor,
    this.falta,
  });

  final int n;
  final DateTime? vence;
  final int valor;

  /// Lo que falta de esta cuota si ya se abonó una parte.
  final int? falta;

  int get porPagar => falta ?? valor;

  static CuotaDeAcuerdo? deJson(dynamic json) {
    if (json is! Map) return null;
    return CuotaDeAcuerdo(
      n: enteroO(json['n']),
      vence: fechaDelServidor(json['vence']),
      valor: enteroO(json['valor']),
      falta: entero(json['falta']),
    );
  }
}

/// `2026-10-10` o `2026-10-10 08:30:00` → la fecha, sin hora ni zona.
///
/// Se corta a los diez primeros caracteres porque lo único que se pinta es el
/// día, y así una columna `datetime` y una `date` se leen igual.
DateTime? fechaDelServidor(dynamic valor) {
  final crudo = texto(valor);
  if (crudo == null || crudo.length < 10) return null;
  return DateTime.tryParse(crudo.substring(0, 10));
}

List<T> _lista<T>(dynamic crudos, T Function(Map<String, dynamic>) leer) => [
      if (crudos is List)
        for (final fila in crudos)
          if (fila is Map) leer(Map<String, dynamic>.from(fila)),
    ];
