import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga un archivo desde el navegador.
Future<void> descargar(Uint8List bytes, String nombre, String tipo) async {
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: tipo)));
  web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..click();
  web.URL.revokeObjectURL(url);
}

/// Abre un enlace (`tel:`, mapas…) en una pestaña nueva o en la app que lo maneje.
void abrirEnlace(String url) => web.window.open(url, '_blank');
