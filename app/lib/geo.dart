import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Busca las coordenadas de la dirección del cliente con OpenStreetMap (Nominatim, gratis y sin clave).
/// Devuelve true si lo ha ubicado. Sin red o sin resultado, el cliente queda sin ubicar.
Future<bool> ubicar(Cliente c) async {
  final g = await coordenadas(c.direccionCompleta);
  if (g == null) return false;
  c
    ..lat = g.$1
    ..lng = g.$2;
  return true;
}

/// Coordenadas (lat, lng) de una dirección con Nominatim; null sin red o sin resultado.
Future<(double, double)?> coordenadas(String q) async {
  if (q.trim().isEmpty) return null;
  try {
    final r = await http
        .get(Uri.https('nominatim.openstreetmap.org', '/search', {'q': q, 'format': 'json', 'limit': '1'}))
        .timeout(const Duration(seconds: 8));
    final lista = jsonDecode(r.body) as List;
    if (lista.isEmpty) return null;
    return (double.parse(lista.first['lat'] as String), double.parse(lista.first['lon'] as String));
  } catch (_) {
    return null;
  }
}
