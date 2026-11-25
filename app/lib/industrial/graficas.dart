import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Gráficas de Estadísticas: todas en la gama del morado (sin los colores de criticidad, que son de las órdenes),
/// pintadas con `CustomPaint` y con una entrada animada que se repite al cambiar sus datos de clave.

/// Tono [i] de [n] del morado: del pleno al casi fondo, para segmentos y series.
Color tonoMorado(int i, int n) => Color.lerp(P.morado, P.superficie, n <= 1 ? 0 : i / (n - 1) * .72)!;

/// Avance 0 → 1 de la entrada de una gráfica (750 ms, easeOutCubic). Se repite si cambia la [key].
class EntradaGrafica extends StatelessWidget {
  final Widget Function(double v) builder;
  final int ms;
  const EntradaGrafica({super.key, required this.builder, this.ms = 750});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : ms),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => builder(v),
  );
}

/// Tarjeta de una gráfica: título, nota en gris y la gráfica con su alto.
class TarjetaGrafica extends StatelessWidget {
  final String titulo;
  final String? nota;
  final Widget? accion;
  final double alto;
  final Widget child;
  const TarjetaGrafica({super.key, required this.titulo, this.nota, this.accion, this.alto = 220, required this.child});

  @override
  Widget build(BuildContext context) => Tarjeta(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.3),
                  ),
                  if (nota != null) Text(nota!, style: TextStyle(fontSize: 13, color: P.textoSuave)),
                ],
              ),
            ),
            ?accion,
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(height: alto, child: child),
      ],
    ),
  );
}

/// Cifra con su tendencia: etiqueta, número que cuenta hasta su valor y, si hay serie, una línea suave con área.
class CifraGrafica extends StatelessWidget {
  final String etiqueta;
  final num? valor;

  /// Texto en lugar del número (p. ej. «1.240 h»).
  final String? texto;
  final String sufijo;
  final List<double>? serie;
  const CifraGrafica(this.etiqueta, {super.key, this.valor, this.texto, this.sufijo = '', this.serie});

  @override
  Widget build(BuildContext context) {
    final grande = TextStyle(fontFamily: P.titulos, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.8, height: 1.1);
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: EntradaGrafica(
        ms: 900,
        builder: (v) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: P.textoSuave)),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      texto ??
                          (valor == null
                              ? '—'
                              : '${valor is int ? (valor! * v).round() : numCorto(valor!.toDouble() * v)}$sufijo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: grande,
                    ),
                  ),
                  if (serie != null && serie!.length > 1) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomPaint(painter: _PintorLinea(serie!, P.morado, v, rejilla: null)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «1,5»: un decimal como mucho, con coma.
String numCorto(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1).replaceAll('.', ',');

/// Columnas redondeadas en el tiempo (una por tramo), que crecen escalonadas al entrar. Al pasar el ratón, la
/// columna se marca y sale su valor.
class GraficaColumnas extends StatefulWidget {
  final List<double> valores;
  final List<String> etiquetas;

  /// Qué se cuenta, para el globo («órdenes», «incidencias»).
  final String unidad;
  const GraficaColumnas(this.valores, this.etiquetas, {super.key, this.unidad = ''});

  @override
  State<GraficaColumnas> createState() => _GraficaColumnasState();
}

class _GraficaColumnasState extends State<GraficaColumnas> {
  int? _cerca;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => EntradaGrafica(
      ms: 900,
      builder: (v) {
        final pintor = _PintorColumnas(widget.valores, widget.etiquetas, v, _cerca, P.morado, P.borde, P.textoSuave, P.hover);
        return MouseRegion(
          onHover: (e) {
            final i = pintor.indice(e.localPosition, box.biggest);
            if (i != _cerca) setState(() => _cerca = i);
          },
          onExit: (_) => setState(() => _cerca = null),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(size: box.biggest, painter: pintor),
              if (_cerca != null)
                Positioned(
                  left: (pintor.centro(_cerca!, box.biggest) - 60).clamp(0, max(0, box.maxWidth - 120)),
                  top: max(0, pintor.cima(_cerca!, box.biggest) - 52),
                  child: Globo(
                    '${numCorto(widget.valores[_cerca!])} ${widget.unidad}'.trim(),
                    widget.etiquetas[_cerca!],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Globo de una gráfica: valor en negrita y, debajo, de cuándo es.
class Globo extends StatelessWidget {
  final String valor, nota;
  const Globo(this.valor, this.nota, {super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(P.radioControl),
        border: Border.all(color: P.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          Text(nota, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: P.textoSuave)),
        ],
      ),
    ),
  );
}

/// Rejilla y textos comunes de los ejes.
mixin _Ejes {
  static const izq = 34.0, abajo = 24.0, arriba = 8.0;

  void texto(Canvas c, String t, Offset o, Color color, {double alinear = 0, double vertical = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 11, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o.translate(-tp.width * alinear, -tp.height * vertical));
  }

  /// Máximo «redondo» del eje, para que las rayas caigan en números limpios.
  double techo(double v) {
    if (v <= 0) return 4;
    final p = pow(10, (log(v) / ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (v <= m * p) return m * p;
    }
    return 10 * p;
  }
}

class _PintorColumnas extends CustomPainter with _Ejes {
  final List<double> valores;
  final List<String> etiquetas;
  final double v;
  final int? cerca;
  final Color color, rejilla, texto_, pista;
  _PintorColumnas(this.valores, this.etiquetas, this.v, this.cerca, this.color, this.rejilla, this.texto_, this.pista);

  double get _max => techo(valores.isEmpty ? 0 : valores.reduce(max));
  double _paso(Size s) => (s.width - _Ejes.izq) / max(1, valores.length);
  double centro(int i, Size s) => _Ejes.izq + _paso(s) * (i + .5);
  double _alto(Size s) => s.height - _Ejes.abajo - _Ejes.arriba;
  double cima(int i, Size s) => _Ejes.arriba + _alto(s) * (1 - valores[i] / _max);

  int? indice(Offset p, Size s) {
    if (p.dx < _Ejes.izq || valores.isEmpty) return null;
    return ((p.dx - _Ejes.izq) / _paso(s)).floor().clamp(0, valores.length - 1);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final alto = _alto(s), m = _max;
    final fino = Paint()..color = rejilla..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final y = _Ejes.arriba + alto * (1 - k / 4);
      canvas.drawLine(Offset(_Ejes.izq, y), Offset(s.width, y), fino);
      texto(canvas, numCorto(m * k / 4), Offset(_Ejes.izq - 8, y), texto_, alinear: 1, vertical: .5);
    }
    if (valores.isEmpty) return;
    final paso = _paso(s);
    final ancho = min(28.0, paso * .62);
    final base = _Ejes.arriba + alto;
    for (var i = 0; i < valores.length; i++) {
      final cx = centro(i, s);
      // Columna bajo el ratón: una franja suave detrás.
      if (i == cerca) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx - paso / 2 + 2, _Ejes.arriba, paso - 4, alto), const Radius.circular(6)),
          Paint()..color = pista.withValues(alpha: .7),
        );
      }
      // Escalonadas: cada una empieza un poco después que la anterior.
      final retraso = valores.length <= 1 ? 0.0 : i / (valores.length - 1) * .35;
      final p = Curves.easeOutBack.transform(((v - retraso) / (1 - .35)).clamp(0.0, 1.0));
      final h = alto * (valores[i] / m) * p;
      if (h <= 0) continue;
      final r = Rect.fromLTWH(cx - ancho / 2, base - h, ancho, h);
      final apagada = cerca != null && i != cerca;
      canvas.drawRRect(
        RRect.fromRectAndCorners(r, topLeft: Radius.circular(min(6, ancho / 2)), topRight: Radius.circular(min(6, ancho / 2))),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: apagada ? .45 : 1), color.withValues(alpha: apagada ? .25 : .55)],
          ).createShader(r),
      );
    }
    // Etiquetas de abajo: como mucho ocho, repartidas.
    final cada = max(1, (valores.length / 8).ceil());
    for (var i = 0; i < valores.length; i += cada) {
      texto(canvas, etiquetas[i], Offset(centro(i, s), base + 7), texto_, alinear: .5);
    }
  }

  @override
  bool shouldRepaint(_PintorColumnas o) => o.v != v || o.cerca != cerca || o.valores != valores || o.color != color;
}

/// Línea suave con área en degradado; con [rejilla] dibuja también las rayas de fondo. La línea se dibuja de
/// izquierda a derecha según [v].
class _PintorLinea extends CustomPainter {
  final List<double> serie;
  final Color color;
  final double v;
  final Color? rejilla;
  _PintorLinea(this.serie, this.color, this.v, {this.rejilla});

  @override
  void paint(Canvas canvas, Size s) {
    if (serie.length < 2) return;
    var lo = serie.reduce(min), hi = serie.reduce(max);
    if (hi == lo) hi = lo + 1;
    final pts = [
      for (var i = 0; i < serie.length; i++)
        Offset(s.width * i / (serie.length - 1), 3 + (s.height - 6) * (1 - (serie[i] - lo) / (hi - lo))),
    ];
    final linea = curvaSuave(pts);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -4, s.width * v, s.height + 8));
    final area = Path.from(linea)
      ..lineTo(pts.last.dx, s.height)
      ..lineTo(pts.first.dx, s.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & s),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorLinea o) => o.v != v || o.serie != serie || o.color != color;
}

/// Curva suave que pasa por todos los puntos (Catmull-Rom a Bézier), sin pasarse por arriba ni por abajo.
Path curvaSuave(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = i == 0 ? pts[i] : pts[i - 1], p1 = pts[i], p2 = pts[i + 1];
    final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
    final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
    final yMin = min(p1.dy, p2.dy), yMax = max(p1.dy, p2.dy);
    p.cubicTo(c1.dx, c1.dy.clamp(yMin, yMax), c2.dx, c2.dy.clamp(yMin, yMax), p2.dx, p2.dy);
  }
  return p;
}

/// Anillo con sus partes en tonos del morado y la cifra principal en el centro; la leyenda, con barritas.
class Anillo extends StatelessWidget {
  final List<(String, double)> partes;
  final String centro, nota;
  const Anillo(this.partes, {super.key, required this.centro, required this.nota});

  @override
  Widget build(BuildContext context) {
    final total = partes.fold(0.0, (a, p) => a + p.$2);
    return EntradaGrafica(
      ms: 1000,
      builder: (v) => Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _PintorAnillo([for (final p in partes) p.$2], v, [for (var i = 0; i < partes.length; i++) tonoMorado(i, partes.length)], P.hover),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centro, style: TextStyle(fontFamily: P.titulos, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
                    Text(nota, style: TextStyle(fontSize: 12, color: P.textoSuave)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (nombre, valor)) in partes.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 4,
                        decoration: BoxDecoration(color: tonoMorado(i, partes.length), borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: P.textoSuave)),
                      ),
                      Text(
                        total == 0 ? '0' : numCorto(valor),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ],
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

class _PintorAnillo extends CustomPainter {
  final List<double> valores;
  final double v;
  final List<Color> colores;
  final Color pista;
  _PintorAnillo(this.valores, this.v, this.colores, this.pista);

  @override
  void paint(Canvas canvas, Size s) {
    const grosor = 16.0;
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: min(s.width, s.height) / 2 - grosor / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, base..color = pista);
    final total = valores.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;
    final vivos = valores.where((x) => x > 0).length;
    // Hueco entre partes (lo que ocupan las puntas redondeadas y un poco más).
    final hueco = vivos > 1 ? (grosor + 6) / r.width : 0.0;
    var a = -pi / 2;
    final barrido = 2 * pi * v;
    for (var i = 0; i < valores.length; i++) {
      if (valores[i] <= 0) continue;
      final ang = 2 * pi * valores[i] / total;
      final ini = a + hueco / 2, largo = max(0.001, ang - hueco);
      final visible = min(largo, barrido - (ini + pi / 2));
      if (visible > 0) canvas.drawArc(r, ini, visible, false, base..color = colores[i]);
      a += ang;
    }
  }

  @override
  bool shouldRepaint(_PintorAnillo o) => o.v != v || o.valores != valores;
}

/// Ranking en barras horizontales: nombre (con su avatar), barra redondeada sobre su pista y el valor. Cada
/// barra crece un poco después que la de encima.
class BarrasRanking extends StatelessWidget {
  final List<({String nombre, double valor, Widget? lider})> filas;
  const BarrasRanking(this.filas, {super.key});

  @override
  Widget build(BuildContext context) {
    final maximo = filas.isEmpty ? 1.0 : max(1.0, filas.map((f) => f.valor).reduce(max));
    return EntradaGrafica(
      ms: 1000,
      builder: (v) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in filas.indexed)
            Row(
              children: [
                if (f.lider != null) ...[f.lider!, const SizedBox(width: 10)],
                SizedBox(
                  width: 110,
                  child: Text(f.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(child: BarraValor(f.valor / maximo * Curves.easeOutCubic.transform(((v - i * .08) / .7).clamp(0.0, 1.0)))),
                const SizedBox(width: 10),
                SizedBox(
                  width: 34,
                  child: Text(numCorto(f.valor), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Barra redondeada de 0 a 1 sobre su pista gris, en degradado del morado.
class BarraValor extends StatelessWidget {
  final double fraccion;
  final Color? color;
  const BarraValor(this.fraccion, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? P.morado;
    return Container(
      height: 8,
      decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraccion.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [c.withValues(alpha: .6), c]),
          ),
        ),
      ),
    );
  }
}

/// Barra de una tabla: el número y su barra animada (crece al entrar).
class CeldaBarra extends StatelessWidget {
  final int n, maximo;
  final Color? color;
  const CeldaBarra(this.n, this.maximo, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 30, child: Text('$n', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
      Expanded(
        child: EntradaGrafica(
          ms: 800,
          builder: (v) => BarraValor(maximo == 0 ? 0 : n / maximo * v, color: color),
        ),
      ),
    ],
  );
}

// ─── Tramos de tiempo ───

const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// El periodo en tramos: por días (30 días), por semanas (3 meses) o por meses de 30 días (año).
typedef Tramos = ({DateTime desde, int paso, int n, List<String> etiquetas, String nombre});

Tramos tramosDe(DateTime desde, int dias) {
  final paso = dias <= 31 ? 1 : (dias <= 91 ? 7 : 30);
  final n = (dias / paso).ceil();
  return (
    desde: desde,
    paso: paso,
    n: n,
    nombre: paso == 1 ? 'Por día' : (paso == 7 ? 'Por semana' : 'Por mes'),
    etiquetas: [
      for (var i = 0; i < n; i++)
        () {
          final d = masDias(desde, i * paso);
          return paso == 30 ? _mesesCortos[d.month - 1] : '${d.day} ${_mesesCortos[d.month - 1]}';
        }(),
    ],
  );
}

/// Cuántas fechas caen en cada tramo.
List<double> contarPorTramo(Iterable<DateTime> fechas, Tramos t) {
  final r = List<double>.filled(t.n, 0);
  for (final f in fechas) {
    final dias = (DateUtils.dateOnly(f).difference(t.desde).inHours / 24).round();
    final i = dias ~/ t.paso;
    if (dias >= 0 && i < t.n) r[i]++;
  }
  return r;
}
