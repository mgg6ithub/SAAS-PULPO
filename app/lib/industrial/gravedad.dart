import 'package:flutter/material.dart';

import '../theme.dart';
import '../models.dart';
import '../store.dart';
import 'incidencia.dart';

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

/// «a, b y c».
String _enumerar(List<String> xs) =>
    xs.length <= 1 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} y ${xs.last}';

String _cuantos(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// Qué más se borra con estos activos (componentes, mantenimientos, OT pendientes e incidencias); null si nada.
String? avisoBorrarActivos(Iterable<String> ids) {
  final rama = {for (final id in ids) ...store.ramaDe(id)};
  final componentes = rama.length - ids.length;
  final planes = store.planes.where((p) => rama.contains(p.activoId)).length;
  final ots = [...store.tareas, ...store.subtareas].where((t) => rama.contains(t.activoId)).length;
  final incidencias = store.incidencias.where((x) => rama.contains(x.activoId)).length;
  final partes = [
    if (componentes > 0) _cuantos(componentes, 'componente', 'componentes'),
    if (planes > 0) _cuantos(planes, 'mantenimiento', 'mantenimientos'),
    if (ots > 0) _cuantos(ots, 'orden de trabajo', 'órdenes de trabajo'),
    if (incidencias > 0) _cuantos(incidencias, 'incidencia', 'incidencias'),
  ];
  return partes.isEmpty ? null : 'Se borrarán también ${_enumerar(partes)}, también del calendario y del histórico.';
}

/// Qué más se borra con estos mantenimientos (sus OT pendientes); null si nada.
String? avisoBorrarPlanes(Iterable<String> ids) {
  final set = ids.toSet();
  final otIds = {for (final t in [...store.tareas, ...store.subtareas]) if (set.contains(t.planId)) t.id};
  final incidencias = store.incidencias
      .where((x) => set.contains(x.planId) || otIds.contains(x.trabajoId) || otIds.contains(x.origenTrabajoId))
      .length;
  final partes = [
    if (otIds.isNotEmpty) _cuantos(otIds.length, 'orden de trabajo', 'órdenes de trabajo'),
    if (incidencias > 0) _cuantos(incidencias, 'incidencia', 'incidencias'),
  ];
  return partes.isEmpty ? null : 'Se borrarán también ${_enumerar(partes)}, también del calendario y del histórico.';
}

/// De dónde sale la OT: de un mantenimiento (sola), de una incidencia o creada a mano.
(String, Color) origenOt(Tarea t) => t.planId != null
    ? ('Mantenimiento', P.morado)
    : store.incidenciaDeOt(t.id) != null
    ? ('Incidencia', P.rojo)
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
  child: Icon(ot == null ? Icons.content_paste_rounded : ot.trabajadorIds.isEmpty
      ? Icons.radio_button_unchecked_rounded : Icons.check_circle_outline_rounded,
    size: 18, color: ot != null && ot.trabajadorIds.isNotEmpty ? P.verde : P.textoSuave),
);
