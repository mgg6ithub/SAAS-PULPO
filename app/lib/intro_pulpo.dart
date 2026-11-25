import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ajustes.dart';
import 'marca.dart';
import 'theme.dart';

/// Mientras sale la entrada del pulpo: el logo de la barra se oculta (el pulpo vuela a su sitio) y la presentación
/// de Inicio espera. La pone a true el Shell al montarse (cada vez que se entra en la app).
final introPulpoActiva = ValueNotifier<bool>(false);

/// El logo de la barra lateral: destino del vuelo.
final logoBarraKey = GlobalKey();

/// Logo de la barra, oculto mientras el pulpo de la entrada vuela hacia él.
class LogoBarra extends StatelessWidget {
  final double size;
  const LogoBarra({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: logoBarraKey,
    child: ValueListenableBuilder(
      valueListenable: introPulpoActiva,
      builder: (_, activa, child) => Opacity(opacity: activa ? 0 : 1, child: child),
      child: LogoPultec(size: size),
    ),
  );
}

/// Entrada al entrar en la app, la misma de la landing: todo en blanco, el pulpo cae grande en el centro, saca los
/// tentáculos, parpadea y vuela al logo de la barra mientras el blanco se desvanece. Un clic, una tecla o la rueda
/// la saltan; con «reducir movimiento» no sale.
class IntroPulpo extends StatefulWidget {
  final VoidCallback onFin;
  const IntroPulpo({super.key, required this.onFin});

  @override
  State<IntroPulpo> createState() => _IntroPulpoState();
}

class _IntroPulpoState extends State<IntroPulpo> with SingleTickerProviderStateMixin {
  static const _vuelo = 2050.0, _total = 2810.0;
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2810));
  Rect? _destino;
  bool _fin = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_tecla);
    _c.addListener(() {
      if (_destino == null && _c.value * _total >= _vuelo) _destino = _medirDestino();
    });
    _c.forward().whenComplete(_terminar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) WidgetsBinding.instance.addPostFrameCallback((_) => _terminar());
  }

  bool _tecla(KeyEvent _) {
    _terminar();
    return false;
  }

  /// Dónde está el logo de la barra, en las coordenadas de esta capa (null si no hay barra, p. ej. en móvil).
  Rect? _medirDestino() {
    final logo = logoBarraKey.currentContext?.findRenderObject() as RenderBox?;
    final capa = context.findRenderObject() as RenderBox?;
    if (logo == null || capa == null || !logo.attached) return null;
    return capa.globalToLocal(logo.localToGlobal(Offset.zero)) & logo.size;
  }

  void _terminar() {
    if (_fin) return;
    _fin = true;
    HardwareKeyboard.instance.removeHandler(_tecla);
    introPulpoActiva.value = false;
    widget.onFin();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_tecla);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _terminar(),
    onPointerSignal: (_) => _terminar(),
    behavior: HitTestBehavior.opaque,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PintorPulpo(_c, () => _destino, P.superficie),
        ),
      ),
    ),
  );
}

// ─── Geometría del logo (la del SVG de la landing, viewBox 126 136 772 758) ───

const _caja = Rect.fromLTWH(126, 136, 772, 758);

final _cabeza = Path()
  ..moveTo(512, 160)
  ..cubicTo(628, 160, 708, 245, 708, 360)
  ..cubicTo(708, 450, 655, 505, 605, 570)
  ..cubicTo(575, 598, 449, 598, 419, 570)
  ..cubicTo(369, 505, 316, 450, 316, 360)
  ..cubicTo(316, 245, 396, 160, 512, 160)
  ..close();

/// Los seis tentáculos: siete puntos cada uno (dos curvas). Los tres primeros, a la izquierda.
const _tentaculos = <List<Offset>>[
  [Offset(352, 452), Offset(300, 500), Offset(230, 500), Offset(205, 450), Offset(185, 405), Offset(215, 365), Offset(255, 380)],
  [Offset(400, 545), Offset(330, 600), Offset(240, 590), Offset(190, 625), Offset(140, 662), Offset(160, 725), Offset(210, 715)],
  [Offset(465, 575), Offset(455, 660), Offset(385, 700), Offset(370, 770), Offset(358, 830), Offset(415, 860), Offset(445, 820)],
  [Offset(672, 452), Offset(724, 500), Offset(794, 500), Offset(819, 450), Offset(839, 405), Offset(809, 365), Offset(769, 380)],
  [Offset(624, 545), Offset(694, 600), Offset(784, 590), Offset(834, 625), Offset(884, 662), Offset(864, 725), Offset(814, 715)],
  [Offset(559, 575), Offset(569, 660), Offset(639, 700), Offset(654, 770), Offset(666, 830), Offset(609, 860), Offset(579, 820)],
];

/// Salen de dentro hacia fuera, alternando lados; cada uno con su ritmo, fuerza y desfase.
const _orden = [0, 3, 1, 4, 2, 5];
const _gestos = <({double f, double fase, double amp, double k, double cie})>[
  (f: 7.4, fase: 0.0, amp: 1.0, k: 4.2, cie: 1.0),
  (f: 9.0, fase: 2.3, amp: 0.65, k: 3.4, cie: 0.6),
  (f: 6.3, fase: 4.1, amp: 1.15, k: 5.0, cie: 0.85),
  (f: 8.2, fase: 1.2, amp: 0.8, k: 3.8, cie: 1.15),
  (f: 6.9, fase: 3.4, amp: 1.05, k: 4.6, cie: 0.7),
  (f: 8.7, fase: 5.2, amp: 0.7, k: 3.6, cie: 1.05),
];

/// Avance a lo largo de cada tentáculo (0 en la base, 1 en la punta), por la cuerda entre sus puntos.
final _pesos = [
  for (final pts in _tentaculos)
    () {
      final acum = <double>[0];
      for (var i = 1; i < pts.length; i++) {
        acum.add(acum.last + (pts[i] - pts[i - 1]).distance);
      }
      return [for (final a in acum) a / acum.last];
    }(),
];

const _rebote = Cubic(.2, .8, .2, 1);
const _salida = Cubic(0, 0, .58, 1);
const _vaiven = Cubic(.42, 0, .58, 1);
const _viaje = Cubic(.65, 0, .25, 1);

double _suave(double x) => x <= 0 ? 0 : (x >= 1 ? 1 : x * x * (3 - 2 * x));
double _tramo(double t, double a, double dur) => ((t - a) / dur).clamp(0.0, 1.0);
double _lerp(double a, double b, double p) => a + (b - a) * p;

/// Interpola fotogramas [(offset, valores…)] en p (ya suavizado), lineal entre ellos.
List<double> _fotogramas(List<List<double>> kf, double p) {
  for (var i = 1; i < kf.length; i++) {
    if (p <= kf[i][0] || i == kf.length - 1) {
      final a = kf[i - 1], b = kf[i];
      final q = ((p - a[0]) / (b[0] - a[0])).clamp(0.0, 1.0);
      return [for (var j = 1; j < a.length; j++) _lerp(a[j], b[j], q)];
    }
  }
  return kf.last.sublist(1);
}

class _PintorPulpo extends CustomPainter {
  final Animation<double> anim;
  final Rect? Function() destino;
  final Color fondo;
  _PintorPulpo(this.anim, this.destino, this.fondo) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 2810; // ms

    // Fondo blanco: se desvanece durante el vuelo.
    final alfa = 1 - _salida.transform(_tramo(t, 2300, 500));
    canvas.drawRect(Offset.zero & size, Paint()..color = fondo.withValues(alpha: fondo.a * alfa));

    final ancho = min(260.0, size.width * .52);
    final k = ancho / _caja.width;
    final alto = _caja.height * k;
    final centro = size.center(Offset.zero);

    // 4. Vuelo al logo de la barra (a su zona útil: el PNG deja ~8 % de margen).
    var tx = 0.0, ty = 0.0, s = 1.0;
    if (t >= 2050) {
      final d = destino() ?? const Rect.fromLTWH(24, 20, 34, 34);
      final dx = d.center.dx - centro.dx, dy = d.center.dy - centro.dy;
      final v = _fotogramas([
        [0, 0, 0, 1],
        [.2, dx * .15, dy * .05 - 20, 1.05],
        [1, dx, dy, d.width * .92 / ancho],
      ], _viaje.transform(_tramo(t, 2050, 750)));
      tx = v[0];
      ty = v[1];
      s = v[2];
    }

    canvas.save();
    canvas.translate(centro.dx + tx, centro.dy + ty);
    canvas.scale(s);
    canvas.translate(-ancho / 2, -alto / 2);
    canvas.scale(k);
    canvas.translate(-_caja.left, -_caja.top);

    final degradado = industrial && !ajustes.mejorada
        ? [Color.lerp(Marca.color, Colors.white, .3)!, Color.lerp(Marca.color, Colors.black, .3)!]
        : const [Color(0xFF9C6CFF), Color(0xFF4A10C8)];
    final shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: degradado)
        .createShader(const Rect.fromLTRB(0, 160, 1024, 870));

    // 2. Tentáculos: salen uno a uno y se doblan como en el agua hasta su forma.
    final trazo = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 78
      ..strokeCap = StrokeCap.round;
    for (final (n, i) in _orden.indexed) {
      final retraso = 450 + n * 90.0;
      final dibujado = _rebote.transform(_tramo(t, retraso, 650));
      if (dibujado <= 0) continue;
      final pts = _tentaculos[i];
      final ms = t - retraso;
      var q = pts;
      if (ms < 2000) {
        final g = _gestos[n];
        final lado = i < 3 ? -1 : 1;
        final seg = max(0.0, ms) / 1000;
        final cierre = lado * -0.22 * g.cie * (1 - _suave(ms / 1100));
        final amp = 0.12 * g.amp * _suave(ms / 250) * (1 - _suave((ms - 300) / 1700));
        final base = pts[0];
        q = [
          for (final (j, p) in pts.indexed)
            () {
              final w = _pesos[i][j];
              final ang = w * (cierre + amp * sin(seg * g.f - w * g.k + g.fase));
              final d = p - base;
              return base + Offset(d.dx * cos(ang) - d.dy * sin(ang), d.dx * sin(ang) + d.dy * cos(ang));
            }(),
        ];
      }
      final camino = Path()
        ..moveTo(q[0].dx, q[0].dy)
        ..cubicTo(q[1].dx, q[1].dy, q[2].dx, q[2].dy, q[3].dx, q[3].dy)
        ..cubicTo(q[4].dx, q[4].dy, q[5].dx, q[5].dy, q[6].dx, q[6].dy);
      if (dibujado >= 1) {
        canvas.drawPath(camino, trazo);
      } else {
        final m = camino.computeMetrics().first;
        canvas.drawPath(m.extractPath(0, m.length * dibujado), trazo);
      }
    }

    // 1. La cabeza cae y rebota (estira y aplasta), con origen abajo en el centro.
    final c = _fotogramas([
      [0, 0, -120, .6, .9],
      [.55, 1, 0, 1.12, .86],
      [.8, 1, -14, .95, 1.06],
      [1, 1, 0, 1, 1],
    ], _salida.transform(_tramo(t, 0, 700)));
    if (c[0] > 0) {
      canvas.save();
      canvas.translate(512, 591 + c[1]);
      canvas.scale(c[2], c[3]);
      canvas.translate(-512, -591);
      canvas.saveLayer(_caja, Paint()..color = Colors.white.withValues(alpha: c[0]));
      canvas.drawPath(_cabeza, Paint()..shader = shader);
      // 3. Parpadeo.
      final ojo = _fotogramas([
        [0, 1],
        [.5, .1],
        [1, 1],
      ], _vaiven.transform(_tramo(t, 1450, 220)))[0];
      final blanco = Paint()..color = Colors.white;
      for (final x in const [452.0, 572.0]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, 410), width: 64, height: 64 * ojo), blanco);
      }
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorPulpo old) => old.fondo != fondo;
}
