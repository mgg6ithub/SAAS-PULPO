import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'plataforma_io.dart' if (dart.library.js_interop) 'plataforma_web.dart';
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
  final String notas, material;

  /// Tiempo dedicado, en minutos (null = sin apuntar).
  final int? minutos;

  /// Rutas del bucket `fotos` (con sesión) o JPEG en base64 (sin sesión).
  final List<String> fotos;

  /// Firma del cliente en PNG (ruta o base64, como las fotos); null = sin firmar.
  final String? firma;
  final String firmante;
  final DateTime cuando;
  Informe({
    this.id = '',
    required this.trabajoId,
    this.trabajadorId,
    required this.resultado,
    required this.notas,
    this.material = '',
    this.minutos,
    this.fotos = const [],
    this.firma,
    this.firmante = '',
    DateTime? cuando,
  }) : cuando = cuando ?? DateTime.now();

  /// El mismo informe ya guardado: con su id, sus fotos y su firma guardadas y la hora de la base.
  Informe guardado({required String id, required List<String> fotos, String? firma, DateTime? cuando}) => Informe(
    id: id,
    trabajoId: trabajoId,
    trabajadorId: trabajadorId,
    resultado: resultado,
    notas: notas,
    material: material,
    minutos: minutos,
    fotos: fotos,
    firma: firma,
    firmante: firmante,
    cuando: cuando,
  );
}

/// «1 h 30 min», «45 min».
String duracionTexto(int minutos) =>
    [if (minutos >= 60) '${minutos ~/ 60} h', if (minutos % 60 != 0 || minutos == 0) '${minutos % 60} min'].join(' ');

const resultadosInforme = ['Todo correcto', 'Con incidencias', 'No se pudo hacer'];
const coloresResultado = [P.verde, P.ambar, P.rojo];

/// Fotos como mucho por informe.
const maxFotosInforme = 6;

/// Informes por trabajo: se piden a la base la primera vez que se ven y se guardan aquí.
class Informes extends ChangeNotifier {
  Informes() {
    // Otra persona ha hecho un parte: se vuelven a pedir los de cada trabajo al verlo.
    Nube.cambiado.addListener(() {
      if (!Nube.cambiado.value.contains('informes') || _pedidos.isEmpty) return;
      _de.clear();
      _pedidos.clear();
      notifyListeners();
    });
  }

  final _local = <Informe>[];
  final _de = <String, List<Informe>>{};
  final _pedidos = <String>{};
  Nube? _nube;

  /// Partes hechos sin conexión, guardados en el dispositivo hasta poder subirlos (fotos y firma en base64).
  List<Map<String, dynamic>>? _sinSubir;
  Timer? _reintento;
  static const _clave = 'pulpo_informes_sin_subir';

  /// El parte aún no se ha subido (se hizo sin conexión).
  bool sinSubir(Informe i) => _sinSubir?.any((x) => x['id'] == i.id) ?? false;

  Informe _deApunte(Map<String, dynamic> x) => Informe(
    id: x['id'],
    trabajoId: x['trabajo_id'],
    trabajadorId: x['trabajador_id'],
    resultado: x['resultado'],
    notas: x['notas'],
    material: x['material'],
    minutos: x['minutos'],
    fotos: List<String>.from(x['fotos'] as List),
    firma: x['firma'],
    firmante: x['firmante'],
    cuando: DateTime.parse(x['cuando'] as String),
  );

  Future<void> _apuntar() async {
    final prefs = await SharedPreferences.getInstance();
    final l = _sinSubir ?? [];
    l.isEmpty ? await prefs.remove(_clave) : await prefs.setString(_clave, jsonEncode(l));
  }

  Future<List<Map<String, dynamic>>> _apuntados() async => _sinSubir ??= [
    for (final x in jsonDecode((await SharedPreferences.getInstance()).getString(_clave) ?? '[]') as List)
      Map<String, dynamic>.from(x as Map),
  ];

  void _reintentar() {
    if (!(_reintento?.isActive ?? false)) _reintento = Timer(const Duration(seconds: 15), _subirApuntados);
  }

  /// Intenta subir los partes guardados en el dispositivo; si sigue sin conexión, vuelve a probar en 15 s.
  Future<void> _subirApuntados() async {
    _reintento?.cancel();
    final n = store.nube;
    if (n == null) return;
    final todos = [
      for (final x in await _apuntados())
        if (x['empresa_id'] == n.empresaId) x,
    ];
    if (todos.isEmpty) return;
    if (_de.isEmpty) notifyListeners(); // que se vean ya los que estaban en el dispositivo
    var cambio = false;
    Nube.subiendo.value = 'Subiendo partes…';
    for (final x in todos) {
      try {
        final g = await n.crearInforme(
          _deApunte(x),
          [for (final f in x['fotos'] as List) base64Decode(f as String)],
          x['firma'] == null ? null : base64Decode(x['firma'] as String),
          id: x['id'],
        );
        _sinSubir!.remove(x);
        await _apuntar();
        unawaited(_mandarParte(n, g));
        final l = _de[g.trabajoId];
        if (l != null) _de[g.trabajoId] = [g, ...l.where((i) => i.id != g.id)];
        cambio = true;
      } catch (e) {
        debugPrint('Pulpo: parte sin subir: $e');
        if (!Nube.sinConexion(e)) continue;
        _reintentar();
        break;
      }
    }
    Nube.subiendo.value = null;
    if (cambio) notifyListeners();
  }

  /// Manda el PDF del parte recién subido al cliente (si tiene correo, lo decide la función). Si falla no se
  /// avisa: el parte ya está guardado y se puede descargar desde el Histórico.
  Future<void> _mandarParte(Nube n, Informe g) async {
    final t = store.tarea(g.trabajoId);
    if (t == null) return;
    try {
      await n.enviarParte(g.id, await informePdf(g, t));
    } catch (e) {
      debugPrint('Pulpo: no se pudo mandar el parte al cliente: $e');
    }
  }

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
      _subirApuntados();
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
    final pendientes = [
      for (final x in _sinSubir ?? const <Map<String, dynamic>>[])
        if (x['empresa_id'] == n.empresaId && x['trabajo_id'] == trabajoId) _deApunte(x),
    ];
    final l = _de[trabajoId];
    if (pendientes.isEmpty) return l;
    return [...pendientes.reversed, ...?l?.where((i) => !pendientes.any((p) => p.id == i.id))];
  }

  /// Guarda el informe [i] (sin id) y sube sus fotos, ya comprimidas, y la firma. Sin conexión lo guarda
  /// en el dispositivo y lo sube al volver: devuelve false.
  Future<bool> crear(Informe i, {List<Uint8List> fotos = const [], Uint8List? firma}) async {
    final n = store.nube;
    if (n == null) {
      _local.add(
        i.guardado(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          fotos: [for (final f in fotos) base64Encode(f)],
          firma: firma == null ? null : base64Encode(firma),
        ),
      );
    } else {
      final id = store.nuevoId();
      try {
        final g = await n.crearInforme(i, fotos, firma, id: id);
        if (_de[i.trabajoId] != null) _de[i.trabajoId] = [g, ..._de[i.trabajoId]!];
        unawaited(_mandarParte(n, g));
      } catch (e) {
        if (!Nube.sinConexion(e)) rethrow;
        (await _apuntados()).add({
          'id': id,
          'empresa_id': n.empresaId,
          'trabajo_id': i.trabajoId,
          'trabajador_id': i.trabajadorId,
          'resultado': i.resultado,
          'notas': i.notas,
          'material': i.material,
          'minutos': i.minutos,
          'fotos': [for (final f in fotos) base64Encode(f)],
          'firma': firma == null ? null : base64Encode(firma),
          'firmante': i.firmante,
          'cuando': i.cuando.toIso8601String(),
        });
        await _apuntar();
        _reintentar();
        notifyListeners();
        return false;
      }
    }
    notifyListeners();
    return true;
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
  final BoxFit fit;
  const FotoGuardada(this.foto, {super.key, this.width, this.height, this.fit = BoxFit.cover});

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
        ? Image.memory(s.data!, width: widget.width, height: widget.height, fit: widget.fit)
        : Container(width: widget.width, height: widget.height, color: P.fondo),
  );
}

/// Descarga el informe en PDF, para mandárselo al cliente.
Future<void> descargarInformePdf(Informe i, Tarea t) async {
  final nombre = 'Parte ${t.nombre} ${fecha(i.cuando)}'.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '');
  await descargar(await informePdf(i, t), '$nombre.pdf', 'application/pdf');
}

/// El informe en PDF: datos del trabajo, resultado, notas y fotos.
Future<Uint8List> informePdf(Informe i, Tarea t) async {
  final cliente = store.cliente(t.clienteId);
  final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
  final fotos = await Future.wait(i.fotos.map(bytesFoto));
  final firma = i.firma == null ? null : await bytesFoto(i.firma!);
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
        pw.Text('Parte de trabajo', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        dato('Trabajo', t.nombre),
        if (cliente != null) dato('Cliente', cliente.nombre),
        dato('Dirección', t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '-')),
        dato('Fecha', '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}'),
        if (w != null) dato('Técnico', w.nombreCompleto),
        dato('Resultado', resultadosInforme[i.resultado]),
        if (i.minutos != null) dato('Tiempo', duracionTexto(i.minutos!)),
        pw.SizedBox(height: 14),
        pw.Text('Qué se ha hecho', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(i.notas, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
        if (i.material.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('Material', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(i.material, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
        ],
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
        if (firma != null) ...[
          pw.SizedBox(height: 18),
          pw.Text('Conforme, el cliente', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Image(pw.MemoryImage(firma), width: 200, height: 80, fit: pw.BoxFit.contain),
          if (i.firmante.isNotEmpty) pw.Text(i.firmante, style: const pw.TextStyle(fontSize: 10.5)),
        ],
      ],
    ),
  );
  return doc.save();
}
