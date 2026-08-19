import 'dart:async';

import "package:equatable/equatable.dart";
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final SelectServerCubit selectServerCubit;

  LoginBloc({required this.selectServerCubit}) : super(LoginInitialState()) {
    // bloc 8 quitó mapEventToState y no dejó nada en su lugar: el método seguía
    // aquí con un @override que ya no overrideaba nada, y como no había ningún
    // on<...> registrado, pulsar "Entrar" no ejecutaba absolutamente nada.
    on<DoLoginEvent>(_alEntrar);
  }

  Future<void> _alEntrar(DoLoginEvent event, Emitter<LoginState> emit) async {
    final colegio = selectServerCubit.state.uriColegioSelected;
    final servidorElegido = colegio.uri;
    final isLocal = colegio.nombre == 'Otro';

    if (servidorElegido.isEmpty) {
      emit(LoginErrorState('Elige primero tu colegio.'));
      return;
    }

    emit(LoggingInState());

    try {
      final token = await LoginController().login(
        event.username,
        event.password,
        isLocal,
        servidorElegido,
      );

      emit(LoggedState(token));
    } on LoginException catch (err) {
      emit(LoginErrorState(err.mensaje));
    } catch (err) {
      // Que nada quede en silencio: antes cualquier fallo que no fuera
      // LoginException se escapaba sin que el docente viera nada.
      emit(LoginErrorState('Fallo inesperado al entrar:\n$err'));
    }
  }
}
