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

/// Importar clientes, trabajadores y trabajos desde CSV con vista previa, y exportarlo todo a CSV.
Future<void> abrirImportarExportar(BuildContext context) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.fondo,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
      child: const ImportarExportar(),
    ),
  ),
);

Future<void> _descargarCsv(String nombre, String csv) => descargar(utf8.encode(csv), nombre, 'text/csv');

class ImportarExportar extends StatefulWidget {
  const ImportarExportar({super.key});

  @override
  State<ImportarExportar> createState() => _ImportarExportarState();
}

class _ImportarExportarState extends State<ImportarExportar> {
  QueImportar que = QueImportar.clientes;
  Importacion? vista;
  String? archivo;

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${imp.total} ${que.etiqueta.toLowerCase()} importados')));
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
              'Importar y exportar',
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
      Text(
        m('Trae tus datos desde un Excel guardado como CSV, o llévatelos. Lo que ya está en Pulpo no se duplica.'),
        style: TextStyle(fontSize: 13, color: P.textoSuave),
      ),
      const SizedBox(height: 18),
      _titulo('Importar'),
      Pestanas(
        opciones: [for (final q in QueImportar.values) q.etiqueta],
        seleccion: que.index,
        onChanged: (i) => setState(() {
          que = QueImportar.values[i];
          vista = null;
          archivo = null;
        }),
      ),
      const SizedBox(height: 12),
      if (que == QueImportar.trabajos)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            m('Cada trabajo va a un cliente que ya exista en Pulpo (por nombre o CIF): importa antes los clientes.'),
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
        ],
      ),
      if (vista != null) ...[const SizedBox(height: 16), _vistaPrevia(vista!)],
      const SizedBox(height: 26),
      _titulo('Exportar'),
      Tarjeta(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final q in QueImportar.values)
              FilaLista(
                lider: const SizedBox(width: 4),
                titulo: q.etiqueta,
                subtitulo: switch (q) {
                  QueImportar.clientes => m('${store.clientes.length} clientes'),
                  QueImportar.trabajadores => m('${store.trabajadores.length} trabajadores'),
                  QueImportar.trabajos => m('${store.tareas.where((t) => !t.esPlantilla).length} trabajos'),
                },
                derecha: Enlace(
                  'Descargar',
                  onTap: () => _descargarCsv('${q.etiqueta.toLowerCase()}.csv', exportarCsv(q, store)),
                ),
              ),
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

  Widget _vistaPrevia(Importacion imp) {
    final nombres = [
      for (final c in imp.clientes) c.nombre,
      for (final w in imp.trabajadores) w.nombreCompleto,
      for (final t in imp.tareas) '${store.cliente(t.clienteId)?.nombre} · ${t.nombre}',
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
              '${imp.total} ${imp.total == 1 ? 'nuevo' : 'nuevos'}',
              if (imp.duplicados > 0) '${imp.duplicados} ya estaban',
              if (imp.avisos.isNotEmpty) '${imp.avisos.length} ${imp.avisos.length == 1 ? 'aviso' : 'avisos'}',
            ].join(' · '),
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
