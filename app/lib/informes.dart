import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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

/// Descarga el informe en PDF, para mandárselo al cliente.
Future<void> descargarInformePdf(Informe i, Tarea t) async {
  final nombre = 'Parte ${t.nombre} ${fecha(i.cuando)}'.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '');
  await descargar(await informePdf(i, t), '$nombre.pdf', 'application/pdf');
}

/// El informe en PDF, como plantilla profesional: cabecera con el logo y la empresa, número y fecha; bloques
/// con la orden y el activo; ejecución con el resultado en color; trabajo, material, fotos y firmas; pie con página.
Future<Uint8List> informePdf(Informe i, Tarea t) async {
  final cliente = store.cliente(t.clienteId);
  final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
  final fotos = await Future.wait(i.fotos.map(bytesFoto));
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
  final colorResultado = PdfColor.fromInt(base.toARGB32());
  // El PDF no mezcla la transparencia: el fondo claro se calcula ya mezclado con el blanco.
  final fondoResultado = PdfColor.fromInt(Color.alphaBlend(base.withValues(alpha: .12), Colors.white).toARGB32());

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
                    t.nombre,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: tinta),
                  ),
                  if (t.descripcion.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(t.descripcion, style: pw.TextStyle(fontSize: 11, color: suave)),
                  ],
                ],
              ),
            ),
            // Solo si no fue bien (con incidencias o sin hacer): «Todo correcto» no hace falta decirlo.
            if (i.resultado != 0) ...[
              pw.SizedBox(width: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: fondoResultado,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  resultadosInforme[i.resultado],
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colorResultado),
                ),
              ),
            ],
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
              ]),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: industrial
                  ? tarjeta('Activo', [
                      dato('Activo', raiz?.titulo ?? '-'),
                      if (componente != null && componente.id != raiz?.id) dato('Componente', componente.titulo),
                      if (t.ubicacion.isNotEmpty) dato('Ubicación', t.ubicacion),
                    ])
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
        seccion('Trabajo realizado', i.notas.isEmpty ? 'Sin observaciones.' : i.notas),
        if (i.valor != null)
          seccion(
            plan != null && plan.conMedicion ? plan.medicionNombre : 'Medición',
            medidaTexto(i, t),
          ),
        if (i.material.isNotEmpty) seccion('Material y repuestos', i.material),
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
}) {
  final marca = PdfColor.fromInt(P.morado.toARGB32());
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
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
                pw.Text(Marca.nombre, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: marca)),
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

/// Informe de una incidencia: con OT y parte, el parte de la OT (que ya lleva la incidencia y sus fotos); si no,
/// la incidencia, sus fotos y en qué quedó.
Future<void> descargarInformeIncidencia(Incidencia x) async {
  final ot = store.tarea(x.trabajoId);
  final parte = ot == null ? null : (await informes.cargar(ot.id)).firstOrNull;
  final bytes = parte != null ? await informePdf(parte, ot!) : await incidenciaPdf(x);
  final nombre = 'Incidencia ${dondeEs(x.activoId)} ${fecha(x.creada)}'.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '');
  await descargar(bytes, '$nombre.pdf', 'application/pdf');
}

/// La incidencia en PDF (sin parte de OT): qué se comunicó, quién y cuándo, fotos y resolución.
Future<Uint8List> incidenciaPdf(Incidencia x) async {
  final fotos = await Future.wait(x.fotos.map(bytesFoto));
  final estado = store.estadoIncidencia(x);
  final ot = store.tarea(x.trabajoId);
  final plan = store.planes.where((p) => p.id == x.planId).firstOrNull;
  final raiz = raizActivo(x.activoId);
  final componente = store.activo(x.activoId);
  final empresa = store.nube?.nombre ?? '';
  final limpio = x.id.replaceAll('-', '').toUpperCase();
  final numero = 'INC-${limpio.substring(0, min(8, limpio.length))}';
  final color = PdfColor.fromInt(estado.color.toARGB32());
  final fondo = PdfColor.fromInt(Color.alphaBlend(estado.color.withValues(alpha: .12), Colors.white).toARGB32());
  final doc = pw.Document(title: 'Incidencia $numero', author: empresa.isEmpty ? Marca.nombre : empresa);
  doc.addPage(
    _paginaPdf(
      logo: await _logoPdf(),
      empresa: empresa,
      titulo: 'Informe de incidencia',
      numero: numero,
      cuando: '${fecha(x.creada)} ${hhmm(x.creada.hour * 60 + x.creada.minute)}',
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                x.descripcion.isEmpty ? 'Sin descripción' : x.descripcion,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _tintaPdf),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(color: fondo, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text(
                estado.etiqueta,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _tarjetaPdf('Incidencia', [
                _datoPdf('Número', numero),
                _datoPdf('Gravedad', x.gravedad.etiqueta),
                _datoPdf('Comunicada por', (x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!))?.nombreCompleto ?? 'Oficina'),
                _datoPdf('Fecha', fecha(x.creada)),
              ]),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _tarjetaPdf('Activo', [
                _datoPdf('Activo', raiz?.titulo ?? '-'),
                if (componente != null && componente.id != raiz?.id) _datoPdf('Componente', componente.titulo),
                if (plan != null) _datoPdf('Mantenimiento vinculado', plan.nombre),
              ]),
            ),
          ],
        ),
        if (fotos.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _etiquetaPdf('Fotos'),
          pw.SizedBox(height: 8),
          _fotosPdf(fotos),
        ],
        _seccionPdf('Resolución', switch (estado) {
          EstadoIncidencia.abierta => 'Pendiente de revisión.',
          EstadoIncidencia.desestimada =>
            'Desestimada${x.cerradaEl == null ? '' : ' el ${fecha(x.cerradaEl!)}'}: no hizo falta intervenir.',
          _ when ot != null => [
            'Orden de trabajo: ${ot.nombre}',
            if (estado == EstadoIncidencia.completada)
              'Completada${ot.ultimo == null ? '' : ' el ${fecha(ot.ultimo!)}'}.'
            else
              'Pendiente${ot.proximo == null ? '' : ', prevista el ${fecha(ot.proximo!)}'}.',
          ].join('\n'),
          _ => estado.etiqueta,
        }),
      ],
    ),
  );
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
