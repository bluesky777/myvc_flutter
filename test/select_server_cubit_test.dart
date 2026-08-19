import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myvc_flutter/Utils/DatosDesarrollo.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';
import 'package:myvc_flutter/cubit/select_server_cubit.dart';

/// Almacén en memoria: lo que se prueba es el cubit, no el disco.
class AlmacenEnMemoria implements Storage {
  final Map<String, dynamic> datos = {};

  @override
  dynamic read(String key) => datos[key];

  @override
  Future<void> write(String key, dynamic value) async => datos[key] = value;

  @override
  Future<void> delete(String key) async => datos.remove(key);

  @override
  Future<void> clear() async => datos.clear();

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() {
    HydratedBloc.storage = AlmacenEnMemoria();
  });

  test('elegir colegio no revienta al emitir', () {
    final cubit = SelectServerCubit(UriColegio());

    expect(
      () => cubit.selectUriColegio(
        UriColegio(nombre: 'Fortul', uri: 'https://coaf.micolevirtual.com'),
      ),
      returnsNormally,
    );
  });

  test('el colegio elegido sobrevive a reabrir la app', () {
    SelectServerCubit(UriColegio()).selectUriColegio(
      UriColegio(
        nombre: 'Saravena COAB',
        uri: 'https://coab.micolevirtual.com',
        logo: 'https://coab.micolevirtual.com/logo.png',
      ),
    );

    // Una instancia nueva es lo que ocurre al arrancar la app de nuevo.
    final alArrancarDeNuevo = SelectServerCubit(UriColegio());

    expect(alArrancarDeNuevo.state.uriColegioSelected.nombre, 'Saravena COAB');
    expect(
      alArrancarDeNuevo.state.uriColegioSelected.uri,
      'https://coab.micolevirtual.com',
    );
  });

  test('en depuración arranca en el servidor local, sin elegir colegio', () {
    // Las pruebas corren en modo depuración, que es cuando esto está activo.
    expect(DatosDesarrollo.activo, isTrue);

    final cubit = SelectServerCubit(UriColegio());

    expect(cubit.state.uriColegioSelected.uri, DatosDesarrollo.servidor);
    // 'Otro' es lo que hace que LoginBloc trate la dirección como local.
    expect(cubit.state.uriColegioSelected.nombre, 'Otro');
  });

  test('el colegio guardado manda sobre el atajo de depuración', () {
    SelectServerCubit(UriColegio()).selectUriColegio(
      UriColegio(nombre: 'Fortul', uri: 'https://coaf.micolevirtual.com'),
    );

    final alArrancarDeNuevo = SelectServerCubit(UriColegio());

    expect(alArrancarDeNuevo.state.uriColegioSelected.nombre, 'Fortul');
  });
}
