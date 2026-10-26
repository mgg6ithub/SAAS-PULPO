import 'dart:math';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../shell.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tarea_card.dart';

/// Inicio: saludo, cifras clave, lo pendiente, la carga del equipo y los próximos mantenimientos
/// como las tarjetas de la landing. Sin gráficas de relleno: solo lo que se mira cada mañana.
class Resumen extends StatelessWidget {
  final ValueChanged<Seccion> onIr;
  final ValueChanged<String> onTrabajador;
  const Resumen({super.key, required this.onIr, required this.onTrabajador});

  String get saludo {
    final h = DateTime.now().hour;
    return h < 14 ? 'Buenos días' : (h < 21 ? 'Buenas tardes' : 'Buenas noches');
  }

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final h = hoy();
    final activas = store.tareas.where((t) => !t.esPlantilla && t.activa).toList();
    final conFecha = activas.where((t) => t.proximo != null).toList();
    final vencidas = conFecha.where((t) => diasHasta(t.proximo!) < 0).toList();
    final hoyT = conFecha.where((t) => diasHasta(t.proximo!) == 0).toList();
    final semana = conFecha.where((t) => diasHasta(t.proximo!) >= 0 && diasHasta(t.proximo!) <= 7).toList();
    final hechas30 = activas.where((t) => t.ultimo != null && diasHasta(t.ultimo!) >= -30).length;
    final sinTrabajador = conFecha.where((t) => t.trabajadorIds.isEmpty && diasHasta(t.proximo!) <= 7).toList();
    final guiaHecha =
        store.clientes.isNotEmpty && store.trabajadores.isNotEmpty && store.tareas.any((t) => !t.esPlantilla);

    // Solo se reconstruye al pasar de una a dos columnas; el resto del ancho lo resuelve la maquetación.
    return SegunTamano(
      clave: (box) => min(1080.0, box.maxWidth - margenPagina.horizontal) > 760,
      builder: (context, box) {
        final dosCol = min(1080.0, box.maxWidth - margenPagina.horizontal) > 760;
        Widget par(Widget a, Widget b) => dosCol
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 16),
                  Expanded(child: b),
                ],
              )
            : Column(children: [a, const SizedBox(height: 16), b]);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margenPagina.left, margenPagina.top, margenPagina.right, margenPagina.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(
                    saludo: saludo,
                    fecha: 'Hoy es ${_dias[h.weekday - 1]}, ${h.day} de ${_meses[h.month - 1]}',
                    hoy: hoyT.length,
                    vencidas: vencidas.length,
                    sinTrabajador: sinTrabajador,
                    onIr: onIr,
                  ),
                  const SizedBox(height: 16),
                  if (!guiaHecha) ...[const _PrimerosPasos(), const SizedBox(height: 16)],
                  _Kpis(
                    hoy: hoyT.length,
                    semana: semana.length,
                    vencidas: vencidas.length,
                    hechas: hechas30,
                    dosCol: dosCol,
                  ),
                  const SizedBox(height: 16),
                  par(
                    _Pendientes(vencidas: vencidas, sinTrabajador: sinTrabajador, onIr: onIr),
                    _CargaTrabajadores(onTrabajador: onTrabajador),
                  ),
                  const SizedBox(height: 32),
                  _Proximos(conFecha, onIr: onIr, columnas: dosCol ? 2 : 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Guía de primeros pasos (como la de Google Play Console): índice vertical con ticks que se marcan
/// solos según lo que ya existe. Solo el paso en curso lleva su acción; desaparece al completarla.
class _PrimerosPasos extends StatelessWidget {
  const _PrimerosPasos();

  @override
  Widget build(BuildContext context) {
    final pasos = [
      (
        'Crea tu primer cliente',
        'El edificio, colegio u hospital donde haces el mantenimiento.',
        store.clientes.isNotEmpty,
        'Nuevo cliente',
        () => abrirClienteForm(context),
      ),
      (
        'Crea un trabajo',
        'Un mantenimiento para ese cliente; Pulpo calcula cuándo toca.',
        store.tareas.any((t) => !t.esPlantilla),
        'Nuevo trabajo',
        () => abrirTareaForm(context, null, clienteId: store.clientes.firstOrNull?.id),
      ),
      (
        'Añade un trabajador',
        'Quién hace los mantenimientos; Pulpo le asignará los que pueda hacer.',
        store.trabajadores.isNotEmpty,
        'Nuevo trabajador',
        () => abrirTrabajadorForm(context),
      ),
    ];
    final hechos = pasos.where((p) => p.$3).length;
    final actual = pasos.indexWhere((p) => !p.$3);
    return Tarjeta(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Primeros pasos',
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.4,
                    ),
                  ),
                ),
                Text('$hechos de ${pasos.length}', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
              ],
            ),
            const SizedBox(height: 18),
            for (final (i, (titulo, detalle, hecho, accion, onTap)) in pasos.indexed)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Marca y, debajo, la línea que une con el siguiente paso.
                    SizedBox(
                      width: 22,
                      child: Column(
                        children: [
                          _MarcaPaso(hecho: hecho, actual: i == actual),
                          if (i < pasos.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: P.borde,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: i == actual ? FontWeight.w600 : FontWeight.w500,
                                color: hecho || i == actual ? P.texto : P.textoSuave,
                                decoration: hecho ? TextDecoration.lineThrough : null,
                                decorationColor: P.textoSuave,
                              ),
                              child: Text(titulo),
                            ),
                            if (i == actual) ...[
                              const SizedBox(height: 2),
                              Text(detalle, style: TextStyle(fontSize: 13, color: P.textoSuave)),
                              const SizedBox(height: 12),
                              BotonPrimario(accion, onPressed: onTap),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Marca de un paso: tick verde si está hecho, anillo morado si es el actual, anillo gris si falta.
class _MarcaPaso extends StatelessWidget {
  final bool hecho, actual;
  const _MarcaPaso({required this.hecho, required this.actual});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: hecho
          ? const Icon(Icons.check_rounded, key: ValueKey(1), size: 18, color: P.verde)
          : Container(
              key: ValueKey(actual),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: actual ? P.morado : P.borde, width: 2),
              ),
            ),
    ),
  );
}

/// "Acciones pendientes": lo que necesita atención, con su categoría a la derecha.
class _Pendientes extends StatelessWidget {
  final List<Tarea> vencidas, sinTrabajador;
  final ValueChanged<Seccion> onIr;
  const _Pendientes({required this.vencidas, required this.sinTrabajador, required this.onIr});

  @override
  Widget build(BuildContext context) {
    final sinTareas = store.clientes.where((c) => c.activa && store.tareasDe(c.id).isEmpty).length;
    final averiadas = store.tareas.where((t) => !t.esPlantilla && t.estadoMaquina != EstadoMaquina.operativa).length;
    final ausentes = store.trabajadores.where((w) => w.activo && w.estadoHoy == EstadoHoy.ausente).length;
    final filas = [
      if (vencidas.isNotEmpty)
        FilaLista(
          lider: _punto(P.rojo),
          titulo: '${vencidas.length} ${vencidas.length == 1 ? 'mantenimiento vencido' : 'mantenimientos vencidos'}',
          derecha: _cat('Itinerario'),
          onTap: () => onIr(Seccion.planificacion),
        ),
      if (sinTrabajador.isNotEmpty)
        FilaLista(
          lider: _punto(P.morado),
          titulo: '${sinTrabajador.length} sin trabajador esta semana',
          derecha: _cat('Tareas'),
          onTap: () => onIr(Seccion.tareas),
        ),
      if (averiadas > 0)
        FilaLista(
          lider: _punto(P.ambar),
          titulo: '$averiadas ${averiadas == 1 ? 'equipo' : 'equipos'} en revisión o averiados',
          derecha: _cat('Tareas'),
          onTap: () => onIr(Seccion.tareas),
        ),
      if (sinTareas > 0)
        FilaLista(
          lider: _punto(P.azul),
          titulo: '$sinTareas ${sinTareas == 1 ? 'cliente' : 'clientes'} sin mantenimientos',
          derecha: _cat('Clientes'),
          onTap: () => onIr(Seccion.clientes),
        ),
      if (ausentes > 0)
        FilaLista(
          lider: _punto(P.gris),
          titulo: '$ausentes ${ausentes == 1 ? 'trabajador ausente' : 'trabajadores ausentes'} hoy',
          derecha: _cat('Trabajadores'),
          onTap: () => onIr(Seccion.trabajadores),
        ),
    ];
    return SeccionTarjeta(
      alto: _alto,
      titulo: 'Acciones pendientes',
      accion: filas.isEmpty ? null : Pill('${filas.length}', P.rojo),
      children: filas.isEmpty
          ? [
              const SizedBox(
                height: 180,
                child: Vacio(icono: Icons.task_alt_rounded, texto: 'Nada pendiente. ¡Todo al día!'),
              ),
            ]
          : filas,
    );
  }

  Widget _cat(String t) => Text(t, style: TextStyle(fontSize: 12, color: P.textoSuave));
}

/// Barra horizontal fina con su valor, para listas tipo "Cuentas de gasto" de Holded.
Widget _barra(double v, Color color) => ClipRRect(
  borderRadius: BorderRadius.circular(3),
  child: TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: v),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 6, color: color, backgroundColor: P.hover),
  ),
);

class _CargaTrabajadores extends StatelessWidget {
  final ValueChanged<String> onTrabajador;
  const _CargaTrabajadores({required this.onTrabajador});

  @override
  Widget build(BuildContext context) {
    final ws = store.trabajadores.where((w) => w.activo).toList();
    int carga(Trabajador w) => store.tareas
        .where(
          (t) => !t.esPlantilla && t.trabajadorIds.contains(w.id) && t.proximo != null && diasHasta(t.proximo!) <= 7,
        )
        .length;
    ws.sort((a, b) => carga(b) - carga(a));
    final maximo = max(1, ws.isEmpty ? 1 : carga(ws.first));
    return SeccionTarjeta(
      alto: _alto,
      titulo: 'Carga del equipo',
      subtitulo: 'Tareas asignadas en los próximos 7 días',
      sinFilas: true,
      children: [
        if (ws.isEmpty)
          const SizedBox(
            height: 160,
            child: Vacio(icono: Icons.badge_outlined, texto: 'Aún no hay trabajadores'),
          )
        else
          for (final w in ws.take(6))
            InkWell(
              onTap: () => onTrabajador(w.id),
              hoverColor: P.hoverFila,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 26),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: w.estadoHoy.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: P.superficie, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: Text(
                        w.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(child: _barra(carga(w) / maximo, colorPaleta(w.color))),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${carga(w)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Próximos mantenimientos como los cuadraditos de la landing (lo vencido primero).
class _Proximos extends StatelessWidget {
  final List<Tarea> conFecha;
  final ValueChanged<Seccion> onIr;
  final int columnas;
  const _Proximos(this.conFecha, {required this.onIr, required this.columnas});

  @override
  Widget build(BuildContext context) {
    final lista = [...conFecha.where((t) => diasHasta(t.proximo!) <= 14)]
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));
    final ts = lista.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Próximos mantenimientos',
                style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
            ),
            Enlace('Ir al itinerario', onTap: () => onIr(Seccion.planificacion)),
          ],
        ),
        const SizedBox(height: 14),
        if (ts.isEmpty)
          const Tarjeta(
            child: SizedBox(
              height: 160,
              child: Vacio(icono: Icons.event_available_outlined, texto: 'Nada programado en las próximas dos semanas'),
            ),
          )
        else
          Rejilla(columnas: columnas, children: [for (final t in ts) TareaCard(t)]),
      ],
    );
  }
}

/// Alto común de las tarjetas que van en pareja, para que queden iguales.
const _alto = 340.0;

/// Cabecera de Inicio: la fecha en morado y las acciones fuera; dentro de un bloque morado oscuro
/// (degradado suave), el saludo, una frase y tres cifras básicas, sin botones.
class _Hero extends StatelessWidget {
  final String saludo, fecha;
  final int hoy, vencidas;
  final List<Tarea> sinTrabajador;
  final ValueChanged<Seccion> onIr;
  const _Hero({
    required this.saludo,
    required this.fecha,
    required this.hoy,
    required this.vencidas,
    required this.sinTrabajador,
    required this.onIr,
  });

  String get frase {
    if (store.clientes.isEmpty) return 'Preparado para automatizarlo todo.';
    return hoy == 0
        ? 'Hoy no hay nada programado.'
        : 'Hoy tienes $hoy ${hoy == 1 ? 'mantenimiento' : 'mantenimientos'}.';
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = store.trabajadores.where((w) => w.activo && w.estadoHoy != EstadoHoy.ausente).length;
    final cifras = [
      (vencidas, vencidas == 1 ? 'vencida' : 'vencidas'),
      (sinTrabajador.length, 'sin asignar'),
      (disponibles, disponibles == 1 ? 'trabajador hoy' : 'trabajadores hoy'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fecha,
                style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            // Sin botón "Itinerario": ya está "Ir al itinerario" en Próximos mantenimientos (una acción, un sitio).
            if (sinTrabajador.isNotEmpty) ...[
              BotonAccion(
                '✦ Asignar ${sinTrabajador.length}',
                tooltip: 'Asignar el trabajador más adecuado a lo que no tiene',
                onPressed: () {
                  final n = store.automatizar(sinTrabajador);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      width: 420,
                      content: Text(
                        n == 0
                            ? 'No hay trabajadores aptos para lo que falta.'
                            : 'Pulpo ha asignado $n ${n == 1 ? 'mantenimiento' : 'mantenimientos'}.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            // Igual que en el Itinerario.
            BotonAccion(
              'Nueva tarea',
              icono: Icons.add_rounded,
              tooltip: 'Crear una tarea (N)',
              onPressed: () => abrirTareaForm(context, null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            // Morado apagado hacia tinta: menos saturado que el morado de acción.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(P.morado, P.tinta, .35)!, Color.lerp(P.morado, P.tinta, .62)!],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saludo,
                style: TextStyle(
                  fontFamily: P.titulos,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(frase, style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 15.5)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 28,
                runSpacing: 10,
                children: [
                  for (final (n, texto) in cifras)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$n ',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          TextSpan(
                            text: texto,
                            style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .68)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cuatro cifras en tarjetas blancas: punto de color, etiqueta, número grande y una nota.
class _Kpis extends StatelessWidget {
  final int hoy, semana, vencidas, hechas;
  final bool dosCol;
  const _Kpis({
    required this.hoy,
    required this.semana,
    required this.vencidas,
    required this.hechas,
    required this.dosCol,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.today_rounded, 'Para hoy', hoy, P.morado, 'en agenda'),
      (Icons.date_range_rounded, 'Esta semana', semana, P.teal, 'próximos 7 días'),
      (
        Icons.warning_amber_rounded,
        'Vencidas',
        vencidas,
        P.rojo,
        vencidas == 0 ? '¡todo al día!' : 'requieren atención',
      ),
      (Icons.task_alt_rounded, 'Hechas', hechas, P.verde, 'últimos 30 días'),
    ];
    return Rejilla(
      columnas: dosCol ? 4 : 2,
      children: [
        for (final (icono, etiqueta, valor, color, nota) in items)
          // Tarjeta blanca con una barra de su color abajo del todo.
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: P.superficie,
              borderRadius: BorderRadius.circular(P.radio),
              border: Border.all(color: P.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Cifra(
                          etiqueta,
                          valor,
                          nota: nota,
                          tamano: 32,
                          color: color == P.rojo && valor > 0 ? P.rojo : null,
                          punto: color,
                        ),
                      ),
                      // Icono arriba a la derecha para reconocer la cifra de un vistazo.
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
                        child: Icon(icono, size: 17, color: color),
                      ),
                    ],
                  ),
                ),
                Container(height: 4, color: color),
              ],
            ),
          ),
      ],
    );
  }
}

/// Punto de color para marcar una fila sin recurrir a un icono.
Widget _punto(Color c) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);
