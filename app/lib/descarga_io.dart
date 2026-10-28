import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Guarda un archivo donde elija el usuario (escritorio).
Future<void> descargar(Uint8List bytes, String nombre, String tipo) async {
  final ruta = await FilePicker.platform.saveFile(fileName: nombre);
  if (ruta != null) await File(ruta).writeAsBytes(bytes);
}
