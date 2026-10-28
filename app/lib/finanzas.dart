import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'nube.dart';
import 'plataforma_io.dart' if (dart.library.js_interop) 'plataforma_web.dart';
import 'store.dart';
import 'theme.dart';

/// Finanzas básicas SIN valor fiscal: presupuestos y facturas proforma (la factura legal con Verifactu
/// llega después). Solo para el administrador.

/// Una línea de un documento. Si sale de un trabajo hecho, lleva el trabajo y el día (para no cobrarlo dos veces).
class Linea {
  String concepto;
  double cantidad, precio, iva;
  final String? trabajoId;
  final DateTime? dia;
  Linea({this.concepto = '', this.cantidad = 1, this.precio = 0, this.iva = 21, this.trabajoId, this.dia});

  double get base => cantidad * precio;
  double get cuota => base * iva / 100;

  Map<String, dynamic> toJson() => {
    'concepto': concepto,
    'cantidad': cantidad,
    'precio': precio,
    'iva': iva,
    if (trabajoId != null) 'trabajo_id': trabajoId,
    if (dia != null) 'dia': DateUtils.dateOnly(dia!).toIso8601String().substring(0, 10),
  };

  factory Linea.fromJson(Map j) => Linea(
    concepto: j['concepto'] as String? ?? '',
    cantidad: (j['cantidad'] as num? ?? 1).toDouble(),
    precio: (j['precio'] as num? ?? 0).toDouble(),
    iva: (j['iva'] as num? ?? 21).toDouble(),
    trabajoId: j['trabajo_id'] as String?,
    dia: j['dia'] == null ? null : DateTime.parse(j['dia'] as String),
  );
}

enum TipoDocumento {
  proforma('Factura proforma', 'F'),
  presupuesto('Presupuesto', 'P');

  final String etiqueta, letra;
  const TipoDocumento(this.etiqueta, this.letra);
}

enum EstadoCobro {
  presupuesto('Presupuesto'),
  pendiente('Pendiente'),
  vencida('Vencida'),
  cobrada('Cobrada');

  final String etiqueta;
  const EstadoCobro(this.etiqueta);

  Color get color => switch (this) {
    presupuesto => P.morado,
    pendiente => P.ambar,
    vencida => P.rojo,
    cobrada => P.verde,
  };
}

class Documento {
  String? id;
  TipoDocumento tipo;
  int serie, numero;
  String? clienteId;
  DateTime fecha;
  DateTime? vence, cobradaEl;
  List<Linea> lineas;
  String notas;
  Documento({
    this.id,
    this.tipo = TipoDocumento.proforma,
    int? serie,
    this.numero = 0,
    this.clienteId,
    DateTime? fecha,
    this.vence,
    this.cobradaEl,
    List<Linea>? lineas,
    this.notas = '',
  }) : fecha = fecha ?? hoy(),
       serie = serie ?? (fecha ?? hoy()).year,
       lineas = lineas ?? [];

  /// «F2026-0007», «P2026-0012»; sin número todavía, «Nueva».
  String get codigo => numero == 0 ? 'Nueva' : '${tipo.letra}$serie-${numero.toString().padLeft(4, '0')}';

  double get base => lineas.fold(0, (s, l) => s + l.base);
  double get cuota => lineas.fold(0, (s, l) => s + l.cuota);
  double get total => base + cuota;

  EstadoCobro get estado => tipo == TipoDocumento.presupuesto
      ? EstadoCobro.presupuesto
      : cobradaEl != null
      ? EstadoCobro.cobrada
      : vence != null && diasHasta(vence!) < 0
      ? EstadoCobro.vencida
      : EstadoCobro.pendiente;

  Map<String, dynamic> toFila() => {
    'id': id,
    'tipo': tipo.name,
    'serie': serie,
    'cliente_id': clienteId,
    'fecha': _dia(fecha),
    'vence': vence == null ? null : _dia(vence!),
    'cobrada_el': cobradaEl == null ? null : _dia(cobradaEl!),
    'lineas': [for (final l in lineas) l.toJson()],
    'notas': notas,
  };

  factory Documento.deFila(Map x) => Documento(
    id: x['id'],
    tipo: TipoDocumento.values.byName(x['tipo'] as String),
    serie: x['serie'],
    numero: x['numero'],
    clienteId: x['cliente_id'],
    fecha: DateTime.parse(x['fecha'] as String),
    vence: x['vence'] == null ? null : DateTime.parse(x['vence'] as String),
    cobradaEl: x['cobrada_el'] == null ? null : DateTime.parse(x['cobrada_el'] as String),
    lineas: [for (final l in x['lineas'] as List) Linea.fromJson(l as Map)],
    notas: x['notas'] ?? '',
  );

  Documento copia() => Documento.deFila({...toFila(), 'numero': numero});
}

String _dia(DateTime d) => DateUtils.dateOnly(d).toIso8601String().substring(0, 10);

/// «1.234,50 €».
String euros(double v) {
  final c = (v * 100).round();
  final entero = (c.abs() ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  return '${c < 0 ? '-' : ''}$entero,${(c.abs() % 100).toString().padLeft(2, '0')} €';
}

/// Lo facturado, cobrado y pendiente de un mes.
typedef ResumenMes = ({double facturado, double cobrado, double pendiente});

/// Los presupuestos y proformas de la empresa: se piden a la base al abrir Finanzas; sin sesión, en memoria.
class Finanzas extends ChangeNotifier {
  List<Documento>? _docs;
  Nube? _nube;
  bool _pidiendo = false;

  /// Todos, el más reciente primero (null = cargando).
  List<Documento>? get documentos {
    final n = store.nube;
    if (n != _nube) {
      _nube = n;
      _docs = n == null ? [] : null;
    }
    if (n == null) _docs ??= [];
    if (_docs == null && !_pidiendo && n != null) {
      _pidiendo = true;
      n.documentos().then(
        (r) {
          _pidiendo = false;
          if (n != _nube) return;
          _docs = [for (final x in r) Documento.deFila(x)];
          notifyListeners();
        },
        onError: (Object e) {
          _pidiendo = false;
          debugPrint('Pulpo: no se pudieron leer las finanzas: $e');
        },
      );
    }
    final d = _docs;
    if (d == null) return null;
    return [...d]..sort((a, b) {
      final c = b.fecha.compareTo(a.fecha);
      return c != 0 ? c : b.numero.compareTo(a.numero);
    });
  }

  /// Guarda el documento (crea o actualiza). Al crearlo, el número lo pone la base.
  Future<void> guardar(Documento d) async {
    final n = store.nube;
    final lista = _docs ??= [];
    if (n == null) {
      if (d.id == null) {
        d
          ..id = '${DateTime.now().microsecondsSinceEpoch}'
          ..numero =
              lista
                  .where((x) => x.tipo == d.tipo && x.serie == d.serie)
                  .fold(0, (m, x) => x.numero > m ? x.numero : m) +
              1;
      }
    } else {
      final g = Documento.deFila(await n.guardarDocumento(d.toFila()));
      d
        ..id = g.id
        ..numero = g.numero;
    }
    lista
      ..removeWhere((x) => x.id == d.id)
      ..add(d);
    notifyListeners();
  }

  Future<void> borrar(Documento d) async {
    if (d.id == null) return;
    await store.nube?.borrarDocumento(d.id!);
    _docs?.removeWhere((x) => x.id == d.id);
    notifyListeners();
  }

  Future<void> cobrar(Documento d, bool cobrada) async {
    final antes = d.cobradaEl;
    d.cobradaEl = cobrada ? hoy() : null;
    try {
      await guardar(d);
    } catch (_) {
      d.cobradaEl = antes;
      rethrow;
    }
  }

  ResumenMes resumen(DateTime mes) {
    bool enMes(DateTime? d) => d != null && d.year == mes.year && d.month == mes.month;
    final proformas = (_docs ?? const <Documento>[]).where((d) => d.tipo == TipoDocumento.proforma);
    return (
      facturado: proformas.where((d) => enMes(d.fecha)).fold(0.0, (s, d) => s + d.total),
      cobrado: proformas.where((d) => enMes(d.cobradaEl)).fold(0.0, (s, d) => s + d.total),
      pendiente: proformas.where((d) => d.cobradaEl == null).fold(0.0, (s, d) => s + d.total),
    );
  }

  /// Proformas nuevas (sin guardar) con los trabajos con precio hechos en [mes] que aún no se han cobrado,
  /// una por cliente. Así los mantenimientos periódicos generan su factura solos.
  List<Documento> porFacturar(DateTime mes) {
    final yaFacturado = {
      for (final d in _docs ?? const <Documento>[])
        if (d.tipo == TipoDocumento.proforma)
          for (final l in d.lineas)
            if (l.trabajoId != null && l.dia != null) '${l.trabajoId}|${_dia(l.dia!)}',
    };
    final porCliente = <String, Documento>{};
    for (final t in store.tareas) {
      if (t.esPlantilla || t.precio <= 0 || t.clienteId == null || store.cliente(t.clienteId) == null) continue;
      final dias = {...t.historial, ?t.ultimo}.where((d) => d.year == mes.year && d.month == mes.month);
      for (final d in {for (final x in dias) _dia(x)}) {
        if (yaFacturado.contains('${t.id}|$d')) continue;
        final doc = porCliente[t.clienteId!] ??= Documento(
          clienteId: t.clienteId,
          vence: masDias(hoy(), 30),
          notas: 'Mantenimientos de ${_mesLargo(mes)}',
        );
        doc.lineas.add(
          Linea(
            concepto: '${t.nombre} · ${fecha(DateTime.parse(d))}',
            precio: t.precio,
            iva: t.iva,
            trabajoId: t.id,
            dia: DateTime.parse(d),
          ),
        );
      }
    }
    return porCliente.values.toList();
  }

  /// Para la gestoría: una fila por documento, separado por «;» y con coma decimal (Excel en español).
  String csv(Iterable<Documento> docs) {
    String n(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    return [
      'Tipo;Número;Fecha;Cliente;CIF;Base;IVA;Total;Vence;Cobrada el;Estado',
      for (final d in docs)
        [
          d.tipo.etiqueta,
          d.codigo,
          fecha(d.fecha),
          q(store.cliente(d.clienteId)?.nombre ?? ''),
          store.cliente(d.clienteId)?.cif ?? '',
          n(d.base),
          n(d.cuota),
          n(d.total),
          d.vence == null ? '' : fecha(d.vence),
          d.cobradaEl == null ? '' : fecha(d.cobradaEl),
          d.estado.etiqueta,
        ].join(';'),
    ].join('\r\n');
  }
}

final finanzas = Finanzas();

String _mesLargo(DateTime m) => const [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
][m.month - 1];

/// «octubre de 2026».
String mesYAno(DateTime m) => '${_mesLargo(m)} de ${m.year}';

/// Descarga el CSV (con BOM para que Excel lea bien las tildes).
Future<void> descargarCsv(Iterable<Documento> docs, DateTime mes) => descargar(
  Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(finanzas.csv(docs))]),
  'Pulpo ${mesYAno(mes)}.csv',
  'text/csv',
);

Future<void> descargarDocumentoPdf(Documento d) async =>
    descargar(await documentoPdf(d), '${d.tipo.etiqueta} ${d.codigo}.pdf', 'application/pdf');

/// El documento en PDF: empresa, cliente, líneas, totales y el aviso de que no es una factura.
Future<Uint8List> documentoPdf(Documento d) async {
  final c = store.cliente(d.clienteId);
  final doc = pw.Document();
  final morado = PdfColor.fromInt(P.morado.toARGB32());
  final suave = PdfColor.fromInt(0xFF6B7280);
  const normal = pw.TextStyle(fontSize: 10);
  final negrita = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  String n(double v) => euros(v).replaceAll('€', 'EUR');
  pw.Widget derecha(String s, [pw.TextStyle? e]) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(s, style: e ?? normal),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    (store.nube?.nombre ?? '').toUpperCase(),
                    style: pw.TextStyle(color: morado, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(d.tipo.etiqueta, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(d.codigo, style: pw.TextStyle(color: suave, fontSize: 11)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Fecha: ${fecha(d.fecha)}', style: normal),
                if (d.vence != null) pw.Text('Vence: ${fecha(d.vence)}', style: normal),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        if (c != null) ...[
          pw.Text('Cliente', style: pw.TextStyle(color: suave, fontSize: 9)),
          pw.Text(c.nombre, style: negrita),
          if (c.cif.isNotEmpty) pw.Text(c.cif, style: normal),
          if (c.direccionCompleta.isNotEmpty) pw.Text(c.direccionCompleta, style: normal),
          pw.SizedBox(height: 20),
        ],
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(5),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1.8),
          },
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB))),
          children: [
            pw.TableRow(
              children: [
                pw.Text('Concepto', style: negrita),
                derecha('Cant.', negrita),
                derecha('Precio', negrita),
                derecha('IVA', negrita),
                derecha('Importe', negrita),
              ],
            ),
            for (final l in d.lineas)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text(l.concepto, style: normal),
                  ),
                  derecha(_num(l.cantidad)),
                  derecha(n(l.precio)),
                  derecha('${_num(l.iva)} %'),
                  derecha(n(l.base)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 200,
            child: pw.Column(
              children: [
                for (final (e, v, s) in [
                  ('Base', d.base, normal),
                  ('IVA', d.cuota, normal),
                  ('Total', d.total, negrita),
                ])
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text(e, style: s)),
                      pw.Text(n(v), style: s),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (d.notas.isNotEmpty) ...[pw.SizedBox(height: 16), pw.Text(d.notas, style: normal)],
        pw.SizedBox(height: 24),
        pw.Text(
          d.tipo == TipoDocumento.proforma
              ? 'Factura proforma: documento sin valor fiscal. No sustituye a la factura.'
              : 'Presupuesto sin valor fiscal.',
          style: pw.TextStyle(color: suave, fontSize: 8.5),
        ),
      ],
    ),
  );
  return doc.save();
}

/// 1 → «1», 1,5 → «1,5».
String _num(double v) => (v == v.roundToDouble() ? v.toInt().toString() : v.toString()).replaceAll('.', ',');
