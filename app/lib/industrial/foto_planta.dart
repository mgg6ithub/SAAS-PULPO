import 'package:flutter/material.dart';

/// Foto de una refinería para la cabecera de Inicio en la vista mejorada. Se funde con el fondo por la
/// izquierda (donde va el título) y por abajo (donde empiezan las cifras), como en la maqueta.
///
/// Origen: «Petron Bataan Refinery in Limay Bataan», Wikimedia Commons, licencia CC0 (dominio público, sin
/// atribución obligatoria). Reducida a 1600 px.
class FotoPlanta extends StatelessWidget {
  const FotoPlanta({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        // Los primeros píxeles del todo transparentes: si no, queda una raya fina en el borde de la foto.
        colors: [Colors.transparent, Colors.transparent, Colors.black, Colors.black],
        stops: [0, .04, .48, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, .6, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          'assets/planta.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(.2, -.1),
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}
