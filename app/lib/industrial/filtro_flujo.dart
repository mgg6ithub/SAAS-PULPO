import 'package:flutter/material.dart';
import '../marca.dart';
import '../theme.dart';

/// Fases de preparación de las OT; Todos queda fuera del flujo.
class FiltroFlujoMantenimiento extends StatelessWidget {
  final int seleccion;
  final ValueChanged<int> onChanged;
  const FiltroFlujoMantenimiento({super.key, required this.seleccion, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 4; i++) ...[
        if (i == 1) const SizedBox(width: 10),
        Semantics(
          selected: seleccion == i,
          child: Transform.translate(
            offset: Offset(i > 1 ? -12.0 * (i - 1) : 0, 0),
            child: ClipPath(
            clipper: _FaseClipper(i),
            child: Material(
              color: seleccion == i ? P.morado.withValues(alpha: .15) : P.cabeceraTabla,
              child: InkWell(
                onTap: () => onChanged(i),
                hoverColor: P.hover,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(i > 1 ? 24 : 14, 0, i > 0 ? 24 : 14, 0),
                  child: SizedBox(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (i > 0) ...[
                      Icon([Icons.list, Marca.iconoTrabajo, Icons.radio_button_unchecked_rounded,
                        Icons.check_circle_outline_rounded][i], size: 18, color: seleccion == i ? P.morado : P.textoSuave),
                      const SizedBox(width: 6),
                    ],
                    Text(['Todos', 'Sin orden', 'Sin asignar', 'Asignados'][i],
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                        color: seleccion == i ? P.morado : P.textoSuave)),
                  ])),
                ),
              ),
            ),
          ),
          ),
        ),
      ],
    ]),
  );
}

class _FaseClipper extends CustomClipper<Path> {
  final int fase;
  const _FaseClipper(this.fase);
  @override
  Path getClip(Size s) {
    if (fase == 0) return Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(8)));
    return Path()
      ..moveTo(0, 0)..lineTo(s.width - 12, 0)..lineTo(s.width, s.height / 2)
      ..lineTo(s.width - 12, s.height)..lineTo(0, s.height)
      ..lineTo(fase > 1 ? 12 : 0, s.height / 2)..close();
  }
  @override
  bool shouldReclip(_FaseClipper oldClipper) => oldClipper.fase != fase;
}
