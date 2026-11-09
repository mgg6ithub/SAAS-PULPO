import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'agenda_herramientas.dart';
import 'calendario_datos.dart';
import 'tarea_detalle.dart';
import 'vista_dias.dart' show lunesDe, diasSemana;
import '../marca.dart';
import '../industrial/iconos.dart';
import '../industrial/tipo_mantenimiento.dart';
import '../industrial/plan.dart';

enum ModoCalendario { mes, semana, dia }

class CalendarioTrabajos extends StatefulWidget {
  final DateTime dia;
  final ModoCalendario modo;
  final ValueChanged<ModoCalendario> onModo;
  final ValueChanged<DateTime> onDia;
  const CalendarioTrabajos({
    super.key,
    required this.dia,
    required this.modo,
    required this.onModo,
    required this.onDia,
  });
  @override
  State<CalendarioTrabajos> createState() => _CalendarioTrabajosState();
}

class _CalendarioTrabajosState extends State<CalendarioTrabajos> {
  // Los filtros pertenecen al calendario: no cambian el Plan.
  final filtro = FiltroAgenda();
  Map<DateTime, List<VisitaCalendario>> visitas = {};
  String? detalle;
  late DateTime desde, hasta;
  @override
  void initState() {
    super.initState();
    store.addListener(_actualizar);
    filtro.addListener(_actualizar);
    _indexar();
  }

  @override
  void didUpdateWidget(CalendarioTrabajos old) {
    super.didUpdateWidget(old);
    if (old.dia != widget.dia || old.modo != widget.modo) _indexar();
  }

  void _indexar() {
    desde = widget.modo == ModoCalendario.mes
        ? lunesDe(DateTime(widget.dia.year, widget.dia.month))
        : widget.modo == ModoCalendario.semana
        ? lunesDe(widget.dia)
        : DateUtils.dateOnly(widget.dia);
    hasta = masDias(
      desde,
      widget.modo == ModoCalendario.mes
          ? 41
          : widget.modo == ModoCalendario.semana
          ? 6
          : 0,
    );
    visitas = visitasCalendario(store.tareas, desde, hasta, filtro.pasa);
  }

  void _actualizar() {
    if (mounted) setState(_indexar);
  }

  @override
  void dispose() {
    store.removeListener(_actualizar);
    filtro.removeListener(_actualizar);
    filtro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Pestanas(
                    opciones: const ['Mes', 'Semana', 'Día'],
                    seleccion: widget.modo.index,
                    onChanged: (i) => widget.onModo(ModoCalendario.values[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            // Como las tablas: esquinas redondeadas y borde fino.
            decoration: BoxDecoration(
              color: P.superficie,
              borderRadius: BorderRadius.circular(P.radio),
              border: Border.all(color: P.borde),
            ),
            child: switch (widget.modo) {
              ModoCalendario.mes => _MesCalendario(
                dia: widget.dia,
                desde: desde,
                visitas: visitas,
                onDia: widget.onDia,
                onDetalle: _detalle,
              ),
              ModoCalendario.semana => _SemanaCalendario(
                key: ValueKey('semana-$desde'),
                desde: desde,
                visitas: visitas,
                onDia: widget.onDia,
                onDetalle: _detalle,
              ),
              ModoCalendario.dia => _DiaCalendario(
                key: ValueKey('dia-$desde'),
                dia: desde,
                visitas: visitas[desde] ?? [],
                onDetalle: _detalle,
              ),
            },
          ),
        ),
      ],
    );
    return Stack(
      children: [
        Positioned.fill(child: contenido),
        if (detalle != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: box.maxWidth < 900 ? box.maxWidth : min(680, box.maxWidth * .65),
                  decoration: BoxDecoration(
                    color: P.superficie,
                    border: Border.all(color: P.borde),
                    borderRadius: BorderRadius.circular(P.radio),
                  ),
                  child: CallbackShortcuts(
                    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cerrar},
                    child: Focus(
                      autofocus: true,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(m('Detalles del trabajo'), style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  tooltip: 'Cerrar detalles',
                                  onPressed: _cerrar,
                                  icon: const Icon(CupertinoIcons.xmark, size: 18),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TareaDetalle(
                              key: ValueKey(detalle),
                              tareaId: detalle!,
                              onVolver: _cerrar,
                              onAbrir: _detalle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _detalle(String id) => setState(() => detalle = id);
  void _cerrar() => setState(() => detalle = null);
}

class _MesCalendario extends StatelessWidget {
  final DateTime dia, desde;
  final Map<DateTime, List<VisitaCalendario>> visitas;
  final ValueChanged<DateTime> onDia;
  final ValueChanged<String> onDetalle;
  const _MesCalendario({
    required this.dia,
    required this.desde,
    required this.visitas,
    required this.onDia,
    required this.onDetalle,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 36,
        child: Row(
          children: [
            for (final d in diasSemana)
              Expanded(
                child: Center(
                  child: Text(d.substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 11, color: P.textoSuave)),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            final alto = max(110.0, box.maxHeight / 6);
            final escala = MediaQuery.textScalerOf(context).scale(1);
            final capacidad = max(1, ((alto - 64) / (27 * escala)).floor());
            return ListView.builder(
              itemExtent: alto,
              itemCount: 6,
              itemBuilder: (context, semana) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(child: _celda(context, masDias(desde, semana * 7 + i), capacidad, 27 * escala)),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
  Widget _celda(BuildContext context, DateTime d, int capacidad, double alto) {
    final lista = visitas[d] ?? [];
    // Soltar aquí una orden de «Sin fecha» le pone este día.
    return DragTarget<Tarea>(
      // En el mes no hay hora donde cae: la primera libre de ese día.
      onAcceptWithDetails: (e) => _ponerFecha(e.data, d, inicioMin: primerHueco(d, e.data.duracionMin, sin: e.data.id)),
      builder: (context, candidatos, _) => Container(
        decoration: BoxDecoration(
          color: candidatos.isNotEmpty
              ? P.moradoSuave
              : d.month != dia.month
              ? P.fondo
              : P.superficie,
          border: Border(
            top: BorderSide(color: P.borde),
            right: BorderSide(color: P.borde),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 34,
              child: InkWell(
                onTap: () => onDia(d),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [_NumeroDia(d)]),
                ),
              ),
            ),
            for (final v in lista.take(capacidad))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: SizedBox(
                  height: alto - 3,
                  child: _EventoCalendario(v, compacto: true, onDetalle: onDetalle),
                ),
              ),
            if (lista.length > capacidad)
              SizedBox(
                height: 25,
                child: InkWell(
                  onTap: () => onDia(d),
                  child: Center(
                    child: Text(
                      '+${lista.length - capacidad} más',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: P.moradoOscuro),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pone fecha (y, si se sabe, hora) a una orden arrastrada desde «Sin fecha»; sale de la lista.
void _ponerFecha(Tarea t, DateTime d, {int? inicioMin}) {
  final c = t.copia()..proximo = d;
  if (inicioMin != null) c.inicioMin = inicioMin;
  store.guardarTarea(c);
}

/// Primera hora libre (cada 15 min, de 8:00 a 20:00) en que cabe [duracion] sin pisar otra orden ese día;
/// hoy, desde la próxima hora en punto. null si no cabe.
int? primerHueco(DateTime dia, int duracion, {String? sin}) {
  final ocupado = [
    for (final v in visitasCalendario(store.tareas, dia, dia, (_, _) => true)[DateUtils.dateOnly(dia)] ?? [])
      if (v.tarea.id != sin && v.inicio != null) (v.inicio!, v.fin!),
  ];
  var desde = 8 * 60;
  if (DateUtils.isSameDay(dia, hoy())) desde = max(desde, (DateTime.now().hour + 1) * 60);
  for (var s = desde; s + duracion <= 20 * 60; s += 15) {
    if (ocupado.every((o) => s + duracion <= o.$1 || s >= o.$2)) return s;
  }
  return null;
}

class _NumeroDia extends StatelessWidget {
  final DateTime dia;
  const _NumeroDia(this.dia);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: DateUtils.isSameDay(dia, hoy()) ? P.morado : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '${dia.day}',
      style: TextStyle(fontWeight: FontWeight.w700, color: DateUtils.isSameDay(dia, hoy()) ? Colors.white : P.texto),
    ),
  );
}

class _SemanaCalendario extends StatefulWidget {
  final DateTime desde;
  final Map<DateTime, List<VisitaCalendario>> visitas;
  final ValueChanged<DateTime> onDia;
  final ValueChanged<String> onDetalle;
  const _SemanaCalendario({
    super.key,
    required this.desde,
    required this.visitas,
    required this.onDia,
    required this.onDetalle,
  });
  @override
  State<_SemanaCalendario> createState() => _SemanaCalendarioState();
}

class _SemanaCalendarioState extends State<_SemanaCalendario> {
  static const hora = 72.0, margen = 54.0;
  final vertical = ScrollController(initialScrollOffset: 7.5 * hora);
  final horizontal = ScrollController();
  @override
  void dispose() {
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final ancho = max(box.maxWidth, margen + 7 * 40);
      final columna = (ancho - margen) / 7;
      final dias = [for (var i = 0; i < 7; i++) masDias(widget.desde, i)];
      final grupos = [for (final d in dias) distribuirVisitas(widget.visitas[d] ?? [], minimoMin: 24)];
      // Las órdenes sin hora no caben en la rejilla: van en una franja bajo los días (hasta 3 por día).
      final sinHora = [
        for (final d in dias)
          [
            for (final v in widget.visitas[d] ?? <VisitaCalendario>[])
              if (v.inicio == null) v,
          ],
      ];
      final filasSinHora = sinHora.fold(0, (m, l) => max(m, l.length)).clamp(0, 3);
      return Scrollbar(
        controller: horizontal,
        thumbVisibility: ancho > box.maxWidth,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const SizedBox(width: margen),
                      for (final d in dias)
                        Expanded(
                          child: InkWell(
                            onTap: () => widget.onDia(d),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    diasSemana[d.weekday - 1].substring(0, 3).toUpperCase(),
                                    style: TextStyle(fontSize: 11, color: P.textoSuave),
                                  ),
                                  const SizedBox(width: 5),
                                  _NumeroDia(d),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (filasSinHora > 0)
                  Container(
                    height: filasSinHora * 27.0 + 6,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: P.borde)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: margen,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6, top: 8),
                            child: Text('Sin hora', style: TextStyle(fontSize: 11, color: P.textoSuave)),
                          ),
                        ),
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
                              child: Column(
                                children: [
                                  for (final (j, v) in sinHora[i].indexed)
                                    if (j < 3)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: SizedBox(
                                          height: 24,
                                          child: j == 2 && sinHora[i].length > 3
                                              ? InkWell(
                                                  onTap: () => widget.onDia(dias[i]),
                                                  child: Center(
                                                    child: Text(
                                                      '+${sinHora[i].length - 2} más',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: P.moradoOscuro,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : _EventoCalendario(v, compacto: true, onDetalle: widget.onDetalle),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: vertical,
                    child: SingleChildScrollView(
                      controller: vertical,
                      child: SizedBox(
                        height: hora * 24,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RejillaCalendario(
                                  horizontal: false,
                                  unidad: hora,
                                  margen: margen,
                                  divisiones: 7,
                                  actual: dias.indexWhere((d) => DateUtils.isSameDay(d, hoy())),
                                ),
                              ),
                            ),
                            for (var h = 0; h < 24; h++)
                              Positioned(
                                top: h * hora + 5,
                                left: 6,
                                width: 42,
                                child: Text(
                                  '${h.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(fontSize: 11, color: P.textoSuave),
                                ),
                              ),
                            for (var i = 0; i < 7; i++)
                              Positioned(
                                left: margen + i * columna,
                                top: 0,
                                bottom: 0,
                                width: columna,
                                // Soltar una orden de «Sin fecha» le pone este día y la hora donde cae.
                                child: Builder(
                                  builder: (columnaCtx) => DragTarget<Tarea>(
                                    onAcceptWithDetails: (e) {
                                      final y = (columnaCtx.findRenderObject() as RenderBox).globalToLocal(e.offset).dy;
                                      _ponerFecha(
                                        e.data,
                                        dias[i],
                                        inicioMin: ((y / hora * 60) ~/ 15 * 15).clamp(0, 1425),
                                      );
                                    },
                                    builder: (context, candidatos, _) => GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapUp: (e) => abrirTareaForm(
                                        context,
                                        null,
                                        fecha: dias[i],
                                        horaMin: ((e.localPosition.dy / hora * 60) ~/ 15 * 15).clamp(0, 1425),
                                      ),
                                      child: ColoredBox(
                                        color: candidatos.isEmpty
                                            ? Colors.transparent
                                            : P.moradoSuave.withValues(alpha: .5),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (var i = 0; i < 7; i++)
                              for (final g in grupos[i]) ..._bloques(g, dias[i], margen + i * columna, columna),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  List<Widget> _bloques(GrupoCalendario g, DateTime d, double x, double ancho) {
    final maximo = max(1, (ancho / 105).floor());
    final exceso = g.carriles > maximo;
    final visibles = exceso ? maximo - 1 : g.carriles;
    final columnas = exceso ? maximo : g.carriles;
    final w = ancho / columnas;
    final ocultas = g.posiciones.where((p) => p.$2 >= visibles).length;
    return [
      for (final (v, carril) in g.posiciones)
        if (carril < visibles)
          Positioned(
            left: x + carril * w + 3,
            top: v.inicio! / 60 * hora + 1,
            width: w - 6,
            height: min(1440 - v.inicio!, max(24, v.fin! - v.inicio!)) / 60 * hora - 2,
            child: _EventoCalendario(v, onDetalle: widget.onDetalle),
          ),
      if (exceso)
        Positioned(
          left: x + visibles * w + 3,
          top: g.inicio / 60 * hora + 1,
          width: w - 6,
          height: max(40, (g.fin - g.inicio) / 60 * hora - 2),
          child: Material(
            color: P.moradoSuave,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onDia(d),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m('$ocultas trabajos →'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: P.moradoOscuro),
                    ),
                    if ((g.fin - g.inicio) >= 70)
                      Text('Ver día →', style: TextStyle(fontSize: 11, color: P.moradoOscuro)),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// Día por trabajador y carriles: nunca se estrechan los trabajos simultáneos.
class _DiaCalendario extends StatefulWidget {
  final DateTime dia;
  final List<VisitaCalendario> visitas;
  final ValueChanged<String> onDetalle;
  const _DiaCalendario({super.key, required this.dia, required this.visitas, required this.onDetalle});
  @override
  State<_DiaCalendario> createState() => _DiaCalendarioState();
}

class _DiaCalendarioState extends State<_DiaCalendario> {
  static const hora = 130.0;
  final horizontal = ScrollController(initialScrollOffset: 7.5 * hora);
  final vertical = ScrollController();
  List<({String nombre, String? id, List<VisitaCalendario> visitas, bool sinHora})> filas = [];
  @override
  void initState() {
    super.initState();
    _filas();
  }

  @override
  void didUpdateWidget(_DiaCalendario old) {
    super.didUpdateWidget(old);
    _filas();
  }

  void _filas() {
    filas = [];
    final equipos = <String, List<VisitaCalendario>>{'': []};
    for (final w in store.trabajadores.where((w) => w.activo)) {
      equipos[w.id] = [];
    }
    for (final v in widget.visitas) {
      final ids = v.tarea.trabajadorIds.where((id) => store.trabajador(id) != null).toList();
      for (final id in ids.isEmpty ? [''] : ids) {
        (equipos[id] ??= []).add(v);
      }
    }
    for (final e in equipos.entries) {
      if (e.value.isEmpty) continue;
      final nombre = e.key.isEmpty ? 'Sin asignar' : store.trabajador(e.key)!.nombreCompleto;
      final sinHora = e.value.where((v) => v.inicio == null).toList();
      for (final v in sinHora) {
        filas.add((nombre: nombre, id: e.key.isEmpty ? null : e.key, visitas: [v], sinHora: true));
      }
      final grupos = distribuirVisitas(e.value, minimoMin: 30);
      final cantidad = grupos.fold(0, (n, g) => max(n, g.carriles));
      final carriles = List.generate(max(1, cantidad), (_) => <VisitaCalendario>[]);
      for (final g in grupos) {
        for (final (v, c) in g.posiciones) {
          carriles[c].add(v);
        }
      }
      for (final carril in carriles) {
        if (carril.isNotEmpty) {
          filas.add((nombre: nombre, id: e.key.isEmpty ? null : e.key, visitas: carril, sinHora: false));
        }
      }
    }
    if (filas.isEmpty) {
      filas.add((nombre: '', id: null, visitas: [], sinHora: false));
    }
  }

  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final escala = MediaQuery.textScalerOf(context).scale(1);
      final alto = 76.0 * escala;
      return Scrollbar(
        controller: horizontal,
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: max(box.maxWidth, 24 * hora),
            height: box.maxHeight,
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      for (var h = 0; h < 24; h++)
                        SizedBox(
                          width: hora,
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: TextStyle(fontSize: 12, color: P.textoSuave),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: vertical,
                    child: ListView.builder(
                      controller: vertical,
                      itemExtent: alto,
                      itemCount: filas.length,
                      itemBuilder: (context, i) {
                        final f = filas[i];
                        return SizedBox(
                          width: 24 * hora,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _RejillaCalendario(
                                    horizontal: true,
                                    unidad: hora,
                                    actual: DateUtils.isSameDay(widget.dia, hoy()) ? 0 : -1,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapUp: (e) => abrirTareaForm(
                                    context,
                                    null,
                                    fecha: widget.dia,
                                    trabajadorId: f.id,
                                    horaMin: ((e.localPosition.dx / hora * 60) ~/ 15 * 15).clamp(0, 1425),
                                  ),
                                ),
                              ),
                              for (final v in f.visitas)
                                Positioned(
                                  left: f.sinHora ? 6 : v.inicio! / 60 * hora + 2,
                                  top: 7,
                                  height: alto - 14,
                                  // Sin hora: al principio de la fila y del ancho de lo que dura, no todo el día.
                                  width: f.sinHora
                                      ? max(hora * 1.5, v.tarea.duracionMin / 60 * hora - 4)
                                      : max(hora / 2 - 4, (v.fin! - v.inicio!) / 60 * hora - 4),
                                  child: _EventoCalendario(v, onDetalle: widget.onDetalle),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
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

class _RejillaCalendario extends CustomPainter {
  final bool horizontal;
  final double unidad, margen;
  final int divisiones, actual;
  final Color fondo = P.fondo, borde = P.borde, rojo = P.rojo;
  final DateTime ahora = DateTime.now();
  _RejillaCalendario({
    required this.horizontal,
    required this.unidad,
    this.margen = 0,
    this.divisiones = 1,
    this.actual = -1,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = fondo;
    if (horizontal) {
      canvas.drawRect(Rect.fromLTRB(0, 0, 8 * unidad, size.height), p);
      canvas.drawRect(Rect.fromLTRB(17 * unidad, 0, size.width, size.height), p);
      for (var h = 0; h <= 24; h++) {
        final x = h * unidad;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = borde);
      }
      canvas.drawLine(Offset.zero, Offset(size.width, 0), Paint()..color = borde);
      if (actual >= 0) {
        final x = (ahora.hour + ahora.minute / 60) * unidad;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = rojo
            ..strokeWidth = 1.5,
        );
      }
    } else {
      canvas.drawRect(Rect.fromLTWH(margen, 0, size.width - margen, 8 * unidad), p);
      canvas.drawRect(Rect.fromLTWH(margen, 17 * unidad, size.width - margen, 7 * unidad), p);
      for (var h = 0; h <= 48; h++) {
        canvas.drawLine(
          Offset(margen, h * unidad / 2),
          Offset(size.width, h * unidad / 2),
          Paint()..color = borde.withValues(alpha: h.isEven ? 1 : .45),
        );
      }
      final ancho = (size.width - margen) / divisiones;
      for (var i = 0; i <= divisiones; i++) {
        canvas.drawLine(Offset(margen + i * ancho, 0), Offset(margen + i * ancho, size.height), Paint()..color = borde);
      }
      if (actual >= 0) {
        final y = (ahora.hour + ahora.minute / 60) * unidad;
        canvas.drawLine(
          Offset(margen + actual * ancho, y),
          Offset(margen + (actual + 1) * ancho, y),
          Paint()
            ..color = rojo
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RejillaCalendario old) =>
      horizontal != old.horizontal ||
      unidad != old.unidad ||
      margen != old.margen ||
      divisiones != old.divisiones ||
      actual != old.actual ||
      fondo != old.fondo ||
      borde != old.borde ||
      ahora.minute != old.ahora.minute;
}

class _EventoCalendario extends StatefulWidget {
  final VisitaCalendario visita;
  final bool compacto;
  final ValueChanged<String> onDetalle;
  const _EventoCalendario(this.visita, {this.compacto = false, required this.onDetalle});
  @override
  State<_EventoCalendario> createState() => _EventoCalendarioState();
}

class _EventoCalendarioState extends State<_EventoCalendario> {
  final portal = OverlayPortalController();
  Timer? espera;
  bool fijo = false;
  bool _tecla(KeyEvent evento) {
    if (evento is KeyDownEvent && evento.logicalKey == LogicalKeyboardKey.escape && portal.isShowing) {
      _cerrar();
      return true;
    }
    return false;
  }

  void _abrir({bool fijar = false}) {
    espera?.cancel();
    fijo = fijar;
    HardwareKeyboard.instance.removeHandler(_tecla);
    HardwareKeyboard.instance.addHandler(_tecla);
    portal.show();
  }

  void _salir() {
    if (!fijo) {
      espera?.cancel();
      espera = Timer(const Duration(milliseconds: 240), _cerrar);
    }
  }

  void _cerrar() {
    espera?.cancel();
    fijo = false;
    HardwareKeyboard.instance.removeHandler(_tecla);
    portal.hide();
  }

  @override
  void dispose() {
    espera?.cancel();
    HardwareKeyboard.instance.removeHandler(_tecla);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visita, t = widget.visita.tarea;
    final color = t.colorBloque;
    final texto = '${v.inicio == null ? 'Sin hora' : hhmm(v.inicio!)} · ${t.nombre}';
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: (context) {
        final caja = this.context.findRenderObject()! as RenderBox;
        final punto = caja.localToGlobal(Offset.zero);
        final pantalla = MediaQuery.sizeOf(context);
        final ancho = min(410.0, pantalla.width - 24);
        final alto = min(500.0, pantalla.height - 24);
        final x =
            (punto.dx + caja.size.width + 8 + ancho <= pantalla.width
                    ? punto.dx + caja.size.width + 8
                    : punto.dx - ancho - 8)
                .clamp(12.0, max(12.0, pantalla.width - ancho - 12));
        final y = punto.dy.clamp(12.0, max(12.0, pantalla.height - alto - 12));
        return Stack(
          children: [
            if (fijo)
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _cerrar),
              ),
            Positioned(
              left: x.toDouble(),
              top: y.toDouble(),
              width: ancho,
              child: MouseRegion(
                onEnter: (_) => espera?.cancel(),
                onExit: (_) => _salir(),
                child: CallbackShortcuts(
                  bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cerrar},
                  child: Focus(
                    autofocus: fijo,
                    child: Material(
                      color: P.superficie,
                      elevation: 8,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(P.radio),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: alto),
                        child: SingleChildScrollView(
                          child: industrial
                              ? _resumenPultec(v, t, color)
                              : Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.tipo.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: P.moradoOscuro,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Cerrar resumen',
                                            onPressed: _cerrar,
                                            icon: const Icon(CupertinoIcons.xmark, size: 17),
                                          ),
                                        ],
                                      ),
                                      Text(t.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(
                                        v.hecha ? 'Completado' : 'Pendiente',
                                        style: TextStyle(color: v.hecha ? P.verde : P.textoSuave, fontSize: 12),
                                      ),
                                      const SizedBox(height: 14),
                                      _dato(Marca.iconoCliente, store.cliente(t.clienteId)?.nombre ?? m('Sin cliente')),
                                      _dato(
                                        Icons.schedule_rounded,
                                        '${fecha(v.dia)} · ${v.inicio == null ? 'Sin hora' : '${hhmm(v.inicio!)} – ${hhmm(v.fin!)}'} · ${t.duracionMin} min',
                                      ),
                                      _dato(Icons.place_outlined, t.ubicacion.isEmpty ? 'Sin ubicación' : t.ubicacion),
                                      _dato(
                                        Icons.people_outline,
                                        t.trabajadorIds.isEmpty
                                            ? 'Sin asignar'
                                            : t.trabajadorIds
                                                  .map(
                                                    (id) =>
                                                        store.trabajador(id)?.nombreCompleto ??
                                                        m('Trabajador no disponible'),
                                                  )
                                                  .join(', '),
                                      ),
                                      _dato(
                                        Icons.repeat_rounded,
                                        '${t.periodicidad.etiqueta} · ${t.criticidad.etiqueta}',
                                      ),
                                      if (t.notas.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text(t.notas, maxLines: 4, overflow: TextOverflow.ellipsis),
                                        ),
                                      const Divider(),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton(
                                            onPressed: () {
                                              _cerrar();
                                              widget.onDetalle(t.id);
                                            },
                                            child: const Text('Ver detalles'),
                                          ),
                                          OutlinedButton(
                                            onPressed: () {
                                              _cerrar();
                                              abrirTareaForm(this.context, t);
                                            },
                                            child: const Text('Editar'),
                                          ),
                                          if (!v.hecha && DateUtils.isSameDay(v.dia, hoy()))
                                            TextButton(
                                              onPressed: () {
                                                _cerrar();
                                                store.marcarHecha(t);
                                              },
                                              child: const Text('Completar'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: MouseRegion(
        onEnter: (_) {
          espera?.cancel();
          espera = Timer(const Duration(milliseconds: 350), _abrir);
        },
        onExit: (_) => _salir(),
        child: Semantics(
          button: true,
          label: '$texto. Abrir resumen',
          child: Material(
            color: Color.alphaBlend(color.withValues(alpha: .11), P.superficie),
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _abrir(fijar: true),
              hoverColor: color.withValues(alpha: .15),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color, width: 3)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: widget.compacto ? 1 : 4),
                child: LayoutBuilder(
                  builder: (context, box) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.compacto ? texto : t.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.1,
                          fontSize: widget.compacto ? 11 : 12,
                          color: P.texto,
                          fontWeight: FontWeight.w600,
                          decoration: v.hecha ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (!widget.compacto && box.maxHeight >= 35 * MediaQuery.textScalerOf(context).scale(1))
                        Text(
                          v.inicio == null ? 'Sin hora' : '${hhmm(v.inicio!)} – ${hhmm(v.fin!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: P.textoSuave),
                        ),
                      if (!widget.compacto && box.maxHeight >= 55 * MediaQuery.textScalerOf(context).scale(1))
                        Text(
                          store.cliente(t.clienteId)?.nombre ?? m('Sin cliente'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: P.textoSuave),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pultec: resumen de la orden con su activo, su criticidad y su mantenimiento, compacto y en color.
  Widget _resumenPultec(VisitaCalendario v, Tarea t, Color color) {
    var a = store.activo(t.activoId);
    final componente = a;
    while (a?.padreId != null && store.activo(a!.padreId!) != null) {
      a = store.activo(a.padreId!);
    }
    final plan = t.planId == null ? null : store.planes.where((p) => p.id == t.planId).firstOrNull;
    // Al tocar algo del resumen (menús, reloj) se queda abierto aunque el ratón salga hacia el menú.
    return Listener(
      onPointerDown: (_) => fijo = true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: a == null
                      ? Icon(Icons.assignment_outlined, size: 28, color: color)
                      : IconoActivo(a.icono, size: 28, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a?.titulo ?? 'Sin activo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                      ),
                      const SizedBox(height: 2),
                      Text(t.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar resumen',
                  visualDensity: VisualDensity.compact,
                  onPressed: _cerrar,
                  icon: const Icon(CupertinoIcons.xmark, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (t.tipoMantenimiento != null) PillTipo(t.tipoMantenimiento!),
                  Pill(v.hecha ? 'Completada' : 'Pendiente', v.hecha ? P.verde : P.textoSuave, punto: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (componente != null && componente.id != a?.id) _dato(Icons.account_tree_outlined, componente.titulo),
            if (plan != null) _datoPlan(plan),
            _datoHora(v, t),
            // Técnico, asignable desde aquí.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 17, color: P.textoSuave),
                  const SizedBox(width: 6),
                  Flexible(child: SelectorTrabajadores(t, () => store.guardarTarea(t), compacto: true)),
                ],
              ),
            ),
            if (t.notas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, right: 8),
                child: Text(
                  t.notas,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                ),
              ),
            Divider(height: 1, color: P.borde),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Lo demás, en la propia orden.
                  FilledButton(
                    onPressed: () {
                      _cerrar();
                      widget.onDetalle(t.id);
                    },
                    child: const Text('Editar'),
                  ),
                  if (!v.hecha && DateUtils.isSameDay(v.dia, hoy()))
                    TextButton(
                      onPressed: () {
                        _cerrar();
                        store.marcarHecha(t);
                      },
                      child: const Text('Completar'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Botón pequeño morado de lo que se cambia desde el resumen (hora, duración, periodicidad).
  Widget _chip(String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: P.moradoSuave, borderRadius: BorderRadius.circular(6)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texto,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.moradoOscuro),
        ),
        const SizedBox(width: 2),
        Icon(Icons.unfold_more_rounded, size: 14, color: P.moradoOscuro),
      ],
    ),
  );

  /// Mantenimiento y, si va por días, cada cuánto (se cambia aquí).
  Widget _datoPlan(PlanMantenimiento plan) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(Icons.content_paste_rounded, size: 17, color: P.textoSuave),
        const SizedBox(width: 10),
        Flexible(
          child: Text(plan.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
        const Text(' · ', style: TextStyle(fontSize: 13)),
        if (plan.cadaHoras != null)
          Text(plan.cada, style: const TextStyle(fontSize: 13))
        else
          BotonMenu<int>(
            tooltip: 'Cada cuánto',
            seleccionado: plan.cadaDias,
            onSelected: (d) => store.guardarPlan(plan..cadaDias = d),
            opciones: [
              for (final d in const [7, 14, 30, 60, 90, 180, 365]) (d, Text('Cada $d días')),
            ],
            child: _chip(plan.cadaDias == null ? 'Sin periodicidad' : 'cada ${plan.cadaDias} días'),
          ),
      ],
    ),
  );

  /// Fecha y, pulsable, la hora: se cambia aquí mismo sin abrir la orden.
  Widget _datoHora(VisitaCalendario v, Tarea t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(Icons.schedule_rounded, size: 17, color: P.textoSuave),
        const SizedBox(width: 10),
        Text('${fecha(v.dia)} · ', style: const TextStyle(fontSize: 13)),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            fijo = true; // que no se cierre al salir el ratón hacia el reloj
            final actual = t.inicioMin ?? primerHueco(v.dia, t.duracionMin, sin: t.id) ?? 9 * 60;
            final h = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
            );
            if (h != null) store.guardarTarea(t.copia()..inicioMin = h.hour * 60 + h.minute);
          },
          child: _chip(v.inicio == null ? 'Poner hora' : '${hhmm(v.inicio!)} – ${hhmm(v.fin!)}'),
        ),
        const Text(' · ', style: TextStyle(fontSize: 13)),
        BotonMenu<int>(
          tooltip: 'Duración',
          seleccionado: t.duracionMin,
          onSelected: (m) => store.guardarTarea(t.copia()..duracionMin = m),
          opciones: [
            for (final m in const [15, 30, 45, 60, 90, 120, 180, 240, 480]) (m, Text(duracion(m))),
          ],
          child: _chip(duracion(t.duracionMin)),
        ),
      ],
    ),
  );

  Widget _dato(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 17, color: P.textoSuave),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
