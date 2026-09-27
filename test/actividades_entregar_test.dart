import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myvc_flutter/Http/ActividadesApi.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Models/ActividadModel.dart';
import 'package:myvc_flutter/Screens/EntregarTareaScreen.dart';
import 'package:myvc_flutter/Utils/ElegirParaActividad.dart';

import 'actividades_backend_de_mentira.dart';

/// Un PNG de 1×1: lo mínimo que `Image.memory` acepta sin quejarse.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// El selector de documentos de mentira: da lo que se le diga.
///
/// `FilePickerPlatform` lo reexporta `file_picker`, que es dependencia de la
/// app: no hace falta un paquete de mocks.
base class SelectorDeMentira extends FilePickerPlatform {
  SelectorDeMentira(this.bytes, this.nombre);

  final Uint8List bytes;
  final String nombre;
  List<String>? extensionesPedidas;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    extensionesPedidas = allowedExtensions;
    return ArchivoElegido(bytes, nombre);
  }
}

final class ArchivoElegido extends PlatformFile {
  ArchivoElegido(this.bytes, this.name);

  final Uint8List bytes;

  @override
  final String name;

  @override
  Uri get uri => Uri.parse('memoria://$name');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

/// Una tarea que pide lo que se le diga, sin entregar.
Map<String, dynamic> _tarea({
  bool texto = false,
  bool foto = false,
  bool archivo = false,
  bool enlace = false,
  Map<String, dynamic>? miEntrega,
}) =>
    objetoAct('responder_tarea_sobre_50')
      ..['entrega'] = {
        'texto': texto,
        'foto': foto,
        'archivo': archivo,
        'enlace': enlace,
      }
      ..['mi_entrega'] = miEntrega;

ActEnBandeja _fila(int id, {String miEstado = 'pendiente'}) =>
    ActEnBandeja.fromJson({
      'id': id,
      'modo': 'tarea',
      'titulo': 'x',
      'estado': 'abierta',
      'califica': true,
      'mi_estado': miEstado,
      'creador': {'nombre': 'CARMEN ROSA DÍAZ LUNA'},
    });

void main() {
  setUp(() => entrarComo('Alumno'));
  tearDown(AuthService.limpiar);

  Future<void> montar(WidgetTester tester, ActEnBandeja fila,
      {double? ancho}) async {
    enTelefono(tester);
    if (ancho != null) tester.view.physicalSize = Size(ancho, 900);
    await tester.pumpWidget(MaterialApp(home: EntregarTareaScreen(fila: fila)));
    await tester.pumpAndSettle();
  }

  FilledButton botonPrincipal(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton).last);

  group('entregar', () {
    testWidgets('la tarea de texto: se escribe y se entrega', (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/14/responder', _tarea(texto: true))
        ..cuando('POST /act/14/entregar', {
          'texto': 'Mi dibujo es una vaca.',
          'entregada_at': '2026-09-26 19:00:00',
          'tarde': false,
        });
      await backend.con(() async {
        await montar(tester, _fila(14));
        expect(find.text('Tu respuesta'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '  Mi dibujo es una vaca. ');
        await tester.pump();
        await tester.tap(find.text('Entregar'));
        await tester.pumpAndSettle();

        // Sólo lo que la tarea pide, y el texto recortado.
        expect(backend.cuerpoDe('POST /act/14/entregar'),
            {'texto': 'Mi dibujo es una vaca.'});
        // Entregada: el botón pasa a «cambiar», apagado mientras no cambie.
        expect(find.text('Cambiar mi entrega'), findsOneWidget);
        expect(botonPrincipal(tester).onPressed, isNull);
      });
    });

    testWidgets('la ya entregada se reabre con lo suyo y sus preguntas',
        (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/28/responder',
            fixtureAct('responder_tarea_con_preguntas'))
        ..cuando('POST /act/28/entregar',
            {'texto': 'otra', 'entregada_at': '2026-09-26 21:30:00'});
      await backend.con(() async {
        await montar(tester, _fila(28, miEstado: 'entregada'));

        expect(find.text('dos respuesta 0'), findsOneWidget);
        expect(find.text('dos respuesta 1'), findsOneWidget);
        expect(botonPrincipal(tester).onPressed, isNull);

        await tester.enterText(
            find.widgetWithText(TextField, 'dos respuesta 1'), 'Bogotá');
        await tester.pump();
        expect(botonPrincipal(tester).onPressed, isNotNull);

        await tester.tap(find.text('Cambiar mi entrega'));
        await tester.pumpAndSettle();

        final cuerpo = backend.cuerpoDe('POST /act/28/entregar') as Map;
        expect(cuerpo['texto'], 'dos respuesta 0');
        expect((cuerpo['respuestas'] as List).single['texto'], 'Bogotá');
      });
    });

    testWidgets('la calificada no se toca', (tester) async {
      final backend = BackendDeActividades()
        ..cuando(
            'GET /act/14/responder',
            _tarea(texto: true, miEntrega: {
              'texto': 'hecho',
              'entregada_at': '2026-09-26 18:28:49',
              'nota': 42,
              'calificada_at': '2026-09-26 18:29:44',
            }));
      await backend.con(() async {
        await montar(tester, _fila(14, miEstado: 'entregada'));
        expect(find.text('Entregar'), findsNothing);
        expect(find.text('Cambiar mi entrega'), findsNothing);
      });
    });
  });

  group('el archivo y el tope de 5 MB', () {
    setUp(() {
      final original = FilePickerPlatform.instance;
      addTearDown(() => FilePickerPlatform.instance = original);
    });

    testWidgets('se sube al elegirlo, y se entrega su id', (tester) async {
      final selector =
          SelectorDeMentira(Uint8List.fromList([1, 2, 3]), 'taller.pdf');
      FilePickerPlatform.instance = selector;
      final backend = BackendDeActividades()
        ..cuando('GET /act/14/responder', _tarea(archivo: true))
        ..cuandoCon('POST /act/14/archivo', (req) {
          return BackendDeActividades.respuesta({
            'id': 31,
            'clase': 'archivo',
            'nombre_original': 'taller.pdf',
            'mime': 'application/pdf',
            'bytes': 3,
          });
        })
        ..cuando('POST /act/14/entregar',
            {'entregada_at': '2026-09-26 19:00:00'});
      await backend.con(() async {
        await montar(tester, _fila(14));
        await tester.tap(find.text('Archivo'));
        await tester.pumpAndSettle();

        expect(selector.extensionesPedidas, extensionesDeDocumento);
        final subida = backend.pedidos
            .firstWhere((p) => p.url.path.endsWith('/archivo'));
        expect(subida.headers['content-type'], startsWith('multipart/'));
        expect(subida.body, contains('name="clase"\r\n\r\narchivo'));
        expect(find.text('taller.pdf'), findsOneWidget);

        await tester.tap(find.text('Entregar'));
        await tester.pumpAndSettle();
        expect(backend.cuerpoDe('POST /act/14/entregar'), {'archivo_id': 31});
      });
    });

    testWidgets('más de 5 MB no se sube: se ofrece pegar un enlace',
        (tester) async {
      FilePickerPlatform.instance = SelectorDeMentira(
          Uint8List(topeDeArchivoAct + 1), 'video.mp4');
      final backend = BackendDeActividades()
        ..cuando('GET /act/14/responder', _tarea(archivo: true, enlace: true))
        ..cuando('POST /act/14/entregar',
            {'enlace': 'https://drive.google.com/abc'});
      await backend.con(() async {
        await montar(tester, _fila(14));
        await tester.tap(find.text('Archivo'));
        await tester.pumpAndSettle();

        expect(find.text('El archivo pasa de 5 MB'), findsOneWidget);
        expect(backend.rutasPedidas, isNot(contains('POST /act/14/archivo')));

        await tester.tap(find.text('Pegar un enlace'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField)),
            'https://drive.google.com/abc');
        await tester.tap(find.text('Poner'));
        await tester.pumpAndSettle();

        expect(find.text('https://drive.google.com/abc'), findsOneWidget);
        await tester.tap(find.text('Entregar'));
        await tester.pumpAndSettle();
        expect(backend.cuerpoDe('POST /act/14/entregar'),
            {'enlace': 'https://drive.google.com/abc'});
      });
    });

    testWidgets('sin enlace pedido, sólo se explica', (tester) async {
      FilePickerPlatform.instance = SelectorDeMentira(
          Uint8List(topeDeArchivoAct + 1), 'video.mp4');
      final backend = BackendDeActividades()
        ..cuando('GET /act/14/responder', _tarea(archivo: true));
      await backend.con(() async {
        await montar(tester, _fila(14));
        await tester.tap(find.text('Archivo'));
        await tester.pumpAndSettle();

        expect(find.text('El archivo pasa de 5 MB'), findsOneWidget);
        expect(find.text('Pegar un enlace'), findsNothing);
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    testWidgets('un enlace que no es http no se acepta', (tester) async {
      final backend = BackendDeActividades()
        ..cuando('GET /act/14/responder', _tarea(enlace: true));
      await backend.con(() async {
        await montar(tester, _fila(14));
        await tester.tap(find.text('Enlace'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField)),
            'drive.google.com/abc');
        await tester.tap(find.text('Poner'));
        await tester.pumpAndSettle();

        expect(find.text('El enlace tiene que empezar por http:// o https://'),
            findsOneWidget);
      });
    });
  });

  group('la foto se reduce en el teléfono', () {
    const canal = MethodChannel('plugins.flutter.io/image_picker');
    late Map<dynamic, dynamic> pedido;
    late String ruta;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('foto_act');
      ruta = '${dir.path}/cuaderno.png';
      File(ruta).writeAsBytesSync(_png);
      addTearDown(() => dir.deleteSync(recursive: true));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (llamada) async {
        if (llamada.method != 'pickImage') return null;
        pedido = llamada.arguments as Map;
        return ruta;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null));
    });

    test('Normal es 1280 px de lado largo; Ligera, 800', () {
      expect(CalidadDeFoto.normal.lado, 1280);
      expect(CalidadDeFoto.ligera.lado, 800);
      // Nada por encima de lo que el servidor acepta (1600).
      expect(CalidadDeFoto.values.every((c) => c.lado <= 1600), isTrue);
    });

    Future<void> elegirFoto(WidgetTester tester, BackendDeActividades backend,
        {String? calidad}) async {
      // La fila de las calidades en la letra de las pruebas (Ahem, cada
      // letra un cuadrado del tamaño de la fuente) no cabe en 420 px; con
      // la letra de verdad sobra sitio. Se ensancha sólo aquí.
      await montar(tester, _fila(14), ancho: 700);
      if (calidad != null) {
        await tester.tap(find.text(calidad));
        await tester.pump();
      }
      await tester.tap(find.text('Foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      // Leer el archivo es E/S de verdad: se le da tiempo real hasta que la
      // subida salga.
      for (var i = 0;
          i < 50 && !backend.rutasPedidas.contains('POST /act/14/archivo');
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    BackendDeActividades conFoto() => BackendDeActividades()
      ..cuando('GET /act/14/responder', _tarea(foto: true))
      ..cuandoCon(
          'POST /act/14/archivo',
          (http.Request req) => BackendDeActividades.respuesta({
                'id': 9,
                'clase': 'foto',
                'nombre_original': 'cuaderno.png',
                'mime': 'image/png',
                'bytes': _png.length,
              }))
      ..cuando('POST /act/14/entregar', {'entregada_at': '2026-09-26 19:00:00'});

    testWidgets('por defecto, Normal: se le pide 1280 al selector',
        (tester) async {
      final backend = conFoto();
      await backend.con(() async {
        await elegirFoto(tester, backend);

        expect(pedido['maxWidth'], 1280);
        expect(pedido['maxHeight'], 1280);
        expect(pedido['imageQuality'], 80);
        expect(pedido['source'], 1); // la galería

        final subida = backend.pedidos
            .firstWhere((p) => p.url.path.endsWith('/archivo'));
        // El PNG no es UTF-8: el cuerpo se lee byte a byte.
        final cuerpo = latin1.decode(subida.bodyBytes);
        expect(cuerpo, contains('name="clase"\r\n\r\nfoto'));
        expect(cuerpo, contains('filename="cuaderno.png"'));

        await tester.tap(find.text('Entregar'));
        await tester.pumpAndSettle();
        expect(backend.cuerpoDe('POST /act/14/entregar'), {'foto_id': 9});
      });
    });

    testWidgets('en Ligera, 800', (tester) async {
      final backend = conFoto();
      await backend.con(() async {
        await elegirFoto(tester, backend, calidad: 'Ligera');

        expect(pedido['maxWidth'], 800);
        expect(pedido['maxHeight'], 800);
        expect(pedido['imageQuality'], 70);
      });
    });
  });
}
