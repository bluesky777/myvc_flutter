import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/AlumnoModel.dart';
import 'package:myvc_flutter/Models/AsistenciaModel.dart';
import 'package:myvc_flutter/Utils/JsonBackend.dart';

void main() {
  group('leer números del backend', () {
    test('un id que viene como cadena sigue siendo un número', () {
      // Es lo que devuelve PDO según cómo esté la conexión: '42', no 42.
      expect(entero('42'), 42);
      expect(entero(42), 42);
      expect(entero(42.0), 42);
    });

    test('lo que no es número da null, no una excepción', () {
      expect(entero(null), isNull);
      expect(entero(''), isNull);
      expect(entero('mañana'), isNull);
    });

    test('los booleanos de MySQL cuentan como 1 y 0', () {
      expect(entero(true), 1);
      expect(entero(false), 0);
    });

    test('sin mapa de totales, mapa vacío y no un fallo', () {
      expect(mapaDeEnteros(null), isEmpty);
      expect(mapaDeEnteros('nada'), isEmpty);
    });

    test('los contadores se leen aunque vengan como cadenas', () {
      final total = mapaDeEnteros({
        'cant_tardanzas_entrada': '3',
        'cant_ausencias_entrada': 1,
      });

      expect(total['cant_tardanzas_entrada'], 3);
      expect(total['cant_ausencias_entrada'], 1);
    });
  });

  group('un alumno con datos raros', () {
    test('no tumba el parseo aunque falte ausencias_total', () {
      final alumno = AlumnoModel.fromJson({
        'alumno_id': '17',
        'nombres': 'Dámaris',
        'apellidos': null,
        'sexo': 'F',
      });

      expect(alumno.id, 17);
      expect(alumno.apellidos, isNull);
      expect(alumno.ausenciasTotal, isEmpty);
      expect(alumno.tardanzasEntrada, isEmpty);
    });

    test('una falta ilegible no se lleva por delante a las demás', () {
      final alumno = AlumnoModel.fromJson({
        'alumno_id': 5,
        'nombres': 'Ariolfo',
        'sexo': 'M',
        'tardanzas': [
          'esto no es una fila',
          {'id': 9, 'alumno_id': 5, 'entrada': 1, 'fecha_hora': '2026-08-19 07:30:00'},
        ],
        'ausencias_total': {'cant_tardanzas_entrada': '1'},
      });

      expect(alumno.tardanzasEntrada!.length, 1);
      expect(alumno.tardanzasEntrada!.first.id, 9);
    });
  });

  group('una falta recién creada', () {
    test('se lee aunque el servidor mande los números como cadenas', () {
      // Así responde POST /ausencias/store: la fila entera, con los tipos que
      // le salgan al driver.
      final falta = AsistenciaModel.fromJson({
        'alumno_id': '17',
        'asignatura_id': null,
        'periodo_id': '4',
        'entrada': '1',
        'tipo': 'tardanza',
        'fecha_hora': '2026-08-19 07:30:00',
        'created_by': '2',
        'created_at': '2026-08-19T12:30:00.000000Z',
        'id': '123',
      });

      expect(falta.id, 123);
      expect(falta.alumnoId, 17);
      expect(falta.entrada, 1);
      expect(falta.periodoId, 4);
      expect(falta.esDelDia(DateTime(2026, 8, 19)), isTrue);
    });

    test('sin fecha_hora no hay día, pero tampoco excepción', () {
      final falta = AsistenciaModel.fromJson({'id': 1, 'alumno_id': 2});

      expect(falta.fecha, isNull);
      expect(falta.fechaHora, isNull);
      expect(falta.esDelDia(DateTime.now()), isFalse);
    });
  });
}
