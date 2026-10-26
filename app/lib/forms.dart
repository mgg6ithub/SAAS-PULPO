import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'geo.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

// ── Ventana de formulario ──
// Por defecto sale en el centro desde abajo (como una hoja de iOS) y se puede
// arrastrar. Con su botón se acopla a la derecha y vuelve a ser ventana.
// El modo elegido se recuerda para la siguiente vez.

/// Dónde va la ventana: 0 flotando en el centro, -1 acoplada a la izquierda, 1 a la derecha.
int _lado = 0;

/// Nombre de la ruta de las ventanas de [abrirPanel] (el atajo N la reconoce para cerrarla).
const rutaPanel = 'panel';

Future<void> abrirPanel(BuildContext context, Widget panel) => showGeneralDialog(
  context: context,
  routeSettings: const RouteSettings(name: rutaPanel),
  barrierDismissible: true,
  barrierLabel: 'Cerrar',
  barrierColor: P.texto.withValues(alpha: .25),
  transitionDuration: const Duration(milliseconds: 380),
  pageBuilder: (c, a, b) => panel,
  transitionBuilder: (c, a, b, child) => SlideTransition(
    position: Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
    child: child,
  ),
);

class VentanaFormulario extends StatefulWidget {
  final String titulo;
  final String? subtitulo;

  /// Texto pequeño en morado encima del título ("CLIENTE", "TAREA"), como "CONFIGURACIÓN" en Ajustes.
  final String? etiqueta;

  /// A la izquierda del título (el avatar del cliente o del trabajador).
  final Widget? lider;

  /// Arriba a la derecha, antes de acoplar y cerrar (p. ej. los colores).
  final Widget? extra;

  /// Arriba a la derecha, debajo de los botones de acoplar y cerrar (p. ej. la criticidad del trabajo).
  final Widget? bajoBotones;

  /// Al bajar y dejar de ver el campo del nombre, el título pasa a ser este (el nombre escrito).
  final String? tituloDesplazado;
  final List<Widget> campos;
  final VoidCallback onGuardar;
  final VoidCallback? onBorrar;

  /// Lo que falta para poder guardar, en el orden de los campos, con la acción de ir a cada uno. Abajo a la
  /// izquierda sale el primero con un triángulo; al pulsarlo, un menú con todos.
  final List<(String, VoidCallback)> avisos;

  /// Panel fijo dentro de una vista (p. ej. a la derecha del trabajador), no una ventana flotante.
  final bool incrustada;
  const VentanaFormulario({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.etiqueta,
    this.lider,
    this.extra,
    this.bajoBotones,
    this.tituloDesplazado,
    required this.campos,
    required this.onGuardar,
    this.onBorrar,
    this.avisos = const [],
    this.incrustada = false,
  });

  @override
  State<VentanaFormulario> createState() => _VentanaFormularioState();
}

class _VentanaFormularioState extends State<VentanaFormulario> {
  int lado = _lado;
  bool get acoplada => lado != 0;
  Offset desplazamiento = Offset.zero;
  bool arrastrando = false;

  /// Se ha bajado lo bastante como para no ver el campo del nombre.
  bool desplazado = false;
  late final ScrollController scroll = ScrollController()
    ..addListener(() {
      final d = scroll.offset > 140;
      if (d != desplazado) setState(() => desplazado = d);
    });

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  /// Acopla a ese lado; si ya estaba ahí, vuelve a ventana.
  void acoplar(int l) => setState(() {
    lado = _lado = lado == l ? 0 : l;
    desplazamiento = Offset.zero;
  });

  @override
  Widget build(BuildContext context) {
    if (widget.incrustada) {
      return Material(
        color: P.superficie,
        shape: Border(left: BorderSide(color: P.borde)),
        child: Column(
          children: [
            _cabecera(),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(32, 6, 32, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.campos),
              ),
            ),
            const Divider(),
            _pie(),
          ],
        ),
      );
    }
    final pantalla = MediaQuery.sizeOf(context);
    // Mismo ancho centrada y acoplada: al cambiar de modo solo se mueve el marco y los campos no se
    // recolocan (cambiar de ancho rehacía todo el formulario de golpe y daba un tirón).
    final ancho = min(860.0, pantalla.width - 48);
    final alto = acoplada ? pantalla.height : min(pantalla.height * .9, 900.0);
    var left = lado < 0 ? 0.0 : pantalla.width - ancho;
    var top = 0.0;
    if (!acoplada) {
      // Que la cabecera nunca se salga de la pantalla al arrastrar.
      left = ((pantalla.width - ancho) / 2 + desplazamiento.dx).clamp(120 - ancho, pantalla.width - 120).toDouble();
      top = ((pantalla.height - alto) / 2 + desplazamiento.dy).clamp(0, pantalla.height - 80).toDouble();
    }
    return Stack(
      children: [
        AnimatedPositioned(
          duration: arrastrando ? Duration.zero : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          left: left,
          top: top,
          width: ancho,
          height: alto,
          child: Material(
            color: P.superficie,
            elevation: 24,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(acoplada ? 0 : 14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _cabecera(),
                const Divider(),
                Expanded(
                  child: ClipRect(
                    // Solo el marco cambia de tamaño en cada fotograma. Los campos conservan
                    // el ancho de destino, sin escalar texto ni repetir su maquetación.
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: ancho,
                      maxWidth: ancho,
                      child: SingleChildScrollView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(32, 6, 32, 32),
                        child: RepaintBoundary(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.campos),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                _pie(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _titulo {
    final t = widget.tituloDesplazado?.trim() ?? '';
    return desplazado && t.isNotEmpty ? t : widget.titulo;
  }

  Widget _cabecera() => MouseRegion(
    cursor: acoplada || widget.incrustada ? MouseCursor.defer : SystemMouseCursors.move,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: acoplada || widget.incrustada ? null : (_) => setState(() => arrastrando = true),
      onPanUpdate: acoplada || widget.incrustada ? null : (d) => setState(() => desplazamiento += d.delta),
      onPanEnd: acoplada || widget.incrustada ? null : (_) => setState(() => arrastrando = false),
      child: Stack(
        children: [
          Padding(
            // Compacta: una sola fila con avatar, título, colores y botones; el espacio, para los datos.
            // A la derecha, sitio para los botones de ventana (y la criticidad debajo, si la hay).
            padding: EdgeInsets.fromLTRB(
              32,
              acoplada || widget.incrustada ? 16 : 6,
              widget.incrustada ? 12 : (widget.bajoBotones != null ? 240 : 120),
              8,
            ),
            child: Column(
              children: [
                if (!acoplada && !widget.incrustada) const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.lider != null) ...[widget.lider!, const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.etiqueta != null)
                            Text(
                              widget.etiqueta!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                                color: P.morado,
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            layoutBuilder: (actual, anteriores) =>
                                Stack(alignment: Alignment.centerLeft, children: [...anteriores, ?actual]),
                            child: Text(
                              _titulo,
                              key: ValueKey(_titulo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: P.titulos,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.5,
                              ),
                            ),
                          ),
                          if (widget.subtitulo != null)
                            Text(
                              widget.subtitulo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: P.textoSuave, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    if (widget.extra != null) ...[const SizedBox(width: 12), widget.extra!, const SizedBox(width: 8)],
                  ],
                ),
              ],
            ),
          ),
          if (!acoplada && !widget.incrustada)
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: P.borde, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
          if (!widget.incrustada)
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BotonVentana(
                    lado < 0 ? CupertinoIcons.rectangle : CupertinoIcons.sidebar_left,
                    lado < 0 ? 'Acoplar al centro' : 'Acoplar a la izquierda',
                    () => acoplar(-1),
                    centro: lado < 0,
                  ),
                  _BotonVentana(
                    lado > 0 ? CupertinoIcons.rectangle : CupertinoIcons.sidebar_right,
                    lado > 0 ? 'Acoplar al centro' : 'Acoplar a la derecha',
                    () => acoplar(1),
                    centro: lado > 0,
                  ),
                  const SizedBox(width: 4),
                  _BotonVentana(CupertinoIcons.xmark, 'Cerrar', () => Navigator.pop(context)),
                ],
              ),
            ),
          // A la altura del título, bajo los botones de ventana.
          if (widget.bajoBotones != null && !widget.incrustada)
            Positioned(top: acoplada ? 40 : 42, right: 12, child: widget.bajoBotones!),
        ],
      ),
    ),
  );

  Widget _pie() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      children: [
        if (widget.onBorrar != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: P.rojo),
            onPressed: widget.onBorrar,
            child: const Text('Eliminar'),
          ),
        Expanded(
          child: widget.avisos.isEmpty
              ? const SizedBox()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: widget.onBorrar != null ? 12 : 0),
                    child: _Avisos(widget.avisos),
                  ),
                ),
        ),
        if (!widget.incrustada) ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: P.textoSuave),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton(onPressed: widget.onGuardar, child: const Text('Guardar')),
      ],
    ),
  );
}

/// Avisos de la barra de abajo: triángulo, el primero que falta (y cuántos más) y flechas; al pulsarlo,
/// la lista en orden, y elegir uno lleva la vista a su campo.
class _Avisos extends StatelessWidget {
  final List<(String, VoidCallback)> avisos;
  const _Avisos(this.avisos);

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: BotonMenu<int>(
      tooltip: 'Lo que falta para guardar',
      seleccionado: 0,
      onSelected: (i) => avisos[i].$2(),
      opciones: [
        for (final (i, (texto, _)) in avisos.indexed)
          (
            i,
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: P.rojo),
                const SizedBox(width: 8),
                Text(texto),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 17, color: P.rojo),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                avisos.first.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: P.rojo, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (avisos.length > 1)
              Text(
                '  +${avisos.length - 1}',
                style: const TextStyle(color: P.rojo, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_up_chevron_down, size: 13, color: P.rojo),
          ],
        ),
      ),
    ),
  );
}

/// Botón de la cabecera de la ventana: icono fino (SF Symbols), cuadrado de 34 y fondo suave al estar activo.
class _BotonVentana extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  final bool centro;
  const _BotonVentana(this.icono, this.tooltip, this.onTap, {this.centro = false});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      fixedSize: const Size(34, 34),
      minimumSize: const Size(34, 34),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl - 2)),
    ),
    icon: centro
        ? SizedBox(
            width: 19,
            height: 19,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(CupertinoIcons.rectangle, size: 19, color: P.textoSuave),
                Icon(CupertinoIcons.line_horizontal_3, size: 8, color: P.textoSuave),
              ],
            ),
          )
        : Icon(icono, size: 19, color: P.textoSuave),
  );
}

// ── Piezas de formulario ──

Widget etiqueta(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    t,
    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: P.textoSuave),
  ),
);

/// [obligatorio]: deja reservada la línea del aviso bajo el campo, para que al aparecer «Ponle un nombre»
/// no se mueva nada hacia abajo.
Widget campo(
  String label,
  TextEditingController c, {
  String? hint,
  int lineas = 1,
  String? error,
  bool obligatorio = false,
}) => Padding(
  padding: EdgeInsets.only(bottom: obligatorio ? 0 : 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      etiqueta(label),
      TextField(
        controller: c,
        maxLines: lineas,
        decoration: InputDecoration(hintText: hint, errorText: error, helperText: obligatorio ? ' ' : null),
      ),
    ],
  ),
);

/// Bloque de formulario estilo Jobber: título y explicación a la izquierda, campos a la derecha.
/// En ventanas estrechas se apila.
class Bloque extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final List<Widget> children;

  /// El primero va pegado a la cabecera, que ya tiene su línea: sin línea encima.
  final bool primero;

  /// Bajo la descripción, en la columna del título (p. ej. los colores del trabajo).
  final Widget? pie;
  const Bloque(this.titulo, this.children, {super.key, this.descripcion, this.primero = false, this.pie});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    // Solo se reconstruye al cruzar el umbral de apilar: al acoplar (cambia el ancho) no se rehace el formulario.
    child: SegunTamano(
      clave: (box) => box.maxWidth < 640,
      builder: (context, box) {
        final cabeza = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontFamily: P.titulos, fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            if (descripcion != null) ...[
              const SizedBox(height: 4),
              Text(descripcion!, style: TextStyle(fontSize: 12.5, color: P.textoSuave, height: 1.4)),
            ],
            if (pie != null) ...[const SizedBox(height: 14), pie!],
          ],
        );
        final campos = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
        final contenido = box.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cabeza, const SizedBox(height: 14), campos],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 210, child: cabeza),
                  const SizedBox(width: 32),
                  Expanded(child: campos),
                ],
              );
        return Container(
          padding: EdgeInsets.only(top: primero ? 16 : 22, bottom: 10),
          decoration: BoxDecoration(
            border: primero ? null : Border(top: BorderSide(color: P.borde)),
          ),
          child: contenido,
        );
      },
    ),
  );
}

Widget dos(Widget a, Widget b) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: a),
    const SizedBox(width: 12),
    Expanded(child: b),
  ],
);

Widget conMargen(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w);

class CampoFecha extends StatelessWidget {
  final String label;
  final DateTime? valor;
  final ValueChanged<DateTime> onChanged;

  /// Fecha máxima elegible (p. ej. hoy, para algo que ya se hizo).
  final DateTime? hasta;
  const CampoFecha(this.label, this.valor, this.onChanged, {super.key, this.hasta});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta(label),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: valor == null || (hasta != null && valor!.isAfter(hasta!))
                  ? (hasta ?? DateTime.now())
                  : valor!,
              firstDate: DateTime(2000),
              lastDate: hasta ?? DateTime(2100),
            );
            if (d != null) onChanged(d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
            child: Text(fecha(valor), style: TextStyle(color: valor == null ? P.textoSuave : P.texto)),
          ),
        ),
      ],
    ),
  );
}

const duraciones = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480];

String duracion(int m) => m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min');

class CampoHora extends StatelessWidget {
  final String label;
  final int? valor; // minutos desde las 00:00
  final ValueChanged<int> onChanged;
  const CampoHora(this.label, this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta(label),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final h = await showTimePicker(
              context: context,
              initialTime: valor == null
                  ? const TimeOfDay(hour: 9, minute: 0)
                  : TimeOfDay(hour: valor! ~/ 60, minute: valor! % 60),
            );
            if (h != null) onChanged(h.hour * 60 + h.minute);
          },
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.schedule_rounded, size: 18)),
            child: Text(
              valor == null ? '—' : hhmm(valor!),
              style: TextStyle(color: valor == null ? P.textoSuave : P.texto),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget selectorColor(int actual, ValueChanged<int> onChanged, {double size = 26}) => Wrap(
  spacing: size * .3,
  runSpacing: 8,
  children: [
    for (var i = 0; i < paleta.length; i++)
      InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: paleta[i],
            shape: BoxShape.circle,
            border: Border.all(color: i == actual ? P.superficie : Colors.transparent, width: 2),
            boxShadow: i == actual ? [BoxShadow(color: paleta[i], spreadRadius: 2)] : null,
          ),
          child: i == actual ? Icon(Icons.check_rounded, size: size * .58, color: Colors.white) : null,
        ),
      ),
  ],
);

/// Foto o logotipo de la cabecera del formulario. Sin foto: cuadro discontinuo con un icono de imagen;
/// al pulsarlo se puede arrastrar una imagen o elegirla del ordenador.
class FotoFormulario extends StatelessWidget {
  final String foto; // PNG en base64; vacío = sin foto
  final ValueChanged<String> onCambio;
  final bool cuadrado;
  const FotoFormulario({super.key, required this.foto, required this.onCambio, this.cuadrado = false});

  static const _lado = 40.0;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(cuadrado ? 10 : _lado / 2);
    return Tooltip(
      message: foto.isEmpty ? 'Añadir foto' : 'Cambiar foto',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            final f = await _elegirFoto(context, foto);
            if (f != null) onCambio(f);
          },
          child: foto.isEmpty
              ? CustomPaint(
                  painter: BordeDiscontinuo(P.textoSuave.withValues(alpha: .6), radio),
                  child: SizedBox(
                    width: _lado,
                    height: _lado,
                    child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: P.textoSuave),
                  ),
                )
              : ClipRRect(
                  borderRadius: radio,
                  child: Image.memory(base64Decode(foto), width: _lado, height: _lado, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }
}

/// Reduce la imagen a 256 px de ancho y la devuelve en PNG base64 (cabe de sobra en el guardado local).
Future<String> _reducir(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
  final imagen = (await codec.getNextFrame()).image;
  final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return base64Encode(png!.buffer.asUint8List());
}

/// Ventanita para poner la foto: zona donde arrastrar una imagen o botón para elegirla.
/// Devuelve la nueva foto, '' si se quita, o null si se cancela.
Future<String?> _elegirFoto(BuildContext context, String actual) => showDialog<String>(
  context: context,
  builder: (c) => Dialog(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _ZonaFoto(actual)),
  ),
);

class _ZonaFoto extends StatefulWidget {
  final String actual;
  const _ZonaFoto(this.actual);

  @override
  State<_ZonaFoto> createState() => _ZonaFotoState();
}

class _ZonaFotoState extends State<_ZonaFoto> {
  bool encima = false, cargando = false;
  String? error;

  Future<void> _usar(Future<Uint8List?> leer) async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final bytes = await leer;
      if (bytes == null) return setState(() => cargando = false);
      final foto = await _reducir(bytes);
      if (mounted) Navigator.pop(context, foto);
    } catch (_) {
      if (mounted) {
        setState(() {
          cargando = false;
          error = 'No se ha podido leer esa imagen';
        });
      }
    }
  }

  Future<Uint8List?> _desdeArchivo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    return r?.files.firstOrNull?.bytes;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Foto',
          style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('Una foto, el logotipo del cliente o lo que quieras.', style: TextStyle(color: P.textoSuave)),
        const SizedBox(height: 16),
        DropTarget(
          onEnter: (_) => setState(() => encima = true),
          onLeave: () => setState(() => encima = false),
          // La imagen hay que leerla dentro de onDrop: después el navegador puede soltarla.
          onDrop: (d) async {
            setState(() => encima = false);
            final f = d.items.whereType<DropFileItem>().firstOrNull;
            if (f != null) await _usar(f.file.readAsBytes());
          },
          child: CustomPaint(
            painter: BordeDiscontinuo(
              encima ? P.morado : P.textoSuave.withValues(alpha: .5),
              BorderRadius.circular(P.radio),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 180,
              decoration: BoxDecoration(
                color: encima ? P.moradoSuave : P.fondo,
                borderRadius: BorderRadius.circular(P.radio),
              ),
              child: Center(
                child: cargando
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 34, color: encima ? P.morado : P.textoSuave),
                          const SizedBox(height: 10),
                          Text(
                            'Arrastra una imagen aquí',
                            style: TextStyle(fontWeight: FontWeight.w600, color: encima ? P.morado : P.texto),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => _usar(_desdeArchivo()),
                            child: const Text('Elegir del ordenador'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: P.rojo, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (widget.actual.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: P.rojo),
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('Quitar foto'),
              ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: P.textoSuave),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Elegir una opción entre pastillas de su color (estado de hoy, estado de la máquina…).
class SelectorEstado<T> extends StatelessWidget {
  final List<(T, String, Color)> opciones;
  final T valor;
  final ValueChanged<T> onChanged;
  const SelectorEstado({super.key, required this.opciones, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (v, texto, color) in opciones)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: v == valor ? color.withValues(alpha: .12) : P.superficie,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: v == valor ? color : P.borde, width: v == valor ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: v == valor ? FontWeight.w700 : FontWeight.w500,
                    color: v == valor ? color : P.texto,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Widget chipsCompetencias(List<String> seleccion, VoidCallback onChanged) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    for (final c in competencias)
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          seleccion.contains(c) ? seleccion.remove(c) : seleccion.add(c);
          onChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: seleccion.contains(c) ? P.morado : P.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: seleccion.contains(c) ? P.morado : P.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                seleccion.contains(c) ? Icons.check_rounded : Icons.add_rounded,
                size: 14,
                color: seleccion.contains(c) ? Colors.white : P.textoSuave,
              ),
              const SizedBox(width: 5),
              Text(
                c,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: seleccion.contains(c) ? Colors.white : P.texto,
                ),
              ),
            ],
          ),
        ),
      ),
  ],
);

// ── Cliente ──

Future<void> abrirClienteForm(BuildContext context, [Cliente? c]) => abrirPanel(context, ClienteForm(original: c));

class ClienteForm extends StatefulWidget {
  final Cliente? original;
  const ClienteForm({super.key, this.original});

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  late final Cliente c =
      widget.original?.copia() ?? Cliente(id: store.nuevoId(), color: store.clientes.length % paleta.length);
  late final nombre = TextEditingController(text: c.nombre)..addListener(() => setState(() {}));
  late final cif = TextEditingController(text: c.cif);
  late final direccion = TextEditingController(text: c.direccion);
  late final ciudad = TextEditingController(text: c.ciudad);
  late final cp = TextEditingController(text: c.cp);
  late final provincia = TextEditingController(text: c.provincia);
  late final telefono = TextEditingController(text: c.telefono);
  late final email = TextEditingController(text: c.email);
  late final contacto = TextEditingController(text: c.contacto);
  late final telContacto = TextEditingController(text: c.telefonoContacto);
  late final notas = TextEditingController(text: c.notas);
  String? error;

  void guardar() {
    if (nombre.text.trim().isEmpty) {
      setState(() => error = 'El nombre es obligatorio');
      return;
    }
    c
      ..nombre = nombre.text.trim()
      ..cif = cif.text.trim()
      ..direccion = direccion.text.trim()
      ..ciudad = ciudad.text.trim()
      ..cp = cp.text.trim()
      ..provincia = provincia.text.trim()
      ..telefono = telefono.text.trim()
      ..email = email.text.trim()
      ..contacto = contacto.text.trim()
      ..telefonoContacto = telContacto.text.trim()
      ..notas = notas.text.trim();
    // Si la dirección es nueva o ha cambiado, se ubica en el mapa en segundo plano.
    final cambio = c.direccionCompleta != (widget.original?.direccionCompleta ?? '');
    if (cambio || !c.ubicado) {
      c
        ..lat = null
        ..lng = null;
      final copia = c.copia();
      ubicar(copia).then((ok) {
        if (ok && store.cliente(copia.id) != null) {
          store.cliente(copia.id)!
            ..lat = copia.lat
            ..lng = copia.lng;
          store.guardarCliente(store.cliente(copia.id)!);
        }
      });
    }
    store.guardarCliente(c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Clientes',
    titulo: widget.original == null ? 'Nuevo cliente' : 'Editar cliente',
    tituloDesplazado: nombre.text,
    lider: FotoFormulario(foto: c.foto, cuadrado: true, onCambio: (f) => setState(() => c.foto = f)),
    extra: selectorColor(c.color, (i) => setState(() => c.color = i), size: 20),
    onGuardar: guardar,
    onBorrar: widget.original == null
        ? null
        : () async {
            final nav = Navigator.of(context);
            if (await confirmar(context, '¿Eliminar ${c.nombre} y todos sus trabajos?')) {
              store.borrarCliente(c.id);
              nav.pop();
            }
          },
    campos: [
      Bloque('Datos del cliente', primero: true, descripcion: 'Cómo se llama y cómo contactar con él.', [
        campo('Nombre', nombre, hint: 'Colegio San José', error: error, obligatorio: true),
        dos(campo('Teléfono', telefono), campo('Email', email)),
      ]),
      Bloque('Persona de contacto', descripcion: 'Con quién hablas para coordinar las visitas.', [
        dos(campo('Nombre', contacto, hint: 'Administrador, conserje…'), campo('Teléfono', telContacto)),
      ]),
      Bloque('Dirección', descripcion: 'Dónde está. Con ella se sitúa en el mapa de la agenda.', [
        campo('Calle y número', direccion),
        dos(campo('Ciudad', ciudad), campo('Código postal', cp)),
        campo('Provincia', provincia),
      ]),
      Bloque('Datos fiscales', descripcion: 'Para facturar más adelante.', [
        dos(campo('CIF/NIF', cif), CampoFecha('Cliente desde', c.fechaAlta, (d) => setState(() => c.fechaAlta = d))),
      ]),
      Bloque('Notas', [
        campo('Notas internas', notas, lineas: 3),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activo'),
          subtitle: const Text('Un cliente inactivo no aparece en la planificación.'),
          value: c.activa,
          onChanged: (v) => setState(() => c.activa = v),
        ),
      ]),
    ],
  );
}

// ── Trabajador ──

Future<void> abrirTrabajadorForm(BuildContext context, [Trabajador? w]) =>
    abrirPanel(context, TrabajadorForm(original: w));

class TrabajadorForm extends StatefulWidget {
  final Trabajador? original;

  /// Fijo a la derecha de la vista del trabajador: guardar no cierra nada.
  final bool incrustada;
  const TrabajadorForm({super.key, this.original, this.incrustada = false});

  @override
  State<TrabajadorForm> createState() => _TrabajadorFormState();
}

class _TrabajadorFormState extends State<TrabajadorForm> {
  late final Trabajador w =
      widget.original?.copia() ?? Trabajador(id: store.nuevoId(), color: store.trabajadores.length % paleta.length);
  late final nombre = TextEditingController(text: w.nombre)..addListener(() => setState(() {}));
  late final apellidos = TextEditingController(text: w.apellidos)..addListener(() => setState(() {}));
  late final telefono = TextEditingController(text: w.telefono);
  late final email = TextEditingController(text: w.email);
  late final titulos = TextEditingController(text: w.titulos);
  late final info = TextEditingController(text: w.info);
  String? error, errorCompetencias;

  void guardar() {
    setState(() {
      error = nombre.text.trim().isEmpty ? 'El nombre es obligatorio' : null;
      errorCompetencias = w.competencias.isEmpty ? 'Elige al menos una competencia' : null;
    });
    if (error != null || errorCompetencias != null) return;
    w
      ..nombre = nombre.text.trim()
      ..apellidos = apellidos.text.trim()
      ..telefono = telefono.text.trim()
      ..email = email.text.trim()
      ..titulos = titulos.text.trim()
      ..info = info.text.trim();
    store.guardarTrabajador(w.copia());
    if (widget.incrustada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, width: 320, content: Text('${w.nombreCompleto} guardado')),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Trabajadores',
    titulo: widget.original == null ? 'Nuevo trabajador' : (widget.incrustada ? 'Ficha' : 'Editar trabajador'),
    tituloDesplazado: '${nombre.text} ${apellidos.text}',
    lider: FotoFormulario(foto: w.foto, onCambio: (f) => setState(() => w.foto = f)),
    extra: selectorColor(w.color, (i) => setState(() => w.color = i), size: 20),
    incrustada: widget.incrustada,
    onGuardar: guardar,
    onBorrar: widget.original == null
        ? null
        : () async {
            final nav = Navigator.of(context);
            if (await confirmar(context, '¿Eliminar a ${w.nombreCompleto}?')) {
              store.borrarTrabajador(w.id);
              if (!widget.incrustada) nav.pop();
            }
          },
    campos: [
      Bloque('Datos personales', primero: true, descripcion: 'Nombre y forma de contacto.', [
        dos(campo('Nombre', nombre, error: error, obligatorio: true), campo('Apellidos', apellidos)),
        dos(campo('Teléfono', telefono), campo('Email', email)),
      ]),
      Bloque('Competencias', descripcion: 'Qué sabe hacer. Pulpo solo le asigna trabajos que puede hacer.', [
        chipsCompetencias(w.competencias, () => setState(() => errorCompetencias = null)),
        if (errorCompetencias != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(errorCompetencias!, style: const TextStyle(color: P.rojo, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        campo('Títulos y carnés', titulos, hint: 'Carné RITE, PRL 60 h…'),
      ]),
      Bloque('Disponibilidad', descripcion: 'Cómo está hoy. Los ausentes no reciben trabajos.', [
        conMargen(
          SelectorEstado<EstadoHoy>(
            opciones: [for (final e in EstadoHoy.values) (e, e.etiqueta, e.color)],
            valor: w.estadoHoy,
            onChanged: (e) => setState(() => w.estadoHoy = e),
          ),
        ),
      ]),
      Bloque('Notas', [
        campo('Información básica', info, lineas: 2),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activo'),
          subtitle: const Text('Si está de baja o ya no trabaja, desactívalo.'),
          value: w.activo,
          onChanged: (v) => setState(() => w.activo = v),
        ),
      ]),
    ],
  );
}

// ── Tarea ──

/// [fecha], [horaMin] y [trabajadorId] rellenan la tarea nueva (p. ej. al crearla desde un hueco de la agenda).
Future<void> abrirTareaForm(
  BuildContext context,
  Tarea? t, {
  String? clienteId,
  bool plantilla = false,
  DateTime? fecha,
  int? horaMin,
  String? trabajadorId,
}) => abrirPanel(
  context,
  TareaForm(
    original: t,
    clienteId: clienteId,
    plantilla: plantilla,
    fecha: fecha,
    horaMin: horaMin,
    trabajadorId: trabajadorId,
  ),
);

class TareaForm extends StatefulWidget {
  final Tarea? original;
  final String? clienteId;
  final DateTime? fecha;
  final int? horaMin;
  final String? trabajadorId;

  /// Crear una plantilla (sin cliente) en vez de una tarea.
  final bool plantilla;
  const TareaForm({
    super.key,
    this.original,
    this.clienteId,
    this.plantilla = false,
    this.fecha,
    this.horaMin,
    this.trabajadorId,
  });

  @override
  State<TareaForm> createState() => _TareaFormState();
}

class _TareaFormState extends State<TareaForm> {
  late final Tarea t =
      widget.original?.copia() ??
      Tarea(
        id: store.nuevoId(),
        clienteId: widget.clienteId,
        plantilla: widget.plantilla,
        proximo: widget.fecha ?? hoy(),
        periodicidad: widget.plantilla ? Periodicidad.mensual : Periodicidad.unica,
        inicioMin: widget.horaMin,
        trabajadorIds: [?widget.trabajadorId],
        criticidad: Criticidad.rutinaria,
      );
  late final nombre = TextEditingController(text: t.nombre)..addListener(() => setState(() {}));
  late final marca = TextEditingController(text: t.marca);
  late final modelo = TextEditingController(text: t.modelo);
  late final serie = TextEditingController(text: t.numeroSerie);
  late final ubicacion = TextEditingController(text: t.ubicacion);
  late final notas = TextEditingController(text: t.notas);
  bool intentoGuardar = false;

  bool get nueva => widget.original == null;

  // Tras el primer intento de guardar, los avisos se recalculan al escribir: se van al rellenar y vuelven al vaciar.
  String? get error => intentoGuardar && nombre.text.trim().isEmpty ? 'Ponle un nombre' : null;

  String? get errorHorario {
    if (!intentoGuardar || t.esPlantilla) return null;
    if (t.inicioMin == null) return 'Pon una hora';
    if (t.ventanaDesdeMin != null || t.ventanaHastaMin != null) {
      if (!t.conFranja) return 'Pon una hora';
      if (t.ventanaHastaMin! <= t.ventanaDesdeMin!) {
        return 'La hora de fin debe ser posterior a la de inicio';
      }
    }
    return null;
  }

  /// Rellena la tarea con los datos de una plantilla.
  void aplicar(Tarea p) => setState(() {
    store.usarPlantilla(p.id);
    t
      ..plantillaId = p.id
      ..tipo = p.tipo
      ..periodicidad = p.periodicidad
      ..competencias = [...p.competencias]
      ..proximo = t.proximo ?? widget.fecha ?? hoy();
    nombre.text = p.nombre;
    marca.text = p.marca;
    modelo.text = p.modelo;
    notas.text = p.notas;
    final mejor = store.mejorPara(t);
    t.trabajadorIds = widget.trabajadorId != null ? [widget.trabajadorId!] : (mejor == null ? [] : [mejor.id]);
  });

  /// Campos obligatorios, en el orden en que aparecen: al guardar con uno vacío se lleva la vista al primero.
  final _claveNombre = GlobalKey(), _claveCuando = GlobalKey();

  void _irA(GlobalKey clave) => WidgetsBinding.instance.addPostFrameCallback((_) {
    final c = clave.currentContext;
    if (c != null) {
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: .2,
      );
    }
  });

  void guardar() {
    setState(() => intentoGuardar = true);
    if (error != null) return _irA(_claveNombre);
    if (errorHorario != null) return _irA(_claveCuando);
    t
      ..nombre = nombre.text.trim()
      ..marca = marca.text.trim()
      ..modelo = modelo.text.trim()
      ..numeroSerie = serie.text.trim()
      ..ubicacion = ubicacion.text.trim()
      ..notas = notas.text.trim();
    store.guardarTarea(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final aptos = store.trabajadores.where((w) => store.esApto(w, t)).length;
    final plantillas = store.plantillasPorUso.where((p) => p.id != t.id).toList();

    return VentanaFormulario(
      etiqueta: t.esPlantilla ? 'Plantillas' : 'Trabajos',
      titulo: nueva ? (t.esPlantilla ? 'Nueva plantilla' : 'Nuevo trabajo') : nombre.text,
      tituloDesplazado: nombre.text,
      subtitulo: t.esPlantilla
          ? 'Sin cliente: sirve de plantilla para crear trabajos en tus clientes.'
          : store.cliente(t.clienteId)?.nombre,
      bajoBotones: _MenuCriticidad(t.criticidad, (c) => setState(() => t.criticidad = c)),
      onGuardar: guardar,
      avisos: [
        if (error != null) ('Te falta el nombre', () => _irA(_claveNombre)),
        if (errorHorario != null)
          (errorHorario == 'Pon una hora' ? 'Te falta la hora' : errorHorario!, () => _irA(_claveCuando)),
      ],
      onBorrar: nueva
          ? null
          : () async {
              final nav = Navigator.of(context);
              if (await confirmar(context, '¿Eliminar "${t.nombre}"?')) {
                store.borrarTarea(t.id);
                nav.pop();
              }
            },
      // Mismo esquema que cliente y trabajador: bloques con su título a la izquierda y los campos a la derecha.
      campos: [
        Bloque(
          t.esPlantilla ? 'Plantilla' : 'Trabajo',
          primero: true,
          descripcion: t.esPlantilla ? 'Cómo se llama y de qué tipo es.' : 'Qué hay que hacer y de qué tipo es.',
          [
            KeyedSubtree(
              key: _claveNombre,
              child: campo(
                'Nombre',
                nombre,
                hint: t.esPlantilla
                    ? 'Revisión de ascensor, corte de césped…'
                    : 'Ascensor portal A, centralita de incendios…',
                error: error,
                obligatorio: true,
              ),
            ),
            // Tipo: plantillas (tarea nueva) o tipos (plantilla).
            if (t.esPlantilla) ...[
              etiqueta('Tipo'),
              conMargen(
                SelectorTipo(
                  t.tipo,
                  (v) => setState(() {
                    t.tipo = v;
                    final c = tipoDe(v).competencia;
                    if (c != null && !t.competencias.contains(c)) t.competencias.add(c);
                  }),
                ),
              ),
            ] else if (nueva) ...[
              etiqueta('A partir de una plantilla'),
              conMargen(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in plantillas) _CuadroPlantilla(p, t.plantillaId == p.id, () => aplicar(p)),
                    _CuadroOtro(() async {
                      final p = await crearPlantillaRapida(context);
                      if (p != null) aplicar(p);
                    }),
                  ],
                ),
              ),
            ],
          ],
          pie: t.esPlantilla ? null : SelectorColorTarea(t, () => setState(() {})),
        ),
        if (!t.esPlantilla)
          Bloque('Cliente y equipo', descripcion: 'Para quién es y quién la hace.', [
            dos(
              conMargen(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    etiqueta('Cliente'),
                    SelectorCliente(t.clienteId, (id) => setState(() => t.clienteId = id)),
                  ],
                ),
              ),
              conMargen(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: etiqueta('Trabajadores')),
                        if (aptos > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Enlace(
                              'El más adecuado',
                              onTap: () => setState(() {
                                final m = store.mejorPara(t);
                                if (m != null) t.trabajadorIds = [m.id];
                              }),
                            ),
                          ),
                      ],
                    ),
                    SelectorTrabajadores(t, () => setState(() {})),
                  ],
                ),
              ),
            ),
          ]),
        Bloque('Cuándo', descripcion: 'Fecha, hora y cada cuánto se repite.', [
          SelectorCuando(t, () => setState(() {}), error: errorHorario, key: _claveCuando),
        ]),
        Bloque('Cuánto', descripcion: 'Cuánto tiempo lleva hacerlo. Pulpo lo usa para cuadrar el día y las rutas.', [
          etiqueta('Duración'),
          conMargen(
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: t.duracionMin,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.timer_outlined, size: 18)),
              items: [
                for (final m in {...duraciones, t.duracionMin}.toList()..sort())
                  DropdownMenuItem(value: m, child: Text(duracion(m))),
              ],
              onChanged: (m) => setState(() => t.duracionMin = m!),
            ),
          ),
        ]),
        Bloque('Competencias', descripcion: 'Qué tiene que saber hacer. Pulpo solo se la asigna a quien puede.', [
          conMargen(chipsCompetencias(t.competencias, () => setState(() {}))),
        ]),
        Bloque('Equipo y notas', descripcion: 'La máquina, dónde está y lo que haya que saber.', [
          if (!t.esPlantilla)
            dos(
              CampoFecha(
                'Último mantenimiento',
                t.ultimo,
                (d) => setState(() {
                  t.ultimo = d;
                  if (t.periodicidad.repite) t.proximo = masDias(d, t.periodicidad.dias);
                }),
                hasta: hoy(), // lo que ya se hizo no puede ser futuro
              ),
              CampoFecha('Solicitado el', t.solicitud, (d) => setState(() => t.solicitud = d)),
            ),
          campo('Ubicación', ubicacion, hint: 'Sala de máquinas, planta 2…'),
          dos(campo('Marca', marca), campo('Modelo', modelo)),
          dos(
            campo('Número de serie', serie),
            CampoFecha('Fecha de instalación', t.instalacion, (d) => setState(() => t.instalacion = d)),
          ),
          campo('Notas / observaciones', notas, lineas: 3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            value: t.activa,
            onChanged: (v) => setState(() => t.activa = v),
          ),
        ]),
      ],
    );
  }
}

/// Cuadrícula de tipos de mantenimiento: icono de su color y nombre; el elegido, relleno.
class SelectorTipo extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;
  const SelectorTipo(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const cols = 5;
      final w = (box.maxWidth - (cols - 1) * 8) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final x in tipos)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(x.nombre),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: w,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: x.nombre == valor ? x.color : P.columna,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(x.icono, size: 20, color: x.nombre == valor ? Colors.white : x.color),
                    const SizedBox(height: 5),
                    Text(
                      x.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: x.nombre == valor ? Colors.white : P.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Cuadradito de plantilla: barrita del color de su tipo, nombre y periodicidad.
class _CuadroPlantilla extends StatelessWidget {
  final Tarea p;
  final bool elegida;
  final VoidCallback onTap;
  const _CuadroPlantilla(this.p, this.elegida, this.onTap);

  @override
  Widget build(BuildContext context) {
    final color = tipoDe(p.tipo).color;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 128,
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: elegida ? color.withValues(alpha: .1) : P.superficie,
          borderRadius: BorderRadius.circular(P.radioControl + 2),
          border: Border.all(color: elegida ? color : P.borde, width: elegida ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tipoDe(p.tipo).icono, size: 20, color: color),
            const Spacer(),
            Text(
              p.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2),
            ),
            Text(p.periodicidad.etiqueta, style: TextStyle(fontSize: 11, color: P.textoSuave)),
          ],
        ),
      ),
    );
  }
}

/// Cuadradito "Otro": crea una plantilla nueva sin salir de la tarea.
class _CuadroOtro extends StatelessWidget {
  final VoidCallback onTap;
  const _CuadroOtro(this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      width: 128,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(P.radioControl + 2),
        border: Border.all(color: P.morado.withValues(alpha: .4)),
        color: P.moradoSuave.withValues(alpha: .5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, color: P.morado),
          const SizedBox(height: 4),
          Text(
            'Otro',
            style: TextStyle(fontWeight: FontWeight.w700, color: P.moradoOscuro),
          ),
        ],
      ),
    ),
  );
}

/// Ventanita para crear una plantilla rápida (nombre y tipo). Devuelve la plantilla creada.
Future<Tarea?> crearPlantillaRapida(BuildContext context) {
  final nombre = TextEditingController();
  var tipo = tipos.first.nombre;
  return showDialog<Tarea>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva plantilla',
                  style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                etiqueta('Nombre'),
                TextField(
                  controller: nombre,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Corte de césped, revisión de puertas…'),
                ),
                const SizedBox(height: 12),
                etiqueta('Tipo'),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  items: [
                    for (final x in tipos)
                      DropdownMenuItem(
                        value: x.nombre,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: x.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(x.nombre),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => set(() => tipo = v!),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        if (nombre.text.trim().isEmpty) return;
                        final p = Tarea(
                          id: store.nuevoId(),
                          nombre: nombre.text.trim(),
                          tipo: tipo,
                          competencias: [?tipoDe(tipo).competencia],
                        );
                        store.guardarTarea(p);
                        Navigator.pop(c, p);
                      },
                      child: const Text('Crear y usar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Caja que parece un campo con flechas ⇕ (indica que es un menú).
class _CajaMenu extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool abierto;
  const _CajaMenu({required this.child, required this.onTap, required this.abierto});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: abierto ? P.morado : P.borde, width: abierto ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
        ],
      ),
    ),
  );
}

/// Menú de clientes: todos los clientes y, abajo, "Crear nuevo cliente" (abre la misma ventana
/// que en Clientes; el cliente creado queda elegido).
class SelectorCliente extends StatelessWidget {
  final String? valor;
  final ValueChanged<String> onChanged;
  const SelectorCliente(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = store.cliente(valor);
    final clientes = [...store.clientes]..sort((a, b) => a.nombre.compareTo(b.nombre));
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        maximumSize: const WidgetStatePropertyAll(Size(460, 380)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      menuChildren: [
        if (clientes.isEmpty)
          const MenuItemButton(child: Text('Aún no tienes clientes'))
        else
          for (final x in clientes)
            MenuItemButton(
              leadingIcon: Avatar(x.iniciales, colorPaleta(x.color), size: 22, cuadrado: true),
              trailingIcon: x.id == valor ? Icon(Icons.check_rounded, size: 18, color: P.morado) : null,
              onPressed: () => onChanged(x.id),
              child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 260), child: Text(x.nombre)),
            ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: Icon(Icons.add_rounded, color: P.morado),
          onPressed: () async {
            final antes = {for (final x in store.clientes) x.id};
            await abrirClienteForm(context);
            final nuevo = store.clientes.where((x) => !antes.contains(x.id)).firstOrNull;
            if (nuevo != null) onChanged(nuevo.id);
          },
          child: Text(
            'Crear nuevo cliente',
            style: TextStyle(color: P.morado, fontWeight: FontWeight.w700),
          ),
        ),
      ],
      builder: (context, menu, _) => _CajaMenu(
        abierto: menu.isOpen,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: c == null
            ? Text('Elegir cliente', style: TextStyle(color: P.textoSuave))
            : Row(
                children: [
                  Avatar(c.iniciales, colorPaleta(c.color), size: 24, cuadrado: true),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      c.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Menú de trabajadores: se marcan uno o varios (no se cierra al marcar). Los que no son aptos
/// salen apagados con lo que les falta. Los equipos llegarán con la fase de grupos.
class SelectorTrabajadores extends StatelessWidget {
  final Tarea t;
  final VoidCallback onCambio;
  const SelectorTrabajadores(this.t, this.onCambio, {super.key});

  @override
  Widget build(BuildContext context) {
    final ws = store.trabajadores.where((w) => w.activo).toList()
      ..sort((a, b) => (store.esApto(a, t) ? 0 : 1) - (store.esApto(b, t) ? 0 : 1));
    final elegidos = t.trabajadorIds.map(store.trabajador).whereType<Trabajador>().toList();
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        maximumSize: const WidgetStatePropertyAll(Size(460, 420)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      menuChildren: [
        if (ws.isEmpty) const MenuItemButton(child: Text('Aún no tienes trabajadores')),
        for (final w in ws)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              t.trabajadorIds.contains(w.id) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: t.trabajadorIds.contains(w.id) ? P.morado : P.textoSuave,
            ),
            trailingIcon: store.esApto(w, t)
                ? const Pill('Apto', P.verde, punto: true)
                : Pill('Le falta: ${store.faltan(w, t).join(', ')}', P.gris),
            onPressed: () {
              t.trabajadorIds.contains(w.id) ? t.trabajadorIds.remove(w.id) : t.trabajadorIds.add(w.id);
              onCambio();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Row(
                children: [
                  Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22),
                  const SizedBox(width: 8),
                  Opacity(opacity: store.esApto(w, t) ? 1 : .55, child: Text(w.nombreCompleto)),
                ],
              ),
            ),
          ),
        const Divider(height: 8),
        MenuItemButton(
          onPressed: null,
          child: Text('Equipos · próximamente', style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
        ),
      ],
      builder: (context, menu, _) => _CajaMenu(
        abierto: menu.isOpen,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: elegidos.isEmpty
            ? Text('Sin asignar', style: TextStyle(color: P.textoSuave))
            : Row(
                children: [
                  AvataresTrabajadores(t.trabajadorIds, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      elegidos.map((w) => w.nombre).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Cuándo, sencillo: el día (abre el calendario) con la repetición al lado, y debajo la hora
/// o, con "Franja horaria", dos horas: de tal a tal.
class SelectorCuando extends StatefulWidget {
  final Tarea t;
  final VoidCallback onCambio;
  final String? error;
  const SelectorCuando(this.t, this.onCambio, {super.key, this.error});

  @override
  State<SelectorCuando> createState() => _SelectorCuandoState();
}

class _SelectorCuandoState extends State<SelectorCuando> {
  late bool franja = widget.t.conFranja;
  Tarea get t => widget.t;

  void cambiar(void Function() f) {
    setState(f);
    widget.onCambio();
  }

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  /// Campo que abre un selector al pulsarlo (día u hora).
  Widget _campo(
    String label,
    String? valor,
    String vacio,
    IconData icono,
    VoidCallback onTap, {
    bool destacado = false,
    bool conError = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      etiqueta(label),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: destacado ? P.moradoSuave.withValues(alpha: .6) : P.superficie,
            borderRadius: BorderRadius.circular(10),
            // En rojo el campo que falta para poder guardar.
            border: conError
                ? Border.all(color: P.rojo, width: 1.5)
                : Border.all(color: destacado ? P.morado.withValues(alpha: .45) : P.borde),
          ),
          child: Row(
            children: [
              Icon(icono, size: 18, color: conError ? P.rojo : (destacado ? P.morado : P.textoSuave)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  valor ?? vacio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: valor == null ? FontWeight.w400 : FontWeight.w600,
                    color: valor == null ? P.textoSuave : (destacado ? P.moradoOscuro : P.texto),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<int?> _pedirHora(int? actual) async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (actual ?? 540) ~/ 60, minute: (actual ?? 540) % 60),
    );
    return h == null ? null : h.hour * 60 + h.minute;
  }

  /// Campo en rojo y, debajo, el aviso corto (la barra de abajo lleva la lista completa).
  bool get hayError => widget.error != null;

  @override
  Widget build(BuildContext context) {
    final d = t.proximo;
    final opciones = {
      Periodicidad.unica,
      Periodicidad.semanal,
      Periodicidad.mensual,
      Periodicidad.anual,
      t.periodicidad,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Día + repetición.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _campo(
                  t.esPlantilla ? 'Primer día' : 'Día',
                  d == null
                      ? null
                      : '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]} · ${relativo(d).toLowerCase()}',
                  'Elegir día',
                  Icons.calendar_month_rounded,
                  () async {
                    final x = await showDatePicker(
                      context: context,
                      initialDate: d ?? hoy(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (x != null) cambiar(() => t.proximo = x);
                  },
                  destacado: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    etiqueta('Se repite'),
                    DropdownButtonFormField<Periodicidad>(
                      isExpanded: true,
                      initialValue: t.periodicidad,
                      items: [
                        for (final p in Periodicidad.values.where(opciones.contains))
                          DropdownMenuItem(value: p, child: Text(p.etiqueta)),
                      ],
                      onChanged: (v) => cambiar(() => t.periodicidad = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Hora exacta, o franja (de tal a tal).
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!franja)
                Expanded(
                  child: _campo(
                    'Hora',
                    t.inicioMin == null ? null : hhmm(t.inicioMin!),
                    'Elegir hora',
                    Icons.schedule_rounded,
                    () async {
                      final m = await _pedirHora(t.inicioMin);
                      if (m != null) cambiar(() => t.inicioMin = m);
                    },
                    conError: hayError && t.inicioMin == null,
                  ),
                )
              else ...[
                Expanded(
                  child: _campo(
                    'Desde',
                    t.ventanaDesdeMin == null ? null : hhmm(t.ventanaDesdeMin!),
                    'Hora de inicio',
                    Icons.schedule_rounded,
                    () async {
                      final m = await _pedirHora(t.ventanaDesdeMin);
                      if (m != null) {
                        cambiar(() {
                          t.ventanaDesdeMin = m;
                          t.inicioMin = m;
                          if ((t.ventanaHastaMin ?? 0) <= m) t.ventanaHastaMin = m + 60;
                        });
                      }
                    },
                    conError: hayError && t.ventanaDesdeMin == null,
                  ),
                ),
                // De la hora de inicio a la de fin.
                SizedBox(
                  width: 36,
                  height: 46,
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: P.textoSuave),
                ),
                Expanded(
                  child: _campo(
                    'Hasta',
                    t.ventanaHastaMin == null ? null : hhmm(t.ventanaHastaMin!),
                    'Hora de fin',
                    Icons.schedule_rounded,
                    () async {
                      final m = await _pedirHora(t.ventanaHastaMin);
                      if (m != null) cambiar(() => t.ventanaHastaMin = m);
                    },
                    // Vacía o antes que la de inicio.
                    conError:
                        hayError &&
                        (t.ventanaHastaMin == null ||
                            (t.ventanaDesdeMin != null && t.ventanaHastaMin! <= t.ventanaDesdeMin!)),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: franja ? P.moradoSuave : null,
                    side: BorderSide(color: franja ? P.morado.withValues(alpha: .5) : P.borde),
                  ),
                  onPressed: () => cambiar(() {
                    franja = !franja;
                    if (franja) {
                      t.ventanaDesdeMin = t.inicioMin;
                      t.ventanaHastaMin = t.inicioMin == null ? null : t.inicioMin! + 4 * 60;
                    } else {
                      t.ventanaDesdeMin = null;
                      t.ventanaHastaMin = null;
                    }
                  }),
                  child: Text(franja ? 'Hora exacta' : 'Franja horaria'),
                ),
              ),
            ],
          ),
          // Línea del aviso siempre reservada: al aparecer «Pon una hora» no se mueve nada.
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: SizedBox(
              height: 16,
              child: hayError ? Text(widget.error!, style: const TextStyle(color: P.rojo, fontSize: 12)) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Color del bloque en el calendario: circulitos con colores habituales y "+" para cualquier otro.
/// El primero es "Automático": el color de su tipo.
class SelectorColorTarea extends StatelessWidget {
  final Tarea t;
  final VoidCallback onCambio;
  const SelectorColorTarea(this.t, this.onCambio, {super.key});

  static const colores = [
    0xFF7C3AED,
    0xFF2563EB,
    0xFF0EA5E9,
    0xFF0D9488,
    0xFF16A34A,
    0xFF84CC16,
    0xFFCA8A04,
    0xFFEA580C,
    0xFFDC2626,
    0xFFDB2777,
    0xFF64748B,
  ];

  static const _lado = 20.0;

  Widget _circulo(Color c, bool sel, VoidCallback onTap, {Widget? dentro, String? tip}) => Tooltip(
    message: tip ?? '',
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _lado,
        height: _lado,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? P.superficie : Colors.transparent, width: 2),
          boxShadow: sel ? [BoxShadow(color: c, spreadRadius: 2)] : null,
        ),
        child: dentro ?? (sel ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null),
      ),
    ),
  );

  Future<void> _otro(BuildContext context) async {
    // Paleta amplia: 12 tonos × 4 luminosidades.
    final todos = [
      for (final l in [.35, .45, .55, .7])
        for (var h = 0; h < 360; h += 30) HSLColor.fromAHSL(1, h.toDouble(), .7, l).toColor(),
    ];
    final elegido = await showDialog<Color>(
      context: context,
      builder: (c) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Otro color',
                style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 12 * 34,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final x in todos) _circulo(x, false, () => Navigator.pop(c, x))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null) {
      t.color = elegido.toARGB32();
      onCambio();
    }
  }

  @override
  Widget build(BuildContext context) {
    final propio = t.color != null && !colores.contains(t.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _circulo(
              tipoDe(t.tipo).color,
              t.color == null,
              () {
                t.color = null;
                onCambio();
              },
              tip: 'Automático (color del tipo)',
              dentro: t.color == null
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : const Text(
                      'A',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
            ),
            for (final c in colores)
              _circulo(Color(c), t.color == c, () {
                t.color = c;
                onCambio();
              }),
            if (propio) _circulo(Color(t.color!), true, () {}),
            Tooltip(
              message: 'Otro color',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _otro(context),
                child: Container(
                  width: _lado,
                  height: _lado,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: P.borde, width: 1.5),
                  ),
                  child: Icon(Icons.add_rounded, size: 13, color: P.textoSuave),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Criticidad del trabajo en un menú pequeño arriba a la derecha del formulario: punto de color, la
/// elegida y flechas arriba/abajo. De menos a más: rutinaria, media, alta, crítica.
class _MenuCriticidad extends StatelessWidget {
  final Criticidad valor;
  final ValueChanged<Criticidad> onChanged;
  const _MenuCriticidad(this.valor, this.onChanged);

  Widget _punto(Criticidad c) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
  );

  @override
  Widget build(BuildContext context) => BotonMenu<Criticidad>(
    tooltip: '¿Cómo de importante es este trabajo?',
    seleccionado: valor,
    onSelected: onChanged,
    opciones: [
      for (final c in Criticidad.values.reversed)
        (c, Row(children: [_punto(c), const SizedBox(width: 10), Text(c.etiqueta)])),
    ],
    // Fondo bajo, que no llegue a la línea de debajo de la cabecera.
    child: SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _punto(valor),
          const SizedBox(width: 8),
          Text('Criticidad', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
          const SizedBox(width: 6),
          Text(valor.etiqueta, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_up_chevron_down, size: 14, color: P.textoSuave),
        ],
      ),
    ),
  );
}
