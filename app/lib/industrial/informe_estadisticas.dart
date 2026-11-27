import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart' show descargarInformeEmpresa, descargarResumenActivo;
import '../models.dart' show fecha;
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'estadisticas.dart' show resumenActivo;

/// Estadísticas → descargar: ventana para elegir de cuántos días es el informe (slider con muescas en 1 semana,
/// 1, 3 y 6 meses y 1 año) y de qué (toda la empresa o solo el activo que se está viendo).
Future<void> abrirInformeEstadisticas(BuildContext context, {Activo? activo, int dias = 90}) =>
    abrirPanel(context, _InformeEstadisticas(activo: activo, dias: dias));

class _InformeEstadisticas extends StatefulWidget {
  final Activo? activo;
  final int dias;
  const _InformeEstadisticas({this.activo, required this.dias});

  @override
  State<_InformeEstadisticas> createState() => _InformeEstadisticasState();
}

class _InformeEstadisticasState extends State<_InformeEstadisticas> {
  late int dias = widget.dias.clamp(_minimo, _maximo);

  /// 0 = toda la empresa, 1 = solo el activo.
  int de = 0;
  bool preparando = false;

  static const _minimo = 7, _maximo = 365;
  static const _muescas = [(7, '1 sem.'), (30, '1 mes'), (90, '3 meses'), (180, '6 meses'), (365, '1 año')];

  DateTime get _desde => DateUtils.dateOnly(DateTime.now()).subtract(Duration(days: dias));

  /// Cerca de una muesca (a menos de 4 días), se engancha a ella.
  int _iman(double v) {
    for (final (d, _) in _muescas) {
      if ((v - d).abs() < 4) return d;
    }
    return v.round();
  }

  Future<void> _descargar() async {
    if (preparando) return;
    setState(() => preparando = true);
    final navegador = Navigator.of(context);
    final avisos = ScaffoldMessenger.maybeOf(context);
    try {
      if (de == 1 && widget.activo != null) {
        await descargarResumenActivo(widget.activo!, _desde, dias);
      } else {
        await descargarInformeEmpresa(_desde, dias);
      }
      navegador.pop();
    } catch (e) {
      debugPrint('Pultec: no se pudo crear el informe: $e');
      if (mounted) setState(() => preparando = false);
      avisos?.showSnackBar(
        const SnackBar(duration: const Duration(seconds: 6), behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activo;
    final soloActivo = de == 1 && a != null;
    // Lo que entra, para contarlo antes de descargar.
    final activos = soloActivo ? [a] : store.hijosDe(null).toList();
    final resumenes = [for (final x in activos) resumenActivo(x, _desde)];
    final mantenimientos = resumenes.fold(0, (s, r) => s + r.planes.length);
    final hechas = resumenes.fold(0, (s, r) => s + r.hechas);
    final incidencias = resumenes.fold(0, (s, r) => s + r.incidencias.length);
    return VentanaFormulario(
      etiqueta: 'INFORME',
      titulo: 'Descargar informe',
      subtitulo: 'Estadísticas en PDF',
      textoGuardar: preparando ? 'Preparando…' : 'Descargar PDF',
      iconoGuardar: Icons.download_rounded,
      puedeGuardar: !preparando,
      onGuardar: _descargar,
      campos: [
        if (a != null)
          Bloque('De qué', primero: true, descripcion: 'Todos los activos o solo el que estás viendo.', [
            Pestanas(opciones: ['Toda la empresa', a.titulo], seleccion: de, onChanged: (i) => setState(() => de = i)),
          ]),
        Bloque(
          'Periodo',
          primero: a == null,
          descripcion: 'Arrastra para elegir de cuántos días es. Las muescas son atajos.',
          [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$dias',
                  style: TextStyle(fontFamily: P.titulos, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1),
                ),
                const SizedBox(width: 8),
                Text(dias == 1 ? 'día' : 'días', style: TextStyle(fontSize: 15, color: P.textoSuave)),
                const Spacer(),
                Text('Del ${fecha(_desde)} a hoy', style: TextStyle(fontSize: 13, color: P.textoSuave)),
              ],
            ),
            const SizedBox(height: 14),
            _SliderDias(
              valor: dias,
              minimo: _minimo,
              maximo: _maximo,
              muescas: _muescas,
              onChanged: (v) => setState(() => dias = _iman(v)),
            ),
          ],
        ),
        Bloque('Qué incluye', descripcion: 'Las cifras del periodo y el estado de hoy.', [
          _linea('Activos', '${activos.length}'),
          _linea('Mantenimientos', '$mantenimientos'),
          _linea('Órdenes hechas en el periodo', '$hechas'),
          _linea('Incidencias en el periodo', '$incidencias'),
        ]),
      ],
    );
  }

  Widget _linea(String nombre, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(nombre, style: TextStyle(fontSize: 13.5, color: P.textoSuave)),
        ),
        Text(
          valor,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: P.texto),
        ),
      ],
    ),
  );
}

/// Slider de días: pista gruesa morada, pomo blanco con borde y, debajo, las muescas con su nombre (al tocar una,
/// va a ella). La elegida se marca en morado.
class _SliderDias extends StatelessWidget {
  final int valor, minimo, maximo;
  final List<(int, String)> muescas;
  final ValueChanged<double> onChanged;
  const _SliderDias({
    required this.valor,
    required this.minimo,
    required this.maximo,
    required this.muescas,
    required this.onChanged,
  });

  static const _pomo = 11.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // La pista va de borde a borde menos el radio del pomo, para que muescas y pista cuadren.
      final ancho = box.maxWidth - 2 * _pomo;
      double x(int d) => _pomo + ancho * (d - minimo) / (maximo - minimo);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              padding: const EdgeInsets.symmetric(horizontal: _pomo),
              activeTrackColor: P.morado,
              inactiveTrackColor: P.hover,
              thumbColor: P.superficie,
              overlayColor: P.morado.withValues(alpha: .12),
              thumbShape: const _Pomo(_pomo),
              trackShape: const RoundedRectSliderTrackShape(),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: valor.toDouble(),
              min: minimo.toDouble(),
              max: maximo.toDouble(),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 6),
          // Muescas: una rayita bajo la pista y su nombre; se pueden tocar.
          SizedBox(
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (d, nombre) in muescas)
                  Positioned(
                    left: (x(d) - 32).clamp(0.0, box.maxWidth - 64),
                    width: 64,
                    top: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(d.toDouble()),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Column(
                          crossAxisAlignment: d == minimo
                              ? CrossAxisAlignment.start
                              : d == maximo
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.center,
                          children: [
                            Padding(
                              // La rayita, justo bajo su punto de la pista aunque el nombre se ajuste al borde.
                              padding: EdgeInsets.only(
                                left: d == minimo ? (x(d) - 1).clamp(0.0, 64.0) : 0,
                                right: d == maximo ? (box.maxWidth - x(d) - 1).clamp(0.0, 64.0) : 0,
                              ),
                              child: Container(
                                width: 2,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: valor >= d ? P.morado : P.borde,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              nombre,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: valor == d ? FontWeight.w700 : FontWeight.w500,
                                color: valor == d ? P.morado : P.textoSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Pomo del slider: círculo blanco con borde morado y una sombra suave.
class _Pomo extends SliderComponentShape {
  final double radio;
  const _Pomo(this.radio);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radio);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    final r = radio + 2 * activationAnimation.value;
    c.drawCircle(
      center + const Offset(0, 1.5),
      r,
      Paint()
        ..color = const Color(0x2414121F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    c.drawCircle(center, r, Paint()..color = sliderTheme.thumbColor ?? Colors.white);
    c.drawCircle(
      center,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = sliderTheme.activeTrackColor ?? Colors.purple,
    );
  }
}
