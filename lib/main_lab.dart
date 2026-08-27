// BANCO DE PRUEBAS DE LAYOUT — no entra en la app publicada.
//
// Abre una pantalla sola, con datos escritos a mano y sin red, para poder mirar
// cómo queda en una tablet. Se lanza así:
//
//   flutter run -d emulator-5554 -t lib/main_lab.dart
//
// Existe porque decidir un layout de tablet obligaba, si no, a entrar con las
// credenciales de un colegio de verdad —que no están en el repositorio, y a
// propósito— y a mirar datos de alumnos reales para decidir un ancho.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Models/AsignaturaModel.dart';
import 'package:myvc_flutter/Screens/LibroAsignaturaScreen.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';

/// Un servidor que contesta siempre lo mismo, sin salir a la red.
class ServidorDeMentira extends Server {
  @override
  Future put(String direccion, params) async =>
      http.Response(jsonEncode(_libro), 200);

  @override
  Future get(String direccion) async => http.Response('{}', 200);
}

/// Cinco indicadores repartidos en dos unidades, que es el caso que se midió
/// mal en tablet: poco contenido y mucha pantalla.
final _libro = {
  'asignatura': {
    'asignatura_id': 1,
    'grupo_id': 7,
    'materia': 'Matemáticas',
    'alias_materia': 'Matemáticas',
    'nombre_grupo': 'Décimo B',
    'abrev_grupo': '10-B',
  },
  'unidades': [
    {
      'id': 10,
      'asignatura_id': 1,
      'periodo_id': 3,
      'definicion': 'Funciones y sus gráficas',
      'porcentaje': 60,
      'orden': 1,
      'subunidades': [
        {
          'id': 101,
          'unidad_id': 10,
          'definicion': 'Quiz de función lineal',
          'porcentaje': 20,
          'orden': 1,
        },
        {
          'id': 102,
          'unidad_id': 10,
          'definicion': 'Taller de pendiente y corte',
          'porcentaje': 20,
          'orden': 2,
        },
        {
          'id': 103,
          'unidad_id': 10,
          'definicion': 'Evaluación de la unidad',
          'porcentaje': 20,
          'orden': 3,
        },
      ],
    },
    {
      'id': 11,
      'asignatura_id': 1,
      'periodo_id': 3,
      'definicion': 'Sistemas de ecuaciones',
      'porcentaje': 40,
      'orden': 2,
      'subunidades': [
        {
          'id': 111,
          'unidad_id': 11,
          'definicion': 'Método de sustitución',
          'porcentaje': 20,
          'orden': 1,
        },
        {
          'id': 112,
          'unidad_id': 11,
          'definicion': 'Problemas de aplicación',
          'porcentaje': 20,
          'orden': 2,
        },
      ],
    },
  ],
  'alumnos': [
    for (var i = 0; i < 30; i++)
      {
        'alumno_id': 100 + i,
        'nombres': _nombres[i % _nombres.length],
        'apellidos': _apellidos[i % _apellidos.length],
        'estado': 'MATR',
        'notas': [
          {'subunidad_id': 101, 'nota': 70 + (i % 30), 'id': 900 + i},
        ],
      },
  ],
};

const _nombres = [
  'Ana', 'Luis', 'Dámaris', 'Julián', 'Marcela', 'Andrés', 'Valentina',
  'Santiago', 'Camila', 'Nicolás',
];

const _apellidos = [
  'Acosta Pérez', 'Bolaño Díaz', 'Gómez Pico', 'Herrera Ruiz', 'Ibarra Solano',
];

void main() {
  AuthService.user = UserAutenticado(
    username: 'lab',
    nombres: 'Banco de pruebas',
    tipo: 'Profesor',
  );

  ContextoAcademico.instancia.numeroPeriodo = 3;

  runApp(MaterialApp(
    title: 'Banco de pruebas',
    debugShowCheckedModeBanner: false,
    home: LibroAsignaturaScreen(
      asignatura: AsignaturaModel.fromJson(
        Map<String, dynamic>.from(_libro['asignatura'] as Map),
      ),
      servidor: ServidorDeMentira(),
    ),
  ));
}
