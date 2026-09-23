import 'package:flutter/material.dart';

/// La llave del navegador de la app, arriba del todo.
///
/// Existe porque **tocar una notificación no ocurre dentro de ninguna
/// pantalla**: el aviso llega al proceso, no a un widget, y a veces llega con
/// la app cerrada y sin un solo `BuildContext` montado. Sin una llave global no
/// hay forma de decir «abre Mis notas» desde ahí.
///
/// Es lo único que se comparte así. Todo lo demás navega con el `context` que
/// tiene a mano, que es lo correcto cuando se tiene.
final GlobalKey<NavigatorState> navegadorDeLaApp = GlobalKey<NavigatorState>();
