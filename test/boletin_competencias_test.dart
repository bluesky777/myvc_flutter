import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/BoletinCompetenciasApi.dart';
import 'package:myvc_flutter/Http/NotasApi.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/LineaDeBoletinModel.dart';

/// Un servidor de mentira que apunta la ruta y el cuerpo que le mandan.
class ServidorFingido extends Server {
  ServidorFingido(this.respuesta);

  final http.Response respuesta;

  final List<String> rutas = [];
  final List<dynamic> cuerpos = [];

  @override
  Future put(String direccion, params) async {
    rutas.add(direccion);
    cuerpos.add(params);
    return respuesta;
  }
}

/// La tupla de CINCO que devuelve `boletinDelGrupo`, en su orden:
/// `[grupo, year, alumnos, escalas, poblacion]`. Es un array posicional, no un
/// objeto con claves, y por eso el boletín de cada alumno está en el `[2]`.
http.Response boletin(List<Map<String, dynamic>> alumnos,
    {bool caritas = false}) {
  return respuestaJson([
    {
      'grupo_id': 9,
      'nombre_grupo': 'Septimo A',
      'caritas': caritas ? 1 : 0,
      'cantidad_alumnos': alumnos.length,
    },
    {'year_id': 3, 'periodo': 2},
    alumnos,
    [
      {'id': 1, 'desempenio': 'Alto', 'descripcion': 'Fortaleza en'},
    ],
    {'alumnos': alumnos.length, 'desempenos_impresos': 0, 'caritas': caritas},
  ]);
}

/// Con `charset=utf-8` a propósito: sin él el `http` de Dart decodifica el
/// cuerpo como latin1 y los acentos de las pruebas dejarían de ser los del
/// servidor.
http.Response respuestaJson(Object cuerpo, {int codigo = 200}) {
  return http.Response(
    jsonEncode(cuerpo),
    codigo,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> alumnoCon(
  int id, {
  String nombres = 'Damaris',
  List<Map<String, dynamic>> asignaturas = const [],
}) {
  return {
    'alumno_id': id,
    'matricula_id': 400 + id,
    'nombres': nombres,
    'apellidos': 'Gomez Pico',
    'asignaturas': asignaturas,
  };
}

Map<String, dynamic> asignaturaCon({
  int id = 5,
  String materia = 'Matematicas',
  dynamic nota = 87,
  String? nivel = 'Alto',
  String? motivo,
  List<Map<String, dynamic>> desempenos = const [],
}) {
  return {
    'asignatura_id': id,
    'materia': materia,
    'alias_materia': 'Mate',
    'area_nombre': 'Ciencias',
    'nota_asignatura': nota,
    'desempenio': nivel,
    'motivo_del_nivel': motivo,
    'total_ausencias': 0,
    'total_tardanzas': 0,
    'desempenos': desempenos,
  };
}

/// Una línea del catálogo, tal como la monta `ponerLosDesempenos`: el texto ya
/// trae el prefijo de la banda pegado delante.
Map<String, dynamic> delCatalogo(
  String texto, {
  int id = 100,
  dynamic orden = 1,
  String? nivel = 'Alto',
  dynamic escalaId = 1,
  String? tipo,
  dynamic gradoId,
  String? iconoInfantil,
  String? iconoAdolescente,
}) {
  return {
    'desempeno_id': id,
    'frase_asignatura_id': null,
    'texto': texto,
    'tipo': tipo,
    'orden': orden,
    'grado_id': gradoId,
    'escala_id': nivel == null ? null : escalaId,
    'nivel': nivel,
    'icono_infantil': iconoInfantil,
    'icono_adolescente': iconoAdolescente,
    'origen': 'catalogo',
  };
}

/// Una frase escrita a mano por el docente para ESE alumno: sin nivel, sin
/// escala, sin iconos y sin orden.
Map<String, dynamic> deFrase(String texto, {int id = 700}) {
  return {
    'desempeno_id': null,
    'frase_asignatura_id': id,
    'texto': texto,
    'tipo': null,
    'orden': null,
    'grado_id': null,
    'escala_id': null,
    'nivel': null,
    'icono_infantil': null,
    'icono_adolescente': null,
    'origen': 'frase',
  };
}

Future<BoletinDeCompetencias> traer(
  ServidorFingido servidor, {
  int alumnoId = 31,
  int grupoId = 9,
  int? matriculaId,
  int? periodoId,
}) {
  return traerBoletinPorCompetencias(
    servidor,
    grupoId: grupoId,
    alumnoId: alumnoId,
    matriculaId: matriculaId,
    periodoId: periodoId,
  );
}

void main() {
  group('lo que se le pide al servidor', () {
    test('se pide UN alumno, por su alumno_id, en la ruta del grupo', () async {
      final servidor = ServidorFingido(boletin([alumnoCon(31)]));

      await traer(servidor, alumnoId: 31, grupoId: 9, matriculaId: 431);

      expect(servidor.rutas.single, '/boletines-competencias/detailed-notas/9');

      final pedidos = (servidor.cuerpos.single as Map)['requested_alumnos'];
      // Uno solo: con dos, el guard `boletin.propio` contesta 403 a una
      // familia, porque deja de saber de quién es el boletín.
      expect(pedidos, hasLength(1));
      expect(pedidos.single['alumno_id'], 31);
      // La matrícula sólo hace falta para un retirado, pero se manda cuando se
      // sabe: sin ella, `Grupo::alumnos` no lo trae.
      expect(pedidos.single['matricula_id'], 431);
    });

    test('sin matrícula no se inventa la clave', () async {
      final servidor = ServidorFingido(boletin([alumnoCon(31)]));

      await traer(servidor);

      final pedidos = (servidor.cuerpos.single as Map)['requested_alumnos'];
      expect(pedidos.single.containsKey('matricula_id'), isFalse);
      // Y sin periodo pedido, el cuerpo no lo nombra: su ausencia es lo que
      // significa «el periodo activo».
      expect(
          (servidor.cuerpos.single as Map).containsKey('periodo_id'), isFalse);
    });

    test('un periodo pasado viaja en el cuerpo', () async {
      final servidor = ServidorFingido(boletin([alumnoCon(31)]));

      await traer(servidor, periodoId: 22);

      expect((servidor.cuerpos.single as Map)['periodo_id'], 22);
    });
  });

  group('el filtro por alumno', () {
    test('descarta a los compañeros que el servidor mande de más', () async {
      // El servidor filtra —`soloLosPedidos`—, pero ese filtro es condicional:
      // si `requested_alumnos` no le llega como espera, devuelve la lista
      // entera, y `Grupo::alumnos` de por sí devuelve un superconjunto. Lo que
      // cuesta que falle es el boletín de los treinta compañeros dentro de la
      // cuenta de un acudiente.
      final servidor = ServidorFingido(boletin([
        alumnoCon(29, nombres: 'Ana'),
        alumnoCon(31, nombres: 'Damaris'),
        alumnoCon(33, nombres: 'Zoe'),
      ]));

      final mio = await traer(servidor, alumnoId: 31);

      expect(mio.alumnoId, 31);
      expect(mio.nombres, 'Damaris');
    });

    test('no coge el primero de la lista', () async {
      // Vienen ordenados por apellido, así que el primero es casi nunca el que
      // se pidió.
      final servidor = ServidorFingido(boletin([
        alumnoCon(29, nombres: 'Ana'),
        alumnoCon(33, nombres: 'Zoe'),
      ]));

      expect(traer(servidor, alumnoId: 31), throwsA(isA<Exception>()));
    });

    test('el alumno_id se compara como número aunque llegue como cadena',
        () async {
      // Los listados van por `DB::select` a pelo y el tipo lo decide PDO:
      // comparar '31' con 31 a pelo descartaría justo al alumno correcto.
      final servidor = ServidorFingido(respuestaJson([
        {'grupo_id': 9, 'caritas': '0'},
        {'periodo': '2'},
        [
          {'alumno_id': '29', 'nombres': 'Ana', 'asignaturas': []},
          {'alumno_id': '31', 'nombres': 'Damaris', 'asignaturas': []},
        ],
        [],
        {'alumnos': 2},
      ]));

      final mio = await traer(servidor, alumnoId: 31);

      expect(mio.alumnoId, 31);
      expect(mio.nombres, 'Damaris');
    });
  });

  group('las líneas de una asignatura', () {
    Future<AsignaturaDelBoletin> mate(
      List<Map<String, dynamic>> lineas, {
      String? nivel = 'Alto',
      String? motivo,
      bool caritas = false,
    }) async {
      final servidor = ServidorFingido(boletin(
        [
          alumnoCon(31, asignaturas: [
            asignaturaCon(nivel: nivel, motivo: motivo, desempenos: lineas),
          ]),
        ],
        caritas: caritas,
      ));

      final mio = await traer(servidor);
      return mio.asignaturas.single;
    }

    test('el texto se pinta tal cual: el prefijo ya viene montado', () async {
      // `conElPrefijo` pega la frase del SIEE delante en el servidor. Armarlo
      // otra vez aquí sería un segundo sitio donde vive la misma regla, y el
      // día que alguien toque uno el papel y la pantalla dejan de coincidir.
      final asignatura = await mate([
        delCatalogo('Fortaleza en interpretar graficas de barras.'),
      ]);

      expect(asignatura.lineas.single.texto,
          'Fortaleza en interpretar graficas de barras.');
    });

    test('no se le añade el nivel ni se le recorta nada', () async {
      // El servidor recorta el prefijo y NO el texto: si el docente escribió
      // la competencia con un espacio delante, el papel imprime dos espacios.
      // Esto es un boletín, no un corrector.
      final asignatura = await mate([
        delCatalogo('  Fortaleza en  interpretar graficas ', nivel: 'Alto'),
      ]);

      final linea = asignatura.lineas.single;
      expect(linea.texto, '  Fortaleza en  interpretar graficas ');
      expect(linea.texto.contains('Alto'), isFalse);
      expect(linea.nivel, 'Alto');
    });

    test('una frase del docente sale sin nivel y al final', () async {
      // Y no es un olvido: una frase escrita sobre un alumno concreto no es
      // una fila de un plan de área, así que ponerle la banda de la asignatura
      // sería afirmar algo que nadie dijo.
      final asignatura = await mate([
        delCatalogo('Fortaleza en interpretar graficas.', id: 100),
        delCatalogo('Fortaleza en resolver problemas.', id: 101, orden: 2),
        deFrase('Mejoro mucho en el segundo periodo.'),
      ]);

      final ultima = asignatura.lineas.last;
      expect(ultima.esFraseDelDocente, isTrue);
      expect(ultima.esDelCatalogo, isFalse);
      expect(ultima.tieneNivel, isFalse);
      expect(ultima.nivel, isNull);
      expect(ultima.escalaId, isNull);
      expect(ultima.fraseAsignaturaId, 700);
      expect(ultima.desempenoId, isNull);

      expect(asignatura.frasesDelDocente, hasLength(1));
      expect(asignatura.delCatalogo, hasLength(2));
      // Y las del catálogo, que sí la llevan.
      expect(asignatura.delCatalogo.every((l) => l.tieneNivel), isTrue);
    });

    test('las líneas conservan el orden recibido', () async {
      // El orden lo hace el servidor —«todos los grados» antes que las del
      // grado, y dentro por `orden` con `id` de desempate— y es el mismo de la
      // pantalla donde el colegio las teclea. Reordenarlas aquí por `orden`
      // separaría la app del papel.
      final asignatura = await mate([
        delCatalogo('Tercera en llegar.', id: 100, orden: 9),
        delCatalogo('Primera en llegar.', id: 101, orden: 2),
        delCatalogo('Segunda en llegar.', id: 102, orden: 5),
        deFrase('La frase, siempre la ultima.'),
      ]);

      expect(
        asignatura.lineas.map((l) => l.texto).toList(),
        [
          'Tercera en llegar.',
          'Primera en llegar.',
          'Segunda en llegar.',
          'La frase, siempre la ultima.',
        ],
      );
    });

    test('los enteros llegan como cadena y se leen igual', () async {
      // PDO decide el tipo de cada columna, así que un id puede venir como
      // cadena. Antes esto reventaba el parseo entero de la lista.
      final asignatura = await mate([
        delCatalogo('Fortaleza en interpretar graficas.',
            id: 100, orden: '3', escalaId: '4', gradoId: '7'),
      ]);

      final linea = asignatura.lineas.single;
      expect(linea.desempenoId, 100);
      expect(linea.orden, 3);
      expect(linea.escalaId, 4);
      expect(linea.gradoId, 7);
      // Y la definitiva, que además puede traer decimales desde que es
      // DECIMAL(7,4).
      expect(asignatura.nota, 87);
      expect(asignatura.notaEscrita, '87');
    });

    test('el nivel es uno por asignatura, repetido en todas sus líneas',
        () async {
      // P1.bis: se deriva de la definitiva de la asignatura, no de cada
      // competencia. Que se repita es lo que significa.
      final asignatura = await mate([
        delCatalogo('Fortaleza en A.', id: 100),
        delCatalogo('Fortaleza en B.', id: 101),
      ]);

      expect(asignatura.nivel, 'Alto');
      expect(asignatura.delCatalogo.map((l) => l.nivel), ['Alto', 'Alto']);
    });

    test('sin definitiva se queda sin nivel, y el motivo lo dice', () async {
      // Un nivel vacío tiene dos causas y no son la misma: o no hay nota que
      // traducir, o la nota no cae en ninguna banda de la escala.
      final asignatura = await mate(
        [delCatalogo('Fortaleza en interpretar graficas.', nivel: null)],
        nivel: null,
        motivo: 'sin_definitiva',
      );

      expect(asignatura.tieneNivel, isFalse);
      expect(asignatura.motivoSinNivel, MotivoSinNivel.sinDefinitiva);
      expect(asignatura.lineas.single.tieneNivel, isFalse);
      // Y la línea se imprime igual: el plan de área sale entero, tenga el
      // alumno nota o no.
      expect(
          asignatura.lineas.single.texto, 'Fortaleza en interpretar graficas.');
    });

    test('una nota que no cae en ninguna banda no es lo mismo que no tenerla',
        () async {
      final asignatura = await mate(
        [delCatalogo('Fortaleza en interpretar graficas.', nivel: null)],
        nivel: null,
        motivo: 'sin_banda',
      );

      expect(asignatura.motivoSinNivel, MotivoSinNivel.sinBanda);
    });

    test('sin plan de área la asignatura sale con nota y sin nada debajo',
        () async {
      // Es el fallo que de verdad ocurre: el colegio no escribió el plan de
      // esa materia y ese grado. Una frase del docente no lo tapa.
      final asignatura = await mate([deFrase('Le felicito por su esfuerzo.')]);

      expect(asignatura.sinCatalogo, isTrue);
      expect(asignatura.lineas, hasLength(1));
    });

    test('los iconos son adorno y sólo vienen con caritas', () async {
      // D17: el nivel viaja en TEXTO siempre. Una carita no es un informe
      // descriptivo, así que nunca sustituye a la palabra.
      final conCaritas = await mate(
        [
          delCatalogo('Fortaleza en contar hasta diez.',
              iconoInfantil: 'carita_feliz.png',
              iconoAdolescente: 'pulgar_arriba.png'),
        ],
        caritas: true,
      );

      final linea = conCaritas.lineas.single;
      expect(linea.nivel, 'Alto');
      expect(linea.icono(infantil: true), 'carita_feliz.png');
      expect(linea.icono(infantil: false), 'pulgar_arriba.png');

      final sinCaritas = await mate([
        delCatalogo('Fortaleza en contar hasta diez.'),
      ]);

      expect(sinCaritas.lineas.single.nivel, 'Alto');
      expect(sinCaritas.lineas.single.icono(infantil: true), isNull);
    });
  });

  group('el boletín entero', () {
    test('trae sus asignaturas en el orden del servidor y dice si hay caritas',
        () async {
      final servidor = ServidorFingido(boletin(
        [
          alumnoCon(31, asignaturas: [
            asignaturaCon(id: 5, materia: 'Matematicas', desempenos: [
              delCatalogo('Fortaleza en interpretar graficas.'),
            ]),
            asignaturaCon(id: 6, materia: 'Lengua', desempenos: []),
          ]),
        ],
        caritas: true,
      ));

      final mio = await traer(servidor);

      expect(mio.nombreCompleto, 'Damaris Gomez Pico');
      expect(mio.caritas, isTrue);
      expect(mio.asignaturas.map((a) => a.materia), ['Matematicas', 'Lengua']);
      expect(mio.tieneLineas, isTrue);
      expect(mio.asignaturas.last.sinCatalogo, isTrue);
    });

    test('sin una sola línea en ninguna asignatura se sabe decir', () async {
      // Para que la pantalla pueda no pintar el bloque en lugar de pintar doce
      // materias con un hueco debajo.
      final servidor = ServidorFingido(boletin([
        alumnoCon(31, asignaturas: [asignaturaCon(desempenos: [])]),
      ]));

      expect((await traer(servidor)).tieneLineas, isFalse);
    });

    test('una respuesta que no es la tupla de cinco no se lee a medias',
        () async {
      final servidor = ServidorFingido(respuestaJson([
        {'grupo_id': 9},
        {'periodo': 2},
      ]));

      expect(traer(servidor), throwsA(isA<Exception>()));
    });
  });

  group('los bloqueos', () {
    test('el paz y salvo no es un error de red', () async {
      // `boletin.propio` retiene el boletín de quien debe en tesorería.
      // Enseñar «no se pudo conectar» a ese padre le manda a reiniciar el
      // teléfono en vez de al colegio.
      final servidor = ServidorFingido(respuestaJson(
        {'message': 'No está a paz y salvo. Lo siento.'},
        codigo: 403,
      ));

      await expectLater(
        traer(servidor),
        throwsA(isA<NotasBloqueadas>().having(
          (e) => e.motivo,
          'motivo',
          MotivoBloqueo.tesoreria,
        )),
      );
    });

    test('se reconoce aunque el servidor conteste su página de error en HTML',
        () async {
      // El cliente no manda `Accept: application/json`, así que Laravel puede
      // contestar la página de error. Por eso se busca «paz y salvo», que es
      // ASCII y sobrevive al HTML y a una decodificación en latin1.
      final servidor = ServidorFingido(http.Response(
        '<!DOCTYPE html><html><body>403 No est&aacute; a paz y salvo.'
        ' Lo siento.</body></html>',
        403,
      ));

      await expectLater(
        traer(servidor),
        throwsA(isA<NotasBloqueadas>().having(
          (e) => e.motivo,
          'motivo',
          MotivoBloqueo.tesoreria,
        )),
      );
    });

    test('los otros 403 del guard no son un bloqueo de tesorería', () async {
      // «Pedis más de lo que debes», «No puedes ver el de otros» y «No es
      // acudiente de este alumno» son el mismo número y otra cosa: fallos de
      // quien llama o cuentas mal emparejadas, no algo que explicarle a una
      // familia como una deuda.
      final servidor = ServidorFingido(respuestaJson(
        {'message': 'No puedes ver el de otros'},
        codigo: 403,
      ));

      await expectLater(
        traer(servidor),
        throwsA(allOf(
          isA<Exception>(),
          isNot(isA<NotasBloqueadas>()),
          predicate((e) => '$e'.contains('No puedes ver el de otros'),
              'dice lo que dijo el servidor'),
        )),
      );
    });

    test('un 404 dice lo que dijo el servidor, y si no, el número', () async {
      // Las dos rutas están en `main` de 8myvc y sin desplegar: hoy esto es un
      // 404 en cualquier colegio.
      final servidor = ServidorFingido(http.Response('', 404));

      await expectLater(
        traer(servidor),
        throwsA(isA<Exception>().having(
          (e) => '$e',
          'mensaje',
          contains('404'),
        )),
      );
    });
  });
}
