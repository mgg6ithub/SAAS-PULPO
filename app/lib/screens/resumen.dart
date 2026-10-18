import 'dart:math';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../shell.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Inicio: saludo, acciones rápidas, cifras clave, lo pendiente y widgets de carga.
/// Inspirado en el Inicio y los Tableros de Holded (ver Interfaz UI/capturas/01 y 02).
class Resumen extends StatelessWidget {
  final ValueChanged<Seccion> onIr;
  final ValueChanged<String> onCliente;
  final ValueChanged<String> onTrabajador;
  const Resumen({super.key, required this.onIr, required this.onCliente, required this.onTrabajador});

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
        final ancho = min(1080.0, box.maxWidth - 64);
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
          padding: const EdgeInsets.symmetric(vertical: 28),
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
                  const SizedBox(height: 16),
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
                    _ProximosDias(conFecha),
                  ),
                  const SizedBox(height: 16),
                  par(_CargaTrabajadores(onTrabajador: onTrabajador), _PorTipo(activas)),
                  const SizedBox(height: 16),
                  _Proximos(conFecha, onCliente: onCliente, onIr: onIr),
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
      borderRadius: BorderRadius.circular(10),
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
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.5),
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
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [P.moradoSuave, Color.lerp(P.moradoSuave, P.azul, .12)!],
      ),
    ),
    padding: const EdgeInsets.all(28),
    child: Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: P.superficie,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: P.morado.withValues(alpha: .15), blurRadius: 30, offset: const Offset(0, 12))],
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
              ('Ascensor', 'Ascensor portal A', 'Hoy · 09:00', Pill('Hoy', P.morado, solido: true)),
              ('Caldera', 'Caldera comunitaria', 'Jue · 11:30', const Pill('Pronto', P.ambar, solido: true)),
              ('Contra incendios', 'Extintores planta 2', 'Vie · 16:00', const Pill('Al día', P.verde, solido: true)),
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

/// Barras de los próximos 7 días (como el "Resumen ventas" de los tableros de Holded).
class _ProximosDias extends StatelessWidget {
  final List<Tarea> conFecha;
  const _ProximosDias(this.conFecha);

  static const _letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final dias = [for (var i = 0; i < 7; i++) masDias(hoy(), i)];
    final cuenta = [for (final d in dias) conFecha.where((t) => DateUtils.isSameDay(t.proximo, d)).length];
    final maximo = max(1, cuenta.fold(0, max));
    final total = cuenta.fold(0, (a, b) => a + b);
    return SeccionTarjeta(
      alto: _alto,
      titulo: 'Próximos 7 días',
      subtitulo: 'Mantenimientos por día',
      sinFilas: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('programados', style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, d) in dias.indexed)
                      Expanded(
                        child: Tooltip(
                          message: '${cuenta[i]} el ${d.day}/${d.month}',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (cuenta[i] > 0)
                                Text('${cuenta[i]}', style: TextStyle(fontSize: 11, color: P.textoSuave)),
                              const SizedBox(height: 4),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: cuenta[i] / maximo),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) => Container(
                                  height: max(4, 100 * v),
                                  margin: const EdgeInsets.symmetric(horizontal: 7),
                                  decoration: BoxDecoration(
                                    color: i == 0 ? P.morado : P.morado.withValues(alpha: cuenta[i] == 0 ? .12 : .45),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                i == 0 ? 'Hoy' : _letras[d.weekday - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: i == 0 ? P.morado : P.textoSuave,
                                ),
                              ),
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
      ],
    );
  }
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

class _PorTipo extends StatelessWidget {
  final List<Tarea> activas;
  const _PorTipo(this.activas);

  @override
  Widget build(BuildContext context) {
    final cuenta = <String, int>{};
    for (final t in activas) {
      cuenta[t.tipo] = (cuenta[t.tipo] ?? 0) + 1;
    }
    final orden = cuenta.entries.toList()..sort((a, b) => b.value - a.value);
    final maximo = max(1, orden.isEmpty ? 1 : orden.first.value);
    return SeccionTarjeta(
      alto: _alto,
      titulo: 'Por tipo de mantenimiento',
      subtitulo: '${activas.length} equipos activos',
      sinFilas: true,
      children: [
        if (orden.isEmpty)
          const SizedBox(
            height: 160,
            child: Vacio(icono: Icons.handyman_outlined, texto: 'Aún no hay mantenimientos'),
          )
        else
          for (final e in orden.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Align(alignment: Alignment.centerLeft, child: Etiqueta(e.key, tipoDe(e.key).color)),
                  ),
                  Expanded(child: _barra(e.value / maximo, tipoDe(e.key).color)),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${e.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Tabla con los próximos mantenimientos (lo vencido primero).
class _Proximos extends StatelessWidget {
  final List<Tarea> conFecha;
  final ValueChanged<String> onCliente;
  final ValueChanged<Seccion> onIr;
  const _Proximos(this.conFecha, {required this.onCliente, required this.onIr});

  @override
  Widget build(BuildContext context) {
    final lista = [...conFecha.where((t) => diasHasta(t.proximo!) <= 14)]
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));
    final ts = lista.take(8).toList();
    return SeccionTarjeta(
      titulo: 'Próximos mantenimientos',
      accion: Enlace('Ir al itinerario', onTap: () => onIr(Seccion.planificacion)),
      sinFilas: true,
      children: [
        if (ts.isEmpty)
          const SizedBox(
            height: 160,
            child: Vacio(icono: Icons.event_available_outlined, texto: 'Nada programado en las próximas dos semanas'),
          )
        else
          for (final (i, t) in ts.indexed) ...[
            if (i > 0) Divider(height: 1, color: P.borde),
            InkWell(
              hoverColor: P.columna,
              onTap: () => abrirTareaForm(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        relativo(t.proximo!),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: diasHasta(t.proximo!) < 0 ? P.rojo : P.texto,
                        ),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 30,
                      decoration: BoxDecoration(color: tipoDe(t.tipo).color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            [fecha(t.proximo), ?t.horario].join(' · '),
                            style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: t.clienteId == null ? null : () => onCliente(t.clienteId!),
                        child: Text(
                          store.cliente(t.clienteId)?.nombre ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: P.textoSuave),
                        ),
                      ),
                    ),
                    AvataresTrabajadores(t.trabajadorIds, size: 24),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 66,
                      child: Align(alignment: Alignment.centerRight, child: pillEstado(t)),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ],
    );
  }
}

/// Alto común de las tarjetas que van en pareja, para que queden iguales.
const _alto = 340.0;

/// Cabecera con el carácter de Pulpo: degradado morado, saludo, resumen del día en una frase,
/// acciones rápidas en botones translúcidos y el pulpo con burbujas a la derecha.
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
  Widget build(BuildContext context) {
    final oscuro = Color.lerp(P.morado, const Color(0xFF1E1B4B), .55)!;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [P.morado, oscuro]),
        boxShadow: [BoxShadow(color: P.morado.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  saludo,
                  style: TextStyle(
                    fontFamily: P.titulos,
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(frase, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BotonHero('Nueva tarea', () => abrirTareaForm(context, null), solido: true),
                    _BotonHero('Cliente', () => abrirClienteForm(context)),
                    _BotonHero('Trabajador', () => abrirTrabajadorForm(context)),
                    _BotonHero('Itinerario', () => onIr(Seccion.planificacion)),
                    if (sinTrabajador.isNotEmpty)
                      _BotonHero('Automatizar ${sinTrabajador.length}', () {
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
                      }, destacado: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de la cabecera: blanco sólido (principal), translúcido o con brillo ámbar (Automatizar).
class _BotonHero extends StatefulWidget {
  final String texto;
  final VoidCallback onTap;
  final bool solido, destacado;
  const _BotonHero(this.texto, this.onTap, {this.solido = false, this.destacado = false});

  @override
  State<_BotonHero> createState() => _BotonHeroState();
}

class _BotonHeroState extends State<_BotonHero> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final fondo = widget.solido
        ? Colors.white
        : widget.destacado
        ? const Color(0xFFFBBF24)
        : Colors.white.withValues(alpha: hover ? .24 : .14);
    final fg = widget.solido ? P.morado : (widget.destacado ? const Color(0xFF422006) : Colors.white);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: widget.solido || widget.destacado ? 0 : .22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.texto,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuatro tarjetas de cifra, cada una con su color: icono en círculo, número grande y una barra fina abajo.
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
      (Icons.date_range_rounded, 'Esta semana', semana, P.azul, 'próximos 7 días'),
      (
        Icons.warning_amber_rounded,
        'Vencidas',
        vencidas,
        P.rojo,
        vencidas == 0 ? '¡todo al día!' : 'requieren atención',
      ),
      (Icons.task_alt_rounded, 'Hechas', hechas, P.verde, 'últimos 30 días'),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = dosCol ? 4 : 2;
        final w = (box.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (icono, etiqueta, valor, color, nota) in items)
              Container(
                width: w,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: P.superficie,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: P.borde),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                            child: Icon(icono, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(etiqueta, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: valor.toDouble()),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, _) => Text(
                                    '${v.round()}',
                                    style: TextStyle(
                                      fontFamily: P.titulos,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.8,
                                      height: 1.15,
                                      color: color == P.rojo && valor > 0 ? P.rojo : P.texto,
                                    ),
                                  ),
                                ),
                                Text(nota, style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 3, color: color),
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
