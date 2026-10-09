import 'dart:math';

import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tarea_card.dart';
import 'vista_calendario.dart';
import 'vista_dias.dart';

/// Vista principal. Tres formas de verla:
/// Días (por defecto): calendario en horizontal, un bloque por día.
/// Calendario: el mes por bloques.
/// Tablero: Realizadas / Actual / Futuro, con el pulpo que automatiza lo actual.
class Planificacion extends StatefulWidget {
  const Planificacion({super.key});

  @override
  State<Planificacion> createState() => _PlanificacionState();
}

class _PlanificacionState extends State<Planificacion> {
  // ?v=0..2 abre una vista concreta (útil para enlaces y capturas).
  int vista = (int.tryParse(Uri.base.queryParameters['v'] ?? '') ?? ajustes.vistaInicio).clamp(0, 2);
  DateTime? diaInicial;

  @override
  Widget build(BuildContext context) {
    final semana = store.tareas
        .where((t) => !t.esPlantilla && t.activa && t.proximo != null && diasHasta(t.proximo!) <= 7)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Cabecera(
              titulo: 'Planificación',
              subtitulo: '$semana mantenimientos en los próximos 7 días',
              acciones: [
                Pestanas(
                  opciones: const ['Días', 'Calendario', 'Tablero'],
                  seleccion: vista,
                  onChanged: (i) => setState(() {
                    vista = i;
                    diaInicial = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
              child: switch (vista) {
                0 => VistaDias(key: ValueKey(diaInicial), inicial: diaInicial, margen: 32),
                1 => Padding(
                  key: const ValueKey('calendario'),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: VistaCalendario(
                    onDia: (d) => setState(() {
                      diaInicial = d;
                      vista = 0;
                    }),
                  ),
                ),
                _ => const Padding(
                  key: ValueKey('tablero'),
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: _Tablero(),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tablero extends StatelessWidget {
  const _Tablero();

  @override
  Widget build(BuildContext context) {
    final activas = store.tareas.where((t) => !t.esPlantilla && t.activa).toList();
    final realizadas =
        activas.where((t) => t.ultimo != null && diasHasta(t.ultimo!) >= -30 && diasHasta(t.ultimo!) <= 0).toList()
          ..sort((a, b) => b.ultimo!.compareTo(a.ultimo!));
    final actual = activas.where((t) => t.proximo != null && diasHasta(t.proximo!) <= 7).toList()
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));
    final futuro = activas.where((t) => t.proximo != null && diasHasta(t.proximo!) > 7).toList()
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));

    return LayoutBuilder(
      builder: (context, box) {
        final w = max(320.0, (box.maxWidth - 32) / 3);
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Columna('Realizadas', 'Últimos 30 días', P.verde, realizadas, w, box.maxHeight, realizada: true),
                const SizedBox(width: 16),
                _Columna(
                  'Actual',
                  'Vencidas y próximos 7 días',
                  P.morado,
                  actual,
                  w,
                  box.maxHeight,
                  botonHecha: true,
                  accion: _PulpoMagico(actual),
                ),
                const SizedBox(width: 16),
                _Columna('Futuro', 'Más adelante', P.azul, futuro, w, box.maxHeight),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Botón que automatiza lo actual: asigna el trabajador más adecuado a lo que no tiene.
class _PulpoMagico extends StatelessWidget {
  final List<Tarea> tareas;
  const _PulpoMagico(this.tareas);

  @override
  Widget build(BuildContext context) {
    final pendientes = tareas.where((t) => t.trabajadorIds.isEmpty).length;
    return Tooltip(
      message: pendientes == 0
          ? 'Todo lo actual ya tiene trabajador'
          : 'Asignar el trabajador más adecuado a $pendientes ${pendientes == 1 ? 'tarea' : 'tareas'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          final n = store.automatizar(tareas);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              width: 420,
              backgroundColor: P.moradoOscuro,
              content: Text(
                n == 0
                    ? (pendientes == 0
                          ? 'Todo lo actual ya tiene trabajador.'
                          : 'No hay trabajadores aptos para lo que falta.')
                    : 'Pulpo ha asignado $n ${n == 1 ? 'tarea' : 'tareas'}.',
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [P.morado, Color.lerp(P.morado, const Color(0xFF1E1B4B), .45)!]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: P.morado.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Automatizar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              if (pendientes > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '$pendientes',
                    style: TextStyle(color: P.morado, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Columna extends StatelessWidget {
  final String titulo, subtitulo;
  final Color color;
  final List<Tarea> tareas;
  final double width, height;
  final bool realizada, botonHecha;
  final Widget? accion;
  const _Columna(
    this.titulo,
    this.subtitulo,
    this.color,
    this.tareas,
    this.width,
    this.height, {
    this.realizada = false,
    this.botonHecha = false,
    this.accion,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: P.columna,
      borderRadius: BorderRadius.circular(14),
      border: Border(top: BorderSide(color: color, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(width: 8),
              Text(
                '${tareas.length}',
                style: TextStyle(fontWeight: FontWeight.w600, color: P.textoSuave),
              ),
              const Spacer(),
              accion ?? Text(subtitulo, style: TextStyle(color: P.textoSuave, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: tareas.isEmpty
              ? const Vacio(icono: Icons.inbox_outlined, texto: 'Nada por aquí')
              : ListView.separated(
                  itemCount: tareas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => TareaCard(tareas[i], realizada: realizada, botonHecha: botonHecha),
                ),
        ),
      ],
    ),
  );
}
