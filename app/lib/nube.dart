import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'en_vivo.dart';
import 'informes.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart' show TipoInfo, tipos, competencias;

const supabaseUrl = 'https://gvasthxiqckmekwvhtrg.supabase.co';

/// Clave publicable: está pensada para ir dentro de la app. La secreta (`service_role`) nunca.
const supabasePublicable = 'sb_publishable_jGH8ZqhOiUZOttnNh8AOSg_BHvqppBQ';

/// El enlace de invitación ya se usó, caducó o no existe.
class InvitacionNoValida implements Exception {
  const InvitacionNoValida();
}

/// La empresa se quedaría sin administrador (quitar o degradar al último, o borrar su cuenta).
class UltimoAdministrador implements Exception {
  const UltimoAdministrador();
}

/// Una cuenta con acceso a la empresa.
typedef Acceso = ({String usuarioId, String correo, String nombre, String rol, String? trabajadorId});

/// Invitación sin usar y sin caducar.
typedef InvitacionPendiente = ({String id, String codigo, String rol, String? trabajadorId, DateTime caduca});

/// Datos que el [Store] tenía cargados y que se guardan en Supabase.
typedef _Filas = Map<String, Map<String, Map<String, dynamic>>>;

/// Conexión con Supabase para una cuenta y una empresa: lee todo al entrar y, después, guarda solo lo que cambia.
class Nube {
  Nube._(
    this.empresaId, {
    required this.nueva,
    this.nombre = '',
    this.tipo = '',
    this.rol = 'admin',
    this.trabajadorId,
  });

  final String empresaId;

  /// Nombre de la empresa, para enseñarlo en Mi cuenta.
  final String nombre;

  /// A qué se dedica (clave de [tiposEmpresa]): una empresa nueva arranca solo con sus plantillas.
  final String tipo;

  /// Tipos de empresa al crearla → tipo de las plantillas con las que arranca (null = todas).
  static const tiposEmpresa = <String, String?>{
    'Ascensores': 'Ascensor',
    'Calderas': 'Caldera',
    'Jardinería': 'Jardinería',
    'Limpieza': 'Limpieza',
    'Varios': null,
  };

  bool get esAdmin => rol == 'admin';

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

  /// Cambia cada vez que hay que volver a abrir la empresa (se ha cambiado, creado o borrado una).
  static final reabrir = ValueNotifier<int>(0);

  /// Empresa recién creada desde la cuenta: al abrirla arranca con sus plantillas.
  static String? _recienCreada;

  /// Entra en la empresa de la cuenta (primero acepta la invitación, si trae una): la última elegida o, si no,
  /// una donde sea administradora. Si no tiene ninguna, crea una y la hace administradora.
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
    final ms = await _db
        .from('miembros')
        .select('empresa_id, rol, trabajador_id')
        .eq('usuario_id', _db.auth.currentUser!.id);
    if (ms.isNotEmpty) {
      final elegida = (await SharedPreferences.getInstance()).getString('pulpo_empresa');
      final m = ms.firstWhere(
        (x) => x['empresa_id'] == elegida,
        orElse: () => ms.firstWhere((x) => x['rol'] == 'admin', orElse: () => ms.first),
      );
      final id = m['empresa_id'] as String;
      final e = await _db.from('empresas').select('nombre, tipo').eq('id', id).single();
      final nueva = id == _recienCreada;
      _recienCreada = null;
      return _abierta = Nube._(
        id,
        nueva: nueva,
        nombre: e['nombre'] as String,
        tipo: e['tipo'] as String,
        rol: m['rol'] as String,
        trabajadorId: m['trabajador_id'] as String?,
      );
    }
    final e = await _db.from('empresas').insert({'nombre': 'Mi empresa'}).select('id').single();
    final id = e['id'] as String;
    await _db.from('miembros').insert({'usuario_id': _db.auth.currentUser!.id, 'empresa_id': id, 'rol': 'admin'});
    creadaAlEntrar = true;
    return _abierta = Nube._(id, nueva: true, nombre: 'Mi empresa');
  }

  /// La cuenta no tenía empresa ni invitación y se le acaba de crear una (se avisa al entrar).
  static bool creadaAlEntrar = false;

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
  Future<Informe> crearInforme(Informe i, List<Uint8List> fotos, Uint8List? firma, {String? id}) async {
    await _cola;
    id ??= store.nuevoId();
    Future<String> subir(String nombre, Uint8List bytes, String tipo) async {
      final ruta = '$empresaId/informes/$id/$nombre';
      try {
        await _db.storage.from(_bucket).uploadBinary(ruta, bytes, fileOptions: FileOptions(contentType: tipo));
      } on StorageException catch (e) {
        // Ya subida en un intento anterior que se cortó (sin conexión): vale la que hay.
        if (e.statusCode != '409' && !e.message.contains('already exists')) rethrow;
      }
      _fotos[ruta] = Future.value(bytes);
      return ruta;
    }

    final rutas = [for (var n = 0; n < fotos.length; n++) await subir('$n.jpg', fotos[n], 'image/jpeg')];
    final rutaFirma = firma == null ? null : await subir('firma.png', firma, 'image/png');
    final x = await _db
        .from('informes')
        .upsert({
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
        }, onConflict: 'id', ignoreDuplicates: true)
        .select('created_at');
    return i.guardado(
      id: id,
      fotos: rutas,
      firma: rutaFirma,
      cuando: x.isEmpty ? i.cuando : DateTime.parse(x.first['created_at'] as String).toLocal(),
    );
  }

  /// Manda al cliente el PDF del parte (función `enviar-parte`); la función no lo repite si ya se mandó.
  Future<void> enviarParte(String informeId, Uint8List pdf) =>
      _db.functions.invoke('enviar-parte', body: {'informe_id': informeId, 'pdf': base64Encode(pdf)});

  // ── Documentos de los equipos ──

  static const _bucketDocumentos = 'documentos';

  /// Tipos que admite el bucket `documentos`.
  static const extensionesDocumento = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

  /// Sube un documento (certificado, libro de mantenimiento, foto) a `<empresa>/equipos/<equipo>/<nombre>`
  /// y devuelve su ruta. Con el mismo nombre, lo sustituye.
  Future<String> subirDocumentoEquipo(String equipoId, String nombre, Uint8List bytes) async {
    final ruta = '$empresaId/equipos/$equipoId/$nombre';
    final tipo = switch (nombre.split('.').last.toLowerCase()) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await _db.storage
        .from(_bucketDocumentos)
        .uploadBinary(ruta, bytes, fileOptions: FileOptions(contentType: tipo, upsert: true));
    return ruta;
  }

  Future<Uint8List> documentoEquipo(String ruta) => _db.storage.from(_bucketDocumentos).download(ruta);

  Future<void> borrarDocumentoEquipo(String ruta) => _db.storage.from(_bucketDocumentos).remove([ruta]);

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

  static Future<void> cerrarSesion({bool enTodos = false}) async {
    await _abierta?._cola;
    await _abierta?._enVivo?.parar();
    await _db.auth.signOut(scope: enTodos ? SignOutScope.global : SignOutScope.local);
  }

  // ── Cuenta ──

  static String? get correo => _db.auth.currentUser?.email;

  /// Nombre y foto de la cuenta (vacío si aún no los ha puesto).
  static Future<({String nombre, String? foto})> perfil() async {
    final r = await _db.from('perfiles').select('nombre, foto').eq('usuario_id', _db.auth.currentUser!.id);
    return r.isEmpty
        ? (nombre: '', foto: null)
        : (nombre: r.first['nombre'] as String, foto: r.first['foto'] as String?);
  }

  /// El perfil ya existe: lo crea la base al crear la cuenta (trigger `copiar_correo`).
  static Future<void> guardarPerfil({required String nombre, String? foto}) =>
      _db.from('perfiles').update({'nombre': nombre, 'foto': foto}).eq('usuario_id', _db.auth.currentUser!.id);

  static Future<void> cambiarClave(String nueva) => _db.auth.updateUser(UserAttributes(password: nueva));

  /// Supabase manda un enlace al correo nuevo; el cambio vale al pulsarlo.
  static Future<void> cambiarCorreo(String nuevo) =>
      _db.auth.updateUser(UserAttributes(email: nuevo), emailRedirectTo: _aqui());

  /// Manda el correo de «olvidé mi contraseña»; el enlace vuelve a la app para poner una nueva.
  static Future<void> recuperarClave(String correo) => _db.auth.resetPasswordForEmail(correo, redirectTo: _aqui());

  /// Crea la cuenta; el enlace del correo de confirmación vuelve a esta misma dirección de la app.
  static Future<AuthResponse> crearCuenta(String correo, String clave) =>
      _db.auth.signUp(email: correo, password: clave, emailRedirectTo: _aqui());

  /// Entra con Google (DEV-012): sale a Google y vuelve a esta misma dirección con la sesión puesta. Si ya hay
  /// una cuenta con ese correo, Supabase enlaza las dos (Google verifica el correo).
  static Future<void> entrarConGoogle() => _db.auth.signInWithOAuth(OAuthProvider.google, redirectTo: _aqui());

  /// Vuelve a mandar el correo de confirmar la cuenta.
  static Future<void> reenviarConfirmacion(String correo) =>
      _db.auth.resend(type: OtpType.signup, email: correo, emailRedirectTo: _aqui());

  static String _aqui() => Uri.base.removeFragment().replace(queryParameters: {}).toString();

  /// Borra la cuenta y las empresas donde es el único miembro (función `borrar-cuenta`), y cierra la sesión.
  static Future<void> borrarCuenta() async {
    await _abierta?._cola;
    try {
      await _db.functions.invoke('borrar-cuenta');
    } on FunctionException catch (e) {
      if (e.status == 409) throw const UltimoAdministrador();
      rethrow;
    }
    await _db.auth.signOut(scope: SignOutScope.local);
  }

  // ── Empresas ──

  /// Empresas de la cuenta con su rol, por nombre.
  static Future<List<({String id, String nombre, String rol})>> empresas() async {
    final ms = await _db
        .from('miembros')
        .select('empresa_id, rol, empresas(nombre)')
        .eq('usuario_id', _db.auth.currentUser!.id);
    return [
      for (final m in ms)
        (id: m['empresa_id'] as String, nombre: (m['empresas'] as Map)['nombre'] as String, rol: m['rol'] as String),
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  /// Cambia a otra empresa de la cuenta (se recuerda para la próxima vez).
  static Future<void> entrarEn(String empresaId) async {
    await _abierta?._cola;
    await (await SharedPreferences.getInstance()).setString('pulpo_empresa', empresaId);
    reabrir.value++;
  }

  /// Crea otra empresa, la hace administradora y entra en ella.
  static Future<void> crearEmpresa(String nombre, String tipo) async {
    final e = await _db.from('empresas').insert({'nombre': nombre, 'tipo': tipo}).select('id').single();
    final id = e['id'] as String;
    await _db.from('miembros').insert({'usuario_id': _db.auth.currentUser!.id, 'empresa_id': id, 'rol': 'admin'});
    _recienCreada = id;
    await entrarEn(id);
  }

  /// Nombre, tipo, CIF, dirección, teléfono y logo de la empresa abierta.
  Future<Map<String, dynamic>> datosEmpresa() =>
      _db.from('empresas').select('nombre, tipo, cif, direccion, telefono, logo').eq('id', empresaId).single();

  Future<void> guardarEmpresa(Map<String, dynamic> datos) async {
    await _db.from('empresas').update(datos).eq('id', empresaId);
    reabrir.value++; // el nombre sale en Mi cuenta y en la barra
  }

  // ── Accesos (solo administradores) ──

  /// Quién tiene cuenta en la empresa: primero los administradores, luego por nombre o correo.
  Future<List<Acceso>> accesos() async {
    final ms = await _db.from('miembros').select('usuario_id, rol, trabajador_id').eq('empresa_id', empresaId);
    final ids = [for (final m in ms) m['usuario_id'] as String];
    final ps = {
      for (final p in await _db.from('perfiles').select('usuario_id, correo, nombre').inFilter('usuario_id', ids))
        p['usuario_id'] as String: p,
    };
    return [
      for (final m in ms)
        (
          usuarioId: m['usuario_id'] as String,
          correo: ps[m['usuario_id']]?['correo'] as String? ?? '',
          nombre: ps[m['usuario_id']]?['nombre'] as String? ?? '',
          rol: m['rol'] as String,
          trabajadorId: m['trabajador_id'] as String?,
        ),
    ]..sort((a, b) {
      if (a.rol != b.rol) return a.rol == 'admin' ? -1 : 1;
      return (a.nombre.isEmpty ? a.correo : a.nombre).toLowerCase().compareTo(
        (b.nombre.isEmpty ? b.correo : b.nombre).toLowerCase(),
      );
    });
  }

  /// Cambia el rol de una cuenta (un trabajador va siempre ligado a su ficha).
  Future<void> cambiarRol(String usuarioId, String rol, {String? trabajadorId}) => _protegido(
    _db
        .from('miembros')
        .update({'rol': rol, 'trabajador_id': trabajadorId == null ? null : _u(trabajadorId)})
        .eq('empresa_id', empresaId)
        .eq('usuario_id', usuarioId),
  );

  Future<void> quitarAcceso(String usuarioId) =>
      _protegido(_db.from('miembros').delete().eq('empresa_id', empresaId).eq('usuario_id', usuarioId));

  /// La base no deja quitar ni degradar al último administrador (trigger `proteger_ultimo_admin`).
  static Future<void> _protegido(Future<void> f) async {
    try {
      await f;
    } on PostgrestException catch (e) {
      if (e.hint == 'ultimo_admin') throw const UltimoAdministrador();
      rethrow;
    }
  }

  Future<List<InvitacionPendiente>> invitacionesPendientes() async {
    final r = await _db
        .from('invitaciones')
        .select('id, codigo, rol, trabajador_id, caduca_en')
        .eq('empresa_id', empresaId)
        .isFilter('usada_por', null)
        .gt('caduca_en', DateTime.now().toUtc().toIso8601String())
        .order('created_at');
    return [
      for (final x in r)
        (
          id: x['id'] as String,
          codigo: x['codigo'] as String,
          rol: x['rol'] as String,
          trabajadorId: x['trabajador_id'] as String?,
          caduca: DateTime.parse(x['caduca_en'] as String).toLocal(),
        ),
    ];
  }

  /// La ficha [fichaId] del [Store] es la que la base llama [idBase] (las simulaciones usan ids cortos).
  bool esFicha(String fichaId, String? idBase) => idBase != null && _u(fichaId) == idBase;

  Future<void> anularInvitacion(String id) => _db.from('invitaciones').delete().eq('id', id);

  /// Borra la empresa abierta con todo lo suyo y pasa a otra (o a una nueva si no queda ninguna).
  Future<void> borrarEmpresa() async {
    await _cola;
    await _db.from('empresas').delete().eq('id', empresaId);
    await (await SharedPreferences.getInstance()).remove('pulpo_empresa');
    reabrir.value++;
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
      _todo('tipos_trabajo'),
      _todo('competencias'),
      _todo('equipos'),
      _todo('vencimientos'),
      // El trabajador no ve precios: la base le devuelve la lista vacía.
      _db.from('trabajo_precios').select('trabajo_id, precio, iva').eq('empresa_id', empresaId),
    ]);
    final precioDe = {for (final x in r[11]) x['trabajo_id'] as String: x};
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
      tipos: [
        for (final x in [...r[7]]..sort((a, b) => (a['orden'] as int).compareTo(b['orden'] as int)))
          TipoInfo(
            x['id'],
            x['nombre'],
            x['clave'],
            Color((x['color'] as num).toInt()),
            x['competencia'],
            x['retraso_min'],
          ),
      ],
      competencias: [
        for (final x in [...r[8]]..sort((a, b) => (a['orden'] as int).compareTo(b['orden'] as int)))
          x['nombre'] as String,
      ],
      equipos: [
        for (final x in r[9])
          Equipo(
            id: x['id'],
            clienteId: x['cliente_id'],
            tipo: x['tipo'],
            nombre: x['nombre'],
            marca: x['marca'],
            modelo: x['modelo'],
            numeroSerie: x['numero_serie'],
            ubicacion: x['ubicacion'],
            notas: x['notas'],
            instalacion: _fecha(x['instalacion']),
            estado: EstadoMaquina.values[x['estado'] as int],
            documentos: List<String>.from(x['documentos'] as List),
          ),
      ],
      vencimientos: [
        for (final x in r[10])
          Vencimiento(
            id: x['id'],
            equipoId: x['equipo_id'],
            nombre: x['nombre'],
            vence: DateTime.parse(x['vence'] as String),
            avisarDias: x['avisar_dias'],
          ),
      ],
    );
  }

  /// Borra de la base TODO lo de la empresa (también lo que el [Store] no conozca) y no deja nada pendiente.
  /// Después el [Store] vuelve a su estado inicial.
  Future<void> vaciar() async {
    await _cola;
    for (final t in [
      'documentos',
      'trabajos',
      'equipos',
      'clientes',
      'trabajadores',
      'etiquetas',
      'tipos_trabajo',
      'competencias',
    ]) {
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
    'tipos_trabajo',
    'competencias',
    'equipos',
    'vencimientos',
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
    final envio = ++_envios;
    _reintento?.cancel();
    // Se apunta en el dispositivo antes de mandarlo: si se cierra la app sin conexión, se sube al volver.
    _apuntarPendiente(subir, borrar);
    _cola = _cola.then((_) async {
      if (error.value != null) subiendo.value = 'Subiendo cambios…';
      try {
        await _subir(subir, borrar);
        _enviado
          ..clear()
          ..addAll({
            for (final t in _orden) t: {for (final e in ahora[t]!.entries) e.key: jsonEncode(e.value)},
          });
        if (envio == _envios) await _apuntarPendiente(const {}, const {});
        error.value = null;
      } catch (e) {
        debugPrint('Pulpo: no se pudo guardar en Supabase: $e');
        error.value = sinConexion(e)
            ? 'Sin conexión. Los cambios se guardan aquí y se subirán al volver.'
            : 'No se pudo guardar. Se reintentará solo.';
        _reintento = Timer(const Duration(seconds: 10), sincronizar);
      } finally {
        subiendo.value = null;
      }
    });
  }

  /// Manda a la base las filas cambiadas y borra las quitadas, en orden.
  Future<void> _subir(Map<String, List<Map<String, dynamic>>> subir, Map<String, List<String>> borrar) async {
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
  }

  // ── Sin conexión ──

  /// «Subiendo cambios…» mientras se sube lo que antes no se pudo guardar (null = nada).
  static final subiendo = ValueNotifier<String?>(null);

  /// El fallo es de red (sin cobertura o el servidor no responde), no de la base.
  static bool sinConexion(Object e) =>
      e is TimeoutException ||
      e is AuthRetryableFetchException ||
      e is RealtimeSubscribeException ||
      RegExp(r'SocketException|ClientException|Failed to fetch|Connection|XMLHttpRequest').hasMatch('$e');

  String get _clavePendiente => 'pulpo_pendiente_$empresaId';

  Future<void> _apuntarPendiente(Map<String, List<Map<String, dynamic>>> subir, Map<String, List<String>> borrar) async {
    final prefs = await SharedPreferences.getInstance();
    if (subir.isEmpty && borrar.isEmpty) {
      await prefs.remove(_clavePendiente);
    } else {
      await prefs.setString(_clavePendiente, jsonEncode({'subir': subir, 'borrar': borrar}));
    }
  }

  /// Sube lo que quedó sin guardar en este dispositivo la última vez (sin conexión). Si sigue sin haber
  /// conexión, falla y no se abre la empresa.
  Future<void> subirPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    final j = prefs.getString(_clavePendiente);
    if (j == null) return;
    final p = jsonDecode(j) as Map<String, dynamic>;
    await _subir(
      {
        for (final e in (p['subir'] as Map<String, dynamic>).entries)
          e.key: [for (final f in e.value as List) Map<String, dynamic>.from(f as Map)],
      },
      {for (final e in (p['borrar'] as Map<String, dynamic>).entries) e.key: List<String>.from(e.value as List)},
    );
    await prefs.remove(_clavePendiente);
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
        final remoto = _filas(Store()..ponerDeLaNube(d));
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
    'tipos_trabajo': 'id',
    'competencias': 'id',
    'equipos': 'id',
    'vencimientos': 'id',
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
    final equipos = {for (final x in s.equipos) x.id};
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
        'salida': w.salida,
        'salida_lat': w.salidaLat,
        'salida_lng': w.salidaLng,
        'color': w.color,
      };
    }
    for (final x in s.etiquetas) {
      r['etiquetas']![_u(x.id)] = {'id': _u(x.id), 'empresa_id': e, 'nombre': x.nombre, 'color': x.color};
    }
    for (final (i, x) in tipos.indexed) {
      r['tipos_trabajo']![_u(x.id)] = {
        'id': _u(x.id),
        'empresa_id': e,
        'nombre': x.nombre,
        'clave': x.clave,
        'color': x.color.toARGB32(),
        'competencia': x.competencia,
        'retraso_min': x.retrasoMin,
        'orden': i,
      };
    }
    for (final x in s.equipos.where((x) => clientes.contains(x.clienteId))) {
      r['equipos']![_u(x.id)] = {
        'id': _u(x.id),
        'empresa_id': e,
        'cliente_id': _u(x.clienteId),
        'tipo': x.tipo,
        'nombre': x.nombre,
        'marca': x.marca,
        'modelo': x.modelo,
        'numero_serie': x.numeroSerie,
        'ubicacion': x.ubicacion,
        'notas': x.notas,
        'instalacion': _dia(x.instalacion),
        'estado': x.estado.index,
        'documentos': x.documentos,
      };
    }
    for (final x in s.vencimientos.where((x) => equipos.contains(x.equipoId))) {
      r['vencimientos']![_u(x.id)] = {
        'id': _u(x.id),
        'empresa_id': e,
        'equipo_id': _u(x.equipoId),
        'nombre': x.nombre,
        'vence': _dia(x.vence),
        'avisar_dias': x.avisarDias,
      };
    }
    // Una fila por competencia; su id sale del nombre (renombrar = quitar una y poner otra).
    for (final (i, n) in competencias.indexed) {
      final id = _u('competencia:$n');
      r['competencias']![id] = {'id': id, 'empresa_id': e, 'nombre': n, 'orden': i};
    }
    for (final t in trabajos) {
      r['trabajos']![_u(t.id)] = {
        'id': _u(t.id),
        'empresa_id': e,
        'cliente_id': clientes.contains(t.clienteId) ? _u(t.clienteId!) : null,
        'equipo_id': equipos.contains(t.equipoId) ? _u(t.equipoId!) : null,
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
        'fijado': t.fijado,
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

  /// Vacíos = la empresa aún no los ha guardado: se usan los de partida.
  final List<TipoInfo> tipos;
  final List<String> competencias;
  final List<Equipo> equipos;
  final List<Vencimiento> vencimientos;
  const DatosNube({
    required this.clientes,
    required this.trabajadores,
    required this.etiquetas,
    required this.tareas,
    required this.subtareas,
    this.tipos = const [],
    this.competencias = const [],
    this.equipos = const [],
    this.vencimientos = const [],
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
  salida: x['salida'] as String? ?? '',
  salidaLat: (x['salida_lat'] as num?)?.toDouble(),
  salidaLng: (x['salida_lng'] as num?)?.toDouble(),
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
      equipoId: x['equipo_id'],
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
      fijado: x['fijado'] as bool? ?? false,
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
