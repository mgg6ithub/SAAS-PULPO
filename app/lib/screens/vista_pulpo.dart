import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'agenda_herramientas.dart';

class VistaPulpo extends StatelessWidget {
  final DateTime dia;
  final VoidCallback onCrearTrabajo;
  const VistaPulpo({super.key, required this.dia, required this.onCrearTrabajo});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final sinConcretar = store.tareas
          .where((t) => !t.esPlantilla && t.activa && (t.proximo == null || t.inicioMin == null))
          .toList();
      final asignados = store.tareasDelDia(dia).where((t) => filtroAgenda.pasa(t, dia) && t.inicioMin != null).toList()
        ..sort((a, b) => a.inicioMin!.compareTo(b.inicioMin!));
      return LayoutBuilder(
        builder: (context, box) {
          final estrecho = box.maxWidth < 920;
          final pendientes = _PanelSinConcretar(tareas: sinConcretar, onCrear: onCrearTrabajo);
          final agenda = _TrabajosDia(tareas: asignados, dia: dia);
          if (estrecho) {
            return Column(
              children: [
                SizedBox(height: 190, child: pendientes),
                const SizedBox(height: huecoVista),
                Expanded(child: agenda),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 250, child: pendientes),
              const SizedBox(width: huecoVista),
              Expanded(child: agenda),
            ],
          );
        },
      );
    },
  );
}

class _PanelSinConcretar extends StatelessWidget {
  final List<Tarea> tareas;
  final VoidCallback onCrear;
  const _PanelSinConcretar({required this.tareas, required this.onCrear});

  @override
  Widget build(BuildContext context) => Tarjeta(
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sin concretar',
                style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Crear trabajo',
              onPressed: onCrear,
              icon: const Icon(Icons.add_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: tareas.isEmpty
              ? Center(
                  child: Text(
                    'No hay trabajos pendientes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: P.textoSuave),
                  ),
                )
              : ListView.separated(
                  itemCount: tareas.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                  itemBuilder: (context, i) => _TrabajoSinConcretar(tarea: tareas[i]),
                ),
        ),
      ],
    ),
  );
}

class _TrabajoSinConcretar extends StatelessWidget {
  final Tarea tarea;
  const _TrabajoSinConcretar({required this.tarea});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => abrirFichaRapida(context, tarea),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(color: tarea.colorBloque, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  tarea.proximo == null ? 'Sin fecha ni hora' : 'Sin hora · ${relativo(tarea.proximo!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrabajosDia extends StatelessWidget {
  final List<Tarea> tareas;
  final DateTime dia;
  const _TrabajosDia({required this.tareas, required this.dia});

  @override
  Widget build(BuildContext context) => Tarjeta(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Trabajos asignados',
                style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Trabajadores',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.textoSuave),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tareas.isEmpty
              ? Center(
                  child: Text('No hay trabajos con horario para este día', style: TextStyle(color: P.textoSuave)),
                )
              : ListView.separated(
                  itemCount: tareas.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                  itemBuilder: (context, i) => _FilaTrabajo(tarea: tareas[i]),
                ),
        ),
      ],
    ),
  );
}

class _FilaTrabajo extends StatelessWidget {
  final Tarea tarea;
  const _FilaTrabajo({required this.tarea});

  @override
  Widget build(BuildContext context) {
    final tecnico = tarea.trabajadorIds.map(store.trabajador).whereType<Trabajador>().firstOrNull;
    final tecnicos = store.trabajadores.where((w) => w.activo).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              hhmm(tarea.inicioMin!),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: P.textoSuave),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => abrirFichaRapida(context, tarea),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Color.lerp(P.superficie, tarea.colorBloque, .10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: tarea.colorBloque, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tarea.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        ?store.cliente(tarea.clienteId)?.nombre,
                        '${hhmm(tarea.inicioMin!)}–${hhmm(tarea.finMin!)}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 19, color: P.textoSuave),
          ),
          SizedBox(
            width: 178,
            child: PopupMenuButton<String>(
              tooltip: 'Asignar trabajador',
              onSelected: (id) => store.guardarTarea(tarea.copia()..trabajadorIds = [id]),
              itemBuilder: (_) => [for (final w in tecnicos) PopupMenuItem(value: w.id, child: Text(w.nombreCompleto))],
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18, color: P.morado),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tecnico?.nombreCompleto ?? 'Seleccionar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: tecnico == null ? P.textoSuave : P.texto),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 18, color: P.textoSuave),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
