import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ajustes.dart';

/// Colores de Pulpo. El morado es el del logo.
/// Los neutros cambian con el modo oscuro; los de acento son fijos.
class P {
  static bool get _o => ajustes.oscuro;

  /// Color de acento (por defecto el morado del logo; se cambia en Ajustes).
  static Color get morado => acentos[ajustes.acento.clamp(0, acentos.length - 1)].color;
  static Color get moradoOscuro => Color.lerp(morado, _o ? Colors.white : Colors.black, _o ? .5 : .3)!;
  static Color get moradoSuave => Color.lerp(_o ? superficie : Colors.white, morado, _o ? .22 : .1)!;

  /// Fondo del contenido: blanco, como Holded.
  static Color get fondo => _o ? const Color(0xFF111114) : Colors.white;
  static Color get superficie => _o ? const Color(0xFF1A1A1F) : Colors.white;

  /// Barra lateral y zonas secundarias: gris muy claro.
  static Color get barra => _o ? const Color(0xFF16161A) : const Color(0xFFF7F7F8);
  static Color get columna => _o ? const Color(0xFF17171C) : const Color(0xFFF5F5F7);

  /// Fondo al pasar el ratón o elemento activo de la barra.
  static Color get hover => _o ? const Color(0xFF24242B) : const Color(0xFFEDEDF0);

  /// Cabecera de tabla.
  static Color get cabeceraTabla => _o ? const Color(0xFF1E1E24) : const Color(0xFFFAFAFB);
  static Color get borde => _o ? const Color(0xFF2B2B33) : const Color(0xFFE9E9EE);
  static Color get texto => _o ? const Color(0xFFEDEDF2) : const Color(0xFF1B1B21);
  static Color get textoSuave => _o ? const Color(0xFF9A9AAA) : const Color(0xFF71717C);

  /// Banners y tooltips oscuros (destacan sobre tanto blanco).
  static const tinta = Color(0xFF16152B);
  static const verde = Color(0xFF16A34A);
  static const rojo = Color(0xFFE5484D);
  static const ambar = Color(0xFFD97706);
  static const azul = Color(0xFF2563EB);
  static const gris = Color(0xFF71717A);
}

/// Colores de acento que se pueden elegir en Ajustes. El primero es el del logo.
const acentos = <({String nombre, Color color})>[
  (nombre: 'Morado', color: Color(0xFF7C3AED)),
  (nombre: 'Azul', color: Color(0xFF2563EB)),
  (nombre: 'Verde', color: Color(0xFF16A34A)),
  (nombre: 'Rojo', color: Color(0xFFDC2626)),
  (nombre: 'Naranja', color: Color(0xFFEA580C)),
  (nombre: 'Rosa', color: Color(0xFFDB2777)),
  (nombre: 'Turquesa', color: Color(0xFF0D9488)),
  (nombre: 'Gris', color: Color(0xFF52525B)),
];

/// Colores para avatares de clientes y trabajadores.
const paleta = <Color>[
  Color(0xFF7C3AED),
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFEA580C),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFFCA8A04),
  Color(0xFF4F46E5),
];

Color colorPaleta(int i) => paleta[i % paleta.length];

/// Tipo de máquina/tarea: icono, color y la competencia que suele pedir.
class TipoInfo {
  final String nombre;
  final IconData icono;
  final Color color;
  final String? competencia;

  /// Retraso medio sobre lo previsto, en minutos. De momento es una estimación fija;
  /// cuando haya historial se calculará con los tiempos reales.
  final int retrasoMin;
  const TipoInfo(this.nombre, this.icono, this.color, this.competencia, [this.retrasoMin = 15]);
}

const tipos = <TipoInfo>[
  TipoInfo('Caldera', Icons.local_fire_department_rounded, Color(0xFFEA580C), 'Calderas (RITE)', 20),
  TipoInfo('Ascensor', Icons.elevator_rounded, Color(0xFF2563EB), 'Ascensores', 25),
  TipoInfo('Jardinería', Icons.yard_rounded, Color(0xFF16A34A), 'Jardinería', 15),
  TipoInfo('Limpieza', Icons.cleaning_services_rounded, Color(0xFF0891B2), 'Limpieza', 10),
  TipoInfo('Fontanería', Icons.plumbing_rounded, Color(0xFF4F46E5), 'Fontanería', 20),
  TipoInfo('Electricidad', Icons.bolt_rounded, Color(0xFFCA8A04), 'Electricidad', 15),
  TipoInfo('Climatización', Icons.ac_unit_rounded, Color(0xFF0D9488), 'Climatización', 20),
  TipoInfo('Contra incendios', Icons.fire_extinguisher_rounded, Color(0xFFDC2626), 'Contra incendios', 15),
  TipoInfo('Piscina', Icons.pool_rounded, Color(0xFF0EA5E9), 'Piscinas', 15),
  TipoInfo('Otro', Icons.build_rounded, Color(0xFF71717A), null),
];

TipoInfo tipoDe(String nombre) => tipos.firstWhere((t) => t.nombre == nombre, orElse: () => tipos.last);

const competencias = <String>[
  'Calderas (RITE)',
  'Ascensores',
  'Fontanería',
  'Electricidad',
  'Jardinería',
  'Limpieza',
  'Climatización',
  'Piscinas',
  'Contra incendios',
  'Trabajo en altura',
  'PRL',
];

ThemeData temaPulpo() {
  final brillo = ajustes.oscuro ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: ColorScheme.fromSeed(
      seedColor: P.morado,
      brightness: brillo,
      primary: P.morado,
      surface: P.superficie,
      onSurface: P.texto,
    ),
    scaffoldBackgroundColor: P.fondo,
    fontFamily: GoogleFonts.inter().fontFamily,
  );
  final radio = BorderRadius.circular(8);
  OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: radio,
    borderSide: BorderSide(color: c, width: w),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: P.texto, displayColor: P.texto),
    dividerColor: P.borde,
    dividerTheme: DividerThemeData(color: P.borde, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: P.superficie,
      hintStyle: TextStyle(color: P.textoSuave, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: borde(P.borde),
      enabledBorder: borde(P.borde),
      focusedBorder: borde(P.morado, 1.6),
      errorBorder: borde(P.rojo),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: P.texto,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        side: BorderSide(color: P.borde),
        shape: RoundedRectangleBorder(borderRadius: radio),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: P.tinta, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: P.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: P.tinta,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
  );
}
