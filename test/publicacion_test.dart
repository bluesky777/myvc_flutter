import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Models/PublicacionModel.dart';
import 'package:myvc_flutter/Widgets/Publicacion.dart';

void main() {
  group('las tres formas de una publicación', () {
    test('solo texto', () {
      final publi = PublicacionModel.fromJson({
        'id': 1,
        'contenido': '<p>Mañana no hay clase</p>',
        'nombre_autor': 'Rectoría',
      });

      expect(publi.tieneTexto, isTrue);
      expect(publi.tieneImagen, isFalse);
      expect(publi.contenido, 'Mañana no hay clase');
    });

    test('solo imagen', () {
      final publi = PublicacionModel.fromJson({
        'id': 2,
        'imagen_nombre': 'user_2/cartel.jpg',
        'nombre_autor': 'Rectoría',
      });

      expect(publi.tieneImagen, isTrue);
      expect(publi.tieneTexto, isFalse);
    });

    test('imagen con texto', () {
      final publi = PublicacionModel.fromJson({
        'id': 3,
        'contenido': 'Izada de bandera',
        'imagen_nombre': 'user_2/izada.jpg',
        'nombre_autor': 'Rectoría',
      });

      expect(publi.tieneTexto, isTrue);
      expect(publi.tieneImagen, isTrue);
    });

    test('sin texto ni imagen no hay nada que pintar', () {
      final publi = PublicacionModel.fromJson({'id': 4, 'contenido': '   '});

      expect(publi.tieneAlgo, isFalse);
    });
  });

  group('el HTML que guarda la plataforma web', () {
    test('se convierte en texto, no se enseña crudo', () {
      final publi = PublicacionModel.fromJson({
        'id': 5,
        'contenido': '<div><b>Aviso</b>&nbsp;importante</div>',
      });

      expect(publi.contenido, 'Aviso importante');
    });

    test('los saltos de línea se respetan', () {
      final publi = PublicacionModel.fromJson({
        'id': 6,
        'contenido': 'Primera<br>Segunda<br/>Tercera',
      });

      expect(publi.contenido, 'Primera\nSegunda\nTercera');
    });

    test('los entrecomillados de HTML vuelven a ser signos', () {
      final publi = PublicacionModel.fromJson({
        'id': 7,
        'contenido': 'Matem&aacute;ticas &amp; Física &lt;3',
      });

      // El &aacute; no se traduce —no se traduce ninguna entidad con nombre de
      // letra—, pero las cuatro que sí se usan en texto normal, sí.
      expect(publi.contenido, contains('&'));
      expect(publi.contenido, contains('<3'));
    });
  });

  group('la publicación en pantalla', () {
    testWidgets('una de solo texto no deja hueco de imagen',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Publicacion(
            publicacion: PublicacionModel.fromJson({
              'id': 8,
              'contenido': 'Mañana no hay clase',
              'nombre_autor': 'Rectoría',
            }),
          ),
        ),
      ));

      expect(find.text('Mañana no hay clase'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('se ve el autor y su comentario', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Publicacion(
            publicacion: PublicacionModel.fromJson({
              'id': 9,
              'contenido': 'Izada de bandera',
              'nombre_autor': 'Ariolfo Gómez',
              'comentarios': [
                {'id': 1, 'nombre_autor': 'Dámaris', 'comentario': '¡Qué bien!'},
                {'id': 2, 'nombre_autor': 'Otro', 'comentario': 'Allí estaré'},
              ],
            }),
          ),
        ),
      ));

      expect(find.text('Ariolfo Gómez'), findsOneWidget);
      expect(find.text('¡Qué bien!'), findsOneWidget);
      // El segundo no se pinta entero: se cuenta.
      expect(find.text('2 comentarios'), findsOneWidget);
    });

    testWidgets('sin comentarios el pie sigue ahí, diciéndolo',
        (WidgetTester tester) async {
      // Un pie que aparece y desaparece hace bailar las tarjetas al bajar.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Publicacion(
            publicacion: PublicacionModel.fromJson({
              'id': 10,
              'contenido': 'Algo',
              'nombre_autor': 'Rectoría',
            }),
          ),
        ),
      ));

      expect(find.text('Sin comentarios'), findsOneWidget);
    });
  });

  group('un aviso corto', () {
    test('va solo, es texto y es breve', () {
      final aviso = PublicacionModel.fromJson({
        'id': 11,
        'contenido': 'Esta es una informacion un poco pequeña pero'
            ' improtante, no se la salten!',
      });

      expect(aviso.esAviso, isTrue);
    });

    test('un texto largo no es un aviso', () {
      final largo = PublicacionModel.fromJson({
        'id': 12,
        'contenido': 'a' * 200,
      });

      expect(largo.esAviso, isFalse);
    });

    test('con imagen no es un aviso, por corto que sea', () {
      final conFoto = PublicacionModel.fromJson({
        'id': 13,
        'contenido': 'Izada',
        'imagen_nombre': 'user_2/izada.jpg',
      });

      expect(conFoto.esAviso, isFalse);
    });
  });

  group('la fecha de la publicación', () {
    test('se lee del formato que manda el servidor', () {
      final publi = PublicacionModel.fromJson({
        'id': 14,
        'contenido': 'Algo',
        'created_at': '2026-08-19 19:10:58',
      });

      expect(publi.cuando, DateTime(2026, 8, 19, 19, 10, 58));
    });

    test('una fecha ilegible no tumba la publicación', () {
      final publi = PublicacionModel.fromJson({
        'id': 15,
        'contenido': 'Algo',
        'created_at': 'cuando sea',
      });

      expect(publi.cuando, isNull);
      expect(publi.tieneAlgo, isTrue);
    });
  });
}
