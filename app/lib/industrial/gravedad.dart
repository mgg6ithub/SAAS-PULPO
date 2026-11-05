import 'package:flutter/material.dart' show Color;

import '../theme.dart';
import '../models.dart';

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

/// Cómo acabó una OT según su parte: (texto, color). Sin parte, si está hecha, «Hecha».
(String, Color) resultadoOt(Tarea t) => switch (t.resultado) {
  1 => ('Con incidencia', P.ambar),
  2 => ('No se pudo hacer', P.rojo),
  // Sin parte: si ya se hizo alguna vez (o está cerrada), «Hecha».
  _ =>
    t.estado == EstadoTrabajo.realizado || t.ultimo != null || t.historial.isNotEmpty
        ? ('Hecha', P.verde)
        : ('Pendiente', P.textoSuave),
};

/// Incidencia de un parte (con incidencia o sin poder hacerse) que aún nadie ha dado por solucionada.
bool incidenciaAbierta(Tarea t) => !t.esPlantilla && (t.resultado ?? 0) > 0 && !t.resultadoResuelto;
