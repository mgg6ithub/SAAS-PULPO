import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Busca las coordenadas de la dirección del cliente con OpenStreetMap (Nominatim, gratis y sin clave).
/// Devuelve true si lo ha ubicado. Sin red o sin resultado, el cliente queda sin ubicar.
Future<bool> ubicar(Cliente c) async {
  final q = c.direccionCompleta;
  if (q.trim().isEmpty) return false;
  try {
    final r = await http
        .get(Uri.https('nominatim.openstreetmap.org', '/search', {'q': q, 'format': 'json', 'limit': '1'}))
        .timeout(const Duration(seconds: 8));
    final lista = jsonDecode(r.body) as List;
    if (lista.isEmpty) return false;
    c
      ..lat = double.parse(lista.first['lat'] as String)
      ..lng = double.parse(lista.first['lon'] as String);
    return true;
  } catch (_) {
    return false;
  }
}
