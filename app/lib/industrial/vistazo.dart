import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'activos.dart';
import 'gravedad.dart';
import 'tipo_mantenimiento.dart';

/// Leyenda de los tres colores de estado, con los textos del planteamiento de iPultec.
class LeyendaEstados extends StatelessWidget {
  final bool columnas;
  const LeyendaEstados({super.key, required this.columnas});

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final t in TipoMantenimiento.values)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 5), child: puntoTipo(t.color)),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: t.etiqueta,
                      style: TextStyle(fontWeight: FontWeight.w600, color: P.texto),
                    ),
                    TextSpan(text: '. ${t.descripcion}'),
                  ],
                ),
                style: TextStyle(fontSize: 12.5, height: 1.4, color: P.textoSuave),
              ),
            ),
          ],
        ),
    ];
    return columnas
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, x) in items.indexed) ...[if (i > 0) const SizedBox(width: 20), Expanded(child: x)],
            ],
          )
        : Column(
            children: [
              for (final (i, x) in items.indexed) ...[if (i > 0) const SizedBox(height: 6), x],
            ],
          );
  }
}

/// Inicio de iPultec: una columna por estado de mantenimiento con sus 3 primeros activos.
/// «Ver más» lleva a Activos filtrado por ese tipo; al pulsar una máquina se abre su ficha.
class VistazoActivos extends StatelessWidget {
  final ValueChanged<String> onAbrir;

  /// Abre Activos con el filtro ya puesto (0 = todos; 1.. = tipo de mantenimiento).
  final ValueChanged<int> onVerMas;
  final int columnas;
  const VistazoActivos({super.key, required this.onAbrir, required this.onVerMas, required this.columnas});

  static const _maximo = 3;

  @override
  Widget build(BuildContext context) {
    final activos = [for (final a in store.hijosDe(null).where((a) => a.activo)) (a, gravedadDe(a.id))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Estado de los activos',
                style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
            ),
            Enlace('Ver todos', onTap: () => onVerMas(0)),
          ],
        ),
        const SizedBox(height: 14),
        Rejilla(
          columnas: columnas,
          children: [
            for (final t in TipoMantenimiento.values)
              _Columna(
                tipo: t,
                activos: [
                  for (final (a, g) in activos)
                    if (g == t) a,
                ],
                onAbrir: onAbrir,
                onVerMas: () => onVerMas(t.index + 1),
              ),
          ],
        ),
      ],
    );
  }
}

const _iconos = [Icons.event_available_rounded, Icons.warning_amber_rounded, Icons.error_outline_rounded];

class _Columna extends StatelessWidget {
  final TipoMantenimiento tipo;
  final List<Activo> activos;
  final ValueChanged<String> onAbrir;
  final VoidCallback onVerMas;
  const _Columna({required this.tipo, required this.activos, required this.onAbrir, required this.onVerMas});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Qué significa cada tipo, al pasar el ratón; al pulsar, Activos con ese filtro.
      Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: tipo.descripcion,
          child: GestureDetector(
            onTap: onVerMas,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono en su círculo de color, como el de las cifras de arriba.
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: tipo.color.withValues(alpha: .1), shape: BoxShape.circle),
                    child: Icon(_iconos[tipo.index], size: 16, color: tipo.color),
                  ),
                  const SizedBox(width: 10),
                  Text(tipo.etiqueta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('${activos.length}', style: TextStyle(color: P.textoSuave, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (activos.isEmpty)
        Text('Ningún activo', style: TextStyle(color: P.textoSuave, fontSize: 13))
      else
        for (final a in activos.take(VistazoActivos._maximo)) ...[
          HoverCard(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            onTap: () => onAbrir(a.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, letterSpacing: -.2),
                ),
                const SizedBox(height: 2),
                Text(
                  [_pendientes(a.id), if (a.division.isNotEmpty) a.division].where((x) => x.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: P.textoSuave, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      if (activos.length > VistazoActivos._maximo)
        Align(
          alignment: Alignment.centerLeft,
          child: Enlace('Ver todos (${activos.length})', onTap: onVerMas),
        ),
    ],
  );

  String _pendientes(String id) {
    final n = store.otsDe(id).where(otPendiente).length;
    return '$n ${n == 1 ? 'orden pendiente' : 'órdenes pendientes'}';
  }
}
