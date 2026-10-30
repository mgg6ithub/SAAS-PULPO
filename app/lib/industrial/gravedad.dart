import '../models.dart';

/// OT que aún cuenta para el estado de un activo: activa y sin terminar.
bool otPendiente(Tarea t) =>
    t.activa && t.tipoMantenimiento != null && (t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso);

/// El mantenimiento pendiente más grave de estas OT (null = nada pendiente): da el color del activo.
TipoMantenimiento? masGrave(Iterable<Tarea> ots) {
  TipoMantenimiento? r;
  for (final t in ots.where(otPendiente)) {
    if (r == null || t.tipoMantenimiento!.index > r.index) r = t.tipoMantenimiento;
  }
  return r;
}
