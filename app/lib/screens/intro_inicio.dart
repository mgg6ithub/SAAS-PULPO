import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ajustes.dart';
import '../nube.dart' show Nube;
import '../theme.dart';

/// Presentación de Inicio la primera vez que se entra (una vez por cuenta y navegador): bienvenida con el nombre,
/// la fecha, el nombre de la empresa y la frase se escriben solos, y después los bloques entran uno a uno.
/// Todo cuelga de un único reloj ([t], en segundos desde el inicio); sin presentación, [t] es null y todo se ve
/// tal cual.
class IntroInicio {
  static final t = ValueNotifier<double?>(null);

  /// Cuándo se empieza a escribir la fecha (antes, la bienvenida).
  static const fecha = 1.5;

  /// Cuándo empiezan a entrar los bloques (lo fija la cabecera según lo que tarde en escribirse).
  static double resto = 3.5;

  /// Lo que tarda un bloque en entrar.
  static const entrada = .45;

  /// Con todo ya dentro, se recorren los primeros pasos de uno en uno (cada uno resaltado [porPaso] segundos) y,
  /// mientras, el borde discontinuo late entre morado y neutro.
  static double get recorrido => resto + 2.1;
  static const porPaso = .8, pasos = 4;
  static double get fin => recorrido + pasos * porPaso + .3;

  /// El paso resaltado ahora (o -1).
  static int pasoResaltado(double? t) {
    if (t == null || t < recorrido || t >= recorrido + pasos * porPaso) return -1;
    return ((t - recorrido) / porPaso).floor();
  }

  /// Cuánto morado lleva el borde discontinuo (0 = neutro, 1 = morado): late una vez por paso.
  static double latido(double? t) {
    if (pasoResaltado(t) < 0) return 0;
    return .5 - .5 * cos(2 * pi * (t! - recorrido) / porPaso);
  }
}

/// Envuelve Inicio: arranca el reloj si toca y pone la bienvenida encima.
class IntroInicioMarco extends StatefulWidget {
  final Widget child;

  /// Si puede salir (cuenta nueva, con la guía sin hacer). Aun así, solo la primera vez.
  final bool activa;
  const IntroInicioMarco({super.key, required this.activa, required this.child});

  @override
  State<IntroInicioMarco> createState() => _IntroInicioMarcoState();
}

class _IntroInicioMarcoState extends State<IntroInicioMarco> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _nombre = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    final usuario = Supabase.instance.client.auth.currentUser;
    if (!widget.activa || usuario == null || ajustes.introInicioVista(usuario.id)) return;
    // Se marca al empezar: aunque se cambie de vista a medias, no vuelve a salir.
    ajustes.marcarIntroInicio(usuario.id);
    _empezar();
  }

  /// Arranca (o vuelve a arrancar) la presentación desde el principio.
  void _empezar() {
    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) return;
    final correo = usuario.email ?? '';
    _nombre.value = correo.contains('@') ? correo.substring(0, correo.indexOf('@')) : correo;
    Nube.perfil().then((p) {
      if (p.nombre.trim().isNotEmpty) _nombre.value = p.nombre.trim().split(' ').first;
    }).catchError((_) {});
    IntroInicio.t.value = 0;
    _ticker?.dispose();
    _ticker = createTicker((e) {
      final s = e.inMicroseconds / 1e6;
      if (s > IntroInicio.fin) {
        _ticker?.stop();
        IntroInicio.t.value = null;
      } else {
        IntroInicio.t.value = s;
      }
    })..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con «reducir movimiento», sin presentación.
    if (MediaQuery.of(context).disableAnimations && IntroInicio.t.value != null) {
      _ticker?.stop();
      IntroInicio.t.value = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    if (IntroInicio.t.value != null) IntroInicio.t.value = null;
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      // TEMPORAL: botón para repetir la presentación mientras se ajusta. Quitar.
      Positioned(
        top: 12,
        right: 16,
        child: FilledButton.tonal(onPressed: _empezar, child: const Text('Repetir animación')),
      ),
      // La bienvenida, en el centro: entra con un leve zoom y se va antes de que empiece a escribirse la fecha.
      Positioned.fill(
        child: IgnorePointer(
          child: ValueListenableBuilder<double?>(
            valueListenable: IntroInicio.t,
            builder: (context, t, _) {
              if (t == null || t >= IntroInicio.fecha) return const SizedBox.shrink();
              final entra = Curves.easeOutCubic.transform((t / .4).clamp(0, 1));
              final sale = 1 - Curves.easeInCubic.transform(((t - 1.1) / .35).clamp(0, 1));
              return Opacity(
                opacity: entra * sale,
                child: Transform.scale(
                  scale: .96 + .04 * entra,
                  child: Center(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _nombre,
                      builder: (context, nombre, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Te damos la bienvenida',
                            style: TextStyle(color: P.textoSuave, fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nombre,
                            style: TextStyle(
                              fontFamily: P.titulos,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: P.morado,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

/// Texto que se escribe solo desde [desde] a [porSegundo] letras por segundo. Lo que falta se pinta transparente,
/// así el bloque ocupa desde el principio lo mismo y nada salta.
class Escribir extends StatelessWidget {
  final String texto;
  final TextStyle estilo;
  final double desde, porSegundo;
  const Escribir(this.texto, {super.key, required this.estilo, required this.desde, required this.porSegundo});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double?>(
    valueListenable: IntroInicio.t,
    builder: (context, t, _) {
      if (t == null) return Text(texto, style: estilo);
      final n = ((t - desde) * porSegundo).floor().clamp(0, texto.length);
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: texto.substring(0, n)),
            TextSpan(text: texto.substring(n), style: const TextStyle(color: Colors.transparent)),
          ],
        ),
        style: estilo,
      );
    },
  );
}

/// Bloque que entra (fundido y sube un poco) [retraso] segundos después de [IntroInicio.resto].
class Aparecer extends StatelessWidget {
  final double retraso;
  final Widget child;
  const Aparecer({super.key, this.retraso = 0, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double?>(
    valueListenable: IntroInicio.t,
    child: child,
    builder: (context, t, child) {
      if (t == null) return child!;
      final v = Curves.easeOutCubic.transform(
        ((t - IntroInicio.resto - retraso) / IntroInicio.entrada).clamp(0, 1),
      );
      return Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      );
    },
  );
}
