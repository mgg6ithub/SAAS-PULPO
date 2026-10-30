import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Guarda un archivo donde elija el usuario (escritorio).
Future<void> descargar(Uint8List bytes, String nombre, String tipo) async {
  final ruta = await FilePicker.platform.saveFile(fileName: nombre);
  if (ruta != null) await File(ruta).writeAsBytes(bytes);
}

/// Abre un enlace (`tel:`, mapas…) con el programa del sistema.
void abrirEnlace(String url) =>
    Process.run(Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open'), [url]);

void ponerPestana(String icono, String titulo) {}
