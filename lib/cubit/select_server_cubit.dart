import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'select_server_state.dart';

class SelectServerCubit extends Cubit<SelectServerState> {
  SelectServerCubit() : super(SelectServerState());

  void toggleMostrar() {
    emit(
      SelectServerState(mostrando: !state.mostrando),
    );
    print(state);
  }
}
