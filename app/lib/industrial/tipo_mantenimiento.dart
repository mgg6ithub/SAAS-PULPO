import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Punto de color del estado (tipo de mantenimiento o estado de un activo).
Widget puntoTipo(Color c, {double tam = 8}) => Container(
  width: tam,
  height: tam,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);

/// Píldora del tipo de mantenimiento de una OT, con su descripción al pasar el ratón.
class PillTipo extends StatelessWidget {
  final TipoMantenimiento tipo;
  const PillTipo(this.tipo, {super.key});

  @override
  Widget build(BuildContext context) =>
      Tooltip(message: tipo.descripcion, child: Pill(tipo.etiqueta, tipo.color, punto: true));
}

/// Tipo de mantenimiento de la OT en el menú pequeño de arriba a la derecha del formulario (en iPultec
/// sustituye a la criticidad). La descripción de cada opción sale al pasar el ratón.
class MenuTipoMantenimiento extends StatelessWidget {
  final TipoMantenimiento valor;
  final ValueChanged<TipoMantenimiento> onChanged;
  const MenuTipoMantenimiento(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => BotonMenu<TipoMantenimiento>(
    tooltip: valor.descripcion,
    seleccionado: valor,
    onSelected: onChanged,
    opciones: [
      for (final x in TipoMantenimiento.values)
        (
          x,
          Tooltip(
            message: x.descripcion,
            child: Row(children: [puntoTipo(x.color), const SizedBox(width: 10), Text(x.etiqueta)]),
          ),
        ),
    ],
    child: SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          puntoTipo(valor.color),
          const SizedBox(width: 8),
          Text('Tipo', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
          const SizedBox(width: 6),
          Text(valor.etiqueta, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_up_chevron_down, size: 14, color: P.textoSuave),
        ],
      ),
    ),
  );
}
