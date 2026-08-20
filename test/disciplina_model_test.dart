import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AlumnoDisciplinaModel.dart';
import 'package:myvc_flutter/Models/ConfigDisciplinaModel.dart';
import 'package:myvc_flutter/Models/OrdinalModel.dart';
import 'package:myvc_flutter/Models/SituacionModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';
import 'package:myvc_flutter/Models/UniformeModel.dart';

void main() {
  group('la configuración de disciplina del año', () {
    test('usa los nombres que le puso el colegio', () {
      final config = ConfigDisciplinaModel.fromJson({
        'id': 3,
        'year_id': 9,
        'falta_tipo1_displayname': 'Situación leve',
        'faltas_tipo1_displayname': 'Situaciones leves',
        'falta_tipo2_displayname': 'Situación grave',
        'faltas_tipo2_displayname': 'Situaciones graves',
        'falta_tipo3_displayname': 'Situación gravísima',
        'faltas_tipo3_displayname': 'Situaciones gravísimas',
        'cant_tard_to_ft1': '4',
        'reinicia_por_periodo': 1,
      });

      expect(config.nombre(1), 'Situación leve');
      expect(config.nombres(2), 'Situaciones graves');
      expect(config.nombre(3), 'Situación gravísima');
      // Llega como cadena desde PDO y tiene que leerse como número.
      expect(config.tardanzasParaTipo1, 4);
      expect(config.reiniciaPorPeriodo, isTrue);
    });

    test('cae en los nombres por defecto cuando vienen vacíos', () {
      final config = ConfigDisciplinaModel.fromJson({
        'falta_tipo1_displayname': '',
        'faltas_tipo1_displayname': '   ',
      });

      expect(config.nombre(1), 'Situación tipo 1');
      expect(config.nombres(1), 'Situaciones tipo 1');
      // Y los umbrales, con los mismos valores que tiene la columna.
      expect(config.tipo1ParaTipo2, 3);
    });

    test('un tipo que no existe no revienta', () {
      expect(ConfigDisciplinaModel().nombre(7), 'Tipo 7');
    });

    test('abrevia «Situaciones tipo 1» y respeta «Leves»', () {
      final propio = ConfigDisciplinaModel(plural: ['Leves', 'Graves', 'X']);

      expect(ConfigDisciplinaModel().abreviado(2), 'tipo 2');
      expect(propio.abreviado(1), 'Leves');
    });
  });

  group('un ordinal del manual de convivencia', () {
    final ordinal = OrdinalModel.fromJson({
      'id': 41,
      'tipo': 'Tipo I',
      'ordinal': '3',
      'descripcion': 'No portar el uniforme completo',
    });

    test('se cita con su tipo y su número', () {
      expect(ordinal.numero, 'Tipo I - 3');
      expect(ordinal.rotulo, 'Tipo I - 3. No portar el uniforme completo');
    });

    test('no deja el guion colgando cuando falta una mitad', () {
      final soloTipo = OrdinalModel(id: 1, tipo: 'Tipo II', descripcion: 'Algo');
      final soloNumero = OrdinalModel(id: 2, ordinal: '9', descripcion: 'Otro');

      expect(soloTipo.numero, 'Tipo II');
      expect(soloNumero.numero, '9');
    });

    test('se busca sin acentos y por cualquiera de los dos campos', () {
      expect(ordinal.coincideCon('uniforme'), isTrue);
      expect(ordinal.coincideCon('tipo i'), isTrue);
      expect(ordinal.coincideCon('TIPO I - 3'), isTrue);
      expect(ordinal.coincideCon('cabello'), isFalse);
      // La lista entera cuando no se ha escrito nada.
      expect(ordinal.coincideCon('   '), isTrue);

      final conTilde = OrdinalModel(id: 3, descripcion: 'Agresión física');
      expect(conTilde.coincideCon('agresion'), isTrue);
    });
  });

  group('una situación', () {
    test('saca los ordinales de ordinal_id y no del id de la pivote', () {
      final situacion = SituacionModel.fromJson({
        'id': 700,
        'tipo_situacion': 2,
        'descripcion': 'Se salió de clase',
        'proceso_ordinales': [
          // El `id` es el de la FILA PIVOTE; el del ordinal es `ordinal_id`.
          {'id': 5001, 'ordinal_id': 41, 'proceso_id': 700},
          {'id': 5002, 'ordinal_id': 44, 'proceso_id': 700},
        ],
      });

      expect(situacion.ordinalIds, [41, 44]);
    });

    test('cruza sus ordinales contra el catálogo del año', () {
      final catalogo = [
        OrdinalModel(id: 41, tipo: 'Tipo I', ordinal: '3', descripcion: 'Uno'),
        OrdinalModel(id: 44, tipo: 'Tipo II', ordinal: '1', descripcion: 'Dos'),
        OrdinalModel(id: 99, descripcion: 'Ni pintado'),
      ];

      final situacion = SituacionModel(id: 1, ordinalIds: [44, 41]);
      final resueltos = situacion.ordinalesDe(catalogo);

      // En el orden en que los tiene la situación, no en el del catálogo.
      expect(resueltos.map((o) => o.id), [44, 41]);
      expect(resueltos.first.descripcion, 'Dos');
    });

    test('un ordinal que ya no está en el catálogo se salta', () {
      final situacion = SituacionModel(id: 1, ordinalIds: [41, 1234]);

      expect(
        situacion.ordinalesDe([OrdinalModel(id: 41, descripcion: 'Uno')]).length,
        1,
      );
    });

    test('lee la fecha de MySQL y descarta la del año cero', () {
      final buena = SituacionModel.fromJson({
        'id': 1,
        'fecha_hora_aprox': '2026-08-19 07:15:00',
      });
      final rota = SituacionModel.fromJson({
        'id': 2,
        'fecha_hora_aprox': '0000-00-00 00:00:00',
      });

      expect(buena.fecha, DateTime(2026, 8, 19, 7, 15));
      expect(rota.fecha, isNull);
    });

    test('sabe cuándo fue absorbida por otra derivada de ella', () {
      expect(SituacionModel(id: 1).absorbida, isFalse);
      expect(SituacionModel(id: 1, absorbidaPor: 8).absorbida, isTrue);
    });

    test('un profesor a medias no deja un nombre con espacios sueltos', () {
      final sinNombre =
          SituacionModel.fromJson({'id': 1, 'profesor_nombre': '  '});

      expect(sinNombre.profesorNombre, isNull);
    });
  });

  group('una falla de uniforme', () {
    test('recoge las marcas encendidas', () {
      final uniforme = UniformeModel.fromJson({
        'id': 12,
        'alumno_id': 300,
        'periodo_id': 7,
        'fecha_hora': '2026-08-19 07:05:00',
        'camara': 0,
        'contrario': '1',
        'sin_uniforme': 0,
        'incompleto': 1,
        'cabello': 0,
        'accesorios': 0,
        'excusado': 1,
      });

      expect(uniforme.marcas,
          {MarcaUniforme.contrario, MarcaUniforme.incompleto});
      expect(uniforme.excusado, isTrue);
      expect(uniforme.nombresDeMarcas, ['Contrario', 'Incompleto']);
    });

    test('manda las siete columnas siempre, apagadas incluidas', () {
      final cuerpo = UniformeModel(
        id: 1,
        marcas: {MarcaUniforme.cabello},
        fechaHora: DateTime(2026, 8, 19, 7, 5),
      ).aCuerpo();

      for (final marca in MarcaUniforme.values) {
        expect(cuerpo.containsKey(marca.clave), isTrue,
            reason: 'falta ${marca.clave}');
      }
      expect(cuerpo['cabello'], 1);
      expect(cuerpo['camara'], 0);
      expect(cuerpo['fecha_hora'], '2026-08-19 07:05:00');
    });
  });

  group('un alumno de PUT disciplina/alumnos', () {
    // Recortado de la forma real: el backend cuelga cada periodo del alumno
    // como claves con el número pegado.
    final crudo = <String, dynamic>{
      'alumno_id': 300,
      'nombres': 'Ana María',
      'apellidos': 'Acosta Pérez',
      'foto_nombre': 'user_2/ana.jpg',
      'estado': 'ASIS',
      'periodo1': [
        {'id': 1, 'tipo_situacion': 1, 'descripcion': 'Una', 'periodo_numero': 1},
        {'id': 2, 'tipo_situacion': 1, 'descripcion': 'Otra', 'become_id': 3},
        {'id': 3, 'tipo_situacion': 2, 'descripcion': 'La grave'},
      ],
      // El backend NO cuenta la absorbida: dos tipo 1 en la lista, una sola
      // en el contador.
      'per1_cant_t1': 1,
      'per1_cant_t2': '1',
      'per1_cant_t3': 0,
      'uniformes_per1': [
        {'id': 10, 'incompleto': 1},
        {'id': 11, 'cabello': 1},
      ],
      'tardanzas_per1': [
        {'id': 60, 'entrada': 1, 'tipo': 'tardanza'},
        {'id': 61, 'entrada': 1, 'tipo': 'ausencia'},
        // Las filas viejas no traen tipo: cuentan como tardanza.
        {'id': 62, 'entrada': 1},
      ],
      'periodo2': [],
      'per2_cant_t1': 0,
      'per2_cant_t2': 0,
      'per2_cant_t3': 0,
      'uniformes_per2': [],
      'tardanzas_per2': [],
    };

    test('reparte cada periodo en su sitio', () {
      final alumno = AlumnoDisciplinaModel.fromJson(crudo);

      expect(alumno.alumnoId, 300);
      expect(alumno.nombreCompleto, 'Acosta Pérez Ana María');
      expect(alumno.esAsistente, isTrue);
      expect(alumno.periodos, [1, 2]);
      expect(alumno.situacionesDe(1).length, 3);
      expect(alumno.uniformesDe(1).length, 2);
    });

    test('cuenta las situaciones con el contador del backend', () {
      final alumno = AlumnoDisciplinaModel.fromJson(crudo);

      // Tres situaciones de tipo 1 en la lista serían dos; el backend dice
      // una, porque la segunda fue absorbida. Manda el backend.
      expect(alumno.situacionesDeTipo(1, 1).length, 2);
      expect(alumno.cuantasSituaciones(1, 1), 1);
      expect(alumno.cuantasSituaciones(1, 2), 1);
    });

    test('separa las tardanzas de las ausencias, que vienen mezcladas', () {
      final alumno = AlumnoDisciplinaModel.fromJson(crudo);

      expect(alumno.cuantasFaltas(1, TipoFalta.tardanza), 2);
      expect(alumno.cuantasFaltas(1, TipoFalta.ausencia), 1);
    });

    test('suma el total del periodo para la tira', () {
      final alumno = AlumnoDisciplinaModel.fromJson(crudo);

      // 2 uniformes + 2 tardanzas + 1 ausencia + 1 tipo1 + 1 tipo2 = 7
      expect(alumno.totalDe(1), 7);
      expect(alumno.totalDe(2), 0);
      expect(alumno.tieneGravesEn(1), isTrue);
      expect(alumno.limpio, isFalse);
    });

    test('un alumno sin nada queda limpio', () {
      final alumno = AlumnoDisciplinaModel.fromJson({
        'alumno_id': 4,
        'nombres': 'Luis',
        'apellidos': 'Bolaño',
        'periodo1': [],
        'uniformes_per1': [],
        'tardanzas_per1': [],
      });

      expect(alumno.limpio, isTrue);
      expect(alumno.totalDe(1), 0);
      // Y preguntar por un periodo que no vino no revienta.
      expect(alumno.totalDe(4), 0);
    });

    test('una fila rota no se lleva por delante a las demás', () {
      final alumno = AlumnoDisciplinaModel.fromJson({
        'alumno_id': 5,
        'periodo1': [
          'esto no es un objeto',
          {'id': 9, 'tipo_situacion': 1, 'descripcion': 'Sí es'},
        ],
      });

      expect(alumno.situacionesDe(1).length, 1);
    });
  });
}
