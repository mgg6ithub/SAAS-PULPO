import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ajustes.dart';
import 'marca.dart';

/// Colores de Pulpo: los mismos de la landing (tinta, morado del logo, lavanda y verde azulado).
/// Los neutros cambian con el modo oscuro; los de acento son fijos.
class P {
  static bool get _o => ajustes.oscuro;

  /// Neutro según la variante: con tinte lavanda en Pultec, gris azulado en iPultec.
  static Color _n(int pultec, int ipultec) => Color(industrial ? ipultec : pultec);

  /// Color de acento (por defecto el morado del logo; se cambia en Ajustes).
  static Color get morado => acentos[ajustes.acento.clamp(0, acentos.length - 1)].color;
  static Color get moradoOscuro => Color.lerp(morado, _o ? Colors.white : Colors.black, _o ? .5 : .22)!;
  static Color get moradoSuave => Color.lerp(_o ? superficie : Colors.white, morado, _o ? .22 : .09)!;

  /// Fondo del contenido: lavanda muy leve (el "tint" de la landing); las tarjetas, blancas encima.
  static Color get fondo => _o ? _n(0xFF0F0E16, 0xFF0D1015) : _n(0xFFF7F6FB, 0xFFF5F7FA);
  static Color get superficie => _o ? _n(0xFF18171F, 0xFF161A20) : Colors.white;

  /// Barra lateral: blanca con su borde, como la navegación de la landing.
  static Color get barra => _o ? _n(0xFF14131B, 0xFF13161C) : Colors.white;
  static Color get columna => _o ? _n(0xFF15141C, 0xFF14171D) : _n(0xFFF7F6FB, 0xFFF5F7FA);

  /// Fila de lista bajo el ratón: un velo morado muy suave (como el borde morado de las tarjetas).
  static Color get hoverFila => morado.withValues(alpha: _o ? .12 : .06);

  /// Fondo al pasar el ratón o elemento activo de la barra.
  static Color get hover => _o ? _n(0xFF24232D, 0xFF222833) : _n(0xFFEFECF7, 0xFFEBEFF5);

  /// Cabecera de tabla.
  static Color get cabeceraTabla => _o ? _n(0xFF1C1B24, 0xFF1A1E25) : _n(0xFFFBFAFD, 0xFFFAFBFC);
  static Color get borde => _o ? _n(0xFF2B2A35, 0xFF2A303A) : _n(0xFFE7E4F0, 0xFFE3E7EE);
  static Color get texto => _o ? _n(0xFFEDEDF2, 0xFFECEFF3) : _n(0xFF14121F, 0xFF121821);
  static Color get textoSuave => _o ? _n(0xFF9D9BAD, 0xFF98A1AE) : _n(0xFF5D5A6E, 0xFF5A6474);

  /// Tinta de la landing: botones oscuros, banners y tooltips.
  static const tinta = Color(industrial ? 0xFF121821 : 0xFF14121F);

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

/// Margen de todas las páginas: igual en todas y estrecho, para aprovechar el ancho de un portátil.
const margenPagina = EdgeInsets.fromLTRB(12, 12, 12, 12);

/// Hueco entre los bloques de una vista (barra y contenido, panel, calendario y mapa): igual en todas.
const huecoVista = 10.0;

/// Logo de Pulpo (el de la landing).
class LogoPulpo extends StatelessWidget {
  final double size;
  const LogoPulpo({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/pulpo.png',
    width: size,
    height: size,
    // En iPultec, el mismo pulpo con el tono de la marca.
    color: industrial ? Marca.color : null,
    colorBlendMode: industrial ? BlendMode.hue : null,
    filterQuality: FilterQuality.medium,
    semanticLabel: Marca.nombre,
  );
}

/// Colores de acento que se pueden elegir en Ajustes. El primero es el de la marca ([Marca.color]).
const acentos = <({String nombre, Color color})>[
  (nombre: Marca.nombreColor, color: Marca.color),
  (nombre: 'Azul', color: Color(0xFF2563EB)),
  (nombre: 'Verde', color: Color(0xFF16A34A)),
  (nombre: 'Rojo', color: Color(0xFFDC2626)),
  (nombre: 'Naranja', color: Color(0xFFEA580C)),
  (nombre: 'Rosa', color: Color(0xFFDB2777)),
  (nombre: 'Turquesa', color: Color(0xFF0D9488)),
  (nombre: 'Gris', color: Color(0xFF52525B)),
];

/// Colores para avatares de clientes y trabajadores. El primero, el de la marca.
const paleta = <Color>[
  Marca.color,
  Color(0xFF0F9F8F),
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFEA580C),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFFCA8A04),
];

Color colorPaleta(int i) => paleta[i % paleta.length];

/// Iconos que se pueden elegir para un tipo de trabajo. El tipo guarda la clave (texto), no el icono:
/// así se guarda en la base y los iconos siguen siendo constantes.
const iconosTipo = <String, IconData>{
  'caldera': Icons.local_fire_department_rounded,
  'ascensor': Icons.elevator_rounded,
  'jardin': Icons.yard_rounded,
  'limpieza': Icons.cleaning_services_rounded,
  'fontaneria': Icons.plumbing_rounded,
  'electricidad': Icons.bolt_rounded,
  'clima': Icons.ac_unit_rounded,
  'incendios': Icons.fire_extinguisher_rounded,
  'piscina': Icons.pool_rounded,
  'puerta': Icons.door_sliding_rounded,
  'camara': Icons.videocam_rounded,
  'solar': Icons.solar_power_rounded,
  'agua': Icons.water_drop_rounded,
  'pintura': Icons.format_paint_rounded,
  'plagas': Icons.pest_control_rounded,
  'otro': Icons.build_rounded,
};

/// Tipo de máquina/tarea: icono, color y la competencia que suele pedir. Cada empresa tiene los suyos
/// (los edita en Ajustes); al empezar, los de [tiposBase].
class TipoInfo {
  final String id, nombre;

  /// Clave de [iconosTipo].
  final String clave;
  final Color color;
  final String? competencia;

  /// Retraso medio sobre lo previsto, en minutos. De momento es una estimación fija;
  /// cuando haya historial se calculará con los tiempos reales.
  final int retrasoMin;
  const TipoInfo(this.id, this.nombre, this.clave, this.color, this.competencia, [this.retrasoMin = 15]);

  IconData get icono => iconosTipo[clave] ?? Icons.build_rounded;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'clave': clave,
    'color': color.toARGB32(),
    'competencia': competencia,
    'retrasoMin': retrasoMin,
  };

  factory TipoInfo.fromJson(Map<String, dynamic> j) => TipoInfo(
    j['id'] as String,
    j['nombre'] as String? ?? '',
    j['clave'] as String? ?? 'otro',
    Color((j['color'] as num?)?.toInt() ?? 0xFF71717A),
    j['competencia'] as String?,
    j['retrasoMin'] as int? ?? 15,
  );

  TipoInfo cambiar({String? nombre, String? clave, Color? color, String? competencia, bool sinCompetencia = false}) =>
      TipoInfo(
        id,
        nombre ?? this.nombre,
        clave ?? this.clave,
        color ?? this.color,
        sinCompetencia ? null : competencia ?? this.competencia,
        retrasoMin,
      );
}

/// Los de una empresa nueva. «Otro» va siempre el último: es el de lo que no encaja.
const tiposBase = <TipoInfo>[
  TipoInfo('tipo-caldera', 'Caldera', 'caldera', Color(0xFFEA580C), 'Calderas (RITE)', 20),
  TipoInfo('tipo-ascensor', 'Ascensor', 'ascensor', Color(0xFF2563EB), 'Ascensores', 25),
  TipoInfo('tipo-jardineria', 'Jardinería', 'jardin', Color(0xFF16A34A), 'Jardinería', 15),
  TipoInfo('tipo-limpieza', 'Limpieza', 'limpieza', Color(0xFF0891B2), 'Limpieza', 10),
  TipoInfo('tipo-fontaneria', 'Fontanería', 'fontaneria', Color(0xFF4F46E5), 'Fontanería', 20),
  TipoInfo('tipo-electricidad', 'Electricidad', 'electricidad', Color(0xFFCA8A04), 'Electricidad', 15),
  TipoInfo('tipo-climatizacion', 'Climatización', 'clima', Color(0xFF0D9488), 'Climatización', 20),
  TipoInfo('tipo-incendios', 'Contra incendios', 'incendios', Color(0xFFDC2626), 'Contra incendios', 15),
  TipoInfo('tipo-piscina', 'Piscina', 'piscina', Color(0xFF0EA5E9), 'Piscinas', 15),
  TipoInfo('tipo-otro', 'Otro', 'otro', Color(0xFF71717A), null),
];

/// Tipos de la empresa en curso. Los carga y guarda el [Store]; aquí para que [tipoDe] los vea en todas partes.
List<TipoInfo> tipos = [...tiposBase];

TipoInfo tipoDe(String nombre) => tipos.firstWhere((t) => t.nombre == nombre, orElse: () => tipos.last);

const competenciasBase = <String>[
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

/// Competencias de la empresa en curso (las carga y guarda el [Store]).
List<String> competencias = [...competenciasBase];

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
    // En escritorio Flutter compacta los controles (los botones se quedaban en 32): todos a su alto real, 40.
    visualDensity: VisualDensity.standard,
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
        // Todos los botones miden 40 de alto (sin padding vertical): mismo alto en toda la app.
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
