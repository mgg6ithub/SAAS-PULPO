import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'en_vivo.dart';
import 'informes.dart';
import 'models.dart';
import 'store.dart';

const supabaseUrl = 'https://gvasthxiqckmekwvhtrg.supabase.co';

/// Clave publicable: está pensada para ir dentro de la app. La secreta (`service_role`) nunca.
const supabasePublicable = 'sb_publishable_jGH8ZqhOiUZOttnNh8AOSg_BHvqppBQ';

/// El enlace de invitación ya se usó, caducó o no existe.
class InvitacionNoValida implements Exception {
  const InvitacionNoValida();
}

/// Datos que el [Store] tenía cargados y que se guardan en Supabase.
typedef _Filas = Map<String, Map<String, Map<String, dynamic>>>;

/// Conexión con Supabase para una cuenta y una empresa: lee todo al entrar y, después, guarda solo lo que cambia.
class Nube {
  Nube._(this.empresaId, {required this.nueva, this.nombre = '', this.rol = 'admin', this.trabajadorId});

  final String empresaId;

  /// Nombre de la empresa, para enseñarlo en Mi cuenta.
  final String nombre;

  /// `admin` (todo) o `trabajador` (solo sus trabajos, el resto lo recorta la base de datos).
  final String rol;

  /// Ficha del trabajador (solo con rol `trabajador`).
  final String? trabajadorId;

  bool get esTrabajador => rol == 'trabajador';

  /// La empresa se acaba de crear: el [Store] la rellena con las plantillas iniciales.
  final bool nueva;

  /// Último fallo al guardar (null = todo guardado). Se vuelve a intentar solo.
  static final error = ValueNotifier<String?>(null);

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> iniciar() => Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublicable);

  /// Código del enlace de invitación (`?invitacion=…`), pendiente de aceptar.
  static String? invitacion;

  /// Guarda el código del enlace (o recupera el último guardado), por si hay que confirmar el correo
  /// y volver a entrar antes de aceptarlo.
  static Future<void> recordarInvitacion(String? delEnlace) async {
    final prefs = await SharedPreferences.getInstance();
    if (delEnlace != null && delEnlace.isNotEmpty) await prefs.setString('pulpo_invitacion', delEnlace);
    invitacion = prefs.getString('pulpo_invitacion');
  }

  static Future<void> _olvidarInvitacion() async {
    invitacion = null;
    await (await SharedPreferences.getInstance()).remove('pulpo_invitacion');
  }

  /// Entra en la empresa de la cuenta (primero acepta la invitación, si trae una). Si no tiene ninguna,
  /// crea una y la hace administradora.
  static Future<Nube> abrir() async {
    if (invitacion != null) {
      try {
        await _db.rpc('aceptar_invitacion', params: {'p_codigo': invitacion});
      } on PostgrestException catch (e) {
        if (e.code == 'P0001') {
          await _olvidarInvitacion();
          throw const InvitacionNoValida();
        }
        rethrow;
      }
      await _olvidarInvitacion();
    }
    await _abierta?._enVivo?.parar();
    final ms = await _db.from('miembros').select('empresa_id, rol, trabajador_id');
    if (ms.isNotEmpty) {
      final m = ms.firstWhere((x) => x['rol'] == 'admin', orElse: () => ms.first);
      final id = m['empresa_id'] as String;
      final e = await _db.from('empresas').select('nombre').eq('id', id).single();
      return _abierta = Nube._(
        id,
        nueva: false,
        nombre: e['nombre'] as String,
        rol: m['rol'] as String,
        trabajadorId: m['trabajador_id'] as String?,
      );
    }
    final e = await _db.from('empresas').insert({'nombre': 'Mi empresa'}).select('id').single();
    final id = e['id'] as String;
    await _db.from('miembros').insert({'usuario_id': _db.auth.currentUser!.id, 'empresa_id': id, 'rol': 'admin'});
    return _abierta = Nube._(id, nueva: true, nombre: 'Mi empresa');
  }

  /// Crea una invitación de un solo uso (7 días) y devuelve su código. Las fichas pendientes de guardar
  /// se esperan antes, porque la invitación apunta a una.
  Future<String> crearInvitacion({required String rol, String? trabajadorId}) async {
    await _cola;
    final r = await _db
        .from('invitaciones')
        .insert({'empresa_id': empresaId, 'rol': rol, if (trabajadorId != null) 'trabajador_id': _u(trabajadorId)})
        .select('codigo')
        .single();
    return r['codigo'] as String;
  }

  /// Últimos emails de las automatizaciones de un trabajo: a quién, cómo fue y cuándo.
  Future<List<Map<String, dynamic>>> envios(String trabajoId) => _db
      .from('envios_automatizacion')
      .select('destinatario, asunto, estado, error, enviado_en, created_at')
      .eq('trabajo_id', _u(trabajoId))
      .order('created_at', ascending: false)
      .limit(30);

  // ── Informes y fotos ──

  static const _bucket = 'fotos';

  /// La foto ya está en Storage (ruta del bucket) y no en base64. El base64 nunca lleva puntos.
  static bool esRutaFoto(String foto) => foto.endsWith('.png') || foto.endsWith('.jpg');

  static final _fotos = <String, Future<Uint8List>>{};

  /// Bytes de una foto del bucket (se descargan una sola vez).
  Future<Uint8List> foto(String ruta) =>
      _fotos[ruta] ??= _db.storage.from(_bucket).download(ruta).catchError((Object e) {
        _fotos.remove(ruta);
        throw e;
      });

  Future<List<Informe>> informes(String trabajoId) async {
    final r = await _db
        .from('informes')
        .select('id, trabajador_id, resultado, notas, material, minutos, fotos, firma, firmante, created_at')
        .eq('trabajo_id', _u(trabajoId))
        .order('created_at', ascending: false);
    return [
      for (final x in r)
        Informe(
          id: x['id'],
          trabajoId: trabajoId,
          trabajadorId: x['trabajador_id'],
          resultado: x['resultado'],
          notas: x['notas'],
          material: x['material'],
          minutos: x['minutos'],
          fotos: List<String>.from(x['fotos'] as List),
          firma: x['firma'],
          firmante: x['firmante'],
          cuando: DateTime.parse(x['created_at'] as String).toLocal(),
        ),
    ];
  }

  /// Sube las fotos (JPEG) y la firma (PNG) a `<empresa>/informes/<informe>/` y guarda el informe. Espera
  /// antes a que el trabajo esté guardado, porque el informe apunta a él.
  Future<Informe> crearInforme(Informe i, List<Uint8List> fotos, Uint8List? firma) async {
    await _cola;
    final id = store.nuevoId();
    Future<String> subir(String nombre, Uint8List bytes, String tipo) async {
      final ruta = '$empresaId/informes/$id/$nombre';
      await _db.storage.from(_bucket).uploadBinary(ruta, bytes, fileOptions: FileOptions(contentType: tipo));
      _fotos[ruta] = Future.value(bytes);
      return ruta;
    }

    final rutas = [for (var n = 0; n < fotos.length; n++) await subir('$n.jpg', fotos[n], 'image/jpeg')];
    final rutaFirma = firma == null ? null : await subir('firma.png', firma, 'image/png');
    final x = await _db
        .from('informes')
        .insert({
          'id': id,
          'empresa_id': empresaId,
          'trabajo_id': _u(i.trabajoId),
          'trabajador_id': i.trabajadorId == null ? null : _u(i.trabajadorId!),
          'resultado': i.resultado,
          'notas': i.notas,
          'material': i.material,
          'minutos': i.minutos,
          'fotos': rutas,
          'firma': rutaFirma,
          'firmante': i.firmante,
        })
        .select('created_at')
        .single();
    return i.guardado(
      id: id,
      fotos: rutas,
      firma: rutaFirma,
      cuando: DateTime.parse(x['created_at'] as String).toLocal(),
    );
  }

  // ── Presupuestos y facturas proforma ──

  Future<List<Map<String, dynamic>>> documentos() => _todo('documentos');

  /// Crea (sin id) o actualiza un documento y devuelve la fila guardada: al crearlo, la base le pone el número.
  Future<Map<String, dynamic>> guardarDocumento(Map<String, dynamic> fila) async {
    await _cola;
    final f = {
      ...fila,
      'empresa_id': empresaId,
      if (fila['cliente_id'] != null) 'cliente_id': _u(fila['cliente_id'] as String),
    };
    return f['id'] == null
        ? await _db.from('documentos').insert(f..remove('id')).select().single()
        : await _db.from('documentos').update(f).eq('id', f['id']).select().single();
  }

  Future<void> borrarDocumento(String id) => _db.from('documentos').delete().eq('id', id);

  /// Sube a Storage la foto en base64 de una fila de `clientes` o `trabajadores` y devuelve la fila con la
  /// ruta. El nombre sale del contenido, así que reintentar no duplica.
  Future<Map<String, dynamic>> _conFotoSubida(String tabla, Map<String, dynamic> f) async {
    final foto = f['foto'] as String;
    if (foto.isEmpty || esRutaFoto(foto)) return f;
    final bytes = base64Decode(foto);
    final ruta = '$empresaId/$tabla/${md5.convert(bytes)}.png';
    await _db.storage
        .from(_bucket)
        .uploadBinary(ruta, bytes, fileOptions: const FileOptions(contentType: 'image/png', upsert: true));
    _fotos[ruta] = Future.value(bytes);
    return {...f, 'foto': ruta};
  }

  /// Enlace que se manda a quien se invita: abre la app con el código puesto.
  static String enlace(String codigo) =>
      Uri.base.removeFragment().replace(queryParameters: {'invitacion': codigo}).toString();

  /// La última empresa abierta, para no cerrar la sesión con cambios sin guardar.
  static Nube? _abierta;

  static Future<void> cerrarSesion() async {
    await _abierta?._cola;
    await _abierta?._enVivo?.parar();
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
      // El trabajador no ve precios: la base le devuelve la lista vacía.
      _db.from('trabajo_precios').select('trabajo_id, precio, iva').eq('empresa_id', empresaId),
    ]);
    final precioDe = {for (final x in r[7]) x['trabajo_id'] as String: x};
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
      final p = precioDe[id];
      if (p != null) {
        t
          ..precio = (p['precio'] as num).toDouble()
          ..iva = (p['iva'] as num).toDouble();
      }
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

  /// Borra de la base TODO lo de la empresa (también lo que el [Store] no conozca) y no deja nada pendiente.
  /// Después el [Store] vuelve a su estado inicial.
  Future<void> vaciar() async {
    await _cola;
    for (final t in ['documentos', 'trabajos', 'clientes', 'trabajadores', 'etiquetas']) {
      await _db.from(t).delete().eq('empresa_id', empresaId);
    }
    _enviado.clear();
    error.value = null;
  }

  // ── Guardar ──

  /// Lo último que ya está en la base, por tabla y clave (la fila en JSON, para comparar).
  final Map<String, Map<String, String>> _enviado = {};
  Future<void> _cola = Future.value();

  /// Termina cuando todo lo pendiente ya está guardado.
  Future<void> get guardado => _cola;
  Timer? _reintento;
  Store? _store;

  /// Empieza a vigilar el [Store]. Con [vacio] no da nada por guardado y lo sube todo.
  void vincular(Store s, {bool vacio = false}) {
    _store = s;
    _enviado.clear();
    (_enVivo ??= EnVivo(empresaId, _alCambiar)).empezar();
    if (!vacio) {
      _filas(s).forEach(
        (t, filas) => _enviado[t] = {
          for (final e in filas.entries)
            // Fotos antiguas en base64: se dejan sin guardar para que se suban a Storage.
            if (esTrabajador || !_fotoEnBase64(e.value)) e.key: jsonEncode(e.value),
        },
      );
      if (!esTrabajador) sincronizar();
    }
  }

  static bool _fotoEnBase64(Map<String, dynamic> f) {
    final foto = f['foto'];
    return foto is String && foto.isNotEmpty && !esRutaFoto(foto);
  }

  static const _orden = [
    'clientes',
    'trabajadores',
    'etiquetas',
    'trabajos',
    'trabajo_precios',
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
    _envios++;
    _reintento?.cancel();
    _cola = _cola.then((_) async {
      try {
        for (final t in _orden) {
          var filas = subir[t];
          if (filas == null) continue;
          if (esTrabajador) {
            // Solo puede cambiar sus trabajos (estado y fechas) y marcarlos como hechos.
            if (t == 'trabajos') {
              for (final f in filas) {
                await _db.from(t).update(f).eq('id', f['id']);
              }
            } else if (t == 'trabajo_historial') {
              await _db.from(t).upsert(filas, onConflict: _clave[t]!, ignoreDuplicates: true);
            }
            continue;
          }
          if (t == 'clientes' || t == 'trabajadores') {
            filas = [for (final f in filas) await _conFotoSubida(t, f)];
          }
          for (var i = 0; i < filas.length; i += 200) {
            await _db
                .from(t)
                .upsert(filas.sublist(i, i + 200 > filas.length ? filas.length : i + 200), onConflict: _clave[t]!);
          }
        }
        for (final t in _orden.reversed) {
          if (esTrabajador && t != 'trabajo_historial') continue;
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

  // ── En vivo ──

  /// Tablas que otra persona acaba de cambiar (informes y documentos se vuelven a pedir al verlo).
  static final cambiado = ValueNotifier<Set<String>>({});

  /// Otra persona cambió algo que también se estaba cambiando aquí: se queda lo de aquí.
  static final choque = ValueNotifier<String?>(null);

  EnVivo? _enVivo;
  bool _recargando = false, _otraVez = false;

  /// Veces que se ha puesto algo en la cola de guardar: si cambia mientras se lee, la lectura no vale.
  int _envios = 0;

  void _alCambiar(Set<String> tablas) {
    cambiado.value = tablas;
    if (tablas.any(_orden.contains)) _recargar();
  }

  /// Vuelve a leer la empresa y la pone en el [Store]. Lo propio que aún no se ha subido no se pisa: se sube
  /// primero y se vuelve a leer después. Los ecos de lo que se guardó aquí no cambian nada.
  Future<void> _recargar() async {
    if (_recargando) {
      _otraVez = true;
      return;
    }
    _recargando = true;
    try {
      do {
        _otraVez = false;
        await _cola;
        final envios = _envios;
        final s = _store;
        if (s == null) return;
        final d = await cargar();
        if (envios != _envios || _store != s) {
          _otraVez = true;
          continue;
        }
        final remoto = _filas(
          Store()
            ..clientes = d.clientes
            ..trabajadores = d.trabajadores
            ..etiquetas = d.etiquetas
            ..tareas = d.tareas
            ..subtareas = d.subtareas,
        );
        final aqui = _filas(s);
        final visto = _comoClaves(_enviado), base = _comoClaves(remoto), local = _comoClaves(aqui);
        if (mapEquals(visto, base)) continue;
        final pendientes = [
          for (final k in {...visto.keys, ...local.keys})
            if (visto[k] != local[k]) k,
        ];
        if (pendientes.isNotEmpty) {
          if (choques(visto, base, pendientes).isNotEmpty) {
            choque.value = 'Otra persona ha cambiado lo mismo que tú: se ha quedado tu versión.';
            Timer(const Duration(seconds: 6), () => choque.value = null);
          }
          sincronizar();
          _otraVez = true;
          continue;
        }
        s.ponerDeLaNube(d);
        _enviado
          ..clear()
          ..addAll({
            for (final t in _orden) t: {for (final e in remoto[t]!.entries) e.key: jsonEncode(e.value)},
          });
      } while (_otraVez);
    } catch (e) {
      debugPrint('Pulpo: no se pudo leer en vivo: $e');
    } finally {
      _recargando = false;
    }
  }

  /// Filas por `tabla|clave`, en JSON.
  static Map<String, String> _comoClaves(Map<String, Map<String, Object?>> filas) => {
    for (final t in filas.entries)
      for (final f in t.value.entries) '${t.key}|${f.key}': f.value is String ? f.value as String : jsonEncode(f.value),
  };

  static const _clave = {
    'clientes': 'id',
    'trabajadores': 'id',
    'etiquetas': 'id',
    'trabajos': 'id',
    'trabajo_precios': 'trabajo_id',
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
      case 'trabajo_precios':
        return q.eq('trabajo_id', clave);
      default:
        return q.eq('id', clave);
    }
  }

  static final _esUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// Las simulaciones usan ids como `c1` o `d5`: aquí se convierten en un uuid fijo de esta empresa
  /// (las claves de la base son globales, así que dos empresas no pueden compartir `c1`).
  String _u(String id) {
    if (_esUuid.hasMatch(id)) return id;
    final h = md5.convert(utf8.encode('$empresaId:$id')).toString();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-4${h.substring(13, 16)}-8${h.substring(17, 20)}-${h.substring(20)}';
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
      r['clientes']![_u(c.id)] = {
        'id': _u(c.id),
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
      r['trabajadores']![_u(w.id)] = {
        'id': _u(w.id),
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
      r['etiquetas']![_u(x.id)] = {'id': _u(x.id), 'empresa_id': e, 'nombre': x.nombre, 'color': x.color};
    }
    for (final t in trabajos) {
      r['trabajos']![_u(t.id)] = {
        'id': _u(t.id),
        'empresa_id': e,
        'cliente_id': clientes.contains(t.clienteId) ? _u(t.clienteId!) : null,
        'plantilla': t.plantilla,
        'color': t.color,
        'plantilla_id': ids.contains(t.plantillaId) ? _u(t.plantillaId!) : null,
        'padre_id': ids.contains(t.padreId) ? _u(t.padreId!) : null,
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
      if (t.precio > 0) {
        r['trabajo_precios']![_u(t.id)] = {'trabajo_id': _u(t.id), 'empresa_id': e, 'precio': t.precio, 'iva': t.iva};
      }
      for (final w in t.trabajadorIds.where(trabajadores.contains)) {
        r['trabajo_trabajadores']!['${_u(t.id)}|${_u(w)}'] = {
          'trabajo_id': _u(t.id),
          'trabajador_id': _u(w),
          'empresa_id': e,
        };
      }
      for (final d in t.historial.map(_dia).toSet()) {
        r['trabajo_historial']!['${_u(t.id)}|$d'] = {'trabajo_id': _u(t.id), 'dia': d, 'empresa_id': e};
      }
      for (final a in t.automatizaciones) {
        r['automatizaciones']![_u(a.id)] = {
          'id': _u(a.id),
          'empresa_id': e,
          'trabajo_id': _u(t.id),
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
