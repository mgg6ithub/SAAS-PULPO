import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Excel (.xlsx) sin paquetes de hoja de cálculo: un zip con XML dentro. Se escribe lo justo para que Excel,
/// Numbers y Google Sheets lo abran con la cabecera en negrita, fija al bajar y columnas a su ancho; se lee la
/// primera hoja de cualquier .xlsx como filas de texto (las fechas de Excel llegan como número de serie).

String _escapar(String x) => const HtmlEscape(HtmlEscapeMode.element).convert(x).replaceAll('"', '&quot;');

/// «A», «B»… «AA» para la columna [i] (desde 0).
String _letra(int i) {
  var n = i + 1, s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Índice de columna (desde 0) de una referencia como «C12».
int _columna(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c < 65 || c > 90) break;
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

String _hoja(List<List<String>> filas) {
  final anchos = <int, int>{};
  for (final f in filas) {
    for (final (i, x) in f.indexed) {
      final l = x.split('\n').map((l) => l.length).fold(0, (a, b) => a > b ? a : b);
      if (l > (anchos[i] ?? 0)) anchos[i] = l;
    }
  }
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    // La cabecera queda fija al bajar.
    ..write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" '
        'state="frozen"/></sheetView></sheetViews>');
  if (anchos.isNotEmpty) {
    b.write('<cols>');
    for (final e in anchos.entries) {
      final w = (e.value + 3).clamp(10, 60);
      b.write('<col min="${e.key + 1}" max="${e.key + 1}" width="$w" customWidth="1"/>');
    }
    b.write('</cols>');
  }
  b.write('<sheetData>');
  for (final (r, f) in filas.indexed) {
    b.write('<row r="${r + 1}">');
    for (final (c, x) in f.indexed) {
      if (x.isEmpty) continue;
      // Estilo 1: cabecera en negrita con fondo morado claro; 2: texto que salta de línea.
      final estilo = r == 0 ? ' s="1"' : (x.contains('\n') ? ' s="2"' : '');
      b.write('<c r="${_letra(c)}${r + 1}" t="inlineStr"$estilo><is><t xml:space="preserve">${_escapar(x)}</t></is></c>');
    }
    b.write('</row>');
  }
  return (b..write('</sheetData></worksheet>')).toString();
}

/// Libro .xlsx con una hoja por cada (nombre, filas); la primera fila de cada hoja es su cabecera.
Uint8List escribirXlsx(List<(String, List<List<String>>)> hojas) {
  final a = Archive();
  void poner(String ruta, String texto) => a.addFile(ArchiveFile.bytes(ruta, utf8.encode(texto)));
  const xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  poner(
    '[Content_Types].xml',
    '$xml<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${[for (var i = 1; i <= hojas.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  poner(
    '_rels/.rels',
    '$xml<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/></Relationships>',
  );
  poner(
    'xl/workbook.xml',
    '$xml<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (final (i, (n, _)) in hojas.indexed) '<sheet name="${_escapar(n.length > 31 ? n.substring(0, 31) : n)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  poner(
    'xl/_rels/workbook.xml.rels',
    '$xml<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 1; i <= hojas.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
        '<Relationship Id="rId${hojas.length + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>',
  );
  poner(
    'xl/styles.xml',
    '$xml<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><color rgb="FF3B2A9E"/><name val="Calibri"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FFEEEAFD"/></patternFill></fill></fills>'
        '<borders count="1"><border/></borders>'
        '<cellStyleXfs count="1"><xf/></cellStyleXfs>'
        '<cellXfs count="3"><xf/>'
        '<xf fontId="1" fillId="2" applyFont="1" applyFill="1"/>'
        '<xf applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf></cellXfs>'
        '</styleSheet>',
  );
  for (final (i, (_, filas)) in hojas.indexed) {
    poner('xl/worksheets/sheet${i + 1}.xml', _hoja(filas));
  }
  return ZipEncoder().encodeBytes(a);
}

/// La primera hoja de un .xlsx como filas de texto (sin filas vacías). Lanza [FormatException] si no lo es.
List<List<String>> leerXlsx(List<int> bytes) {
  final Archive a;
  try {
    a = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('No es un Excel (.xlsx) válido.');
  }
  String? leer(String ruta) {
    final f = a.findFile(ruta);
    final b = f?.readBytes();
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  final libro = leer('xl/workbook.xml');
  if (libro == null) throw const FormatException('No es un Excel (.xlsx) válido.');
  // La primera hoja, por su relación (no siempre se llama sheet1).
  var ruta = 'xl/worksheets/sheet1.xml';
  final primera = XmlDocument.parse(libro).findAllElements('sheet').firstOrNull;
  final id = primera?.attributes.where((x) => x.localName == 'id').firstOrNull?.value;
  final rels = leer('xl/_rels/workbook.xml.rels');
  if (id != null && rels != null) {
    final r = XmlDocument.parse(rels).findAllElements('Relationship').where((e) => e.getAttribute('Id') == id).firstOrNull;
    final t = r?.getAttribute('Target');
    if (t != null) ruta = t.startsWith('/') ? t.substring(1) : 'xl/$t';
  }
  final compartidas = <String>[
    for (final si in XmlDocument.parse(leer('xl/sharedStrings.xml') ?? '<sst/>').findAllElements('si'))
      si.findAllElements('t').map((t) => t.innerText).join(),
  ];
  final hoja = leer(ruta);
  if (hoja == null) throw const FormatException('El Excel no tiene ninguna hoja.');
  final filas = <List<String>>[];
  for (final row in XmlDocument.parse(hoja).findAllElements('row')) {
    final fila = <String>[];
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      final col = ref == null ? fila.length : _columna(ref);
      while (fila.length < col) {
        fila.add('');
      }
      final tipo = c.getAttribute('t');
      final v = c.findElements('v').firstOrNull?.innerText ?? '';
      final texto = switch (tipo) {
        's' => compartidas.elementAtOrNull(int.tryParse(v) ?? -1) ?? '',
        'inlineStr' => c.findAllElements('t').map((t) => t.innerText).join(),
        'b' => v == '1' ? 'Sí' : 'No',
        _ => v.endsWith('.0') ? v.substring(0, v.length - 2) : v,
      };
      fila.add(texto.trim());
    }
    if (fila.any((x) => x.isNotEmpty)) filas.add(fila);
  }
  return filas;
}
