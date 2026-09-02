import 'package:myvc_flutter/Http/MuroApi.dart';

/// El último muro que se trajo, para no volver a pedirlo cuatro veces seguidas.
///
/// **Existe por lo que cuesta `GET ChangesAsked/to-me` del otro lado.** Medido
/// por el backend el 2 sep 2026 —`docs/migracion/24-el-panel-de-inicio.md`—, a
/// un acudiente le manda **108 KB**, de los que el 99 % es la tabla
/// `calendario` entera: `SELECT * FROM calendario`, sin filtro de año y sin
/// filtro de fecha, con filas de 2019 dentro. **La app no lee esa clave.**
///
/// De toda esa respuesta lee tres: `publicaciones`, `alumnos` y `horario_hoy`,
/// que son unos 5 KB. Y por debajo, la rama del acudiente recorre a sus
/// acudidos uno a uno —seis consultas más por cada uno, dice la medición—
/// calculando el comportamiento, las situaciones, el libro rojo, los uniformes
/// y la prematrícula, de los cuales aquí no se mira ni uno.
///
/// Y lo pedían **cuatro pantallas**: el muro, Mis notas, Mi disciplina y Mi
/// asistencia. Las tres últimas no quieren el muro: quieren la lista de
/// acudidos para preguntar de quién se va a mirar. Un acudiente que entraba y
/// pasaba por las tres pagaba esa cuenta cuatro veces en menos de un minuto.
///
/// Mientras la app era de docentes daba igual —eran cincuenta personas y la
/// rama del docente no tiene el bucle—. Con las familias dentro es la petición
/// más cara que hace la app y la que más se repite, y encima llega en ráfaga:
/// una notificación de «ya están las notas» hace que cientos de teléfonos
/// abran la app en el mismo minuto. Ver
/// [docs/backend-pendiente.md](../../docs/backend-pendiente.md) §5, que es
/// donde está pedido el endpoint que arregla el fondo.
///
/// **Esto no lo arregla, lo tapa**, y a propósito: el backend es otro
/// despliegue y esto se puede hacer hoy. Cuando exista un muro propio para la
/// app, esta caché sigue valiendo pero deja de ser urgente.
///
/// ## Por qué cinco minutos y no más
///
/// La caché tiene que durar lo que dura *una visita* —abrir, mirar notas,
/// mirar disciplina, mirar asistencia—, que es el trecho que hoy cuesta cuatro
/// peticiones. No más: quien deja la app abierta toda la tarde y vuelve tiene
/// que ver lo de ahora, no lo de las dos.
///
/// Y hay una garantía que no depende del reloj: **[MuroScreen] siempre pide
/// fresco**. La pantalla que enseña las publicaciones no las lee nunca de aquí,
/// así que ni el muro ni el «deslizar para recargar» pueden enseñar algo viejo.
/// Lo que se sirve de la caché es la lista de acudidos, que no cambia a media
/// tarde.
class MuroEnMemoria {
  MuroEnMemoria._();

  static final MuroEnMemoria instancia = MuroEnMemoria._();

  /// Cuánto vale lo guardado. Ver «Por qué cinco minutos» arriba.
  static const Duration vigencia = Duration(minutes: 5);

  MuroCargado? _guardado;
  DateTime? _cuando;

  /// Lo guardado, si todavía vale. Null si no hay nada o si ya caducó.
  ///
  /// `ahora` es para las pruebas, como en [FechaServidor]: deja comprobar que
  /// caduca sin tener que esperar cinco minutos de reloj.
  MuroCargado? vigente({DateTime? ahora}) {
    final guardado = _guardado;
    final cuando = _cuando;

    if (guardado == null || cuando == null) return null;
    if ((ahora ?? DateTime.now()).difference(cuando) > vigencia) return null;

    return guardado;
  }

  void guardar(MuroCargado muro, {DateTime? cuando}) {
    _guardado = muro;
    _cuando = cuando ?? DateTime.now();
  }

  /// Deja la caché como recién arrancada la app.
  ///
  /// Al cerrar sesión, sin falta: ahí dentro están los nombres y las fotos de
  /// los hijos de quien se va. En un teléfono prestado, el siguiente no tiene
  /// por qué verlos. Es el mismo cuidado que ya tienen [HorarioDeHoy] y
  /// `ContextoAcademico`.
  void limpiar() {
    _guardado = null;
    _cuando = null;
  }
}
