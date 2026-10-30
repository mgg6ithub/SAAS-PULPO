import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'agenda_herramientas.dart';
import '../marca.dart';

const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Calendario en horizontal: un bloque por día, hoy en el centro.
/// El pasado se ve apagado (historial); hoy y el futuro, destacados.
class VistaDias extends StatefulWidget {
  final DateTime? inicial;

  /// Margen lateral de la cabecera; los días llegan hasta el borde de la ventana.
  final double margen;
  const VistaDias({super.key, this.inicial, this.margen = 0});

  @override
  State<VistaDias> createState() => _VistaDiasState();
}

class _VistaDiasState extends State<VistaDias> {
  /// Semana: un bloque por semana con sus días plegables. Día: un bloque por día.
  bool porSemana = false;

  int get atras => porSemana ? 13 : 90;
  int get adelante => porSemana ? 57 : 400;

  /// Días: caben ~3,4 (3 enteros y un trozo de los vecinos). Semanas: ~2,4, más anchas.
  double get visibles => porSemana ? 2.4 : 3.4;
  double get anchoMinimo => porSemana ? 380 : 340;

  late int paginaDia = 90 + (widget.inicial == null ? 0 : diasHasta(widget.inicial!)).clamp(-90, 400);
  late int paginaSemana = 13 + (widget.inicial == null ? 0 : diasHasta(lunesDe(widget.inicial!)) ~/ 7).clamp(-13, 57);
  int get pagina => porSemana ? paginaSemana : paginaDia;
  set pagina(int i) {
    porSemana ? paginaSemana = i : paginaDia = i;
    titulo.value = i;
  }

  /// Solo el título (mes y año) depende de la página: cambiarla no reconstruye el carrusel.
  late final titulo = ValueNotifier(pagina);

  PageController? pc;
  double fraccion = 0;
  double rueda = 0;
  bool girando = false;

  DateTime diaDe(int i) => masDias(hoy(), i - atras);
  DateTime lunesDeLaPagina(int i) => masDias(lunesDe(hoy()), 7 * (i - atras));

  /// PageView necesita su fracción al crearse: si cambia el ancho o el modo, se rehace.
  PageController controlador(double f) {
    if (pc == null || (f - fraccion).abs() > .001) {
      final viejo = pc;
      pc = PageController(viewportFraction: f, initialPage: pagina);
      fraccion = f;
      if (viejo != null) WidgetsBinding.instance.addPostFrameCallback((_) => viejo.dispose());
    }
    return pc!;
  }

  void cambiarModo(bool semana) {
    if (semana == porSemana) return;
    setState(() {
      porSemana = semana;
      titulo.value = pagina;
      fraccion = 0; // fuerza un controlador nuevo en la página del otro modo
    });
  }

  Future<void> ir(int i) async => pc?.animateToPage(
    i.clamp(0, atras + adelante),
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );

  /// La rueda vertical del ratón también pasa días, de uno en uno.
  void alGirarRueda(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || e.scrollDelta.dx != 0) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) async {
      if (girando) return;
      rueda += e.scrollDelta.dy;
      if (rueda.abs() < 40) return;
      girando = true;
      final paso = rueda.sign.toInt();
      rueda = 0;
      await ir(pagina + paso);
      girando = false;
    });
  }

  @override
  void dispose() {
    titulo.dispose();
    pc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.margen),
          child: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: titulo,
                builder: (_, i, _) {
                  final dia = porSemana ? masDias(lunesDeLaPagina(i), 3) : diaDe(i);
                  return Text(
                    '${meses[dia.month - 1]} ${dia.year}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.3),
                  );
                },
              ),
              const Spacer(),
              Pestanas(
                opciones: const ['Semana', 'Día'],
                seleccion: porSemana ? 0 : 1,
                onChanged: (i) => cambiarModo(i == 0),
              ),
              const SizedBox(width: 8),
              NavegadorFecha(
                anterior: porSemana ? 'Semana anterior' : 'Día anterior',
                siguiente: porSemana ? 'Semana siguiente' : 'Día siguiente',
                onAnterior: () => ir(pagina - 1),
                onHoy: () => ir(atras),
                onSiguiente: () => ir(pagina + 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final f = min(1.0, max(1 / visibles, anchoMinimo / box.maxWidth));
              return Listener(
                onPointerSignal: alGirarRueda,
                child: PageView.builder(
                  key: ValueKey(porSemana),
                  controller: controlador(f),
                  itemCount: atras + adelante + 1,
                  onPageChanged: (i) => pagina = i,
                  // Cada bloque en su capa: al desplazar solo se mueven, no se repintan.
                  itemBuilder: (_, i) =>
                      RepaintBoundary(child: porSemana ? _Semana(lunesDeLaPagina(i)) : _Dia(diaDe(i))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

DateTime lunesDe(DateTime d) => masDias(DateUtils.dateOnly(d), -(d.weekday - 1));

String _mes(DateTime d) => meses[d.month - 1].substring(0, 3).toLowerCase();

String rangoSemana(DateTime lunes) {
  final dom = masDias(lunes, 6);
  return lunes.month == dom.month
      ? '${lunes.day}–${dom.day} ${_mes(dom)}'
      : '${lunes.day} ${_mes(lunes)} – ${dom.day} ${_mes(dom)}';
}

/// Clientes con tareas ese día, ordenados, cada uno con las suyas.
List<(Cliente, List<Tarea>)> clientesDelDia(DateTime dia) {
  final porCliente = <String, List<Tarea>>{};
  for (final t in store.tareasDelDia(dia).where((t) => filtroAgenda.pasa(t, dia))) {
    porCliente.putIfAbsent(t.clienteId ?? '', () => []).add(t);
  }
  return [
    for (final id in porCliente.keys)
      if (id.isEmpty)
        (Cliente(id: '', nombre: m('Sin cliente'), color: 7), porCliente[id]!)
      else if (store.cliente(id) case final c?)
        (c, porCliente[id]!),
  ]..sort((a, b) => a.$1.nombre.compareTo(b.$1.nombre));
}

/// Abre un día o una semana a pantalla completa, para verlo con detalle.
void abrirDetalle(BuildContext context, DateTime inicio, {bool semana = false}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Detalle(inicio, semana: semana)));

/// Bloque del carrusel (un día o una semana) con su punto en la línea de tiempo.
class _Bloque extends StatelessWidget {
  final bool destacado, pasado;
  final String titulo, subtitulo;
  final VoidCallback onTap;
  final Widget child;
  const _Bloque({
    required this.destacado,
    required this.pasado,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = destacado ? P.morado : (pasado ? const Color(0xFFB9B9C6) : P.morado.withValues(alpha: .5));
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Opacity(
              opacity: pasado ? .6 : 1,
              child: Material(
                color: pasado ? P.columna : (destacado ? P.moradoSuave.withValues(alpha: .5) : P.superficie),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: destacado ? P.morado.withValues(alpha: .5) : P.borde,
                    width: destacado ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (destacado)
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [P.morado, Color.lerp(P.morado, P.azul, .5)!]),
                          ),
                        ),
                      Expanded(
                        child: Padding(padding: const EdgeInsets.all(10), child: child),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Línea de tiempo: una raya neutra continua que pasa por debajo de los puntos.
        SizedBox(
          width: double.infinity,
          height: 80,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(left: 0, right: 0, top: 21, child: Container(height: 2, color: P.borde)),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: P.fondo, // tapa la raya: el punto queda encima
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
                        color: destacado ? P.morado : (pasado ? P.textoSuave : P.texto),
                      ),
                    ),
                    Text(subtitulo, style: TextStyle(fontSize: 11, color: P.textoSuave)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dia extends StatelessWidget {
  final DateTime dia;
  const _Dia(this.dia);

  @override
  Widget build(BuildContext context) {
    final n = diasHasta(dia);
    final pasado = n < 0;
    final clientes = clientesDelDia(dia);
    return _Bloque(
      destacado: n == 0,
      pasado: pasado,
      titulo: '${diasSemana[dia.weekday - 1]} ${dia.day}',
      subtitulo: n == 0 ? 'Hoy' : (n == 1 ? 'Mañana' : (n == -1 ? 'Ayer' : '')),
      onTap: () => abrirDetalle(context, dia),
      child: clientes.isEmpty
          ? Vacio(
              icono: pasado ? Icons.history_rounded : Icons.event_available_rounded,
              texto: pasado ? 'Nada hecho este día' : 'Sin mantenimientos',
            )
          : ListView.separated(
              itemCount: clientes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _BloqueCliente(clientes[i].$1, clientes[i].$2, dia),
            ),
    );
  }
}

/// Una semana de lunes a domingo; cada día se pliega. Abiertos de inicio: lunes y martes
/// (para ver cómo empieza la semana), y además hoy y mañana.
class _Semana extends StatefulWidget {
  final DateTime lunes;
  const _Semana(this.lunes);

  @override
  State<_Semana> createState() => _SemanaState();
}

class _SemanaState extends State<_Semana> {
  late final abiertos = {
    for (var i = 0; i < 7; i++)
      if (i < 2 || [0, 1].contains(diasHasta(masDias(widget.lunes, i)))) i,
  };

  @override
  Widget build(BuildContext context) {
    final n = diasHasta(widget.lunes);
    final actual = n <= 0 && n > -7;
    return _Bloque(
      destacado: actual,
      pasado: n <= -7,
      titulo: rangoSemana(widget.lunes),
      subtitulo: actual ? 'Esta semana' : (n == 7 ? 'La próxima' : (n == -7 ? 'La pasada' : '')),
      onTap: () => abrirDetalle(context, widget.lunes, semana: true),
      child: ListView(
        children: [
          for (var i = 0; i < 7; i++) _diaPlegable(masDias(widget.lunes, i), i),
          Center(
            child: TextButton(
              onPressed: () => abrirDetalle(context, widget.lunes, semana: true),
              child: const Text('Ver todos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diaPlegable(DateTime dia, int i) {
    final abierto = abiertos.contains(i);
    final clientes = clientesDelDia(dia);
    final tareas = clientes.fold(0, (s, c) => s + c.$2.length);
    final esHoy = diasHasta(dia) == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => abierto ? abiertos.remove(i) : abiertos.add(i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: esHoy ? P.morado : P.superficie,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: esHoy ? P.morado : P.borde),
                  ),
                  child: Text(
                    '${diasSemana[dia.weekday - 1]} ${dia.day}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: esHoy ? Colors.white : P.texto),
                  ),
                ),
                const SizedBox(width: 8),
                if (tareas > 0) Pill('$tareas', P.gris),
                const Spacer(),
                AnimatedRotation(
                  turns: abierto ? .25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.chevron_right_rounded, size: 20, color: P.textoSuave),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: P.borde),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !abierto
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: clientes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Sin mantenimientos', style: TextStyle(fontSize: 12, color: P.textoSuave)),
                        )
                      : Column(
                          children: [
                            for (final (c, ts) in clientes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _BloqueCliente(c, ts, dia, compacto: true),
                              ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}

/// Un día o una semana a pantalla completa.
class _Detalle extends StatelessWidget {
  final DateTime inicio;
  final bool semana;
  const _Detalle(this.inicio, {this.semana = false});

  @override
  Widget build(BuildContext context) {
    final n = diasHasta(inicio);
    final titulo = semana
        ? 'Semana del ${rangoSemana(inicio)}'
        : '${diasSemana[inicio.weekday - 1]} ${inicio.day} de ${meses[inicio.month - 1].toLowerCase()}'
              '${n == 0 ? ' · Hoy' : (n == 1 ? ' · Mañana' : '')}';
    return Scaffold(
      backgroundColor: P.fondo,
      appBar: AppBar(
        backgroundColor: P.fondo,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: P.borde)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -.3)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => semana ? _columnasSemana() : _columnaDia(inicio, ancho: 720),
      ),
    );
  }

  Widget _columnaDia(DateTime dia, {double? ancho}) {
    final clientes = clientesDelDia(dia);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho ?? double.infinity),
        child: clientes.isEmpty
            ? const Vacio(icono: Icons.event_available_rounded, texto: 'Sin mantenimientos')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: clientes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _BloqueCliente(clientes[i].$1, clientes[i].$2, dia),
              ),
      ),
    );
  }

  /// Lunes a domingo en columnas; si no caben, se desplaza en horizontal.
  Widget _columnasSemana() => LayoutBuilder(
    builder: (context, box) {
      final w = max(260.0, box.maxWidth / 7);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 7; i++)
              SizedBox(
                width: w,
                height: box.maxHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${diasSemana[masDias(inicio, i).weekday - 1]} ${masDias(inicio, i).day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: diasHasta(masDias(inicio, i)) == 0 ? P.morado : P.texto,
                        ),
                      ),
                    ),
                    Expanded(child: _columnaDia(masDias(inicio, i))),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Un cliente dentro de un día, con el resumen de sus tareas.
class _BloqueCliente extends StatelessWidget {
  final Cliente cliente;
  final List<Tarea> tareas;
  final DateTime dia;

  /// Más pequeño, para que quepan los días de una semana.
  final bool compacto;
  const _BloqueCliente(this.cliente, this.tareas, this.dia, {this.compacto = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: compacto ? const EdgeInsets.fromLTRB(10, 8, 10, 2) : const EdgeInsets.fromLTRB(12, 10, 10, 4),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: P.borde),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Avatar(cliente.iniciales, colorPaleta(cliente.color), size: 24, cuadrado: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cliente.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            Text(
              '${tareas.length}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: P.textoSuave),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final t in tareas) _fila(context, t),
      ],
    ),
  );

  Widget _fila(BuildContext context, Tarea t) {
    final hecha = t.hechaEl(dia);
    final vencida = !hecha && t.proximo != null && diasHasta(t.proximo!) < 0;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => abrirFichaRapida(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            BarraTipo(t.tipo, alto: 24, color: t.colorBloque),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  decoration: hecha ? TextDecoration.lineThrough : null,
                  color: hecha ? P.textoSuave : P.texto,
                ),
              ),
            ),
            if (hecha)
              const Icon(Icons.check_circle_rounded, size: 18, color: P.verde)
            else ...[
              if (vencida) ...[const Pill('Vencido', P.rojo, punto: true), const SizedBox(width: 6)],
              if (t.horario != null && !vencida) ...[
                Text(hhmm(t.inicioMin!), style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                const SizedBox(width: 6),
              ],
              AvataresTrabajadores(t.trabajadorIds, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}
