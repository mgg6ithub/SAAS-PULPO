import 'dart:math';

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
        ..sort((a, b) {
          final hora = a.inicioMin!.compareTo(b.inicioMin!);
          return hora != 0 ? hora : a.finMin!.compareTo(b.finMin!);
        });
      return LayoutBuilder(
        builder: (context, box) {
          final estrecho = box.maxWidth < 920;
          final pendientes = _PanelSinConcretar(tareas: sinConcretar, onCrear: onCrearTrabajo);
          final agenda = _TrabajosDia(tareas: asignados);
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
  const _TrabajosDia({required this.tareas});

  List<_GrupoHorario> get grupos {
    final resultado = <_GrupoHorario>[];
    for (final tarea in tareas) {
      final inicio = tarea.inicioMin!;
      if (resultado.isNotEmpty && resultado.last.inicio == inicio) {
        final grupo = resultado.last;
        grupo
          ..fin = max(grupo.fin, tarea.finMin!)
          ..tareas.add(tarea);
      } else {
        resultado.add(_GrupoHorario(inicio, tarea.finMin!, [tarea]));
      }
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final horarios = grupos;
    return Tarjeta(
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
                    itemCount: horarios.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                    itemBuilder: (context, i) => _FilaGrupoHorario(grupo: horarios[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GrupoHorario {
  final int inicio;
  int fin;
  final List<Tarea> tareas;
  _GrupoHorario(this.inicio, this.fin, this.tareas);
}

class _FilaGrupoHorario extends StatelessWidget {
  final _GrupoHorario grupo;
  const _FilaGrupoHorario({required this.grupo});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hhmm(grupo.inicio),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: P.texto),
                ),
                const SizedBox(height: 3),
                Icon(Icons.arrow_downward_rounded, size: 15, color: P.textoSuave),
                const SizedBox(height: 3),
                Text(
                  hhmm(grupo.fin),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: P.texto),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 18, child: CustomPaint(painter: _CorcheteHorario(P.textoSuave))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (final (i, tarea) in grupo.tareas.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _FilaTrabajo(tarea: tarea),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CorcheteHorario extends CustomPainter {
  final Color color;
  const _CorcheteHorario(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = color.withValues(alpha: .65)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width - 2, 1)
      ..lineTo(4, 1)
      ..lineTo(4, size.height - 1)
      ..lineTo(size.width - 2, size.height - 1);
    canvas.drawPath(path, pintura);
  }

  @override
  bool shouldRepaint(_CorcheteHorario oldDelegate) => oldDelegate.color != color;
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
                      [if (store.cliente(tarea.clienteId) case final cliente?) cliente.nombre, tarea.tipo].join(' · '),
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
