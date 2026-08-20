import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Utils/PreferenciasSesion.dart';
import 'package:myvc_flutter/Utils/SesionGuardada.dart';
import 'package:myvc_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la sesión que sobrevive a recargar', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('se guarda con su servidor y se vuelve a leer', () async {
      await SesionGuardada.guardar(
        token: '568|abc',
        servidor: 'https://lalvirtual.edu.co',
        usuario: '{"username":"pgomez","tipo":"Profesor"}',
        local: false,
      );

      final leida = await SesionGuardada.leer();

      expect(leida, isNotNull);
      expect(leida!.token, '568|abc');
      expect(leida.servidor, 'https://lalvirtual.edu.co');
      expect(leida.usuario, contains('pgomez'));
      expect(leida.local, isFalse);
    });

    test('sin nada guardado no hay sesión', () async {
      expect(await SesionGuardada.leer(), isNull);
    });

    test('un token sin servidor no vale', () async {
      // Sin saber a qué colegio preguntar, el token no sirve para nada: no hay
      // forma de comprobarlo ni de usarlo.
      SharedPreferences.setMockInitialValues(
          {SesionGuardada.claveToken: '568|abc'});

      expect(await SesionGuardada.leer(), isNull);
    });

    test('sin quién entró tampoco vale', () async {
      // Arrancar sin saber quién es ni con qué periodo es medio funcionar, y
      // eso se ve peor que no funcionar.
      SharedPreferences.setMockInitialValues({
        SesionGuardada.claveToken: '568|abc',
        SesionGuardada.claveServidor: 'https://lalvirtual.edu.co',
      });

      expect(await SesionGuardada.leer(), isNull);
    });

    test('en un equipo compartido no se guarda nada', () async {
      // La casilla de recordar está desmarcada: el docente siguiente no puede
      // encontrarse la sesión del anterior ya abierta.
      await PreferenciasSesion.setGuardarDatos(false);

      await SesionGuardada.guardar(
        token: '568|abc',
        servidor: 'https://lalvirtual.edu.co',
        usuario: '{"username":"pgomez"}',
        local: false,
      );

      expect(await SesionGuardada.leer(), isNull);
    });

    test('cambiar de periodo pone al día lo guardado', () async {
      await SesionGuardada.guardar(
        token: '568|abc',
        servidor: 'https://lalvirtual.edu.co',
        usuario: '{"username":"pgomez","numero_periodo":1}',
        local: false,
      );

      await SesionGuardada.actualizarUsuario(
          '{"username":"pgomez","numero_periodo":3}');

      final leida = await SesionGuardada.leer();

      expect(leida!.usuario, contains('"numero_periodo":3'));
      expect(leida.token, '568|abc', reason: 'el token no se toca');
    });

    test('poner al día no crea una sesión donde no la había', () async {
      // En el equipo compartido no se guarda nada, y esto no puede ser la
      // puerta de atrás por la que se guarde.
      await SesionGuardada.actualizarUsuario('{"username":"pgomez"}');

      expect(await SesionGuardada.leer(), isNull);
    });

    test('cerrar sesión se lleva lo guardado', () async {
      await SesionGuardada.guardar(
        token: '568|abc',
        servidor: 'https://lalvirtual.edu.co',
        usuario: '{"username":"pgomez"}',
        local: false,
      );
      await SesionGuardada.borrar();

      expect(await SesionGuardada.leer(), isNull);
    });
  });

  group('a qué servidor apunta la app', () {
    test('un colegio en internet cuelga de /8myvc/public', () {
      Server.apuntarA('https://lalvirtual.edu.co');

      expect(Server.urlApi, 'https://lalvirtual.edu.co/8myvc/public/api');
      expect(Server.urlImages,
          'https://lalvirtual.edu.co/8myvc/public/images/perfil');
    });

    test('un servidor escrito a mano va a la raíz', () {
      Server.apuntarA('http://192.168.1.5', otro: true);

      expect(Server.urlApi, 'http://192.168.1.5/api');
      expect(Server.urlImages, 'http://192.168.1.5/images/perfil');
    });
  });

  group('con qué pantalla abre la app', () {
    test('sin sesión, siempre el login', () {
      // Aunque el navegador insista en la ruta donde estaba: sin token, esa
      // pantalla solo puede pedir datos que no le van a dar.
      expect(rutaDeArranque('/mis-notas', haySesion: false), '/login');
      expect(rutaDeArranque('/', haySesion: false), '/login');
    });

    test('con sesión, se vuelve a donde se estaba', () {
      expect(rutaDeArranque('/mis-notas', haySesion: true), '/mis-notas');
      expect(rutaDeArranque('/unidades', haySesion: true), '/unidades');
    });

    test('con sesión y sin ruta, al muro', () {
      // Es lo que pasa en el móvil, donde el sistema siempre dice '/'.
      expect(rutaDeArranque('/', haySesion: true), '/muro');
    });
  });
}
