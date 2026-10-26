import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart' show competencias;

/// Datos del prototipo. Se guardan en el navegador; más adelante, Supabase.
class Store extends ChangeNotifier {
  static const _clave = 'pulpo_v2';
  static const _respaldo = 'pulpo_v2_respaldo';

  /// Hay datos de ejemplo cargados; los reales esperan en el respaldo.
  bool demo = false;

  List<Cliente> clientes = [];
  List<Trabajador> trabajadores = [];
  List<Tarea> tareas = [];
  SharedPreferences? _prefs;

  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs!.getString(_clave);
    if (s == null) {
      _inicial();
      _guardar();
    } else {
      final j = jsonDecode(s) as Map<String, dynamic>;
      clientes = [for (final x in j['clientes'] as List) Cliente.fromJson(x)];
      trabajadores = [for (final x in j['trabajadores'] as List) Trabajador.fromJson(x)];
      tareas = [for (final x in j['tareas'] as List) Tarea.fromJson(x)];
      // Datos de ejemplo cargados antes de existir la marca: se reconocen por sus ids.
      demo = (j['demo'] as bool? ?? false) || _hayDemo;
      usoPlantillas = List<String>.from(j['usoPlantillas'] as List? ?? []);
      // Clientes de ejemplo creados antes de existir las coordenadas: se ubican con las de la tabla.
      for (final c in clientes) {
        final g = _coordsDemo[c.id];
        if (g != null && !c.ubicado) {
          c
            ..lat = g.$1
            ..lng = g.$2;
        }
      }
    }
    notifyListeners();
  }

  void _guardar() => _prefs?.setString(
    _clave,
    jsonEncode({
      'clientes': [for (final x in clientes) x.toJson()],
      'trabajadores': [for (final x in trabajadores) x.toJson()],
      'tareas': [for (final x in tareas) x.toJson()],
      'demo': demo,
      'usoPlantillas': usoPlantillas,
    }),
  );

  void _cambio() {
    _guardar();
    notifyListeners();
  }

  String nuevoId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ── Clientes ──
  Cliente? cliente(String? id) {
    for (final c in clientes) {
      if (c.id == id) return c;
    }
    return null;
  }

  void guardarCliente(Cliente c) {
    _poner(clientes, c, (x) => x.id == c.id);
    _cambio();
  }

  void borrarCliente(String id) {
    clientes.removeWhere((c) => c.id == id);
    tareas.removeWhere((t) => t.clienteId == id);
    _cambio();
  }

  List<Tarea> tareasDe(String clienteId) => tareas.where((t) => t.clienteId == clienteId).toList();

  // ── Trabajadores ──
  Trabajador? trabajador(String id) {
    for (final w in trabajadores) {
      if (w.id == id) return w;
    }
    return null;
  }

  void guardarTrabajador(Trabajador w) {
    _poner(trabajadores, w, (x) => x.id == w.id);
    _cambio();
  }

  void borrarTrabajador(String id) {
    trabajadores.removeWhere((w) => w.id == id);
    for (final t in tareas) {
      t.trabajadorIds.remove(id);
    }
    _cambio();
  }

  // ── Tareas ──
  List<Tarea> get plantillas => tareas.where((t) => t.esPlantilla).toList();

  /// Plantillas usadas, de la más reciente a la más antigua (lista LRU).
  List<String> usoPlantillas = [];

  /// Plantillas ordenadas por uso reciente; las nunca usadas, después, en su orden.
  List<Tarea> get plantillasPorUso {
    final ps = plantillas;
    int pos(Tarea p) {
      final i = usoPlantillas.indexOf(p.id);
      return i < 0 ? 1000 + ps.indexOf(p) : i;
    }

    return ps..sort((a, b) => pos(a) - pos(b));
  }

  /// Marca la plantilla como la última usada: pasa a ser la primera de la lista.
  void usarPlantilla(String id) {
    usoPlantillas
      ..remove(id)
      ..insert(0, id);
    _cambio();
  }

  /// Última tarea creada (id y momento), para animar su aparición en el itinerario.
  String? recienId;
  DateTime? recienEn;
  bool esRecien(String id) =>
      id == recienId && recienEn != null && DateTime.now().difference(recienEn!).inMilliseconds < 2500;

  void guardarTarea(Tarea t) {
    if (!tareas.any((x) => x.id == t.id)) {
      recienId = t.id;
      recienEn = DateTime.now();
    }
    _poner(tareas, t, (x) => x.id == t.id);
    _cambio();
  }

  void borrarTarea(String id) {
    tareas.removeWhere((t) => t.id == id);
    _cambio();
  }

  /// El mantenimiento se ha hecho hoy: se calcula el siguiente.
  /// Cómo estaba cada tarea antes de marcarla hecha, para poder desmarcarla (durante la sesión).
  final _antesDeHecha = <String, (DateTime?, DateTime?, EstadoMaquina)>{};

  bool puedeDesmarcar(Tarea t) => _antesDeHecha.containsKey(t.id);

  void desmarcarHecha(Tarea t) {
    final antes = _antesDeHecha.remove(t.id);
    if (antes == null) return;
    t
      ..ultimo = antes.$1
      ..proximo = antes.$2
      ..estadoMaquina = antes.$3;
    _cambio();
  }

  void marcarHecha(Tarea t) {
    _antesDeHecha[t.id] = (t.ultimo, t.proximo, t.estadoMaquina);
    t.ultimo = hoy();
    // Una tarea única, al hacerse, ya no tiene próxima.
    t.proximo = t.periodicidad.repite ? masDias(hoy(), t.periodicidad.dias) : null;
    if (t.estadoMaquina == EstadoMaquina.revision) t.estadoMaquina = EstadoMaquina.operativa;
    _cambio();
  }

  /// Tareas de un día. Pasado: lo que se hizo ese día. Hoy: lo hecho hoy, lo que toca
  /// y lo vencido. Futuro: lo que toca ese día.
  List<Tarea> tareasDelDia(DateTime dia) {
    final n = diasHasta(dia);
    bool mismo(DateTime? d) => d != null && DateUtils.isSameDay(d, dia);
    return tareas.where((t) {
      if (t.esPlantilla || !t.activa) return false;
      if (n < 0) return mismo(t.ultimo);
      if (n == 0) return mismo(t.ultimo) || (t.proximo != null && diasHasta(t.proximo!) <= 0);
      return mismo(t.proximo);
    }).toList();
  }

  /// Tareas de [trabajadorId] que chocan con [t]: mismo día y horas que se pisan,
  /// contando el retraso medio de cada una. Sin día u hora no se puede saber: no choca.
  List<Tarea> solapes(Tarea t, String trabajadorId) {
    if (t.proximo == null || t.inicioMin == null) return [];
    return tareas.where((o) {
      if (o.id == t.id || o.esPlantilla || !o.activa || !o.trabajadorIds.contains(trabajadorId)) return false;
      if (o.proximo == null || o.inicioMin == null || !DateUtils.isSameDay(o.proximo, t.proximo)) return false;
      return t.inicioMin! < o.finConMargenMin! && o.inicioMin! < t.finConMargenMin!;
    }).toList();
  }

  void asignar(Tarea t, String trabajadorId) {
    if (!t.trabajadorIds.contains(trabajadorId)) t.trabajadorIds.add(trabajadorId);
    _cambio();
  }

  void desasignar(Tarea t, String trabajadorId) {
    t.trabajadorIds.remove(trabajadorId);
    _cambio();
  }

  /// El "pulpo mágico": asigna el mejor trabajador a las tareas que no tienen.
  /// Devuelve cuántas ha organizado.
  int automatizar(List<Tarea> lista) {
    var n = 0;
    for (final t in lista) {
      if (t.trabajadorIds.isNotEmpty) continue;
      final m = mejorPara(t);
      if (m == null) continue;
      t.trabajadorIds = [m.id];
      n++;
    }
    if (n > 0) _cambio();
    return n;
  }

  /// Competencias de la tarea que le faltan al trabajador.
  List<String> faltan(Trabajador w, Tarea t) => t.competencias.where((c) => !w.competencias.contains(c)).toList();

  bool esApto(Trabajador w, Tarea t) => w.activo && faltan(w, t).isEmpty;

  /// Apto y disponible hoy con menos tareas asignadas. Primer paso de la automatización.
  Trabajador? mejorPara(Tarea t) {
    final aptos = trabajadores.where((w) => esApto(w, t)).toList();
    if (aptos.isEmpty) return null;
    int carga(Trabajador w) => tareas.where((x) => x.trabajadorIds.contains(w.id)).length;
    aptos.sort((a, b) {
      final d = (a.estadoHoy == EstadoHoy.disponible ? 0 : 1) - (b.estadoHoy == EstadoHoy.disponible ? 0 : 1);
      return d != 0 ? d : carga(a) - carga(b);
    });
    return aptos.first;
  }

  void _poner<T>(List<T> lista, T x, bool Function(T) igual) {
    final i = lista.indexWhere(igual);
    if (i < 0) {
      lista.add(x);
    } else {
      lista[i] = x;
    }
  }

  void restablecer() {
    _inicial();
    _cambio();
  }

  /// Rellena la cuenta con una empresa de ejemplo (clientes, equipo y mantenimientos
  /// repartidos alrededor de hoy) para ver la app funcionando.
  /// Datos para probar rutas: 2 trabajadores (azul y verde) y 10 tareas de hoy por Bilbao
  /// y alrededores, 5 para cada uno, todas a las 9:00 para que el planificador las ordene.
  void cargarDemoRutas() {
    if (!demo) _prefs?.setString(_respaldo, _prefs?.getString(_clave) ?? '');
    demo = true;
    _inicial();
    trabajadores = [
      Trabajador(id: 'w10', nombre: 'Trabajador', apellidos: '1', color: 1, competencias: [...competencias]),
      Trabajador(id: 'w11', nombre: 'Trabajador', apellidos: '2', color: 2, competencias: [...competencias]),
    ];
    // Tareas largas y algunas con franja de tarde: el día queda repartido de 8:00 a ~18:00.
    const sitios = [
      ('Casco Viejo', 'Calle Somera 12', 43.2590, -2.9230, 'Ascensor', Criticidad.critica, 90, null),
      ('Indautxu', 'Alameda Urquijo 40', 43.2615, -2.9395, 'Caldera', Criticidad.media, 120, null),
      (
        'Deusto',
        'Avenida Lehendakari Aguirre 20',
        43.2710,
        -2.9460,
        'Contra incendios',
        Criticidad.alta,
        60,
        (15 * 60, 17 * 60),
      ),
      ('Santutxu', 'Calle Santutxu 30', 43.2545, -2.9135, 'Limpieza', Criticidad.rutinaria, 90, (16 * 60, 18 * 60)),
      ('Basurto', 'Avenida Montevideo 18', 43.2620, -2.9575, 'Climatización', Criticidad.alta, 120, null),
      ('Zorrotza', 'Calle Fuente 5', 43.2770, -2.9710, 'Electricidad', Criticidad.media, 90, (13 * 60, 15 * 60)),
      ('Barakaldo', 'Calle Elcano 4', 43.2960, -2.9900, 'Ascensor', Criticidad.critica, 90, null),
      (
        'Leioa',
        'Avenida Iparraguirre 50',
        43.3270,
        -2.9870,
        'Jardinería',
        Criticidad.rutinaria,
        120,
        (8 * 60, 11 * 60),
      ),
      (
        'Galdakao',
        'Calle Juan Bautista Uriarte 10',
        43.2310,
        -2.8430,
        'Caldera',
        Criticidad.media,
        90,
        (14 * 60, 17 * 60),
      ),
      ('Etxebarri', 'Calle Doctor Fleming 2', 43.2470, -2.8920, 'Fontanería', Criticidad.alta, 60, null),
    ];
    clientes = [
      for (final (i, (n, dir, lat, lng, _, _, _, _)) in sitios.indexed)
        Cliente(
          id: 'c${20 + i}',
          nombre: 'Cliente $n',
          direccion: dir,
          ciudad: n,
          provincia: 'Bizkaia',
          lat: lat,
          lng: lng,
          color: i,
        ),
    ];
    tareas.addAll([
      for (final (i, (n, _, _, _, tipo, crit, dur, ventana)) in sitios.indexed)
        Tarea(
          id: 'd${100 + i}',
          clienteId: 'c${20 + i}',
          nombre: '$tipo · $n',
          tipo: tipo,
          criticidad: crit,
          duracionMin: dur,
          proximo: hoy(),
          inicioMin: (8 + i) * 60, // repartidas de 8:00 a 17:00 antes de planificar
          ventanaDesdeMin: ventana?.$1,
          ventanaHastaMin: ventana?.$2,
          // 5 y 5, mezcladas a propósito (no por cercanía): el planificador las ordena.
          trabajadorIds: [i.isEven ? 'w10' : 'w11'],
          color: i.isEven ? 0xFF2563EB : 0xFF16A34A,
        ),
    ]);
    _cambio();
  }

  void cargarDemo() {
    // Guarda lo que hay para poder volver a ello con quitarDemo().
    if (!demo) _prefs?.setString(_respaldo, _prefs?.getString(_clave) ?? '');
    demo = true;
    _inicial();
    final r = Random(7);
    trabajadores = [
      for (final (i, (n, a, comp, est)) in [
        ('Lucía', 'Martín', ['Calderas (RITE)', 'Fontanería', 'PRL'], EstadoHoy.disponible),
        ('Javier', 'Ortega', ['Ascensores', 'Electricidad', 'Trabajo en altura'], EstadoHoy.ocupado),
        ('Marta', 'Ruiz', ['Jardinería', 'Piscinas'], EstadoHoy.disponible),
        ('Iker', 'Etxeberria', ['Contra incendios', 'Electricidad', 'PRL'], EstadoHoy.disponible),
        ('Ana', 'Gómez', ['Limpieza'], EstadoHoy.ausente),
        ('Pablo', 'Santos', ['Climatización', 'Electricidad', 'Calderas (RITE)'], EstadoHoy.disponible),
      ].indexed)
        Trabajador(
          id: 'w$i',
          nombre: n,
          apellidos: a,
          competencias: comp,
          estadoHoy: est,
          color: i,
          telefono: '6${(10000000 + r.nextInt(89999999))}',
          email: '${n.toLowerCase()}@pulpo-demo.es',
          titulos: comp.first,
        ),
    ];
    clientes = [
      for (final (i, (n, ciudad, contacto, dir, lat, lng)) in [
        ('Comunidad Santa María 11', 'Bilbao', 'Begoña Uriarte', 'Calle Santa María 11', 43.2571, -2.9246),
        ('Colegio San Ignacio', 'Getxo', 'Mikel Arana', 'Avenida Algorta 32', 43.3505, -3.0085),
        ('Hospital Basurto · Pabellón B', 'Bilbao', 'Dra. Elena Pérez', 'Avenida Montevideo 18', 43.2617, -2.9573),
        ('Hotel Ercilla', 'Bilbao', 'Recepción', 'Calle Ercilla 37', 43.2627, -2.9405),
        ('Polideportivo Lezama', 'Lezama', 'Unai Goikoetxea', 'Calle Garaioltza 1', 43.2737, -2.8335),
        ('Oficinas Torre Iberdrola', 'Bilbao', 'Facility Manager', 'Plaza Euskadi 5', 43.2675, -2.9395),
        ('Residencia Los Robles', 'Barakaldo', 'Carmen Ibáñez', 'Calle Elcano 4', 43.2965, -2.9873),
        ('Comunidad Gran Vía 45', 'Bilbao', 'Administración Larrea', 'Gran Vía 45', 43.2632, -2.9353),
      ].indexed)
        Cliente(
          id: 'c$i',
          nombre: n,
          ciudad: ciudad,
          direccion: dir,
          lat: lat,
          lng: lng,
          provincia: 'Bizkaia',
          contacto: contacto,
          telefonoContacto: '94${4000000 + r.nextInt(999999)}',
          cif: 'B${48000000 + r.nextInt(999999)}',
          email: 'mantenimiento@cliente$i.es',
          color: i,
          activa: i != 7,
          fechaAlta: masDias(hoy(), -400 + i * 30),
        ),
    ];
    final equipos = [
      ('Caldera', 'Caldera de gas comunitaria', Periodicidad.anual, ['Calderas (RITE)']),
      ('Ascensor', 'Ascensor portal', Periodicidad.mensual, ['Ascensores', 'Electricidad']),
      ('Jardinería', 'Zonas verdes', Periodicidad.mensual, ['Jardinería']),
      ('Limpieza', 'Limpieza de zonas comunes', Periodicidad.semanal, ['Limpieza']),
      ('Contra incendios', 'Extintores y BIEs', Periodicidad.trimestral, ['Contra incendios']),
      ('Climatización', 'Climatizadora cubierta', Periodicidad.semestral, ['Climatización']),
      ('Piscina', 'Depuradora piscina', Periodicidad.mensual, ['Piscinas']),
      ('Electricidad', 'Cuadro general BT', Periodicidad.anual, ['Electricidad']),
    ];
    var n = 0;
    for (final c in clientes) {
      for (var k = 0; k < 3 + r.nextInt(3); k++) {
        final (tipo, nombre, per, comp) = equipos[r.nextInt(equipos.length)];
        final desfase = r.nextInt(30) - 6; // algunas vencidas, la mayoría en las próximas semanas
        final proximo = masDias(hoy(), desfase);
        final aptos = trabajadores.where((w) => comp.every(w.competencias.contains)).toList();
        tareas.add(
          Tarea(
            id: 'd${n++}',
            clienteId: c.id,
            nombre: nombre,
            tipo: tipo,
            periodicidad: per,
            competencias: [...comp],
            proximo: proximo,
            ultimo: r.nextInt(4) == 0 ? masDias(hoy(), -r.nextInt(25)) : masDias(proximo, -per.dias),
            inicioMin: (8 + r.nextInt(9)) * 60 + (r.nextBool() ? 30 : 0),
            duracionMin: [45, 60, 90, 120][r.nextInt(4)],
            ubicacion: ['Sala de máquinas', 'Cubierta', 'Sótano -1', 'Portal A', 'Jardín'][r.nextInt(5)],
            trabajadorIds: aptos.isNotEmpty && r.nextInt(5) > 0 ? [aptos[r.nextInt(aptos.length)].id] : [],
            estadoMaquina: r.nextInt(9) == 0 ? EstadoMaquina.revision : EstadoMaquina.operativa,
          ),
        );
      }
    }
    _cambio();
  }

  /// Cantidades exactas; las plantillas no cuentan como tareas de la simulación.
  void cargarSimulacion({
    required int equipo,
    required int cuentas,
    required int cantidadTareas,
    int dias = 30,
    DateTime? desde,
    DateTime? hasta,
    bool permitirSolapes = false,
    int trabajosSimultaneos = 2,
  }) {
    final fechaInicio = DateUtils.dateOnly(desde ?? hoy());
    final fechaFin = DateUtils.dateOnly(hasta ?? masDias(fechaInicio, dias - 1));
    final diasSimulados = fechaFin.difference(fechaInicio).inDays + 1;
    if (equipo < 0 ||
        equipo > 100 ||
        cuentas < 1 ||
        cuentas > 200 ||
        cantidadTareas < 0 ||
        cantidadTareas > 1000 ||
        (desde == null && (dias < 1 || dias > 90)) ||
        diasSimulados < 1 ||
        (permitirSolapes && (trabajosSimultaneos < 2 || trabajosSimultaneos > 20))) {
      throw ArgumentError('Cantidades de simulación fuera de rango');
    }
    if (!demo) _prefs?.setString(_respaldo, _prefs?.getString(_clave) ?? '');
    demo = true;
    _inicial();
    final plantillas = tareas.toList();
    final r = Random(7);
    trabajadores = [
      for (var i = 0; i < equipo; i++)
        Trabajador(
          id: 'w$i',
          nombre: 'Trabajador',
          apellidos: '${i + 1}',
          competencias: [...competencias],
          color: i % 8,
        ),
    ];
    final sitios = _coordsDemo.values.toList();
    clientes = [
      for (var i = 0; i < cuentas; i++)
        Cliente(
          id: 'c$i',
          nombre: 'Cliente ${i + 1}',
          ciudad: 'Bilbao',
          provincia: 'Bizkaia',
          lat: sitios[i % sitios.length].$1,
          lng: sitios[i % sitios.length].$2,
          color: i % 8,
        ),
    ];
    for (var i = 0; i < cantidadTareas; i++) {
      final t = plantillas[i % plantillas.length].copia();
      final grupo = i ~/ trabajosSimultaneos;
      final diaSimulado = permitirSolapes
          ? masDias(fechaInicio, grupo % diasSimulados)
          : masDias(fechaInicio, r.nextInt(diasSimulados));
      final horaSimulada = permitirSolapes ? (8 + (grupo ~/ diasSimulados) % 9) * 60 : (8 + r.nextInt(9)) * 60;
      t
        ..id = 'd$i'
        ..plantilla = false
        ..clienteId = clientes[i % cuentas].id
        ..proximo = diaSimulado
        ..inicioMin = horaSimulada
        ..duracionMin = permitirSolapes ? 60 : [30, 60, 90, 120][r.nextInt(4)]
        ..trabajadorIds = equipo == 0 ? [] : [trabajadores[i % equipo].id];
      tareas.add(t);
    }
    _cambio();
  }

  static const _coordsDemo = {
    'c0': (43.2571, -2.9246),
    'c1': (43.3505, -3.0085),
    'c2': (43.2617, -2.9573),
    'c3': (43.2627, -2.9405),
    'c4': (43.2737, -2.8335),
    'c5': (43.2675, -2.9395),
    'c6': (43.2965, -2.9873),
    'c7': (43.2632, -2.9353),
  };

  /// Los ids de ejemplo son cortos (c0, w3, d17); los reales son marcas de tiempo largas.
  static final _idDemo = RegExp(r'^[cwd]\d{1,3}$');
  bool get _hayDemo => clientes.any((c) => _idDemo.hasMatch(c.id)) || trabajadores.any((w) => _idDemo.hasMatch(w.id));

  /// Quita los datos de ejemplo y deja la cuenta como estaba antes de cargarlos.
  /// Sin respaldo, borra solo lo que es de ejemplo y conserva lo que hayas creado tú.
  Future<void> quitarDemo() async {
    final r = _prefs?.getString(_respaldo);
    _prefs?.remove(_respaldo);
    demo = false;
    if (r != null && r.isNotEmpty) {
      await _prefs?.setString(_clave, r);
      await cargar();
      return;
    }
    clientes.removeWhere((c) => _idDemo.hasMatch(c.id));
    trabajadores.removeWhere((w) => _idDemo.hasMatch(w.id));
    tareas.removeWhere((t) => _idDemo.hasMatch(t.id) || (t.clienteId != null && cliente(t.clienteId) == null));
    for (final t in tareas) {
      t.trabajadorIds.removeWhere((id) => trabajador(id) == null);
    }
    _cambio();
  }

  /// Estado inicial de una cuenta nueva: vacía salvo las plantillas.
  void _inicial() {
    clientes = [];
    trabajadores = [];
    tareas = [
      Tarea(
        id: 'p1',
        nombre: 'Revisión caldera de gas',
        tipo: 'Caldera',
        periodicidad: Periodicidad.anual,
        competencias: ['Calderas (RITE)'],
        notas: 'Comprobar presión, quemador, salida de humos y CO.',
      ),
      Tarea(
        id: 'p2',
        nombre: 'Mantenimiento de ascensor',
        tipo: 'Ascensor',
        periodicidad: Periodicidad.mensual,
        competencias: ['Ascensores', 'Electricidad'],
        notas: 'Revisión de cables, frenos, puertas y foso.',
      ),
      Tarea(
        id: 'p3',
        nombre: 'Poda y riego de zonas verdes',
        tipo: 'Jardinería',
        periodicidad: Periodicidad.mensual,
        competencias: ['Jardinería'],
      ),
      Tarea(
        id: 'p4',
        nombre: 'Limpieza de rellanos y portal',
        tipo: 'Limpieza',
        periodicidad: Periodicidad.semanal,
        competencias: ['Limpieza'],
      ),
    ];
  }
}

final store = Store();
