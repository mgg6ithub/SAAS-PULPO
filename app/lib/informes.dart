import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, LogicalKeyboardKey;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'plataforma_io.dart' if (dart.library.js_interop) 'plataforma_web.dart';
import 'models.dart';
import 'nube.dart';
import 'store.dart';
import 'theme.dart';
import 'marca.dart';
import 'industrial/activo.dart';
import 'industrial/activos.dart' show contadorTexto;
import 'industrial/estadisticas.dart' show numTexto, resumenActivo;
import 'industrial/gravedad.dart' show resultadoOt;
import 'industrial/incidencia.dart';
import 'industrial/mantenimientos.dart' show dondeEs;
import 'industrial/planes.dart' show horasRestantesPlan, proximoPlan, raizActivo;
import 'screens/vista_previa_pdf.dart' show revisarPdf;

/// Informe de un trabajo hecho por un trabajador. Con sesión vive en la tabla `informes` y sus fotos en Storage;
/// sin sesión (demo), en memoria con las fotos en base64.
class Informe {
  final String id, trabajoId;
  final String? trabajadorId;
  final int resultado;
  final String notas, material;

  /// Tiempo dedicado, en minutos (null = sin apuntar).
  final int? minutos;

  /// Valor medido, si su mantenimiento pide medición (null = sin medir).
  final double? valor;

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
    this.valor,
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
    valor: valor,
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

/// Icono de cada resultado del parte (sin puntos de color, que son de la criticidad).
const iconosResultado = [Icons.task_alt_rounded, Icons.report_outlined, Icons.block_rounded];

/// «7,2 mm/s»: el valor medido con la unidad de su mantenimiento.
String medidaTexto(Informe i, Tarea t) {
  final p = store.planes.where((x) => x.id == t.planId).firstOrNull;
  final v = i.valor!;
  final n = v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');
  return [n, if (p != null && p.medicionUnidad.isNotEmpty) p.medicionUnidad].join(' ');
}

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
    valor: (x['valor'] as num?)?.toDouble(),
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
        debugPrint('Pultec: parte sin subir: $e');
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
      debugPrint('Pultec: no se pudo mandar el parte al cliente: $e');
    }
  }

  Future<List<Informe>> delTecnico(String id) async {
    final nube = store.nube;
    if (nube != null) return nube.historialTecnico(id);
    return _local.where((i) => i.trabajadorId == id).toList()..sort((a, b) => b.cuando.compareTo(a.cuando));
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
              debugPrint('Pultec: no se pudieron leer los informes: $e');
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

  /// Valores medidos de un mantenimiento (en los partes de todas sus OT), del más antiguo al más reciente.
  Future<List<(DateTime, double)>> mediciones(String planId) async {
    final ots = [for (final t in [...store.tareas, ...store.subtareas]) if (t.planId == planId) t.id];
    final n = store.nube;
    if (n == null) {
      return [
        for (final i in _local)
          if (i.valor != null && ots.contains(i.trabajoId)) (i.cuando, i.valor!),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
    }
    return [for (final (d, v, _) in await n.mediciones(ots)) (d, v)];
  }

  /// Informes del trabajo ya leídos (para descargar su PDF sin esperar a que se pinten).
  Future<List<Informe>> cargar(String trabajoId) async {
    final n = store.nube;
    if (n == null) return de(trabajoId)!;
    return _de[trabajoId] ?? await n.informes(trabajoId);
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
          'valor': i.valor,
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

/// Fotos a pantalla completa: flechas (y las del teclado) para pasar, Esc o la X para cerrar.
Future<void> verFotos(BuildContext context, List<String> fotos, int inicio) => showDialog(
  context: context,
  barrierColor: Colors.black87,
  builder: (_) => _VisorFotos(fotos, inicio),
);

class _VisorFotos extends StatefulWidget {
  final List<String> fotos;
  final int inicio;
  const _VisorFotos(this.fotos, this.inicio);

  @override
  State<_VisorFotos> createState() => _VisorFotosState();
}

class _VisorFotosState extends State<_VisorFotos> {
  late int n = widget.inicio;

  void _ir(int d) {
    final nuevo = (n + d).clamp(0, widget.fotos.length - 1);
    if (nuevo != n) setState(() => n = nuevo);
  }

  Widget _flecha(IconData icono, VoidCallback? onTap) => IconButton.filled(
    style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
    onPressed: onTap,
    icon: Icon(icono),
  );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _ir(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _ir(1),
      const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
    },
    child: Focus(
      autofocus: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(80, 60, 80, 60),
                child: Center(child: FotoGuardada(widget.fotos[n], key: ValueKey(n), fit: BoxFit.contain)),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _flecha(Icons.close_rounded, () => Navigator.pop(context)),
          ),
          if (widget.fotos.length > 1) ...[
            Positioned(left: 16, top: 0, bottom: 0, child: Center(child: _flecha(Icons.chevron_left_rounded, n > 0 ? () => _ir(-1) : null))),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(child: _flecha(Icons.chevron_right_rounded, n < widget.fotos.length - 1 ? () => _ir(1) : null)),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${n + 1} / ${widget.fotos.length}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Lo que el administrador puede retocar del PDF antes de descargarlo. Solo cambia el PDF: la orden, el parte y
/// la incidencia guardados se quedan como estaban.
class EdicionPdf {
  String titulo, descripcion, cuerpo, material, notas;
  final List<Uint8List> fotos;
  EdicionPdf({
    required this.titulo,
    this.descripcion = '',
    this.cuerpo = '',
    this.material = '',
    this.notas = '',
    List<Uint8List>? fotos,
  }) : fotos = fotos ?? [];
}

String _nombreArchivo(String texto) => '${texto.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '')}.pdf';

/// Revisa el parte en PDF (vista previa editable) y lo descarga, para mandárselo al cliente.
Future<void> descargarInformePdf(BuildContext context, Informe i, Tarea t, {String? archivo}) async {
  final e = EdicionPdf(
    titulo: t.nombre,
    descripcion: t.descripcion,
    cuerpo: i.notas,
    material: i.material,
    fotos: await Future.wait(i.fotos.map(bytesFoto)),
  );
  if (!context.mounted) return;
  await revisarPdf(
    context,
    titulo: industrial ? 'Parte de orden de trabajo' : m('Parte de trabajo'),
    archivo: archivo ?? _nombreArchivo('Parte ${t.nombre} ${fecha(i.cuando)}'),
    edicion: e,
    nombreCuerpo: 'Trabajo realizado',
    conMaterial: true,
    generar: (e) => informePdf(i, t, e: e),
  );
}

/// El informe en PDF, como plantilla profesional: cabecera con el logo y la empresa, número y fecha; bloques
/// con la orden y el activo; ejecución con el resultado en color; trabajo, material, fotos y firmas; pie con página.
/// Con [e], lo retocado en la vista previa en lugar de lo guardado.
Future<Uint8List> informePdf(Informe i, Tarea t, {EdicionPdf? e}) async {
  final cliente = store.cliente(t.clienteId);
  final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
  final fotos = e?.fotos ?? await Future.wait(i.fotos.map(bytesFoto));
  final titulo = e?.titulo ?? t.nombre, descripcion = e?.descripcion ?? t.descripcion;
  final notas = e?.cuerpo ?? i.notas, material = e?.material ?? i.material, extra = e?.notas ?? '';
  final tecnicos = [for (final id in t.trabajadorIds) ?store.trabajador(id)?.nombreCompleto];
  final firma = i.firma == null ? null : await bytesFoto(i.firma!);
  final logo = await _logoPdf();
  final plan = t.planId == null ? null : store.planes.where((p) => p.id == t.planId).firstOrNull;
  final raiz = industrial ? raizActivo(t.activoId) : null;
  final componente = industrial ? store.activo(t.activoId) : null;
  final empresa = store.nube?.nombre ?? '';
  final numero = 'OT-${t.id.replaceAll('-', '').toUpperCase().substring(0, min(8, t.id.replaceAll('-', '').length))}';
  // OT que resuelve una incidencia: el parte lleva también lo que se comunicó y sus fotos.
  final incidencia = industrial ? store.incidenciaDeOt(t.id) : null;
  final fotosIncidencia = incidencia == null ? const <Uint8List>[] : await Future.wait(incidencia.fotos.map(bytesFoto));

  final doc = pw.Document(title: 'Parte ${t.nombre}', author: empresa.isEmpty ? Marca.nombre : empresa);
  final marcaSuave = PdfColor.fromInt(Color.alphaBlend(P.morado.withValues(alpha: .08), Colors.white).toARGB32());
  final tinta = PdfColor.fromInt(0xFF111827);
  final suave = PdfColor.fromInt(0xFF6B7280);
  final base = [P.verde, P.ambar, P.rojo][i.resultado.clamp(0, 2)];

  const etiqueta = _etiquetaPdf, dato = _datoPdf, tarjeta = _tarjetaPdf, seccion = _seccionPdf;

  pw.Widget firmaBloque(String titulo, String nombre, {Uint8List? imagen}) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        etiqueta(titulo),
        pw.SizedBox(
          height: 70,
          child: imagen == null
              ? pw.SizedBox()
              : pw.Align(
                  alignment: pw.Alignment.bottomLeft,
                  child: pw.Image(pw.MemoryImage(imagen), height: 64, fit: pw.BoxFit.contain),
                ),
        ),
        pw.Container(height: .8, color: tinta),
        pw.SizedBox(height: 4),
        pw.Text(nombre.isEmpty ? ' ' : nombre, style: pw.TextStyle(fontSize: 9.5, color: suave)),
      ],
    ),
  );

  doc.addPage(
    _paginaPdf(
      logo: logo,
      empresa: empresa,
      titulo: industrial ? 'Parte de orden de trabajo' : m('Parte de trabajo'),
      numero: numero,
      cuando: '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}',
      build: (_) => [
        // Título de la orden y su descripción, con el resultado a la derecha.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    titulo,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: tinta),
                  ),
                  if (descripcion.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(descripcion, style: pw.TextStyle(fontSize: 11, color: suave)),
                  ],
                ],
              ),
            ),
            // Siempre el resultado, como el estado en el informe de incidencia.
            pw.SizedBox(width: 16),
            _pildoraPdf(i.resultado == 0 ? 'Completada' : resultadosInforme[i.resultado], base),
          ],
        ),
        if (incidencia != null) ...[
          seccion('Incidencia original', '${incidencia.descripcion}\n\n${_comunicada(incidencia)}'),
          if (fotosIncidencia.isNotEmpty) ...[pw.SizedBox(height: 8), _fotosPdf(fotosIncidencia)],
        ],
        pw.SizedBox(height: 18),
        // Dos tarjetas: la orden y dónde se hizo.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: tarjeta(industrial ? 'Orden de trabajo' : m('Trabajo'), [
                dato('Número', numero),
                if (industrial && t.tipoMantenimiento != null)
                  _datoPuntoPdf('Criticidad', t.tipoMantenimiento!.etiqueta, t.tipoMantenimiento!.color),
                if (industrial)
                  dato('Origen', incidencia != null ? 'Incidencia' : plan != null ? 'Mantenimiento' : 'Manual'),
                if (plan != null) dato('Mantenimiento', [plan.nombre, if (plan.cada.isNotEmpty) plan.cada].join(', ')),
                if (t.proximo != null || t.ultimo != null) dato('Fecha prevista', fecha(t.proximo ?? t.ultimo)),
                if (industrial && tecnicos.isNotEmpty) dato('Asignada a', tecnicos.join(', ')),
                if (industrial)
                  _datoPuntoPdf('Resultado', resultadosInforme[i.resultado.clamp(0, 2)], base),
              ]),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: industrial
                  ? tarjeta('Activo', _datosActivoPdf(raiz, componente, t.ubicacion))
                  : tarjeta(m('Cliente'), [
                      dato(m('Cliente'), cliente?.nombre ?? '-'),
                      dato('Dirección', t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '-')),
                    ]),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        // Ejecución en una franja suave del color de la marca.
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 6),
          decoration: pw.BoxDecoration(color: marcaSuave, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: dato('Realizado el', '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}'),
              ),
              pw.Expanded(child: dato('Técnico', w?.nombreCompleto ?? '-')),
              pw.Expanded(child: dato('Tiempo', i.minutos == null ? '-' : duracionTexto(i.minutos!))),
            ],
          ),
        ),
        // Lo que pasó, en orden: de la avería (o el mantenimiento) a la orden cerrada.
        if (industrial) ...[
          pw.SizedBox(height: 16),
          etiqueta('Historial'),
          pw.SizedBox(height: 8),
          for (final (cuando, texto) in cronologiaOt(t, i)) _pasoPdf(cuando, texto),
        ],
        seccion('Trabajo realizado', notas.isEmpty ? 'Sin observaciones.' : notas),
        if (i.valor != null)
          seccion(
            plan != null && plan.conMedicion ? plan.medicionNombre : 'Medición',
            medidaTexto(i, t),
          ),
        if (material.isNotEmpty) seccion('Material y repuestos', material),
        if (extra.isNotEmpty) seccion('Notas', extra),
        if (fotos.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          etiqueta('Fotos'),
          pw.SizedBox(height: 8),
          _fotosPdf(fotos),
        ],
        pw.SizedBox(height: 28),
        // Firmas: el técnico que lo hizo y quien lo da por bueno.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Pultec: firma el técnico que la hizo (su firma y su nombre).
            if (industrial)
              firmaBloque('Firma del técnico', w?.nombreCompleto ?? i.firmante, imagen: firma)
            else ...[
              firmaBloque('Técnico', w?.nombreCompleto ?? ''),
              pw.SizedBox(width: 40),
              firmaBloque(m('Conforme, el cliente'), i.firmante, imagen: firma),
            ],
            if (industrial) pw.Expanded(child: pw.SizedBox()),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Cronología de una OT cerrada: incidencia comunicada (si la hay), orden creada, asignada y realizada.
List<(String, String)> cronologiaOt(Tarea t, Informe i) {
  String cuando(DateTime d) => '${fecha(d)} ${hhmm(d.hour * 60 + d.minute)}';
  final x = industrial ? store.incidenciaDeOt(t.id) : null;
  final plan = t.planId == null ? null : store.planes.where((p) => p.id == t.planId).firstOrNull;
  final tecnicos = [for (final id in t.trabajadorIds) ?store.trabajador(id)?.nombreCompleto];
  final w = store.trabajadores.where((y) => y.id == i.trabajadorId).firstOrNull;
  return [
    if (x != null)
      (
        cuando(x.creada),
        'Incidencia comunicada por ${(x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!))?.nombreCompleto ?? 'la oficina'}'
            ' (${x.gravedad.etiqueta.toLowerCase()}): ${x.descripcion}',
      ),
    if (x != null)
      ('', 'Se crea esta orden de trabajo para resolverla${t.proximo == null ? '' : ', prevista para el ${fecha(t.proximo)}'}.')
    else if (plan != null)
      ('', 'Orden creada sola por el mantenimiento «${plan.nombre}»${plan.cada.isEmpty ? '' : ' (${plan.cada})'}.')
    else
      ('', 'Orden creada a mano${t.proximo == null ? '' : ', prevista para el ${fecha(t.proximo)}'}.'),
    if (tecnicos.isNotEmpty) ('', 'Asignada a ${tecnicos.join(', ')}.'),
    (
      cuando(i.cuando),
      'Realizada por ${w?.nombreCompleto ?? 'el técnico'}${i.minutos == null ? '' : ' en ${duracionTexto(i.minutos!)}'}'
          '${i.resultado == 0 ? '' : ' (${resultadosInforme[i.resultado].toLowerCase()})'}.',
    ),
  ];
}

/// Un paso de la cronología: punto morado, fecha (si la hay) y texto.
pw.Widget _pasoPdf(String cuando, String texto) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 3.5, right: 8),
        width: 5,
        height: 5,
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(P.morado.toARGB32()), shape: pw.BoxShape.circle),
      ),
      if (cuando.isNotEmpty)
        pw.SizedBox(width: 92, child: pw.Text(cuando, style: pw.TextStyle(fontSize: 9.5, color: _suavePdf))),
      pw.Expanded(child: pw.Text(texto, style: pw.TextStyle(fontSize: 10, color: _tintaPdf))),
    ],
  ),
);

/// Dato con un punto de color delante (p. ej. la criticidad).
pw.Widget _datoPuntoPdf(String nombre, String valor, Color color) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 7),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(nombre, style: pw.TextStyle(fontSize: 8.5, color: _suavePdf)),
      pw.SizedBox(height: 1.5),
      pw.Row(children: [
        pw.Container(
          width: 6,
          height: 6,
          margin: const pw.EdgeInsets.only(right: 5),
          decoration: pw.BoxDecoration(color: PdfColor.fromInt(color.toARGB32()), shape: pw.BoxShape.circle),
        ),
        pw.Text(valor, style: pw.TextStyle(fontSize: 11, color: _tintaPdf)),
      ]),
    ],
  ),
);

// ── Piezas comunes de los PDF (parte de OT e informe de incidencia) ──
final _tintaPdf = PdfColor.fromInt(0xFF111827);
final _suavePdf = PdfColor.fromInt(0xFF6B7280);
final _bordePdf = PdfColor.fromInt(0xFFE5E7EB);

pw.Widget _etiquetaPdf(String texto) => pw.Text(
  texto.toUpperCase(),
  style: pw.TextStyle(fontSize: 7.5, color: _suavePdf, fontWeight: pw.FontWeight.bold, letterSpacing: .8),
);

pw.Widget _datoPdf(String nombre, String valor) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 7),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(nombre, style: pw.TextStyle(fontSize: 8.5, color: _suavePdf)),
      pw.SizedBox(height: 1.5),
      pw.Text(valor.isEmpty ? '-' : valor, style: pw.TextStyle(fontSize: 10.5, color: _tintaPdf)),
    ],
  ),
);

pw.Widget _tarjetaPdf(String titulo, List<pw.Widget> hijos) => pw.Container(
  padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 6),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _bordePdf, width: .8),
    borderRadius: pw.BorderRadius.circular(6),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [_etiquetaPdf(titulo), pw.SizedBox(height: 8), ...hijos],
  ),
);

/// Estado o resultado arriba a la derecha: etiqueta rectangular de esquinas suaves, fondo claro, borde y punto
/// del color (el radio no pasa de la mitad del alto: si no, el PDF pinta picos en los lados).
pw.Widget _pildoraPdf(String texto, Color color) {
  final c = PdfColor.fromInt(color.toARGB32());
  PdfColor mezcla(double a) => PdfColor.fromInt(Color.alphaBlend(color.withValues(alpha: a), Colors.white).toARGB32());
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 6),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: pw.BoxDecoration(
      color: mezcla(.08),
      border: pw.Border.all(color: mezcla(.35), width: .8),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
        pw.SizedBox(width: 6),
        pw.Text(texto.toUpperCase(),
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: c, letterSpacing: .6)),
      ],
    ),
  );
}

pw.Widget _seccionPdf(String titulo, String texto) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 14),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _etiquetaPdf(titulo),
      pw.SizedBox(height: 6),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(texto, style: pw.TextStyle(fontSize: 10.5, color: _tintaPdf, lineSpacing: 2.5)),
      ),
    ],
  ),
);

pw.Widget _fotosPdf(List<Uint8List> fotos) => pw.Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final f in fotos)
      pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Image(pw.MemoryImage(f), width: 253, height: 180, fit: pw.BoxFit.cover),
      ),
  ],
);

/// Página A4 de todos los PDF: cabecera con logo, marca y empresa a la izquierda; título, número y fecha a la
/// derecha; raya del color de la marca. Pie con la fecha de generación y la página.
pw.MultiPage _paginaPdf({
  required Uint8List? logo,
  required String empresa,
  required String titulo,
  required String numero,
  required String cuando,
  required List<pw.Widget> Function(pw.Context) build,
  PdfPageFormat formato = PdfPageFormat.a4,
}) {
  final marca = PdfColor.fromInt(P.morado.toARGB32());
  return pw.MultiPage(
    pageFormat: formato,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    header: (context) => pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[pw.Image(pw.MemoryImage(logo), width: 34, height: 34), pw.SizedBox(width: 10)],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(Marca.nombre, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _tintaPdf)),
                if (empresa.isNotEmpty) pw.Text(empresa, style: pw.TextStyle(fontSize: 9.5, color: _suavePdf)),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(titulo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _tintaPdf)),
                pw.SizedBox(height: 2),
                pw.Text(numero, style: pw.TextStyle(fontSize: 9, color: _suavePdf)),
                pw.Text(cuando, style: pw.TextStyle(fontSize: 9, color: _suavePdf)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: marca),
        pw.SizedBox(height: 18),
      ],
    ),
    footer: (context) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        children: [
          pw.Text('Generado con ${Marca.nombre} el ${fecha(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: _suavePdf)),
          pw.Spacer(),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: _suavePdf)),
        ],
      ),
    ),
    build: build,
  );
}

Future<Uint8List?> _logoPdf() async {
  try {
    // El pulpo morado, como en la app.
    return (await rootBundle.load('assets/pultec.png')).buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// «Comunicada por Ana el 18/11/2026.»
String _comunicada(Incidencia x) =>
    'Comunicada por ${(x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!))?.nombreCompleto ?? 'la oficina'} el ${fecha(x.creada)}.';

/// Datos del activo para las tarjetas del PDF: activo, componente, tag, fabricante y modelo, número de serie,
/// división y ubicación (solo los que tiene).
List<pw.Widget> _datosActivoPdf(Activo? raiz, Activo? componente, String ubicacion) {
  final fabricante = [?raiz?.fabricante, ?raiz?.modelo].where((s) => s.isNotEmpty).join(' ');
  return [
    _datoPdf('Activo', raiz?.titulo ?? '-'),
    if (componente != null && componente.id != raiz?.id) _datoPdf('Componente', componente.titulo),
    if (fabricante.isNotEmpty) _datoPdf('Fabricante y modelo', fabricante),
    if (raiz != null && raiz.numeroSerie.isNotEmpty) _datoPdf('Número de serie', raiz.numeroSerie),
    if (raiz != null && raiz.division.isNotEmpty) _datoPdf('División', raiz.division),
    if (ubicacion.isNotEmpty) _datoPdf('Ubicación', ubicacion),
  ];
}

String _quien(String? id) => (id == null ? null : store.trabajador(id))?.nombreCompleto ?? 'la oficina';

/// En qué quedó la incidencia, en texto (se puede retocar antes de descargar).
String _resolucionIncidencia(Incidencia x) {
  final ot = store.tarea(x.trabajoId);
  return switch (store.estadoIncidencia(x)) {
    EstadoIncidencia.abierta => 'Pendiente de revisión por la oficina.',
    EstadoIncidencia.desestimada =>
      'Desestimada${x.cerradaEl == null ? '' : ' el ${fecha(x.cerradaEl!)}'}: no hizo falta intervenir.',
    final estado when ot != null => estado == EstadoIncidencia.completada
        ? 'Resuelta con la orden de trabajo «${ot.nombre}»${ot.ultimo == null ? '' : ', completada el ${fecha(ot.ultimo!)}'}.'
        : 'Se ha creado la orden de trabajo «${ot.nombre}» para resolverla'
              '${ot.proximo == null ? '' : ', prevista para el ${fecha(ot.proximo!)}'}.',
    final estado => estado.etiqueta,
  };
}

/// Revisa el informe de una incidencia (vista previa editable) y lo descarga. Con OT y parte, el parte de la OT
/// (que ya lleva la incidencia y sus fotos); si no, la incidencia, sus fotos y en qué quedó.
Future<void> descargarInformeIncidencia(BuildContext context, Incidencia x) async {
  final ot = store.tarea(x.trabajoId);
  final parte = ot == null ? null : (await informes.cargar(ot.id)).firstOrNull;
  if (!context.mounted) return;
  final archivo = _nombreArchivo('Incidencia ${dondeEs(x.activoId)} ${fecha(x.creada)}');
  if (parte != null) return descargarInformePdf(context, parte, ot!, archivo: archivo);
  final e = EdicionPdf(
    titulo: 'Incidencia en ${raizActivo(x.activoId)?.titulo ?? 'el activo'}',
    descripcion: x.descripcion,
    cuerpo: _resolucionIncidencia(x),
    fotos: await Future.wait(x.fotos.map(bytesFoto)),
  );
  if (!context.mounted) return;
  await revisarPdf(
    context,
    titulo: 'Informe de incidencia',
    archivo: archivo,
    edicion: e,
    nombreDescripcion: 'Qué ocurre',
    nombreCuerpo: 'Resolución',
    generar: (e) => incidenciaPdf(x, e: e),
  );
}

/// La incidencia en PDF (sin parte de OT): qué pasó y dónde, quién y cuándo la comunicó, fotos, la orden que la
/// resuelve, el historial y en qué quedó. Con [e], lo retocado en la vista previa.
Future<Uint8List> incidenciaPdf(Incidencia x, {EdicionPdf? e}) async {
  final fotos = e?.fotos ?? await Future.wait(x.fotos.map(bytesFoto));
  final estado = store.estadoIncidencia(x);
  final ot = store.tarea(x.trabajoId);
  final origen = store.tarea(x.origenTrabajoId);
  final plan = store.planes.where((p) => p.id == x.planId).firstOrNull;
  final raiz = raizActivo(x.activoId);
  final componente = store.activo(x.activoId);
  final empresa = store.nube?.nombre ?? '';
  final limpio = x.id.replaceAll('-', '').toUpperCase();
  final numero = 'INC-${limpio.substring(0, min(8, limpio.length))}';
  final marcaSuave = PdfColor.fromInt(Color.alphaBlend(P.morado.withValues(alpha: .08), Colors.white).toARGB32());
  String cuando(DateTime d) => '${fecha(d)} ${hhmm(d.hour * 60 + d.minute)}';
  final titulo = e?.titulo ?? 'Incidencia en ${raiz?.titulo ?? 'el activo'}';
  final descripcion = e?.descripcion ?? x.descripcion;
  final resolucion = e?.cuerpo ?? _resolucionIncidencia(x);
  final notas = e?.notas ?? '';
  final tecnicosOt = ot == null ? const <String>[] : [for (final id in ot.trabajadorIds) ?store.trabajador(id)?.nombreCompleto];
  final otLimpio = ot?.id.replaceAll('-', '').toUpperCase() ?? '';
  // Lo que pasó, en orden: de la avería comunicada a la orden (o a desestimarla).
  final historial = <(String, String)>[
    (cuando(x.creada), 'Comunicada por ${_quien(x.tecnicoId)}${origen == null ? '' : ' durante la orden «${origen.nombre}»'}.'),
    if (x.editadaEl != null) (cuando(x.editadaEl!), 'Corregida por quien la comunicó.'),
    if (ot != null) ('', 'Se crea la orden de trabajo «${ot.nombre}»${ot.proximo == null ? '' : ', prevista para el ${fecha(ot.proximo!)}'}.'),
    if (tecnicosOt.isNotEmpty) ('', 'Asignada a ${tecnicosOt.join(', ')}.'),
    if (estado == EstadoIncidencia.completada)
      (x.cerradaEl == null ? '' : cuando(x.cerradaEl!), 'Incidencia resuelta.'),
    if (estado == EstadoIncidencia.desestimada)
      (x.cerradaEl == null ? '' : cuando(x.cerradaEl!), 'Desestimada por la oficina.'),
  ];
  final doc = pw.Document(title: 'Incidencia $numero', author: empresa.isEmpty ? Marca.nombre : empresa);
  doc.addPage(
    _paginaPdf(
      logo: await _logoPdf(),
      empresa: empresa,
      titulo: 'Informe de incidencia',
      numero: numero,
      cuando: cuando(x.creada),
      build: (_) => [
        // Título con el estado a la derecha, como el parte de la OT.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(titulo, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _tintaPdf)),
            ),
            pw.SizedBox(width: 16),
            _pildoraPdf(estado.etiqueta, estado.color),
          ],
        ),
        _seccionPdf('Qué ocurre', descripcion.isEmpty ? 'Sin descripción.' : descripcion),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _tarjetaPdf('Incidencia', [
                _datoPdf('Número', numero),
                _datoPuntoPdf('Gravedad', x.gravedad.etiqueta, x.gravedad.color),
                _datoPdf('Comunicada por', _quien(x.tecnicoId)),
                _datoPdf('Fecha y hora', cuando(x.creada)),
                if (origen != null) _datoPdf('Detectada durante', origen.nombre),
                if (plan != null) _datoPdf('Mantenimiento vinculado', plan.nombre),
              ]),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _tarjetaPdf('Activo', _datosActivoPdf(raiz, componente, ''))),
          ],
        ),
        if (ot != null) ...[
          pw.SizedBox(height: 12),
          // La orden que la resuelve, en una franja suave del color de la marca.
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 6),
            decoration: pw.BoxDecoration(color: marcaSuave, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _etiquetaPdf('Orden de trabajo'),
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 2, child: _datoPdf(ot.nombre, 'OT-${otLimpio.substring(0, min(8, otLimpio.length))}')),
                    pw.Expanded(child: _datoPdf('Estado', ot.estado.etiqueta)),
                    pw.Expanded(
                      child: _datoPdf(
                        ot.estado == EstadoTrabajo.realizado ? 'Completada el' : 'Prevista',
                        fecha(ot.estado == EstadoTrabajo.realizado ? ot.ultimo : ot.proximo),
                      ),
                    ),
                    pw.Expanded(flex: 2, child: _datoPdf('Asignada a', tecnicosOt.isEmpty ? 'Sin asignar' : tecnicosOt.join(', '))),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (fotos.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _etiquetaPdf('Fotos'),
          pw.SizedBox(height: 8),
          _fotosPdf(fotos),
        ],
        pw.SizedBox(height: 16),
        _etiquetaPdf('Historial'),
        pw.SizedBox(height: 8),
        for (final (c, texto) in historial) _pasoPdf(c, texto),
        _seccionPdf('Resolución', resolucion.isEmpty ? '-' : resolucion),
        if (notas.isNotEmpty) _seccionPdf('Notas', notas),
      ],
    ),
  );
  return doc.save();
}

/// Guía de importación en PDF: para qué sirve, cómo rellenarla en tres pasos y una tabla con cada columna (si
/// es obligatoria, qué lleva y un ejemplo). [guia] lleva la cabecera en la primera fila.
Future<Uint8List> guiaPdf(String que, List<List<String>> guia, {List<String> notas = const []}) async {
  final empresa = store.nube?.nombre ?? '';
  final doc = pw.Document(title: 'Guía para importar $que', author: empresa.isEmpty ? Marca.nombre : empresa);
  final marca = PdfColor.fromInt(P.morado.toARGB32());
  final marcaSuave = PdfColor.fromInt(Color.alphaBlend(P.morado.withValues(alpha: .08), Colors.white).toARGB32());
  pw.Widget paso(int n, String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 16,
          height: 16,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: marca, shape: pw.BoxShape.circle),
          child: pw.Text('$n', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Text(texto, style: pw.TextStyle(fontSize: 10, color: _tintaPdf))),
      ],
    ),
  );
  pw.Widget celda(String t, {bool cab = false, bool negrita = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    child: pw.Text(
      // La letra del PDF no trae «…».
      t.replaceAll('…', '...'),
      style: pw.TextStyle(
        fontSize: cab ? 8.5 : 9.5,
        color: color ?? (cab ? _suavePdf : _tintaPdf),
        fontWeight: cab || negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
  doc.addPage(
    _paginaPdf(
      logo: await _logoPdf(),
      empresa: empresa,
      titulo: 'Guía para importar',
      numero: que,
      cuando: fecha(DateTime.now()),
      build: (_) => [
        pw.Text('Cómo importar $que', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _tintaPdf)),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: marcaSuave, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              paso(1, 'Descarga la plantilla en Excel (trae esta guía en la hoja «Guía») o en CSV.'),
              paso(2, 'Rellena una fila por cada elemento. El orden de las columnas da igual y las que no uses pueden faltar.'),
              paso(3, 'En ${Marca.nombre}, «Elegir archivo» con tu Excel, CSV o JSON: verás lo que se va a crear y los avisos por fila antes de guardar.'),
            ],
          ),
        ),
        for (final n in notas) ...[
          pw.SizedBox(height: 8),
          pw.Text(n, style: pw.TextStyle(fontSize: 10, color: _suavePdf)),
        ],
        pw.SizedBox(height: 16),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(5),
            3: pw.FlexColumnWidth(2.4),
          },
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _bordePdf, width: .6)),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _tintaPdf, width: .8))),
              children: [for (final c in guia.first) celda(c, cab: true)],
            ),
            for (final f in guia.skip(1))
              pw.TableRow(
                children: [
                  celda(f[0], negrita: true),
                  celda(f[1], color: f[1] == 'Sí' ? marca : _suavePdf, negrita: f[1] == 'Sí'),
                  celda(f[2].isEmpty ? '-' : f[2]),
                  celda(f[3], color: _suavePdf),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Listado en PDF (exportar activos, técnicos…): A4 en horizontal con la cabecera de la empresa y una tabla.
Future<Uint8List> listadoPdf(String titulo, List<List<String>> conCabecera) async {
  final empresa = store.nube?.nombre ?? '';
  final doc = pw.Document(title: titulo, author: empresa.isEmpty ? Marca.nombre : empresa);
  final logo = await _logoPdf();
  pw.Widget celda(String t, {bool cab = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: cab ? 8 : 8.5,
        color: cab ? _suavePdf : _tintaPdf,
        fontWeight: cab ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
  final filas = conCabecera.length - 1;
  doc.addPage(_paginaPdf(
    formato: PdfPageFormat.a4.landscape,
    logo: logo,
    empresa: empresa,
    titulo: titulo,
    numero: '$filas ${filas == 1 ? 'fila' : 'filas'}',
    cuando: fecha(DateTime.now()),
    build: (_) => [
      if (filas == 0)
        pw.Text('No hay nada que listar.', style: pw.TextStyle(fontSize: 10, color: _suavePdf))
      else
        pw.Table(
          // Cada columna, ancha según lo que lleva (un día del mes, estrecho; un nombre, ancho).
          columnWidths: {
            for (var i = 0; i < conCabecera.first.length; i++)
              i: pw.FlexColumnWidth(
                conCabecera.map((f) => i < f.length ? f[i].length : 0).fold(0, max).clamp(2, 30).toDouble(),
              ),
          },
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _bordePdf, width: .6)),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _tintaPdf, width: .8))),
              children: [for (final c in conCabecera.first) celda(c, cab: true)],
            ),
            for (final f in conCabecera.skip(1)) pw.TableRow(children: [for (final c in f) celda(c)]),
          ],
        ),
    ],
  ));
  return doc.save();
}

/// Resumen de un activo en PDF (Estadísticas): cifras del periodo, contador, sus mantenimientos (cada cuánto,
/// último, próximo y cuántos se han hecho), las órdenes hechas y sus incidencias.
Future<void> descargarResumenActivo(Activo a, DateTime desde, int dias) async {
  final r = resumenActivo(a, desde);
  final empresa = store.nube?.nombre ?? '';
  final doc = pw.Document(title: 'Resumen ${a.titulo}', author: empresa.isEmpty ? Marca.nombre : empresa);
  final limpio = a.id.replaceAll('-', '').toUpperCase();
  pw.Widget celda(String t, {bool cab = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: pw.Text(t, style: pw.TextStyle(fontSize: cab ? 8.5 : 9.5, color: cab ? _suavePdf : _tintaPdf,
      fontWeight: cab ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
  pw.Widget tabla(List<String> cab, List<List<String>> filas) => pw.Table(
    border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _bordePdf, width: .6)),
    children: [
      pw.TableRow(children: [for (final c in cab) celda(c, cab: true)]),
      for (final f in filas) pw.TableRow(children: [for (final c in f) celda(c)]),
    ],
  );
  doc.addPage(
    _paginaPdf(
      logo: await _logoPdf(),
      empresa: empresa,
      titulo: 'Resumen del activo',
      numero: 'ACT-${limpio.substring(0, min(8, limpio.length))}',
      cuando: 'Últimos $dias días',
      build: (_) => [
        pw.Text(a.titulo, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _tintaPdf)),
        if (a.descripcion.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(a.descripcion, style: pw.TextStyle(fontSize: 10.5, color: _suavePdf)),
        ],
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _tarjetaPdf('Periodo (del ${fecha(desde)} a hoy)', [
                _datoPdf('Órdenes hechas', '${r.hechas}'),
                _datoPdf('Partes con problema', '${r.conProblema}'),
                _datoPdf('Incidencias', '${r.incidencias.length}'),
              ]),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _tarjetaPdf('Estado hoy', [
                _datoPdf('Contador', contadorTexto(a)),
                _datoPdf('Órdenes pendientes', '${r.pendientes}'),
                _datoPdf('Atrasadas', '${r.atrasadas}'),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        _etiquetaPdf('Mantenimientos'),
        pw.SizedBox(height: 6),
        tabla(
          ['Mantenimiento', 'Cada', 'Último', 'Próximo', 'Hechos'],
          [
            for (final (p, hechos) in r.planes)
              [
                p.nombre,
                p.cada.replaceAll(' · ', ', '),
                p.ultimo == null ? '-' : fecha(p.ultimo!),
                switch ((proximoPlan(p), horasRestantesPlan(p))) {
                  (final d?, _) => fecha(d),
                  (null, final h?) => 'Faltan ${numTexto(h)} h',
                  _ => '-',
                },
                '$hechos',
              ],
          ],
        ),
        if (r.realizadas.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _etiquetaPdf('Órdenes hechas'),
          pw.SizedBox(height: 6),
          tabla(
            ['Fecha', 'Orden', 'Técnico', 'Resultado'],
            [
              for (final (d, t) in r.realizadas.take(40))
                [
                  fecha(d),
                  t.nombre,
                  store.trabajador(t.ejecutadoPor ?? t.trabajadorIds.firstOrNull ?? '')?.nombreCompleto ?? '-',
                  resultadoOt(t).$1,
                ],
            ],
          ),
        ],
        if (r.incidencias.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _etiquetaPdf('Incidencias'),
          pw.SizedBox(height: 6),
          tabla(
            ['Fecha', 'Incidencia', 'Gravedad', 'Estado'],
            [
              for (final x in r.incidencias)
                [fecha(x.creada), x.descripcion, x.gravedad.etiqueta, store.estadoIncidencia(x).etiqueta],
            ],
          ),
        ],
      ],
    ),
  );
  final nombre = 'Resumen ${a.titulo} ${fecha(hoy())}'.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '');
  await descargar(await doc.save(), '$nombre.pdf', 'application/pdf');
}
