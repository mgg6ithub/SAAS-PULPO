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

/// Va a otra web en esta misma pestaña (p. ej. volver a la landing).
void irA(String url) => web.window.location.href = url;

/// Cambia el icono y el título de la pestaña (Pultec compila con el `web/` de Pultec).
void ponerPestana(String icono, String titulo) {
  (web.document.querySelector('link[rel="icon"]') as web.HTMLLinkElement?)?.href = icono;
  web.document.title = titulo;
}

/// Quita un parámetro de la dirección sin recargar (p. ej. `?pago=ok` al volver de Stripe: un F5 no lo repite).
void quitarDeLaDireccion(String parametro) {
  final u = Uri.base;
  if (!u.queryParameters.containsKey(parametro)) return;
  final limpia = u.replace(queryParameters: Map.of(u.queryParameters)..remove(parametro));
  web.window.history.replaceState(null, '', limpia.toString().replaceFirst(RegExp(r'\?$'), ''));
}
