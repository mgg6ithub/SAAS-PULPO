import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart' show IconoAsignado;
import '../models.dart';
import '../store.dart';
import 'incidencia.dart';
import 'plan.dart';
import 'planes.dart' show horasRestantesPlan, proximoPlan;
import 'dart:math' as math;

/// OT que aún cuenta para el estado de un activo: activa y sin terminar.
bool otPendiente(Tarea t) =>
    t.activa &&
    t.tipoMantenimiento != null &&
    (t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso);

/// El mantenimiento pendiente más grave de estas OT (null = nada pendiente): da el color del activo.
TipoMantenimiento? masGrave(Iterable<Tarea> ots) {
  TipoMantenimiento? r;
  for (final t in ots.where(otPendiente)) {
    if (r == null || t.tipoMantenimiento!.index > r.index) r = t.tipoMantenimiento;
  }
  return r;
}

/// OT de un mantenimiento vigente: no se cancela, porque se volvería a crear sola. Para quitarla, se pausa
/// antes su mantenimiento.
bool otDeMantenimientoVigente(Tarea t) => t.planId != null && store.planes.any((p) => p.id == t.planId && p.activa);

/// Periodicidad que se enseña de una OT. La OT de un mantenimiento se guarda como «Única» (quien se repite es
/// el mantenimiento), así que se muestra la de su mantenimiento: la fija si coincide (Mensual…) o «Cada 10 días ·
/// cada 500 h». Las sueltas (manuales, de incidencia) o sin mantenimiento, la suya.
String periodicidadOt(Tarea t) {
  final plan = t.planId == null ? null : store.planes.where((p) => p.id == t.planId).firstOrNull;
  if (plan == null) return t.periodicidad.etiqueta;
  if (plan.periodicidad.repite && plan.cadaHoras == null) return plan.periodicidad.etiqueta;
  final cada = plan.cada;
  return cada.isEmpty ? t.periodicidad.etiqueta : '${cada[0].toUpperCase()}${cada.substring(1)}';
}

String _cuantos(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// Lo que se borra con algo, con el icono de cada cosa (como en sus pestañas), para el aviso de eliminar.
typedef Borrado = List<(IconData, String)>;

/// Qué más se borra con estos activos: componentes, mantenimientos, OT e incidencias (vacío si nada).
Borrado borradoConActivos(Iterable<String> ids) {
  final rama = {for (final id in ids) ...store.ramaDe(id)};
  final componentes = rama.length - ids.length;
  final planes = store.planes.where((p) => rama.contains(p.activoId)).length;
  final ots = [...store.tareas, ...store.subtareas].where((t) => rama.contains(t.activoId)).length;
  final incidencias = store.incidencias.where((x) => rama.contains(x.activoId)).length;
  return [
    if (componentes > 0) (Icons.account_tree_outlined, _cuantos(componentes, 'componente', 'componentes')),
    if (planes > 0) (Icons.content_paste_rounded, _cuantos(planes, 'mantenimiento', 'mantenimientos')),
    if (ots > 0) (Icons.assignment_outlined, _cuantos(ots, 'orden de trabajo', 'órdenes de trabajo')),
    if (incidencias > 0) (Icons.report_outlined, _cuantos(incidencias, 'incidencia', 'incidencias')),
  ];
}

/// Qué más se borra con estos mantenimientos: sus OT y sus incidencias (vacío si nada).
Borrado borradoConPlanes(Iterable<String> ids) {
  final set = ids.toSet();
  final otIds = {for (final t in [...store.tareas, ...store.subtareas]) if (set.contains(t.planId)) t.id};
  final incidencias = store.incidencias
      .where((x) => set.contains(x.planId) || otIds.contains(x.trabajoId) || otIds.contains(x.origenTrabajoId))
      .length;
  return [
    if (otIds.isNotEmpty) (Icons.assignment_outlined, _cuantos(otIds.length, 'orden de trabajo', 'órdenes de trabajo')),
    if (incidencias > 0) (Icons.report_outlined, _cuantos(incidencias, 'incidencia', 'incidencias')),
  ];
}

/// Borra una fila del histórico: la OT cerrada entera; si sigue abierta (el día viene de su historial), solo ese día.
void borrarDelHistorico(Tarea t, DateTime d) {
  if (!t.estado.abierta) return store.borrarTarea(t.id);
  t.historial.removeWhere((x) => DateUtils.isSameDay(x, d));
  if (DateUtils.isSameDay(t.ultimo, d)) {
    t.ultimo = t.historial.isEmpty ? null : t.historial.reduce((a, b) => a.isAfter(b) ? a : b);
  }
  if (t.resultado == 2 && t.ultimo == null) t.resultado = 0;
  store.guardarTarea(t);
}

/// De dónde sale la OT: de un mantenimiento (sola), de una incidencia o creada a mano.
// Primero la incidencia: la correctiva que sigue a una preventiva interrumpida lleva también su mantenimiento.
(String, Color) origenOt(Tarea t) => store.incidenciaDeOt(t.id) != null && store.incidenciaDeOt(t.id)!.origenTrabajoId != t.id
    ? ('Incidencia', P.rojo)
    : t.planId != null
    ? ('Mantenimiento', P.morado)
    : ('Manual', P.gris);

/// Cancela las OT que se pueden (quedan en el histórico como «Canceladas») y avisa de las que no.
void cancelarOts(BuildContext context, Iterable<Tarea> ts) {
  final si = ts.where((t) => t.estado.abierta && !otDeMantenimientoVigente(t)).toList();
  final no = ts.where(otDeMantenimientoVigente).length;
  if (si.isNotEmpty) {
    store.deshacible(
      si.length == 1 ? 'Has cancelado ${si.first.nombre}' : 'Has cancelado ${si.length} órdenes de trabajo',
      () => store.cambiarEstado(si, EstadoTrabajo.noRealizado),
    );
  }
  if (no > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 420,
        content: Text(
          no == 1
              ? 'La orden de un mantenimiento vigente no se cancela: pausa antes su mantenimiento.'
              : '$no órdenes son de mantenimientos vigentes y no se cancelan: pausa antes sus mantenimientos.',
        ),
      ),
    );
  }
}

/// Cómo acabó una OT según su parte: (texto, color). Sin parte, si está hecha, «Hecha».
(String, Color) resultadoOt(Tarea t) => t.estado == EstadoTrabajo.noRealizado
    ? ('Cancelada', P.gris)
    : switch (t.resultado) {
  1 => ('Con incidencia', P.ambar),
  2 => ('No se pudo hacer', P.rojo),
  // Sin parte: si ya se hizo alguna vez (o está cerrada), «Hecha».
  _ =>
    t.estado == EstadoTrabajo.realizado || t.ultimo != null || t.historial.isNotEmpty
        ? ('Hecha', P.verde)
        : ('Pendiente', P.textoSuave),
};

/// La OT dejó una incidencia (parte con incidencia o sin hacer, o comunicada desde ella) aún sin resolver.
bool incidenciaAbierta(Tarea t) =>
    !t.esPlantilla && store.incidencias.any((i) => i.origenTrabajoId == t.id && store.estadoIncidencia(i).pendiente);

/// Estado de preparación de una OT, sin confundirlo con su tipo de mantenimiento.
Widget iconoAsignacion(Tarea? ot) => Tooltip(
  message: ot == null ? 'Sin orden' : ot.trabajadorIds.isEmpty ? 'Sin asignar' : 'Asignado',
  // Sin asignar: persona tachada en un círculo; asignado: persona en un círculo (el check es solo para lo terminado).
  child: ot == null
      ? Icon(Icons.content_paste_rounded, size: 18, color: P.textoSuave)
      : IconoAsignado(ot.trabajadorIds.isNotEmpty, size: 18),
);


/// Cuánto le queda al ciclo (1 = recién hecho, 0 = toca ya o vencido) y el texto de lo que queda. Por horas, con
/// las horas que le quedan; por días, con los días hasta su fecha sobre el «cada cuánto». Sin periodo (una orden
/// suelta), sobre una ventana de 30 días.
(double, String)? cicloPlan(PlanMantenimiento p, {DateTime? fecha}) {
  if (p.cadaHoras != null && p.cadaHoras! > 0) {
    final h = horasRestantesPlan(p);
    if (h == null) return null;
    final d = proximoPlan(p);
    final texto = h <= 0 ? 'Le toca ya' : 'Quedan ${h.round()} h';
    return ((h / p.cadaHoras!).clamp(0, 1).toDouble(), d == null ? texto : '$texto, hacia el ${fechaDe(d)}');
  }
  final d = fecha ?? proximoPlan(p);
  if (d == null) return null;
  return _cicloDias(d, p.cadaDias ?? 30);
}

/// Con la fecha exacta debajo (la lista de órdenes ya no tiene columna de fecha).
(double, String) _cicloDias(DateTime d, int total) {
  final quedan = diasHasta(d);
  final texto = quedan < 0
      ? 'Vencida hace ${-quedan} ${-quedan == 1 ? 'día' : 'días'}'
      : quedan == 0
      ? 'Toca hoy'
      : 'Quedan $quedan ${quedan == 1 ? 'día' : 'días'}';
  return ((quedan / math.max(total, 1)).clamp(0, 1).toDouble(), '$texto, es el ${fechaDe(d)}');
}

(double, String)? cicloOt(Tarea t) {
  if (!t.estado.abierta || t.proximo == null) return null;
  final p = t.planId == null ? null : store.planes.where((x) => x.id == t.planId).firstOrNull;
  if (p != null) return cicloPlan(p, fecha: p.cadaHoras != null ? null : t.proximo);
  return _cicloDias(t.proximo!, 30);
}

/// Anillo de progreso del ciclo, de un vistazo: lleno y verde recién hecho; se vacía con los días (u horas); por
/// debajo del 20 % pasa a ámbar y del 10 %, a rojo.
class AnilloCiclo extends StatelessWidget {
  final (double, String)? ciclo;
  final double size;
  const AnilloCiclo(this.ciclo, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final c = ciclo;
    if (c == null) return SizedBox(width: size, height: size);
    final (f, texto) = c;
    final color = f <= .1 ? P.rojo : f <= .2 ? P.ambar : P.verde;
    return Tooltip(
      message: texto,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: f),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(size: Size.square(size), painter: _Anillo(v, color)),
      ),
    );
  }
}

class _Anillo extends CustomPainter {
  final double f;
  final Color color;
  const _Anillo(this.f, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final grosor = s.width * .2;
    final r = (s.width - grosor) / 2;
    final centro = s.center(Offset.zero);
    final rect = Rect.fromCircle(center: centro, radius: r);
    canvas.drawCircle(centro, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = color.withValues(alpha: .18));
    if (f <= 0) return;
    // Un brillo suave debajo del arco, como un anillo encendido.
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * f, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * f, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(covariant _Anillo old) => old.f != f || old.color != color;
}

String fechaDe(DateTime d) => fecha(d);

/// Qué hay que hacer: la descripción de la orden o, si no tiene, la de su mantenimiento o su incidencia.
String descripcionOt(Tarea t) {
  if (t.descripcion.trim().isNotEmpty) return t.descripcion.trim();
  final plan = t.planId == null ? null : store.planes.where((p) => p.id == t.planId).firstOrNull;
  if (plan != null && plan.descripcion.trim().isNotEmpty) return plan.descripcion.trim();
  final x = store.incidenciaDeOt(t.id);
  if (x != null && x.descripcion.trim().isNotEmpty) return x.descripcion.trim();
  return t.ubicacion;
}
