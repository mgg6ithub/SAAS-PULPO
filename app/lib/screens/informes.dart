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
import '../industrial/planes.dart' show raizActivo;

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

/// Orden completada sin parte (se marcó desde la oficina): lo que se sabe de ella, para poder sacar su PDF.
Informe parteSinRellenar(Tarea t) => Informe(
  trabajoId: t.id,
  trabajadorId: t.ejecutadoPor ?? t.trabajadorIds.firstOrNull,
  resultado: t.resultado ?? 0,
  notas: '',
  cuando: t.completadaEl ?? t.ultimo ?? hoy(),
);

/// «26 nov a las 15:42, Jon Etxebarria»: cuándo y quién completó la orden. Las antiguas, con lo que haya.
String textoCompletada(Tarea t) {
  final parte = informes.de(t.id)?.firstOrNull;
  final d = t.completadaEl ?? parte?.cuando;
  final quien =
      t.completadaPor ?? store.trabajador(parte?.trabajadorId ?? t.ejecutadoPor ?? '')?.nombreCompleto;
  final cuando = d == null ? fecha(t.ultimo) : '${fecha(d)} a las ${hhmm(d.hour * 60 + d.minute)}';
  return [cuando, ?quien].join(', ');
}

/// El informe entero: resultado, quién y cuándo, notas, fotos y descarga en PDF.
Future<void> verInforme(BuildContext context, Informe i, Tarea t) => showDialog(
  context: context,
  builder: (c) => Dialog(
    backgroundColor: P.superficie,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: industrial ? 820 : 620, maxHeight: MediaQuery.sizeOf(c).height * .9),
      child: _Informe(i, t),
    ),
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

  /// Etiqueta pequeña en mayúsculas, como en el PDF.
  Widget _etiqueta(String t) => Text(
    t.toUpperCase(),
    style: TextStyle(color: P.textoSuave, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8),
  );

  /// Dato con su nombre encima (tarjetas y franja de ejecución).
  Widget _dato(String nombre, String valor, {Widget? hijo}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre, style: TextStyle(color: P.textoSuave, fontSize: 12)),
        const SizedBox(height: 2),
        hijo ?? Text(valor.isEmpty ? '-' : valor, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );

  /// Tarjeta blanca de borde fino con su etiqueta.
  Widget _tarjeta(String titulo, List<Widget> hijos) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    decoration: BoxDecoration(border: Border.all(color: P.borde), borderRadius: BorderRadius.circular(P.radio)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_etiqueta(titulo), const SizedBox(height: 10), ...hijos],
    ),
  );

  /// Bloque con su etiqueta y el texto en una caja gris suave.
  Widget _seccion(String titulo, String texto) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiqueta(titulo),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: P.fondo, borderRadius: BorderRadius.circular(P.radio)),
          child: Text(texto, style: const TextStyle(fontSize: 14, height: 1.45)),
        ),
      ],
    ),
  );

  Widget _fotos(List<String> fotos) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var n = 0; n < fotos.length; n++)
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => verFotos(context, fotos, n),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(P.radio),
              child: FotoGuardada(fotos[n], width: 180, height: 128),
            ),
          ),
        ),
    ],
  );

  Future<void> _pdf() async {
    setState(() => descargando = true);
    try {
      await descargarInformePdf(context, widget.i, widget.t);
    } catch (e) {
      debugPrint('Pultec: no se pudo crear el PDF: $e');
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
    final i = widget.i, t = widget.t;
    final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
    final cliente = store.cliente(t.clienteId);
    final raiz = industrial ? raizActivo(t.activoId) : null;
    final comp = industrial ? store.activo(t.activoId) : null;
    final plan = t.planId == null ? null : store.planes.where((p) => p.id == t.planId).firstOrNull;
    final x = industrial ? store.incidenciaDeOt(t.id) : null;
    final tecnicos = [for (final id in t.trabajadorIds) ?store.trabajador(id)?.nombreCompleto];
    final limpio = t.id.replaceAll('-', '').toUpperCase();
    final numero = 'OT-${limpio.substring(0, limpio.length < 8 ? limpio.length : 8)}';
    final cuando = '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}';
    final resultado = i.resultado.clamp(0, 2);
    final fabricante = [?raiz?.fabricante, ?raiz?.modelo].where((s) => s.isNotEmpty).join(' ');
    final estrecho = MediaQuery.sizeOf(context).width < 640;

    final tarjetaOt = _tarjeta(industrial ? 'Orden de trabajo' : m('Trabajo'), [
      _dato('Número', numero),
      if (industrial && t.tipoMantenimiento != null)
        _dato('Criticidad', '', hijo: Pill(t.tipoMantenimiento!.etiqueta, t.tipoMantenimiento!.color, punto: true)),
      if (industrial) _dato('Origen', x != null ? 'Incidencia' : plan != null ? 'Mantenimiento' : 'Manual'),
      if (plan != null) _dato('Mantenimiento', [plan.nombre, if (plan.cada.isNotEmpty) plan.cada].join(', ')),
      if (t.proximo != null || t.ultimo != null) _dato('Fecha prevista', fecha(t.proximo ?? t.ultimo)),
      if (industrial && tecnicos.isNotEmpty) _dato('Asignada a', tecnicos.join(', ')),
    ]);
    final tarjetaDonde = industrial
        ? _tarjeta('Activo', [
            _dato('Activo', raiz?.titulo ?? '-'),
            if (comp != null && comp.id != raiz?.id) _dato('Componente', comp.titulo),
            if (fabricante.isNotEmpty) _dato('Fabricante y modelo', fabricante),
            if (raiz != null && raiz.numeroSerie.isNotEmpty) _dato('Número de serie', raiz.numeroSerie),
            if (t.ubicacion.isNotEmpty) _dato('Ubicación', t.ubicacion),
          ])
        : _tarjeta(m('Cliente'), [
            _dato(m('Cliente'), cliente?.nombre ?? '-'),
            _dato('Dirección', t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '-')),
          ]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera fija: qué es, número y fecha; la X para cerrar.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      industrial ? 'PARTE DE ORDEN DE TRABAJO' : 'PARTE DE TRABAJO',
                      style: TextStyle(color: P.morado, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text('$numero  ·  $cuando', style: TextStyle(color: P.textoSuave, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: P.textoSuave),
              ),
            ],
          ),
        ),
        Container(height: 2, color: P.morado),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título y descripción, con el resultado a la derecha.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.nombre,
                            style: TextStyle(fontFamily: P.titulos, fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          if (t.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(t.descripcion, style: TextStyle(color: P.textoSuave, fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Pill(
                      resultado == 0 && industrial ? 'Completada' : resultadosInforme[resultado],
                      coloresResultado[resultado],
                      icono: iconosResultado[resultado],
                    ),
                  ],
                ),
                if (x != null) ...[
                  _seccion('Incidencia original', x.descripcion),
                  if (x.fotos.isNotEmpty) ...[const SizedBox(height: 8), _fotos(x.fotos)],
                ],
                const SizedBox(height: 18),
                if (estrecho) ...[tarjetaOt, const SizedBox(height: 12), tarjetaDonde]
                else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Expanded(child: tarjetaOt), const SizedBox(width: 12), Expanded(child: tarjetaDonde)],
                    ),
                  ),
                const SizedBox(height: 12),
                // Ejecución en una franja suave del color de la marca.
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  decoration: BoxDecoration(color: P.moradoSuave, borderRadius: BorderRadius.circular(P.radio)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _dato('Realizado el', cuando)),
                      Expanded(child: _dato('Técnico', w?.nombreCompleto ?? '-')),
                      Expanded(child: _dato('Tiempo', i.minutos == null ? '-' : duracionTexto(i.minutos!))),
                    ],
                  ),
                ),
                if (industrial) ...[
                  const SizedBox(height: 18),
                  _etiqueta('Historial'),
                  const SizedBox(height: 10),
                  for (final (c, texto) in cronologiaOt(t, i))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: P.morado, shape: BoxShape.circle),
                          ),
                          if (c.isNotEmpty)
                            SizedBox(width: 128, child: Text(c, style: TextStyle(color: P.textoSuave, fontSize: 13))),
                          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13.5))),
                        ],
                      ),
                    ),
                ],
                _seccion('Trabajo realizado', i.notas.isEmpty ? 'Sin observaciones.' : i.notas),
                if (i.valor != null)
                  _seccion(plan != null && plan.conMedicion ? plan.medicionNombre : 'Medición', medidaTexto(i, t)),
                if (i.material.isNotEmpty) _seccion('Material y repuestos', i.material),
                if (i.fotos.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _etiqueta('Fotos'),
                  const SizedBox(height: 8),
                  _fotos(i.fotos),
                ],
                if (i.firma != null) ...[
                  const SizedBox(height: 22),
                  _etiqueta(industrial ? 'Firma del técnico' : m('Conforme, el cliente')),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FotoGuardada(i.firma!, width: 220, height: 80, fit: BoxFit.contain),
                          Container(height: 1, color: P.texto),
                          const SizedBox(height: 4),
                          Text(
                            industrial ? (w?.nombreCompleto ?? i.firmante) : i.firmante,
                            style: TextStyle(color: P.textoSuave, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: P.borde),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              const SizedBox(width: 8),
              BotonAccion(
                descargando ? 'Creando PDF…' : 'Descargar PDF',
                icono: Icons.download_rounded,
                color: P.morado,
                onPressed: () => descargando ? null : _pdf(),
              ),
            ],
          ),
        ),
      ],
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

/// Icono de descarga en PDF para las filas de las tablas (una pulsación; mientras se prepara, un círculo).
class BotonPdf extends StatefulWidget {
  final Future<void> Function() descargar;
  final String tooltip;

  /// 32 × 32, como el botón de selección de las tablas (para ir justo debajo de él).
  final bool compacto;
  const BotonPdf(this.descargar, {super.key, this.tooltip = 'Descargar PDF', this.compacto = false});

  /// El parte más reciente de la OT; sin parte, lo avisa.
  factory BotonPdf.orden(Tarea t, BuildContext context, {bool compacto = false}) => BotonPdf(compacto: compacto, () async {
    final messenger = ScaffoldMessenger.of(context);
    final ultimo = (await informes.cargar(t.id)).firstOrNull ?? (t.estado == EstadoTrabajo.realizado ? parteSinRellenar(t) : null);
    if (ultimo == null) {
      messenger.showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('Esta orden aún no tiene parte')),
      );
      return;
    }
    if (context.mounted) await descargarInformePdf(context, ultimo, t);
  }, tooltip: 'Descargar el parte en PDF');

  @override
  State<BotonPdf> createState() => _BotonPdfState();
}

class _BotonPdfState extends State<BotonPdf> {
  bool preparando = false;

  Future<void> _pulsar() async {
    setState(() => preparando = true);
    try {
      await widget.descargar();
    } catch (e) {
      debugPrint('Pultec: no se pudo crear el PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
        );
      }
    }
    if (mounted) setState(() => preparando = false);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.tooltip,
    onPressed: preparando ? null : _pulsar,
    padding: widget.compacto ? EdgeInsets.zero : null,
    constraints: widget.compacto ? const BoxConstraints.tightFor(width: 32, height: 32) : null,
    icon: preparando
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(Icons.download_rounded, size: 18, color: P.textoSuave),
  );
}
