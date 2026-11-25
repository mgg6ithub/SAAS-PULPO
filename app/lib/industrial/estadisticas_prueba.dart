import 'dart:math';

import '../models.dart';
import '../rellenar.dart' show maquinasPrueba, componentesPrueba;
import '../store.dart';
import 'activo.dart';
import 'incidencia.dart';
import 'plan.dart';

/// Botón de prueba de Estadísticas (solo al desarrollar): cambia en memoria lo que hay por un año de datos
/// inventados (técnicos, activos, mantenimientos con su historial, incidencias y mediciones) para ver cómo quedan
/// las gráficas. No se guarda: al quitarlo, o al salir de Estadísticas, vuelve lo de antes.
class EstadisticasPrueba {
  static bool activa = false;
  static ({
    List<Trabajador> trabajadores,
    List<Activo> activos,
    List<PlanMantenimiento> planes,
    List<Incidencia> incidencias,
    List<Tarea> tareas,
    List<Tarea> subtareas,
  })? _antes;

  /// Mediciones inventadas por mantenimiento.
  static final mediciones = <String, List<(DateTime, double)>>{};

  static void poner() {
    if (activa) return;
    _antes = (
      trabajadores: store.trabajadores,
      activos: store.activos,
      planes: store.planes,
      incidencias: store.incidencias,
      tareas: store.tareas,
      subtareas: store.subtareas,
    );
    _generar();
    activa = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    store.notifyListeners();
  }

  static void quitar() {
    final a = _antes;
    if (!activa || a == null) return;
    store
      ..trabajadores = a.trabajadores
      ..activos = a.activos
      ..planes = a.planes
      ..incidencias = a.incidencias
      ..tareas = a.tareas
      ..subtareas = a.subtareas;
    mediciones.clear();
    _antes = null;
    activa = false;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    store.notifyListeners();
  }

  static void _generar() {
    final r = Random(11);
    final hoy_ = hoy();
    final ws = [
      for (final (i, (n, a)) in [
        ('Lucía', 'Martín'),
        ('Javier', 'Ortega'),
        ('Marta', 'Ruiz'),
        ('Iker', 'Etxeberria'),
        ('Pablo', 'Santos'),
        ('Ana', 'Gómez'),
      ].indexed)
        Trabajador(id: 'prueba-w$i', nombre: n, apellidos: a, color: i),
    ];
    final activos = <Activo>[];
    final planes = <PlanMantenimiento>[];
    final tareas = <Tarea>[];
    final incidencias = <Incidencia>[];
    const medidas = [('Vibración', 'mm/s', 0.0, 7.1, 3.2), ('Temperatura', 'ºC', 40.0, 85.0, 64.0), ('Presión', 'bar', 6.0, 9.0, 7.6)];
    const nombresPlan = ['Revisión general', 'Engrase', 'Cambio de filtros', 'Inspección eléctrica', 'Ajuste de correas'];
    for (final (i, (nombre, tag, desc)) in maquinasPrueba.take(6).indexed) {
      final raiz = Activo(id: 'prueba-a$i', nombre: nombre, tag: '$tag-0${i + 1}', descripcion: desc, horas: 800 + r.nextInt(4000).toDouble());
      activos.add(raiz);
      for (final (j, (cn, ct)) in componentesPrueba.skip(i % 4).take(2).indexed) {
        activos.add(Activo(id: 'prueba-a$i-$j', padreId: raiz.id, nombre: cn, tag: '$ct-0${i + 1}'));
      }
      for (var k = 0; k < 3; k++) {
        final cada = const [7, 14, 30, 60][r.nextInt(4)];
        final m = k == 0 && i < 4 ? medidas[i % medidas.length] : null;
        final w = ws[r.nextInt(ws.length)];
        final p = PlanMantenimiento(
          id: 'prueba-p$i-$k',
          activoId: k == 2 ? 'prueba-a$i-0' : raiz.id,
          nombre: m == null ? nombresPlan[(i + k) % nombresPlan.length] : 'Medición de ${m.$1.toLowerCase()}',
          cadaDias: cada,
          trabajadorId: w.id,
          medicionNombre: m?.$1 ?? '',
          medicionUnidad: m?.$2 ?? '',
          medicionMin: m?.$3,
          medicionMax: m?.$4,
        );
        // Un año de historial, con algo de holgura en cada visita.
        final historial = <DateTime>[];
        for (var d = masDias(hoy_, -365 + r.nextInt(cada)); d.isBefore(hoy_); d = masDias(d, cada + r.nextInt(3) - 1)) {
          if (r.nextDouble() > .08) historial.add(d);
        }
        p.ultimo = historial.lastOrNull;
        // Unos pocos, atrasados.
        final proximo = r.nextDouble() < .2 ? masDias(hoy_, -1 - r.nextInt(8)) : masDias(hoy_, 1 + r.nextInt(cada));
        p.proximo = proximo;
        planes.add(p);
        tareas.add(Tarea(
          id: 'prueba-t$i-$k',
          plantilla: false,
          activoId: p.activoId,
          planId: p.id,
          nombre: p.nombre,
          tipoMantenimiento: TipoMantenimiento.preventivo,
          trabajadorIds: [w.id],
          historial: historial,
          ultimo: p.ultimo,
          proximo: proximo,
          resultado: r.nextDouble() < .15 ? 1 : 0,
        ));
        if (m != null) {
          mediciones[p.id] = [
            for (final d in historial)
              (
                d.add(Duration(hours: 8 + r.nextInt(8))),
                double.parse((m.$5 + (r.nextDouble() - .5) * (m.$4 - m.$3) * (r.nextDouble() < .1 ? 1.3 : .45)).toStringAsFixed(1)),
              ),
          ];
        }
      }
    }
    // Correctivos hechos (reparaciones), para el reparto preventivo frente a correctivo.
    for (var k = 0; k < 18; k++) {
      final a = activos[r.nextInt(activos.length)];
      final d = masDias(hoy_, -r.nextInt(365));
      tareas.add(Tarea(
        id: 'prueba-c$k',
        plantilla: false,
        activoId: a.id,
        nombre: 'Reparación',
        tipoMantenimiento: r.nextBool() ? TipoMantenimiento.correctivoNoCritico : TipoMantenimiento.correctivoCritico,
        trabajadorIds: [ws[r.nextInt(ws.length)].id],
        historial: [d],
        ultimo: d,
        estado: EstadoTrabajo.realizado,
        activa: false,
      ));
    }
    const textos = ['Ruido extraño al arrancar', 'Fuga de aceite', 'Temperatura alta', 'No arranca', 'Vibración excesiva', 'Correa desgastada'];
    for (var k = 0; k < 46; k++) {
      final a = activos[r.nextInt(activos.length)];
      final creada = masDias(hoy_, -r.nextInt(365)).add(Duration(hours: 7 + r.nextInt(10)));
      final reciente = hoy_.difference(creada).inDays < 20;
      incidencias.add(Incidencia(
        id: 'prueba-i$k',
        activoId: a.id,
        tecnicoId: ws[r.nextInt(ws.length)].id,
        descripcion: textos[r.nextInt(textos.length)],
        gravedad: Gravedad.values[r.nextInt(3)],
        estado: reciente
            ? EstadoIncidencia.values[r.nextInt(2)]
            : (r.nextDouble() < .8 ? EstadoIncidencia.completada : EstadoIncidencia.desestimada),
        creada: creada,
        // Resueltas en unas horas o pocos días, para el MTTR y la disponibilidad.
        cerradaEl: reciente && r.nextBool() ? null : creada.add(Duration(hours: 2 + r.nextInt(70))),
      ));
    }
    store
      ..trabajadores = ws
      ..activos = activos
      ..planes = planes
      ..incidencias = incidencias
      ..tareas = tareas
      ..subtareas = [];
  }
}
