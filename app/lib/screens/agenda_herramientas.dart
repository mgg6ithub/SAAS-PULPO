import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ── Filtros de la agenda ─────────────────────────────────

enum EstadoFiltro { todas, pendientes, vencidas, sinAsignar }

/// Qué se ve en la agenda y en su mapa. Global para que se mantenga al cambiar de vista.
class FiltroAgenda extends ChangeNotifier {
  /// Técnicos visibles; vacío = todos.
  final tecnicos = <String>{};
  String? tipo;
  EstadoFiltro estado = EstadoFiltro.todas;

  /// Texto a buscar en la tarea, su tipo, su cliente o sus técnicos.
  String texto = '';

  bool get activo => tecnicos.isNotEmpty || tipo != null || estado != EstadoFiltro.todas || texto.isNotEmpty;

  bool pasa(Tarea t, DateTime dia) {
    if (texto.isNotEmpty) {
      final q = texto.toLowerCase();
      final donde = [
        t.nombre,
        t.tipo,
        t.ubicacion,
        store.cliente(t.clienteId)?.nombre ?? '',
        for (final id in t.trabajadorIds) store.trabajador(id)?.nombreCompleto ?? '',
      ].join(' ').toLowerCase();
      if (!donde.contains(q)) return false;
    }
    if (tipo != null && t.tipo != tipo) return false;
    if (tecnicos.isNotEmpty && !t.trabajadorIds.any(tecnicos.contains)) return false;
    final hecha = t.hechaEl(dia);
    final vencida = !hecha && t.proximo != null && diasHasta(t.proximo!) < 0;
    return switch (estado) {
      EstadoFiltro.todas => true,
      EstadoFiltro.pendientes => !hecha,
      EstadoFiltro.vencidas => vencida,
      EstadoFiltro.sinAsignar => t.trabajadorIds.isEmpty,
    };
  }

  void alternarTecnico(String id) {
    tecnicos.contains(id) ? tecnicos.remove(id) : tecnicos.add(id);
    notifyListeners();
  }

  /// Ver solo a un técnico (o volver a todos si ya era el único).
  void soloTecnico(String id) {
    final era = tecnicos.length == 1 && tecnicos.contains(id);
    tecnicos.clear();
    if (!era) tecnicos.add(id);
    notifyListeners();
  }

  void buscar(String q) {
    texto = q.trim();
    notifyListeners();
  }

  void ponerTipo(String? t) {
    tipo = t;
    notifyListeners();
  }

  void ponerEstado(EstadoFiltro e) {
    estado = e;
    notifyListeners();
  }

  void limpiar() {
    tecnicos.clear();
    tipo = null;
    estado = EstadoFiltro.todas;
    texto = '';
    notifyListeners();
  }
}

final filtroAgenda = FiltroAgenda();

// ── Ficha rápida de una tarea ────────────────────────────

/// Ventanita para gestionar una tarea sin salir de la agenda: cliente, fecha, hora, técnicos,
/// marcar como hecha, editar todo o eliminar. Los cambios se guardan al momento.
Future<void> abrirFichaRapida(BuildContext context, Tarea t) => showDialog(
  context: context,
  barrierColor: P.texto.withValues(alpha: .15),
  builder: (_) => Dialog(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: _FichaRapida(t.id)),
  ),
);

class _FichaRapida extends StatelessWidget {
  final String id;
  const _FichaRapida(this.id);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = store.tareas.where((x) => x.id == id).firstOrNull;
      if (t == null) return const SizedBox();
      void guardar(void Function(Tarea) cambio) {
        final c = t.copia();
        cambio(c);
        store.guardarTarea(c);
      }

      final ws = store.trabajadores.where((w) => w.activo).toList()
        ..sort((a, b) => (store.esApto(a, t) ? 0 : 1) - (store.esApto(b, t) ? 0 : 1));
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BarraTipo(t.tipo, alto: 38, color: t.colorBloque),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.nombre,
                        style: TextStyle(
                          fontFamily: P.titulos,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                      Text(
                        [t.tipo, if (t.ubicacion.isNotEmpty) t.ubicacion].join(' · '),
                        style: TextStyle(fontSize: 13.5, color: P.textoSuave),
                      ),
                    ],
                  ),
                ),
                pillEstado(t),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  etiqueta('Cliente'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: t.clienteId,
                    items: [
                      for (final c in store.clientes)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Avatar(c.iniciales, colorPaleta(c.color), size: 20, cuadrado: true),
                              const SizedBox(width: 8),
                              Flexible(child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => guardar((c) => c.clienteId = v),
                  ),
                  const SizedBox(height: 12),
                  dos(
                    CampoFecha('Fecha', t.proximo, (d) => guardar((c) => c.proximo = d)),
                    CampoHora('Hora', t.inicioMin, (m) => guardar((c) => c.inicioMin = m)),
                  ),
                  Row(
                    children: [
                      Expanded(child: etiqueta('Técnicos')),
                      Enlace(
                        'Asignar el más adecuado',
                        onTap: () {
                          final m = store.mejorPara(t);
                          if (m != null) guardar((c) => c.trabajadorIds = [m.id]);
                        },
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in ws)
                        _ChipTecnico(
                          w,
                          asignado: t.trabajadorIds.contains(w.id),
                          faltan: store.faltan(w, t),
                          onTap: () => guardar(
                            (c) => c.trabajadorIds.contains(w.id)
                                ? c.trabajadorIds.remove(w.id)
                                : c.trabajadorIds.add(w.id),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: P.rojo),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    if (await confirmar(context, '¿Eliminar "${t.nombre}"?')) {
                      store.borrarTarea(t.id);
                      nav.pop();
                    }
                  },
                  child: const Text('Eliminar'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    abrirTareaForm(context, t);
                  },
                  child: const Text('Editar todo'),
                ),
                FilledButton(
                  onPressed: () {
                    store.marcarHecha(t);
                    Navigator.pop(context);
                  },
                  child: const Text('Marcar hecho'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _ChipTecnico extends StatelessWidget {
  final Trabajador w;
  final bool asignado;
  final List<String> faltan;
  final VoidCallback onTap;
  const _ChipTecnico(this.w, {required this.asignado, required this.faltan, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: faltan.isEmpty ? '${w.nombreCompleto} · ${w.estadoHoy.etiqueta}' : 'Le falta: ${faltan.join(', ')}',
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: asignado ? P.moradoSuave : P.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: asignado ? P.morado : P.borde, width: asignado ? 1.5 : 1),
        ),
        child: Opacity(
          opacity: faltan.isEmpty || asignado ? 1 : .45,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22),
              const SizedBox(width: 6),
              Text(
                w.nombre,
                style: TextStyle(fontSize: 13.5, fontWeight: asignado ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Panel de trabajos sin asignar ────────────────────────

/// Lista lateral con lo que no tiene técnico (vencido o en los próximos 30 días):
/// se pulsa y se asigna desde la ficha rápida.
class PanelSinAsignar extends StatelessWidget {
  final VoidCallback onCerrar;
  const PanelSinAsignar({super.key, required this.onCerrar});

  static List<Tarea> pendientes() =>
      store.tareas
          .where(
            (t) =>
                !t.esPlantilla &&
                t.activa &&
                t.trabajadorIds.isEmpty &&
                (t.proximo == null || diasHasta(t.proximo!) <= 30),
          )
          .toList()
        ..sort((a, b) => (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100)));

  @override
  Widget build(BuildContext context) {
    final ts = pendientes();
    return Container(
      decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radio)),
      // Borde por encima del contenido: si no, las cabeceras lo tapan en las esquinas.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(P.radio),
        border: Border.all(color: P.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cerrar en la esquina de arriba a la derecha (como el aviso en la esquina del calendario).
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 40, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trabajos sin asignar',
                      style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Pulsa un trabajo para asignarlo o arrástralo',
                      style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onCerrar,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(34, 34),
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl - 2)),
                  ),
                  icon: Icon(CupertinoIcons.xmark, size: 17, color: P.textoSuave),
                ),
              ),
            ],
          ),
          Divider(height: 1, color: P.borde),
          Expanded(
            child: ts.isEmpty
                ? const Vacio(icono: Icons.task_alt_rounded, texto: 'Todo tiene técnico')
                : ListView.separated(
                    itemCount: ts.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                    itemBuilder: (_, i) {
                      final t = ts[i];
                      final c = store.cliente(t.clienteId);
                      final vencida = t.proximo != null && diasHasta(t.proximo!) < 0;
                      // Se puede pulsar (ficha rápida) o arrastrar a un día y hora del calendario (Semana).
                      final fila = InkWell(
                        onTap: () => abrirFichaRapida(context, t),
                        hoverColor: P.hoverFila,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              BarraTipo(t.tipo, alto: 30, color: t.colorBloque),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      [c?.nombre ?? '—', if (t.proximo != null) relativo(t.proximo!)].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, color: vencida ? P.rojo : P.textoSuave),
                                    ),
                                    Text(
                                      'Dura ${duracion(t.duracionMin)}',
                                      style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      return Draggable<Tarea>(
                        data: t,
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: _Arrastrando(t),
                        childWhenDragging: Opacity(opacity: .4, child: fila),
                        child: MouseRegion(cursor: SystemMouseCursors.grab, child: fila),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve bajo el ratón al arrastrar una tarea desde "Sin asignar": tarjetita con su color.
class _Arrastrando extends StatelessWidget {
  final Tarea t;
  const _Arrastrando(this.t);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    elevation: 8,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 180,
      height: 44,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: BoxDecoration(
        color: Color.lerp(P.superficie, t.colorBloque, .14),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: t.colorBloque, width: 3)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        t.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.texto),
      ),
    ),
  );
}
