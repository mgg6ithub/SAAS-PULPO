import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ilustración de una planta industrial (depósitos, columnas, chimeneas y tuberías) en azules apagados,
/// para la cabecera de Inicio en la vista mejorada. Dibujada a mano: sin fotos ni licencias, y con su
/// versión para el modo oscuro. Se difumina hacia la izquierda para fundirse con el título.
class IlustracionPlanta extends StatelessWidget {
  const IlustracionPlanta({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ShaderMask(
      // Transparente a la izquierda y opaca a la derecha: el título se lee encima sin cortes.
      // Y también se apaga en el borde derecho, para no dejar un corte donde acaba el contenido.
      shaderCallback: (r) => const LinearGradient(
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0, .38, .9, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ShaderMask(
        // Y se apaga hacia abajo, para no chocar con las cifras.
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, .72, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: RepaintBoundary(child: CustomPaint(painter: _Planta(oscuro: P.fondo.computeLuminance() < .3))),
      ),
    ),
  );
}

class _Planta extends CustomPainter {
  final bool oscuro;
  const _Planta({required this.oscuro});

  // Tonos: lejano (neblina), medio y cercano; el cercano es el más oscuro en claro y el más claro en oscuro.
  Color get _cielo1 => oscuro ? const Color(0xFF16233A) : const Color(0xFFDCE7F3);
  Color get _cielo2 => oscuro ? const Color(0xFF0E1726) : const Color(0xFFF2F6FB);
  Color get _lejos => oscuro ? const Color(0xFF22324A) : const Color(0xFFBFD0E2);
  Color get _medio => oscuro ? const Color(0xFF34496A) : const Color(0xFF8FA7C2);
  Color get _cerca => oscuro ? const Color(0xFF5C7699) : const Color(0xFF4F6A8C);
  Color get _luz => oscuro ? const Color(0xFF8FB0D6) : const Color(0xFFE9F0F8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final suelo = h * .9;

    // Cielo con un degradado suave.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cielo1, _cielo2],
        ).createShader(Offset.zero & size),
    );

    // Siluetas lejanas en la neblina.
    final lejos = Paint()..color = _lejos;
    final rnd = Random(7);
    var x = w * .18;
    while (x < w) {
      final ancho = w * (.03 + rnd.nextDouble() * .05);
      final alto = h * (.12 + rnd.nextDouble() * .22);
      canvas.drawRect(Rect.fromLTWH(x, suelo - alto, ancho, alto), lejos);
      if (rnd.nextBool()) {
        canvas.drawRect(Rect.fromLTWH(x + ancho * .4, suelo - alto - h * .12, ancho * .12, h * .12), lejos);
      }
      x += ancho + w * .01;
    }

    // Esfera de gas sobre patas.
    _esfera(canvas, Offset(w * .36, suelo - h * .2), h * .13, _medio);

    // Farola curva en primer plano.
    final farola = Paint()
      ..color = _medio
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, w * .003)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * .3, suelo)
        ..lineTo(w * .3, h * .3)
        ..quadraticBezierTo(w * .3, h * .24, w * .325, h * .24),
      farola,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .32, h * .235, w * .022, h * .022), const Radius.circular(2)),
      Paint()..color = _medio,
    );

    // Columnas de destilación (altas y finas, con plataformas).
    _columna(canvas, size, x: w * .46, ancho: w * .03, arriba: h * .14, color: _medio);
    _columna(canvas, size, x: w * .5, ancho: w * .022, arriba: h * .28, color: _medio);

    // Depósito grande: cilindro con cúpula, franjas y escalera.
    _deposito(canvas, size, izquierda: w * .58, ancho: w * .2, arriba: h * .3, suelo: suelo);

    // Columnas cercanas, más oscuras, y chimenea con su luz.
    _columna(canvas, size, x: w * .82, ancho: w * .036, arriba: h * .04, color: _cerca);
    _columna(canvas, size, x: w * .885, ancho: w * .026, arriba: h * .2, color: _cerca);
    final chimenea = Paint()..color = _cerca;
    canvas.drawPath(
      Path()
        ..moveTo(w * .945, suelo)
        ..lineTo(w * .952, h * .02)
        ..lineTo(w * .966, h * .02)
        ..lineTo(w * .973, suelo)
        ..close(),
      chimenea,
    );
    canvas.drawCircle(Offset(w * .959, h * .045), max(1.6, w * .004), Paint()..color = const Color(0xFFE5484D));

    // Rack de tuberías que cruza la planta.
    final tubo = Paint()
      ..color = _cerca
      ..strokeWidth = max(1.2, h * .012);
    for (final (i, y) in [h * .7, h * .745].indexed) {
      canvas.drawLine(Offset(w * (.22 + i * .04), y), Offset(w, y), tubo);
    }
    final soporte = Paint()
      ..color = _cerca
      ..strokeWidth = max(1, w * .0025);
    for (var sx = w * .24; sx < w; sx += w * .045) {
      canvas.drawLine(Offset(sx, h * .69), Offset(sx, suelo), soporte);
    }

    // Suelo.
    canvas.drawRect(Rect.fromLTWH(0, suelo, w, h - suelo), Paint()..color = _medio.withValues(alpha: .5));
  }

  void _columna(
    Canvas canvas,
    Size size, {
    required double x,
    required double ancho,
    required double arriba,
    required Color color,
  }) {
    final h = size.height, suelo = h * .9;
    final cuerpo = Rect.fromLTWH(x, arriba, ancho, suelo - arriba);
    // Sombreado de cilindro: más claro a la izquierda.
    canvas.drawRRect(
      RRect.fromRectAndCorners(cuerpo, topLeft: Radius.circular(ancho / 2), topRight: Radius.circular(ancho / 2)),
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(color, _luz, .35)!, color, Color.lerp(color, Colors.black, .12)!],
          stops: const [0, .55, 1],
        ).createShader(cuerpo),
    );
    // Plataformas con barandilla.
    final plataforma = Paint()
      ..color = color
      ..strokeWidth = max(1, h * .008);
    for (var y = arriba + (suelo - arriba) * .18; y < suelo - h * .08; y += (suelo - arriba) * .2) {
      canvas.drawLine(Offset(x - ancho * .45, y), Offset(x + ancho * 1.45, y), plataforma);
      final baranda = Paint()
        ..color = color.withValues(alpha: .7)
        ..strokeWidth = max(.8, h * .004);
      canvas.drawLine(Offset(x - ancho * .45, y - h * .03), Offset(x + ancho * 1.45, y - h * .03), baranda);
    }
  }

  void _deposito(
    Canvas canvas,
    Size size, {
    required double izquierda,
    required double ancho,
    required double arriba,
    required double suelo,
  }) {
    final h = size.height;
    final cuerpo = Rect.fromLTWH(izquierda, arriba, ancho, suelo - arriba);
    final sombreado = Paint()
      ..shader = LinearGradient(
        colors: [Color.lerp(_medio, _luz, .45)!, _medio, Color.lerp(_cerca, Colors.black, .05)!],
        stops: const [0, .5, 1],
      ).createShader(cuerpo);
    canvas.drawRect(cuerpo, sombreado);
    // Cúpula.
    canvas.drawOval(Rect.fromLTWH(izquierda, arriba - h * .05, ancho, h * .1), sombreado);
    // Franjas horizontales.
    final franja = Paint()
      ..color = _cerca.withValues(alpha: .35)
      ..strokeWidth = max(.8, h * .005);
    for (var y = arriba + h * .07; y < suelo; y += h * .07) {
      canvas.drawLine(Offset(izquierda, y), Offset(izquierda + ancho, y), franja);
    }
    // Escalera en espiral (un tramo en diagonal).
    final escalera = Paint()
      ..color = _cerca
      ..strokeWidth = max(1, h * .008);
    canvas.drawLine(Offset(izquierda + ancho * .1, suelo), Offset(izquierda + ancho * .78, arriba + h * .02), escalera);
  }

  void _esfera(Canvas canvas, Offset centro, double radio, Color color) {
    final patas = Paint()
      ..color = color
      ..strokeWidth = max(1, radio * .08);
    for (final dx in [-.7, -.25, .25, .7]) {
      canvas.drawLine(centro + Offset(radio * dx, radio * .4), centro + Offset(radio * dx * 1.1, radio * 1.55), patas);
    }
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.4),
          colors: [Color.lerp(color, _luz, .5)!, color],
        ).createShader(Rect.fromCircle(center: centro, radius: radio)),
    );
  }

  @override
  bool shouldRepaint(_Planta old) => old.oscuro != oscuro;
}
