import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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

  group('lo que dejó guardado una versión anterior', () {
    test('sin la clave mostrando, se asume que sí', () {
      final estado = SelectServerState.fromMap({
        'uriColegioSelected': {'nombre': 'Fortul', 'uri': 'https://coaf.com'},
      });

      expect(estado.mostrandoButtonSelectedUri, isTrue);
      expect(estado.uriColegioSelected.nombre, 'Fortul');
      // El logo tampoco estaba: cadena vacía, no una excepción.
      expect(estado.uriColegioSelected.logo, '');
    });

    test('sin colegio guardado no revienta al arrancar', () {
      final estado = SelectServerState.fromMap({'mostrando': false});

      expect(estado.mostrandoButtonSelectedUri, isFalse);
      expect(estado.uriColegioSelected.uri, isEmpty);
    });
  });

  test('sin nada guardado no hay colegio elegido', () {
    // El docente tiene que elegir el suyo: la app no arranca apuntando a
    // ningún servidor por su cuenta.
    final cubit = SelectServerCubit(UriColegio());

    expect(cubit.state.uriColegioSelected.uri, isEmpty);
    expect(cubit.state.uriColegioSelected.nombre, isEmpty);
  });
}
