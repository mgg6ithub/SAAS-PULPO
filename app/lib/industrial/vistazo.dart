import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'iconos.dart';
import 'gravedad.dart';
import 'planes.dart';
import 'tipo_mantenimiento.dart';

/// Leyenda de los tres colores de estado, con los textos del planteamiento de Pultec.
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

/// Inicio de Pultec: una columna por criticidad con sus primeras órdenes de trabajo pendientes.
/// Cada tarjeta: arriba el activo principal y debajo el mantenimiento. La criticidad es del mantenimiento,
/// no del activo. «Ver todas» lleva a Órdenes de trabajo con esa criticidad.
class VistazoActivos extends StatelessWidget {
  final ValueChanged<String> onAbrir;

  /// Abre Órdenes de trabajo con la criticidad ya puesta (0 = todas; 1.. = tipo de mantenimiento).
  final ValueChanged<int> onVerMas;
  final int columnas;
  const VistazoActivos({super.key, required this.onAbrir, required this.onVerMas, required this.columnas});

  static const _maximo = 3;

  @override
  Widget build(BuildContext context) {
    final ots = [...store.tareas, ...store.subtareas].where((t) => otPendiente(t) && !t.esPlantilla).toList()
      ..sort((a, b) => (a.proximo ?? DateTime(9999)).compareTo(b.proximo ?? DateTime(9999)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mantenimientos por criticidad',
                style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
            ),
            Enlace('Ver todas', onTap: () => onVerMas(0)),
          ],
        ),
        const SizedBox(height: 14),
        Rejilla(
          columnas: columnas,
          children: [
            for (final t in TipoMantenimiento.values)
              _Columna(
                tipo: t,
                ots: [
                  for (final o in ots)
                    if (o.tipoMantenimiento == t) o,
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

/// El activo principal (sin padre) del que cuelga este activo o componente.
Activo? _raiz(String? id) {
  var a = id == null ? null : store.activo(id);
  while (a?.padreId != null) {
    final p = store.activo(a!.padreId!);
    if (p == null) break;
    a = p;
  }
  return a;
}

class _Columna extends StatelessWidget {
  final TipoMantenimiento tipo;
  final List<Tarea> ots;
  final ValueChanged<String> onAbrir;
  final VoidCallback onVerMas;
  const _Columna({required this.tipo, required this.ots, required this.onAbrir, required this.onVerMas});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Qué significa cada tipo, al pasar el ratón; al pulsar, Órdenes de trabajo con esa criticidad.
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
                  puntoTipo(tipo.color),
                  const SizedBox(width: 8),
                  Text(tipo.etiqueta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('${ots.length}', style: TextStyle(color: P.textoSuave, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (ots.isEmpty)
        Text('Ningún mantenimiento pendiente', style: TextStyle(color: P.textoSuave, fontSize: 13))
      else
        for (final o in ots.take(VistazoActivos._maximo)) ...[
          Builder(
            builder: (context) {
              final a = _raiz(o.activoId);
              return HoverCard(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                onTap: a == null ? null : () => onAbrir(a.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (a != null) IconoActivo(a.icono, size: 20, color: P.textoSuave),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a?.titulo ?? 'Sin activo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: P.textoSuave, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        puntoTipo(tipo.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            o.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, letterSpacing: -.2),
                          ),
                        ),
                        if (o.proximo != null)
                          Text(relativo(o.proximo!), style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
        ],
      if (ots.length > VistazoActivos._maximo)
        Align(
          alignment: Alignment.centerLeft,
          child: Enlace('Ver todas (${ots.length})', onTap: onVerMas),
        ),
    ],
  );
}

/// Inicio de Pultec: mantenimientos con alerta previa cuya antelación ya ha llegado, para preparar a tiempo
/// grúas, repuestos o personal externo. Sin ninguno, no se ve.
class AvisosPreparacion extends StatelessWidget {
  final ValueChanged<String> onAbrir;
  const AvisosPreparacion({super.key, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final avisos = [
      for (final p in store.planes)
        if (p.activa && p.avisoDias != null)
          if (proximoPlan(p) case final d? when diasHasta(d) <= p.avisoDias!) (p, d),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (avisos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: SeccionTarjeta(
        titulo: 'Preparar',
        subtitulo: 'Mantenimientos con aviso previo que ya toca preparar',
        children: [
          for (final (p, d) in avisos)
            FilaLista(
              lider: puntoTipo(p.tipo.color),
              titulo: '${p.nombre} · ${store.activo(p.activoId)?.titulo ?? ''}',
              subtitulo: [
                'Previsto ${fecha(d)}',
                if (p.preparar.isNotEmpty) p.preparar,
                if (p.subcontratado) 'Externo: ${p.empresaExterna.isEmpty ? 'sin indicar' : p.empresaExterna}',
              ].join(' · '),
              onTap: () => onAbrir(p.activoId),
            ),
        ],
      ),
    );
  }
}
