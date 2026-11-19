import 'package:flutter/material.dart';

import '../theme.dart';

/// Foto de una refinería para la cabecera de Inicio en la vista mejorada. Se funde con el fondo por la
/// izquierda (donde va el título) y por abajo (donde empiezan las cifras), como en la maqueta.
///
/// El fundido son degradados del color del fondo pintados encima (no una máscara), y la foto empieza unos
/// píxeles a la derecha, bajo la parte opaca del degradado: así su borde nunca asoma como una raya vertical.
///
/// Origen: «Petron Bataan Refinery in Limay Bataan», Wikimedia Commons, licencia CC0 (dominio público, sin
/// atribución obligatoria). Reducida a 1600 px.
class FotoPlanta extends StatelessWidget {
  const FotoPlanta({super.key});

  @override
  Widget build(BuildContext context) {
    final f = P.fondo;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                left: 6,
                child: Image.asset(
                  'assets/planta.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(.2, -.1),
                  filterQuality: FilterQuality.medium,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [f, f, f.withValues(alpha: 0)], stops: const [0, .04, .5]),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [f.withValues(alpha: 0), f.withValues(alpha: 0), f],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
