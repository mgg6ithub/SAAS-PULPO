import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../informes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../marca.dart';

/// Punto del color del resultado: sustituye al icono en las filas de informes.
Widget puntoResultado(int resultado) => Container(
  width: 10,
  height: 10,
  decoration: BoxDecoration(color: coloresResultado[resultado], shape: BoxShape.circle),
);

/// Fila de un informe; al pulsarla se abre entero.
class FilaInforme extends StatelessWidget {
  final Informe i;
  final Tarea t;
  const FilaInforme(this.i, this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
    return FilaLista(
      lider: puntoResultado(i.resultado),
      titulo: resultadosInforme[i.resultado],
      subtitulo: [
        if (informes.sinSubir(i)) 'Sin subir',
        if (w != null) w.nombreCompleto,
        if (i.fotos.isNotEmpty) '${i.fotos.length} ${i.fotos.length == 1 ? 'foto' : 'fotos'}',
        i.notas,
      ].join(' · '),
      derecha: Text(
        '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}',
        style: TextStyle(fontSize: 12.5, color: P.textoSuave),
      ),
      onTap: () => verInforme(context, i, t),
    );
  }
}

/// Filas de los informes de un trabajo (nada si no tiene), para el histórico del administrador.
class InformesDelTrabajo extends StatelessWidget {
  final Tarea t;
  const InformesDelTrabajo(this.t, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: informes,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final i in informes.de(t.id) ?? const <Informe>[]) FilaInforme(i, t)],
    ),
  );
}

/// El informe entero: resultado, quién y cuándo, notas, fotos y descarga en PDF.
Future<void> verInforme(BuildContext context, Informe i, Tarea t) => showDialog(
  context: context,
  builder: (c) => Dialog(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _Informe(i, t)),
  ),
);

class _Informe extends StatefulWidget {
  final Informe i;
  final Tarea t;
  const _Informe(this.i, this.t);

  @override
  State<_Informe> createState() => _InformeState();
}

class _InformeState extends State<_Informe> {
  bool descargando = false;

  Widget _dato(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(etiqueta, style: TextStyle(color: P.textoSuave, fontSize: 13)),
        ),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 13.5))),
      ],
    ),
  );

  Future<void> _pdf() async {
    setState(() => descargando = true);
    try {
      await descargarInformePdf(widget.i, widget.t);
    } catch (e) {
      debugPrint('Pulpo: no se pudo crear el PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
        );
      }
    }
    if (mounted) setState(() => descargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.i;
    final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORME',
            style: TextStyle(color: P.morado, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            widget.t.nombre,
            style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(resultadosInforme[i.resultado], coloresResultado[i.resultado], punto: true),
              Text(
                [
                  '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}',
                  if (w != null) w.nombreCompleto,
                ].join(' · '),
                style: TextStyle(color: P.textoSuave, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(i.notas, style: const TextStyle(fontSize: 14, height: 1.45)),
          if (i.material.isNotEmpty || i.minutos != null) ...[
            const SizedBox(height: 12),
            if (i.material.isNotEmpty) _dato('Material', i.material),
            if (i.minutos != null) _dato('Tiempo', duracionTexto(i.minutos!)),
          ],
          if (i.fotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in i.fotos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(P.radio),
                    child: FotoGuardada(f, width: 160, height: 120),
                  ),
              ],
            ),
          ],
          if (i.firma != null) ...[
            const SizedBox(height: 16),
            Text(m('Conforme, el cliente'), style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
            const SizedBox(height: 4),
            FotoGuardada(i.firma!, width: 220, height: 88, fit: BoxFit.contain),
            if (i.firmante.isNotEmpty) Text(i.firmante, style: const TextStyle(fontSize: 13.5)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              const SizedBox(width: 8),
              BotonAccion(
                descargando ? 'Creando PDF…' : 'Descargar PDF',
                icono: Icons.download_rounded,
                onPressed: () => descargando ? null : _pdf(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Trazos de una firma hecha con el dedo o el ratón.
class Firma extends ChangeNotifier {
  final trazos = <List<Offset>>[];
  Size tamano = Size.zero;
  bool get vacia => trazos.isEmpty;

  Offset _dentro(Offset p) => Offset(p.dx.clamp(0, tamano.width), p.dy.clamp(0, tamano.height));

  void empezar(Offset p) {
    trazos.add([_dentro(p)]);
    notifyListeners();
  }

  void seguir(Offset p) {
    if (trazos.isEmpty) return;
    trazos.last.add(_dentro(p));
    notifyListeners();
  }

  void borrar() {
    trazos.clear();
    notifyListeners();
  }

  void pintar(Canvas c, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final t in trazos) {
      final camino = Path()..moveTo(t.first.dx, t.first.dy);
      for (final q in t.skip(1)) {
        camino.lineTo(q.dx, q.dy);
      }
      if (t.length == 1) camino.lineTo(t.first.dx + .1, t.first.dy);
      c.drawPath(camino, p);
    }
  }

  /// La firma en PNG con fondo transparente (null = sin firmar).
  Future<Uint8List?> png() async {
    if (vacia) return null;
    final r = ui.PictureRecorder();
    pintar(Canvas(r), const Color(0xFF111111));
    final imagen = await r.endRecording().toImage(tamano.width.ceil(), tamano.height.ceil());
    final b = await imagen.toByteData(format: ui.ImageByteFormat.png);
    return b!.buffer.asUint8List();
  }
}

/// Recuadro donde el cliente firma con el dedo. Se queda con el gesto para que la ventana no se desplace.
class PanelFirma extends StatelessWidget {
  final Firma firma;
  const PanelFirma(this.firma, {super.key});

  static const alto = 160.0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        height: alto,
        decoration: BoxDecoration(
          color: P.superficie,
          borderRadius: BorderRadius.circular(P.radio),
          border: Border.all(color: P.borde),
        ),
        child: RawGestureDetector(
          gestures: {
            EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
          },
          child: Listener(
            onPointerDown: (e) => firma.empezar(e.localPosition),
            onPointerMove: (e) => firma.seguir(e.localPosition),
            child: LayoutBuilder(
              builder: (context, box) {
                firma.tamano = Size(box.maxWidth, box.maxHeight);
                return ListenableBuilder(
                  listenable: firma,
                  builder: (context, _) => Stack(
                    children: [
                      if (firma.vacia)
                        Center(
                          child: Text('Firma aquí', style: TextStyle(color: P.textoSuave, fontSize: 15)),
                        ),
                      Positioned.fill(child: CustomPaint(painter: _PintorFirma(firma))),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: firma.borrar, child: const Text('Borrar firma')),
      ),
    ],
  );
}

class _PintorFirma extends CustomPainter {
  final Firma firma;
  _PintorFirma(this.firma) : super(repaint: firma);

  @override
  void paint(Canvas canvas, Size size) => firma.pintar(canvas, P.texto);

  @override
  bool shouldRepaint(_PintorFirma old) => false;
}
