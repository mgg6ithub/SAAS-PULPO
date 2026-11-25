import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../geo.dart';
import '../importar.dart';
import '../informes.dart' show listadoPdf;
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
      constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
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
  FormatoExportar formato = FormatoExportar.pdf;
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
      // Sin archivo, la plantilla a la vista; con archivo, lo que se va a crear.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        child: vista == null ? _plantilla() : _vistaPrevia(vista!),
      ),
      const SizedBox(height: 26),
      // Título y, a su derecha, el formato de la descarga (PDF por defecto).
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _titulo('Exportar')),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pestanas(
              compactas: true,
              opciones: [for (final f in FormatoExportar.values) f.etiqueta],
              seleccion: formato.index,
              onChanged: (i) => setState(() => formato = FormatoExportar.values[i]),
            ),
          ),
        ],
      ),
      Tarjeta(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final q in solo ? [que] : importables)
              FilaLista(
                titulo: q.etiqueta,
                subtitulo: switch (q) {
                  QueImportar.clientes => m('${store.clientes.length} clientes'),
                  QueImportar.trabajadores => m('${store.trabajadores.length} trabajadores'),
                  QueImportar.trabajos => m('${store.tareas.where((t) => !t.esPlantilla).length} trabajos'),
                  QueImportar.activos =>
                    '${store.activos.length} ${store.activos.length == 1 ? 'activo o componente' : 'activos y componentes'}, '
                        '${store.planes.length} ${store.planes.length == 1 ? 'mantenimiento' : 'mantenimientos'}',
                },
                derecha: Enlace(
                  'Descargar ${formato.etiqueta}',
                  onTap: () =>
                      _exportar(q.etiqueta, [q.columnas, ...filasExportar(q, store)], columnasPdf: columnasPdf(q)),
                ),
              ),
            if (!industrial)
              FilaLista(
                titulo: 'Histórico',
                subtitulo: 'Cada mantenimiento hecho, con su fecha',
                derecha: Enlace(
                  'Descargar ${formato.etiqueta}',
                  onTap: () => _exportar('Histórico', filasHistorial(store)),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  /// Descarga [conCabecera] en el formato elegido. El PDF lleva solo [columnasPdf] (las que caben).
  Future<void> _exportar(String titulo, List<List<String>> conCabecera, {List<String>? columnasPdf}) async {
    final nombre = normalizar(titulo).replaceAll(' ', '_');
    final bytes = switch (formato) {
      FormatoExportar.pdf => await listadoPdf(
        titulo,
        columnasPdf == null ? conCabecera : soloColumnas(conCabecera, columnasPdf),
      ),
      FormatoExportar.csv => utf8.encode(escribirCsv(conCabecera)),
      FormatoExportar.json => utf8.encode(filasJson(conCabecera)),
    };
    await descargar(bytes, '$nombre.${formato.name}', formato.tipo);
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.textoSuave),
    ),
  );

  /// Avisos por número de fila (los que no son de una fila, al final).
  List<String> _enOrden(List<String> avisos) {
    int fila(String a) => int.tryParse(RegExp(r'^Fila (\d+)').firstMatch(a)?[1] ?? '') ?? 1 << 30;
    return [...avisos]..sort((a, b) => fila(a).compareTo(fila(b)));
  }

  /// «3 activos», «2 componentes», «5 mantenimientos» (lo que haya).
  List<String> _partes(Importacion imp) {
    String n(int x, String uno, String varios) => '$x ${x == 1 ? uno : varios}';
    final comp = imp.activos.where((a) => a.padreId != null).length;
    return [
      if (imp.activos.length > comp) n(imp.activos.length - comp, 'activo', 'activos'),
      if (comp > 0) n(comp, 'componente', 'componentes'),
      if (imp.planes.isNotEmpty) n(imp.planes.length, 'mantenimiento', 'mantenimientos'),
    ];
  }

  /// «3 activos, 2 componentes y 5 mantenimientos».
  String _resumen(Importacion imp) {
    final partes = _partes(imp);
    return partes.length == 1 ? partes.first : '${partes.take(partes.length - 1).join(', ')} y ${partes.last}';
  }

  /// Tabla de solo lectura que se desplaza a lo ancho si no cabe; si sobra sitio, las columnas se ensanchan.
  Widget _tabla(List<Col> columnas, List<List<Widget>> filas, {int maxFilas = 7}) => LayoutBuilder(
    builder: (context, c) {
      // La tabla lleva 18 px de margen a cada lado.
      final suma = columnas.fold<double>(0, (t, x) => t + x.ancho!), libre = c.maxWidth - 36;
      final k = suma < libre ? libre / suma : 1.0;
      return Tarjeta(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: suma * k + 36,
            height: 46 + 57.0 * filas.length.clamp(1, maxFilas),
            child: Tabla(
              columnas: [for (final x in columnas) Col(x.titulo, ancho: x.ancho! * k, ayuda: x.ayuda)],
              filas: filas.length,
              celdas: (i) => filas[i],
            ),
          ),
        ),
      );
    },
  );

  /// La plantilla a la vista: sus columnas (con lo que lleva cada una al pasar el ratón) y las filas de ejemplo.
  Widget _plantilla() {
    final guia = que.guia;
    return Column(
      key: ValueKey('plantilla_${que.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Plantilla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            // En ventana estrecha, los enlaces bajan de línea en vez de salirse.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 16,
                runSpacing: 6,
                children: [
                  Enlace(
                    'Descargar plantilla',
                    onTap: () => _descargarCsv('plantilla_${que.etiqueta.toLowerCase()}.csv', plantillaCsv(que)),
                  ),
                  Enlace(
                    'Descargar guía',
                    onTap: () =>
                        descargar(utf8.encode(guiaTexto(que)), 'guia_${que.etiqueta.toLowerCase()}.txt', 'text/plain'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Consejo(
          'Rellena tu Excel con estas columnas y guárdalo como CSV. Pasa el ratón por cada columna para ver qué '
          'lleva; las de * son obligatorias y el orden da igual.',
          clave: 'importar_plantilla',
        ),
        const SizedBox(height: 10),
        _tabla(
          [
            for (final (c, texto) in guia)
              Col(
                texto.startsWith('Obligatoria') ? '$c *' : c,
                ancho: (c.length * 8.5 + 48).clamp(110, 260).toDouble(),
                ayuda: texto.isEmpty ? c : texto,
              ),
          ],
          [
            for (final f in que.ejemplos) [for (final (i, x) in f.indexed) celdaTexto(x, negrita: i == 0)],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(onPressed: elegir, child: const Text('Elegir archivo CSV')),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'En Excel: Archivo, Guardar como, CSV.',
                style: TextStyle(fontSize: 12.5, color: P.textoSuave),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Lo que se va a crear, en tabla, con el resumen en colores y los avisos por fila.
  Widget _vistaPrevia(Importacion imp) {
    final todos = [...store.activos, ...imp.activos];
    String tag(String? id) => todos.where((a) => a.id == id).firstOrNull?.tag ?? '';
    String mants(String id) => [for (final p in imp.planes.where((p) => p.activoId == id)) p.nombre].join(', ');
    final (columnas, filas) = switch (que) {
      QueImportar.activos => (
        const [
          Col('Tag', ancho: 130),
          Col('Nombre', ancho: 220),
          Col('Tipo', ancho: 130),
          Col('Padre', ancho: 120),
          Col('Mantenimientos nuevos', ancho: 300),
        ],
        [
          for (final a in imp.activos)
            [
              celdaTexto(a.tag, negrita: true),
              celdaTexto(a.nombre),
              celdaTexto(a.padreId == null ? 'Activo' : 'Componente', suave: true),
              celdaTexto(tag(a.padreId), suave: true),
              celdaTexto(mants(a.id)),
            ],
          // Activos que ya estaban y reciben mantenimientos nuevos.
          for (final a in store.activos.where((a) => imp.planes.any((p) => p.activoId == a.id)))
            [
              celdaTexto(a.tag, negrita: true),
              celdaTexto(a.nombre),
              celdaTexto('Ya en Pultec', suave: true),
              celdaTexto(tag(a.padreId), suave: true),
              celdaTexto(mants(a.id)),
            ],
        ],
      ),
      QueImportar.trabajadores => (
        [
          const Col('Nombre', ancho: 200),
          const Col('Correo', ancho: 220),
          const Col('Teléfono', ancho: 130),
          Col(industrial ? 'Especialidades' : 'Competencias', ancho: 260),
        ],
        [
          for (final w in imp.trabajadores)
            [
              celdaTexto(w.nombreCompleto, negrita: true),
              celdaTexto(w.email),
              celdaTexto(w.telefono),
              celdaTexto(w.competencias.join(', ')),
            ],
        ],
      ),
      QueImportar.clientes => (
        const [Col('Nombre', ancho: 260), Col('Ciudad', ancho: 160), Col('Teléfono', ancho: 140)],
        [
          for (final c in imp.clientes)
            [celdaTexto(c.nombre, negrita: true), celdaTexto(c.ciudad), celdaTexto(c.telefono)],
        ],
      ),
      QueImportar.trabajos => (
        const [Col('Cliente', ancho: 220), Col('Nombre', ancho: 240), Col('Periodicidad', ancho: 140)],
        [
          for (final t in imp.tareas)
            [
              celdaTexto(store.cliente(t.clienteId)?.nombre ?? '', negrita: true),
              celdaTexto(t.nombre),
              celdaTexto(t.periodicidad.etiqueta, suave: true),
            ],
        ],
      ),
    };
    return Column(
      key: ValueKey('vista_$archivo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                archivo ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Enlace('Elegir otro archivo', onTap: elegir),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (que == QueImportar.activos && imp.total > 0)
              for (final x in _partes(imp)) Pill(x, P.verde, punto: true)
            else
              Pill('${imp.total} ${imp.total == 1 ? 'nuevo' : 'nuevos'}', P.verde, punto: true),
            if (imp.duplicados > 0) Pill('${imp.duplicados} ya estaban', P.textoSuave, punto: true),
            if (imp.avisos.isNotEmpty)
              Pill('${imp.avisos.length} ${imp.avisos.length == 1 ? 'aviso' : 'avisos'}', P.ambar, punto: true),
          ],
        ),
        if (filas.isNotEmpty) ...[const SizedBox(height: 12), _tabla(columnas, filas)],
        if (imp.avisos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Tarjeta(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in _enOrden(imp.avisos).take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: P.ambar),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                if (imp.avisos.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 3),
                    child: Text(
                      'y ${imp.avisos.length - 8} avisos más',
                      style: TextStyle(fontSize: 13, color: P.textoSuave),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() {
                vista = null;
                archivo = null;
              }),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: imp.total == 0 ? null : importar, child: Text('Importar ${imp.total}')),
          ],
        ),
      ],
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
