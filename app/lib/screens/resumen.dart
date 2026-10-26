import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../forms.dart';
import '../models.dart';
import '../shell.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'planificacion.dart';
import 'tarea_card.dart';

/// Inicio: saludo, cifras clave, lo pendiente, la carga del equipo y los próximos mantenimientos
/// como las tarjetas de la landing. Sin gráficas de relleno: solo lo que se mira cada mañana.
class Resumen extends StatelessWidget {
  final ValueChanged<Seccion> onIr;
  final ValueChanged<String> onTrabajador;
  const Resumen({super.key, required this.onIr, required this.onTrabajador});

  @override
  Widget build(BuildContext context) {
    final activas = store.tareas.where((t) => !t.esPlantilla && t.activa).toList();
    final conFecha = activas.where((t) => t.proximo != null).toList();
    final vencidas = conFecha.where((t) => diasHasta(t.proximo!) < 0).toList();
    final hoyT = conFecha.where((t) => diasHasta(t.proximo!) == 0).toList();
    final semana = conFecha.where((t) => diasHasta(t.proximo!) >= 0 && diasHasta(t.proximo!) <= 7).toList();
    final hechas30 = activas.where((t) => t.ultimo != null && diasHasta(t.ultimo!) >= -30).length;
    final sinTrabajador = conFecha.where((t) => t.trabajadorIds.isEmpty && diasHasta(t.proximo!) <= 7).toList();
    // Pasos de la guía, siempre según los datos de ahora: si se borra el cliente, vuelve a pedirlo.
    final hayTarea = store.tareas.any((t) => !t.esPlantilla);
    final pasos = [
      store.clientes.isNotEmpty,
      hayTarea,
      hayTarea && ajustes.guiaItinerario,
      store.trabajadores.isNotEmpty,
    ];

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
                  _Hero(conFecha: conFecha, sinTrabajador: sinTrabajador, pasos: pasos),
                  const SizedBox(height: 16),
                  if (pasos.contains(false)) ...[_PrimerosPasos(pasos, onIr: onIr), const SizedBox(height: 16)],
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

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
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

/// Guía de primeros pasos (como la de Google Play Console): índice vertical con ticks que se marcan y
/// desmarcan solos según los datos. A la derecha de cada paso, dónde se hace en la app; solo el paso
/// en curso lleva su botón. Desaparece al completarla.
class _PrimerosPasos extends StatelessWidget {
  /// Hecho o no, por paso: cliente, trabajo, ver el itinerario, trabajador.
  final List<bool> hechos;
  final ValueChanged<Seccion> onIr;
  const _PrimerosPasos(this.hechos, {required this.onIr});

  /// Abre el itinerario en la semana del último trabajo creado, para verlo en su día y su hora.
  void _verItinerario() {
    final t = store.tareas.lastWhere((t) => !t.esPlantilla);
    Planificacion.mostrarSemana(t.proximo ?? hoy());
    ajustes.marcarGuiaItinerario();
    onIr(Seccion.planificacion);
  }

  @override
  Widget build(BuildContext context) {
    // (título, explicación, ruta en la app, botón). Los pasos de crear no llevan botón: se hacen desde
    // su sección, como siempre, y la ruta indica dónde.
    final pasos = [
      (
        'Crea tu primer cliente',
        'A quien le haces el mantenimiento: una comunidad, una empresa, un local, una instalación…',
        (Icons.apartment_outlined, 'Clientes', 'Nuevo cliente'),
        null,
      ),
      (
        'Crea un trabajo',
        'Una tarea de mantenimiento: qué hay que revisar y cada cuánto. Pulpo calcula cuándo toca. '
            'También puedes crearla desde la ficha del cliente.',
        (Icons.handyman_outlined, 'Tareas', 'Nueva tarea'),
        null,
      ),
      (
        'Mira tu trabajo en el itinerario',
        'El itinerario es tu semana: cada trabajo en su día y a su hora, y en el mapa.',
        (Icons.calendar_month_outlined, 'Itinerario', null),
        BotonPrimario('Ir al itinerario', icono: Icons.calendar_month_outlined, onPressed: _verItinerario),
      ),
      (
        'Añade un trabajador',
        'Quién hace los mantenimientos. Indica qué sabe hacer y Pulpo le propondrá los trabajos que le encajan.',
        (Icons.badge_outlined, 'Trabajadores', 'Nuevo trabajador'),
        null,
      ),
    ];
    final actual = hechos.indexOf(false);
    // Borde discontinuo: es una guía de paso, no una tarjeta de datos.
    return CustomPaint(
      foregroundPainter: BordeDiscontinuo(P.textoSuave.withValues(alpha: .45), BorderRadius.circular(P.radio)),
      child: Tarjeta(
        color: P.superficie,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
                Text(
                  '${hechos.where((h) => h).length} de ${pasos.length}',
                  style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (i, (titulo, detalle, ruta, boton)) in pasos.indexed)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Marca y, debajo, la línea que une con el siguiente paso.
                    SizedBox(
                      width: 20,
                      child: Column(
                        children: [
                          _MarcaPaso(hecho: hechos[i], actual: i == actual),
                          if (i < pasos.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                color: P.borde,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título a la izquierda y, en el paso en curso, dónde se hace a la derecha (baja de
                            // línea si no cabe).
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 2,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 220),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      fontWeight: i == actual ? FontWeight.w600 : FontWeight.w500,
                                      color: hechos[i] || i == actual ? P.texto : P.textoSuave,
                                      decoration: hechos[i] ? TextDecoration.lineThrough : null,
                                      decorationColor: P.textoSuave,
                                    ),
                                    child: Text(titulo),
                                  ),
                                  if (i == actual) _Ruta(ruta.$1, ruta.$2, ruta.$3),
                                ],
                              ),
                            ),
                            if (i == actual) ...[
                              const SizedBox(height: 2),
                              Text(detalle, style: TextStyle(fontSize: 13, height: 1.4, color: P.textoSuave)),
                              if (boton != null) ...[const SizedBox(height: 10), boton],
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

/// Dónde se hace un paso en la app: icono y nombre de la sección › acción.
class _Ruta extends StatelessWidget {
  final IconData icono;
  final String seccion;
  final String? accion;
  const _Ruta(this.icono, this.seccion, this.accion);

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(fontSize: 12.5, color: P.textoSuave);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: P.textoSuave),
        const SizedBox(width: 5),
        Text(seccion, style: estilo),
        if (accion != null) ...[
          Icon(Icons.chevron_right_rounded, size: 16, color: P.textoSuave),
          Text(accion!, style: estilo),
        ],
      ],
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

/// Cabecera de Inicio: la fecha en morado y las acciones fuera, justo encima de un bloque morado claro
/// (degradado desde la izquierda) con el saludo, una frase según el momento y tres cifras, sin botones.
/// Saludo, fecha y frase siguen a la hora: se revisan cada minuto.
class _Hero extends StatefulWidget {
  final List<Tarea> conFecha, sinTrabajador;

  /// Pasos de la guía hechos o no (ver [_PrimerosPasos]).
  final List<bool> pasos;
  const _Hero({required this.conFecha, required this.sinTrabajador, required this.pasos});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  late final Timer _reloj;
  late DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Solo repinta si cambia la hora (saludo, frase) o el día (fecha).
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) {
      final n = DateTime.now();
      if (n.hour != _ahora.hour || n.day != _ahora.day) setState(() => _ahora = n);
    });
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  String get saludo {
    final h = _ahora.hour;
    return h >= 6 && h < 14 ? 'Buenos días' : (h >= 14 && h < 21 ? 'Buenas tardes' : 'Buenas noches');
  }

  String get fecha => 'Hoy es ${_dias[_ahora.weekday - 1]}, ${_ahora.day} de ${_meses[_ahora.month - 1]}';

  static String _mant(int n) => '$n ${n == 1 ? 'mantenimiento' : 'mantenimientos'}';

  /// Primera vez: bienvenida; con la guía a medias: lo que falta; después, el día (y por la noche, mañana).
  String get frase {
    final pasos = widget.pasos;
    final quedan = pasos.where((p) => !p).length;
    if (quedan == pasos.length) {
      return 'Te damos la bienvenida a Pulpo. En unos minutos tendrás tu mantenimiento en marcha.';
    }
    if (quedan == 1) return 'Ya casi está: solo te falta un paso.';
    if (quedan > 1) return 'Vas bien: en nada tendrás tu mantenimiento en marcha.';

    final hoyT = widget.conFecha.where((t) => diasHasta(t.proximo!) == 0).toList();
    final vencidas = widget.conFecha.where((t) => diasHasta(t.proximo!) < 0).length;
    final futuras = widget.conFecha.where((t) => diasHasta(t.proximo!) > 0).toList()
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));
    if (hoyT.isNotEmpty) {
      final horas = [for (final t in hoyT) ?t.inicioMin]..sort();
      return 'Hoy tienes ${_mant(hoyT.length)}${horas.isEmpty ? '' : ', el primero a las ${hhmm(horas.first)}'}.';
    }
    final manana = futuras.where((t) => diasHasta(t.proximo!) == 1).length;
    if (_ahora.hour >= 19 && manana > 0) return 'Por hoy, nada más. Mañana tienes ${_mant(manana)}.';
    if (vencidas > 0) return 'Hoy no hay nada programado: buen momento para ponerte al día con lo vencido.';
    if (futuras.isNotEmpty) {
      final d = futuras.first.proximo!;
      final cuando = diasHasta(d) == 1 ? 'mañana' : 'el ${_dias[d.weekday - 1]} ${d.day}';
      return 'Hoy no hay nada programado. El próximo mantenimiento es $cuando.';
    }
    return 'Todo al día. Pulpo te avisará cuando toque el siguiente mantenimiento.';
  }

  @override
  Widget build(BuildContext context) {
    final sinTrabajador = widget.sinTrabajador;
    // Con la guía a medias, en vez de ceros, la invitación a completarla; después, lo que ya hay.
    final hechos = widget.pasos.where((p) => p).length;
    final clientes = store.clientes.length;
    final trabajos = store.tareas.where((t) => !t.esPlantilla).length;
    final trabajadores = store.trabajadores.length;
    final cifras = [
      (clientes, clientes == 1 ? 'cliente' : 'clientes'),
      (trabajos, trabajos == 1 ? 'trabajo' : 'trabajos'),
      (trabajadores, trabajadores == 1 ? 'trabajador' : 'trabajadores'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La fecha, pegada al bloque (abajo de la fila de botones) y alineada con el saludo de dentro.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: _sangriaHero),
                child: Text(
                  fecha,
                  style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600),
                ),
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
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(_sangriaHero, 18, _sangriaHero, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            // Claro a la izquierda y el morado del logo a la derecha, como la versión antigua.
            gradient: LinearGradient(
              colors: [Color.lerp(P.morado, Colors.white, .22)!, Color.lerp(P.morado, Colors.white, .04)!],
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
              Text(frase, style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 15.5)),
              const SizedBox(height: 14),
              if (hechos < widget.pasos.length)
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Completa los primeros pasos',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      TextSpan(
                        text: '  ·  $hechos de ${widget.pasos.length}',
                        style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .82)),
                      ),
                    ],
                  ),
                )
              else
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
                              style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .82)),
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

/// Margen interior del bloque del saludo; la fecha de encima entra lo mismo para alinearse con él.
const _sangriaHero = 22.0;

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
