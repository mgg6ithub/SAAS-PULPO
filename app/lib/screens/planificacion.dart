import 'dart:math';

import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../forms.dart';
import '../marca.dart';
import 'agenda_herramientas.dart';
import 'agenda_vistas.dart';
import 'calendario_trabajos.dart';
import 'rutas_mapa.dart';
import 'tarea_card.dart';
import 'vista_dias.dart';
import 'vista_pulpo.dart';

/// Agenda (antes Planificación), inspirada en el Schedule de Jobber:
/// Día (una fila por técnico), Semana (por horas), Mes y Tablero, con un mapa lateral opcional
/// que muestra los clientes con visitas en el periodo que estás viendo.
class Planificacion extends StatefulWidget {
  /// Mapa abierto al entrar (en los tests va cerrado: no hay red para las teselas).
  final bool mapa;
  const Planificacion({super.key, this.mapa = true});

  /// La próxima vez que se pinte, el itinerario enseña el día de [d] (lo usa la guía de Inicio).
  static void mostrarSemana(DateTime d) {
    _PlanificacionState._dia = d;
    _PlanificacionState._vista = 0;
  }

  @override
  State<Planificacion> createState() => _PlanificacionState();
}

class _PlanificacionState extends State<Planificacion> {
  final _marcoGuiaKey = GlobalKey();
  final _organizarGuiaKey = GlobalKey();
  bool _mostrarSinConcretar = true;

  /// Hueco del botón Organizar en la guía. En un ValueNotifier: al mover la barra lateral el botón se
  /// desplaza en cada fotograma y solo debe repintarse el velo, no toda la página.
  final _organizarRect = ValueNotifier<Rect?>(null);
  bool _medicionPendiente = false;

  // ?v=0..4 abre una vista concreta (útil para enlaces y capturas): 0 Día, 1 Semana, 2 Mes, 3 Tablero, 4 Línea.
  // Vista y día viven fuera del State: si la página se reconstruye (p. ej. al mover un bloque
  // y guardar), el itinerario sigue exactamente donde estaba.
  static int? _vista;
  static DateTime? _dia;
  int get vista => _vista ??= (int.tryParse(Uri.base.queryParameters['v'] ?? '') ?? (industrial ? 1 : ajustes.vistaInicio)).clamp(0, 1);
  set vista(int v) => _vista = v;
  DateTime get dia => _dia ??= hoy();
  set dia(DateTime d) => _dia = d;

  /// Mapa al lado del calendario: apagado al entrar al Itinerario; lo enciende su botón.
  late bool mapa = false;

  /// Ancho del mapa (se ajusta arrastrando el separador); null = el de por defecto. Va en un
  /// ValueNotifier: arrastrar solo maqueta de nuevo la fila del calendario y el mapa, no toda la página.
  final anchoMapa = ValueNotifier<double?>(null);

  /// El mapa ya se ha mostrado alguna vez: desde entonces se queda montado (solo se oculta).
  bool mapaVisto = false;
  @override
  void dispose() {
    anchoMapa.dispose();
    _organizarRect.dispose();
    super.dispose();
  }

  /// Panel lateral con los trabajos sin técnico.
  bool sinAsignar = false;
  ModoCalendario modoCalendario = ModoCalendario.semana;
  int get escala => vista == 0
      ? 0
      : switch (modoCalendario) {
          ModoCalendario.dia => 0,
          ModoCalendario.semana => 1,
          ModoCalendario.mes => 2,
        };

  DateTime get lunes => lunesDe(dia);

  bool get _guiaOrganizarVisible {
    return !ajustes.guiaOrganizar &&
        ajustes.guiaItinerario &&
        store.tareas.any((t) => !t.esPlantilla) &&
        store.trabajadores.any((w) => w.activo);
  }

  void _medirBotonOrganizar() {
    if (_medicionPendiente) return;
    _medicionPendiente = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _medicionPendiente = false;
      if (!mounted || !_guiaOrganizarVisible) return;
      final boton = _organizarGuiaKey.currentContext?.findRenderObject();
      final marco = _marcoGuiaKey.currentContext?.findRenderObject();
      if (boton is! RenderBox || marco is! RenderBox || !boton.hasSize || !marco.hasSize) return;
      final posicion = boton.localToGlobal(Offset.zero, ancestor: marco);
      final rect = posicion & boton.size;
      _organizarRect.value = rect;
    });
  }

  /// Periodo que se ve ahora (para el mapa y el título).
  (DateTime, DateTime, String) get periodo => switch (escala) {
    0 => (dia, dia, diasHasta(dia) == 0 ? 'hoy' : '${diasSemana[dia.weekday - 1].toLowerCase()} ${dia.day}'),
    1 => (lunes, masDias(lunes, 6), 'semana ${rangoSemana(lunes)}'),
    2 => (DateTime(dia.year, dia.month), DateTime(dia.year, dia.month + 1, 0), meses[dia.month - 1].toLowerCase()),
    3 => (hoy(), masDias(hoy(), 7), 'próximos 7 días'),
    _ => (masDias(hoy(), -1), masDias(hoy(), 2), 'de ayer a pasado mañana'),
  };

  String get titulo => switch (escala) {
    0 => '${diasSemana[dia.weekday - 1]} ${dia.day} de ${meses[dia.month - 1].toLowerCase()}',
    1 => 'Semana del ${rangoSemana(lunes)}',
    _ => '${meses[dia.month - 1]} ${dia.year}',
  };

  /// Del título más largo al más corto: se muestra el primero que cabe junto a los botones.
  List<String> get titulos {
    final mes = meses[dia.month - 1];
    final corto = mes.substring(0, 3).toLowerCase();
    return switch (escala) {
      0 => [titulo, '${dia.day} de ${mes.toLowerCase()}', '${dia.day} $corto', '${dia.day}'],
      1 => [titulo, rangoSemana(lunes), '${lunes.day} ${meses[lunes.month - 1].substring(0, 3).toLowerCase()}'],
      2 => [titulo, mes, corto],
      3 => ['Próximos 7 días', '7 días'],
      _ => ['De ayer a pasado mañana', '3 días'],
    };
  }

  void mover(int n) => setState(
    () => dia = switch (escala) {
      0 => masDias(dia, n),
      1 => masDias(dia, 7 * n),
      _ => DateTime(dia.year, dia.month + n, 1),
    },
  );

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: filtroAgenda, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final mostrarGuia = _guiaOrganizarVisible;
    final (desde, hasta, nombrePeriodo) = periodo;
    final contenido = switch (vista) {
      0 => VistaPulpo(
        dia: dia,
        mostrarSinConcretar: _mostrarSinConcretar,
        onCambiarVisibilidad: () => setState(() => _mostrarSinConcretar = !_mostrarSinConcretar),
        onCrearTrabajo: () async {
          final hora = diasHasta(dia) == 0 ? (TimeOfDay.now().hour + 1).clamp(7, 20) * 60 : 9 * 60;
          await abrirTareaForm(context, null, fecha: dia, horaMin: hora);
        },
      ),
      _ => CalendarioTrabajos(
        dia: dia,
        modo: modoCalendario,
        onModo: (m) => setState(() => modoCalendario = m),
        onDia: (d) => setState(() {
          dia = d;
          modoCalendario = ModoCalendario.dia;
        }),
      ),
    };
    final calendario = RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
        child: contenido,
      ),
    );
    final panel = RepaintBoundary(child: PanelSinAsignar(onCerrar: () => setState(() => sinAsignar = false)));
    final mapaVista = RepaintBoundary(
      child: MapaAgenda(key: ValueKey('mapa-$desde-$hasta'), desde: desde, hasta: hasta, periodo: nombrePeriodo),
    );
    // Más sitio para el calendario y el mapa: márgenes estrechos y una sola barra compacta.
    final pagina = Padding(
      padding: vista == 1 ? const EdgeInsets.fromLTRB(12, 12, 12, 0) : margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha y vistas a la izquierda; a la derecha del todo, todo con el mismo alto (40):
          // [Sin asignar] [+ Nueva tarea] [Organizar] [Mapa]. Técnico se filtra pulsando su fila en la vista Día.
          Builder(
            builder: (context) {
              final fecha = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...[
                    NavegadorFecha(
                      anterior: escala == 0
                          ? 'Día anterior'
                          : escala == 1
                          ? 'Semana anterior'
                          : 'Mes anterior',
                      siguiente: escala == 0
                          ? 'Día siguiente'
                          : escala == 1
                          ? 'Semana siguiente'
                          : 'Mes siguiente',
                      onAnterior: () => mover(-1),
                      onHoy: () => setState(() => dia = hoy()),
                      onSiguiente: () => mover(1),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Flexible(
                    child: TextoAjustable(
                      titulos,
                      estilo: TextStyle(
                        fontFamily: P.titulos,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
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
                opciones: const ['Plan', 'Calendario'],
                seleccion: vista,
                onChanged: (i) => setState(() => vista = i),
              );
              final acciones = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Sin asignar" solo aparece cuando hay algo sin técnico (o con su panel abierto).
                  if (vista == 1 && (sinAsignar || PanelSinAsignar.pendientes().isNotEmpty)) ...[
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
                  if (vista == 1)
                    BotonAccion(
                      m('Nuevo trabajo'),
                      icono: Icons.add_rounded,
                      tooltip: m('Crear un trabajo (N)'),
                      onPressed: () async {
                        final f = dia;
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
                    ),
                  if (vista == 1) const SizedBox(width: 8),
                  // El pulpo: organiza el día que estás viendo.
                  BotonPulpo(key: _organizarGuiaKey, dia: dia, onHecho: () => setState(() => mapa = Marca.mapa)),
                  // iPultec, sin rutas: sin mapa ni su botón.
                  if (Marca.mapa && vista == 1) ...[const SizedBox(width: 8), _BotonMapa(mapa, () => setState(() => mapa = !mapa))],
                ],
              );
              // Con menos de 900 los botones van solo con icono: así caben junto a la fecha sin solaparse.
              return BarraVista(
                izquierda: [fecha, vistas],
                derecha: const [],
                principal: acciones,
                principalCompactoBajo: 900,
              );
            },
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: LayoutBuilder(
              // Calendario y mapa se crean fuera (más arriba): al redimensionar o arrastrar el separador,
              // aquí solo se recoloca la fila con las mismas instancias, sin reconstruirlas.
              builder: (context, box) {
                final conMapa = vista == 1 && mapa && box.maxWidth > 760;
                final maxMapa = max(260.0, box.maxWidth - 360);
                // El mapa se monta la primera vez que se muestra y luego ya no se desmonta.
                if (conMapa) mapaVisto = true;
                // Ancho por defecto fijo: al mover la barra lateral solo cambia el calendario, no el mapa.
                double ancho(double? a) => (a ?? 420.0).clamp(260.0, maxMapa).toDouble();
                // Móvil: el panel «Sin asignar» se abre encima del calendario, a todo el ancho.
                if (esMovil(context)) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Con el mapa encendido, va debajo del calendario (apilado).
                      if (vista == 1 && mapa)
                        Column(
                          children: [
                            Expanded(child: calendario),
                            const SizedBox(height: huecoVista),
                            Padding(
                              padding: const EdgeInsets.only(right: 12, bottom: 12),
                              child: SizedBox(height: box.maxHeight * .45, child: mapaVista),
                            ),
                          ],
                        )
                      else
                        calendario,
                      if (sinAsignar) Padding(padding: const EdgeInsets.only(right: 12), child: panel),
                    ],
                  );
                }
                return ValueListenableBuilder<double?>(
                  valueListenable: anchoMapa,
                  builder: (context, a, _) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Panel "Sin asignar": entra deslizándose desde la izquierda.
                      ClipRect(
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.centerRight,
                          widthFactor: sinAsignar ? 1 : 0,
                          child: Padding(
                            padding: const EdgeInsets.only(right: huecoVista),
                            child: SizedBox(width: 290, child: panel),
                          ),
                        ),
                      ),
                      Expanded(child: calendario),
                      // El mapa se queda montado y se abre o cierra deslizándose: no se vuelve a crear
                      // ni a cargar las teselas cada vez.
                      if (mapaVisto)
                        ClipRect(
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerLeft,
                            widthFactor: conMapa ? 1 : 0,
                            child: TickerMode(
                              enabled: conMapa,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _Separador(
                                    onInicio: () => anchoMapa.value = ancho(a),
                                    onMover: (dx) => anchoMapa.value = (anchoMapa.value! - dx).clamp(260.0, maxMapa),
                                  ),
                                  SizedBox(width: ancho(a), child: mapaVista),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, _) {
        if (mostrarGuia) _medirBotonOrganizar();
        return Stack(
          key: _marcoGuiaKey,
          fit: StackFit.expand,
          children: [
            pagina,
            if (mostrarGuia)
              ValueListenableBuilder<Rect?>(
                valueListenable: _organizarRect,
                builder: (context, rect, _) => rect == null
                    ? const SizedBox.shrink()
                    : Positioned.fill(
                        child: IgnorePointer(
                          child: Semantics(
                            label: m('Pulsa Organizar para que Pulpo asigne el trabajo al técnico.'),
                            liveRegion: true,
                            child: CustomPaint(painter: _GuiaOrganizarPainter(rect)),
                          ),
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _GuiaOrganizarPainter extends CustomPainter {
  final Rect boton;
  const _GuiaOrganizarPainter(this.boton);

  @override
  void paint(Canvas canvas, Size size) {
    final limites = Offset.zero & size;
    final foco = boton.inflate(7);
    canvas.saveLayer(limites, Paint());
    canvas.drawRect(limites, Paint()..color = Colors.black.withValues(alpha: .48));
    canvas.drawRRect(RRect.fromRectAndRadius(foco, const Radius.circular(14)), Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(foco, const Radius.circular(14)),
      Paint()
        ..color = P.morado
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final texto = m('Pulsa Organizar para que Pulpo asigne el trabajo al técnico.');
    final letras = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: min(220, size.width - 32).toDouble());
    final burbuja = Rect.fromLTWH(
      (boton.left - letras.width - 40).clamp(12, size.width - letras.width - 36).toDouble(),
      (boton.bottom + 38).clamp(12, size.height - letras.height - 32).toDouble(),
      letras.width + 24,
      letras.height + 18,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(burbuja, const Radius.circular(12)), Paint()..color = P.morado);
    letras.paint(canvas, Offset(burbuja.left + 12, burbuja.top + 9));

    final inicio = Offset(burbuja.right - 8, burbuja.top + 2);
    final fin = Offset(boton.left + boton.width * .45, boton.bottom + 7);
    final control1 = Offset(inicio.dx + 42, inicio.dy - 66);
    final control2 = Offset(fin.dx + 48, fin.dy + 56);
    final flecha = Path()
      ..moveTo(inicio.dx, inicio.dy)
      ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, fin.dx, fin.dy);
    final pintura = Paint()
      ..color = P.morado
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(flecha, pintura);
    final angulo = atan2(fin.dy - control2.dy, fin.dx - control2.dx);
    final punta = Path()
      ..moveTo(fin.dx, fin.dy)
      ..lineTo(fin.dx - 11 * cos(angulo - .48), fin.dy - 11 * sin(angulo - .48))
      ..lineTo(fin.dx - 11 * cos(angulo + .48), fin.dy - 11 * sin(angulo + .48))
      ..close();
    canvas.drawPath(punta, Paint()..color = P.morado);
  }

  @override
  bool shouldRepaint(_GuiaOrganizarPainter old) => old.boton != boton;
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

// Vista anterior conservada para recuperarla cuando vuelvan a exponerse las variantes.
// ignore: unused_element
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
                  'Vencidos y próximos 7 días',
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
          ? m('Todo lo actual ya tiene trabajador')
          : m('Asignar el trabajador más adecuado a $pendientes ${pendientes == 1 ? 'trabajo' : 'trabajos'}'),
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
                          ? m('Todo lo actual ya tiene trabajador.')
                          : m('No hay trabajadores aptos para lo que falta.'))
                    : m('Pulpo ha asignado $n ${n == 1 ? 'trabajo' : 'trabajos'}.'),
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
        // Triángulo amarillo de aviso: hay trabajo sin técnico.
        const Icon(Icons.warning_amber_rounded, size: 18, color: P.ambar),
        // En móvil, solo el aviso y el número.
        if (!esMovil(context)) ...const [SizedBox(width: 6), Text('Sin asignar')],
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

/// Separador arrastrable entre calendario y mapa: raya fina que, al pasar el ratón o arrastrar,
/// se hace morada y ocupa todo el alto. Lleva su propio estado: el hover no repinta el itinerario.
class _Separador extends StatefulWidget {
  final VoidCallback onInicio;
  final ValueChanged<double> onMover;
  const _Separador({required this.onInicio, required this.onMover});

  @override
  State<_Separador> createState() => _SeparadorState();
}

class _SeparadorState extends State<_Separador> {
  bool encima = false, arrastrando = false;

  @override
  Widget build(BuildContext context) {
    final activo = encima || arrastrando;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => encima = true),
      onExit: (_) => setState(() => encima = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => arrastrando = true);
          widget.onInicio();
        },
        onHorizontalDragUpdate: (d) => widget.onMover(d.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => arrastrando = false),
        child: SizedBox(
          width: huecoVista,
          // Alto real (no infinito): animar hasta infinito rompe el layout.
          child: LayoutBuilder(
            builder: (context, caja) => Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: activo ? 4 : 2,
                height: activo ? caja.maxHeight : 40,
                decoration: BoxDecoration(color: activo ? P.morado : P.borde, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
