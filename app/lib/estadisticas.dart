import 'models.dart';
import 'store.dart';

/// Cifras y avisos sacados de los datos de la empresa: lo hecho, lo que tarda cada tipo de trabajo, dónde
/// hay más averías y lo que pide atención (un equipo que falla, un técnico sobrecargado, un cliente olvidado).

/// Un trabajo es una avería si la máquina está averiada o en revisión, o si es urgente (criticidad crítica o alta).
bool esAveria(Tarea t) =>
    t.estadoMaquina != EstadoMaquina.operativa || t.criticidad == Criticidad.critica || t.criticidad == Criticidad.alta;

/// Cada visita hecha (fecha y trabajo), de cualquier trabajo con cliente.
List<(DateTime, Tarea)> visitas(Store s) => [
  for (final t in s.tareas.where((t) => !t.esPlantilla))
    for (final d in {...t.historial, ?t.ultimo}) (d, t),
];

/// Visitas hechas en cada uno de los últimos [meses] meses, del más antiguo al actual.
List<(DateTime, int)> hechosPorMes(Store s, {int meses = 6, DateTime? ahora}) {
  final h = ahora ?? hoy();
  final inicio = [for (var i = meses - 1; i >= 0; i--) DateTime(h.year, h.month - i)];
  final cuenta = {for (final m in inicio) m: 0};
  for (final (d, _) in visitas(s)) {
    final m = DateTime(d.year, d.month);
    if (cuenta.containsKey(m)) cuenta[m] = cuenta[m]! + 1;
  }
  return [for (final m in inicio) (m, cuenta[m]!)];
}

/// Por tipo de trabajo: cuántos trabajos, su duración media (estimada, en minutos) y cuántos son averías.
/// El de más trabajos primero.
List<({String tipo, int trabajos, int minutosMedios, int averias})> porTipo(Store s) {
  final grupos = <String, List<Tarea>>{};
  for (final t in s.tareas.where((t) => !t.esPlantilla)) {
    (grupos[t.tipo] ??= []).add(t);
  }
  return [
    for (final MapEntry(key: tipo, value: ts) in grupos.entries)
      (
        tipo: tipo,
        trabajos: ts.length,
        minutosMedios: (ts.fold(0, (n, t) => n + t.duracionMin) / ts.length).round(),
        averias: ts.where(esAveria).length,
      ),
  ]..sort((a, b) => b.trabajos - a.trabajos);
}

/// Clientes con averías (trabajos que lo son y equipos averiados o en revisión), el que más primero.
List<(Cliente, int)> clientesConAverias(Store s) {
  final cuenta = <String, int>{};
  for (final t in s.tareas.where((t) => !t.esPlantilla && t.clienteId != null && esAveria(t))) {
    cuenta[t.clienteId!] = (cuenta[t.clienteId!] ?? 0) + 1;
  }
  for (final e in s.equipos.where((e) => e.estado != EstadoMaquina.operativa)) {
    cuenta[e.clienteId] = (cuenta[e.clienteId] ?? 0) + 1;
  }
  return [
    for (final MapEntry(key: id, value: n) in cuenta.entries)
      if (s.cliente(id) != null) (s.cliente(id)!, n),
  ]..sort((a, b) => b.$2 - a.$2);
}

/// Equipos con [minimo] o más averías (trabajos de avería sobre él) en el último año: fallan demasiado.
List<Equipo> equiposQueFallan(Store s, {int minimo = 3}) {
  final haceUnAno = masDias(hoy(), -365);
  bool reciente(Tarea t) => !(t.ultimo ?? t.proximo ?? hoy()).isBefore(haceUnAno);
  return [
    for (final e in s.equipos)
      if (s.trabajosDe(e.id).where((t) => esAveria(t) && reciente(t)).length >= minimo) e,
  ];
}

/// Trabajadores activos con más de [horas] horas de trabajo asignadas en los próximos 7 días.
List<Trabajador> sobrecargados(Store s, {int horas = 40}) => [
  for (final w in s.trabajadores.where((w) => w.activo))
    if (s.tareas
            .where(
              (t) =>
                  !t.esPlantilla &&
                  t.activa &&
                  t.trabajadorIds.contains(w.id) &&
                  t.proximo != null &&
                  diasHasta(t.proximo!) >= 0 &&
                  diasHasta(t.proximo!) <= 7,
            )
            .fold(0, (n, t) => n + t.duracionMin) >
        horas * 60)
      w,
];

/// Clientes activos con trabajos y sin ninguna visita en más de [dias] días (o nunca, si son de antes).
List<Cliente> clientesOlvidados(Store s, {int dias = 365}) {
  final limite = masDias(hoy(), -dias);
  return [
    for (final c in s.clientes.where((c) => c.activa && s.tareasDe(c.id).isNotEmpty))
      if ((_ultimaVisita(s, c.id) ?? c.fechaAlta).isBefore(limite)) c,
  ];
}

DateTime? _ultimaVisita(Store s, String clienteId) {
  DateTime? u;
  for (final t in s.tareasDe(clienteId)) {
    for (final d in {...t.historial, ?t.ultimo}) {
      if (u == null || d.isAfter(u)) u = d;
    }
  }
  return u;
}
