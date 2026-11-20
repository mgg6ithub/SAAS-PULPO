import 'dart:math';

import 'package:flutter/material.dart';

import '../forms.dart' show SelectorActivo;
import '../informes.dart';
import '../screens/informes.dart' show BotonPdf;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'activos.dart' show contadorTexto;
import 'gravedad.dart';
import 'historicos.dart';
import 'incidencia.dart';
import 'mantenimientos.dart' show abrirIncidenciaForm, raizDe;
import 'plan.dart';
import 'planes.dart' show horasRestantesPlan, proximoPlan;

/// Periodos de las estadísticas (días hacia atrás).
const _periodos = [('30 días', 30), ('3 meses', 91), ('Año', 365)];

/// «1,5»: sin decimales si es entero; con coma.
String numTexto(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1).replaceAll('.', ',');

/// Pultec: sección Estadísticas. Cuatro apartados (los del documento del 18/11/2026): estado de un activo (con su
/// PDF), verificaciones con dato, técnicos e incidencias por equipo. Todo con el mismo periodo.
class EstadisticasPultec extends StatefulWidget {
  const EstadisticasPultec({super.key});

  @override
  State<EstadisticasPultec> createState() => _EstadisticasPultecState();
}

class _EstadisticasPultecState extends State<EstadisticasPultec> {
  int apartado = 0, periodo = 1;
  String? activoId;

  @override
  Widget build(BuildContext context) {
    final dias = _periodos[periodo].$2;
    final desde = masDias(hoy(), -dias);
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraVista(
            izquierda: [
              const TituloVista('Estadísticas'),
              Pestanas(
                opciones: const ['Activo', 'Verificaciones', 'Técnicos', 'Incidencias'],
                seleccion: apartado,
                onChanged: (i) => setState(() => apartado = i),
              ),
            ],
            derecha: [
              Pestanas(
                opciones: [for (final (n, _) in _periodos) n],
                seleccion: periodo,
                compactas: true,
                onChanged: (i) => setState(() => periodo = i),
              ),
            ],
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: switch (apartado) {
              0 => _PorActivo(
                activoId: activoId ?? store.hijosDe(null).firstOrNull?.id,
                desde: desde,
                dias: dias,
                onActivo: (id) => setState(() => activoId = raizDe(id)?.id ?? id),
              ),
              1 => _Verificaciones(desde: desde),
              2 => _PorTecnico(desde: desde),
              _ => _PorEquipo(desde: desde, dias: dias),
            },
          ),
        ],
      ),
    );
  }
}

/// Cifra de las estadísticas: etiqueta pequeña, valor grande y, si hace falta, el punto de su color.
class _Dato extends StatelessWidget {
  final String etiqueta, valor;
  final Color? punto;
  const _Dato(this.etiqueta, this.valor, {this.punto});

  @override
  Widget build(BuildContext context) => Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (punto != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: punto, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: P.textoSuave)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: P.titulos, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.5)),
      ],
    ),
  );
}

/// Barrita horizontal proporcional (en vez de un número suelto): el color dice qué se cuenta.
Widget _barra(int n, int maximo, Color color) => Row(
  children: [
    SizedBox(width: 28, child: Text('$n', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
    Expanded(
      child: LayoutBuilder(
        builder: (_, box) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 8,
            width: maximo == 0 ? 0 : max(n == 0 ? 0.0 : 4.0, box.maxWidth * n / maximo),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    ),
  ],
);

// ── 1. Por activo ───────────────────────────────────────────────────────────

class _PorActivo extends StatelessWidget {
  final String? activoId;
  final DateTime desde;
  final int dias;
  final ValueChanged<String?> onActivo;
  const _PorActivo({required this.activoId, required this.desde, required this.dias, required this.onActivo});

  @override
  Widget build(BuildContext context) {
    final a = store.activo(activoId);
    if (a == null) {
      return const Vacio(icono: Icons.insights_outlined, titulo: 'Sin activos', texto: 'Crea un activo para ver su estado.');
    }
    final r = resumenActivo(a, desde);
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: SelectorActivo(a.id, onActivo, filtro: true),
            ),
            const Spacer(),
            BotonPdf(
              () => descargarResumenActivo(a, desde, dias),
              tooltip: 'Resumen del activo en PDF',
            ),
          ],
        ),
        const SizedBox(height: huecoVista),
        SegunTamano(
          clave: (box) => box.maxWidth > 900 ? 6 : box.maxWidth > 560 ? 3 : 2,
          builder: (context, box) => Rejilla(
            columnas: box.maxWidth > 900 ? 6 : box.maxWidth > 560 ? 3 : 2,
            hueco: huecoVista,
            children: [
              _Dato('Hechas en el periodo', '${r.hechas}', punto: P.verde),
              _Dato('Pendientes', '${r.pendientes}'),
              _Dato('Atrasadas', '${r.atrasadas}', punto: r.atrasadas > 0 ? P.rojo : null),
              _Dato('Incidencias', '${r.incidencias.length}', punto: r.incidencias.isEmpty ? null : P.ambar),
              _Dato('Con problema en el parte', '${r.conProblema}', punto: r.conProblema > 0 ? P.ambar : null),
              _Dato('Contador', contadorTexto(a).split(',').first),
            ],
          ),
        ),
        const SizedBox(height: huecoVista),
        SeccionTarjeta(
          titulo: 'Mantenimientos',
          subtitulo: '${r.planes.length}',
          sinFilas: true,
          children: [
            if (r.planes.isEmpty)
              Padding(padding: const EdgeInsets.all(18), child: Text('Sin mantenimientos', style: TextStyle(color: P.textoSuave)))
            else
              // Pocas filas: tabla sencilla dentro de la lista (la `Tabla` necesita alto propio).
              _FilaPlan.cabecera(),
            for (final (p, hechos) in r.planes) _FilaPlan(p, hechos),
          ],
        ),
        const SizedBox(height: huecoVista),
        SeccionTarjeta(
          titulo: 'Incidencias del periodo',
          subtitulo: r.incidencias.isEmpty ? null : '${r.incidencias.length}',
          children: [
            if (r.incidencias.isEmpty)
              Padding(padding: const EdgeInsets.all(18), child: Text('Ninguna en este periodo', style: TextStyle(color: P.textoSuave)))
            else
              for (final x in r.incidencias.take(10))
                FilaLista(
                  lider: Container(width: 10, height: 10, decoration: BoxDecoration(color: x.gravedad.color, shape: BoxShape.circle)),
                  titulo: x.descripcion,
                  subtitulo: fecha(x.creada),
                  derecha: Pill(store.estadoIncidencia(x).etiqueta, store.estadoIncidencia(x).color, punto: true),
                  onTap: () => abrirIncidenciaForm(context, original: x),
                ),
          ],
        ),
      ],
    );
  }
}

/// Fila de la tabla de mantenimientos del activo: nombre, cada cuánto, último, próximo y hechos en el periodo.
class _FilaPlan extends StatelessWidget {
  final PlanMantenimiento? p;
  final int hechos;
  const _FilaPlan(this.p, this.hechos);
  const _FilaPlan.cabecera() : p = null, hechos = 0;

  @override
  Widget build(BuildContext context) {
    final p = this.p;
    final cab = p == null;
    final proximo = cab ? null : proximoPlan(p);
    final horas = cab ? null : horasRestantesPlan(p);
    Widget t(String x, {bool negrita = false}) => Text(x, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: cab ? 12.5 : 13.5, fontWeight: negrita ? FontWeight.w600 : FontWeight.w400,
        color: cab || !negrita ? P.textoSuave : P.texto));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: P.borde))),
      child: Row(
        children: [
          Expanded(flex: 3, child: t(cab ? 'Mantenimiento' : p.nombre, negrita: !cab)),
          Expanded(flex: 2, child: t(cab ? 'Cada' : p.cada.replaceAll(' · ', ', '))),
          SizedBox(width: 110, child: t(cab ? 'Último' : p.ultimo == null ? '—' : fecha(p.ultimo!))),
          SizedBox(
            width: 130,
            child: t(cab
                ? 'Próximo'
                : proximo == null
                ? (horas == null ? '—' : 'Faltan ${numTexto(horas)} h')
                : relativo(proximo)),
          ),
          SizedBox(width: 70, child: t(cab ? 'Hechos' : '$hechos')),
        ],
      ),
    );
  }
}

/// Lo que se cuenta de un activo (y sus componentes) en el periodo; también lo usa su PDF.
typedef ResumenActivo = ({
  int hechas,
  int pendientes,
  int atrasadas,
  int conProblema,
  List<Incidencia> incidencias,
  List<(PlanMantenimiento, int)> planes,
  List<Realizada> realizadas,
});

ResumenActivo resumenActivo(Activo a, DateTime desde) {
  final rama = store.ramaDe(a.id);
  final ots = [...store.tareas, ...store.subtareas].where((t) => rama.contains(t.activoId)).toList();
  final realizadas = otsRealizadas().where((r) => rama.contains(r.$2.activoId) && !r.$1.isBefore(desde)).toList();
  final planes = store.planes.where((p) => rama.contains(p.activoId)).toList()..sort((x, y) => x.nombre.compareTo(y.nombre));
  return (
    hechas: realizadas.length,
    pendientes: ots.where(otPendiente).length,
    atrasadas: ots.where((t) => otPendiente(t) && t.proximo != null && diasHasta(t.proximo!) < 0).length,
    conProblema: realizadas.where((r) => (r.$2.resultado ?? 0) > 0).length,
    incidencias: store.incidencias.where((x) => rama.contains(x.activoId) && !x.creada.isBefore(desde)).toList()
      ..sort((x, y) => y.creada.compareTo(x.creada)),
    planes: [for (final p in planes) (p, realizadas.where((r) => r.$2.planId == p.id).length)],
    realizadas: realizadas,
  );
}

// ── 2. Verificaciones con dato ──────────────────────────────────────────────

class _Verificaciones extends StatefulWidget {
  final DateTime desde;
  const _Verificaciones({required this.desde});

  @override
  State<_Verificaciones> createState() => _VerificacionesState();
}

class _VerificacionesState extends State<_Verificaciones> {
  String? planId;
  final _datos = <String, Future<List<(DateTime, double)>>>{};

  Future<List<(DateTime, double)>> _de(String id) => _datos[id] ??= informes.mediciones(id);

  @override
  Widget build(BuildContext context) {
    final planes = store.planes.where((p) => p.conMedicion).toList()
      ..sort((a, b) => '${raizDe(a.activoId)?.titulo} ${a.nombre}'.compareTo('${raizDe(b.activoId)?.titulo} ${b.nombre}'));
    if (planes.isEmpty) {
      return const Vacio(
        icono: Icons.show_chart_rounded,
        titulo: 'Sin verificaciones con dato',
        texto: 'En un mantenimiento, rellena «Medición» (qué se mide, unidad y límites) y el técnico apuntará el valor en su parte.',
      );
    }
    final p = planes.firstWhere((x) => x.id == planId, orElse: () => planes.first);
    final lista = SeccionTarjeta(
      titulo: 'Mediciones',
      subtitulo: '${planes.length}',
      children: [
        for (final x in planes)
          Container(
            color: x.id == p.id ? P.moradoSuave : null,
            child: FilaLista(
              lider: Icon(Icons.show_chart_rounded, size: 18, color: x.id == p.id ? P.morado : P.textoSuave),
              titulo: x.medicionNombre,
              subtitulo: '${x.nombre}, ${raizDe(x.activoId)?.titulo ?? ''}',
              onTap: () => setState(() => planId = x.id),
            ),
          ),
      ],
    );
    final detalle = FutureBuilder(
      future: _de(p.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return snap.hasError
              ? Padding(padding: const EdgeInsets.all(18), child: Text('No se pudieron leer las mediciones', style: TextStyle(color: P.textoSuave)))
              : const Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator());
        }
        final datos = snap.data!.where((d) => !d.$1.isBefore(widget.desde)).toList();
        final fuera = datos.where((d) => (p.medicionMin != null && d.$2 < p.medicionMin!) || (p.medicionMax != null && d.$2 > p.medicionMax!)).length;
        final u = p.medicionUnidad.isEmpty ? '' : ' ${p.medicionUnidad}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(
              columnas: 4,
              hueco: huecoVista,
              children: [
                _Dato('Medidas', '${datos.length}'),
                _Dato('Última', datos.isEmpty ? '—' : '${numTexto(datos.last.$2)}$u'),
                _Dato('Media', datos.isEmpty ? '—' : '${numTexto(datos.map((d) => d.$2).reduce((a, b) => a + b) / datos.length)}$u'),
                _Dato('Fuera de límites', '$fuera', punto: fuera > 0 ? P.rojo : null),
              ],
            ),
            const SizedBox(height: huecoVista),
            SeccionTarjeta(
              titulo: '${p.medicionNombre}${u.isEmpty ? '' : ' ($u)'.replaceAll('( ', '(')}',
              subtitulo: [
                if (p.medicionMin != null || p.medicionMax != null)
                  'Admitido de ${p.medicionMin == null ? '…' : numTexto(p.medicionMin!)} a ${p.medicionMax == null ? '…' : numTexto(p.medicionMax!)}',
              ].join(),
              sinFilas: true,
              children: [
                if (datos.isEmpty)
                  Padding(padding: const EdgeInsets.all(18), child: Text('Sin medidas en este periodo', style: TextStyle(color: P.textoSuave)))
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 18, 12),
                    child: SizedBox(height: 260, child: GraficaMedidas(datos, minimo: p.medicionMin, maximo: p.medicionMax, unidad: u)),
                  ),
              ],
            ),
            const SizedBox(height: huecoVista),
            SeccionTarjeta(
              titulo: 'Historial',
              children: [
                for (final (d, v) in datos.reversed.take(30))
                  FilaLista(
                    lider: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (p.medicionMin != null && v < p.medicionMin!) || (p.medicionMax != null && v > p.medicionMax!) ? P.rojo : P.morado,
                      ),
                    ),
                    titulo: '${numTexto(v)}$u',
                    subtitulo: '${fecha(d)} ${hhmm(d.hour * 60 + d.minute)}',
                  ),
              ],
            ),
          ],
        );
      },
    );
    return SegunTamano(
      clave: (box) => box.maxWidth > 900,
      builder: (context, box) => box.maxWidth > 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 320, child: SingleChildScrollView(child: lista)),
                const SizedBox(width: huecoVista),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 40), child: detalle)),
              ],
            )
          : ListView(padding: const EdgeInsets.only(bottom: 40), children: [lista, const SizedBox(height: huecoVista), detalle]),
    );
  }
}

/// Línea de las medidas en el tiempo (una sola serie, en morado), con los límites como rayas discontinuas
/// grises y los puntos fuera de límites en rojo. Al pasar el ratón, el valor y la fecha del punto más cercano.
class GraficaMedidas extends StatefulWidget {
  final List<(DateTime, double)> datos;
  final double? minimo, maximo;
  final String unidad;
  const GraficaMedidas(this.datos, {super.key, this.minimo, this.maximo, this.unidad = ''});

  @override
  State<GraficaMedidas> createState() => _GraficaMedidasState();
}

class _GraficaMedidasState extends State<GraficaMedidas> {
  int? cerca;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final pintor = _PintorMedidas(widget.datos, widget.minimo, widget.maximo, cerca, P.morado, P.rojo, P.borde, P.textoSuave);
      return MouseRegion(
        onHover: (e) => setState(() => cerca = pintor.cercano(e.localPosition, box.biggest)),
        onExit: (_) => setState(() => cerca = null),
        child: Stack(
          children: [
            CustomPaint(size: box.biggest, painter: pintor),
            if (cerca != null)
              Positioned(
                left: (pintor.punto(cerca!, box.biggest).dx - 70).clamp(0, max(0, box.maxWidth - 140)),
                top: 0,
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: P.superficie,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: P.borde),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${numTexto(widget.datos[cerca!].$2)}${widget.unidad}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(fecha(widget.datos[cerca!].$1), style: TextStyle(fontSize: 12, color: P.textoSuave)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PintorMedidas extends CustomPainter {
  final List<(DateTime, double)> datos;
  final double? minimo, maximo;
  final int? cerca;
  final Color linea, alerta, rejilla, texto;
  _PintorMedidas(this.datos, this.minimo, this.maximo, this.cerca, this.linea, this.alerta, this.rejilla, this.texto);

  static const _izq = 44.0, _abajo = 22.0, _arriba = 46.0;

  (double, double) get _rango {
    final valores = [for (final d in datos) d.$2, ?minimo, ?maximo];
    var lo = valores.reduce(min), hi = valores.reduce(max);
    if (hi == lo) {
      lo -= 1;
      hi += 1;
    }
    final margen = (hi - lo) * .1;
    return (lo - margen, hi + margen);
  }

  double _y(double v, Size s) {
    final (lo, hi) = _rango;
    return _arriba + (s.height - _arriba - _abajo) * (1 - (v - lo) / (hi - lo));
  }

  Offset punto(int i, Size s) {
    final ancho = s.width - _izq;
    final x = datos.length == 1 ? _izq + ancho / 2 : _izq + ancho * i / (datos.length - 1);
    return Offset(x, _y(datos[i].$2, s));
  }

  int? cercano(Offset p, Size s) {
    if (datos.isEmpty) return null;
    var mejor = 0;
    for (var i = 1; i < datos.length; i++) {
      if ((punto(i, s).dx - p.dx).abs() < (punto(mejor, s).dx - p.dx).abs()) mejor = i;
    }
    return mejor;
  }

  bool _fuera(double v) => (minimo != null && v < minimo!) || (maximo != null && v > maximo!);

  void _texto(Canvas c, String t, Offset o, {bool derecha = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 11, color: texto)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, derecha ? o.translate(-tp.width, -tp.height / 2) : o);
  }

  @override
  void paint(Canvas canvas, Size s) {
    if (datos.isEmpty) return;
    final (lo, hi) = _rango;
    // Rejilla recesiva: tres líneas horizontales con su valor.
    final fino = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      final y = _y(v, s);
      canvas.drawLine(Offset(_izq, y), Offset(s.width, y), fino);
      _texto(canvas, numTexto(v), Offset(_izq - 6, y), derecha: true);
    }
    // Límites: discontinuos.
    final limite = Paint()
      ..color = texto
      ..strokeWidth = 1.2;
    for (final v in [?minimo, ?maximo]) {
      final y = _y(v, s);
      for (var x = _izq; x < s.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 4, s.width), y), limite);
      }
    }
    // La línea (2 px) y sus puntos.
    final camino = Path()..moveTo(punto(0, s).dx, punto(0, s).dy);
    for (var i = 1; i < datos.length; i++) {
      camino.lineTo(punto(i, s).dx, punto(i, s).dy);
    }
    canvas.drawPath(
      camino,
      Paint()
        ..color = linea
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < datos.length; i++) {
      final p = punto(i, s);
      final r = i == cerca ? 6.0 : 4.0;
      canvas.drawCircle(p, r + 2, Paint()..color = Colors.white);
      canvas.drawCircle(p, r, Paint()..color = _fuera(datos[i].$2) ? alerta : linea);
    }
    if (cerca != null) {
      final p = punto(cerca!, s);
      canvas.drawLine(Offset(p.dx, _arriba), Offset(p.dx, s.height - _abajo), fino);
    }
    // Fechas: la primera y la última.
    _texto(canvas, fecha(datos.first.$1), Offset(_izq, s.height - _abajo + 6));
    if (datos.length > 1) {
      final tp = TextPainter(text: TextSpan(text: fecha(datos.last.$1), style: TextStyle(fontSize: 11, color: texto)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(s.width - tp.width, s.height - _abajo + 6));
    }
  }

  @override
  bool shouldRepaint(_PintorMedidas o) => o.datos != datos || o.cerca != cerca || o.minimo != minimo || o.maximo != maximo;
}

// ── 3. Por técnico ──────────────────────────────────────────────────────────

class _PorTecnico extends StatelessWidget {
  final DateTime desde;
  const _PorTecnico({required this.desde});

  @override
  Widget build(BuildContext context) {
    final realizadas = otsRealizadas().where((r) => !r.$1.isBefore(desde)).toList();
    final filas = [
      for (final w in store.trabajadores.where((w) => w.activo))
        () {
          final suyas = realizadas.where((r) => (r.$2.ejecutadoPor ?? r.$2.trabajadorIds.firstOrNull) == w.id).toList();
          return (
            w: w,
            incidencias: store.incidencias.where((x) => x.tecnicoId == w.id && !x.creada.isBefore(desde)).length,
            hechas: suyas.length,
            conProblema: suyas.where((r) => (r.$2.resultado ?? 0) > 0).length,
            atrasadas: [...store.tareas, ...store.subtareas]
                .where((t) => otPendiente(t) && t.trabajadorIds.contains(w.id) && t.proximo != null && diasHasta(t.proximo!) < 0)
                .length,
          );
        }(),
    ]..sort((a, b) => b.hechas.compareTo(a.hechas));
    if (filas.isEmpty) {
      return const Vacio(icono: Icons.engineering_outlined, titulo: 'Sin técnicos', texto: 'Añade técnicos para ver lo que hace cada uno.');
    }
    final maxHechas = filas.map((f) => f.hechas).reduce(max), maxInc = filas.map((f) => f.incidencias).reduce(max);
    return SegunTamano(
      clave: (box) => box.maxWidth > 760,
      builder: (context, box) {
        final ancho = box.maxWidth > 760;
        return Tabla(
          columnas: [
            const Col('Técnico', flex: 3),
            const Col('OT hechas', flex: 3),
            const Col('Incidencias detectadas', flex: 3),
            if (ancho) const Col('Partes con problema', ancho: 150),
            const Col('Atrasadas ahora', ancho: 130),
          ],
          filas: filas.length,
          celdas: (i) {
            final f = filas[i];
            return [
              Row(children: [
                Avatar(inicialesDe(f.w.nombreCompleto), colorPaleta(f.w.color), size: 26),
                const SizedBox(width: 10),
                Expanded(child: celdaTexto(f.w.nombreCompleto, negrita: true)),
              ]),
              Padding(padding: const EdgeInsets.only(right: 16), child: _barra(f.hechas, maxHechas, P.morado)),
              Padding(padding: const EdgeInsets.only(right: 16), child: _barra(f.incidencias, maxInc, P.rojo)),
              if (ancho) celdaTexto('${f.conProblema}', suave: f.conProblema == 0),
              Align(
                alignment: Alignment.centerLeft,
                child: f.atrasadas == 0 ? celdaTexto('0', suave: true) : Pill('${f.atrasadas}', P.rojo, punto: true),
              ),
            ];
          },
          pie: pieTabla(filas.length, filas.length == 1 ? 'técnico' : 'técnicos'),
        );
      },
    );
  }
}

// ── 4. Incidencias por equipo ───────────────────────────────────────────────

class _PorEquipo extends StatelessWidget {
  final DateTime desde;
  final int dias;
  const _PorEquipo({required this.desde, required this.dias});

  @override
  Widget build(BuildContext context) {
    final porMaquina = <String, List<Incidencia>>{};
    for (final x in store.incidencias.where((x) => !x.creada.isBefore(desde))) {
      final r = raizDe(x.activoId);
      if (r != null) (porMaquina[r.id] ??= []).add(x);
    }
    final filas = porMaquina.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (filas.isEmpty) {
      return const Vacio(icono: Icons.report_outlined, titulo: 'Sin incidencias', texto: 'Ninguna máquina ha tenido incidencias en este periodo.');
    }
    final maximo = filas.first.value.length;
    return SegunTamano(
      clave: (box) => box.maxWidth > 900,
      builder: (context, box) {
        final ancho = box.maxWidth > 900;
        return Tabla(
          columnas: [
            const Col('Activo', flex: 3),
            const Col('Incidencias', flex: 3),
            if (ancho) const Col('Abiertas', ancho: 90),
            if (ancho) const Col('Resueltas', ancho: 90),
            if (ancho) const Col('Desestimadas', ancho: 110),
            const Col('Frecuencia', ancho: 140),
            if (ancho) const Col('Última', ancho: 120),
          ],
          filas: filas.length,
          celdas: (i) {
            final a = store.activo(filas[i].key)!;
            final l = filas[i].value;
            final estados = [for (final x in l) store.estadoIncidencia(x)];
            final ultima = l.map((x) => x.creada).reduce((x, y) => x.isAfter(y) ? x : y);
            return [
              celdaTexto(a.titulo, negrita: true),
              Padding(padding: const EdgeInsets.only(right: 16), child: _barra(l.length, maximo, P.rojo)),
              if (ancho) celdaTexto('${estados.where((e) => e.pendiente).length}'),
              if (ancho) celdaTexto('${estados.where((e) => e == EstadoIncidencia.completada).length}'),
              if (ancho) celdaTexto('${estados.where((e) => e == EstadoIncidencia.desestimada).length}', suave: true),
              celdaTexto('1 cada ${max(1, (dias / l.length).round())} días', suave: true),
              if (ancho) celdaTexto(relativo(DateUtils.dateOnly(ultima)), suave: true),
            ];
          },
          pie: pieTabla(filas.length, filas.length == 1 ? 'activo con incidencias' : 'activos con incidencias'),
        );
      },
    );
  }
}
