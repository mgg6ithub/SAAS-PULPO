import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'store.dart';
import 'marca.dart';

/// Planificador de rutas, primera versión ("el pulpo planifica").
///
/// Reglas, en este orden:
///  1. Se reparten primero las tareas más críticas y, a igual criticidad, las de franja más estrecha.
///  2. Cada tarea va a un técnico apto (competencias). Si ya tenía técnico, se respeta.
///  3. Se inserta en el hueco de su ruta que menos desplazamiento añade, respetando su franja
///     horaria y la jornada del técnico (8:00–17:00, saliendo de su punto de salida o del almacén).
///  4. Al final se mejora cada ruta (mover paradas, 2-opt) si baja el coste: viaje + retraso de
///     cada tarea pesado por su criticidad.
///  5. Lo que no cabe queda "Sin programar", con el motivo.
/// Los trabajos fijados van primero, con su técnico y a su hora exacta: no se mueven.
/// Los desplazamientos se estiman en línea recta (haversine) a una velocidad urbana media.

/// Almacén (punto de salida y vuelta): Bilbao centro.
const almacen = LatLng(43.2627, -2.9253);
const inicioJornada = 8 * 60, finJornada = 18 * 60;

/// Velocidad media urbana y factor de rodeo sobre la línea recta.
const _kmh = 28.0, _rodeo = 1.35;

/// De dónde sale y adónde vuelve un técnico: su punto de salida si está ubicado; si no, el almacén.
LatLng salidaDe(Trabajador w) =>
    w.salidaLat != null && w.salidaLng != null ? LatLng(w.salidaLat!, w.salidaLng!) : almacen;

/// Nombre del punto de salida, para las vistas («Almacén» o «Salida»).
String nombreSalida(Trabajador w) => w.salidaLat != null && w.salidaLng != null ? 'Salida' : 'Almacén';

double kmEntre(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b) / 1000 * _rodeo;
int minutosEntre(LatLng a, LatLng b) => (kmEntre(a, b) / _kmh * 60).ceil();

class Parada {
  final Tarea tarea;
  final LatLng punto;
  int llegada = 0, inicio = 0, viajeMin = 0;
  double km = 0;
  String razon = '';
  Parada(this.tarea, this.punto);
  int get fin => inicio + tarea.duracionMin;
}

class Ruta {
  final Trabajador trabajador;
  final List<Parada> paradas;
  Ruta(this.trabajador, this.paradas);

  double get km =>
      paradas.fold(0.0, (s, p) => s + p.km) + (paradas.isEmpty ? 0 : kmEntre(paradas.last.punto, salidaDe(trabajador)));
  int get minutosViaje => paradas.fold(0, (s, p) => s + p.viajeMin);
  int get fin => paradas.isEmpty ? inicioJornada : paradas.last.fin;
}

class Plan {
  final DateTime dia;
  final List<Ruta> rutas;
  final List<(Tarea, String)> sinProgramar;

  /// Cómo estaban las tareas antes de planificar, para deshacer.
  final Map<String, Tarea> antes;
  Plan(this.dia, this.rutas, this.sinProgramar, this.antes);
}

/// El plan aplicado ahora (lo dibuja el mapa) y si las rutas se ven por carretera o en línea recta.
final planActual = ValueNotifier<Plan?>(null);
final rutaPorCarretera = ValueNotifier<bool>(true);

/// Simula una ruta con las paradas en ese orden. Devuelve null si alguna no cabe.
List<Parada>? _simular(List<Parada> ps, LatLng salida) {
  var hora = inicioJornada;
  var donde = salida;
  for (final p in ps) {
    final viaje = minutosEntre(donde, p.punto);
    p
      ..viajeMin = viaje
      ..km = kmEntre(donde, p.punto)
      ..llegada = hora + viaje;
    final fija = _fija(p.tarea);
    final desde = fija ? p.tarea.inicioMin! : p.tarea.ventanaDesdeMin ?? inicioJornada;
    final hasta = fija ? p.tarea.inicioMin! : p.tarea.ventanaHastaMin ?? finJornada;
    p.inicio = max(p.llegada, desde); // si llega antes de su franja, espera
    if (p.inicio > hasta || p.fin > finJornada) return null;
    hora = p.fin;
    donde = p.punto;
  }
  if (hora + minutosEntre(donde, salida) > finJornada + 30) return null; // vuelta con algo de margen
  return ps;
}

/// Fijado de verdad: con hora y técnico.
bool _fija(Tarea t) => t.fijado && t.inicioMin != null && t.trabajadorIds.isNotEmpty;

/// Coste de una ruta: minutos de viaje + lo tarde que empieza cada tarea, pesado por su criticidad
/// (una crítica a las 15:00 cuesta mucho más que una rutinaria a las 15:00). Null si no cabe.
double? _coste(List<Parada> ps, LatLng salida) {
  final sim = _simular([for (final p in ps) Parada(p.tarea, p.punto)], salida);
  if (sim == null) return null;
  return _viaje(ps, salida) +
      sim.fold(0.0, (s, p) => s + (p.inicio - inicioJornada) / 60 * p.tarea.criticidad.peso * 6);
}

int _viaje(List<Parada> ps, LatLng salida) {
  var total = 0;
  var donde = salida;
  for (final p in ps) {
    total += minutosEntre(donde, p.punto);
    donde = p.punto;
  }
  return total + minutosEntre(donde, salida);
}

/// Planifica las tareas de [dia] (las que tienen ubicación) entre los técnicos activos.
Plan planificar(DateTime dia) {
  final tareas = store
      .tareasDelDia(dia)
      .where((t) => !t.hechaEl(dia) && store.cliente(t.clienteId)?.ubicado == true)
      .toList();
  final antes = {for (final t in tareas) t.id: t.copia()};
  final ws = store.trabajadores.where((w) => w.activo && w.estadoHoy != EstadoHoy.ausente).toList();
  final rutas = {for (final w in ws) w.id: <Parada>[]};
  final sinProgramar = <(Tarea, String)>[];

  // 1. Orden: criticidad, después franja más estrecha.
  int anchura(Tarea t) => (t.ventanaHastaMin ?? finJornada) - (t.ventanaDesdeMin ?? inicioJornada);
  tareas.sort((a, b) {
    if (_fija(a) != _fija(b)) return _fija(a) ? -1 : 1;
    final c = b.criticidad.peso - a.criticidad.peso;
    return c != 0 ? c : anchura(a) - anchura(b);
  });

  for (final t in tareas) {
    final c = store.cliente(t.clienteId)!;
    final punto = LatLng(c.lat!, c.lng!);
    // 2. Candidatos: el técnico que ya tenía, o los aptos.
    final fijo = t.trabajadorIds.isNotEmpty ? ws.where((w) => t.trabajadorIds.contains(w.id)).toList() : <Trabajador>[];
    final candidatos = fijo.isNotEmpty ? fijo : ws.where((w) => store.esApto(w, t)).toList();
    if (candidatos.isEmpty) {
      sinProgramar.add((t, 'Ningún técnico disponible tiene las competencias necesarias'));
      continue;
    }
    // 3. Mejor hueco: el que menos desplazamiento añade (y, si es crítica, cuanto antes mejor).
    (String, int, double)? mejor;
    for (final w in candidatos) {
      final r = rutas[w.id]!;
      final base = _coste(r, salidaDe(w)) ?? 0;
      for (var i = 0; i <= r.length; i++) {
        final prueba = [...r]..insert(i, Parada(t, punto));
        final c = _coste(prueba, salidaDe(w));
        if (c == null) continue;
        final coste = c - base;
        if (mejor == null || coste < mejor.$3) mejor = (w.id, i, coste);
      }
    }
    if (mejor == null) {
      sinProgramar.add((
        t,
        _fija(t)
            ? 'Fijado a las ${hhmm(t.inicioMin!)}, pero no se llega a tiempo con los demás fijados'
            : t.ventanaDesdeMin != null
            ? 'No cabe en su franja (${hhmm(t.ventanaDesdeMin!)}–${hhmm(t.ventanaHastaMin!)}) con los demás'
            : 'No cabe en la jornada (${hhmm(inicioJornada)}–${hhmm(finJornada)}) de ningún técnico apto',
      ));
      continue;
    }
    rutas[mejor.$1]!.insert(mejor.$2, Parada(t, punto));
  }

  // 4. Mejora local: mover una parada a otro sitio o invertir un tramo (2-opt) si baja el coste
  //    (menos viaje y las críticas antes) y todo sigue cabiendo.
  for (final id in rutas.keys) {
    final salida = salidaDe(ws.firstWhere((w) => w.id == id));
    var r = rutas[id]!;
    var actual = _coste(r, salida) ?? double.infinity;
    var mejora = true;
    while (mejora) {
      mejora = false;
      final vecinos = <List<Parada>>[
        for (var i = 0; i < r.length; i++)
          for (var j = 0; j < r.length; j++)
            if (i != j) ([...r]..removeAt(i))..insert(j, r[i]),
        for (var i = 0; i < r.length - 1; i++)
          for (var j = i + 1; j < r.length; j++)
            [...r.sublist(0, i), ...r.sublist(i, j + 1).reversed, ...r.sublist(j + 1)],
      ];
      for (final v in vecinos) {
        final c = _coste(v, salida);
        if (c != null && c < actual - .01) {
          r = v;
          actual = c;
          mejora = true;
          break;
        }
      }
    }
    rutas[id] = _simular(r, salida)!;
  }

  // Razones de cada parada (para la vista "Por qué esta ruta").
  for (final w in ws) {
    final r = rutas[w.id]!;
    for (final (i, p) in r.indexed) {
      final t = p.tarea;
      final motivos = <String>[
        if (_fija(t))
          'Fijado a las ${hhmm(t.inicioMin!)}: no se mueve'
        else if (antes[t.id]!.trabajadorIds.contains(w.id))
          'Ya era de ${w.nombreCompleto}'
        else
          'Técnico apto con hueco',
        if (t.criticidad.peso >= 4) '${t.criticidad.etiqueta}: va lo antes posible',
        if (t.ventanaDesdeMin != null) 'Franja ${hhmm(t.ventanaDesdeMin!)}–${hhmm(t.ventanaHastaMin!)}',
        if (p.inicio > p.llegada) 'Espera ${p.inicio - p.llegada} min a que abra su franja',
        i == 0
            ? 'Sale ${nombreSalida(w) == 'Salida' ? 'de su punto de salida' : 'del almacén'}: ${p.km.toStringAsFixed(1)} km'
            : 'A ${p.km.toStringAsFixed(1)} km de la anterior (la más cercana que cabe)',
      ];
      p.razon = motivos.join(' · ');
    }
  }

  return Plan(dia, [for (final w in ws) Ruta(w, rutas[w.id]!)], sinProgramar, antes);
}

/// Ruta hecha a mano: [w] visita [orden] en ese orden, saliendo de su punto de salida. Lo que ya no cabe
/// en la jornada (o en su franja) queda «Sin programar». Se aplica con [aplicar] y se deshace igual.
Plan rutaManual(DateTime dia, Trabajador w, List<Tarea> orden) {
  final salida = salidaDe(w);
  final paradas = <Parada>[];
  final sinProgramar = <(Tarea, String)>[];
  for (final t in orden) {
    final c = store.cliente(t.clienteId);
    if (c == null || !c.ubicado) {
      sinProgramar.add((t, m('Su cliente no está ubicado en el mapa')));
      continue;
    }
    final prueba = [...paradas, Parada(t, LatLng(c.lat!, c.lng!))];
    if (_simular(prueba, salida) == null) {
      sinProgramar.add((t, 'Ya no cabe en la jornada (${hhmm(inicioJornada)}–${hhmm(finJornada)}) en este orden'));
    } else {
      paradas.add(prueba.last);
    }
  }
  _simular(paradas, salida);
  for (final (i, p) in paradas.indexed) {
    p.razon = i == 0
        ? 'Elegido a mano: primera parada (${p.km.toStringAsFixed(1)} km desde la salida)'
        : 'Elegido a mano: parada ${i + 1} (${p.km.toStringAsFixed(1)} km desde la anterior)';
  }
  return Plan(dia, [Ruta(w, paradas)], sinProgramar, {for (final t in orden) t.id: t.copia()});
}

/// Guarda el plan en las tareas: técnico, hora de inicio y color del técnico.
void aplicar(Plan plan) {
  for (final r in plan.rutas) {
    for (final p in r.paradas) {
      final c = p.tarea.copia()
        ..trabajadorIds = [r.trabajador.id]
        ..inicioMin = p.inicio
        ..color = _colorDe(r.trabajador);
      store.guardarTarea(c);
    }
  }
  planActual.value = plan;
}

/// Deja las tareas como estaban antes de planificar.
void deshacer() {
  final plan = planActual.value;
  if (plan == null) return;
  for (final t in plan.antes.values) {
    store.guardarTarea(t.copia());
  }
  planActual.value = null;
}

int _colorDe(Trabajador w) =>
    const [0xFF7C3AED, 0xFF2563EB, 0xFF16A34A, 0xFFEA580C, 0xFFDB2777, 0xFF0891B2, 0xFFCA8A04, 0xFF4F46E5][w.color % 8];

// ── Geometría por carretera (OSRM, gratis y sin clave) ──

final _cache = <String, List<LatLng>>{};

/// Trazado por calles de una ruta (salida → paradas → salida). Null si no hay red.
Future<List<LatLng>?> trazadoCarretera(Ruta r) async {
  if (r.paradas.isEmpty) return null;
  final salida = salidaDe(r.trabajador);
  final puntos = [salida, ...r.paradas.map((p) => p.punto), salida];
  final clave = puntos.map((p) => '${p.longitude},${p.latitude}').join(';');
  if (_cache[clave] case final c?) return c;
  try {
    final res = await http
        .get(Uri.parse('https://router.project-osrm.org/route/v1/driving/$clave?overview=full&geometries=geojson'))
        .timeout(const Duration(seconds: 10));
    final coords = (jsonDecode(res.body)['routes'][0]['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    return _cache[clave] = coords;
  } catch (_) {
    return null;
  }
}
