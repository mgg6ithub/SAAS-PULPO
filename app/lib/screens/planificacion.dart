import 'dart:math';

import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../forms.dart';
import 'agenda_herramientas.dart';
import 'agenda_vistas.dart';
import 'rutas_mapa.dart';
import 'tarea_card.dart';
import 'vista_calendario.dart';
import 'vista_dias.dart';

/// Agenda (antes Planificación), inspirada en el Schedule de Jobber:
/// Día (una fila por técnico), Semana (por horas), Mes y Tablero, con un mapa lateral opcional
/// que muestra los clientes con visitas en el periodo que estás viendo.
class Planificacion extends StatefulWidget {
  /// Mapa abierto al entrar (en los tests va cerrado: no hay red para las teselas).
  final bool mapa;
  const Planificacion({super.key, this.mapa = true});

  @override
  State<Planificacion> createState() => _PlanificacionState();
}

class _PlanificacionState extends State<Planificacion> {
  // ?v=0..4 abre una vista concreta (útil para enlaces y capturas): 0 Día, 1 Semana, 2 Mes, 3 Tablero, 4 Línea.
  // Vista y día viven fuera del State: si la página se reconstruye (p. ej. al mover un bloque
  // y guardar), el itinerario sigue exactamente donde estaba.
  static int? _vista;
  static DateTime? _dia;
  int get vista => _vista ??= (int.tryParse(Uri.base.queryParameters['v'] ?? '') ?? ajustes.vistaInicio).clamp(0, 4);
  set vista(int v) => _vista = v;
  DateTime get dia => _dia ??= hoy();
  set dia(DateTime d) => _dia = d;
  late bool mapa = widget.mapa && Uri.base.queryParameters['mapa'] != '0';

  /// Ancho del mapa (se ajusta arrastrando el separador); null = el de por defecto.
  double? anchoMapa;
  bool sobreSeparador = false, arrastrando = false;

  /// Panel lateral con los trabajos sin técnico.
  bool sinAsignar = false;

  /// Se pueden ocultar los filtros y el grupo de vistas para dejar más sitio.
  bool verFiltros = true, verVistas = true;

  DateTime get lunes => lunesDe(dia);

  /// Periodo que se ve ahora (para el mapa y el título).
  (DateTime, DateTime, String) get periodo => switch (vista) {
    0 => (dia, dia, diasHasta(dia) == 0 ? 'hoy' : '${diasSemana[dia.weekday - 1].toLowerCase()} ${dia.day}'),
    1 => (lunes, masDias(lunes, 6), 'semana ${rangoSemana(lunes)}'),
    2 => (DateTime(dia.year, dia.month), DateTime(dia.year, dia.month + 1, 0), meses[dia.month - 1].toLowerCase()),
    3 => (hoy(), masDias(hoy(), 7), 'próximos 7 días'),
    _ => (masDias(hoy(), -1), masDias(hoy(), 2), 'de ayer a pasado mañana'),
  };

  String get titulo => switch (vista) {
    0 => '${diasSemana[dia.weekday - 1]} ${dia.day} de ${meses[dia.month - 1].toLowerCase()}',
    1 => 'Semana del ${rangoSemana(lunes)}',
    _ => '${meses[dia.month - 1]} ${dia.year}',
  };

  void mover(int n) => setState(
    () => dia = switch (vista) {
      0 => masDias(dia, n),
      1 => masDias(dia, 7 * n),
      _ => DateTime(dia.year, dia.month + n, 1),
    },
  );

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: filtroAgenda, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final semana = store.tareas
        .where((t) => !t.esPlantilla && t.activa && t.proximo != null && diasHasta(t.proximo!) <= 7)
        .length;
    final (desde, hasta, nombrePeriodo) = periodo;
    final contenido = switch (vista) {
      0 => VistaDiaTecnicos(dia, key: ValueKey('dia-$dia')),
      1 => VistaSemana(lunes, key: ValueKey('semana-$lunes')),
      2 => VistaCalendario(
        key: ValueKey('mes-${dia.year}-${dia.month}'),
        inicial: dia,
        conCabecera: false,
        onDia: (d) => setState(() {
          dia = d;
          vista = 0;
        }),
      ),
      3 => const _Tablero(),
      // La línea de días original: scroll horizontal día a día con la línea de tiempo abajo.
      _ => const VistaDias(key: ValueKey('linea')),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: título, y a su lado las acciones de crear (morado); a la derecha, las vistas.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Itinerario',
                          style: TextStyle(
                            fontFamily: P.titulos,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          ),
                        ),
                        Text(
                          '$semana mantenimientos en los próximos 7 días',
                          style: TextStyle(color: P.textoSuave, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _BotonGrande(Icons.add_rounded, 'Nueva tarea', () async {
                    final f = vista < 3 ? dia : hoy();
                    // Con hora, para que se vea como bloque: la próxima hora en punto si es hoy; si no, a las 9.
                    final h = diasHasta(f) == 0 ? (TimeOfDay.now().hour + 1).clamp(7, 20) * 60 : 9 * 60;
                    await abrirTareaForm(context, null, fecha: f, horaMin: h);
                    // Si se ha creado para otro día, el itinerario salta a ese día para verla aparecer.
                    final t = store.tareas.where((x) => store.esRecien(x.id)).firstOrNull;
                    if (t?.proximo != null && mounted) {
                      final (d, h, _) = periodo;
                      if (t!.proximo!.isBefore(d) || t.proximo!.isAfter(h)) setState(() => dia = t.proximo!);
                    }
                  }, principal: true),
                ],
              ),
              // El pulpo, en el centro: planifica el día que estás viendo.
              BotonPulpo(dia: vista < 3 ? dia : hoy(), onHecho: () => setState(() => mapa = true)),
              Wrap(
                spacing: 6,
                children: [
                  _Conmutador('Filtros', verFiltros, () => setState(() => verFiltros = !verFiltros)),
                  _Conmutador('Vistas', verVistas, () => setState(() => verVistas = !verVistas)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Filtros a la izquierda; vistas, mapa y "Sin asignar" a la derecha (ocultables).
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, box) {
                final derecha = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pestanas(
                      opciones: const ['Día', 'Semana', 'Mes', 'Tablero', 'Línea'],
                      seleccion: vista,
                      onChanged: (i) => setState(() => vista = i),
                    ),
                    _BotonMapa(mapa, () => setState(() => mapa = !mapa)),
                    _BotonSinAsignar(
                      sinAsignar,
                      PanelSinAsignar.pendientes().length,
                      () => setState(() => sinAsignar = !sinAsignar),
                    ),
                  ],
                );
                // Ancho de sobra: filtros a la izquierda y vistas a la derecha en la misma fila.
                // Si no cabe, las vistas van arriba (a la derecha) y los filtros debajo.
                if (!verFiltros && !verVistas) return const SizedBox(width: double.infinity);
                if (!verFiltros) return Align(alignment: Alignment.centerRight, child: derecha);
                if (!verVistas) return const BarraFiltrosAgenda();
                if (box.maxWidth > 1400) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: BarraFiltrosAgenda()),
                      const SizedBox(width: 12),
                      derecha,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerRight, child: derecha),
                    const SizedBox(height: 10),
                    const BarraFiltrosAgenda(),
                  ],
                );
              },
            ),
          ),
          if (vista < 3) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: P.titulos,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                const Spacer(),
                if (vista == 1 || vista == 2) ...[
                  _Zoom(
                    onMenos: () => vista == 1
                        ? zoomSemana(1 / 1.25)
                        : altoFilaMes.value = (altoFilaMes.value ?? 110) / 1.25 < 110
                              ? null
                              : (altoFilaMes.value ?? 110) / 1.25,
                    onMas: () => vista == 1
                        ? zoomSemana(1.25)
                        : altoFilaMes.value = ((altoFilaMes.value ?? 110) * 1.25).clamp(110, 600),
                  ),
                  const SizedBox(width: 8),
                ],
                NavegadorFecha(
                  anterior: const ['Día anterior', 'Semana anterior', 'Mes anterior'][vista],
                  siguiente: const ['Día siguiente', 'Semana siguiente', 'Mes siguiente'][vista],
                  onAnterior: () => mover(-1),
                  onHoy: () => setState(() => dia = hoy()),
                  onSiguiente: () => mover(1),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final conMapa = mapa && box.maxWidth > 760;
                final maxMapa = box.maxWidth - 360;
                final ancho = (anchoMapa ?? (box.maxWidth * .36).clamp(300, 520)).clamp(260.0, maxMapa).toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sinAsignar) ...[
                      SizedBox(width: 260, child: PanelSinAsignar(onCerrar: () => setState(() => sinAsignar = false))),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        layoutBuilder: (actual, anteriores) =>
                            Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
                        child: contenido,
                      ),
                    ),
                    if (conMapa) ...[
                      // Separador arrastrable: flechas ↔ al pasar el ratón.
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        onEnter: (_) => setState(() => sobreSeparador = true),
                        onExit: (_) => setState(() => sobreSeparador = false),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) => setState(() {
                            arrastrando = true;
                            anchoMapa = ancho;
                          }),
                          onHorizontalDragUpdate: (d) =>
                              setState(() => anchoMapa = (anchoMapa! - d.delta.dx).clamp(260.0, maxMapa)),
                          onHorizontalDragEnd: (_) => setState(() => arrastrando = false),
                          child: SizedBox(
                            width: 14,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: sobreSeparador || arrastrando ? 4 : 2,
                                height: sobreSeparador || arrastrando ? double.infinity : 40,
                                decoration: BoxDecoration(
                                  color: sobreSeparador || arrastrando ? P.morado : P.borde,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: MapaAgenda(
                          key: ValueKey('mapa-$desde-$hasta'),
                          desde: desde,
                          hasta: hasta,
                          periodo: nombrePeriodo,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono de mapa: lo muestra u oculta (relleno en morado cuando está visible).
class _BotonMapa extends StatelessWidget {
  final bool activo;
  final VoidCallback onTap;
  const _BotonMapa(this.activo, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: activo ? 'Ocultar mapa' : 'Mostrar mapa',
    child: IconButton(
      style: IconButton.styleFrom(
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        backgroundColor: activo ? P.morado : P.superficie,
        side: BorderSide(color: activo ? P.morado : P.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(
        activo ? Icons.map_rounded : Icons.map_outlined,
        size: 18,
        color: activo ? Colors.white : P.textoSuave,
      ),
    ),
  );
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

/// Botón "Sin asignar · N": abre el panel con los trabajos sin técnico.
class _BotonSinAsignar extends StatelessWidget {
  final bool activo;
  final int n;
  final VoidCallback onTap;
  const _BotonSinAsignar(this.activo, this.n, this.onTap);

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      backgroundColor: activo ? P.moradoSuave : null,
      side: BorderSide(color: activo ? P.morado.withValues(alpha: .5) : P.borde),
    ),
    onPressed: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Sin asignar'),
        if (n > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: P.ambar, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '$n',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Botón morado del itinerario: icono + texto, compacto.
class _BotonGrande extends StatefulWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  final bool principal;
  const _BotonGrande(this.icono, this.titulo, this.onTap, {this.principal = false});

  @override
  State<_BotonGrande> createState() => _BotonGrandeState();
}

class _BotonGrandeState extends State<_BotonGrande> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.principal ? P.morado : Color.lerp(P.morado, Colors.white, .12)!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          transform: Matrix4.translationValues(0, hover ? -1.5 : 0, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, Color.lerp(base, const Color(0xFF3B0764), .35)!],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: P.morado.withValues(alpha: hover ? .38 : .2),
                blurRadius: hover ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icono, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.titulo,
                style: TextStyle(fontFamily: P.titulos, color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interruptor de texto con flecha: muestra u oculta una zona del itinerario.
class _Conmutador extends StatelessWidget {
  final String texto;
  final bool visible;
  final VoidCallback onTap;
  const _Conmutador(this.texto, this.visible, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: visible ? 'Ocultar ${texto.toLowerCase()}' : 'Mostrar ${texto.toLowerCase()}',
    child: TextButton(
      style: TextButton.styleFrom(
        foregroundColor: visible ? P.texto : P.textoSuave,
        backgroundColor: visible ? P.hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texto),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: visible ? .5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded, size: 18),
          ),
        ],
      ),
    ),
  );
}

/// Zoom − / + del calendario (también con Ctrl + rueda o Ctrl + / Ctrl −).
class _Zoom extends StatelessWidget {
  final VoidCallback onMenos, onMas;
  const _Zoom({required this.onMenos, required this.onMas});

  Widget _b(String t, String tip, VoidCallback f) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: f,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            t,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: P.textoSuave),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: P.borde),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _b('−', 'Alejar (Ctrl + rueda)', onMenos),
        VerticalDivider(width: 1, color: P.borde),
        _b('+', 'Acercar (Ctrl + rueda)', onMas),
      ],
    ),
  );
}
