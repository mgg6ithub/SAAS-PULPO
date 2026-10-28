import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'descarga_io.dart' if (dart.library.js_interop) 'descarga_web.dart';
import 'models.dart';
import 'nube.dart';
import 'store.dart';
import 'theme.dart';

/// Informe de un trabajo hecho por un trabajador. Con sesión vive en la tabla `informes` y sus fotos en Storage;
/// sin sesión (demo), en memoria con las fotos en base64.
class Informe {
  final String id, trabajoId;
  final String? trabajadorId;
  final int resultado;
  final String notas;

  /// Rutas del bucket `fotos` (con sesión) o JPEG en base64 (sin sesión).
  final List<String> fotos;
  final DateTime cuando;
  Informe({
    required this.id,
    required this.trabajoId,
    this.trabajadorId,
    required this.resultado,
    required this.notas,
    this.fotos = const [],
    DateTime? cuando,
  }) : cuando = cuando ?? DateTime.now();
}

const resultadosInforme = ['Todo correcto', 'Con incidencias', 'No se pudo hacer'];
const coloresResultado = [P.verde, P.ambar, P.rojo];

/// Fotos como mucho por informe.
const maxFotosInforme = 6;

/// Informes por trabajo: se piden a la base la primera vez que se ven y se guardan aquí.
class Informes extends ChangeNotifier {
  final _local = <Informe>[];
  final _de = <String, List<Informe>>{};
  final _pedidos = <String>{};
  Nube? _nube;

  /// Informes del trabajo, el más reciente primero (null = cargando).
  List<Informe>? de(String trabajoId) {
    final n = store.nube;
    if (n == null) {
      return [
        for (final i in _local.reversed)
          if (i.trabajoId == trabajoId) i,
      ];
    }
    if (n != _nube) {
      _nube = n;
      _de.clear();
      _pedidos.clear();
    }
    if (_pedidos.add(trabajoId)) {
      n
          .informes(trabajoId)
          .then(
            (l) {
              if (n != _nube) return;
              _de[trabajoId] = l;
              notifyListeners();
            },
            onError: (Object e) {
              debugPrint('Pulpo: no se pudieron leer los informes: $e');
              _pedidos.remove(trabajoId);
            },
          );
    }
    return _de[trabajoId];
  }

  /// Guarda el informe (y sube sus fotos, ya comprimidas).
  Future<void> crear({
    required String trabajoId,
    required String trabajadorId,
    required int resultado,
    required String notas,
    required List<Uint8List> fotos,
  }) async {
    final n = store.nube;
    if (n == null) {
      _local.add(
        Informe(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          trabajoId: trabajoId,
          trabajadorId: trabajadorId,
          resultado: resultado,
          notas: notas,
          fotos: [for (final f in fotos) base64Encode(f)],
        ),
      );
    } else {
      final i = await n.crearInforme(
        trabajoId: trabajoId,
        trabajadorId: trabajadorId,
        resultado: resultado,
        notas: notas,
        fotos: fotos,
      );
      if (_de[trabajoId] != null) _de[trabajoId] = [i, ..._de[trabajoId]!];
    }
    notifyListeners();
  }
}

final informes = Informes();

/// Bytes de una foto guardada: ruta del bucket `fotos` o base64 (demo y fotos antiguas).
Future<Uint8List> bytesFoto(String foto) async =>
    Nube.esRutaFoto(foto) ? await store.nube!.foto(foto) : base64Decode(foto);

/// Reduce una foto a 1280 px por el lado largo y la guarda en JPEG (calidad 75): unos 150-300 KB.
Future<Uint8List> comprimirFoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodecWithSize(
    await ui.ImmutableBuffer.fromUint8List(bytes),
    getTargetSize: (w, h) {
      final k = min(1.0, 1280 / max(w, h));
      return ui.TargetImageSize(width: (w * k).round(), height: (h * k).round());
    },
  );
  final imagen = (await codec.getNextFrame()).image;
  final rgba = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
  final i = img.Image.fromBytes(
    width: imagen.width,
    height: imagen.height,
    bytes: rgba!.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(i, quality: 75);
}

/// Foto guardada (ruta de Storage o base64), recortada a su caja. Mientras carga, un fondo suave.
class FotoGuardada extends StatefulWidget {
  final String foto;
  final double? width, height;
  const FotoGuardada(this.foto, {super.key, this.width, this.height});

  @override
  State<FotoGuardada> createState() => _FotoGuardadaState();
}

class _FotoGuardadaState extends State<FotoGuardada> {
  late Future<Uint8List> _bytes = bytesFoto(widget.foto);

  @override
  void didUpdateWidget(FotoGuardada old) {
    super.didUpdateWidget(old);
    if (old.foto != widget.foto) _bytes = bytesFoto(widget.foto);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) => s.hasData
        ? Image.memory(s.data!, width: widget.width, height: widget.height, fit: BoxFit.cover)
        : Container(width: widget.width, height: widget.height, color: P.fondo),
  );
}

/// Descarga el informe en PDF, para mandárselo al cliente.
Future<void> descargarInformePdf(Informe i, Tarea t) async {
  final nombre = 'Informe ${t.nombre} ${fecha(i.cuando)}'.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '');
  await descargar(await informePdf(i, t), '$nombre.pdf', 'application/pdf');
}

/// El informe en PDF: datos del trabajo, resultado, notas y fotos.
Future<Uint8List> informePdf(Informe i, Tarea t) async {
  final cliente = store.cliente(t.clienteId);
  final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
  final fotos = await Future.wait(i.fotos.map(bytesFoto));
  final doc = pw.Document();
  final morado = PdfColor.fromInt(P.morado.toARGB32());
  final suave = PdfColor.fromInt(0xFF6B7280);
  pw.Widget dato(String etiqueta, String valor) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(etiqueta, style: pw.TextStyle(color: suave, fontSize: 10)),
        ),
        pw.Expanded(child: pw.Text(valor, style: const pw.TextStyle(fontSize: 10.5))),
      ],
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text(
          (store.nube?.nombre ?? '').toUpperCase(),
          style: pw.TextStyle(color: morado, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Informe de trabajo', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        dato('Trabajo', t.nombre),
        if (cliente != null) dato('Cliente', cliente.nombre),
        dato('Dirección', t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '-')),
        dato('Fecha', '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}'),
        if (w != null) dato('Técnico', w.nombreCompleto),
        dato('Resultado', resultadosInforme[i.resultado]),
        pw.SizedBox(height: 14),
        pw.Text('Qué se ha hecho', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(i.notas, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
        if (fotos.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Text('Fotos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in fotos) pw.Image(pw.MemoryImage(f), width: 246, height: 184, fit: pw.BoxFit.cover),
            ],
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
