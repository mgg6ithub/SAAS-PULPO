import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ajustes.dart';

/// Colores de Pulpo: los mismos de la landing (tinta, morado del logo, lavanda y verde azulado).
/// Los neutros cambian con el modo oscuro; los de acento son fijos.
class P {
  static bool get _o => ajustes.oscuro;

  /// Color de acento (por defecto el morado del logo; se cambia en Ajustes).
  static Color get morado => acentos[ajustes.acento.clamp(0, acentos.length - 1)].color;
  static Color get moradoOscuro => Color.lerp(morado, _o ? Colors.white : Colors.black, _o ? .5 : .22)!;
  static Color get moradoSuave => Color.lerp(_o ? superficie : Colors.white, morado, _o ? .22 : .09)!;

  /// Fondo del contenido: lavanda muy leve (el "tint" de la landing); las tarjetas, blancas encima.
  static Color get fondo => _o ? const Color(0xFF0F0E16) : const Color(0xFFF7F6FB);
  static Color get superficie => _o ? const Color(0xFF18171F) : Colors.white;

  /// Barra lateral: blanca con su borde, como la navegación de la landing.
  static Color get barra => _o ? const Color(0xFF14131B) : Colors.white;
  static Color get columna => _o ? const Color(0xFF15141C) : const Color(0xFFF7F6FB);

  /// Fondo al pasar el ratón o elemento activo de la barra.
  static Color get hover => _o ? const Color(0xFF24232D) : const Color(0xFFEFECF7);

  /// Cabecera de tabla.
  static Color get cabeceraTabla => _o ? const Color(0xFF1C1B24) : const Color(0xFFFBFAFD);
  static Color get borde => _o ? const Color(0xFF2B2A35) : const Color(0xFFE7E4F0);
  static Color get texto => _o ? const Color(0xFFEDEDF2) : const Color(0xFF14121F);
  static Color get textoSuave => _o ? const Color(0xFF9D9BAD) : const Color(0xFF5D5A6E);

  /// Tinta de la landing: botones oscuros, banners y tooltips.
  static const tinta = Color(0xFF14121F);

  /// Segundo color de marca (rutas y equipo en la landing).
  static const teal = Color(0xFF0F9F8F);

  /// Fuente de la app (Geist, la de la landing); null en tests, que no descargan fuentes.
  static String? titulos;
  static const verde = Color(0xFF16A34A);
  static const rojo = Color(0xFFE5484D);
  static const ambar = Color(0xFFD97706);
  static const azul = Color(0xFF2563EB);
  static const gris = Color(0xFF71717A);

  /// Radios: tarjetas como los cuadraditos de la landing, controles algo menos.
  static const radio = 14.0;
  static const radioControl = 10.0;
}

/// Margen de todas las páginas: igual en todas, y contenido para que quepa en un portátil.
const margenPagina = EdgeInsets.fromLTRB(32, 28, 32, 24);

/// Logo de Pulpo (el de la landing).
class LogoPulpo extends StatelessWidget {
  final double size;
  const LogoPulpo({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/pulpo.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'Pulpo',
  );
}

/// Colores de acento que se pueden elegir en Ajustes. El primero es el del logo.
const acentos = <({String nombre, Color color})>[
  (nombre: 'Morado', color: Color(0xFF6A2FF6)),
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
  Color(0xFF6A2FF6),
  Color(0xFF0F9F8F),
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFEA580C),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFFCA8A04),
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

/// Tipos de letra que se pueden elegir en Ajustes. Geist es la de la landing; Atkinson Hyperlegible
/// está pensada para leer mejor con poca vista.
const fuentes = ['Geist', 'Inter', 'Atkinson Hyperlegible'];

/// La fuente elegida; si el paquete no la trae, Inter.
String? _fuente() {
  try {
    return GoogleFonts.getFont(fuentes[ajustes.fuente.clamp(0, fuentes.length - 1)]).fontFamily;
  } catch (_) {
    return GoogleFonts.inter().fontFamily;
  }
}

ThemeData temaPulpo() {
  final brillo = ajustes.oscuro ? Brightness.dark : Brightness.light;
  final fuente = _fuente();
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
    fontFamily: fuente,
  );
  P.titulos = fuente;
  final radio = BorderRadius.circular(P.radioControl);
  OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: radio,
    borderSide: BorderSide(color: c, width: w),
  );
  const textoBoton = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -.1);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: P.texto, displayColor: P.texto),
    dividerColor: P.borde,
    dividerTheme: DividerThemeData(color: P.borde, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: P.superficie,
      hintStyle: TextStyle(color: P.textoSuave, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: borde(P.borde),
      enabledBorder: borde(P.borde),
      focusedBorder: borde(P.morado, 1.6),
      errorBorder: borde(P.rojo),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        minimumSize: const Size(0, 40),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: textoBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: P.texto,
        backgroundColor: P.superficie,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        minimumSize: const Size(0, 40),
        textStyle: textoBoton,
        side: BorderSide(color: P.borde),
        shape: RoundedRectangleBorder(borderRadius: radio),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: P.tinta, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: textoBoton,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: P.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: P.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: P.borde),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: P.tinta,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
  );
}
