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
    // Más alto para el calendario y el mapa: menos margen arriba y abajo, y una sola barra compacta.
    return Padding(
      padding: margenPagina.copyWith(top: 18, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha y vistas a la izquierda; a la derecha del todo, todo con el mismo alto (40):
          // [Sin asignar] [+ Nueva tarea] [Organizar] [Mapa]. Técnico se filtra pulsando su fila en la vista Día.
          LayoutBuilder(
            builder: (context, box) {
              final fecha = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vista < 3) ...[
                    NavegadorFecha(
                      anterior: const ['Día anterior', 'Semana anterior', 'Mes anterior'][vista],
                      siguiente: const ['Día siguiente', 'Semana siguiente', 'Mes siguiente'][vista],
                      onAnterior: () => mover(-1),
                      onHoy: () => setState(() => dia = hoy()),
                      onSiguiente: () => mover(1),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Text(
                    vista < 3 ? titulo : (vista == 3 ? 'Próximos 7 días' : 'De ayer a pasado mañana'),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  if (filtroAgenda.activo) ...[
                    const SizedBox(width: 12),
                    InputChip(
                      label: const Text('Filtrado'),
                      onDeleted: filtroAgenda.limpiar,
                      deleteButtonTooltipMessage: 'Quitar filtro',
                      backgroundColor: P.moradoSuave,
                      side: BorderSide.none,
                      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.moradoOscuro),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    ),
                  ],
                ],
              );
              final vistas = Pestanas(
                opciones: const ['Día', 'Semana', 'Mes', 'Tablero', 'Línea'],
                seleccion: vista,
                onChanged: (i) => setState(() => vista = i),
              );
              final acciones = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Sin asignar" solo aparece cuando hay algo sin técnico (o con su panel abierto).
                  if (sinAsignar || PanelSinAsignar.pendientes().isNotEmpty) ...[
                    SizedBox(
                      height: 40,
                      child: _BotonSinAsignar(
                        sinAsignar,
                        PanelSinAsignar.pendientes().length,
                        () => setState(() => sinAsignar = !sinAsignar),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.fromLTRB(12, 0, 16, 0)),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      onPressed: () async {
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
                      },
                      label: const Text('Nueva tarea'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // El pulpo: organiza el día que estás viendo.
                  BotonPulpo(dia: vista < 3 ? dia : hoy(), onHecho: () => setState(() => mapa = true)),
                  const SizedBox(width: 8),
                  _BotonMapa(mapa, () => setState(() => mapa = !mapa)),
                ],
              );
              // Siempre una sola fila: ocupa todo el ancho (el hueco empuja los botones a la derecha)
              // y, si en una pantalla estrecha no cabe, se desplaza en horizontal en vez de partirse.
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: IntrinsicWidth(
                    child: Row(
                      children: [
                        fecha,
                        const SizedBox(width: 16),
                        vistas,
                        const Spacer(),
                        const SizedBox(width: 16),
                        acciones,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final conMapa = mapa && box.maxWidth > 760;
                final maxMapa = box.maxWidth - 360;
                final ancho = (anchoMapa ?? (box.maxWidth * .4).clamp(300, 640)).clamp(260.0, maxMapa).toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sinAsignar) ...[
                      SizedBox(width: 290, child: PanelSinAsignar(onCerrar: () => setState(() => sinAsignar = false))),
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
                            // Alto real (no infinito): animar hasta infinito rompe el layout.
                            child: LayoutBuilder(
                              builder: (context, caja) => Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: sobreSeparador || arrastrando ? 4 : 2,
                                  height: sobreSeparador || arrastrando ? caja.maxHeight : 40,
                                  decoration: BoxDecoration(
                                    color: sobreSeparador || arrastrando ? P.morado : P.borde,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
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
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        backgroundColor: activo ? P.tinta : P.superficie,
        side: BorderSide(color: activo ? P.tinta : P.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
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
          decoration: BoxDecoration(color: P.morado, borderRadius: BorderRadius.circular(P.radioControl)),
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
    decoration: BoxDecoration(color: P.hover.withValues(alpha: .5), borderRadius: BorderRadius.circular(P.radio + 4)),
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
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: P.ambar.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
            child: Text(
              '$n',
              style: const TextStyle(color: P.ambar, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    ),
  );
}
