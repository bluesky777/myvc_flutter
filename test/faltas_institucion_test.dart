import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Models/TipoFalta.dart';

/// Las faltas a la institución son dos: llegó tarde, o no vino en todo el día.
/// El backend las devuelve en dos listas separadas de /asistencias/detailed.
Map<String, dynamic> _alumnoCrudo({
  List<Map<String, dynamic>> tardanzas = const [],
  List<Map<String, dynamic>> ausencias = const [],
}) {
  return {
    'alumno_id': 1,
    'nombres': 'JUAN',
    'apellidos': 'PÉREZ',
    'sexo': 'M',
    'tardanzas': tardanzas,
    'ausencias': ausencias,
    'ausencias_total': {
      'cant_tardanzas_entrada': 3,
      'cant_ausencias_entrada': 2,
    },
  };
}

Map<String, dynamic> _falta(int id, String tipo, String fechaHora) => {
      'id': id,
      'alumno_id': 1,
      'entrada': 1,
      'periodo_id': 31,
      'tipo': tipo,
      'fecha_hora': fechaHora,
    };

void main() {
  test('las ausencias a la institución se leen, no solo las tardanzas', () {
    final alumno = AlumnoModel.fromJson(_alumnoCrudo(
      tardanzas: [_falta(1, 'tardanza', '2026-08-19 07:10:00')],
      ausencias: [_falta(2, 'ausencia', '2026-08-19 00:00:00')],
    ));

    expect(alumno.tardanzasEntrada, hasLength(1));
    expect(alumno.ausenciasEntrada, hasLength(1));
  });

  test('cada tipo cuenta solo lo suyo en el día elegido', () {
    final alumno = AlumnoModel.fromJson(_alumnoCrudo(
      tardanzas: [
        _falta(1, 'tardanza', '2026-08-19 07:10:00'),
        _falta(2, 'tardanza', '2026-08-12 07:20:00'),
      ],
      ausencias: [_falta(3, 'ausencia', '2026-08-12 00:00:00')],
    ));

    final diecinueve = DateTime(2026, 8, 19);
    final doce = DateTime(2026, 8, 12);

    expect(alumno.tardanzasDelDia(diecinueve), hasLength(1));
    expect(alumno.ausenciasDelDia(diecinueve), isEmpty);
    expect(alumno.tieneAusenciaEn(diecinueve), isFalse);

    expect(alumno.tardanzasDelDia(doce), hasLength(1));
    expect(alumno.ausenciasDelDia(doce), hasLength(1));
    expect(alumno.tieneAusenciaEn(doce), isTrue);
  });

  test('un alumno sin faltas no revienta ni inventa listas nulas', () {
    final alumno = AlumnoModel.fromJson(_alumnoCrudo());

    expect(alumno.tardanzasEntrada, isEmpty);
    expect(alumno.ausenciasEntrada, isEmpty);
    expect(alumno.ausenciasDelDia(DateTime(2026, 8, 19)), isEmpty);
  });

  test('los totales del periodo van en claves distintas', () {
    final alumno = AlumnoModel.fromJson(_alumnoCrudo());

    expect(alumno.ausenciasTotal![TipoFalta.tardanza.claveTotal], 3);
    expect(alumno.ausenciasTotal![TipoFalta.ausencia.claveTotal], 2);
  });

  test('el tipo sabe decirse en singular y en plural', () {
    expect(TipoFalta.tardanza.contar(1), '1 tardanza');
    expect(TipoFalta.tardanza.contar(3), '3 tardanzas');
    expect(TipoFalta.ausencia.contar(0), '0 ausencias');
    expect(TipoFalta.ausencia.contar(1), '1 ausencia');
  });

  test('el valor que viaja al backend es el de la columna tipo', () {
    expect(TipoFalta.tardanza.valor, 'tardanza');
    expect(TipoFalta.ausencia.valor, 'ausencia');
  });

  group('el histórico separa lo que el backend devuelve junto', () {
    // tardanzas_perN de /disciplina/alumnos filtra por entrada=1 pero NO por
    // tipo: ahí vienen las tardanzas y las ausencias mezcladas.
    final mezcladas = [
      AsistenciaModel.fromJson(_falta(1, 'tardanza', '2026-08-10 07:40:00')),
      AsistenciaModel.fromJson(_falta(2, 'ausencia', '2026-08-12 00:00:00')),
      AsistenciaModel.fromJson(_falta(3, 'tardanza', '2026-08-19 07:15:00')),
    ];

    test('las tardanzas son las de tipo tardanza', () {
      final soloTardanzas = soloDelTipo(mezcladas, TipoFalta.tardanza);

      expect(soloTardanzas.map((f) => f.id), [1, 3]);
    });

    test('las ausencias dejan de contarse como tardanzas', () {
      final soloAusencias = soloDelTipo(mezcladas, TipoFalta.ausencia);

      expect(soloAusencias.map((f) => f.id), [2]);
    });

    test('una fila vieja sin tipo cuenta como tardanza', () {
      final sinTipo = AsistenciaModel.fromJson({
        'id': 9,
        'alumno_id': 1,
        'entrada': 1,
        'periodo_id': 31,
        'tipo': null,
        'fecha_hora': '2019-03-04 07:00:00',
      });

      expect(soloDelTipo([sinTipo], TipoFalta.tardanza), hasLength(1));
      expect(soloDelTipo([sinTipo], TipoFalta.ausencia), isEmpty);
    });
  });
}
