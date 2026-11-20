import 'dart:math';

import 'package:flutter/material.dart' show DateUtils;

import '../informes.dart';
import '../models.dart';
import '../store.dart';
import 'incidencia.dart';
import 'plan.dart';
import 'simulacion_dominion.dart';

/// Mediciones que se añaden a los mantenimientos cuyo nombre contiene la clave:
/// (qué, unidad, mínimo, máximo, valor normal).
const _medidas = <String, (String, String, double?, double?, double)>{
  'Vibraciones': ('Vibración', 'mm/s', null, 7.1, 3.6),
  'Revisión de la bomba': ('Presión de descarga', 'bar', 3.0, 6.0, 4.6),
  'Limpieza del quemador': ('Temperatura de llama', '°C', null, 850, 785),
  'Cierre mecánico': ('Temperatura de cojinetes', '°C', null, 80, 63),
  'Revisión de frenos': ('Espesor de pastillas', 'mm', 4, null, 9),
};

const _notas = [
  'Revisado según procedimiento. Todo correcto.',
  'Hecho. Limpieza y ajuste; sin desgaste apreciable.',
  'Realizado sin incidencias. Se deja la zona limpia.',
  'Cambiadas juntas por precaución. Funciona bien.',
  'Revisado y engrasado. Próxima revisión en plazo.',
];

const _problemas = [
  'Ruido anómalo al arrancar; hay que vigilarlo.',
  'Pequeña fuga de aceite en la junta; apretada, conviene cambiarla.',
  'Correa con grietas; pedir una de repuesto.',
  'Temperatura algo alta al final del turno.',
];

const _avisos = [
  ('Fuga de aceite bajo el equipo', Gravedad.media),
  ('Ruido metálico al girar', Gravedad.media),
  ('No arranca a la primera', Gravedad.grave),
  ('Vibración fuerte a plena carga', Gravedad.grave),
  ('Testigo de presión encendido', Gravedad.media),
  ('Manguera con roce y desgaste', Gravedad.media),
];

/// Simulación «Historial de trabajo»: como si la empresa llevara [meses] meses usando Pultec. Sobre los activos que
/// haya (si no hay, crea los de Dominion): tres técnicos, mediciones en algunos mantenimientos, las OT hechas de
/// cada mantenimiento con su parte (resultado, notas y valor medido; algunos fuera de límites o con incidencia) e
/// incidencias comunicadas por los técnicos en todos los estados (abiertas, con OT, completadas y desestimadas).
/// Con sesión, los partes se suben a la base, que crea sola las incidencias de los partes con problema.
Future<String> simularHistorial({int meses = 6}) async {
  final rnd = Random();
  if (store.planes.isEmpty) crearSimulacionDominion();

  // ── Técnicos ──
  final tecnicos = store.trabajadores.where((w) => w.activo).toList();
  for (final (nombre, apellidos, especialidad) in [
    ('Ana', 'Ruiz', 'Mecánica'),
    ('Luis', 'Gómez', 'Eléctrica'),
    ('Marta', 'Sanz', 'Bombas y bombeo'),
  ].take(max(0, 3 - tecnicos.length))) {
    final w = Trabajador(id: store.nuevoId(), nombre: nombre, apellidos: apellidos, competencias: [especialidad]);
    store.guardarTrabajador(w);
    tecnicos.add(w);
  }

  // ── Mediciones en algunos mantenimientos ──
  for (final p in store.planes.where((p) => !p.conMedicion)) {
    for (final MapEntry(key: clave, value: (nombre, unidad, minimo, maximo, _)) in _medidas.entries) {
      if (!p.nombre.contains(clave)) continue;
      store.guardarPlan(p
        ..medicionNombre = nombre
        ..medicionUnidad = unidad
        ..medicionMin = minimo
        ..medicionMax = maximo);
    }
  }

  // ── OT hechas de cada mantenimiento, cada [cadaDias], desde hace [meses] meses ──
  final inicio = masDias(hoy(), -30 * meses);
  final hechas = <(Tarea, DateTime, PlanMantenimiento, Trabajador)>[];
  for (final p in store.planes.where((p) => p.activa && p.cadaDias != null).toList()) {
    var d = masDias(inicio, rnd.nextInt(p.cadaDias!));
    DateTime? ultimo;
    while (d.isBefore(masDias(hoy(), -1))) {
      final w = tecnicos[rnd.nextInt(tecnicos.length)];
      // A veces se hace con uno o dos días de retraso.
      final dia = masDias(d, rnd.nextInt(10) < 7 ? 0 : 1 + rnd.nextInt(2));
      final t = p.ot(store.nuevoId())
        ..estado = EstadoTrabajo.realizado
        ..proximo = d
        ..ultimo = dia
        ..trabajadorIds = [w.id]
        ..ejecutadoPor = w.id;
      store.guardarTarea(t);
      hechas.add((t, dia, p, w));
      ultimo = dia;
      d = masDias(d, p.cadaDias!);
    }
    if (ultimo != null && (p.ultimo == null || ultimo.isAfter(p.ultimo!))) store.guardarPlan(p..ultimo = ultimo);
  }

  // ── Incidencias comunicadas por los técnicos (unas dos al mes), en todos los estados ──
  final activos = store.activos.where((a) => a.activo).toList();
  final avisos = <Incidencia>[];
  for (var n = 0; n < meses * 2 && activos.isNotEmpty; n++) {
    // Las dos primeras, recientes (una abierta y otra con su OT pendiente); el resto, repartidas en el tiempo.
    final dias = n < 2 ? rnd.nextInt(5) : 8 + rnd.nextInt(30 * meses - 8);
    final creada = masDias(hoy(), -dias).add(Duration(hours: 8 + rnd.nextInt(9), minutes: rnd.nextInt(60)));
    final (texto, gravedad) = _avisos[rnd.nextInt(_avisos.length)];
    final a = activos[rnd.nextInt(activos.length)];
    final w = tecnicos[rnd.nextInt(tecnicos.length)];
    final x = Incidencia(id: store.nuevoId(), activoId: a.id, descripcion: texto, gravedad: gravedad, tecnicoId: w.id,
      creada: creada);
    // Lo reciente sigue abierto o con su OT pendiente; lo antiguo, resuelto con OT o desestimado.
    if (dias > 7) {
      if (rnd.nextInt(4) == 0) {
        x
          ..estado = EstadoIncidencia.desestimada
          ..cerradaEl = masDias(creada, 1);
      } else {
        final dia = DateUtils.dateOnly(masDias(creada, 1 + rnd.nextInt(3)));
        final ot = Tarea(id: store.nuevoId(), nombre: 'Reparar ${a.nombre.isEmpty ? a.tag : a.nombre}', descripcion: texto,
          activoId: a.id, plantilla: false, tipoMantenimiento: gravedad.tipo, proximo: dia, ultimo: dia,
          periodicidad: Periodicidad.unica, criticidad: Criticidad.rutinaria, trabajadorIds: [w.id], ejecutadoPor: w.id)
          ..estado = EstadoTrabajo.realizado;
        store.guardarTarea(ot);
        hechas.add((ot, dia, PlanMantenimiento(id: '', activoId: a.id), w));
        x
          ..trabajoId = ot.id
          ..estado = EstadoIncidencia.completada
          ..cerradaEl = dia.add(const Duration(hours: 13));
      }
    } else if (n == 1) {
      final ot = Tarea(id: store.nuevoId(), nombre: 'Reparar ${a.nombre.isEmpty ? a.tag : a.nombre}', descripcion: texto,
        activoId: a.id, plantilla: false, tipoMantenimiento: gravedad.tipo, proximo: masDias(hoy(), rnd.nextInt(3)),
        periodicidad: Periodicidad.unica, criticidad: Criticidad.rutinaria, trabajadorIds: [w.id]);
      store.guardarTarea(ot);
      x
        ..trabajoId = ot.id
        ..estado = EstadoIncidencia.conOt;
    }
    store.guardarIncidencia(x);
    avisos.add(x);
  }

  // ── Partes de lo hecho: resultado, notas y valor medido ──
  final nube = store.nube;
  await nube?.guardado;
  var partes = 0, fueraDeLimites = 0, conProblema = 0;
  for (final (t, dia, p, w) in hechas) {
    final problema = p.id.isNotEmpty && rnd.nextInt(100) < 8;
    double? valor;
    if (p.conMedicion) {
      final normal = _medidas.entries.firstWhere((e) => p.nombre.contains(e.key)).value.$5;
      final fuera = rnd.nextInt(100) < 7;
      valor = fuera
          ? (p.medicionMax != null ? p.medicionMax! * (1.05 + rnd.nextDouble() * .1) : p.medicionMin! * (.6 + rnd.nextDouble() * .2))
          : normal * (.9 + rnd.nextDouble() * .2);
      valor = (valor * 10).roundToDouble() / 10;
      if (fuera) fueraDeLimites++;
    }
    if (problema) conProblema++;
    final i = Informe(
      trabajoId: t.id,
      trabajadorId: w.id,
      resultado: problema ? 1 : 0,
      notas: problema ? _problemas[rnd.nextInt(_problemas.length)] : _notas[rnd.nextInt(_notas.length)],
      valor: valor,
      cuando: dia.add(Duration(hours: 9 + rnd.nextInt(8), minutes: rnd.nextInt(60))),
    );
    if (nube != null) {
      // Directo a la base (sin mandar el parte por correo); la base deja las incidencias de los partes con problema.
      await nube.crearInforme(i, const [], null);
    } else {
      await informes.crear(i);
      if (problema) {
        store.guardarIncidencia(Incidencia(id: store.nuevoId(), activoId: t.activoId!, tecnicoId: w.id,
          origenTrabajoId: t.id, descripcion: 'Con incidencias en «${t.nombre}»: ${i.notas}', creada: i.cuando));
      }
    }
    if (problema) store.guardarTarea(t..resultado = 1);
    partes++;
  }
  await nube?.guardado;
  if (nube != null) await store.cargarDesdeNube(nube);

  // Las incidencias que dejaron los partes (con problema o fuera de límites) ya se revisaron si son antiguas:
  // la mitad se arregló con su OT y el resto se desestimó.
  final deLosPartes = {for (final h in hechas) h.$1.id};
  for (final x in store.incidencias.where((x) =>
      deLosPartes.contains(x.origenTrabajoId) && x.estado == EstadoIncidencia.abierta &&
      x.creada.isBefore(masDias(hoy(), -10))).toList()) {
    if (rnd.nextBool()) {
      store.guardarIncidencia(x.copia()
        ..estado = EstadoIncidencia.desestimada
        ..cerradaEl = x.creada.add(const Duration(days: 1)));
      continue;
    }
    final a = store.activo(x.activoId);
    final w = tecnicos[rnd.nextInt(tecnicos.length)];
    final dia = DateUtils.dateOnly(masDias(x.creada, 2));
    final ot = Tarea(id: store.nuevoId(), nombre: 'Reparar ${a == null ? 'activo' : a.nombre.isEmpty ? a.tag : a.nombre}',
      descripcion: x.descripcion, activoId: x.activoId, plantilla: false, tipoMantenimiento: x.gravedad.tipo,
      proximo: dia, ultimo: dia, periodicidad: Periodicidad.unica, criticidad: Criticidad.rutinaria,
      trabajadorIds: [w.id], ejecutadoPor: w.id)
      ..estado = EstadoTrabajo.realizado;
    store.guardarTarea(ot);
    store.guardarIncidencia(x.copia()
      ..trabajoId = ot.id
      ..estado = EstadoIncidencia.completada
      ..cerradaEl = dia.add(const Duration(hours: 13)));
  }
  await nube?.guardado;
  return 'Historial de $meses meses: $partes partes ($conProblema con incidencia, $fueraDeLimites mediciones fuera de '
      'límites) y ${avisos.length} incidencias comunicadas.';
}
