import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../geo.dart';
import '../importar.dart';
import '../models.dart';
import '../plataforma_io.dart' if (dart.library.js_interop) '../plataforma_web.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../marca.dart';

/// Importar clientes, trabajadores y trabajos (Pultec: activos y técnicos) desde CSV con vista previa, y exportarlo
/// todo a CSV. [que] abre directamente esa pestaña (desde Activos o Técnicos).
Future<void> abrirImportarExportar(BuildContext context, {QueImportar? que}) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.fondo,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
      child: ImportarExportar(que: que),
    ),
  ),
);

Future<void> _descargarCsv(String nombre, String csv) => descargar(utf8.encode(csv), nombre, 'text/csv');

class ImportarExportar extends StatefulWidget {
  final QueImportar? que;
  const ImportarExportar({super.key, this.que});

  @override
  State<ImportarExportar> createState() => _ImportarExportarState();
}

class _ImportarExportarState extends State<ImportarExportar> {
  late QueImportar que = widget.que ?? importables.first;
  Importacion? vista;
  String? archivo;
  bool verGuia = false;
  bool get solo => widget.que != null;

  Future<void> elegir() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f?.bytes == null) return;
    final texto = utf8.decode(f!.bytes!, allowMalformed: true);
    setState(() {
      archivo = f.name;
      vista = prepararImportacion(que, leerCsv(texto), store);
    });
  }

  void importar() {
    final imp = vista!;
    imp.aplicar(store);
    _ubicar([...imp.clientes]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          que == QueImportar.activos
              ? '${_resumen(imp)} importados${imp.planes.isEmpty ? '' : '; sus órdenes de trabajo se crean solas'}'
              : '${imp.total} ${que.etiqueta.toLowerCase()} importados',
        ),
      ),
    );
    setState(() {
      vista = null;
      archivo = null;
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(24, 20, 16, 22),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              solo ? 'Importar y exportar ${que.etiqueta.toLowerCase()}' : 'Importar y exportar',
              style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: Icon(CupertinoIcons.xmark, size: 19, color: P.textoSuave),
          ),
        ],
      ),
      Text(switch (widget.que) {
        QueImportar.activos =>
          'Crea de una vez tus activos, con sus componentes y mantenimientos, desde un Excel guardado como CSV. '
              'Cada mantenimiento sale con su orden de trabajo. Lo que ya está en Pultec no se duplica.',
        QueImportar.trabajadores => m(
          'Crea de una vez a tus trabajadores desde un Excel guardado como CSV. Lo que ya está en Pultec no se duplica.',
        ),
        _ when industrial => 'Trae tus activos (con componentes y mantenimientos) y técnicos desde un Excel guardado como CSV, o llévatelos. Lo que ya está en Pultec no se duplica.',
        _ => m(
          'Trae tus datos desde un Excel guardado como CSV, o llévatelos. Lo que ya está en Pultec no se duplica.',
        ),
      }, style: TextStyle(fontSize: 13, color: P.textoSuave)),
      const SizedBox(height: 18),
      _titulo('Importar'),
      // Desde Activos o Técnicos, solo lo suyo; con todo (Ajustes), una pestaña por tipo, a su ancho.
      if (!solo) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Pestanas(
            opciones: [for (final q in importables) q.etiqueta],
            seleccion: importables.indexOf(que),
            onChanged: (i) => setState(() {
              que = importables[i];
              vista = null;
              archivo = null;
            }),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (que == QueImportar.trabajos)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            m('Cada trabajo va a un cliente que ya exista en Pultec (por nombre o CIF): importa antes los clientes.'),
            style: TextStyle(fontSize: 12.5, color: P.textoSuave),
          ),
        ),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(onPressed: elegir, child: const Text('Elegir archivo CSV')),
          Enlace(
            'Descargar plantilla',
            onTap: () => _descargarCsv('plantilla_${que.etiqueta.toLowerCase()}.csv', plantillaCsv(que)),
          ),
          Enlace(verGuia ? 'Ocultar columnas' : 'Ver columnas', onTap: () => setState(() => verGuia = !verGuia)),
          Enlace(
            'Descargar guía',
            onTap: () => descargar(utf8.encode(guiaTexto(que)), 'guia_${que.etiqueta.toLowerCase()}.txt', 'text/plain'),
          ),
        ],
      ),
      if (verGuia) ...[const SizedBox(height: 12), _guia()],
      if (vista != null) ...[const SizedBox(height: 16), _vistaPrevia(vista!)],
      const SizedBox(height: 26),
      _titulo('Exportar'),
      Tarjeta(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final q in solo ? [que] : importables)
              FilaLista(
                lider: const SizedBox(width: 4),
                titulo: q.etiqueta,
                subtitulo: switch (q) {
                  QueImportar.clientes => m('${store.clientes.length} clientes'),
                  QueImportar.trabajadores => m('${store.trabajadores.length} trabajadores'),
                  QueImportar.trabajos => m('${store.tareas.where((t) => !t.esPlantilla).length} trabajos'),
                  QueImportar.activos =>
                    '${store.activos.length} activos y componentes, ${store.planes.length} mantenimientos',
                },
                derecha: Enlace(
                  'Descargar',
                  onTap: () => _descargarCsv('${q.etiqueta.toLowerCase()}.csv', exportarCsv(q, store)),
                ),
              ),
            if (!industrial)
              FilaLista(
                lider: const SizedBox(width: 4),
                titulo: 'Histórico',
                subtitulo: 'Cada mantenimiento hecho, con su fecha',
                derecha: Enlace('Descargar', onTap: () => _descargarCsv('historico.csv', exportarHistorialCsv(store))),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.textoSuave),
    ),
  );

  /// «3 activos, 2 componentes y 5 mantenimientos».
  String _resumen(Importacion imp) {
    String n(int x, String uno, String varios) => '$x ${x == 1 ? uno : varios}';
    final comp = imp.activos.where((a) => a.padreId != null).length;
    final partes = [
      n(imp.activos.length - comp, 'activo', 'activos'),
      if (comp > 0) n(comp, 'componente', 'componentes'),
      if (imp.planes.isNotEmpty) n(imp.planes.length, 'mantenimiento', 'mantenimientos'),
    ];
    return partes.length == 1 ? partes.first : '${partes.take(partes.length - 1).join(', ')} y ${partes.last}';
  }

  /// Guía de formato: cada columna con lo que lleva.
  Widget _guia() => Tarjeta(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (c, texto) in que.guia)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: c,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (texto.isNotEmpty)
                    TextSpan(
                      text: '  $texto',
                      style: TextStyle(color: P.textoSuave),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
      ],
    ),
  );

  Widget _vistaPrevia(Importacion imp) {
    final nombres = [
      for (final c in imp.clientes) c.nombre,
      for (final w in imp.trabajadores) w.nombreCompleto,
      for (final t in imp.tareas) '${store.cliente(t.clienteId)?.nombre} · ${t.nombre}',
      for (final a in imp.activos) '${a.titulo}${a.padreId == null ? '' : ' (componente)'}',
      for (final p in imp.planes)
        '${[...store.activos, ...imp.activos].where((a) => a.id == p.activoId).firstOrNull?.tag}: ${p.nombre}',
    ];
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(archivo ?? '', style: TextStyle(fontSize: 12, color: P.textoSuave)),
          const SizedBox(height: 4),
          Text(
            [
              que == QueImportar.activos ? _resumen(imp) : '${imp.total} ${imp.total == 1 ? 'nuevo' : 'nuevos'}',
              if (imp.duplicados > 0) '${imp.duplicados} ya estaban',
              if (imp.avisos.isNotEmpty) '${imp.avisos.length} ${imp.avisos.length == 1 ? 'aviso' : 'avisos'}',
            ].join(', '),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (nombres.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              nombres.take(5).join('\n') + (nombres.length > 5 ? '\n… y ${nombres.length - 5} más' : ''),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          if (imp.avisos.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final a in imp.avisos.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(a, style: const TextStyle(fontSize: 12.5, color: P.ambar)),
              ),
            if (imp.avisos.length > 8)
              Text('… y ${imp.avisos.length - 8} avisos más', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => setState(() => vista = null), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton(onPressed: imp.total == 0 ? null : importar, child: Text('Importar ${imp.total}')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sitúa en el mapa los clientes importados, de uno en uno (OpenStreetMap pide no más de uno por segundo).
Future<void> _ubicar(List<Cliente> clientes) async {
  for (final c in clientes.where((c) => c.direccionCompleta.trim().isNotEmpty)) {
    final copia = c.copia();
    if (await ubicar(copia) && store.cliente(c.id) != null) {
      store.guardarCliente(
        store.cliente(c.id)!
          ..lat = copia.lat
          ..lng = copia.lng,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 1100));
  }
}
