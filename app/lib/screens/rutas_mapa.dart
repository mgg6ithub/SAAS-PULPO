import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../planificador.dart';
import '../theme.dart';
import '../widgets.dart';

Color _color(Trabajador w) => colorPaleta(w.color);

/// Capa del mapa con las rutas planificadas: una línea por técnico (por carretera o directa),
/// las paradas numeradas en su orden y el almacén.
class CapaRutas extends StatelessWidget {
  const CapaRutas({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: planActual,
    builder: (context, plan, _) => plan == null
        ? const SizedBox.shrink()
        : ValueListenableBuilder(
            valueListenable: rutaPorCarretera,
            builder: (context, carretera, _) => Stack(
              children: [
                for (final r in plan.rutas.where((r) => r.paradas.isNotEmpty))
                  carretera
                      ? FutureBuilder(
                          future: trazadoCarretera(r),
                          builder: (context, s) => _linea(r, s.data ?? _directa(r), punteada: s.data == null),
                        )
                      : _linea(r, _directa(r), punteada: true),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: almacen,
                      width: 30,
                      height: 30,
                      child: Tooltip(
                        message: 'Almacén · salida y vuelta',
                        child: Container(
                          decoration: BoxDecoration(
                            color: P.tinta,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.warehouse_rounded, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    for (final r in plan.rutas)
                      for (final (i, p) in r.paradas.indexed)
                        Marker(
                          point: p.punto,
                          width: 30,
                          height: 30,
                          child: Tooltip(
                            message:
                                '${i + 1}. ${p.tarea.nombre}\n${hhmm(p.inicio)}–${hhmm(p.fin)} · ${r.trabajador.nombreCompleto}',
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _color(r.trabajador),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 6)],
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
  );

  static List<LatLng> _directa(Ruta r) => [almacen, ...r.paradas.map((p) => p.punto), almacen];

  Widget _linea(Ruta r, List<LatLng> puntos, {bool punteada = false}) => PolylineLayer(
    polylines: [
      Polyline(
        points: puntos,
        strokeWidth: 4,
        color: _color(r.trabajador).withValues(alpha: .85),
        borderStrokeWidth: 1.5,
        borderColor: Colors.white,
        pattern: punteada ? StrokePattern.dashed(segments: const [10, 6]) : const StrokePattern.solid(),
      ),
    ],
  );
}

/// Controles sobre el mapa cuando hay un plan: carretera/directa, por qué, deshacer y quitar.
class ControlesRuta extends StatelessWidget {
  const ControlesRuta({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: planActual,
    builder: (context, plan, _) => plan == null
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: P.superficie,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder(
                  valueListenable: rutaPorCarretera,
                  builder: (_, carretera, _) => Pestanas(
                    opciones: const ['Por carretera', 'Directa'],
                    seleccion: carretera ? 0 : 1,
                    onChanged: (i) => rutaPorCarretera.value = i == 0,
                  ),
                ),
                const SizedBox(height: 6),
                for (final r in plan.rutas)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _color(r.trabajador),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${r.trabajador.nombreCompleto} · ${r.paradas.length} paradas · ${r.km.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Enlace('Por qué esta ruta', onTap: () => abrirPorQue(context, plan)),
                    Enlace('Deshacer', onTap: deshacer),
                    Enlace('Ocultar', onTap: () => planActual.value = null),
                  ],
                ),
              ],
            ),
          ),
  );
}

// ── "Por qué esta ruta": diagrama de bloques ──

Future<void> abrirPorQue(BuildContext context, Plan plan) => showDialog(
  context: context,
  builder: (c) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Por qué esta ruta',
                    style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '1) Primero las más críticas y las de franja más estrecha.  2) Cada una al técnico que ya tenía o a uno apto.  '
              '3) En el hueco que menos desplazamiento añade, respetando franjas y la jornada (${hhmm(inicioJornada)}–${hhmm(finJornada)}).  '
              '4) Se mejora el orden si así se recorre menos.',
              style: TextStyle(fontSize: 12.5, color: P.textoSuave, height: 1.5),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  for (final r in plan.rutas) _FlujoRuta(r),
                  if (plan.sinProgramar.isNotEmpty) ...[
                    Text(
                      'Sin programar',
                      style: TextStyle(fontFamily: P.titulos, fontSize: 15, fontWeight: FontWeight.w700, color: P.rojo),
                    ),
                    const SizedBox(height: 6),
                    for (final (t, motivo) in plan.sinProgramar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('· ${t.nombre}: $motivo', style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Un técnico: almacén → (viaje) → bloque → (viaje) → bloque … → almacén.
class _FlujoRuta extends StatelessWidget {
  final Ruta r;
  const _FlujoRuta(this.r);

  Widget _flecha(int min, double km) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$min min', style: TextStyle(fontSize: 11, color: P.textoSuave)),
        Icon(Icons.arrow_forward_rounded, size: 18, color: P.textoSuave),
        Text('${km.toStringAsFixed(1)} km', style: TextStyle(fontSize: 11, color: P.textoSuave)),
      ],
    ),
  );

  Widget _caja(Widget child, Color color, {double ancho = 210}) => Container(
    width: ancho,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border(left: BorderSide(color: color, width: 4)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final color = _color(r.trabajador);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(inicialesDe(r.trabajador.nombreCompleto), color, size: 24),
              const SizedBox(width: 8),
              Text(r.trabajador.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text(
                '${r.paradas.length} paradas · ${r.km.toStringAsFixed(1)} km · ${r.minutosViaje} min de viaje · termina ${hhmm(r.fin)}',
                style: TextStyle(fontSize: 12, color: P.textoSuave),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _caja(
                  Text(
                    'Almacén\nsalida ${hhmm(inicioJornada)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  P.tinta,
                  ancho: 110,
                ),
                for (final (i, p) in r.paradas.indexed) ...[
                  _flecha(p.viajeMin, p.km),
                  _caja(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${i + 1}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: color),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.tarea.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${hhmm(p.inicio)}–${hhmm(p.fin)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Pill(p.tarea.criticidad.etiqueta, p.tarea.criticidad.color, solido: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(p.razon, style: TextStyle(fontSize: 11, color: P.textoSuave, height: 1.35)),
                      ],
                    ),
                    color,
                  ),
                ],
                if (r.paradas.isNotEmpty) ...[
                  _flecha(minutosEntre(r.paradas.last.punto, almacen), kmEntre(r.paradas.last.punto, almacen)),
                  _caja(
                    const Text('Vuelta\nal almacén', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    P.tinta,
                    ancho: 100,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón del pulpo: planifica el día con una pequeña animación ──

/// Pulpo en el centro del itinerario: planifica las tareas del día elegido.
class BotonPulpo extends StatefulWidget {
  final DateTime dia;
  final VoidCallback onHecho;
  const BotonPulpo({super.key, required this.dia, required this.onHecho});

  @override
  State<BotonPulpo> createState() => _BotonPulpoState();
}

class _BotonPulpoState extends State<BotonPulpo> {
  bool hover = false;

  Future<void> _planificar() async {
    final plan = planificar(widget.dia);
    // Espera con animación: que se vea que el pulpo "piensa".
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (c.mounted) Navigator.pop(c);
        });
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  builder: (_, v, _) => Transform.rotate(
                    angle: v * 6.28,
                    child: const Text('🐙', style: TextStyle(fontSize: 46)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'El pulpo está planificando…',
                  style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${plan.rutas.fold(0, (s, r) => s + r.paradas.length) + plan.sinProgramar.length} tareas · '
                  '${plan.rutas.length} técnicos · calculando distancias y franjas',
                  style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                ),
                const SizedBox(height: 16),
                const SizedBox(width: 220, child: LinearProgressIndicator()),
              ],
            ),
          ),
        );
      },
    );
    aplicar(plan);
    widget.onHecho();
    if (!mounted) return;
    final n = plan.rutas.fold(0, (s, r) => s + r.paradas.length);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        width: 460,
        content: Text(
          'Pulpo ha planificado $n ${n == 1 ? 'tarea' : 'tareas'}'
          '${plan.sinProgramar.isEmpty ? '' : ' · ${plan.sinProgramar.length} sin programar'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: GestureDetector(
      onTap: _planificar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        transform: Matrix4.translationValues(0, hover ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [P.tinta, Color.lerp(P.tinta, P.morado, .6)!]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: P.morado.withValues(alpha: hover ? .45 : .25),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Planificar el día',
              style: TextStyle(fontFamily: P.titulos, color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
