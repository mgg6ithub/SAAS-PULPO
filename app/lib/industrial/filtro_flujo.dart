import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import '../theme.dart';

/// Filtro continuo: Todos y las tres fases de preparación de la OT.
class FiltroFlujoMantenimiento extends StatelessWidget {
  final int seleccion;
  final bool incluirSinOrden;
  final ValueChanged<int> onChanged;
  const FiltroFlujoMantenimiento({super.key, required this.seleccion, required this.onChanged, this.incluirSinOrden = true});

  @override
  Widget build(BuildContext context) {
    final etiquetas = ['Todos', if (incluirSinOrden) 'Sin orden', 'Sin asignar', 'Asignados'];
    final ayudas = [
      incluirSinOrden ? 'Todos los mantenimientos.' : 'Todas las órdenes de trabajo pendientes.',
      if (incluirSinOrden) 'Mantenimientos sin una orden de trabajo pendiente.',
      incluirSinOrden ? 'Mantenimientos con una orden de trabajo pendiente sin técnico asignado.' : 'Órdenes de trabajo pendientes sin técnico asignado.',
      incluirSinOrden ? 'Mantenimientos con una orden de trabajo pendiente y técnico asignado.' : 'Órdenes de trabajo pendientes con técnico asignado.',
    ];
    const estilo = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);
    final anchos = etiquetas.asMap().entries.map((e) {
      final texto = TextPainter(text: TextSpan(text: e.value, style: estilo),
        textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout();
      // «Todos» también acaba en punta de flecha (+12), como las demás fases.
      final ancho = texto.width + (e.key == 0 ? 40 : 66);
      texto.dispose();
      return ancho;
    }).toList();
    final alto = 40.0 * MediaQuery.textScalerOf(context).scale(13.5) / 13.5;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipPath(
        clipper: const _ContornoFlujo(),
        child: CustomPaint(
          foregroundPainter: _BordesFlujo(anchos, Color.alphaBlend(P.textoSuave.withValues(alpha: .4), P.borde)),
          child: SizedBox(
            width: anchos.reduce((a, b) => a + b), height: alto,
            child: Stack(children: [
              for (var i = 0; i < etiquetas.length; i++)
                Positioned(
                  left: anchos.take(i).fold<double>(0, (a, b) => a + b) - (i > 0 ? 12 : 0),
                  top: 0, bottom: 0, width: anchos[i] + (i > 0 ? 12 : 0),
                  child: Tooltip(
                    message: ayudas[i],
                    preferBelow: true,
                    child: Semantics(
                    selected: seleccion == i,
                    child: ClipPath(
                      clipper: _FaseClipper(i),
                      child: Material(
                        color: P.cabeceraTabla,
                        child: InkWell(
                          onTap: () => onChanged(i), hoverColor: P.hover,
                          child: Padding(
                            padding: EdgeInsets.only(left: i > 0 ? 12 : 0, right: 12),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              if (i > 0) ...[
                                Icon([Icons.list, if (incluirSinOrden) Icons.content_paste_rounded, Icons.radio_button_unchecked_rounded,
                                  Icons.check_circle_outline_rounded][i], size: 18,
                                  color: i == etiquetas.length - 1 ? P.verde : seleccion == i ? P.morado : P.textoSuave),
                                const SizedBox(width: 6),
                              ],
                              Text(etiquetas[i], style: estilo.copyWith(color: seleccion == i ? P.morado : P.textoSuave)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

Path _contorno(Size s) => Path()
  ..moveTo(6, .5)..lineTo(s.width - 12, .5)..lineTo(s.width - .5, s.height / 2)
  ..lineTo(s.width - 12, s.height - .5)..lineTo(6, s.height - .5)
  ..quadraticBezierTo(.5, s.height - .5, .5, s.height - 6)
  ..lineTo(.5, 6)..quadraticBezierTo(.5, .5, 6, .5)..close();

class _ContornoFlujo extends CustomClipper<Path> {
  const _ContornoFlujo();
  @override
  Path getClip(Size size) => _contorno(size);
  @override
  bool shouldReclip(_ContornoFlujo oldClipper) => false;
}

class _FaseClipper extends CustomClipper<Path> {
  final int fase;
  const _FaseClipper(this.fase);
  @override
  Path getClip(Size s) {
    return Path()..moveTo(0, 0)..lineTo(s.width - 12, 0)..lineTo(s.width, s.height / 2)
      ..lineTo(s.width - 12, s.height)..lineTo(0, s.height)
      ..lineTo(fase > 0 ? 12 : 0, s.height / 2)..close();
  }
  @override
  bool shouldReclip(_FaseClipper oldClipper) => oldClipper.fase != fase;
}

class _BordesFlujo extends CustomPainter {
  final List<double> anchos;
  final Color color;
  const _BordesFlujo(this.anchos, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawPath(_contorno(size), pintura);
    var x = 0.0;
    for (var i = 0; i < anchos.length - 1; i++) {
      x += anchos[i];
      final divisor = Path();
      divisor..moveTo(x - 12, 0)..lineTo(x, size.height / 2)..lineTo(x - 12, size.height);
      canvas.drawPath(divisor, pintura);
    }
  }
  @override
  bool shouldRepaint(_BordesFlujo oldDelegate) => oldDelegate.color != color ||
      !listEquals(anchos, oldDelegate.anchos);
}
