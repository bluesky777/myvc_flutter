import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Lo elegido para subir a una actividad: los bytes y el nombre.
class ElegidoParaSubir {
  final Uint8List bytes;
  final String nombre;
  const ElegidoParaSubir(this.bytes, this.nombre);
}

/// Las dos calidades de la foto de una entrega (decisión de Joseth, 26 sep).
///
/// **Normal** es 1280 px de lado largo, que es lo que el contrato pide al
/// cliente (§3.8: el servidor corta por encima de 1600). **Ligera**, 800 px,
/// para el plan de datos que se acaba a mitad de mes. No hay una por encima de
/// Normal: el alumno no la elige, y una foto de cuaderno no la necesita.
enum CalidadDeFoto {
  ligera(800, 70, 'Ligera'),
  normal(1280, 80, 'Normal');

  const CalidadDeFoto(this.lado, this.calidadJpeg, this.nombre);

  final double lado;
  final int calidadJpeg;
  final String nombre;
}

/// Pide una foto —cámara o galería— **ya reducida en el teléfono**.
///
/// La reduce `image_picker` con `maxWidth`/`maxHeight` iguales, que conserva
/// la proporción y deja el lado largo en [CalidadDeFoto.lado]; en la web lo
/// hace con un canvas, así que vale igual. Null si se canceló.
Future<ElegidoParaSubir?> elegirFotoReducida(
    BuildContext context, CalidadDeFoto calidad) async {
  final origen = kIsWeb
      ? ImageSource.gallery
      : await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tomar una foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Elegir de la galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
  if (origen == null) return null;

  final elegida = await ImagePicker().pickImage(
    source: origen,
    maxWidth: calidad.lado,
    maxHeight: calidad.lado,
    imageQuality: calidad.calidadJpeg,
  );
  if (elegida == null) return null;

  final bytes = await elegida.readAsBytes();
  return ElegidoParaSubir(bytes, _nombreDeFoto(elegida.name));
}

/// Las extensiones de `SafeUpload::EXTENSIONES_DOCUMENTO` del backend.
const extensionesDeDocumento = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'odt',
  'ods',
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
];

/// Pide un documento. Null si se canceló.
Future<ElegidoParaSubir?> elegirDocumento() async {
  final elegido = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: extensionesDeDocumento,
  );
  if (elegido == null) return null;
  return ElegidoParaSubir(await elegido.readAsBytes(), elegido.name);
}

/// El servidor valida la extensión: una foto sin ella —pasa en la web con
/// algunos navegadores— se llama `foto.jpg`, que es lo que sale de reducirla.
String _nombreDeFoto(String nombre) {
  final minusculas = nombre.toLowerCase();
  const validas = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  return validas.any(minusculas.endsWith) ? nombre : 'foto.jpg';
}
