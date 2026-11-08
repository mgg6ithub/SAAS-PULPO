import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import '../marca.dart';
import '../theme.dart';

/// Filtro continuo: Todos y las tres fases de preparación de la OT.
class FiltroFlujoMantenimiento extends StatelessWidget {
  final int seleccion;
  final ValueChanged<int> onChanged;
  const FiltroFlujoMantenimiento({super.key, required this.seleccion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const etiquetas = ['Todos', 'Sin orden', 'Sin asignar', 'Asignados'];
    const ayudas = [
      'Todos los mantenimientos.',
      'Mantenimientos sin una orden de trabajo pendiente.',
      'Mantenimientos con una orden de trabajo pendiente sin técnico asignado.',
      'Mantenimientos con una orden de trabajo pendiente y técnico asignado.',
    ];
    const estilo = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);
    final anchos = etiquetas.asMap().entries.map((e) {
      final texto = TextPainter(text: TextSpan(text: e.value, style: estilo),
        textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout();
      final ancho = texto.width + (e.key == 0 ? 28 : 66);
      texto.dispose();
      return ancho;
    }).toList();
    final alto = 40.0 * MediaQuery.textScalerOf(context).scale(13.5) / 13.5;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipPath(
        clipper: const _ContornoFlujo(),
        child: CustomPaint(
          foregroundPainter: _BordesFlujo(anchos, P.borde),
          child: SizedBox(
            width: anchos.reduce((a, b) => a + b), height: alto,
            child: Stack(children: [
              for (var i = 0; i < 4; i++)
                Positioned(
                  left: anchos.take(i).fold<double>(0, (a, b) => a + b) - (i > 1 ? 12 : 0),
                  top: 0, bottom: 0, width: anchos[i] + (i > 1 ? 12 : 0),
                  child: Tooltip(
                    message: ayudas[i],
                    preferBelow: true,
                    child: Semantics(
                    selected: seleccion == i,
                    child: ClipPath(
                      clipper: _FaseClipper(i),
                      child: Material(
                        color: seleccion == i ? P.morado.withValues(alpha: .15) : P.cabeceraTabla,
                        child: InkWell(
                          onTap: () => onChanged(i), hoverColor: P.hover,
                          child: Padding(
                            padding: EdgeInsets.only(left: i > 1 ? 12 : 0, right: i > 0 ? 12 : 0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              if (i > 0) ...[
                                Icon([Icons.list, Marca.iconoTrabajo, Icons.radio_button_unchecked_rounded,
                                  Icons.check_circle_outline_rounded][i], size: 18,
                                  color: seleccion == i ? P.morado : P.textoSuave),
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
    if (fase == 0) return Path()..addRect(Offset.zero & s);
    return Path()..moveTo(0, 0)..lineTo(s.width - 12, 0)..lineTo(s.width, s.height / 2)
      ..lineTo(s.width - 12, s.height)..lineTo(0, s.height)
      ..lineTo(fase > 1 ? 12 : 0, s.height / 2)..close();
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
    for (var i = 0; i < 3; i++) {
      x += anchos[i];
      final divisor = Path();
      if (i == 0) {
        divisor..moveTo(x, 0)..lineTo(x, size.height);
      } else {
        divisor..moveTo(x - 12, 0)..lineTo(x, size.height / 2)..lineTo(x - 12, size.height);
      }
      canvas.drawPath(divisor, pintura);
    }
  }
  @override
  bool shouldRepaint(_BordesFlujo oldDelegate) => oldDelegate.color != color ||
      !listEquals(anchos, oldDelegate.anchos);
}
