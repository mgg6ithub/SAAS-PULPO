import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets.dart';

/// Foto de una refinería para la cabecera de Inicio en la vista mejorada. Se funde con el fondo por la
/// izquierda (donde va el título) y por abajo (donde empiezan las cifras), como en la maqueta.
///
/// En el centro, un recuadro discontinuo con una cámara abre los archivos del ordenador para poner un banner
/// propio en su lugar (se guarda en este navegador). Con banner propio, el recuadro solo sale al pasar el ratón.
///
/// El fundido son degradados del color del fondo pintados encima (no una máscara), y la foto empieza unos
/// píxeles a la derecha, bajo la parte opaca del degradado: así su borde nunca asoma como una raya vertical.
///
/// Origen: «Petron Bataan Refinery in Limay Bataan», Wikimedia Commons, licencia CC0 (dominio público, sin
/// atribución obligatoria). Reducida a 1600 px.
class FotoPlanta extends StatefulWidget {
  const FotoPlanta({super.key});

  @override
  State<FotoPlanta> createState() => _FotoPlantaState();
}

const _clave = 'pultec_banner';

class _FotoPlantaState extends State<FotoPlanta> {
  Uint8List? banner;
  bool encima = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final b = p.getString(_clave);
      if (b != null && mounted) setState(() => banner = base64Decode(b));
    });
  }

  Future<void> _subir() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = r?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    // Reducida a 1200 px de ancho para que quepa en el guardado del navegador.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
    final png = await (await codec.getNextFrame()).image.toByteData(format: ui.ImageByteFormat.png);
    final reducida = png!.buffer.asUint8List();
    if (!mounted) return;
    setState(() => banner = reducida);
    try {
      await (await SharedPreferences.getInstance()).setString(_clave, base64Encode(reducida));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final f = P.fondo;
    final radio = BorderRadius.circular(P.radioControl);
    return MouseRegion(
      onEnter: (_) => setState(() => encima = true),
      onExit: (_) => setState(() => encima = false),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      left: 6,
                      child: banner != null
                          ? Image.memory(banner!, fit: BoxFit.cover, filterQuality: FilterQuality.medium)
                          : Image.asset(
                              'assets/planta.jpg',
                              fit: BoxFit.cover,
                              // Algo menos de cielo: la cabecera es más baja.
                              alignment: const Alignment(.2, .1),
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
            // Algo a la derecha del centro: la parte izquierda se funde con el fondo.
            Align(
              alignment: const Alignment(.25, 0),
              child: AnimatedOpacity(
                opacity: banner == null || encima ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Tooltip(
                  message: 'Subir banner',
                  child: Material(
                    color: P.superficie.withValues(alpha: .85),
                    borderRadius: radio,
                    child: InkWell(
                      onTap: _subir,
                      borderRadius: radio,
                      child: CustomPaint(
                        painter: BordeDiscontinuo(P.textoSuave.withValues(alpha: .7), radio),
                        child: SizedBox(
                          width: 88,
                          height: 60,
                          child: Icon(Icons.photo_camera_outlined, size: 26, color: P.textoSuave),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
