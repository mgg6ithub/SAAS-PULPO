import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'nube.dart';
import 'theme.dart' show TipoInfo, tipos, tiposBase, competencias, competenciasBase;

/// Datos del prototipo. Se guardan en el navegador; más adelante, Supabase.
class Store extends ChangeNotifier {
  static const _clave = 'pulpo_v2';
  static const _respaldo = 'pulpo_v2_respaldo';
  static const _nombresSimulados = [
    'Ane',
    'Mikel',
    'Nerea',
    'Iker',
    'June',
    'Unai',
    'Maialen',
    'Aitor',
    'Leire',
    'Jon',
    'Nahia',
    'Asier',
    'Irati',
    'Ander',
    'Miren',
    'Eneko',
    'Lorea',
    'Gorka',
    'Ainhoa',
    'Oier',
    'Amaia',
    'Julen',
    'Garazi',
    'Beñat',
    'Uxue',
    'Xabier',
    'Estibaliz',
    'Koldo',
    'Idoia',
    'Imanol',
    'Ziortza',
    'Aratz',
    'Naiara',
    'Ekain',
    'Itziar',
    'Josu',
    'Olatz',
    'Peru',
    'Saioa',
    'Haritz',
  ];
  static const _apellidosSimulados = [
    'Etxebarria',
    'Arrieta',
    'Goikoetxea',
    'Agirre',
    'García',
    'Martínez',
    'López',
    'Sánchez',
    'González',
    'Ruiz',
    'Fernández',
    'Pérez',
    'Ortega',
    'Santos',
    'Mendizabal',
    'Aguirre',
    'Ibarra',
    'Etxeberria',
    'Bilbao',
    'Sola',
    'Zubiaur',
    'Urrutia',
    'Lasa',
    'Otxoa',
    'Garmendia',
    'Uriarte',
    'Larrañaga',
    'Elorza',
    'Zabala',
    'Landa',
    'Iturbe',
    'Mujika',
    'Aranburu',
    'Berasategi',
    'Olabarria',
    'Gallastegi',
    'Axpe',
    'Barrenetxea',
    'Zuazo',
    'Ugarte',
  ];

  // 10 tipos × 20 lugares, repartidos para que no se repita ninguno hasta 200 clientes.
  static const _tiposClienteSimulados = [
    'Colegio',
    'Hospital',
    'Residencia',
    'Comunidad',
    'Hotel',
    'Polideportivo',
    'Centro comercial',
    'Clínica',
    'Oficinas',
    'Gimnasio',
  ];
  static const _lugaresClienteSimulados = [
    'San Ignacio',
    'Los Pinos',
    'Santa María',
    'Ercilla',
    'Begoña',
    'Las Arenas',
    'Gran Vía',
    'Mirador',
    'El Pilar',
    'Zorrotza',
    'Deusto',
    'Abando',
    'Basurto',
    'Lezama',
    'Rekalde',
    'Indautxu',
    'Casco Viejo',
    'Artxanda',
    'Sarriko',
    'Uribarri',
  ];
  static String _clienteSimulado(int i) =>
      '${_tiposClienteSimulados[i % 10]} ${_lugaresClienteSimulados[(i * 7 + i ~/ 10) % 20]}';
  static String _trabajadorSimulado(int i) =>
      '${_nombresSimulados[i % 40]} ${_apellidosSimulados[(i * 7 + i ~/ 40) % 40]}';

  static const _ubicacionesSimuladas = [
    'Portal A',
    'Portal B',
    'Sótano -1',
    'Cubierta',
    'Sala de máquinas',
    'Planta baja',
    'Jardín',
    'Azotea',
    'Patio interior',
    'Garaje',
    'Zona común',
    'Edificio anexo',
  ];

  /// Cómo se llama cada trabajo simulado según su tipo, para que no se repitan los nombres.
  static const _variantesSimuladas = {
    'Caldera': [
      'Revisión de caldera de gas',
      'Limpieza de quemadores',
      'Control de combustión y CO',
      'Revisión de sala de calderas',
      'Comprobación de presión del circuito',
      'Revisión del vaso de expansión',
      'Inspección de chimenea',
      'Mantenimiento de caldera de condensación',
    ],
    'Ascensor': [
      'Mantenimiento de ascensor',
      'Revisión de cables y poleas',
      'Prueba de frenos y paracaídas',
      'Revisión de puertas de cabina',
      'Engrase de guías',
      'Revisión del cuadro de maniobra',
      'Inspección del foso',
      'Revisión del montacargas',
    ],
    'Jardinería': [
      'Poda y riego de zonas verdes',
      'Siega del césped',
      'Poda de setos',
      'Tratamiento de plagas',
      'Plantación de temporada',
      'Revisión del riego automático',
      'Limpieza de hojas y restos',
      'Abonado de parterres',
    ],
    'Limpieza': [
      'Limpieza de rellanos y portal',
      'Limpieza de cristales',
      'Fregado de escaleras',
      'Limpieza del garaje',
      'Desinfección de zonas comunes',
      'Limpieza de cubiertas',
      'Pulido de suelos',
      'Limpieza de fachada baja',
    ],
  };

  /// Las partes en que se divide un trabajo simulado de cada tipo.
  static const _subtrabajosSimulados = {
    'Caldera': [
      'Revisar el quemador',
      'Comprobar la presión del circuito',
      'Medir el CO en humos',
      'Limpiar filtros',
      'Probar la válvula de seguridad',
    ],
    'Ascensor': [
      'Revisar cables y poleas',
      'Comprobar frenos',
      'Engrasar guías',
      'Revisar puertas de cabina',
      'Limpiar el foso',
    ],
    'Jardinería': [
      'Recoger el césped',
      'Podar los setos',
      'Cortar los arbustos',
      'Regar las zonas verdes',
      'Retirar restos de poda',
    ],
    'Limpieza': [
      'Fregar los rellanos',
      'Limpiar los cristales del portal',
      'Vaciar las papeleras',
      'Desinfectar los pasamanos',
      'Limpiar el ascensor',
    ],
  };
  static const _coloresSubtrabajos = [0xFF2563EB, 0xFF0D9488, 0xFFCA8A04, 0xFFDB2777, 0xFF16A34A, 0xFFEA580C];

  /// Hay datos de ejemplo cargados; los reales esperan en el respaldo.
  bool demo = false;

  List<Cliente> clientes = [];
  List<Trabajador> trabajadores = [];
  List<Tarea> tareas = [];

  /// Subtrabajos de cualquier nivel (cada uno apunta a su padre con `padreId`). Aparte de `tareas` para que
  /// el calendario, el planificador y las cifras sigan viendo solo los trabajos.
  List<Tarea> subtareas = [];
  List<EtiquetaTrabajo> etiquetas = [];

  /// Equipos de los clientes y sus vencimientos legales.
  List<Equipo> equipos = [];
  List<Vencimiento> vencimientos = [];
  SharedPreferences? _prefs;

  /// Con sesión iniciada, cada cambio se guarda en Supabase en vez de en el navegador.
  Nube? nube;

  /// Carga la empresa de la cuenta desde Supabase; una empresa nueva empieza con las plantillas iniciales.
  Future<void> cargarDesdeNube(Nube n) async {
    await n.subirPendiente();
    final d = await n.cargar();
    _deLaNube(d);
    usoPlantillas = [];
    demo = false;
    nube = n;
    n.vincular(this, vacio: n.nueva);
    if (n.nueva) {
      _inicial();
      // Solo las plantillas de lo que hace la empresa (si eligió un tipo concreto).
      final tipo = Nube.tiposEmpresa[n.tipo];
      if (tipo != null) tareas.removeWhere((t) => t.tipo != tipo);
      for (final t in tareas) {
        t.id = nuevoId();
      }
      _cambio();
    }
    notifyListeners();
  }

  void _deLaNube(DatosNube d) {
    clientes = d.clientes;
    trabajadores = d.trabajadores;
    tareas = d.tareas;
    subtareas = d.subtareas;
    etiquetas = d.etiquetas;
    equipos = d.equipos;
    vencimientos = d.vencimientos;
    tipos = d.tipos.isEmpty ? [...tiposBase] : d.tipos;
    competencias = d.competencias.isEmpty ? [...competenciasBase] : d.competencias;
  }

  /// Lo que otra persona ha cambiado en la base (en vivo). No se vuelve a guardar: ya está allí.
  void ponerDeLaNube(DatosNube d) {
    _deLaNube(d);
    notifyListeners();
  }

  /// Hay algo creado además de las plantillas.
  bool get tieneDatos => clientes.isNotEmpty || trabajadores.isNotEmpty || tareas.any((t) => !t.esPlantilla);

  /// Borra de la base todo lo de la empresa (clientes, trabajadores, trabajos, plantillas y etiquetas).
  /// Quedan las cuentas y la empresa a la que pertenecen.
  Future<void> vaciarNube() async {
    await nube!.vaciar();
    demo = false;
    clientes = [];
    trabajadores = [];
    tareas = [];
    subtareas = [];
    etiquetas = [];
    equipos = [];
    vencimientos = [];
    tipos = [...tiposBase];
    competencias = [...competenciasBase];
    usoPlantillas = [];
    notifyListeners();
  }

  /// Al cerrar sesión no se queda en pantalla nada de la cuenta.
  void vaciar() {
    nube = null;
    clientes = [];
    trabajadores = [];
    tareas = [];
    subtareas = [];
    etiquetas = [];
    equipos = [];
    vencimientos = [];
    tipos = [...tiposBase];
    competencias = [...competenciasBase];
    notifyListeners();
  }

  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs!.getString(_clave);
    tipos = [...tiposBase];
    competencias = [...competenciasBase];
    if (s == null) {
      _inicial();
      _guardar();
    } else {
      final j = jsonDecode(s) as Map<String, dynamic>;
      clientes = [for (final x in j['clientes'] as List) Cliente.fromJson(x)];
      trabajadores = [for (final x in j['trabajadores'] as List) Trabajador.fromJson(x)];
      tareas = [for (final x in j['tareas'] as List) Tarea.fromJson(x)];
      subtareas = [for (final x in j['subtareas'] as List? ?? []) Tarea.fromJson(x)];
      // Datos de ejemplo cargados antes de existir la marca: se reconocen por sus ids.
      demo = (j['demo'] as bool? ?? false) || _hayDemo;
      usoPlantillas = List<String>.from(j['usoPlantillas'] as List? ?? []);
      etiquetas = [for (final x in j['etiquetas'] as List? ?? []) EtiquetaTrabajo.fromJson(x)];
      equipos = [for (final x in j['equipos'] as List? ?? []) Equipo.fromJson(x)];
      vencimientos = [for (final x in j['vencimientos'] as List? ?? []) Vencimiento.fromJson(x)];
      if (j['tipos'] case final List l when l.isNotEmpty) tipos = [for (final x in l) TipoInfo.fromJson(x)];
      if (j['competencias'] case final List l when l.isNotEmpty) competencias = List<String>.from(l);
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

  void _guardar() {
    if (nube != null) {
      nube!.sincronizar();
      return;
    }
    _prefs?.setString(
      _clave,
      jsonEncode({
        'clientes': [for (final x in clientes) x.toJson()],
        'trabajadores': [for (final x in trabajadores) x.toJson()],
        'tareas': [for (final x in tareas) x.toJson()],
        'subtareas': [for (final x in subtareas) x.toJson()],
        'demo': demo,
        'usoPlantillas': usoPlantillas,
        'etiquetas': [for (final x in etiquetas) x.toJson()],
        'tipos': [for (final x in tipos) x.toJson()],
        'equipos': [for (final x in equipos) x.toJson()],
        'vencimientos': [for (final x in vencimientos) x.toJson()],
        'competencias': competencias,
      }),
    );
  }

  void _cambio() {
    _guardar();
    notifyListeners();
  }

  void guardarEtiqueta(EtiquetaTrabajo e) {
    final i = etiquetas.indexWhere((x) => x.id == e.id);
    i < 0 ? etiquetas.add(e) : etiquetas[i] = e;
    _cambio();
  }

  void borrarEtiqueta(String id) {
    etiquetas.removeWhere((e) => e.id == id);
    _cambio();
  }

  // ── Tipos de trabajo y competencias (de cada empresa, editables en Ajustes) ──

  /// Crea o cambia un tipo. Si cambia de nombre, sus trabajos y plantillas pasan al nombre nuevo.
  /// «Otro» se queda siempre el último.
  void guardarTipo(TipoInfo t) {
    final i = tipos.indexWhere((x) => x.id == t.id);
    if (i < 0) {
      tipos.insert(tipos.length - 1, t);
    } else {
      final viejo = tipos[i].nombre;
      tipos[i] = t;
      if (viejo != t.nombre) {
        for (final x in [...tareas, ...subtareas].where((x) => x.tipo == viejo)) {
          x.tipo = t.nombre;
        }
      }
    }
    _cambio();
  }

  /// Quita un tipo; sus trabajos pasan a «Otro». «Otro» no se puede quitar.
  void borrarTipo(String id) {
    if (tipos.length < 2 || tipos.last.id == id) return;
    final t = tipos.firstWhere((x) => x.id == id);
    tipos.remove(t);
    for (final x in [...tareas, ...subtareas].where((x) => x.tipo == t.nombre)) {
      x.tipo = tipos.last.nombre;
    }
    _cambio();
  }

  void anadirCompetencia(String nombre) {
    final n = nombre.trim();
    if (n.isEmpty || competencias.contains(n)) return;
    competencias.add(n);
    _cambio();
  }

  /// Cambia el nombre de una competencia en todas partes: trabajadores, trabajos y tipos.
  void renombrarCompetencia(String viejo, String nuevo) {
    final n = nuevo.trim();
    if (n.isEmpty || n == viejo || competencias.contains(n)) return;
    competencias[competencias.indexOf(viejo)] = n;
    List<String> cambiar(List<String> l) => [for (final c in l) c == viejo ? n : c];
    for (final w in trabajadores) {
      w.competencias = cambiar(w.competencias);
    }
    for (final x in [...tareas, ...subtareas]) {
      x.competencias = cambiar(x.competencias);
    }
    tipos = [for (final t in tipos) t.competencia == viejo ? t.cambiar(competencia: n) : t];
    _cambio();
  }

  /// Quita una competencia de la empresa y de quien la tuviera.
  void borrarCompetencia(String nombre) {
    competencias.remove(nombre);
    for (final w in trabajadores) {
      w.competencias.remove(nombre);
    }
    for (final x in [...tareas, ...subtareas]) {
      x.competencias.remove(nombre);
    }
    tipos = [for (final t in tipos) t.competencia == nombre ? t.cambiar(sinCompetencia: true) : t];
    _cambio();
  }

  /// UUID v4: la base de datos usa uuid y así se pueden crear ids sin conexión.
  String nuevoId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

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
    for (final e in equipos.where((e) => e.clienteId == id).toList()) {
      vencimientos.removeWhere((v) => v.equipoId == e.id);
    }
    equipos.removeWhere((e) => e.clienteId == id);
    tareas.removeWhere((t) => t.clienteId == id);
    subtareas.removeWhere((t) => t.clienteId == id);
    _cambio();
  }

  List<Tarea> tareasDe(String clienteId) => tareas.where((t) => t.clienteId == clienteId).toList();

  // ── Equipos y vencimientos legales ──
  Equipo? equipo(String? id) => id == null ? null : equipos.where((e) => e.id == id).firstOrNull;
  List<Equipo> equiposDe(String clienteId) => equipos.where((e) => e.clienteId == clienteId).toList();
  List<Vencimiento> vencimientosDe(String equipoId) =>
      vencimientos.where((v) => v.equipoId == equipoId).toList()..sort((a, b) => a.vence.compareTo(b.vence));

  /// Trabajos hechos sobre el equipo (su historial de revisiones y averías).
  List<Tarea> trabajosDe(String equipoId) => tareas.where((t) => t.equipoId == equipoId).toList();

  /// Vencimientos vencidos o dentro de su plazo de aviso, el más urgente primero.
  List<Vencimiento> get vencimientosPorAvisar =>
      vencimientos.where((v) => v.avisar && equipo(v.equipoId) != null).toList()
        ..sort((a, b) => a.vence.compareTo(b.vence));

  void guardarEquipo(Equipo e) {
    _poner(equipos, e, (x) => x.id == e.id);
    _cambio();
  }

  /// Quita el equipo y sus vencimientos; sus trabajos se quedan, sin equipo.
  void borrarEquipo(String id) {
    equipos.removeWhere((e) => e.id == id);
    vencimientos.removeWhere((v) => v.equipoId == id);
    for (final t in [...tareas, ...subtareas].where((t) => t.equipoId == id)) {
      t.equipoId = null;
    }
    _cambio();
  }

  void guardarVencimiento(Vencimiento v) {
    _poner(vencimientos, v, (x) => x.id == v.id);
    _cambio();
  }

  void borrarVencimiento(String id) {
    vencimientos.removeWhere((v) => v.id == id);
    _cambio();
  }

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

  /// Un trabajo o un subtrabajo, de la lista que toque.
  Tarea? tarea(String? id) {
    for (final t in tareas) {
      if (t.id == id) return t;
    }
    for (final t in subtareas) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Subtrabajos directos de un trabajo o subtrabajo.
  List<Tarea> hijas(String id) => subtareas.where((s) => s.padreId == id).toList();

  /// Aplica un cambio a varios trabajos o subtrabajos a la vez (selección múltiple) y guarda una sola vez.
  void aplicarA(Iterable<Tarea> ts, void Function(Tarea t) cambio) {
    for (final t in ts) {
      cambio(t);
    }
    for (final t in ts) {
      if (t.padreId != null) {
        t.clienteId = tarea(t.padreId)?.clienteId;
      } else {
        _compartirCliente(t);
      }
    }
    _cambio();
  }

  /// «Realizado» lo marca como hecho (histórico y siguiente fecha); el resto solo cambia el estado.
  void cambiarEstado(Iterable<Tarea> ts, EstadoTrabajo e) => aplicarA(ts, (t) {
    if (e == EstadoTrabajo.realizado) {
      if (t.estado != e) _marcarHecha(t);
    } else {
      t.estado = e;
    }
  });

  /// Todos los subtrabajos que cuelgan de este, a cualquier profundidad.
  List<Tarea> descendientes(String id) => [
    for (final h in hijas(id)) ...[h, ...descendientes(h.id)],
  ];

  /// Pone a todos los subtrabajos los mismos trabajadores que a este trabajo.
  void asignarASubtrabajos(Tarea t) {
    for (final h in descendientes(t.id)) {
      h.trabajadorIds = [...t.trabajadorIds];
    }
    _cambio();
  }

  void guardarTarea(Tarea t) {
    if (t.padreId != null) {
      // El subtrabajo comparte el cliente de su padre.
      t.clienteId = tarea(t.padreId)?.clienteId;
      _poner(subtareas, t, (x) => x.id == t.id);
    } else {
      if (!tareas.any((x) => x.id == t.id)) {
        recienId = t.id;
        recienEn = DateTime.now();
      }
      _poner(tareas, t, (x) => x.id == t.id);
    }
    _compartirCliente(t);
    _cambio();
  }

  /// Los subtrabajos, a cualquier profundidad, siguen el cliente del trabajo.
  void _compartirCliente(Tarea t) {
    for (final h in hijas(t.id)) {
      h.clienteId = t.clienteId;
      _compartirCliente(h);
    }
  }

  void borrarTarea(String id) {
    for (final h in hijas(id)) {
      borrarTarea(h.id);
    }
    tareas.removeWhere((t) => t.id == id);
    subtareas.removeWhere((t) => t.id == id);
    _cambio();
  }

  /// El mantenimiento se ha hecho hoy: se calcula el siguiente.
  /// Cómo estaba cada tarea antes de marcarla hecha, para poder desmarcarla (durante la sesión).
  final _antesDeHecha = <String, (DateTime?, DateTime?, EstadoMaquina, EstadoTrabajo)>{};

  bool puedeDesmarcar(Tarea t) => _antesDeHecha.containsKey(t.id);

  void desmarcarHecha(Tarea t) {
    final antes = _antesDeHecha.remove(t.id);
    if (antes == null) return;
    t.historial.removeWhere((d) => DateUtils.isSameDay(d, hoy()) && !DateUtils.isSameDay(antes.$1, d));
    t
      ..ultimo = antes.$1
      ..proximo = antes.$2
      ..estadoMaquina = antes.$3
      ..estado = antes.$4;
    _cambio();
  }

  void marcarHecha(Tarea t) {
    _marcarHecha(t);
    _cambio();
  }

  void _marcarHecha(Tarea t) {
    _antesDeHecha[t.id] = (t.ultimo, t.proximo, t.estadoMaquina, t.estado);
    t.ultimo = hoy();
    // Si se repite, la siguiente vez vuelve a estar pendiente; si es única, se queda realizada.
    t.estado = t.periodicidad.repite ? EstadoTrabajo.pendiente : EstadoTrabajo.realizado;
    if (!t.historial.any((d) => DateUtils.isSameDay(d, hoy()))) t.historial.add(hoy());
    // Una tarea única, al hacerse, ya no tiene próxima.
    t.proximo = t.periodicidad.repite ? masDias(hoy(), t.periodicidad.dias) : null;
    if (t.estadoMaquina == EstadoMaquina.revision) t.estadoMaquina = EstadoMaquina.operativa;
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
      Trabajador(id: 'w10', nombre: 'Mikel', apellidos: 'Arrieta', color: 1, competencias: [...competencias]),
      Trabajador(id: 'w11', nombre: 'Nerea', apellidos: 'Etxeberria', color: 2, competencias: [...competencias]),
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

  void cargarDemo({bool soloProximosDosDias = false}) {
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
        final desfase = soloProximosDosDias ? 1 + r.nextInt(2) : r.nextInt(30) - 6;
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
    bool conSubtrabajos = false,
    int cadaTantosConSubtrabajos = 3,
  }) {
    final fechaInicio = DateUtils.dateOnly(desde ?? hoy());
    final fechaFin = DateUtils.dateOnly(hasta ?? masDias(fechaInicio, dias - 1));
    final diasSimulados = fechaFin.difference(fechaInicio).inDays + 1;
    if (equipo < 0 ||
        equipo > 100 ||
        cuentas < 0 ||
        cuentas > 200 ||
        cantidadTareas < 0 ||
        cantidadTareas > 1000 ||
        (desde == null && (dias < 1 || dias > 90)) ||
        diasSimulados < 1 ||
        (permitirSolapes && (trabajosSimultaneos < 2 || trabajosSimultaneos > 20)) ||
        cadaTantosConSubtrabajos < 1 ||
        cadaTantosConSubtrabajos > 20) {
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
          nombre: _trabajadorSimulado(i).split(' ').first,
          apellidos: _trabajadorSimulado(i).split(' ').skip(1).join(' '),
          competencias: [...competencias],
          color: i % 8,
        ),
    ];
    final sitios = _coordsDemo.values.toList();
    clientes = [
      for (var i = 0; i < cuentas; i++)
        Cliente(
          id: 'c$i',
          nombre: _clienteSimulado(i),
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
        ..nombre =
            '${_variantesSimuladas[t.tipo]?[(i ~/ plantillas.length) % 8] ?? t.nombre} · ${cuentas == 0 ? _ubicacionesSimuladas[(i ~/ 8) % _ubicacionesSimuladas.length] : clientes[i % cuentas].nombre}'
        ..ubicacion = _ubicacionesSimuladas[(i * 5) % _ubicacionesSimuladas.length]
        ..clienteId = cuentas == 0 ? null : clientes[i % cuentas].id
        ..proximo = diaSimulado
        ..inicioMin = horaSimulada
        ..duracionMin = permitirSolapes ? 60 : [30, 60, 90, 120][r.nextInt(4)]
        ..trabajadorIds = equipo == 0 ? [] : [trabajadores[i % equipo].id];
      tareas.add(t);
      // Cada tantos trabajos, uno se divide en varios subtrabajos, cada uno con su color, fecha y hora.
      final partes = _subtrabajosSimulados[t.tipo];
      if (conSubtrabajos && partes != null && i % cadaTantosConSubtrabajos == 0) {
        for (var k = 0; k < 3; k++) {
          subtareas.add(
            t.copia()
              ..id = 's${subtareas.length}'
              ..padreId = t.id
              ..nombre = partes[(i + k) % partes.length]
              ..color = _coloresSubtrabajos[(i + k) % _coloresSubtrabajos.length]
              ..proximo = masDias(t.proximo ?? fechaInicio, k)
              ..inicioMin = (t.inicioMin ?? 8 * 60) + k * 60
              ..duracionMin = [30, 45, 60][k],
          );
        }
      }
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
  static final _idDemo = RegExp(r'^[cwds]\d{1,4}$');
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
    subtareas.removeWhere((t) => tarea(t.padreId) == null || _idDemo.hasMatch(t.id));
    for (final t in tareas) {
      t.trabajadorIds.removeWhere((id) => trabajador(id) == null);
    }
    _cambio();
  }

  /// Estado inicial de una cuenta nueva: vacía salvo las plantillas.
  void _inicial() {
    clientes = [];
    trabajadores = [];
    subtareas = [];
    equipos = [];
    vencimientos = [];
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
