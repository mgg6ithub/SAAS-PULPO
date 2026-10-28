import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart' show DateUtils;

import '../models.dart';

/// Una visita, incluida la parte que continúa después de medianoche.
class VisitaCalendario {
  final Tarea tarea;
  final DateTime dia;
  final int? inicio, fin;
  final bool hecha;
  const VisitaCalendario(this.tarea, this.dia, this.inicio, this.fin, this.hecha);
}

/// Indexa una sola vez el periodo. Los atrasados conservan su fecha real.
Map<DateTime, List<VisitaCalendario>> visitasCalendario(
  Iterable<Tarea> tareas,
  DateTime desde,
  DateTime hasta,
  bool Function(Tarea, DateTime) pasa,
) {
  final resultado = <DateTime, List<VisitaCalendario>>{};
  void agregar(Tarea t, DateTime fecha, bool hecha) {
    final base = DateUtils.dateOnly(fecha);
    final inicio = t.inicioMin;
    final fin = inicio == null ? null : inicio + max(1, t.duracionMin);
    final dias = fin == null ? 1 : ((fin - 1) ~/ 1440) + 1;
    for (var i = 0; i < dias; i++) {
      final d = DateTime(base.year, base.month, base.day + i);
      if (d.isBefore(desde) || d.isAfter(hasta) || !pasa(t, d)) continue;
      (resultado[d] ??= []).add(
        VisitaCalendario(
          t,
          d,
          inicio == null ? null : max(0, inicio - i * 1440),
          fin == null ? null : min(1440, fin - i * 1440).toInt(),
          hecha,
        ),
      );
    }
  }

  for (final t in tareas) {
    if (t.esPlantilla || !t.activa) continue;
    final hechos = {...t.historial.map(DateUtils.dateOnly), if (t.ultimo != null) DateUtils.dateOnly(t.ultimo!)};
    if (t.proximo != null && !hechos.contains(DateUtils.dateOnly(t.proximo!))) agregar(t, t.proximo!, false);
    for (final d in hechos) {
      if (!d.isAfter(hasta)) {
        agregar(t, d, true);
      }
    }
  }
  for (final lista in resultado.values) {
    lista.sort((a, b) => (a.inicio ?? -1).compareTo(b.inicio ?? -1));
  }
  return resultado;
}

class GrupoCalendario {
  final List<(VisitaCalendario, int)> posiciones = [];
  int inicio, fin, carriles = 0;
  GrupoCalendario(this.inicio, this.fin);
}

/// Carriles reutilizables en O(n log n), por grupos de intervalos conectados.
/// El mínimo visual impide que dos trabajos cortos se tapen al dibujarlos.
List<GrupoCalendario> distribuirVisitas(List<VisitaCalendario> visitas, {int minimoMin = 1}) {
  final orden = visitas.where((v) => v.inicio != null).toList()
    ..sort((a, b) {
      final c = a.inicio!.compareTo(b.inicio!);
      return c != 0 ? c : a.tarea.id.compareTo(b.tarea.id);
    });
  final grupos = <GrupoCalendario>[];
  final ocupados = SplayTreeMap<int, List<int>>();
  for (final v in orden) {
    final fin = min(1440, max(v.fin!, v.inicio! + minimoMin));
    if (grupos.isEmpty || v.inicio! >= grupos.last.fin) {
      grupos.add(GrupoCalendario(v.inicio!, fin));
      ocupados.clear();
    }
    final g = grupos.last;
    int carril;
    if (ocupados.isNotEmpty && ocupados.firstKey()! <= v.inicio!) {
      final primero = ocupados.firstKey()!;
      final libres = ocupados[primero]!;
      carril = libres.removeLast();
      if (libres.isEmpty) ocupados.remove(primero);
    } else {
      carril = g.carriles++;
    }
    (ocupados[fin] ??= []).add(carril);
    g.posiciones.add((v, carril));
    g.fin = max(g.fin, fin);
  }
  return grupos;
}
