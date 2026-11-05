import '../screens/tareas.dart' show pasaFechaTrabajo;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'iconos.dart';
import 'gravedad.dart';
import 'activos.dart' show destacarMantenimiento;
import 'plan.dart';
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

/// Cifra de Inicio elegida, que filtra las órdenes por criticidad: 0 = pendientes; 1 hoy, 2 semana,
/// 3 vencidas, 4 hechas (como los filtros de fecha de Órdenes de trabajo).
final periodoInicio = ValueNotifier<int>(0);

/// Inicio de Pultec: una columna por criticidad con sus primeras órdenes de trabajo pendientes.
/// Cada tarjeta es una orden de trabajo: arriba su activo principal, debajo la orden, su fecha y su técnico.
/// Al tocarla se abre la orden; «Ver todas» lleva a Órdenes de trabajo con la misma criticidad y fecha.
class VistazoActivos extends StatelessWidget {
  final ValueChanged<String> onAbrir;

  /// Abre Órdenes de trabajo con la criticidad ya puesta (0 = todas; 1.. = tipo de mantenimiento).
  final ValueChanged<int> onVerMas;
  final int columnas;
  const VistazoActivos({super.key, required this.onAbrir, required this.onVerMas, required this.columnas});

  static const _maximo = 3;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder(valueListenable: periodoInicio, builder: (context, periodo, _) => _construir(periodo));

  Widget _construir(int periodo) {
    final ots = [...store.tareas, ...store.subtareas].where((t) {
      if (t.esPlantilla || t.tipoMantenimiento == null) return false;
      if (periodo == 4) return pasaFechaTrabajo(t, 4);
      return otPendiente(t) && pasaFechaTrabajo(t, periodo);
    }).toList()..sort((a, b) => (a.proximo ?? DateTime(9999)).compareTo(b.proximo ?? DateTime(9999)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Órdenes de trabajo por criticidad',
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
        Text('Ninguna orden de trabajo', style: TextStyle(color: P.textoSuave, fontSize: 13))
      else
        for (final o in ots.take(VistazoActivos._maximo)) ...[
          Builder(
            builder: (context) {
              final a = _raiz(o.activoId);
              return HoverCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                onTap: () => onAbrir(o.id),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El color ya lo dice la columna: el icono del activo lo lleva, sin repetir el punto.
                    if (a != null) ...[IconoActivo(a.icono, size: 26, color: tipo.color), const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a?.titulo ?? 'Sin activo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: P.textoSuave, fontSize: 12.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              o.proximo == null ? 'Sin fecha' : '${relativo(o.proximo!)} · ${fecha(o.proximo!)}',
                              o.trabajadorIds.isEmpty
                                  ? 'Sin técnico'
                                  : store.trabajador(o.trabajadorIds.first)?.nombre ?? 'Sin técnico',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: o.proximo != null && diasHasta(o.proximo!) < 0 ? P.rojo : P.textoSuave,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      if (ots.length > VistazoActivos._maximo)
        Align(
          alignment: Alignment.centerLeft,
          child: Enlace('Ver todas (${ots.length})', onTap: onVerMas),
        ),
    ],
  );
}

/// Inicio de Pultec: mantenimientos que aún no tienen orden de trabajo pendiente (los que la tienen ya
/// salen arriba, como órdenes). Lista sencilla, del más cercano al más lejano: 4 y «Ver todos» la despliega aquí
/// mismo. Al tocar uno se abre su activo, donde se crea la orden o se asigna el técnico.
class MantenimientosSinAsignar extends StatefulWidget {
  final ValueChanged<String> onAbrir;
  const MantenimientosSinAsignar({super.key, required this.onAbrir});

  @override
  State<MantenimientosSinAsignar> createState() => _MantenimientosSinAsignarState();
}

class _MantenimientosSinAsignarState extends State<MantenimientosSinAsignar> {
  static const _primeros = 4;
  bool todos = false;

  @override
  Widget build(BuildContext context) {
    // Una pasada por las OT pendientes: por su enlace al mantenimiento; las antiguas, por activo y nombre.
    final ots = <String, Tarea>{
      for (final t in [...store.tareas, ...store.subtareas])
        if (!t.esPlantilla && otPendiente(t)) t.planId ?? '${t.activoId}|${t.nombre}': t,
    };
    final items = <(PlanMantenimiento, DateTime?, String)>[];
    for (final p in store.planes.where((p) => p.activa)) {
      final ot = ots[p.id] ?? ots['${p.activoId}|${p.nombre}'];
      // Con orden de trabajo ya es trabajo (sale arriba); aquí solo lo que aún no tiene orden.
      if (ot != null) continue;
      items.add((p, proximoPlan(p), 'Sin orden de trabajo'));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    items.sort((a, b) => (a.$2 ?? DateTime(9999)).compareTo(b.$2 ?? DateTime(9999)));
    final vistos = todos ? items : items.take(_primeros).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título como los de las otras secciones de Inicio.
        Row(
          children: [
            Flexible(
              child: Text(
                'Mantenimientos sin orden de trabajo',
                style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
            ),
            const SizedBox(width: 10),
            // Cuántos hay en total, aunque se vean solo los primeros.
            Text(
              '${items.length}',
              style: TextStyle(color: P.textoSuave, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (items.length > _primeros)
              Enlace(todos ? 'Ver menos' : 'Ver todos (${items.length})', onTap: () => setState(() => todos = !todos)),
          ],
        ),
        const SizedBox(height: 14),
        Tarjeta(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, (p, d, falta)) in vistos.indexed) ...[
                if (i > 0) Divider(height: 1, color: P.borde),
                // Como las tarjetas de arriba: icono del activo, el activo en pequeño y debajo el mantenimiento.
                Builder(
                  builder: (context) {
                    final a = _raiz(p.activoId);
                    return InkWell(
                      onTap: () {
                        destacarMantenimiento(p.id);
                        widget.onAbrir(a?.id ?? p.activoId);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                        child: Row(
                          children: [
                            if (a != null) ...[
                              IconoActivo(a.icono, size: 26, color: p.tipo.color),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a?.titulo ?? 'Sin activo',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: P.textoSuave, fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      letterSpacing: -.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [d == null ? 'Sin fecha' : '${relativo(d)} · ${fecha(d)}', falta].join(' · '),
                                    style: TextStyle(
                                      color: d != null && diasHasta(d) < 0 ? P.rojo : P.textoSuave,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 20, color: P.textoSuave),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
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
