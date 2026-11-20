import '../screens/tareas.dart' show pasaFechaTrabajo;

import 'package:flutter/material.dart';

import '../forms.dart' show SelectorTrabajadores;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'iconos.dart';
import 'gravedad.dart';
import 'incidencia.dart';
import 'mantenimientos.dart' show abrirIncidenciaForm, dondeEs;
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

/// Inicio de Pultec en la vista mejorada: una sola tarjeta con la leyenda de las tres criticidades (con su
/// número; al pulsar, Órdenes de trabajo con esa criticidad) y las primeras órdenes pendientes de todas,
/// por fecha. Cada fila: icono del activo en el color de su criticidad, el activo en una etiqueta gris, la
/// orden, su fecha y su técnico, y la píldora del tipo. Respeta la cifra elegida arriba ([periodoInicio]).
class OrdenesPorCriticidad extends StatelessWidget {
  final ValueChanged<String> onAbrir;
  final ValueChanged<int> onVerMas;

  /// Tres columnas (preventivo, correctivo no crítico y crítico) una al lado de otra; si no, una debajo de otra.
  final bool enColumnas;
  const OrdenesPorCriticidad({super.key, required this.onAbrir, required this.onVerMas, this.enColumnas = true});

  static const _maximo = 6;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder(valueListenable: periodoInicio, builder: (context, periodo, _) => _construir(periodo));

  Widget _construir(int periodo) {
    final todas = [...store.tareas, ...store.subtareas].where((t) {
      if (t.esPlantilla || t.tipoMantenimiento == null) return false;
      if (periodo == 4) return pasaFechaTrabajo(t, 4);
      return otPendiente(t) && pasaFechaTrabajo(t, periodo);
    }).toList()..sort((a, b) => (a.proximo ?? DateTime(9999)).compareTo(b.proximo ?? DateTime(9999)));
    final columnas = [
      for (final t in TipoMantenimiento.values) _columna(t, [for (final o in todas) if (o.tipoMantenimiento == t) o]),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(P.radio),
        border: Border.all(color: P.borde),
        boxShadow: P.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Órdenes de trabajo',
            style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
          ),
          const SizedBox(height: 14),
          if (todas.isEmpty)
            const SizedBox(
              height: 150,
              child: Vacio(
                desplazable: false,
                icono: Icons.event_available_outlined,
                texto: 'Ninguna orden de trabajo pendiente',
              ),
            )
          else if (enColumnas)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, c) in columnas.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: c)],
              ],
            )
          else
            for (final (i, c) in columnas.indexed) ...[if (i > 0) const SizedBox(height: 20), c],
        ],
      ),
    );
  }

  /// Una criticidad: su nombre con el número (al pulsarlo, Órdenes de trabajo con esa criticidad), sus primeras
  /// órdenes y «Ver todas» si hay más.
  Widget _columna(TipoMantenimiento t, List<Tarea> ots) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: t.descripcion,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onVerMas(t.index + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  puntoTipo(t.color),
                  const SizedBox(width: 8),
                  Text(t.etiqueta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.color)),
                  const SizedBox(width: 8),
                  Text('${ots.length}', style: TextStyle(fontSize: 14, color: P.textoSuave)),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (ots.isEmpty)
        Text('Ninguna pendiente', style: TextStyle(color: P.textoSuave, fontSize: 13))
      else
        for (final o in ots.take(_maximo)) ...[_FilaOrden(o, onAbrir: onAbrir), const SizedBox(height: 8)],
      if (ots.length > _maximo)
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onVerMas(t.index + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todas (${ots.length})',
                    style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 17, color: P.morado),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// Una orden en [OrdenesPorCriticidad]: tarjeta interior con borde fino que se marca al pasar.
class _FilaOrden extends StatelessWidget {
  final Tarea o;
  final ValueChanged<String> onAbrir;
  const _FilaOrden(this.o, {required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final tipo = o.tipoMantenimiento ?? TipoMantenimiento.preventivo;
    final activo = o.activoId == null ? null : store.activo(o.activoId!);
    final raiz = _raiz(o.activoId);
    final descripcion = descripcionOt(o);
    return HoverCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      onTap: () => onAbrir(o.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El activo y, debajo, cuánto le queda (anillo; al pasar el ratón, lo que queda y la fecha).
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 34,
              child: Column(
                children: [
                  raiz == null && activo == null
                      ? Icon(Icons.assignment_outlined, size: 28, color: tipo.color)
                      : IconoActivo((activo ?? raiz)!.icono, size: 30, color: tipo.color),
                  const SizedBox(height: 10),
                  AnilloCiclo(cicloOt(o), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      activo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: P.textoSuave, fontWeight: FontWeight.w500),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  o.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -.2, color: P.texto),
                ),
                // Qué hay que hacer (la fecha y lo que queda, en el anillo de la derecha).
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: P.textoSuave, height: 1.35),
                  ),
                ],
                // Abajo a la derecha: de dónde sale (mantenimiento, incidencia o manual).
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Builder(builder: (_) {
                    final (origen, color) = origenOt(o);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      puntoTipo(color, tam: 7),
                      const SizedBox(width: 6),
                      Text(origen, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                    ]);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Arriba a la derecha: el técnico, que se asigna desde aquí.
          SelectorTrabajadores(o, () => store.guardarTarea(o), compacto: true),
        ],
      ),
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

/// Inicio de Pultec: incidencias abiertas (comunicadas por un técnico o salidas de un parte con incidencia o
/// sin hacer) que nadie ha revisado aún. «Revisar» abre la incidencia para crear su OT o desestimarla; todas
/// quedan después en la sección Incidencias. Sin ninguna, no se ve.
class IncidenciasAbiertas extends StatelessWidget {
  final ValueChanged<String> onAbrir;
  const IncidenciasAbiertas({super.key, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final avisos = store.incidencias.where((i) => store.estadoIncidencia(i) == EstadoIncidencia.abierta).toList()
      ..sort((a, b) => b.creada.compareTo(a.creada));
    if (avisos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Incidencias abiertas',
                  style: TextStyle(
                    fontFamily: P.titulos,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${avisos.length}', style: TextStyle(color: P.rojo, fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Tarjeta(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (n, aviso) in avisos.indexed) ...[
                  if (n > 0) Divider(height: 1, color: P.borde),
                  Builder(
                    builder: (context) {
                      final a = _raiz(aviso.activoId);
                      final quien = aviso.tecnicoId == null ? null : store.trabajador(aviso.tecnicoId!);
                      return InkWell(
                        onTap: () => abrirIncidenciaForm(context, original: aviso),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                          child: Row(
                            children: [
                              if (a != null) ...[
                                IconoActivo(a.icono, size: 24, color: aviso.gravedad.color),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dondeEs(aviso.activoId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: P.textoSuave, fontSize: 12.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      aviso.descripcion,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Pill(aviso.gravedad.etiqueta, aviso.gravedad.color, punto: true),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            '${quien?.nombre ?? 'Oficina'}, ${relativo(DateUtils.dateOnly(aviso.creada)).toLowerCase()}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: P.textoSuave, fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () => abrirIncidenciaForm(context, original: aviso),
                                child: const Text('Revisar'),
                              ),
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
      ),
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
          // En activos por turnos, la antelación son jornadas previstas, no días de calendario.
          if (proximoPlan(p) case final d? when diasHastaAviso(p.activoId, d) <= p.avisoDias!) (p, d),
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
              lider: puntoTipo(p.prioridad.color),
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
