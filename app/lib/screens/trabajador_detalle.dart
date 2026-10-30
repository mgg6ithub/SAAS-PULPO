import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'invitar.dart';
import '../marca.dart';

/// Vista de un trabajador: en el centro, su trabajo (tareas asignadas); a la derecha, su ficha.
class TrabajadorDetalle extends StatelessWidget {
  final String trabajadorId;
  final VoidCallback onVolver;
  const TrabajadorDetalle({super.key, required this.trabajadorId, required this.onVolver});

  @override
  Widget build(BuildContext context) {
    final w = store.trabajador(trabajadorId);
    if (w == null) {
      // Se acaba de borrar: volvemos a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) => onVolver());
      return const SizedBox();
    }
    final tareas = store.tareas.where((t) => !t.esPlantilla && t.trabajadorIds.contains(w.id)).toList()
      ..sort((a, b) => _orden(a).compareTo(_orden(b)));

    final lista = tareas.isEmpty
        ? Vacio(
            icono: Icons.assignment_outlined,
            texto: m('No tiene ningún trabajo asignado.'),
            accion: FilledButton(onPressed: () => abrirAsignar(context, w), child: Text(m('Asignar trabajo'))),
          )
        : SingleChildScrollView(
            child: SeccionTarjeta(
              titulo: 'Por fecha',
              subtitulo: 'Lo vencido primero; lo que no tiene fecha, al final',
              children: [for (final t in tareas) _TareaAsignada(t, w)],
            ),
          );

    final titulo = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(m('Trabajos asignados'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Pill('${tareas.length}', P.gris),
        ],
      ),
    );

    return SegunTamano(
      clave: (box) => box.maxWidth > 1000,
      builder: (context, box) {
        // Con sitio, la ficha completa va fija a la derecha; si no, se abre con "Editar ficha".
        final conFicha = box.maxWidth > 1000;
        final principal = Padding(
          padding: margenPagina,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cabecera(
                lider: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: m('Volver a Trabajadores'),
                      onPressed: onVolver,
                      icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
                    ),
                    const SizedBox(width: 4),
                    Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 40),
                  ],
                ),
                titulo: w.nombreCompleto,
                subtitulo: w.competencias.isEmpty ? 'Sin competencias' : w.competencias.join(' · '),
                acciones: [
                  w.activo
                      ? Pill(w.estadoHoy.etiqueta, w.estadoHoy.color, punto: true)
                      : const Pill('Inactivo', P.gris, punto: true),
                  if (!conFicha)
                    OutlinedButton(onPressed: () => abrirTrabajadorForm(context, w), child: const Text('Editar ficha')),
                  if (store.nube != null) _Acceso(w, key: ValueKey('acceso-${w.id}')),
                  // Sin tareas, el botón está en el centro; arriba solo cuando ya hay alguna.
                  if (tareas.isNotEmpty)
                    BotonPrimario(
                      m('Asignar trabajo'),
                      icono: Icons.add_task_rounded,
                      onPressed: () => abrirAsignar(context, w),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              titulo,
              Expanded(child: lista),
            ],
          ),
        );
        if (!conFicha) return principal;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: principal),
            SizedBox(
              width: 440,
              child: TrabajadorForm(key: ValueKey(w.id), original: w, incrustada: true),
            ),
          ],
        );
      },
    );
  }

  /// Por día y hora; lo que no tiene fecha, al final.
  static DateTime _orden(Tarea t) => (t.proximo ?? DateTime(2100)).add(Duration(minutes: t.inicioMin ?? 0));
}

/// «Tiene acceso» si la ficha ya está ligada a una cuenta; si no, el botón para invitarlo (DEV-020).
class _Acceso extends StatefulWidget {
  final Trabajador w;
  const _Acceso(this.w, {super.key});

  @override
  State<_Acceso> createState() => _AccesoState();
}

class _AccesoState extends State<_Acceso> {
  /// null mientras se lee la base (no se pinta nada para no parpadear).
  ({bool cuenta, bool invitado})? _estado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final nube = store.nube!;
    var estado = (cuenta: false, invitado: false);
    try {
      final r = await Future.wait([nube.accesos(), nube.invitacionesPendientes()]);
      estado = (
        cuenta: (r[0] as List<Acceso>).any((a) => nube.esFicha(widget.w.id, a.trabajadorId)),
        invitado: (r[1] as List<InvitacionPendiente>).any((i) => nube.esFicha(widget.w.id, i.trabajadorId)),
      );
    } catch (e) {
      debugPrint('Pulpo: no se pudo leer el acceso de ${widget.w.nombre}: $e');
    }
    if (mounted) setState(() => _estado = estado);
  }

  Future<void> _invitar() async {
    await invitarTrabajador(context, widget.w);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final e = _estado;
    if (e == null) return const SizedBox.shrink();
    if (e.cuenta) return const Pill('Tiene acceso', P.verde, punto: true);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.invitado) ...[const Pill('Invitación pendiente', P.ambar, punto: true), const SizedBox(width: 8)],
        OutlinedButton(onPressed: _invitar, child: Text(e.invitado ? 'Invitar de nuevo' : 'Invitar a la app')),
      ],
    );
  }
}

class _TareaAsignada extends StatelessWidget {
  final Tarea t;
  final Trabajador w;
  const _TareaAsignada(this.t, this.w);

  @override
  Widget build(BuildContext context) {
    final c = store.cliente(t.clienteId);
    return FilaLista(
      lider: BarraTipo(t.tipo, alto: 32, color: t.colorBloque),
      titulo: t.nombre,
      subtitulo: [c?.nombre ?? '—', if (t.proximo != null) fecha(t.proximo), ?t.horario].join(' · '),
      onTap: () => abrirTareaForm(context, t),
      derecha: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectorEstado(t),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Quitar de ${w.nombre}',
            visualDensity: VisualDensity.compact,
            onPressed: () => store.desasignar(t, w.id),
            icon: Icon(Icons.person_remove_outlined, size: 18, color: P.textoSuave),
          ),
        ],
      ),
    );
  }
}

// ── Asignar tarea a mano ─────────────────────────────────

/// Lista de clientes con sus tareas para asignar a mano. Normalmente lo hará Pulpo solo,
/// pero siempre se puede hacer manualmente. Avisa de solapes de horario.
Future<void> abrirAsignar(BuildContext context, Trabajador w) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.superficie,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720), child: _Asignar(w.id)),
  ),
);

class _Asignar extends StatefulWidget {
  final String trabajadorId;
  const _Asignar(this.trabajadorId);

  @override
  State<_Asignar> createState() => _AsignarState();
}

class _AsignarState extends State<_Asignar> {
  /// Con pocos clientes y pocas tareas se muestra todo abierto; si no, plegado para no abrumar.
  static const maxClientesAbiertos = 4, maxTareasAbiertas = 12;

  late final Map<Cliente, List<Tarea>> porCliente = () {
    final m = <Cliente, List<Tarea>>{};
    for (final c in [...store.clientes]..sort((a, b) => a.nombre.compareTo(b.nombre))) {
      final ts = store.tareasDe(c.id).where((t) => t.activa).toList()
        ..sort((a, b) => TrabajadorDetalle._orden(a).compareTo(TrabajadorDetalle._orden(b)));
      if (ts.isNotEmpty) m[c] = ts;
    }
    return m;
  }();

  late final abiertos = <String>{
    if (porCliente.length <= maxClientesAbiertos &&
        porCliente.values.fold(0, (s, ts) => s + ts.length) <= maxTareasAbiertas)
      ...porCliente.keys.map((c) => c.id),
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final w = store.trabajador(widget.trabajadorId);
      if (w == null) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m('ASIGNAR TRABAJO'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.morado),
                      ),
                      Text(
                        w.nombreCompleto,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.4),
                      ),
                      Text(
                        m('Toca un trabajo para asignarlo. Los que se solapan con su horario no se pueden elegir.'),
                        style: TextStyle(fontSize: 13, color: P.textoSuave),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: porCliente.isEmpty
                  ? Vacio(icono: Marca.iconoCliente, texto: m('Ningún cliente tiene trabajos todavía'))
                  : ListView(
                      padding: const EdgeInsets.only(right: 8),
                      children: [for (final e in porCliente.entries) _cliente(e.key, e.value, w)],
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _cliente(Cliente c, List<Tarea> tareas, Trabajador w) {
    final abierto = abiertos.contains(c.id);
    final suyas = tareas.where((t) => t.trabajadorIds.contains(w.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => abierto ? abiertos.remove(c.id) : abiertos.add(c.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                Avatar(c.iniciales, colorPaleta(c.color), size: 28, cuadrado: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (suyas > 0) ...[Pill('$suyas suyas', P.verde), const SizedBox(width: 6)],
                Pill('${tareas.length}', colorPaleta(c.color)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: abierto ? .25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.chevron_right_rounded, color: P.textoSuave),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: abierto
              ? Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 8),
                  child: Column(children: [for (final t in tareas) _tarea(t, w)]),
                )
              : const SizedBox(width: double.infinity),
        ),
        Divider(height: 1, color: P.borde),
      ],
    );
  }

  Widget _tarea(Tarea t, Trabajador w) {
    final asignada = t.trabajadorIds.contains(w.id);
    final choques = asignada ? <Tarea>[] : store.solapes(t, w.id);
    final faltan = t.competencias.where((c) => !w.competencias.contains(c)).toList();
    final cuando = [
      if (t.proximo != null) fecha(t.proximo),
      if (t.horario != null) '${t.horario} (+${tipoDe(t.tipo).retrasoMin} min margen)' else 'sin hora',
    ].join(' · ');

    String? aviso;
    Color colorAviso = P.rojo;
    if (choques.isNotEmpty) {
      final o = choques.first;
      aviso = 'Se solapa con "${o.nombre}" (${o.horario} +${tipoDe(o.tipo).retrasoMin} min)';
    } else if (faltan.isNotEmpty) {
      aviso = 'Le falta: ${faltan.join(', ')}';
      colorAviso = P.ambar;
    }

    return Opacity(
      opacity: choques.isNotEmpty ? .55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: choques.isNotEmpty ? null : () => asignada ? store.desasignar(t, w.id) : store.asignar(t, w.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              BarraTipo(t.tipo, alto: 30, color: t.colorBloque),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(cuando, style: TextStyle(fontSize: 12, color: P.textoSuave)),
                    if (aviso != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(aviso, style: TextStyle(fontSize: 12, color: colorAviso)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (asignada)
                const Pill('Asignado', P.verde, punto: true)
              else if (choques.isNotEmpty)
                const Icon(Icons.block_rounded, size: 20, color: P.rojo)
              else
                Icon(Icons.add_circle_outline_rounded, size: 22, color: P.morado),
            ],
          ),
        ),
      ),
    );
  }
}
