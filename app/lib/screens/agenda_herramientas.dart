import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ── Filtros de la agenda ─────────────────────────────────

enum EstadoFiltro { todas, pendientes, vencidas, sinAsignar }

extension EstadoFiltroX on EstadoFiltro {
  String get etiqueta => const ['Todas', 'Pendientes', 'Vencidas', 'Sin asignar'][index];
}

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

/// Barra de filtros de la agenda: técnicos, tipo y estado.
class BarraFiltrosAgenda extends StatelessWidget {
  const BarraFiltrosAgenda({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: filtroAgenda,
    builder: (context, _) {
      final f = filtroAgenda;
      final ws = store.trabajadores.where((w) => w.activo).toList()
        ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
      final tiposUsados = {for (final t in store.tareas.where((t) => !t.esPlantilla)) t.tipo};
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Buscador(hint: 'Buscar tarea, cliente o técnico…', width: 280, onChanged: f.buscar),
          // Técnicos: avatares que se encienden o apagan; con el ratón encima, su nombre.
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: P.superficie,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: P.borde),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 6),
                  child: Text('Técnicos', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                ),
                for (final w in ws)
                  Tooltip(
                    message: w.nombreCompleto,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => f.alternarTecnico(w.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Opacity(
                          opacity: f.tecnicos.isEmpty || f.tecnicos.contains(w.id) ? 1 : .3,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: f.tecnicos.contains(w.id) ? P.morado : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Desplegable<String?>(
            etiqueta: f.tipo ?? 'Tipo',
            activo: f.tipo != null,
            opciones: [
              (null, 'Todos los tipos', null),
              for (final x in tipos.where((x) => tiposUsados.contains(x.nombre))) (x.nombre, x.nombre, x.color),
            ],
            onChanged: f.ponerTipo,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tareas', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
              const SizedBox(width: 8),
              Pestanas(
                opciones: [for (final e in EstadoFiltro.values) e.etiqueta],
                seleccion: f.estado.index,
                onChanged: (i) => f.ponerEstado(EstadoFiltro.values[i]),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Botón con menú desplegable de opciones (con punto de color opcional).
class _Desplegable<T> extends StatelessWidget {
  final String etiqueta;
  final bool activo;
  final List<(T, String, Color?)> opciones;
  final ValueChanged<T> onChanged;
  const _Desplegable({required this.etiqueta, required this.activo, required this.opciones, required this.onChanged});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: '',
    onSelected: (i) => onChanged(opciones[i].$1),
    itemBuilder: (_) => [
      for (final (i, (_, texto, color)) in opciones.indexed)
        PopupMenuItem(
          value: i,
          height: 36,
          child: Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
              ],
              Text(texto, style: const TextStyle(fontSize: 13.5)),
            ],
          ),
        ),
    ],
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: activo ? P.moradoSuave : P.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activo ? P.morado.withValues(alpha: .4) : P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: activo ? P.moradoOscuro : P.texto),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 16, color: P.textoSuave),
        ],
      ),
    ),
  );
}

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
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
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
                        style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [t.tipo, if (t.ubicacion.isNotEmpty) t.ubicacion].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: P.textoSuave),
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
                  child: const Text('Marcar hecha'),
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
                style: TextStyle(fontSize: 12.5, fontWeight: asignado ? FontWeight.w700 : FontWeight.w500),
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
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin asignar',
                        style: TextStyle(fontFamily: P.titulos, fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      Text('Pulsa una para asignarla', style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onCerrar,
                  icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                ),
              ],
            ),
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
                      return InkWell(
                        onTap: () => abrirFichaRapida(context, t),
                        hoverColor: P.columna,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      [c?.nombre ?? '—', if (t.proximo != null) relativo(t.proximo!)].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11.5, color: vencida ? P.rojo : P.textoSuave),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
