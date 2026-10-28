import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'store.dart';

const supabaseUrl = 'https://gvasthxiqckmekwvhtrg.supabase.co';

/// Clave publicable: está pensada para ir dentro de la app. La secreta (`service_role`) nunca.
const supabasePublicable = 'sb_publishable_jGH8ZqhOiUZOttnNh8AOSg_BHvqppBQ';

/// La cuenta pertenece a empresas pero en ninguna es administradora (el trabajador entra en DEV-011).
class SinAcceso implements Exception {
  const SinAcceso();
}

/// Datos que el [Store] tenía cargados y que se guardan en Supabase.
typedef _Filas = Map<String, Map<String, Map<String, dynamic>>>;

/// Conexión con Supabase para una cuenta y una empresa: lee todo al entrar y, después, guarda solo lo que cambia.
class Nube {
  Nube._(this.empresaId, {required this.nueva});

  final String empresaId;

  /// La empresa se acaba de crear: el [Store] la rellena con las plantillas iniciales.
  final bool nueva;

  /// Último fallo al guardar (null = todo guardado). Se vuelve a intentar solo.
  static final error = ValueNotifier<String?>(null);

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> iniciar() => Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublicable);

  /// Entra en la empresa de la cuenta; si no tiene ninguna, crea una y la hace administradora.
  static Future<Nube> abrir() async {
    final ms = await _db.from('miembros').select('empresa_id, rol');
    for (final m in ms) {
      if (m['rol'] == 'admin') return _abierta = Nube._(m['empresa_id'] as String, nueva: false);
    }
    if (ms.isNotEmpty) throw const SinAcceso();
    final e = await _db.from('empresas').insert({'nombre': 'Mi empresa'}).select('id').single();
    final id = e['id'] as String;
    await _db.from('miembros').insert({'usuario_id': _db.auth.currentUser!.id, 'empresa_id': id, 'rol': 'admin'});
    return _abierta = Nube._(id, nueva: true);
  }

  /// La última empresa abierta, para no cerrar la sesión con cambios sin guardar.
  static Nube? _abierta;

  static Future<void> cerrarSesion() async {
    await _abierta?._cola;
    await _db.auth.signOut();
  }

  // ── Leer ──

  Future<List<Map<String, dynamic>>> _todo(String tabla) async {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; ; i += 1000) {
      final r = await _db.from(tabla).select().eq('empresa_id', empresaId).order('created_at').range(i, i + 999);
      out.addAll(r);
      if (r.length < 1000) return out;
    }
  }

  Future<DatosNube> cargar() async {
    final r = await Future.wait([
      _todo('clientes'),
      _todo('trabajadores'),
      _todo('etiquetas'),
      _todo('trabajos'),
      _db.from('trabajo_trabajadores').select('trabajo_id, trabajador_id').eq('empresa_id', empresaId),
      _db.from('trabajo_historial').select('trabajo_id, dia').eq('empresa_id', empresaId),
      _todo('automatizaciones'),
    ]);
    final trabajadoresDe = <String, List<String>>{};
    for (final x in r[4]) {
      (trabajadoresDe[x['trabajo_id']] ??= []).add(x['trabajador_id'] as String);
    }
    final historialDe = <String, List<DateTime>>{};
    for (final x in r[5]) {
      (historialDe[x['trabajo_id']] ??= []).add(DateTime.parse(x['dia'] as String));
    }
    final automatizacionesDe = <String, List<Automatizacion>>{};
    for (final x in r[6]) {
      (automatizacionesDe[x['trabajo_id']] ??= []).add(_automatizacion(x));
    }
    final tareas = <Tarea>[], subtareas = <Tarea>[];
    for (final x in r[3]) {
      final id = x['id'] as String;
      final t = _tarea(x, trabajadoresDe[id] ?? [], (historialDe[id] ?? [])..sort(), automatizacionesDe[id] ?? []);
      (t.padreId == null ? tareas : subtareas).add(t);
    }
    return DatosNube(
      clientes: [for (final x in r[0]) _cliente(x)],
      trabajadores: [for (final x in r[1]) _trabajador(x)],
      etiquetas: [
        for (final x in r[2]) EtiquetaTrabajo(id: x['id'], nombre: x['nombre'], color: (x['color'] as num).toInt()),
      ],
      tareas: tareas,
      subtareas: subtareas,
    );
  }

  // ── Guardar ──

  /// Lo último que ya está en la base, por tabla y clave (la fila en JSON, para comparar).
  final Map<String, Map<String, String>> _enviado = {};
  Future<void> _cola = Future.value();

  /// Termina cuando todo lo pendiente ya está guardado (para las pruebas).
  @visibleForTesting
  Future<void> get guardado => _cola;
  Timer? _reintento;
  Store? _store;

  /// Empieza a vigilar el [Store]. Con [vacio] no da nada por guardado y lo sube todo.
  void vincular(Store s, {bool vacio = false}) {
    _store = s;
    _enviado.clear();
    if (!vacio) {
      _filas(s).forEach((t, filas) => _enviado[t] = {for (final e in filas.entries) e.key: jsonEncode(e.value)});
    }
  }

  static const _orden = [
    'clientes',
    'trabajadores',
    'etiquetas',
    'trabajos',
    'trabajo_trabajadores',
    'trabajo_historial',
    'automatizaciones',
  ];

  /// Compara el [Store] con lo ya guardado y manda solo la diferencia, en orden y sin solaparse.
  void sincronizar() {
    final s = _store;
    if (s == null) return;
    final ahora = _filas(s);
    final subir = <String, List<Map<String, dynamic>>>{};
    final borrar = <String, List<String>>{};
    for (final t in _orden) {
      final viejo = _enviado[t] ?? {};
      final nuevo = ahora[t]!;
      final cambiadas = [
        for (final e in nuevo.entries)
          if (viejo[e.key] != jsonEncode(e.value)) e.value,
      ];
      final quitadas = [
        for (final k in viejo.keys)
          if (!nuevo.containsKey(k)) k,
      ];
      if (cambiadas.isNotEmpty) subir[t] = cambiadas;
      if (quitadas.isNotEmpty) borrar[t] = quitadas;
    }
    if (subir.isEmpty && borrar.isEmpty) return;
    _reintento?.cancel();
    _cola = _cola.then((_) async {
      try {
        for (final t in _orden) {
          final filas = subir[t];
          if (filas == null) continue;
          for (var i = 0; i < filas.length; i += 200) {
            await _db
                .from(t)
                .upsert(filas.sublist(i, i + 200 > filas.length ? filas.length : i + 200), onConflict: _clave[t]!);
          }
        }
        for (final t in _orden.reversed) {
          for (final k in borrar[t] ?? const <String>[]) {
            await _borrar(t, k);
          }
        }
        _enviado
          ..clear()
          ..addAll({
            for (final t in _orden) t: {for (final e in ahora[t]!.entries) e.key: jsonEncode(e.value)},
          });
        error.value = null;
      } catch (e) {
        debugPrint('Pulpo: no se pudo guardar en Supabase: $e');
        error.value = 'No se pudo guardar. Se reintentará solo.';
        _reintento = Timer(const Duration(seconds: 10), sincronizar);
      }
    });
  }

  static const _clave = {
    'clientes': 'id',
    'trabajadores': 'id',
    'etiquetas': 'id',
    'trabajos': 'id',
    'trabajo_trabajadores': 'trabajo_id,trabajador_id',
    'trabajo_historial': 'trabajo_id,dia',
    'automatizaciones': 'id',
  };

  Future<void> _borrar(String tabla, String clave) {
    final q = _db.from(tabla).delete().eq('empresa_id', empresaId);
    switch (tabla) {
      case 'trabajo_trabajadores':
        final p = clave.split('|');
        return q.eq('trabajo_id', p[0]).eq('trabajador_id', p[1]);
      case 'trabajo_historial':
        final p = clave.split('|');
        return q.eq('trabajo_id', p[0]).eq('dia', p[1]);
      default:
        return q.eq('id', clave);
    }
  }

  /// Todo el [Store] como filas de las tablas. Lo que apunta a algo que ya no existe se queda sin enlace.
  _Filas _filas(Store s) {
    final e = empresaId;
    final clientes = {for (final c in s.clientes) c.id};
    final trabajadores = {for (final w in s.trabajadores) w.id};
    final trabajos = [...s.tareas, ...s.subtareas];
    final ids = {for (final t in trabajos) t.id};
    final r = <String, Map<String, Map<String, dynamic>>>{for (final t in _orden) t: {}};
    for (final c in s.clientes) {
      r['clientes']![c.id] = {
        'id': c.id,
        'empresa_id': e,
        'nombre': c.nombre,
        'cif': c.cif,
        'direccion': c.direccion,
        'ciudad': c.ciudad,
        'cp': c.cp,
        'provincia': c.provincia,
        'telefono': c.telefono,
        'email': c.email,
        'contacto': c.contacto,
        'telefono_contacto': c.telefonoContacto,
        'notas': c.notas,
        'foto': c.foto,
        'activa': c.activa,
        'fecha_alta': c.fechaAlta.toUtc().toIso8601String(),
        'color': c.color,
        'lat': c.lat,
        'lng': c.lng,
      };
    }
    for (final w in s.trabajadores) {
      r['trabajadores']![w.id] = {
        'id': w.id,
        'empresa_id': e,
        'nombre': w.nombre,
        'apellidos': w.apellidos,
        'telefono': w.telefono,
        'email': w.email,
        'info': w.info,
        'titulos': w.titulos,
        'foto': w.foto,
        'competencias': w.competencias,
        'activo': w.activo,
        'estado_hoy': w.estadoHoy.index,
        'color': w.color,
      };
    }
    for (final x in s.etiquetas) {
      r['etiquetas']![x.id] = {'id': x.id, 'empresa_id': e, 'nombre': x.nombre, 'color': x.color};
    }
    for (final t in trabajos) {
      r['trabajos']![t.id] = {
        'id': t.id,
        'empresa_id': e,
        'cliente_id': clientes.contains(t.clienteId) ? t.clienteId : null,
        'plantilla': t.plantilla,
        'color': t.color,
        'plantilla_id': ids.contains(t.plantillaId) ? t.plantillaId : null,
        'padre_id': ids.contains(t.padreId) ? t.padreId : null,
        'nombre': t.nombre,
        'tipo': t.tipo,
        'marca': t.marca,
        'modelo': t.modelo,
        'numero_serie': t.numeroSerie,
        'ubicacion': t.ubicacion,
        'notas': t.notas,
        'instalacion': _dia(t.instalacion),
        'ultimo': _dia(t.ultimo),
        'proximo': _dia(t.proximo),
        'solicitud': _dia(t.solicitud),
        'inicio_min': t.inicioMin,
        'ventana_desde_min': t.ventanaDesdeMin,
        'ventana_hasta_min': t.ventanaHastaMin,
        'duracion_min': t.duracionMin,
        'estado_maquina': t.estadoMaquina.index,
        'estado': t.estado.index,
        'criticidad': t.criticidad.index,
        'periodicidad': t.periodicidad.index,
        'activa': t.activa,
        'competencias': t.competencias,
      };
      for (final w in t.trabajadorIds.where(trabajadores.contains)) {
        r['trabajo_trabajadores']!['${t.id}|$w'] = {'trabajo_id': t.id, 'trabajador_id': w, 'empresa_id': e};
      }
      for (final d in t.historial.map(_dia).toSet()) {
        r['trabajo_historial']!['${t.id}|$d'] = {'trabajo_id': t.id, 'dia': d, 'empresa_id': e};
      }
      for (final a in t.automatizaciones) {
        r['automatizaciones']![a.id] = {
          'id': a.id,
          'empresa_id': e,
          'trabajo_id': t.id,
          'nombre': a.nombre,
          'asunto': a.asunto,
          'cuerpo': a.cuerpo,
          'activa': a.activa,
          'a_trabajadores': a.aTrabajadores,
          'a_cliente': a.aCliente,
          'disparador': a.disparador.index,
          'cantidad': a.cantidad,
          'en_horas': a.enHoras,
          'extras': a.extras,
        };
      }
    }
    return r;
  }
}

/// Lo que se lee de la base al entrar.
class DatosNube {
  final List<Cliente> clientes;
  final List<Trabajador> trabajadores;
  final List<EtiquetaTrabajo> etiquetas;
  final List<Tarea> tareas, subtareas;
  const DatosNube({
    required this.clientes,
    required this.trabajadores,
    required this.etiquetas,
    required this.tareas,
    required this.subtareas,
  });
}

/// Día de calendario como lo espera una columna `date`.
String? _dia(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _fecha(dynamic v) => v == null ? null : DateTime.parse(v as String);

Cliente _cliente(Map x) => Cliente(
  id: x['id'],
  nombre: x['nombre'],
  cif: x['cif'],
  direccion: x['direccion'],
  ciudad: x['ciudad'],
  cp: x['cp'],
  provincia: x['provincia'],
  telefono: x['telefono'],
  email: x['email'],
  contacto: x['contacto'],
  telefonoContacto: x['telefono_contacto'],
  notas: x['notas'],
  foto: x['foto'],
  activa: x['activa'],
  fechaAlta: DateTime.parse(x['fecha_alta'] as String).toLocal(),
  color: (x['color'] as num).toInt(),
  lat: (x['lat'] as num?)?.toDouble(),
  lng: (x['lng'] as num?)?.toDouble(),
);

Trabajador _trabajador(Map x) => Trabajador(
  id: x['id'],
  nombre: x['nombre'],
  apellidos: x['apellidos'],
  telefono: x['telefono'],
  email: x['email'],
  info: x['info'],
  titulos: x['titulos'],
  foto: x['foto'],
  competencias: List<String>.from(x['competencias'] as List),
  activo: x['activo'],
  estadoHoy: EstadoHoy.values[x['estado_hoy'] as int],
  color: (x['color'] as num).toInt(),
);

Automatizacion _automatizacion(Map x) => Automatizacion(
  id: x['id'],
  nombre: x['nombre'],
  asunto: x['asunto'],
  cuerpo: x['cuerpo'],
  activa: x['activa'],
  aTrabajadores: x['a_trabajadores'],
  aCliente: x['a_cliente'],
  disparador: Disparador.values[x['disparador'] as int],
  cantidad: x['cantidad'],
  enHoras: x['en_horas'],
  extras: List<String>.from(x['extras'] as List),
);

Tarea _tarea(Map x, List<String> trabajadorIds, List<DateTime> historial, List<Automatizacion> automatizaciones) =>
    Tarea(
      id: x['id'],
      clienteId: x['cliente_id'],
      plantilla: x['plantilla'],
      color: (x['color'] as num?)?.toInt(),
      plantillaId: x['plantilla_id'],
      nombre: x['nombre'],
      tipo: x['tipo'],
      marca: x['marca'],
      modelo: x['modelo'],
      numeroSerie: x['numero_serie'],
      ubicacion: x['ubicacion'],
      notas: x['notas'],
      instalacion: _fecha(x['instalacion']),
      ultimo: _fecha(x['ultimo']),
      proximo: _fecha(x['proximo']),
      solicitud: _fecha(x['solicitud']),
      inicioMin: x['inicio_min'],
      ventanaDesdeMin: x['ventana_desde_min'],
      ventanaHastaMin: x['ventana_hasta_min'],
      duracionMin: x['duracion_min'],
      estadoMaquina: EstadoMaquina.values[x['estado_maquina'] as int],
      estado: EstadoTrabajo.values[x['estado'] as int],
      criticidad: Criticidad.values[x['criticidad'] as int],
      periodicidad: Periodicidad.values[x['periodicidad'] as int],
      activa: x['activa'],
      competencias: List<String>.from(x['competencias'] as List),
      trabajadorIds: trabajadorIds,
      padreId: x['padre_id'],
      historial: historial,
      automatizaciones: automatizaciones,
    );
