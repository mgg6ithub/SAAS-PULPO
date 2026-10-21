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
    final vacia = store.clientes.isEmpty;

    return LayoutBuilder(
      builder: (context, box) {
        final ancho = min(1080.0, box.maxWidth - margenPagina.horizontal);
        final dosCol = ancho > 760;
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
          padding: EdgeInsets.only(top: margenPagina.top, bottom: margenPagina.bottom),
          child: Center(
            child: SizedBox(
              width: ancho,
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
                  const SizedBox(height: 28),
                  if (vacia) ...[const _Bienvenida(), const SizedBox(height: 16)],
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

/// Tarjeta de primeros pasos cuando aún no hay clientes (la "Tu primera factura" de Holded).
class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(P.radio),
      border: Border.all(color: P.borde),
    ),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, box) {
        final texto = Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pill('Primeros pasos', P.morado),
              const SizedBox(height: 12),
              const Text(
                'Tu mantenimiento, en piloto automático',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.7),
              ),
              const SizedBox(height: 8),
              Text(
                'Da de alta tus clientes y tu equipo. Pulpo calcula cuándo toca cada mantenimiento y propone quién lo hace.',
                style: TextStyle(color: P.textoSuave, height: 1.45),
              ),
              const SizedBox(height: 16),
              for (final b in [
                'Plantillas de mantenimiento listas para usar',
                'Avisos de lo que vence antes de que venza',
                'Asignación automática según competencias',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _punto(P.verde),
                      const SizedBox(width: 10),
                      Flexible(child: Text(b, style: const TextStyle(fontSize: 13.5))),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: () => abrirClienteForm(context),
                    child: const Text('Añadir mi primer cliente'),
                  ),
                ],
              ),
            ],
          ),
        );
        if (box.maxWidth < 760) return texto;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 6, child: texto),
              Expanded(flex: 5, child: const _Maqueta()),
            ],
          ),
        );
      },
    ),
  );
}

/// Mini maqueta de una tarea sobre fondo degradado, para ilustrar la bienvenida.
class _Maqueta extends StatelessWidget {
  const _Maqueta();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: P.fondo, border: Border(left: BorderSide(color: P.borde))),
    padding: const EdgeInsets.all(28),
    child: Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: P.superficie,
          borderRadius: BorderRadius.circular(P.radio),
          border: Border.all(color: P.borde),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Esta semana', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                Text('3 tareas', style: TextStyle(fontSize: 11, color: P.textoSuave)),
              ],
            ),
            const SizedBox(height: 12),
            for (final (tipo, nombre, cuando, estado) in [
              ('Ascensor', 'Ascensor portal A', 'Hoy · 09:00', Pill('Hoy', P.morado, punto: true)),
              ('Caldera', 'Caldera comunitaria', 'Jue · 11:30', const Pill('Pronto', P.ambar, punto: true)),
              ('Contra incendios', 'Extintores planta 2', 'Vie · 16:00', const Pill('Al día', P.verde, punto: true)),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(color: tipoDe(tipo).color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          Text(cuando, style: TextStyle(fontSize: 11, color: P.textoSuave)),
                        ],
                      ),
                    ),
                    estado,
                  ],
                ),
              ),
          ],
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
              hoverColor: P.columna,
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
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - (columnas - 1) * 14) / columnas;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [for (final t in ts) TareaCard(t, width: w)],
              );
            },
          ),
      ],
    );
  }
}

/// Alto común de las tarjetas que van en pareja, para que queden iguales.
const _alto = 340.0;

/// Cabecera de Inicio como el hero de la landing: fecha en morado, saludo grande en tinta,
/// el resumen del día en una frase y pocas acciones (la principal en tinta, como "Probar Pulpo").
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
    if (store.clientes.isEmpty) return 'Empecemos: da de alta tu primer cliente y el pulpo hará el resto.';
    final extra = [
      if (vencidas > 0) '$vencidas ${vencidas == 1 ? 'vencido' : 'vencidos'}',
      if (sinTrabajador.isNotEmpty) '${sinTrabajador.length} sin asignar',
    ];
    final base = hoy == 0
        ? 'Hoy no hay nada programado'
        : 'Hoy tienes $hoy ${hoy == 1 ? 'mantenimiento' : 'mantenimientos'}';
    return extra.isEmpty ? '$base. ¡Todo bajo control!' : '$base · ojo: ${extra.join(' y ')}.';
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.end,
    spacing: 16,
    runSpacing: 16,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fecha,
            style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            saludo,
            style: TextStyle(fontFamily: P.titulos, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.2, height: 1.1),
          ),
          const SizedBox(height: 8),
          Text(frase, style: TextStyle(color: P.textoSuave, fontSize: 16)),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(onPressed: () => onIr(Seccion.planificacion), child: const Text('Itinerario')),
          if (sinTrabajador.isNotEmpty)
            OutlinedButton(
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
              child: Text('✦ Asignar ${sinTrabajador.length}'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: P.tinta, foregroundColor: Colors.white),
            onPressed: () => abrirTareaForm(context, null),
            child: const Text('Nueva tarea'),
          ),
        ],
      ),
    ],
  );
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
      ('Para hoy', hoy, P.morado, 'en agenda'),
      ('Esta semana', semana, P.teal, 'próximos 7 días'),
      ('Vencidas', vencidas, P.rojo, vencidas == 0 ? '¡todo al día!' : 'requieren atención'),
      ('Hechas', hechas, P.verde, 'últimos 30 días'),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = dosCol ? 4 : 2;
        final w = (box.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (etiqueta, valor, color, nota) in items)
              // Tarjeta blanca con una barra de su color abajo del todo.
              Container(
                width: w,
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
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Cifra(
                        etiqueta,
                        valor,
                        nota: nota,
                        tamano: 32,
                        color: color == P.rojo && valor > 0 ? P.rojo : null,
                        punto: color,
                      ),
                    ),
                    Container(height: 4, color: color),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Punto de color para marcar una fila sin recurrir a un icono.
Widget _punto(Color c) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);
