import '../screens/tareas.dart' show pasaFechaTrabajo;

import 'package:flutter/material.dart';

import '../forms.dart' show abrirTareaForm;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'iconos.dart';
import 'gravedad.dart';
import 'incidencia.dart';
import 'mantenimientos.dart' show abrirIncidenciaForm;
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

/// Inicio de Pultec: partes con incidencia o que no se pudieron hacer y que nadie ha dado aún por
/// solucionados. Cada uno: «Solucionada» con un clic o «Crear orden» para arreglarlo. Sin ninguna, no se ve.
class IncidenciasAbiertas extends StatelessWidget {
  final ValueChanged<String> onAbrir;
  const IncidenciasAbiertas({super.key, required this.onAbrir});

  Future<void> _crearOrden(BuildContext context, Tarea t) async {
    final id = store.nuevoId();
    await abrirTareaForm(
      context,
      null,
      borrador: Tarea(
        id: id,
        nombre: t.resultado == 2 ? t.nombre : 'Arreglar: ${t.nombre}',
        activoId: t.activoId,
        plantilla: false,
        proximo: hoy(),
        tipoMantenimiento: t.resultado == 2 ? t.tipoMantenimiento : TipoMantenimiento.correctivoNoCritico,
        criticidad: Criticidad.rutinaria,
      ),
    );
    // Con su orden creada, la incidencia queda atendida.
    if (store.tarea(id) != null) {
      t.resultadoResuelto = true;
      store.guardarTarea(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = [...store.tareas, ...store.subtareas].where(incidenciaAbierta).toList()
      ..sort((a, b) => (b.ultimo ?? b.proximo ?? hoy()).compareTo(a.ultimo ?? a.proximo ?? hoy()));
    final avisos = store.incidencias.where((i) => i.estado == EstadoIncidencia.abierta).toList()
      ..sort((a, b) => b.creada.compareTo(a.creada));
    if (lista.isEmpty && avisos.isEmpty) return const SizedBox.shrink();
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
              Text(
                '${lista.length + avisos.length}',
                style: TextStyle(color: P.rojo, fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Consejo(
            'Solucionada retira el aviso sin completar la orden. Crear orden prepara otra intervención; el trabajo original conserva su resultado.',
          ),
          const SizedBox(height: 10),
          Tarjeta(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final aviso in avisos) ...[
                  Material(
                    color: P.superficie,
                    child: ListTile(
                      leading: Icon(Icons.report_outlined, color: aviso.gravedad.color),
                      title: Text(aviso.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${store.activo(aviso.activoId)?.titulo ?? 'Activo'} · Pendiente de revisión'),
                      onTap: () => abrirIncidenciaForm(context, original: aviso),
                      trailing: TextButton(
                        onPressed: () => abrirIncidenciaForm(context, original: aviso),
                        child: const Text('Revisar'),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: P.borde),
                ],
                for (final (i, t) in lista.indexed) ...[
                  if (i > 0) Divider(height: 1, color: P.borde),
                  Builder(
                    builder: (context) {
                      final a = _raiz(t.activoId);
                      final (texto, color) = resultadoOt(t);
                      return InkWell(
                        onTap: () => onAbrir(t.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                          child: Row(
                            children: [
                              if (a != null) ...[
                                IconoActivo(a.icono, size: 24, color: color),
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
                                      t.nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Pill(texto, color, punto: true),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Tooltip(
                                message: 'Retira el aviso; no completa la orden ni reinicia el mantenimiento.',
                                child: TextButton(
                                  onPressed: () async {
                                    if (!await confirmar(
                                      context,
                                      '¿Dar el aviso por solucionado? La orden conserva su resultado y el mantenimiento no se reinicia.',
                                    ))
                                      return;
                                    t.resultadoResuelto = true;
                                    store.guardarTarea(t);
                                  },
                                  child: const Text('Solucionada'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              BotonCrearOrden(() => _crearOrden(context, t)),
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
