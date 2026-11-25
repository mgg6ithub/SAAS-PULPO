import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../geo.dart';
import '../importar.dart';
import '../hoja_calculo.dart';
import '../industrial/activo.dart';
import '../industrial/activos.dart' show horas;
import '../industrial/iconos.dart' show IconoActivo;
import '../industrial/plan.dart';
import '../industrial/planes.dart' show proximoPlan;
import '../informes.dart' show guiaPdf, listadoPdf;
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
    // La barra de progreso de arriba sigue el borde redondeado.
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 820),
      child: ImportarExportar(que: que),
    ),
  ),
);

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
  bool verExportar = false;

  /// La tabla desplegada con todas sus filas («y N filas más»).
  bool verTodas = false;

  /// Barra de progreso (0 a 1); null = oculta. [haciendo]: qué se está haciendo, junto al botón.
  double? progreso;
  String? haciendo;

  /// Vista previa: los avisos en lugar de la tabla.
  bool verAvisos = false;
  bool get solo => widget.que != null;

  Future<void> elegir() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionesImportar,
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f?.bytes == null) return;
    await _conProgreso('Leyendo ${f!.name}…', () async {
      final List<List<String>> filas;
      try {
        filas = leerArchivo(f.name, f.bytes!);
      } on FormatException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: ${e.message}')));
        return;
      }
      final imp = prepararImportacion(que, filas, store);
      if (!mounted) return;
      setState(() {
        archivo = f.name;
        vista = imp;
        verTodas = false;
        verAvisos = imp.total == 0 && imp.avisos.isNotEmpty;
      });
    });
  }

  /// Barra morada arriba mientras se lee o se guarda: avanza sola hasta casi el final, se llena al terminar y se
  /// desvanece. Dura al menos un instante, para que se vea aunque sea rápido.
  Future<void> _conProgreso(String texto, Future<void> Function() trabajo) async {
    setState(() {
      progreso = .9;
      haciendo = texto;
    });
    // Se deja ver aunque el trabajo sea instantáneo.
    await Future.wait([trabajo(), Future<void>.delayed(const Duration(milliseconds: 900))]);
    if (!mounted) return;
    setState(() => progreso = 1);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        progreso = null;
        haciendo = null;
      });
    }
  }

  Future<void> importar() async {
    final imp = vista!;
    // Hasta que la base lo tiene todo guardado (sin nube, al momento).
    await _conProgreso('Importando ${imp.total}…', () async {
      imp.aplicar(store);
      await store.nube?.guardado;
    });
    if (!mounted) return;
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
      verTodas = false;
      verAvisos = false;
    });
  }

  @override
  Widget build(BuildContext context) => _contenido(context);

  Widget _contenido(BuildContext context) => ListView(
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
          // Importar o exportar: una cosa cada vez, junto a la X.
          Pestanas(
            compactas: true,
            opciones: const ['Importar', 'Exportar'],
            seleccion: verExportar ? 1 : 0,
            onChanged: (i) => setState(() {
              verExportar = i == 1;
              verTodas = false;
            }),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: Icon(CupertinoIcons.xmark, size: 19, color: P.textoSuave),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // Qué se hace aquí; mismo alto en Importar y en Exportar, para que la ventana no salte al cambiar.
      SizedBox(
        height: 38,
        child: Text(
          verExportar
              ? 'Así saldrán tus ${que.etiqueta.toLowerCase()}. Elige el formato: PDF para leer o imprimir (con las '
                    'columnas que caben), Excel o CSV para hojas de cálculo, o JSON para otros programas.'
              : que == QueImportar.trabajos
              ? m('Cada trabajo va a un cliente que ya exista en Pultec (por nombre o CIF): importa antes los clientes.')
              : 'Rellena la plantilla con estas columnas y súbela tal cual (Excel, CSV o JSON). Pasa el ratón por cada '
                    'columna para ver qué lleva; las de * son obligatorias. Lo que ya está en Pultec no se duplica.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: P.textoSuave),
        ),
      ),
      // Barra de progreso morada al leer y al importar; su hueco está siempre, para que nada salte.
      const SizedBox(height: 6),
      SizedBox(
        height: 4,
        child: AnimatedOpacity(
          opacity: progreso == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progreso ?? 0),
            duration: Duration(milliseconds: (progreso ?? 0) >= 1 ? 250 : 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              color: P.morado,
              backgroundColor: P.moradoSuave,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Desde Ajustes (con todo), el tipo, igual en las dos caras; desde Activos o Técnicos, solo lo suyo.
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
        const SizedBox(height: 14),
      ],
      // Las dos caras con el mismo esqueleto (título, tabla, botón) y el mismo alto: solo cambia el contenido.
      if (verExportar)
        _cara(
          exportar: true,
          derecha: Pestanas(
            compactas: true,
            opciones: [for (final f in FormatoExportar.values) f.etiqueta],
            seleccion: formato.index,
            onChanged: (i) => setState(() => formato = FormatoExportar.values[i]),
          ),
          pastillas: [
            () {
              final n = filasExportar(que, store).length;
              return Pill('$n ${n == 1 ? 'fila' : 'filas'} en ${formato.etiqueta}', P.morado, punto: true);
            }(),
          ],
          contenido: _tablaExportar(),
          sobran: filasExportar(que, store).length - _maxFilas,
          pie: [
            FilledButton(
              onPressed: () =>
                  _exportar(que.etiqueta, [que.columnas, ...filasExportar(que, store)], columnasPdf: columnasPdf(que)),
              child: Text('Descargar ${formato.etiqueta}'),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                () {
                  final n = filasExportar(que, store).length;
                  return '$n ${n == 1 ? 'fila' : 'filas'} en total';
                }(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: P.textoSuave),
              ),
            ),
            if (!industrial) ...[
              const SizedBox(width: 14),
              Flexible(
                child: Enlace('Descargar el histórico', onTap: () => _exportar('Histórico', filasHistorial(store))),
              ),
            ],
          ],
        )
      else if (vista != null)
        _vistaPrevia(vista!)
      else
        _cara(
          exportar: false,
          derecha: Wrap(
            alignment: WrapAlignment.end,
            spacing: 16,
            runSpacing: 6,
            children: [
              // La plantilla en el formato que se prefiera; la de Excel trae la guía en otra hoja.
              _MenuEnlace(
                'Descargar plantilla',
                opciones: [
                  for (final f in [FormatoExportar.excel, FormatoExportar.csv, FormatoExportar.json])
                    (
                      f == FormatoExportar.excel ? 'Excel, con la guía en otra hoja' : f.etiqueta,
                      () => descargar(
                        plantillaBytes(que, f),
                        'plantilla_${que.etiqueta.toLowerCase()}.${f.extension}',
                        f.tipo,
                      ),
                    ),
                ],
              ),
              _MenuEnlace(
                'Descargar guía',
                opciones: [
                  (
                    'PDF',
                    () async => descargar(
                      await guiaPdf(
                        que.etiqueta.toLowerCase(),
                        guiaFilas(que),
                        notas: [if (que == QueImportar.activos) _notaActivos],
                      ),
                      'guia_${que.etiqueta.toLowerCase()}.pdf',
                      FormatoExportar.pdf.tipo,
                    ),
                  ),
                  (
                    'Excel',
                    () => descargar(
                      escribirXlsx([('Guía', guiaFilas(que))]),
                      'guia_${que.etiqueta.toLowerCase()}.xlsx',
                      FormatoExportar.excel.tipo,
                    ),
                  ),
                  (
                    'Texto',
                    () =>
                        descargar(utf8.encode(guiaTexto(que)), 'guia_${que.etiqueta.toLowerCase()}.txt', 'text/plain'),
                  ),
                ],
              ),
            ],
          ),
          pastillas: [Pill('Plantilla con ${que.ejemplos.length} filas de ejemplo', P.morado, punto: true)],
          contenido: _tablaPlantilla(),
          sobran: que.ejemplos.length - _maxFilas,
          pie: [
            FilledButton(onPressed: elegir, child: const Text('Elegir archivo')),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                haciendo ?? 'Excel (.xlsx), CSV o JSON.',
                style: TextStyle(fontSize: 12.5, color: haciendo == null ? P.textoSuave : P.morado),
              ),
            ),
          ],
        ),
    ],
  );

  /// Como mucho se ven estas filas de cada tabla; abajo a la derecha, cuántas más hay.
  static const _maxFilas = 6;

  /// Alto fijo de la zona de la tabla (pastillas y [_maxFilas] filas), igual en Importar, en la vista previa y en
  /// Exportar: la ventana no cambia de alto al pasar de una a otra ni al elegir o importar un archivo.
  static const _altoTabla = 28 + 10 + 46 + 57.0 * _maxFilas + 2;

  /// Esqueleto común: título con su flecha y [derecha] en una fila de 40; en un hueco de alto fijo, las
  /// [pastillas] y la tabla; abajo, el botón (con su nota) a la izquierda y cuántas filas más hay a la derecha.
  Widget _cara({
    required bool exportar,
    required Widget derecha,
    required List<Widget> pastillas,
    required Widget contenido,
    required List<Widget> pie,
    int sobran = 0,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 40,
        child: Row(
          children: [
            _titulo(exportar ? 'Exportar' : 'Importar', exportar: exportar),
            const SizedBox(width: 16),
            // Si no cabe, se desliza.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(children: [derecha]),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: _altoTabla,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 28,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, p) in pastillas.indexed) ...[if (i > 0) const SizedBox(width: 8), p],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Align(alignment: Alignment.topLeft, child: contenido),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      // Abajo: el botón a la izquierda y, a la derecha del todo, cuántas filas más hay.
      SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(child: Row(children: pie)),
            if (sobran > 0) ...[const SizedBox(width: 16), _mas(sobran)],
          ],
        ),
      ),
    ],
  );

  /// Las primeras [_maxFilas] filas; desplegada («y N filas más»), todas, desplazándose dentro del mismo hueco.
  Widget _tablaCorta(List<Col> columnas, List<List<Widget>> filas) => verTodas
      ? SingleChildScrollView(child: _tabla(columnas, filas, maxFilas: filas.length))
      : _tabla(columnas, filas.take(_maxFilas).toList(), maxFilas: _maxFilas);

  /// «y 6 filas más», en morado: lo que no cabe en la tabla.
  /// Al pulsarlo, despliega todas las filas; desplegado, «Ver menos» las recoge.
  Widget _mas(int n) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => setState(() => verTodas = !verTodas),
      child: Text(
        verTodas ? 'Ver menos' : 'y $n ${n == 1 ? 'fila' : 'filas'} más',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.morado),
      ),
    ),
  );

  /// Ancho de una columna según su título.
  double _ancho(String c) => (c.length * 8.5 + 48).clamp(110, 260).toDouble();

  /// La plantilla: sus columnas (con lo que lleva cada una al pasar el ratón) y las filas de ejemplo.
  Widget _tablaPlantilla() => _tablaCorta(
    [
      for (final (c, texto) in que.guia)
        Col(texto.startsWith('Obligatoria') ? '$c *' : c, ancho: _ancho(c), ayuda: texto.isEmpty ? c : texto),
    ],
    [
      for (final f in que.ejemplos) [for (final (i, x) in f.indexed) celdaTexto(x, negrita: i == 0)],
    ],
  );

  /// Lo que se va a exportar, con las columnas del formato elegido (en PDF, las que caben).
  Widget _tablaExportar() {
    final columnas = formato == FormatoExportar.pdf ? columnasPdf(que) : que.columnas;
    final filas = soloColumnas([que.columnas, ...filasExportar(que, store)], columnas);
    if (filas.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text(
          'Aún no hay ${que.etiqueta.toLowerCase()} que exportar.',
          style: TextStyle(fontSize: 13, color: P.textoSuave),
        ),
      );
    }
    return _tablaCorta(
      [for (final c in columnas) Col(c, ancho: _ancho(c))],
      [
        for (final f in filas.skip(1)) [for (final (i, x) in f.indexed) celdaTexto(x, negrita: i == 0)],
      ],
    );
  }

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
      FormatoExportar.excel => escribirXlsx([(titulo, conCabecera)]),
    };
    await descargar(bytes, '$nombre.${formato.extension}', formato.tipo);
  }

  /// Título de sección con su flecha (la de descargar para importar; girada 180 grados para exportar), como el
  /// botón que abre esta ventana.
  Widget _titulo(String t, {required bool exportar}) {
    const icono = Icon(Icons.download_rounded, size: 17);
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(color: P.textoSuave),
            child: exportar ? const RotatedBox(quarterTurns: 2, child: icono) : icono,
          ),
          const SizedBox(width: 8),
          Text(
            t.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.textoSuave),
          ),
        ],
      ),
    );
  }

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
              columnas: [
                for (final x in columnas) Col(x.titulo, ancho: x.ancho! * k, ayuda: x.ayuda, derecha: x.derecha),
              ],
              filas: filas.length,
              celdas: (i) => filas[i],
            ),
          ),
        ),
      );
    },
  );

  /// Fecha estimada de un mantenimiento aún sin guardar, con la misma cuenta que la base: fecha fija; por días,
  /// desde la última vez (o hoy); por horas, el día en que el contador llega con su uso diario.
  DateTime? _proximoNuevo(PlanMantenimiento p, Activo raiz) {
    if (p.proximo != null) return p.proximo;
    if (p.cadaDias != null) return masDias(p.ultimo ?? hoy(), p.cadaDias!);
    if (p.cadaHoras == null || raiz.usoDiario <= 0) return null;
    final quedan = p.cadaHoras! - (raiz.horas - (p.ultimoHoras ?? raiz.horas));
    return quedan <= 0 ? hoy() : masDias(hoy(), (quedan / raiz.usoDiario).ceil());
  }

  /// Lo que se va a crear, con las mismas columnas que su lista (Activos o Técnicos): así se ve igual antes y
  /// después de importar. Mismo esqueleto y alto que la plantilla; los avisos, en su pastilla.
  Widget _vistaPrevia(Importacion imp) {
    // Lo del archivo una sola vez, también mientras se guarda (entonces ya está además en el store).
    final idsNuevos = {for (final a in imp.activos) a.id, for (final p in imp.planes) p.id};
    final todos = [...store.activos.where((a) => !idsNuevos.contains(a.id)), ...imp.activos];
    final planes = [...store.planes.where((p) => !idsNuevos.contains(p.id)), ...imp.planes];
    Activo? activo(String? id) => todos.where((a) => a.id == id).firstOrNull;
    Activo raizDe(Activo a) {
      var r = a;
      for (var i = 0; i < 50 && activo(r.padreId) != null; i++) {
        r = activo(r.padreId)!;
      }
      return r;
    }

    final nuevos = {for (final p in imp.planes) p.id};
    final (columnas, filas) = switch (que) {
      QueImportar.activos => () {
        // Como la lista de Activos: los activos principales, nuevos o que reciben algo nuevo.
        final raices = <Activo>[
          for (final a in todos)
            if (a.padreId == null &&
                (imp.activos.contains(a) ||
                    imp.activos.any((x) => raizDe(x) == a) ||
                    imp.planes.any((p) => activo(p.activoId) != null && raizDe(activo(p.activoId)!) == a)))
              a,
        ]..sort((a, b) => a.titulo.compareTo(b.titulo)); // el mismo orden que la lista de Activos
        return (
          const [
            Col('Activo', ancho: 200),
            Col('Tag', ancho: 100),
            Col('Uso', ancho: 100),
            Col('Horas totales', ancho: 125, derecha: true),
            Col('Mantenimientos', ancho: 140, derecha: true),
            Col('Próximo mantenimiento', ancho: 185),
            Col('Componentes', ancho: 115, derecha: true),
          ],
          [
            for (final r in raices)
              () {
                final rama = [
                  for (final a in todos)
                    if (raizDe(a) == r) a.id,
                ];
                final suyos = [
                  for (final p in planes)
                    if (rama.contains(p.activoId)) p,
                ];
                final fechas = [for (final p in suyos) ?(nuevos.contains(p.id) ? _proximoNuevo(p, r) : proximoPlan(p))]
                  ..sort();
                Widget derecha(String t) =>
                    Padding(padding: const EdgeInsets.only(right: 16), child: celdaTexto(t, suave: true));
                return [
                  Row(
                    children: [
                      IconoActivo(r.icono, color: P.textoSuave, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: celdaTexto(r.nombre.isNotEmpty ? r.nombre : r.titulo, negrita: true)),
                    ],
                  ),
                  celdaTexto(r.tag.isEmpty ? '—' : r.tag, suave: true),
                  celdaTexto(r.horasUso <= 0 ? '—' : '${horas(r.horasUso)} / día', suave: true),
                  derecha(horas(r.horas)),
                  derecha('${suyos.length}'),
                  celdaTexto(fechas.isEmpty ? '—' : fecha(fechas.first), suave: true),
                  derecha('${rama.length - 1}'),
                ];
              }(),
          ],
        );
      }(),
      // Como la lista de Técnicos.
      QueImportar.trabajadores => (
        [
          const Col('Nombre', ancho: 260),
          const Col('Competencias', ancho: 300),
          const Col('Teléfono', ancho: 140),
          Col(m('Trabajos'), ancho: 110, derecha: true),
          const Col('Hoy', ancho: 120),
        ],
        [
          // El mismo orden que la lista de Técnicos.
          for (final w in [...imp.trabajadores]..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto)))
            [
              Row(
                children: [
                  Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        celdaTexto(w.nombreCompleto, negrita: true),
                        if (w.email.isNotEmpty)
                          Text(
                            w.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final c in w.competencias.take(3)) Etiqueta(c, P.morado),
                  if (w.competencias.length > 3)
                    Text('+${w.competencias.length - 3}', style: TextStyle(fontSize: 12, color: P.textoSuave)),
                ],
              ),
              celdaTexto(w.telefono, suave: true),
              Padding(padding: const EdgeInsets.only(right: 16), child: celdaTexto('0')),
              Align(alignment: Alignment.centerLeft, child: Pill(w.estadoHoy.etiqueta, w.estadoHoy.color, punto: true)),
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
    final avisos = _enOrden(imp.avisos);
    return _cara(
      exportar: false,
      derecha: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              archivo ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: P.textoSuave),
            ),
          ),
          const SizedBox(width: 16),
          Enlace('Elegir otro archivo', onTap: elegir),
        ],
      ),
      pastillas: [
        if (que == QueImportar.activos && imp.total > 0)
          for (final x in _partes(imp)) Pill(x, P.verde, punto: true)
        else
          Pill('${imp.total} ${imp.total == 1 ? 'nuevo' : 'nuevos'}', P.verde, punto: true),
        if (imp.duplicados > 0) Pill('${imp.duplicados} ya estaban', P.textoSuave, punto: true),
        // Pulsando los avisos, se ven en lugar de la tabla (y otra vez, la tabla).
        if (avisos.isNotEmpty)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => verAvisos = !verAvisos),
              child: Pill(
                verAvisos ? 'Ver la tabla' : '${avisos.length} ${avisos.length == 1 ? 'aviso' : 'avisos'}',
                P.ambar,
                punto: true,
              ),
            ),
          ),
      ],
      contenido: verAvisos || filas.isEmpty
          ? Tarjeta(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: avisos.isEmpty
                  ? Text('No hay nada nuevo que importar.', style: TextStyle(fontSize: 13, color: P.textoSuave))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final a in avisos)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: P.ambar),
                                const SizedBox(width: 8),
                                Expanded(child: Text(a, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                      ],
                    ),
            )
          : _tablaCorta(columnas, filas),
      sobran: verAvisos ? 0 : filas.length - _maxFilas,
      pie: [
        FilledButton(
          onPressed: imp.total == 0 || progreso != null ? null : importar,
          child: Text('Importar ${imp.total}'),
        ),
        const SizedBox(width: 16),
        Enlace(
          'Cancelar',
          onTap: () => setState(() {
            vista = null;
            archivo = null;
            verTodas = false;
            verAvisos = false;
          }),
        ),
        if (haciendo != null) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              haciendo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: P.morado),
            ),
          ),
        ],
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

/// Pultec: cómo va el archivo de activos (para la guía en PDF).
const _notaActivos =
    'Un solo archivo para todo: una fila por activo o componente («Padre» = el tag de su activo). Con «Mantenimiento» '
    'rellena, le añade ese mantenimiento; repite el tag en otra fila para darle más. Cada mantenimiento sale ya con su '
    'orden de trabajo en la fecha que le toca.';

/// Enlace morado que abre un menú pequeño con [opciones] (texto y qué hace).
class _MenuEnlace extends StatelessWidget {
  final String texto;
  final List<(String, VoidCallback)> opciones;
  const _MenuEnlace(this.texto, {required this.opciones});

  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(0, 6),
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(P.superficie),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    menuChildren: [
      for (final (t, accion) in opciones)
        MenuItemButton(
          onPressed: accion,
          child: Text(t, style: const TextStyle(fontSize: 13.5)),
        ),
    ],
    builder: (context, menu, _) => Enlace(texto, onTap: () => menu.isOpen ? menu.close() : menu.open()),
  );
}
