import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'estadisticas.dart' show numTexto;
import 'graficas.dart';
import 'gravedad.dart';
import 'historicos.dart';
import 'incidencia.dart';

/// Indicadores de mantenimiento (DEV-055) de un activo con sus componentes, o de todos, en el periodo:
/// - **Averías**: incidencias abiertas en el periodo (sin las desestimadas).
/// - **MTBF**: días del periodo (por activo) entre averías.
/// - **MTTR**: horas medias desde que se abre una incidencia hasta que se resuelve.
/// - **Disponibilidad**: parte del periodo sin incidencias graves abiertas (la máquina se da por parada).
/// - **Preventivo frente a correctivo**: OT hechas de cada tipo.
/// - **Cumplimiento del plan**: preventivas hechas frente a las que siguen vencidas.
typedef Indicadores = ({
  int averias,
  double? mtbfDias,
  double? mttrHoras,
  double disponibilidad,
  int preventivas,
  int correctivas,
  double? cumplimiento,
});

/// Cuándo se resolvió: su cierre o, si se resolvió con su OT, el día que se hizo esa OT (a media tarde).
DateTime? _resuelta(Incidencia x) {
  if (x.cerradaEl != null) return x.cerradaEl;
  if (store.estadoIncidencia(x) != EstadoIncidencia.completada) return null;
  final ot = x.trabajoId == null ? null : store.tarea(x.trabajoId!);
  final dia = ot?.ultimo;
  if (dia == null) return null;
  final t = DateUtils.dateOnly(dia).add(const Duration(hours: 18));
  return t.isBefore(x.creada) ? x.creada : t;
}

/// [rama] null = todos los activos (los tiempos se reparten entre las máquinas).
Indicadores indicadoresDe(Set<String>? rama, DateTime desde, int dias) {
  bool suyo(String? id) => rama == null ? id != null : rama.contains(id);
  final maquinas = rama == null ? max(1, store.hijosDe(null).length) : 1;
  final ahora = DateTime.now();
  final horas = dias * 24.0 * maquinas;

  final incid = store.incidencias.where((x) => suyo(x.activoId) && store.estadoIncidencia(x) != EstadoIncidencia.desestimada);
  final enPeriodo = incid.where((x) => !x.creada.isBefore(desde)).toList();

  final reparaciones = [
    for (final x in enPeriodo)
      if (_resuelta(x) case final r?) r.difference(x.creada).inMinutes / 60,
  ];

  // Parada: lo que estuvo abierta cada incidencia grave dentro del periodo.
  var parada = 0.0;
  for (final x in incid.where((x) => x.gravedad == Gravedad.grave)) {
    final fin = _resuelta(x) ?? ahora;
    final a = x.creada.isBefore(desde) ? desde : x.creada, b = fin.isAfter(ahora) ? ahora : fin;
    if (b.isAfter(a)) parada += b.difference(a).inMinutes / 60;
  }

  final hechas = otsRealizadas().where((r) => suyo(r.$2.activoId) && !r.$1.isBefore(desde) && r.$2.estado != EstadoTrabajo.noRealizado);
  final preventivas = hechas.where((r) => r.$2.tipoMantenimiento == TipoMantenimiento.preventivo).length;
  final correctivas = hechas.where((r) => r.$2.tipoMantenimiento != null && r.$2.tipoMantenimiento != TipoMantenimiento.preventivo).length;
  final vencidas = [...store.tareas, ...store.subtareas]
      .where((t) =>
          suyo(t.activoId) &&
          otPendiente(t) &&
          t.tipoMantenimiento == TipoMantenimiento.preventivo &&
          t.proximo != null &&
          diasHasta(t.proximo!) < 0)
      .length;

  return (
    averias: enPeriodo.length,
    mtbfDias: enPeriodo.isEmpty ? null : dias * maquinas / enPeriodo.length,
    mttrHoras: reparaciones.isEmpty ? null : reparaciones.reduce((a, b) => a + b) / reparaciones.length,
    disponibilidad: (1 - parada / horas).clamp(0.0, 1.0),
    preventivas: preventivas,
    correctivas: correctivas,
    cumplimiento: preventivas + vencidas == 0 ? null : preventivas / (preventivas + vencidas),
  );
}

String _pct(double? v) => v == null ? '—' : '${(v * 100).round()} %';
String _dias(double? v) => v == null ? 'Sin averías' : '${numTexto(double.parse(v.toStringAsFixed(1)))} días';
String _horas(double? v) => v == null ? '—' : '${numTexto(double.parse(v.toStringAsFixed(1)))} h';

/// Apartado «Indicadores» de Estadísticas: los cinco globales, el reparto preventivo/correctivo, las máquinas con
/// menos disponibilidad y una tabla con los indicadores de cada activo.
class IndicadoresPultec extends StatelessWidget {
  final DateTime desde;
  final int dias;
  const IndicadoresPultec({super.key, required this.desde, required this.dias});

  @override
  Widget build(BuildContext context) {
    final g = indicadoresDe(null, desde, dias);
    final filas = [
      for (final a in store.hijosDe(null)) (a: a, i: indicadoresDe(store.ramaDe(a.id), desde, dias)),
    ]..sort((x, y) => x.i.disponibilidad.compareTo(y.i.disponibilidad));
    if (filas.isEmpty) {
      return const Vacio(icono: Icons.speed_rounded, titulo: 'Sin indicadores', texto: 'Aparecerán cuando tengas activos con órdenes e incidencias.');
    }
    final cifras = SegunTamano(
      key: ValueKey('indicadores-$dias'),
      clave: (box) => box.maxWidth > 900 ? 5 : box.maxWidth > 560 ? 3 : 2,
      builder: (context, box) => Rejilla(
        columnas: box.maxWidth > 900 ? 5 : box.maxWidth > 560 ? 3 : 2,
        hueco: huecoVista,
        children: [
          CifraGrafica('MTBF, entre averías', texto: _dias(g.mtbfDias)),
          CifraGrafica('MTTR, en reparar', texto: _horas(g.mttrHoras)),
          CifraGrafica('Disponibilidad', valor: (g.disponibilidad * 100).round(), sufijo: ' %'),
          CifraGrafica(
            'Preventivo',
            texto: g.preventivas + g.correctivas == 0 ? '—' : _pct(g.preventivas / (g.preventivas + g.correctivas)),
          ),
          CifraGrafica('Cumplimiento del plan', texto: _pct(g.cumplimiento)),
        ],
      ),
    );
    final graficas = SegunTamano(
      key: ValueKey('indicadores-graficas-$dias'),
      clave: (box) => box.maxWidth > 900,
      builder: (context, box) {
        final reparto = TarjetaGrafica(
          titulo: 'Preventivo frente a correctivo',
          nota: 'Órdenes hechas en el periodo',
          alto: 190,
          child: Anillo(
            [('Preventivo', g.preventivas.toDouble()), ('Correctivo', g.correctivas.toDouble())],
            centro: g.preventivas + g.correctivas == 0 ? '—' : _pct(g.preventivas / (g.preventivas + g.correctivas)),
            nota: 'preventivo',
          ),
        );
        final peores = TarjetaGrafica(
          titulo: 'Menos disponibles',
          nota: 'Parte del periodo sin incidencias graves abiertas',
          alto: 190,
          child: BarrasRanking([
            for (final f in filas.take(5)) (nombre: f.a.titulo, valor: (f.i.disponibilidad * 100).roundToDouble(), lider: null),
          ], maximo: 100, sufijo: ' %'),
        );
        return box.maxWidth > 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: reparto),
                  const SizedBox(width: huecoVista),
                  Expanded(flex: 3, child: peores),
                ],
              )
            : reparto;
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cifras,
        const SizedBox(height: huecoVista),
        graficas,
        const SizedBox(height: huecoVista),
        Expanded(
          child: SegunTamano(
            clave: (box) => box.maxWidth > 900,
            builder: (context, box) {
              final ancho = box.maxWidth > 900;
              return Tabla(
                columnas: [
                  const Col('Activo', flex: 3),
                  const Col('Disponibilidad', flex: 3),
                  const Col('Averías', ancho: 90),
                  const Col('MTBF', ancho: 120),
                  const Col('MTTR', ancho: 100),
                  if (ancho) const Col('Preventivo', ancho: 110),
                  if (ancho) const Col('Cumplimiento', ancho: 120),
                ],
                filas: filas.length,
                celdas: (n) {
                  final (:a, :i) = filas[n];
                  final total = i.preventivas + i.correctivas;
                  return [
                    celdaTexto(a.titulo, negrita: true),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          SizedBox(width: 48, child: celdaTexto(_pct(i.disponibilidad))),
                          Expanded(child: EntradaGrafica(ms: 800, builder: (v) => BarraValor(i.disponibilidad * v))),
                        ],
                      ),
                    ),
                    celdaTexto('${i.averias}', suave: i.averias == 0),
                    celdaTexto(_dias(i.mtbfDias), suave: i.mtbfDias == null),
                    celdaTexto(_horas(i.mttrHoras), suave: i.mttrHoras == null),
                    if (ancho) celdaTexto(total == 0 ? '—' : _pct(i.preventivas / total), suave: total == 0),
                    if (ancho) celdaTexto(_pct(i.cumplimiento), suave: i.cumplimiento == null),
                  ];
                },
                pie: pieTabla(filas.length, filas.length == 1 ? 'activo' : 'activos'),
              );
            },
          ),
        ),
      ],
    );
  }
}
