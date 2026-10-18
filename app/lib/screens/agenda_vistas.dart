import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../ajustes.dart';
import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../planificador.dart';
import 'agenda_herramientas.dart';
import 'rutas_mapa.dart';
import 'vista_dias.dart';

// Horas visibles en las vistas Día y Semana.
const _desde = 7, _hasta = 21;

/// Tareas que caen en [dia] (hoy incluye lo vencido) y pasan los filtros de la agenda.
List<Tarea> tareasDe(DateTime dia) => store.tareasDelDia(dia).where((t) => filtroAgenda.pasa(t, dia)).toList();

/// Hora (en minutos) que corresponde a una posición en la rejilla: a la media hora o, con
/// zoom, al cuarto de hora.
int _horaEn(double px, double porHora) {
  final paso = porHora >= 110 ? 15 : 30;
  return (_desde * 60 + (px / porHora * 60) ~/ paso * paso).clamp(_desde * 60, _hasta * 60 - paso);
}

// ── Zoom (Semana y Mes): Ctrl + rueda, Ctrl + / Ctrl −, o los botones − / + ──

/// Alto de una hora en la vista Semana y de una fila en la vista Mes (null = ajustado a la pantalla).
final altoHora = ValueNotifier<double>(52);
final altoFilaMes = ValueNotifier<double?>(null);

void zoomSemana(double factor) => altoHora.value = (altoHora.value * factor).clamp(30, 320);
void zoomMes(double factor, double ajustado) =>
    altoFilaMes.value = ((altoFilaMes.value ?? ajustado) * factor).clamp(ajustado, ajustado * 4);

/// Escucha Ctrl + rueda (y el pellizco del trackpad) y Ctrl + / Ctrl − para hacer zoom.
class ConZoom extends StatelessWidget {
  final void Function(double factor) onZoom;
  final Widget child;
  const ConZoom({super.key, required this.onZoom, required this.child});

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () => onZoom(1.2),
      const SingleActivator(LogicalKeyboardKey.add, control: true): () => onZoom(1.2),
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): () => onZoom(1.2),
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () => onZoom(1 / 1.2),
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): () => onZoom(1 / 1.2),
    },
    child: Focus(
      autofocus: true,
      child: Listener(
        onPointerSignal: (e) {
          if (e is PointerScaleEvent) {
            onZoom(e.scale);
          } else if (e is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
            // Que no haga scroll a la vez.
            GestureBinding.instance.pointerSignalResolver.register(
              e,
              (_) => onZoom(e.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15),
            );
          }
        },
        child: child,
      ),
    ),
  );
}

/// Bloque de una tarea en la agenda: fondo suave y barrita del color del tipo; vencida en rojo.
class BloqueTarea extends StatelessWidget {
  final Tarea t;
  final DateTime dia;
  final bool compacto;

  /// Se puede arrastrar a otro día u hora (vista Semana).
  final bool arrastrable;
  const BloqueTarea(this.t, this.dia, {super.key, this.compacto = false, this.arrastrable = false});

  @override
  Widget build(BuildContext context) {
    final color = t.colorBloque;
    final hecha = t.hechaEl(dia);
    final vencida = !hecha && t.proximo != null && diasHasta(t.proximo!) < 0;
    final cliente = store.cliente(t.clienteId);
    final base = _bloque(context, color, hecha, vencida, cliente);
    final bloque = !arrastrable
        ? base
        : LayoutBuilder(
            builder: (context, box) => Draggable<Tarea>(
              data: t,
              feedback: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: box.maxWidth,
                  height: box.maxHeight.isFinite ? box.maxHeight : 40,
                  child: Opacity(opacity: .92, child: base),
                ),
              ),
              childWhenDragging: Opacity(opacity: .3, child: base),
              child: MouseRegion(cursor: SystemMouseCursors.grab, child: base),
            ),
          );
    if (!store.esRecien(t.id)) return bloque;
    // Recién creada: entra creciendo y con un halo morado que se apaga.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        scale: .6 + .4 * v.clamp(0, 1.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: P.morado.withValues(alpha: .6 * (1 - v.clamp(0, 1))), blurRadius: 18, spreadRadius: 4),
            ],
          ),
          child: child,
        ),
      ),
      child: bloque,
    );
  }

  Widget _bloque(BuildContext context, Color color, bool hecha, bool vencida, Cliente? cliente) {
    return Tooltip(
      message: [t.nombre, cliente?.nombre ?? '', ?t.horario].where((x) => x.isNotEmpty).join(' · '),
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Color.lerp(P.superficie, color, hecha ? .06 : .13),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => abrirFichaRapida(context, t),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: vencida ? P.rojo : color, width: 3)),
            ),
            padding: EdgeInsets.fromLTRB(6, compacto ? 2 : 4, 4, 2),
            child: Opacity(
              opacity: hecha ? .55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: hecha ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (!compacto)
                    Text(
                      [?t.inicioMin == null ? null : hhmm(t.inicioMin!), cliente?.nombre ?? ''].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: vencida ? P.rojo : P.textoSuave),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Día: una fila por técnico sobre la línea de horas (como el "Day" de Jobber) ──

class VistaDiaTecnicos extends StatelessWidget {
  final DateTime dia;
  const VistaDiaTecnicos(this.dia, {super.key});

  @override
  Widget build(BuildContext context) {
    final tareas = tareasDe(dia);
    final ws = store.trabajadores.where((w) => w.activo).toList()
      ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
    final f = filtroAgenda.tecnicos;
    final filas = <(Trabajador?, List<Tarea>)>[
      if (f.isEmpty) (null, tareas.where((t) => t.trabajadorIds.isEmpty).toList()),
      for (final w in ws.where((w) => f.isEmpty || f.contains(w.id)))
        (w, tareas.where((t) => t.trabajadorIds.contains(w.id)).toList()),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        const izq = 190.0;
        final porHora = max(64.0, (box.maxWidth - izq) / (_hasta - _desde));
        final ancho = izq + porHora * (_hasta - _desde);
        return Container(
          decoration: BoxDecoration(
            color: P.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: P.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            key: const PageStorageKey('itinerario-dia'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: ancho,
              child: Column(
                children: [
                  // Cabecera de horas.
                  Container(
                    height: 34,
                    color: P.cabeceraTabla,
                    child: Row(
                      children: [
                        SizedBox(
                          width: izq,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text('Equipo', style: TextStyle(fontSize: 12, color: P.textoSuave)),
                          ),
                        ),
                        for (var h = _desde; h < _hasta; h++)
                          SizedBox(
                            width: porHora,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text('$h:00', style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: P.borde),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filas.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                      itemBuilder: (_, i) => _filaTecnico(context, filas[i].$1, filas[i].$2, izq, porHora),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filaTecnico(BuildContext context, Trabajador? w, List<Tarea> ts, double izq, double porHora) {
    final conHora = ts.where((t) => t.inicioMin != null).toList();
    final sinHora = ts.where((t) => t.inicioMin == null).toList();
    final ahora = TimeOfDay.now();
    final minAhora = ahora.hour * 60 + ahora.minute;
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          InkWell(
            onTap: w == null ? null : () => filtroAgenda.soloTecnico(w.id),
            child: Container(
              width: izq,
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: w != null && filtroAgenda.tecnicos.contains(w.id) ? P.moradoSuave.withValues(alpha: .6) : null,
                border: Border(right: BorderSide(color: P.borde)),
              ),
              child: Row(
                children: [
                  w == null
                      ? Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: P.borde, width: 1.5),
                          ),
                        )
                      : Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 26),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w?.nombreCompleto ?? 'Sin asignar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: w == null ? P.textoSuave : P.texto,
                          ),
                        ),
                        Text(
                          [
                            '${ts.length} ${ts.length == 1 ? 'visita' : 'visitas'}',
                            if (sinHora.isNotEmpty) '${sinHora.length} sin hora',
                          ].join(' · '),
                          style: TextStyle(fontSize: 11, color: P.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              // Pulsar un hueco crea una tarea a esa hora para ese técnico.
              onTapUp: (d) => abrirTareaForm(
                context,
                null,
                fecha: dia,
                horaMin: _horaEn(d.localPosition.dx, porHora),
                trabajadorId: w?.id,
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.cell,
                child: Stack(
                  children: [
                    // Rejilla de horas.
                    Row(
                      children: [
                        for (var h = _desde; h < _hasta; h++)
                          Container(
                            width: porHora,
                            decoration: BoxDecoration(
                              border: Border(left: BorderSide(color: P.borde.withValues(alpha: .6))),
                            ),
                          ),
                      ],
                    ),
                    for (final t in conHora)
                      if (t.inicioMin! < _hasta * 60 && t.finMin! > _desde * 60)
                        Positioned(
                          left: (max(t.inicioMin!, _desde * 60) - _desde * 60) / 60 * porHora + 2,
                          width: max(
                            36,
                            (min(t.finMin!, _hasta * 60) - max(t.inicioMin!, _desde * 60)) / 60 * porHora - 4,
                          ),
                          top: 8,
                          bottom: 8,
                          child: BloqueTarea(t, dia),
                        ),
                    // Ahora: línea roja si es hoy.
                    if (diasHasta(dia) == 0 && minAhora > _desde * 60 && minAhora < _hasta * 60)
                      Positioned(
                        left: (minAhora - _desde * 60) / 60 * porHora,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(child: Container(width: 2, color: P.rojo)),
                      ),
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

// ── Semana: columnas por día y franjas por hora ──

class VistaSemana extends StatelessWidget {
  final DateTime lunes;
  const VistaSemana(this.lunes, {super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: altoHora,
    builder: (context, alto, _) => ConZoom(onZoom: zoomSemana, child: _construir(context, alto)),
  );

  Widget _construir(BuildContext context, double altoH) {
    final dias = [for (var i = 0; i < 7; i++) masDias(lunes, i)];
    final porDia = [for (final d in dias) tareasDe(d)];
    // Arriba, lo que no tiene hora y lo vencido (para no amontonarlo en la rejilla de hoy).
    bool arriba(Tarea t, DateTime d) =>
        t.inicioMin == null || (!t.hechaEl(d) && t.proximo != null && diasHasta(t.proximo!) < 0);
    final haySinHora = [for (final (i, ts) in porDia.indexed) ts.any((t) => arriba(t, dias[i]))].any((x) => x);
    const izq = 66.0;
    return Container(
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cabecera de días.
          Container(
            color: P.cabeceraTabla,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: izq),
                for (final d in dias)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          diasSemana[d.weekday - 1].toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                            color: P.textoSuave,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: diasHasta(d) == 0 ? BoxDecoration(color: P.morado, shape: BoxShape.circle) : null,
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontFamily: P.titulos,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: diasHasta(d) == 0 ? Colors.white : P.texto,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: P.borde),
          // Franja de lo que no tiene hora.
          if (haySinHora) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: izq,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text('Pendiente', style: TextStyle(fontSize: 10.5, color: P.textoSuave)),
                    ),
                  ),
                  for (final (i, ts) in porDia.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: [
                            for (final t in ts.where((t) => arriba(t, dias[i])).take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: SizedBox(height: 22, child: BloqueTarea(t, dias[i], compacto: true)),
                              ),
                            if (ts.where((t) => arriba(t, dias[i])).length > 3)
                              Text(
                                '+${ts.where((t) => arriba(t, dias[i])).length - 3} más',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: P.textoSuave),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: P.borde),
          ],
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('itinerario-semana'),
              child: SizedBox(
                height: altoH * (_hasta - _desde),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: izq,
                      child: Column(
                        children: [
                          for (var h = _desde; h < _hasta; h++)
                            SizedBox(
                              height: altoH,
                              child: Stack(
                                children: [
                                  for (final (m, fuerte) in [
                                    (0, true),
                                    if (altoH >= 110) (30, false),
                                    if (altoH >= 200) ...[(15, false), (45, false)],
                                  ])
                                    Positioned(
                                      top: m / 60 * altoH + 2,
                                      right: 8,
                                      child: Text(
                                        '$h:${m.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: fuerte ? 11 : 10,
                                          color: P.textoSuave.withValues(alpha: fuerte ? 1 : .7),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final (i, ts) in porDia.indexed)
                      Expanded(child: _columna(dias[i], ts.where((t) => !arriba(t, dias[i])).toList(), altoH)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columna(DateTime dia, List<Tarea> ts, double altoH) {
    final conHora = ts.where((t) => t.inicioMin != null).toList()..sort((a, b) => a.inicioMin! - b.inicioMin!);
    // Reparte en carriles las que se solapan, para ponerlas lado a lado.
    final carriles = <List<Tarea>>[];
    for (final t in conHora) {
      final libre = carriles.indexWhere((c) => c.last.finMin! <= t.inicioMin!);
      libre < 0 ? carriles.add([t]) : carriles[libre].add(t);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final anchoCarril = box.maxWidth / max(1, carriles.length);
        return Container(
          decoration: BoxDecoration(
            color: diasHasta(dia) == 0 ? P.moradoSuave.withValues(alpha: .35) : null,
            border: Border(left: BorderSide(color: P.borde)),
          ),
          // Soltar un bloque aquí lo mueve a este día y a la hora donde cae su borde superior.
          child: DragTarget<Tarea>(
            onAcceptWithDetails: (d) {
              final caja = context.findRenderObject() as RenderBox;
              final y = caja.globalToLocal(d.offset).dy;
              final c = d.data.copia()
                ..proximo = dia
                ..inicioMin = _horaEn(max(0, y), altoH);
              store.guardarTarea(c);
            },
            builder: (context, candidatos, _) => Container(
              color: candidatos.isEmpty ? null : P.moradoSuave.withValues(alpha: .5),
              child: GestureDetector(
                // Pulsar un hueco crea una tarea ese día a esa hora.
                onTapUp: (d) => abrirTareaForm(context, null, fecha: dia, horaMin: _horaEn(d.localPosition.dy, altoH)),
                child: MouseRegion(
                  cursor: SystemMouseCursors.cell,
                  child: Stack(
                    children: [
                      for (var h = 0; h < _hasta - _desde; h++) ...[
                        Positioned(
                          top: h * altoH,
                          left: 0,
                          right: 0,
                          child: Divider(height: 1, color: P.borde.withValues(alpha: .6)),
                        ),
                        // Con zoom, líneas finas en las medias y en los cuartos.
                        for (final m in [
                          if (altoH >= 110) 30,
                          if (altoH >= 200) ...[15, 45],
                        ])
                          Positioned(
                            top: h * altoH + m / 60 * altoH,
                            left: 0,
                            right: 0,
                            child: Divider(height: 1, color: P.borde.withValues(alpha: .3)),
                          ),
                      ],
                      for (final (c, carril) in carriles.indexed)
                        for (final t in carril)
                          if (t.inicioMin! < _hasta * 60 && t.finMin! > _desde * 60)
                            Positioned(
                              top: (max(t.inicioMin!, _desde * 60) - _desde * 60) / 60 * altoH + 1,
                              height: max(
                                24,
                                (min(t.finMin!, _hasta * 60) - max(t.inicioMin!, _desde * 60)) / 60 * altoH - 2,
                              ),
                              left: c * anchoCarril + 2,
                              width: anchoCarril - 4,
                              child: BloqueTarea(t, dia, compacto: t.duracionMin < 60, arrastrable: true),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Mapa: los clientes con visitas en el periodo, como chinchetas de su color ──

class MapaAgenda extends StatefulWidget {
  final DateTime desde, hasta;
  final String periodo;
  const MapaAgenda({super.key, required this.desde, required this.hasta, required this.periodo});

  @override
  State<MapaAgenda> createState() => _MapaAgendaState();
}

class _MapaAgendaState extends State<MapaAgenda> {
  final mapa = MapController();
  String? elegido;

  /// Color de las chinchetas: 0 cliente, 1 técnico, 2 tipo de mantenimiento.
  int colorPor = 0;

  Color _color(Cliente c, List<Tarea> ts) => switch (colorPor) {
    1 => () {
      final w = ts.expand((t) => t.trabajadorIds).map(store.trabajador).whereType<Trabajador>().firstOrNull;
      return w == null ? P.gris : colorPaleta(w.color);
    }(),
    2 => tipoDe(ts.first.tipo).color,
    _ => colorPaleta(c.color),
  };

  /// Encuadra todas las chinchetas.
  void encuadrar(List<Cliente> cs) {
    if (cs.length < 2) return;
    mapa.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([for (final c in cs) LatLng(c.lat!, c.lng!)]),
        padding: const EdgeInsets.fromLTRB(40, 80, 40, 90),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    planActual.addListener(_repintar);
  }

  @override
  void dispose() {
    planActual.removeListener(_repintar);
    super.dispose();
  }

  void _repintar() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final porCliente = <String, List<Tarea>>{};
    for (var d = widget.desde; !d.isAfter(widget.hasta); d = masDias(d, 1)) {
      for (final t in tareasDe(d)) {
        if (t.clienteId == null) continue;
        final l = porCliente.putIfAbsent(t.clienteId!, () => []);
        if (!l.contains(t)) l.add(t);
      }
    }
    final clientes = porCliente.keys.map(store.cliente).whereType<Cliente>().toList();
    final ubicados = clientes.where((c) => c.ubicado).toList();
    final sinUbicar = clientes.length - ubicados.length;
    final centro = ubicados.isEmpty
        ? const LatLng(43.263, -2.935) // Bilbao
        : LatLng(
            ubicados.map((c) => c.lat!).reduce((a, b) => a + b) / ubicados.length,
            ubicados.map((c) => c.lng!).reduce((a, b) => a + b) / ubicados.length,
          );
    final sel = elegido == null ? null : store.cliente(elegido);

    return Container(
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapa,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: ubicados.length > 1 ? 11.5 : 13,
              onTap: (_, _) => setState(() => elegido = null),
              // Solo Bilbao y alrededores (Bizkaia).
              minZoom: 9.5,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(const LatLng(43.10, -3.25), const LatLng(43.45, -2.60)),
              ),
            ),
            children: [
              TileLayer(
                // OpenStreetMap, gratis y sin clave. Algo desaturado para que no compita con las chinchetas;
                // invertido en modo oscuro.
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pulpo.app',
                tileBuilder: (context, tile, imagen) => ajustes.oscuro
                    ? darkModeTileBuilder(context, tile, imagen)
                    : ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.75, 0.2, 0.05, 0, 12, //
                          0.15, 0.8, 0.05, 0, 12, //
                          0.15, 0.2, 0.65, 0, 18, //
                          0, 0, 0, 1, 0,
                        ]),
                        child: tile,
                      ),
              ),
              // Con un plan a la vista, las chinchetas de cliente dejan sitio a las rutas.
              if (planActual.value == null)
                MarkerLayer(
                  markers: [
                    for (final c in ubicados)
                      Marker(
                        point: LatLng(c.lat!, c.lng!),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => setState(() => elegido = c.id),
                          child: _Chincheta(
                            _color(c, porCliente[c.id]!),
                            porCliente[c.id]!.length,
                            elegido == c.id,
                            vencida: porCliente[c.id]!.any((t) => t.proximo != null && diasHasta(t.proximo!) < 0),
                          ),
                        ),
                      ),
                  ],
                ),
              const CapaRutas(),
            ],
          ),
          Positioned(right: 12, top: 12, child: const ControlesRuta()),
          // Cabecera flotante con el resumen.
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: P.superficie,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mapa · ${widget.periodo}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    [
                      '${ubicados.length} ${ubicados.length == 1 ? 'cliente' : 'clientes'}',
                      if (sinUbicar > 0) '$sinUbicar sin ubicar',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11.5, color: sinUbicar > 0 ? P.ambar : P.textoSuave),
                  ),
                ],
              ),
            ),
          ),
          // Herramientas: color de las chinchetas, leyenda y encuadrar.
          if (sel == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _HerramientasMapa(
                colorPor: colorPor,
                onColor: (i) => setState(() => colorPor = i),
                onEncuadrar: () => encuadrar(ubicados),
                leyenda: switch (colorPor) {
                  1 => [
                    for (final w in store.trabajadores.where(
                      (w) => porCliente.values.expand((ts) => ts).any((t) => t.trabajadorIds.contains(w.id)),
                    ))
                      (w.nombre, colorPaleta(w.color)),
                    if (porCliente.values.expand((ts) => ts).any((t) => t.trabajadorIds.isEmpty))
                      ('Sin asignar', P.gris),
                  ],
                  2 => [
                    for (final x in tipos.where(
                      (x) => porCliente.values.expand((ts) => ts).any((t) => t.tipo == x.nombre),
                    ))
                      (x.nombre, x.color),
                  ],
                  _ => const [],
                },
              ),
            ),
          // Ficha del cliente elegido.
          if (sel != null)
            Positioned(left: 12, right: 12, bottom: 12, child: _FichaMapa(sel, porCliente[sel.id] ?? const [])),
          if (ubicados.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  clientes.isEmpty
                      ? 'Nada programado en este periodo'
                      : 'Añade la dirección de tus clientes para verlos aquí',
                  style: TextStyle(color: P.textoSuave, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chincheta redonda del color del cliente, con el número de visitas.
class _Chincheta extends StatelessWidget {
  final Color color;
  final int n;
  final bool elegida, vencida;
  const _Chincheta(this.color, this.n, this.elegida, {this.vencida = false});

  @override
  Widget build(BuildContext context) => AnimatedScale(
    duration: const Duration(milliseconds: 150),
    scale: elegida ? 1.2 : 1,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: vencida ? P.rojo : Colors.white, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .45), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(
        '$n',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ),
  );
}

class _FichaMapa extends StatelessWidget {
  final Cliente c;
  final List<Tarea> tareas;
  const _FichaMapa(this.c, this.tareas);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 16)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Avatar(c.iniciales, colorPaleta(c.color), size: 28, cuadrado: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(
                    c.direccionCompleta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in tareas.take(4))
          InkWell(
            onTap: () => abrirFichaRapida(context, t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  BarraTipo(t.tipo, alto: 22, color: t.colorBloque),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.nombre, style: const TextStyle(fontSize: 12.5))),
                  Text(
                    [if (t.proximo != null) relativo(t.proximo!), ?t.horario].join(' · '),
                    style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                  ),
                  const SizedBox(width: 8),
                  pillEstado(t),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Barra flotante bajo el mapa: colorear por cliente / técnico / tipo, leyenda y encuadrar.
class _HerramientasMapa extends StatelessWidget {
  final int colorPor;
  final ValueChanged<int> onColor;
  final VoidCallback onEncuadrar;
  final List<(String, Color)> leyenda;
  const _HerramientasMapa({
    required this.colorPor,
    required this.onColor,
    required this.onEncuadrar,
    required this.leyenda,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Color', style: TextStyle(fontSize: 12, color: P.textoSuave)),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  child: Pestanas(
                    opciones: const ['Cliente', 'Técnico', 'Tipo'],
                    seleccion: colorPor,
                    onChanged: onColor,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Encuadrar todo',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onEncuadrar,
                icon: Icon(Icons.fit_screen_outlined, size: 19, color: P.textoSuave),
              ),
            ),
          ],
        ),
        if (leyenda.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final (n, c) in leyenda)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(n, style: const TextStyle(fontSize: 11.5)),
                  ],
                ),
            ],
          ),
        ],
      ],
    ),
  );
}
