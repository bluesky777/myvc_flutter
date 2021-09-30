import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'select_server_state.dart';

class SelectServerCubit extends Cubit<SelectServerState> with HydratedMixin {
  SelectServerCubit() : super(SelectServerState());

  void toggleMostrar() {
    emit(
      SelectServerState(mostrando: !state.mostrando),
    );
    print(state);
  }

  @override
  SelectServerState? fromJson(Map<String, dynamic> json) {
    return SelectServerState.fromMap(json);
  }

  @override
  Map<String, dynamic>? toJson(SelectServerState state) {
    return state.toMap();
  }
}
