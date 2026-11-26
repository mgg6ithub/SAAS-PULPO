import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../forms.dart' show SelectorActivo;
import '../informes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'activos.dart' show contadorTexto;
import 'estadisticas_prueba.dart';
import 'graficas.dart';
import 'gravedad.dart';
import 'indicadores.dart';
import 'historicos.dart';
import 'incidencia.dart';
import 'mantenimientos.dart' show raizDe;
import 'incidencias.dart' show verIncidencia;
import 'informe_estadisticas.dart';
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
  void dispose() {
    // Los datos de prueba no se quedan fuera de Estadísticas.
    EstadisticasPrueba.quitar();
    super.dispose();
  }

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
                opciones: const ['Activo', 'Indicadores', 'Verificaciones', 'Técnicos', 'Incidencias'],
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
              // Solo al desarrollar: un año de datos inventados, en memoria, para ver las gráficas.
              if (kDebugMode)
                BotonAccion(
                  EstadisticasPrueba.activa ? 'Quitar prueba' : 'Datos de prueba',
                  icono: Icons.science_outlined,
                  tooltip: 'Generar estadísticas de prueba (no se guardan)',
                  onPressed: () => setState(() {
                    EstadisticasPrueba.activa ? EstadisticasPrueba.quitar() : EstadisticasPrueba.poner();
                    activoId = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            // Cada apartado se ve siempre tal cual, aunque aún no haya datos (cifras a cero).
            child: switch (apartado) {
              0 => _PorActivo(
                activoId: activoId,
                desde: desde,
                dias: dias,
                onActivo: (id) => setState(() => activoId = id),
              ),
              1 => IndicadoresPultec(desde: desde, dias: dias),
              2 => _Verificaciones(desde: desde),
              3 => _PorTecnico(desde: desde, dias: dias),
              _ => _PorEquipo(desde: desde, dias: dias),
            },
          ),
        ],
      ),
    );
  }
}

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
    // Sin activo elegido, la suma de todos.
    final r = resumenActivo(a, desde);
    final t = tramosDe(desde, dias);
    final hechas = contarPorTramo(r.realizadas.map((x) => x.$1), t);
    final incidencias = contarPorTramo(r.incidencias.map((x) => x.creada), t);
    // Sin ListView: este no destruye lo que sale de pantalla, así las gráficas se animan al entrar en Estadísticas
    // y no cada vez que vuelven a verse al hacer scroll.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: SelectorActivo(a?.id, onActivo, filtro: true),
            ),
            const Spacer(),
            // Abre la ventana del informe: de cuántos días (slider) y de toda la empresa o de este activo.
            IconButton(
              tooltip: 'Descargar informe en PDF',
              onPressed: () => abrirInformeEstadisticas(context, activo: a, dias: dias),
              icon: Icon(Icons.download_rounded, size: 18, color: P.textoSuave),
            ),
          ],
        ),
        const SizedBox(height: huecoVista),
        SegunTamano(
          key: ValueKey('cifras-${a?.id}-$dias'),
          clave: (box) => box.maxWidth > 900 ? 6 : box.maxWidth > 560 ? 3 : 2,
          builder: (context, box) => Rejilla(
            columnas: box.maxWidth > 900 ? 6 : box.maxWidth > 560 ? 3 : 2,
            hueco: huecoVista,
            igualarAlto: true,
            children: [
              CifraGrafica('Hechas en el periodo', valor: r.hechas, serie: hechas),
              CifraGrafica('Pendientes', valor: r.pendientes),
              CifraGrafica('Atrasadas', valor: r.atrasadas),
              CifraGrafica('Incidencias', valor: r.incidencias.length, serie: incidencias),
              CifraGrafica('Con problema en el parte', valor: r.conProblema),
              CifraGrafica('Contador', texto: a == null ? '—' : contadorTexto(a).split(',').first),
            ],
          ),
        ),
        const SizedBox(height: huecoVista),
        _ParGraficas(
          key: ValueKey('graficas-${a?.id}-$dias'),
          TarjetaGrafica(
            titulo: 'Órdenes hechas',
            nota: t.nombre,
            child: GraficaColumnas(hechas, t.etiquetas, unidad: 'órdenes'),
          ),
          TarjetaGrafica(
            titulo: 'Estado de las órdenes',
            nota: 'Hechas en el periodo y pendientes ahora',
            child: Anillo(
              [('Hechas', r.hechas.toDouble()), ('Pendientes al día', (r.pendientes - r.atrasadas).toDouble()), ('Atrasadas', r.atrasadas.toDouble())],
              centro: r.hechas + r.pendientes == 0 ? '—' : '${(100 * r.hechas / (r.hechas + r.pendientes)).round()} %',
              nota: 'hechas',
            ),
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
            // Con «Todos los activos» pueden ser cientos y la lista no es perezosa: se enseñan los primeros.
            for (final (p, hechos) in r.planes.take(50)) _FilaPlan(p, hechos),
            if (r.planes.length > 50)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Y ${r.planes.length - 50} más: elige un activo para verlos', style: TextStyle(color: P.textoSuave)),
              ),
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
                  titulo: x.descripcion,
                  subtitulo: fecha(x.creada),
                  derecha: Pill(store.estadoIncidencia(x).etiqueta, store.estadoIncidencia(x).color),
                  // Lleva a Incidencias con esta marcada en rojo.
                  onTap: () => verIncidencia(context, x.id),
                ),
          ],
        ),
      ],
      ),
    );
  }
}

/// Dos gráficas: la principal más ancha y la otra al lado; en ventana estrecha, una bajo otra.
class _ParGraficas extends StatelessWidget {
  final Widget principal, lado;
  const _ParGraficas(this.principal, this.lado, {super.key});

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => box.maxWidth > 900,
    builder: (context, box) => box.maxWidth > 900
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: principal),
              const SizedBox(width: huecoVista),
              Expanded(flex: 2, child: lado),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [principal, const SizedBox(height: huecoVista), lado],
          ),
  );
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

/// Lo que se cuenta de un activo (y sus componentes) en el periodo, o de todos si [a] es null; también lo usa su PDF.
typedef ResumenActivo = ({
  int hechas,
  int pendientes,
  int atrasadas,
  int conProblema,
  List<Incidencia> incidencias,
  List<(PlanMantenimiento, int)> planes,
  List<Realizada> realizadas,
});

ResumenActivo resumenActivo(Activo? a, DateTime desde) {
  final rama = a == null ? {for (final x in store.activos) x.id} : store.ramaDe(a.id);
  final ots = [...store.tareas, ...store.subtareas].where((t) => !t.esPlantilla && rama.contains(t.activoId)).toList();
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

  Future<List<(DateTime, double)>> _de(String id) => EstadisticasPrueba.activa
      ? Future.value(EstadisticasPrueba.mediciones[id] ?? const [])
      : _datos[id] ??= informes.mediciones(id);

  @override
  Widget build(BuildContext context) {
    final planes = store.planes.where((p) => p.conMedicion).toList()
      ..sort((a, b) => '${raizDe(a.activoId)?.titulo} ${a.nombre}'.compareTo('${raizDe(b.activoId)?.titulo} ${b.nombre}'));
    // Sin ninguna, la misma vista a cero; la lista explica cómo se añade una.
    final p = planes.where((x) => x.id == planId).firstOrNull ?? planes.firstOrNull;
    final lista = SeccionTarjeta(
      titulo: 'Mediciones',
      subtitulo: '${planes.length}',
      children: [
        if (planes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'En un mantenimiento, rellena «Medición» (qué se mide, unidad y límites) y el técnico apuntará el valor en su parte.',
              style: TextStyle(color: P.textoSuave),
            ),
          ),
        for (final x in planes)
          Container(
            color: x.id == p?.id ? P.moradoSuave : null,
            child: FilaLista(
              lider: Icon(Icons.show_chart_rounded, size: 18, color: x.id == p?.id ? P.morado : P.textoSuave),
              titulo: x.medicionNombre,
              subtitulo: '${x.nombre}, ${raizDe(x.activoId)?.titulo ?? ''}',
              onTap: () => setState(() => planId = x.id),
            ),
          ),
      ],
    );
    final detalle = FutureBuilder(
      future: p == null ? Future.value(const <(DateTime, double)>[]) : _de(p.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return snap.hasError
              ? Padding(padding: const EdgeInsets.all(18), child: Text('No se pudieron leer las mediciones', style: TextStyle(color: P.textoSuave)))
              : const Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator());
        }
        final datos = snap.data!.where((d) => !d.$1.isBefore(widget.desde)).toList();
        final minimo = p?.medicionMin, maximo = p?.medicionMax;
        bool fueraDe(double v) => (minimo != null && v < minimo) || (maximo != null && v > maximo);
        final fuera = datos.where((d) => fueraDe(d.$2)).length;
        final unidad = p?.medicionUnidad ?? '';
        final u = unidad.isEmpty ? '' : ' $unidad';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(
              key: ValueKey('cifras-${p?.id}-${widget.desde}'),
              columnas: 4,
              hueco: huecoVista,
              igualarAlto: true,
              children: [
                CifraGrafica('Medidas', valor: datos.length),
                CifraGrafica('Última', texto: datos.isEmpty ? '—' : '${numTexto(datos.last.$2)}$u', serie: [for (final d in datos.reversed.take(12).toList().reversed) d.$2]),
                CifraGrafica('Media', texto: datos.isEmpty ? '—' : '${numTexto(datos.map((d) => d.$2).reduce((a, b) => a + b) / datos.length)}$u'),
                CifraGrafica('Fuera de límites', valor: fuera),
              ],
            ),
            const SizedBox(height: huecoVista),
            TarjetaGrafica(
              titulo: '${p?.medicionNombre ?? 'Medidas'}${u.isEmpty ? '' : ' ($u)'.replaceAll('( ', '(')}',
              nota: minimo != null || maximo != null
                  ? 'Admitido de ${minimo == null ? '…' : numTexto(minimo)} a ${maximo == null ? '…' : numTexto(maximo)}'
                  : null,
              alto: 280,
              child: datos.isEmpty
                  ? Center(child: Text('Sin medidas en este periodo', style: TextStyle(color: P.textoSuave)))
                  : GraficaMedidas(
                      key: ValueKey('medidas-${p?.id}-${widget.desde}'),
                      datos,
                      minimo: minimo,
                      maximo: maximo,
                      unidad: u,
                    ),
            ),
            const SizedBox(height: huecoVista),
            SeccionTarjeta(
              titulo: 'Historial',
              children: [
                for (final (d, v) in datos.reversed.take(30))
                  FilaLista(
                    titulo: '${numTexto(v)}$u',
                    subtitulo: '${fecha(d)} ${hhmm(d.hour * 60 + d.minute)}',
                    derecha: fueraDe(v) ? const Pill('Fuera de límites', P.rojo) : null,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [lista, const SizedBox(height: huecoVista), detalle],
              ),
            ),
    );
  }
}

/// Medidas en el tiempo: curva suave en morado con su área en degradado, la franja admitida sombreada entre los
/// límites (rayas discontinuas) y los puntos fuera de límites en rojo. Se dibuja de izquierda a derecha al entrar;
/// al pasar el ratón, el punto más cercano con su valor y fecha.
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
    builder: (context, box) => EntradaGrafica(
      ms: 1100,
      builder: (v) {
        final pintor = _PintorMedidas(widget.datos, widget.minimo, widget.maximo, cerca, v, P.morado, P.rojo, P.borde, P.textoSuave, P.superficie);
        return MouseRegion(
          onHover: (e) {
            final i = pintor.cercano(e.localPosition, box.biggest);
            if (i != cerca) setState(() => cerca = i);
          },
          onExit: (_) => setState(() => cerca = null),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(size: box.biggest, painter: pintor),
              if (cerca != null)
                Positioned(
                  left: (pintor.punto(cerca!, box.biggest).dx - 60).clamp(0, max(0, box.maxWidth - 120)),
                  top: max(0, pintor.punto(cerca!, box.biggest).dy - 58),
                  child: Globo('${numTexto(widget.datos[cerca!].$2)}${widget.unidad}', fecha(widget.datos[cerca!].$1)),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _PintorMedidas extends CustomPainter {
  final List<(DateTime, double)> datos;
  final double? minimo, maximo;
  final int? cerca;
  final double v;
  final Color linea, alerta, rejilla, texto, fondo;
  _PintorMedidas(this.datos, this.minimo, this.maximo, this.cerca, this.v, this.linea, this.alerta, this.rejilla, this.texto, this.fondo);

  static const _izq = 44.0, _abajo = 24.0, _arriba = 12.0;

  (double, double) get _rango {
    final valores = [for (final d in datos) d.$2, ?minimo, ?maximo];
    var lo = valores.reduce(min), hi = valores.reduce(max);
    if (hi == lo) {
      lo -= 1;
      hi += 1;
    }
    final margen = (hi - lo) * .12;
    return (lo - margen, hi + margen);
  }

  double _y(double v, Size s) {
    final (lo, hi) = _rango;
    return _arriba + (s.height - _arriba - _abajo) * (1 - (v - lo) / (hi - lo));
  }

  Offset punto(int i, Size s) {
    final ancho = s.width - _izq - 8;
    final x = datos.length == 1 ? _izq + ancho / 2 : _izq + 4 + ancho * i / (datos.length - 1);
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

  void _texto(Canvas c, String t, Offset o, {double alinear = 0, double vertical = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 11, color: texto)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o.translate(-tp.width * alinear, -tp.height * vertical));
  }

  @override
  void paint(Canvas canvas, Size s) {
    if (datos.isEmpty) return;
    final (lo, hi) = _rango;
    final abajo = s.height - _abajo;
    // Rejilla recesiva: cuatro rayas con su valor.
    final fino = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final val = lo + (hi - lo) * k / 3;
      final y = _y(val, s);
      canvas.drawLine(Offset(_izq, y), Offset(s.width, y), fino);
      _texto(canvas, numTexto(double.parse(val.toStringAsFixed(1))), Offset(_izq - 8, y), alinear: 1, vertical: .5);
    }
    // Franja admitida, sombreada, y sus límites discontinuos.
    if (minimo != null || maximo != null) {
      final y1 = _y(maximo ?? hi, s), y2 = _y(minimo ?? lo, s);
      canvas.drawRect(Rect.fromLTRB(_izq, y1, s.width, y2), Paint()..color = linea.withValues(alpha: .05));
      final limite = Paint()
        ..color = texto.withValues(alpha: .6)
        ..strokeWidth = 1;
      for (final val in [?minimo, ?maximo]) {
        final y = _y(val, s);
        for (var x = _izq; x < s.width; x += 8) {
          canvas.drawLine(Offset(x, y), Offset(min(x + 4, s.width), y), limite);
        }
      }
    }
    final pts = [for (var i = 0; i < datos.length; i++) punto(i, s)];
    canvas.save();
    // Entrada: se descubre de izquierda a derecha.
    canvas.clipRect(Rect.fromLTRB(0, 0, _izq + (s.width - _izq) * v, s.height));
    if (pts.length > 1) {
      final curva = curvaSuave(pts);
      final area = Path.from(curva)
        ..lineTo(pts.last.dx, abajo)
        ..lineTo(pts.first.dx, abajo)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [linea.withValues(alpha: .20), linea.withValues(alpha: 0)],
          ).createShader(Rect.fromLTRB(0, _arriba, s.width, abajo)),
      );
      canvas.drawPath(
        curva,
        Paint()
          ..color = linea
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // Solo se marcan los puntos que importan: fuera de límites (rojo), el de bajo el ratón y el último.
    for (var i = 0; i < datos.length; i++) {
      final fuera = _fuera(datos[i].$2);
      if (!fuera && i != cerca && i != datos.length - 1) continue;
      final r = i == cerca ? 6.0 : 4.5;
      canvas.drawCircle(pts[i], r + 2.5, Paint()..color = fondo);
      canvas.drawCircle(pts[i], r, Paint()..color = fuera ? alerta : linea);
    }
    canvas.restore();
    if (cerca != null) {
      final p = pts[cerca!];
      final guia = Paint()
        ..color = texto.withValues(alpha: .35)
        ..strokeWidth = 1;
      for (var y = _arriba; y < abajo; y += 6) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, min(y + 3, abajo)), guia);
      }
    }
    // Fechas: la primera y la última.
    _texto(canvas, fecha(datos.first.$1), Offset(_izq, abajo + 7));
    if (datos.length > 1) _texto(canvas, fecha(datos.last.$1), Offset(s.width, abajo + 7), alinear: 1);
  }

  @override
  bool shouldRepaint(_PintorMedidas o) =>
      o.datos != datos || o.cerca != cerca || o.v != v || o.minimo != minimo || o.maximo != maximo || o.linea != linea;
}

// ── 3. Por técnico ──────────────────────────────────────────────────────────

class _PorTecnico extends StatelessWidget {
  final DateTime desde;
  final int dias;
  const _PorTecnico({required this.desde, required this.dias});

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
    final maxHechas = filas.fold(0, (m, f) => max(m, f.hechas)), maxInc = filas.fold(0, (m, f) => max(m, f.incidencias));
    final t = tramosDe(desde, dias);
    final graficas = _ParGraficas(
      key: ValueKey('tecnicos-$dias'),
      TarjetaGrafica(
        titulo: 'Órdenes hechas por el equipo',
        nota: t.nombre,
        alto: 190,
        child: GraficaColumnas(contarPorTramo(realizadas.map((x) => x.$1), t), t.etiquetas, unidad: 'órdenes'),
      ),
      TarjetaGrafica(
        titulo: 'Quién hace más',
        nota: 'Órdenes hechas en el periodo',
        alto: 190,
        child: BarrasRanking([
          for (final f in filas.take(5))
            (nombre: f.w.nombreCompleto, valor: f.hechas.toDouble(), lider: Avatar(inicialesDe(f.w.nombreCompleto), colorPaleta(f.w.color), size: 24)),
        ]),
      ),
    );
    final tabla = SegunTamano(
      clave: (box) => (box.maxWidth > 760, box.maxWidth > 600),
      builder: (context, box) {
        final ancho = box.maxWidth > 760;
        return Tabla(
          id: 'estadisticas-tecnicos',
          menuColumnas: box.maxWidth > 600,
          columnas: [
            const Col('Técnico', flex: 3, fija: true),
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
              Padding(padding: const EdgeInsets.only(right: 16), child: CeldaBarra(f.hechas, maxHechas)),
              Padding(padding: const EdgeInsets.only(right: 16), child: CeldaBarra(f.incidencias, maxInc, color: tonoMorado(2, 4))),
              if (ancho) celdaTexto('${f.conProblema}', suave: f.conProblema == 0),
              Align(
                alignment: Alignment.centerLeft,
                child: f.atrasadas == 0 ? celdaTexto('0', suave: true) : Pill('${f.atrasadas}', P.rojo),
              ),
            ];
          },
          pie: filas.isEmpty ? null : pieTabla(filas.length, filas.length == 1 ? 'técnico' : 'técnicos'),
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [graficas, const SizedBox(height: huecoVista), Expanded(child: tabla)],
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
    final maximo = filas.firstOrNull?.value.length ?? 0;
    final todas = [for (final f in filas) ...f.value];
    final estados = [for (final x in todas) store.estadoIncidencia(x)];
    final t = tramosDe(desde, dias);
    final graficas = _ParGraficas(
      key: ValueKey('equipos-$dias'),
      TarjetaGrafica(
        titulo: 'Incidencias en el tiempo',
        nota: t.nombre,
        alto: 190,
        child: GraficaColumnas(contarPorTramo(todas.map((x) => x.creada), t), t.etiquetas, unidad: 'incidencias'),
      ),
      TarjetaGrafica(
        titulo: 'Cómo acabaron',
        nota: 'Incidencias del periodo',
        alto: 190,
        child: Anillo(
          [
            // Primero las resueltas: son las que llenan el anillo.
            ('Resueltas', estados.where((e) => e == EstadoIncidencia.completada).length.toDouble()),
            ('Abiertas', estados.where((e) => e.pendiente).length.toDouble()),
            ('Desestimadas', estados.where((e) => e == EstadoIncidencia.desestimada).length.toDouble()),
          ],
          centro: '${todas.length}',
          nota: 'incidencias',
        ),
      ),
    );
    final tabla = SegunTamano(
      clave: (box) => (box.maxWidth > 900, box.maxWidth > 600),
      builder: (context, box) {
        final ancho = box.maxWidth > 900;
        return Tabla(
          id: 'estadisticas-incidencias',
          menuColumnas: box.maxWidth > 600,
          columnas: [
            const Col('Activo', flex: 3, fija: true),
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
              Padding(padding: const EdgeInsets.only(right: 16), child: CeldaBarra(l.length, maximo)),
              if (ancho) celdaTexto('${estados.where((e) => e.pendiente).length}'),
              if (ancho) celdaTexto('${estados.where((e) => e == EstadoIncidencia.completada).length}'),
              if (ancho) celdaTexto('${estados.where((e) => e == EstadoIncidencia.desestimada).length}', suave: true),
              celdaTexto('1 cada ${max(1, (dias / l.length).round())} días', suave: true),
              if (ancho) celdaTexto(relativo(DateUtils.dateOnly(ultima)), suave: true),
            ];
          },
          pie: filas.isEmpty ? null : pieTabla(filas.length, filas.length == 1 ? 'activo con incidencias' : 'activos con incidencias'),
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [graficas, const SizedBox(height: huecoVista), Expanded(child: tabla)],
    );
  }
}
