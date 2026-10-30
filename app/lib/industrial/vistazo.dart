import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
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
              for (final (i, x) in items.indexed) ...[if (i > 0) const SizedBox(height: 8), x],
            ],
          );
  }
}

/// Inicio de iPultec: todas las máquinas de un vistazo con el color de su mantenimiento pendiente más
/// grave, de más a menos grave. Al pulsar una se abre su ficha con el árbol de componentes.
class VistazoActivos extends StatelessWidget {
  final ValueChanged<String> onAbrir;
  final int columnas;
  const VistazoActivos({super.key, required this.onAbrir, required this.columnas});

  @override
  Widget build(BuildContext context) {
    final activos = [for (final a in store.hijosDe(null).where((a) => a.activo)) (a, gravedadDe(a.id))]
      ..sort((x, y) => (y.$2?.index ?? -1).compareTo(x.$2?.index ?? -1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estado de las máquinas',
          style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
        ),
        const SizedBox(height: 10),
        LeyendaEstados(columnas: columnas > 1),
        const SizedBox(height: 14),
        Rejilla(
          columnas: columnas,
          children: [
            for (final (a, g) in activos)
              HoverCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                onTap: () => onAbrir(a.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        puntoTipo(colorEstado(g), tam: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        textoEstado(g),
                        _pendientes(a.id),
                        if (a.division.isNotEmpty) a.division,
                      ].where((x) => x.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: P.textoSuave, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _pendientes(String id) {
    final n = store.otsDe(id).where(otPendiente).length;
    return n == 0 ? '' : '$n ${n == 1 ? 'pendiente' : 'pendientes'}';
  }
}
