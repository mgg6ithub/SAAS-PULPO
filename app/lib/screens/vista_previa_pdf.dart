import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../forms.dart';
import '../informes.dart';
import '../plataforma_io.dart' if (dart.library.js_interop) '../plataforma_web.dart';
import '../theme.dart';
import '../widgets.dart';

/// Antes de descargar un PDF: a la izquierda se ve tal cual saldrá; a la derecha se retocan sus textos y fotos.
/// Lo retocado solo cambia el PDF, no la orden ni la incidencia guardadas.
Future<void> revisarPdf(
  BuildContext context, {
  required String titulo,
  required String archivo,
  required EdicionPdf edicion,
  required Future<Uint8List> Function(EdicionPdf) generar,
  String nombreDescripcion = 'Descripción',
  String nombreCuerpo = 'Trabajo realizado',
  bool conMaterial = false,
}) => showDialog(
  context: context,
  barrierColor: P.velo(),
  builder: (_) => _RevisarPdf(
    titulo: titulo,
    archivo: archivo,
    e: edicion,
    generar: generar,
    nombreDescripcion: nombreDescripcion,
    nombreCuerpo: nombreCuerpo,
    conMaterial: conMaterial,
  ),
);

class _RevisarPdf extends StatefulWidget {
  final String titulo, archivo, nombreDescripcion, nombreCuerpo;
  final EdicionPdf e;
  final Future<Uint8List> Function(EdicionPdf) generar;
  final bool conMaterial;
  const _RevisarPdf({
    required this.titulo,
    required this.archivo,
    required this.e,
    required this.generar,
    required this.nombreDescripcion,
    required this.nombreCuerpo,
    required this.conMaterial,
  });

  @override
  State<_RevisarPdf> createState() => _RevisarPdfState();
}

class _RevisarPdfState extends State<_RevisarPdf> {
  late final titulo = TextEditingController(text: widget.e.titulo);
  late final descripcion = TextEditingController(text: widget.e.descripcion);
  late final cuerpo = TextEditingController(text: widget.e.cuerpo);
  late final material = TextEditingController(text: widget.e.material);
  late final notas = TextEditingController(text: widget.e.notas);
  List<Uint8List> paginas = [];
  bool descargando = false, leyendo = false, fallo = false;
  Timer? _espera;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    for (final c in [titulo, descripcion, cuerpo, material, notas]) {
      c.addListener(_cambio);
    }
    _pintar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    for (final c in [titulo, descripcion, cuerpo, material, notas]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Al escribir, la vista previa se rehace cuando se deja de teclear un momento.
  void _cambio() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 450), _pintar);
  }

  void _volcar() => widget.e
    ..titulo = titulo.text.trim()
    ..descripcion = descripcion.text.trim()
    ..cuerpo = cuerpo.text.trim()
    ..material = material.text.trim()
    ..notas = notas.text.trim();

  Future<void> _pintar() async {
    final v = ++_version;
    _volcar();
    try {
      final bytes = await widget.generar(widget.e);
      final pags = <Uint8List>[];
      await for (final p in Printing.raster(bytes, dpi: 110)) {
        pags.add(await p.toPng());
      }
      if (mounted && v == _version) {
        setState(() {
          paginas = pags;
          fallo = false;
        });
      }
    } catch (err) {
      debugPrint('Pultec: no se pudo pintar la vista previa del PDF: $err');
      if (mounted && v == _version) setState(() => fallo = true);
    }
  }

  Future<void> _fotos() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (r == null || !mounted) return;
    setState(() => leyendo = true);
    try {
      for (final f in r.files) {
        if (f.bytes != null) widget.e.fotos.add(await comprimirFoto(f.bytes!));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer la foto.')));
      }
    }
    if (!mounted) return;
    setState(() => leyendo = false);
    _pintar();
  }

  void _quitarFoto(int n) {
    setState(() => widget.e.fotos.removeAt(n));
    _pintar();
  }

  Future<void> _descargar() async {
    if (descargando || leyendo) return;
    setState(() => descargando = true);
    _volcar();
    try {
      await descargar(await widget.generar(widget.e), widget.archivo, 'application/pdf');
      if (mounted) Navigator.pop(context);
    } catch (err) {
      debugPrint('Pultec: no se pudo crear el PDF: $err');
      if (mounted) {
        setState(() => descargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
        );
      }
    }
  }

  /// Foto con una X arriba a la derecha para quitarla del PDF.
  Widget _foto(int n) => SizedBox(
    width: 84,
    height: 84,
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(P.radio),
          child: Image.memory(widget.e.fotos[n], width: 84, height: 84, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Tooltip(
            message: 'Quitar del PDF',
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _quitarFoto(n),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _vistaPrevia() => ColoredBox(
    color: P.fondo,
    child: paginas.isEmpty
        ? Center(
            child: fallo
                ? Text('No se pudo mostrar la vista previa', style: TextStyle(color: P.textoSuave))
                : const CircularProgressIndicator(),
          )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final p in paginas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(color: P.borde)),
                        child: Image.memory(p, fit: BoxFit.contain, gaplessPlayback: true),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _formulario() => VentanaFormulario(
    incrustada: true,
    titulo: widget.titulo,
    textoGuardar: descargando ? 'Descargando…' : 'Descargar PDF',
    iconoGuardar: Icons.download_rounded,
    puedeGuardar: !descargando && !leyendo,
    onGuardar: _descargar,
    onCancelar: () => Navigator.pop(context),
    campos: [
      Bloque('Encabezado', primero: true, [
        campo('Título', titulo),
        campo(widget.nombreDescripcion, descripcion, lineas: 3),
      ]),
      Bloque(widget.nombreCuerpo, [
        campo(widget.nombreCuerpo, cuerpo, lineas: 4),
        if (widget.conMaterial) campo('Material y repuestos', material, lineas: 2),
      ]),
      Bloque('Notas', descripcion: 'Se añaden al final del PDF.', [
        campo('Notas', notas, lineas: 3, hint: 'Opcional'),
      ]),
      Bloque('Fotos', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 0; n < widget.e.fotos.length; n++) _foto(n),
            BotonAccion(
              leyendo ? 'Leyendo…' : 'Añadir fotos',
              icono: Icons.add_a_photo_outlined,
              onPressed: () {
                if (!leyendo && !descargando) _fotos();
              },
            ),
          ],
        ),
      ]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final ancho = pantalla.width > 980;
    return Dialog(
      insetPadding: EdgeInsets.all(ancho ? 32 : 0),
      clipBehavior: Clip.antiAlias,
      backgroundColor: P.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ancho ? 14 : 0)),
      child: SizedBox(
        width: min(1280, pantalla.width),
        height: pantalla.height * (ancho ? .9 : 1),
        child: ancho
            ? Row(
                children: [
                  Expanded(child: _vistaPrevia()),
                  SizedBox(width: 460, child: _formulario()),
                ],
              )
            : Column(
                children: [
                  SizedBox(height: pantalla.height * .4, child: _vistaPrevia()),
                  Expanded(child: _formulario()),
                ],
              ),
      ),
    );
  }
}
