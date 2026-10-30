import 'package:flutter/material.dart';

/// Variante de la app, elegida al compilar: Pultec (por defecto) o iPultec, la industrial
/// (`--dart-define=MARCA=industrial`). Todo lo que cambia entre las dos sale de aquí: nombre, color,
/// palabras, iconos y funciones visibles. Al ser constante, en Pultec lo industrial ni se compila.
const industrial = String.fromEnvironment('MARCA') == 'industrial';

class Marca {
  static const nombre = industrial ? 'iPultec' : 'Pulpo';

  /// Color principal y de acento: morado del logo en Pultec, azul apagado en iPultec.
  static const color = industrial ? Color(0xFF4F77A6) : Color(0xFF6A2FF6);
  static const nombreColor = industrial ? 'Azul' : 'Morado';

  /// Itinerario con mapa y rutas (iPultec, de momento, sin rutas).
  static const mapa = !industrial;

  /// Sección de Finanzas (iPultec, de momento, sin ella).
  static const finanzas = !industrial;

  /// Iconos de clientes/activos, trabajadores/técnicos y trabajos/órdenes de trabajo.
  static const iconoCliente = industrial ? Icons.precision_manufacturing_outlined : Icons.apartment_outlined;
  static const iconoTrabajador = industrial ? Icons.engineering_outlined : Icons.badge_outlined;
  static const iconoTrabajo = industrial ? Icons.assignment_outlined : Icons.handyman_outlined;
}

/// Texto visible según la variante: en Pultec, tal cual; en iPultec, cliente → activo,
/// trabajador → técnico y trabajo → orden de trabajo (con su artículo en femenino) y Pulpo → iPultec.
String m(String texto) => industrial ? _industrial(texto) : texto;

// Artículos y adjetivos que van delante de «trabajo» y cambian a femenino con «orden».
const _antes = <String, String>{
  'todos los': 'todas las',
  'los': 'las',
  'el': 'la',
  'del': 'de la',
  'al': 'a la',
  'un': 'una',
  'unos': 'unas',
  'este': 'esta',
  'estos': 'estas',
  'ese': 'esa',
  'esos': 'esas',
  'nuevo': 'nueva',
  'nuevos': 'nuevas',
  'ningún': 'ninguna',
  'otro': 'otra',
  'otros': 'otras',
  'primer': 'primera',
  'último': 'última',
  'mismo': 'misma',
  'algún': 'alguna',
  'cuántos': 'cuántas',
  'varios': 'varias',
  'tus': 'tus',
  'sus': 'sus',
};

final _palabras = RegExp(
  '(?:\\b(${_antes.keys.join('|')}) )?\\b(trabajos?)\\b'
  '(?: (\\w*(?:ad|id|ech|iert|uest|nuev|asociad|propi|vencid)o(?:s?))\\b)?'
  '|\\b(trabajador(?:a|es|as)?|clientes?|Pulpo)\\b',
  caseSensitive: false,
  unicode: true,
);

String _industrial(String texto) => texto.replaceAllMapped(_palabras, (c) {
  final todo = c[0]!;
  final String nuevo;
  if (c[2] != null) {
    final plural = c[2]!.length > 'trabajo'.length;
    final antes = c[1] == null ? '' : '${_antes[c[1]!.toLowerCase()]} ';
    nuevo = '$antes${plural ? 'órdenes de trabajo' : 'orden de trabajo'}${_femenino(c[3])}';
  } else {
    // «el pulpo» en minúscula es el de Organizar, no la marca: se queda.
    if (c[4] == 'pulpo') return todo;
    final p = c[4]!.toLowerCase();
    nuevo = switch (p) {
      'pulpo' => Marca.nombre,
      'cliente' => 'activo',
      'clientes' => 'activos',
      'trabajador' => 'técnico',
      'trabajadora' => 'técnica',
      'trabajadores' => 'técnicos',
      'trabajadoras' => 'técnicas',
      _ => p,
    };
  }
  return _mayuscula(todo, nuevo);
});

/// Adjetivo detrás de «trabajo» en femenino («trabajos asignados» → «órdenes de trabajo asignadas»).
String _femenino(String? adjetivo) {
  if (adjetivo == null) return '';
  final m = RegExp(r'o(s?)$').firstMatch(adjetivo)!;
  return ' ${adjetivo.substring(0, m.start)}a${m[1]}';
}

/// Respeta la mayúscula inicial del original (y «Pulpo», que siempre la lleva).
String _mayuscula(String original, String nuevo) {
  if (nuevo == Marca.nombre) return nuevo;
  final mayus = original[0] != original[0].toLowerCase();
  return mayus ? '${nuevo[0].toUpperCase()}${nuevo.substring(1)}' : nuevo;
}
