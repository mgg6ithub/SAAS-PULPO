import 'dart:typed_data';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../geo.dart';
import '../importar.dart';
import '../hoja_calculo.dart';
import '../industrial/activo.dart';
import '../industrial/activos.dart' show horas, listaActivosEnTexto;
import 'trabajadores.dart' show listaTecnicosEnTexto;
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

/// Una lista que se exporta o se imprime tal como se ve en su sección (Órdenes de trabajo, Incidencias,
/// Planificación, Uso de activos): [filas] da la cabecera y las filas con los filtros de ese momento.
class Exportable {
  final String titulo;
  final List<List<String>> Function() filas;
  const Exportable(this.titulo, this.filas);
}

/// Solo exportar e imprimir [lista] (sin importar), con el mismo aspecto que la ventana de Activos.
Future<void> abrirExportar(BuildContext context, Exportable lista) => abrirImportarExportar(context, lista: lista);

/// Importar clientes, trabajadores y trabajos (Pultec: activos y técnicos) desde CSV con vista previa, y exportarlo
/// todo a CSV. [que] abre directamente esa pestaña (desde Activos o Técnicos); con [lista], solo exportar e imprimir.
Future<void> abrirImportarExportar(BuildContext context, {QueImportar? que, Exportable? lista}) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.fondo,
    // La barra de progreso de arriba sigue el borde redondeado.
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 820),
      child: ImportarExportar(que: que, lista: lista),
    ),
  ),
);

class ImportarExportar extends StatefulWidget {
  final QueImportar? que;

  /// Lista para solo exportar e imprimir (sin la pestaña Importar).
  final Exportable? lista;
  const ImportarExportar({super.key, this.que, this.lista});

  /// Arrastrar archivos del sistema (las pruebas lo apagan: no tienen el complemento nativo).
  static bool conArrastrar = true;

  @override
  State<ImportarExportar> createState() => _ImportarExportarState();
}

class _ImportarExportarState extends State<ImportarExportar> {
  late QueImportar que = widget.que ?? importables.first;
  Importacion? vista;
  String? archivo;
  FormatoExportar formato = FormatoExportar.pdf;

  /// 0 Importar, 1 Exportar, 2 Imprimir.
  late int cara = widget.lista == null ? 0 : 1;
  bool get verExportar => cara == 1;
  bool get verImprimir => cara == 2;

  /// Pestañas de arriba: con una lista, solo Exportar e Imprimir.
  List<int> get _caras => widget.lista == null ? const [0, 1, 2] : const [1, 2];

  /// La tabla desplegada con todas sus filas («y N filas más»).
  bool verTodas = false;

  /// Barra de progreso (0 a 1); null = oculta. [haciendo]: qué se está haciendo, junto al botón.
  double? progreso;
  String? haciendo;

  /// Vista previa: los avisos en lugar de la tabla.
  bool verAvisos = false;

  /// Nombres de los archivos leídos (para ordenar sus avisos) y si hay uno encima de la zona de arrastrar.
  List<String> archivos = [];
  bool encima = false;
  bool get solo => widget.que != null || widget.lista != null;

  Future<void> elegir() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionesImportar,
      allowMultiple: true,
      withData: true,
    );
    final fs = [
      for (final f in r?.files ?? <PlatformFile>[])
        if (f.bytes != null) (f.name, f.bytes!),
    ];
    if (fs.isNotEmpty) await _leer(fs);
  }

  /// Archivos soltados en la zona de arrastrar (se leen dentro del evento: luego el navegador los suelta).
  Future<void> _soltar(DropDetails d) async {
    setState(() => encima = false);
    final fs = <(String, Uint8List)>[];
    for (final it in d.items.whereType<DropFileItem>()) {
      fs.add((it.name, await it.file.readAsBytes()));
    }
    if (fs.isNotEmpty) await _leer(fs);
  }

  /// Lee uno o varios archivos (Excel, CSV o JSON), los junta y prepara la vista previa. Un archivo que no se
  /// puede leer, o de una extensión que no vale, sale como aviso con su nombre; el resto se importa igual.
  Future<void> _leer(List<(String, Uint8List)> fs) async {
    final texto = fs.length == 1 ? 'Leyendo ${fs.first.$1}…' : 'Leyendo ${fs.length} archivos…';
    await _conProgreso(texto, () async {
      final leidos = <(String, List<List<String>>)>[];
      final errores = <String>[];
      for (final (nombre, bytes) in fs) {
        if (!extensionesImportar.contains(nombre.toLowerCase().split('.').last)) {
          errores.add('$nombre: no es un Excel, CSV ni JSON; no se importa.');
          continue;
        }
        try {
          leidos.add((nombre, leerArchivo(nombre, bytes)));
        } on FormatException catch (e) {
          errores.add('$nombre: ${e.message}');
        }
      }
      final junto = combinarArchivos(leidos);
      final imp = leidos.isEmpty
          ? Importacion(que)
          : prepararImportacion(que, junto.filas, store, origen: junto.origen);
      imp.avisos.insertAll(0, errores);
      if (!mounted) return;
      setState(() {
        archivos = [for (final (n, _) in fs) n];
        archivo = fs.length == 1 ? fs.first.$1 : '${fs.length} archivos';
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
      SnackBar(duration: const Duration(seconds: 6), 
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
              widget.lista != null
                  ? 'Exportar e imprimir ${widget.lista!.titulo.toLowerCase()}'
                  : solo
                  ? 'Importar y exportar ${que.etiqueta.toLowerCase()}'
                  : 'Importar y exportar',
              style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
            ),
          ),
          // Importar o exportar: una cosa cada vez, junto a la X.
          Pestanas(
            compactas: true,
            opciones: [
              for (final c in _caras) const ['Importar', 'Exportar', 'Imprimir'][c],
            ],
            seleccion: _caras.indexOf(cara),
            onChanged: (i) => setState(() {
              cara = _caras[i];
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
          verImprimir
              ? 'Así saldrá en papel: ${widget.lista == null ? 'como en tu lista, con las mismas columnas y en el orden en que las tengas' : 'tal como lo ves, con los filtros que tengas puestos'}. '
                    'Se abre la ventana de imprimir del navegador; desde ella también puedes guardarlo en PDF.'
              : widget.lista != null
              ? 'Así saldrá «${widget.lista!.titulo}», tal como lo ves: con los filtros que tengas puestos. Elige el '
                    'formato abajo: PDF para leer, Excel o CSV para hojas de cálculo, o JSON para otro programa.'
              : verExportar
              // Dos líneas, como la de Importar, para que las dos caras queden iguales.
              ? 'Así saldrán tus ${que.etiqueta.toLowerCase()}. En PDF, como en tu lista: las mismas columnas, en el '
                    'orden en que las tengas. En Excel, CSV o JSON, con todos sus datos, para abrirlos en otro programa o '
                    'volver a importarlos tal cual.'
              : que == QueImportar.trabajos
              ? m('Cada trabajo va a un cliente que ya exista en Pultec (por nombre o CIF): importa antes los clientes.')
              : 'Descarga la plantilla (con su guía), rellénala y súbela tal cual en Excel, CSV o JSON; puedes subir '
                    'varios archivos a la vez. Antes de guardar se revisa cada fila, y lo que ya está en Pultec no se '
                    'duplica.',
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
      // Las dos caras con el mismo esqueleto (título, tabla, controles) y el mismo alto: solo cambia el contenido.
      if (verImprimir)
        _cara(
          cara: 2,
          cabecera: const [],
          contenido: _tablaExportar(imprimir: true),
          sobran: _filasImprimir().length - 1 - _maxFilas,
          controles: [
            FilledButton.icon(
              onPressed: progreso != null ? null : _imprimir,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimir'),
            ),
          ],
        )
      else if (verExportar)
        _cara(
          cara: 1,
          // Sin pastilla de filas: cuántas hay ya se ve abajo («y N filas más»).
          cabecera: const [],
          contenido: _tablaExportar(),
          sobran: _filasExportadas().length - 1 - _maxFilas,
          controles: [
            if (!industrial) _neutro('Descargar el histórico', () => _exportar('Histórico', filasHistorial(store))),
            Pestanas(
              compactas: true,
              opciones: [for (final f in FormatoExportar.values) f.etiqueta],
              seleccion: formato.index,
              onChanged: (i) => setState(() => formato = FormatoExportar.values[i]),
            ),
            FilledButton(
              onPressed: progreso != null
                  ? null
                  : () => _exportar(widget.lista?.titulo ?? que.etiqueta, _filasExportadas()),
              child: Text('Descargar ${formato.etiqueta}'),
            ),
          ],
        )
      else if (vista != null)
        _vistaPrevia(vista!)
      else
        _cara(
          cara: 0,
          // Arriba a la derecha, como siempre: la plantilla y la guía.
          cabecera: [
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
            const SizedBox(width: 8),
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
                  () => descargar(utf8.encode(guiaTexto(que)), 'guia_${que.etiqueta.toLowerCase()}.txt', 'text/plain'),
                ),
              ],
            ),
          ],
          contenido: _zonaArrastrar(),
          nota: haciendo, // el formato ya lo dice la zona de arrastrar
          controles: [FilledButton(onPressed: progreso == null ? elegir : null, child: const Text('Elegir archivos'))],
        ),
    ],
  );

  /// Como mucho se ven estas filas de cada tabla; abajo a la izquierda, cuántas más hay.
  static const _maxFilas = 6;

  /// Alto fijo de la tabla ([_maxFilas] filas), igual en Importar, en la vista previa y en Exportar: la ventana no
  /// cambia de alto al pasar de una a otra ni al elegir o importar un archivo.
  static const _altoTabla = 46 + 57.0 * _maxFilas + 2;

  /// Pastilla neutra con su icono (activos, componentes, mantenimientos, filas…).
  Widget _pastilla(String texto, IconData icono) => Pill(texto, P.textoSuave, icono: icono);

  /// Icono de lo que se importa o exporta, el de su sección.
  IconData _iconoTipo(QueImportar q) => switch (q) {
    QueImportar.activos || QueImportar.clientes => Marca.iconoCliente,
    QueImportar.trabajadores => Marca.iconoTrabajador,
    QueImportar.trabajos => Icons.content_paste_rounded,
  };

  /// Botón secundario neutro (Cancelar, Elegir otro archivo…).
  Widget _neutro(String texto, VoidCallback? accion) => TextButton(
    style: TextButton.styleFrom(foregroundColor: P.textoSuave),
    onPressed: accion,
    child: Text(texto),
  );

  /// Esqueleto común: título con su flecha y, a la derecha, [cabecera] (pastillas, archivo); la tabla en un hueco
  /// de alto fijo; abajo, a la izquierda cuántas filas más hay y, a la derecha del todo, [nota] y los [controles]
  /// (el principal, el último).
  Widget _cara({
    required int cara,
    required List<Widget> cabecera,
    required Widget contenido,
    required List<Widget> controles,
    String? nota,
    int sobran = 0,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 40,
        child: Row(
          children: [
            _titulo(const ['Importar', 'Exportar', 'Imprimir'][cara], cara: cara),
            const SizedBox(width: 16),
            // Si no cabe, se desliza.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (final (i, w) in cabecera.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: _altoTabla,
        child: Align(alignment: Alignment.topLeft, child: contenido),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 40,
        child: Row(
          children: [
            if (sobran > 0) _mas(sobran),
            const SizedBox(width: 16),
            // A la derecha del todo; si no cabe (ventana estrecha), se desliza.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    if (nota != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          nota,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: haciendo != null ? P.morado : P.textoSuave),
                        ),
                      ),
                    for (final w in controles) ...[const SizedBox(width: 12), w],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  /// Las primeras [_maxFilas] filas; desplegada («y N filas más»), todas, desplazándose dentro del mismo hueco.
  Widget _tablaCorta(List<Col> columnas, List<List<Widget>> filas, {int maxFilas = _maxFilas}) => verTodas
      ? SingleChildScrollView(child: _tabla(columnas, filas, maxFilas: filas.length))
      : _tabla(columnas, filas.take(maxFilas).toList(), maxFilas: maxFilas);

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

  /// Anchos de las columnas de las listas (Activos, Técnicos) en la vista previa de Exportar.
  static const _anchosLista = {
    'Activo': 210.0,
    'Nombre': 220.0,
    'Competencias': 260.0,
    'Grupos': 260.0,
    'Uso': 100.0,
    'Horas totales': 125.0,
    'Mantenimientos': 140.0,
    'Próximo mantenimiento': 185.0,
    'Componentes': 115.0,
    'Fabricante y modelo': 180.0,
    'Orden de trabajo': 220.0,
    'Origen': 130.0,
    'Gravedad': 130.0,
    'Asignado a': 160.0,
    'Fecha y hora': 150.0,
    'Periodicidad': 120.0,
    'Estado': 120.0,
    'Incidencia': 260.0,
    'Comunicada por': 150.0,
    'Día': 160.0,
    'Hora': 120.0,
  };

  /// Ancho de una columna según su título.
  double _ancho(String c) => c.length <= 2 ? 52 : (c.length * 8.5 + 48).clamp(110, 260).toDouble();

  /// [DropTarget] alrededor de [child] (en pruebas, sin él: allí no hay arrastre del sistema).
  Widget _arrastrable({
    required void Function(DragDetails) onEnter,
    required VoidCallback onLeave,
    required Future<void> Function(DropDetails) onDrop,
    required Widget child,
  }) => ImportarExportar.conArrastrar
      ? DropTarget(onEnter: onEnter, onLeave: onLeave, onDrop: onDrop, child: child)
      : child;

  /// Zona de borde discontinuo donde soltar los archivos (uno o varios); pulsarla también abre el selector. Ocupa
  /// el mismo hueco que la tabla de las otras caras.
  Widget _zonaArrastrar() => _arrastrable(
    onEnter: (_) => setState(() => encima = true),
    onLeave: () => setState(() => encima = false),
    onDrop: _soltar,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: progreso == null ? elegir : null,
        child: CustomPaint(
          painter: BordeDiscontinuo(
            encima ? P.morado : P.textoSuave.withValues(alpha: .5),
            BorderRadius.circular(P.radio),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: encima ? P.moradoSuave : Colors.transparent,
              borderRadius: BorderRadius.circular(P.radio),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 34, color: encima ? P.morado : P.textoSuave),
                  const SizedBox(height: 12),
                  Text(
                    encima ? 'Suéltalos para leerlos' : 'Arrastra aquí tus archivos',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: encima ? P.morado : P.texto),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Excel, CSV o JSON, uno o varios a la vez. Antes de guardar verás qué se crea y cada fila con '
                    'problemas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: P.textoSuave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Lo que se va a exportar, con las columnas del formato elegido (en PDF, las que caben).
  /// La lista tal como la ve el usuario en su sección (sus columnas en su orden), para el PDF; null si no hay.
  List<List<String>>? _listaComoSeVe() => !industrial
      ? null
      : switch (que) {
          QueImportar.activos => listaActivosEnTexto(),
          QueImportar.trabajadores => listaTecnicosEnTexto(),
          _ => null,
        };

  /// Lo que sale al exportar, con su cabecera: en PDF, como la lista del usuario (o, si no hay, las columnas que
  /// caben); en Excel, CSV o JSON, todos los datos, para poder volver a importarlo.
  List<List<String>> _filasExportadas() {
    if (widget.lista != null) return widget.lista!.filas();
    final todo = [que.columnas, ...filasExportar(que, store)];
    if (formato != FormatoExportar.pdf) return todo;
    return _listaComoSeVe() ?? soloColumnas(todo, columnasPdf(que));
  }

  /// Lo que se imprime: como el PDF (la lista tal como se ve).
  List<List<String>> _filasImprimir() =>
      widget.lista?.filas() ??
      _listaComoSeVe() ??
      soloColumnas([que.columnas, ...filasExportar(que, store)], columnasPdf(que));

  /// Abre la ventana de imprimir del navegador con la lista en PDF (con la barra de progreso mientras se prepara).
  Future<void> _imprimir() {
    final titulo = widget.lista?.titulo ?? que.etiqueta;
    return _conProgreso('Preparando para imprimir…', () async {
      final bytes = await listadoPdf(titulo, _filasImprimir());
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: titulo);
    });
  }

  Widget _tablaExportar({bool imprimir = false}) {
    final filas = imprimir ? _filasImprimir() : _filasExportadas();
    final columnas = filas.first;
    final derecha = {'Horas totales', 'Mantenimientos', 'Componentes', m('Trabajos')};
    if (filas.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text(
          'Aún no hay ${(widget.lista?.titulo ?? que.etiqueta).toLowerCase()} que exportar.',
          style: TextStyle(fontSize: 13, color: P.textoSuave),
        ),
      );
    }
    final comoLista = widget.lista == null && (imprimir || formato == FormatoExportar.pdf) && _listaComoSeVe() != null;
    final raices = que == QueImportar.activos ? store.hijosDe(null) : const <Activo>[];
    return _tablaCorta(
      [
        for (final c in columnas)
          Col(
            c,
            ancho: comoLista || widget.lista != null ? (_anchosLista[c] ?? _ancho(c)) : _ancho(c),
            derecha: comoLista && derecha.contains(c),
          ),
      ],
      [
        for (final (n, f) in filas.skip(1).indexed)
          [
            for (final (i, x) in f.indexed)
              // Como en la lista: el activo con su icono delante.
              comoLista && columnas[i] == 'Activo' && n < raices.length
                  ? Row(
                      children: [
                        IconoActivo(raices[n].icono, color: P.textoSuave, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: celdaTexto(x, negrita: true)),
                      ],
                    )
                  : comoLista && derecha.contains(columnas[i])
                  ? Padding(padding: const EdgeInsets.only(right: 16), child: celdaTexto(x, suave: true))
                  // Como en la lista: el nombre en negrita y el resto en gris, vaya donde vaya cada columna.
                  : comoLista
                  ? celdaTexto(x, negrita: columnas[i] == 'Nombre', suave: columnas[i] != 'Nombre')
                  : celdaTexto(x, negrita: i == 0),
          ],
      ],
    );
  }

  /// Descarga [conCabecera] en el formato elegido, con la barra de progreso mientras se prepara (un PDF largo
  /// tarda un poco).
  Future<void> _exportar(String titulo, List<List<String>> conCabecera) =>
      _conProgreso('Preparando ${formato.etiqueta}…', () async {
        final nombre = normalizar(titulo).replaceAll(' ', '_');
        final bytes = switch (formato) {
          FormatoExportar.pdf => await listadoPdf(titulo, conCabecera),
          FormatoExportar.csv => utf8.encode(escribirCsv(conCabecera)),
          FormatoExportar.json => utf8.encode(filasJson(conCabecera)),
          FormatoExportar.excel => escribirXlsx([(titulo, conCabecera)]),
        };
        await descargar(bytes, '$nombre.${formato.extension}', formato.tipo);
      });

  /// Título de sección con su flecha (la de descargar para importar; girada 180 grados para exportar), como el
  /// botón que abre esta ventana.
  Widget _titulo(String t, {required int cara}) {
    const icono = Icon(Icons.download_rounded, size: 17);
    final exportar = cara == 1;
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(color: P.textoSuave),
            child: cara == 2
                ? const Icon(Icons.print_outlined, size: 17)
                : exportar
                ? const RotatedBox(quarterTurns: 2, child: icono)
                : icono,
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
    // Por archivo (en el orden en que se eligieron) y, dentro, por fila; lo que no es de una fila, primero.
    (int, int) clave(String a) {
      final f = RegExp(r'[Ff]ila (\d+)').firstMatch(a);
      if (f == null) return (-1, 0);
      final i = archivos.indexWhere((n) => a.startsWith('$n,'));
      return (i < 0 ? 0 : i, int.parse(f[1]!));
    }

    return [...avisos]..sort((a, b) {
      final (x, y) = (clave(a), clave(b));
      return x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2);
    });
  }

  /// «3 activos», «2 componentes», «5 mantenimientos» (lo que haya), cada uno con el icono de su sección.
  List<(String, IconData)> _partes(Importacion imp) {
    String n(int x, String uno, String varios) => '$x ${x == 1 ? uno : varios}';
    final comp = imp.activos.where((a) => a.padreId != null).length;
    return [
      if (imp.activos.length > comp) (n(imp.activos.length - comp, 'activo', 'activos'), Marca.iconoCliente),
      if (comp > 0) (n(comp, 'componente', 'componentes'), Icons.account_tree_outlined),
      if (imp.planes.isNotEmpty) (n(imp.planes.length, 'mantenimiento', 'mantenimientos'), Icons.content_paste_rounded),
    ];
  }

  /// «3 activos, 2 componentes y 5 mantenimientos».
  String _resumen(Importacion imp) {
    final partes = [for (final (t, _) in _partes(imp)) t];
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
          // Otra tabla (otras columnas) empieza desde la izquierda, sin heredar el desplazamiento de la anterior.
          key: ValueKey([for (final x in columnas) x.titulo].join('|')),
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
          Col(industrial ? 'Grupos' : 'Competencias', ancho: 300),
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
                // Pultec: sus grupos (los nuevos del archivo, también), no especialidades.
                children: industrial
                    ? [
                        for (final id in w.grupoIds)
                          if ([...store.grupos, ...imp.grupos].where((g) => g.id == id).firstOrNull case final g?)
                            Etiqueta(g.nombre, P.morado),
                      ]
                    : [
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
      cara: 0,
      // Arriba a la derecha, el archivo leído con su marca de hecho (sale al terminar de leerlo).
      cabecera: [
        AnimatedOpacity(
          opacity: progreso == null ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.check_circle_rounded, size: 17, color: P.verde),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            archivo ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      // Debajo de «Importar», a la izquierda, qué se va a crear; la tabla, una fila menos para caber en el hueco.
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (i, w) in <Widget>[
                    if (que == QueImportar.activos && imp.total > 0)
                      for (final (t, ic) in _partes(imp)) _pastilla(t, ic)
                    else
                      _pastilla('${imp.total} ${imp.total == 1 ? 'nuevo' : 'nuevos'}', _iconoTipo(que)),
                    if (imp.duplicados > 0) _pastilla('${imp.duplicados} ya estaban', Icons.done_all_rounded),
                    // Pulsando los avisos, se ven en lugar de la tabla (y otra vez, la tabla).
                    if (avisos.isNotEmpty)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => verAvisos = !verAvisos),
                          child: Pill(
                            verAvisos ? 'Ver la tabla' : '${avisos.length} ${avisos.length == 1 ? 'aviso' : 'avisos'}',
                            P.ambar,
                            icono: Icons.warning_amber_rounded,
                          ),
                        ),
                      ),
                  ].indexed) ...[if (i > 0) const SizedBox(width: 8), w],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: verAvisos || filas.isEmpty
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
                  : _tablaCorta(columnas, filas, maxFilas: _maxFilas - 1),
            ),
          ),
        ],
      ),
      sobran: verAvisos ? 0 : filas.length - (_maxFilas - 1),
      nota: haciendo,
      controles: [
        _neutro(
          'Cancelar',
          progreso != null
              ? null
              : () => setState(() {
                  vista = null;
                  archivo = null;
                  verTodas = false;
                  verAvisos = false;
                }),
        ),
        FilledButton(
          onPressed: imp.total == 0 || progreso != null ? null : importar,
          child: Text('Importar ${imp.total}'),
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
