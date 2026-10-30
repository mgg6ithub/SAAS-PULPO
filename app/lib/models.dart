import 'package:flutter/material.dart';

import 'theme.dart';
import 'marca.dart';

String _s(Map j, String k) => (j[k] ?? '') as String;
DateTime? _d(Map j, String k) => j[k] == null ? null : DateTime.tryParse(j[k] as String);
String? _f(DateTime? d) => d?.toIso8601String();

String inicialesDe(String texto) {
  final p = texto.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p[0][0].toUpperCase();
  return (p[0][0] + p[1][0]).toUpperCase();
}

enum EstadoHoy { disponible, ocupado, ausente }

extension EstadoHoyX on EstadoHoy {
  String get etiqueta => const ['Disponible', 'Ocupado', 'Ausente'][index];
  Color get color => const [P.verde, P.ambar, P.rojo][index];
}

/// Lo urgente que es una tarea. El planificador hace antes las más críticas.
enum Criticidad { critica, alta, media, rutinaria }

extension CriticidadX on Criticidad {
  String get etiqueta => const ['Crítica', 'Alta', 'Media', 'Rutinaria'][index];
  Color get color => const [P.rojo, P.ambar, P.azul, P.gris][index];

  /// Peso para el planificador (cuanto más, antes en el día).
  int get peso => const [8, 4, 2, 1][index];
}

/// En qué punto está un trabajo (se cambia a mano desde listas, bloques y la ficha).
enum EstadoTrabajo { pendiente, enCurso, realizado, noRealizado }

extension EstadoTrabajoX on EstadoTrabajo {
  String get etiqueta => const ['Pendiente', 'En curso', 'Realizado', 'No realizado'][index];
  Color get color => const [P.ambar, P.azul, P.verde, P.rojo][index];
}

enum EstadoMaquina { operativa, revision, averiada }

extension EstadoMaquinaX on EstadoMaquina {
  String get etiqueta => const ['Operativa', 'En revisión', 'Averiada'][index];
  Color get color => const [P.verde, P.ambar, P.rojo][index];
}

/// Tipo de mantenimiento de una OT industrial (iPultec), de menos a más grave. Pultec no lo usa (null).
enum TipoMantenimiento { preventivo, correctivoNoCritico, correctivoCritico }

extension TipoMantenimientoX on TipoMantenimiento {
  String get etiqueta => const ['Preventivo', 'Correctivo no crítico', 'Correctivo crítico'][index];
  String get descripcion => const [
    'Mantenimiento planificado para que el activo siga funcionando.',
    'El activo puede seguir funcionando pero no realizar el mantenimiento puede evolucionar en problemas más graves.',
    'El activo no puede funcionar hasta realizar el mantenimiento.',
  ][index];
  Color get color => const [P.verde, P.ambar, P.rojo][index];
}

/// `unica` va al final para no cambiar los índices ya guardados.
enum Periodicidad { semanal, mensual, trimestral, semestral, anual, unica }

extension PeriodicidadX on Periodicidad {
  String get etiqueta => const ['Semanal', 'Mensual', 'Trimestral', 'Semestral', 'Anual', 'Única'][index];

  /// Días hasta la siguiente; 0 = no se repite.
  int get dias => const [7, 30, 91, 182, 365, 0][index];
  bool get repite => this != Periodicidad.unica;
}

/// Cuándo se dispara una automatización de un trabajo.
enum Disparador { antes, alCompletar, noHecho, alAsignar }

extension DisparadorX on Disparador {
  String get etiqueta => [m('Antes del trabajo'), 'Al completarse', 'Si no se hace a tiempo', 'Al asignar'][index];

  /// Los que llevan un margen en horas o días respecto a la fecha del trabajo.
  bool get llevaMargen => this == Disparador.antes || this == Disparador.noHecho;
}

/// Regla de un trabajo: cuando pasa [disparador] se manda un email a los [destinatarios].
/// Por ahora solo email, y el envío es simulado.
class Automatizacion {
  String id, nombre, asunto, cuerpo;
  bool activa, aTrabajadores, aCliente;
  Disparador disparador;

  /// Margen respecto a la fecha del trabajo: [cantidad] días (o horas si [enHoras]).
  int cantidad;
  bool enHoras;

  /// Direcciones fijas, además de trabajadores y cliente.
  List<String> extras;

  Automatizacion({
    required this.id,
    this.nombre = '',
    this.asunto = '',
    this.cuerpo = '',
    this.activa = true,
    this.aTrabajadores = true,
    this.aCliente = false,
    this.disparador = Disparador.antes,
    this.cantidad = 1,
    this.enHoras = false,
    List<String>? extras,
  }) : extras = extras ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'asunto': asunto,
    'cuerpo': cuerpo,
    'activa': activa,
    'aTrabajadores': aTrabajadores,
    'aCliente': aCliente,
    'disparador': disparador.index,
    'cantidad': cantidad,
    'enHoras': enHoras,
    'extras': extras,
  };

  factory Automatizacion.fromJson(Map<String, dynamic> j) => Automatizacion(
    id: j['id'] as String,
    nombre: j['nombre'] as String? ?? '',
    asunto: j['asunto'] as String? ?? '',
    cuerpo: j['cuerpo'] as String? ?? '',
    activa: j['activa'] as bool? ?? true,
    aTrabajadores: j['aTrabajadores'] as bool? ?? true,
    aCliente: j['aCliente'] as bool? ?? false,
    disparador: Disparador.values[j['disparador'] as int? ?? 0],
    cantidad: j['cantidad'] as int? ?? 1,
    enHoras: j['enHoras'] as bool? ?? false,
    extras: List<String>.from(j['extras'] as List? ?? []),
  );
}

/// Cliente al que se le da mantenimiento: comunidad, colegio, hospital, empresa...
/// Etiqueta con nombre y color, creada por el usuario para marcar trabajos.
class EtiquetaTrabajo {
  String id, nombre;
  int color; // ARGB

  EtiquetaTrabajo({required this.id, this.nombre = '', required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'color': color};

  factory EtiquetaTrabajo.fromJson(Map<String, dynamic> j) =>
      EtiquetaTrabajo(id: j['id'] as String, nombre: j['nombre'] as String? ?? '', color: j['color'] as int);
}

class Cliente {
  String id, nombre, cif, direccion, ciudad, cp, provincia, telefono, email, contacto, telefonoContacto, notas;

  /// Foto o logotipo en PNG base64 (vacío = sin foto).
  String foto;
  bool activa;
  DateTime fechaAlta;
  int color;

  /// Coordenadas de su dirección, para el mapa de la agenda (null = sin ubicar).
  double? lat, lng;

  Cliente({
    required this.id,
    this.nombre = '',
    this.cif = '',
    this.direccion = '',
    this.ciudad = '',
    this.cp = '',
    this.provincia = '',
    this.telefono = '',
    this.email = '',
    this.contacto = '',
    this.telefonoContacto = '',
    this.notas = '',
    this.foto = '',
    this.activa = true,
    DateTime? fechaAlta,
    this.color = 0,
    this.lat,
    this.lng,
  }) : fechaAlta = fechaAlta ?? DateTime.now();

  bool get ubicado => lat != null && lng != null;

  /// Dirección completa en una línea, para buscarla en el mapa.
  String get direccionCompleta => [
    direccion,
    [cp, ciudad].where((x) => x.isNotEmpty).join(' '),
    provincia,
  ].where((x) => x.isNotEmpty).join(', ');

  String get iniciales => inicialesDe(nombre);

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'cif': cif,
    'direccion': direccion,
    'ciudad': ciudad,
    'cp': cp,
    'provincia': provincia,
    'telefono': telefono,
    'email': email,
    'contacto': contacto,
    'telefonoContacto': telefonoContacto,
    'notas': notas,
    'foto': foto,
    'activa': activa,
    'fechaAlta': _f(fechaAlta),
    'color': color,
    'lat': lat,
    'lng': lng,
  };

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
    id: _s(j, 'id'),
    nombre: _s(j, 'nombre'),
    cif: _s(j, 'cif'),
    direccion: _s(j, 'direccion'),
    ciudad: _s(j, 'ciudad'),
    cp: _s(j, 'cp'),
    provincia: _s(j, 'provincia'),
    telefono: _s(j, 'telefono'),
    email: _s(j, 'email'),
    contacto: _s(j, 'contacto'),
    telefonoContacto: _s(j, 'telefonoContacto'),
    notas: _s(j, 'notas'),
    foto: _s(j, 'foto'),
    activa: j['activa'] as bool? ?? true,
    fechaAlta: _d(j, 'fechaAlta'),
    color: j['color'] as int? ?? 0,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );

  Cliente copia() => Cliente.fromJson(toJson());
}

class Trabajador {
  String id, nombre, apellidos, telefono, email, info, titulos;

  /// Foto en PNG base64 (vacío = sin foto).
  String foto;
  List<String> competencias;
  bool activo;
  EstadoHoy estadoHoy;
  int color;

  /// De dónde sale y adónde vuelve cada día (su casa o la oficina); vacío = el almacén.
  String salida;
  double? salidaLat, salidaLng;

  Trabajador({
    required this.id,
    this.nombre = '',
    this.apellidos = '',
    this.telefono = '',
    this.email = '',
    this.info = '',
    this.titulos = '',
    this.foto = '',
    List<String>? competencias,
    this.activo = true,
    this.estadoHoy = EstadoHoy.disponible,
    this.color = 0,
    this.salida = '',
    this.salidaLat,
    this.salidaLng,
  }) : competencias = competencias ?? [];

  String get nombreCompleto => '$nombre $apellidos'.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'apellidos': apellidos,
    'telefono': telefono,
    'email': email,
    'info': info,
    'titulos': titulos,
    'foto': foto,
    'competencias': competencias,
    'activo': activo,
    'estadoHoy': estadoHoy.index,
    'color': color,
    'salida': salida,
    'salidaLat': salidaLat,
    'salidaLng': salidaLng,
  };

  factory Trabajador.fromJson(Map<String, dynamic> j) => Trabajador(
    id: _s(j, 'id'),
    nombre: _s(j, 'nombre'),
    apellidos: _s(j, 'apellidos'),
    telefono: _s(j, 'telefono'),
    email: _s(j, 'email'),
    info: _s(j, 'info'),
    titulos: _s(j, 'titulos'),
    foto: _s(j, 'foto'),
    competencias: List<String>.from(j['competencias'] as List? ?? []),
    activo: j['activo'] as bool? ?? true,
    estadoHoy: EstadoHoy.values[j['estadoHoy'] as int? ?? 0],
    color: j['color'] as int? ?? 0,
    salida: _s(j, 'salida'),
    salidaLat: (j['salidaLat'] as num?)?.toDouble(),
    salidaLng: (j['salidaLng'] as num?)?.toDouble(),
  );

  Trabajador copia() => Trabajador.fromJson(toJson());
}

/// Tarea de mantenimiento sobre una máquina. Sin cliente = plantilla.
class Tarea {
  String id, nombre, tipo, marca, modelo, numeroSerie, ubicacion, notas;
  String? clienteId, plantillaId;

  /// Equipo del cliente sobre el que se hace (ascensor, caldera…); null = sin equipo.
  String? equipoId;

  /// OT industrial (iPultec): su tipo de mantenimiento; null en Pultec.
  TipoMantenimiento? tipoMantenimiento;

  /// OT industrial: activo o componente sobre el que se hace (null = sin activo, siempre en Pultec).
  String? activoId;
  DateTime? instalacion, ultimo, proximo;

  /// Cuándo pidió el cliente este mantenimiento.
  DateTime? solicitud;

  /// Hora de inicio el día del próximo mantenimiento, en minutos desde las 00:00 (null = sin hora).
  int? inicioMin;

  /// Fijado a su hora y su técnico: el planificador no lo mueve.
  bool fijado;

  /// Franja horaria en la que se puede hacer (minutos desde las 00:00); null = hora exacta o sin hora.
  int? ventanaDesdeMin, ventanaHastaMin;

  bool get conFranja => ventanaDesdeMin != null && ventanaHastaMin != null;

  /// Lo que se calcula que dura, en minutos.
  int duracionMin;
  EstadoMaquina estadoMaquina;
  EstadoTrabajo estado;
  Criticidad criticidad;
  Periodicidad periodicidad;
  bool activa;
  List<String> competencias, trabajadorIds;

  /// Si es un subtrabajo, el trabajo (o subtrabajo) del que cuelga. Los subtrabajos viven en
  /// `store.subtareas`, no en `store.tareas`, y comparten el cliente de su trabajo raíz.
  String? padreId;

  /// Días en que se hizo (el más reciente al final).
  List<DateTime> historial;

  /// Reglas que mandan emails cuando pasa algo de este trabajo.
  List<Automatizacion> automatizaciones;

  /// Lo que se cobra cada vez que se hace, sin IVA (0 = sin precio), y su % de IVA. Solo lo ve el administrador.
  double precio, iva;

  Tarea({
    required this.id,
    this.clienteId,
    this.equipoId,
    this.tipoMantenimiento,
    this.activoId,
    bool? plantilla,
    this.color,
    this.plantillaId,
    this.nombre = '',
    this.tipo = 'Otro',
    this.marca = '',
    this.modelo = '',
    this.numeroSerie = '',
    this.ubicacion = '',
    this.notas = '',
    this.instalacion,
    this.ultimo,
    this.proximo,
    this.solicitud,
    this.inicioMin,
    this.fijado = false,
    this.ventanaDesdeMin,
    this.ventanaHastaMin,
    this.duracionMin = 60,
    this.estadoMaquina = EstadoMaquina.operativa,
    this.estado = EstadoTrabajo.pendiente,
    this.criticidad = Criticidad.media,
    this.periodicidad = Periodicidad.mensual,
    this.activa = true,
    List<String>? competencias,
    List<String>? trabajadorIds,
    this.padreId,
    List<DateTime>? historial,
    List<Automatizacion>? automatizaciones,
    this.precio = 0,
    this.iva = 21,
  }) : plantilla = plantilla ?? clienteId == null,
       competencias = competencias ?? [],
       trabajadorIds = trabajadorIds ?? [],
       historial = historial ?? [],
       automatizaciones = automatizaciones ?? [];

  /// Es una plantilla (modelo para crear tareas). Antes se deducía de no tener cliente;
  /// ahora es un dato propio, así una tarea puede existir sin cliente.
  bool plantilla;
  bool get esPlantilla => plantilla;

  /// Color elegido para su bloque en el calendario (ARGB); null = el de su tipo.
  int? color;
  Color get colorBloque => color != null ? Color(color!) : tipoDe(tipo).color;

  /// Completada ese día: se hizo ese día y no es un día futuro (lo futuro siempre está pendiente).
  bool hechaEl(DateTime dia) => ultimo != null && DateUtils.isSameDay(ultimo, dia) && diasHasta(dia) <= 0;

  int? get finMin => inicioMin == null ? null : inicioMin! + duracionMin;

  /// Fin contando el retraso medio habitual de su tipo, para no encajar otra tarea demasiado pegada.
  int? get finConMargenMin => finMin == null ? null : finMin! + tipoDe(tipo).retrasoMin;

  /// "12:00–13:30", o null si no tiene hora.
  String? get horario => inicioMin == null ? null : '${hhmm(inicioMin!)}–${hhmm(finMin!)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'equipoId': equipoId,
    if (tipoMantenimiento != null) 'tipoMantenimiento': tipoMantenimiento!.index,
    if (activoId != null) 'activoId': activoId,
    'plantilla': plantilla,
    'color': color,
    'plantillaId': plantillaId,
    'nombre': nombre,
    'tipo': tipo,
    'marca': marca,
    'modelo': modelo,
    'numeroSerie': numeroSerie,
    'ubicacion': ubicacion,
    'notas': notas,
    'instalacion': _f(instalacion),
    'ultimo': _f(ultimo),
    'proximo': _f(proximo),
    'solicitud': _f(solicitud),
    'inicioMin': inicioMin,
    'fijado': fijado,
    'ventanaDesdeMin': ventanaDesdeMin,
    'ventanaHastaMin': ventanaHastaMin,
    'duracionMin': duracionMin,
    'estadoMaquina': estadoMaquina.index,
    'estado': estado.index,
    'criticidad': criticidad.index,
    'periodicidad': periodicidad.index,
    'activa': activa,
    'competencias': competencias,
    'trabajadorIds': trabajadorIds,
    'padreId': padreId,
    'historial': [for (final d in historial) _f(d)],
    'automatizaciones': [for (final a in automatizaciones) a.toJson()],
    'precio': precio,
    'iva': iva,
  };

  factory Tarea.fromJson(Map<String, dynamic> j) => Tarea(
    id: _s(j, 'id'),
    clienteId: j['clienteId'] as String?,
    equipoId: j['equipoId'] as String?,
    tipoMantenimiento: j['tipoMantenimiento'] == null
        ? null
        : TipoMantenimiento.values[j['tipoMantenimiento'] as int],
    activoId: j['activoId'] as String?,
    plantilla: j['plantilla'] as bool?,
    color: j['color'] as int?,
    plantillaId: j['plantillaId'] as String?,
    nombre: _s(j, 'nombre'),
    tipo: _s(j, 'tipo'),
    marca: _s(j, 'marca'),
    modelo: _s(j, 'modelo'),
    numeroSerie: _s(j, 'numeroSerie'),
    ubicacion: _s(j, 'ubicacion'),
    notas: _s(j, 'notas'),
    instalacion: _d(j, 'instalacion'),
    ultimo: _d(j, 'ultimo'),
    proximo: _d(j, 'proximo'),
    solicitud: _d(j, 'solicitud'),
    inicioMin: j['inicioMin'] as int?,
    fijado: j['fijado'] as bool? ?? false,
    ventanaDesdeMin: j['ventanaDesdeMin'] as int?,
    ventanaHastaMin: j['ventanaHastaMin'] as int?,
    duracionMin: j['duracionMin'] as int? ?? 60,
    estadoMaquina: EstadoMaquina.values[j['estadoMaquina'] as int? ?? 0],
    estado: EstadoTrabajo.values[j['estado'] as int? ?? 0],
    criticidad: Criticidad.values[j['criticidad'] as int? ?? 2],
    periodicidad: Periodicidad.values[j['periodicidad'] as int? ?? 1],
    activa: j['activa'] as bool? ?? true,
    competencias: List<String>.from(j['competencias'] as List? ?? []),
    trabajadorIds: List<String>.from(j['trabajadorIds'] as List? ?? []),
    padreId: j['padreId'] as String?,
    historial: [for (final x in j['historial'] as List? ?? []) DateTime.parse(x as String)],
    automatizaciones: [for (final x in j['automatizaciones'] as List? ?? []) Automatizacion.fromJson(x)],
    precio: (j['precio'] as num? ?? 0).toDouble(),
    iva: (j['iva'] as num? ?? 21).toDouble(),
  );

  Tarea copia() => Tarea.fromJson(toJson());
}

// ── Fechas ───────────────────────────────────────────────

DateTime hoy() => DateUtils.dateOnly(DateTime.now());

int diasHasta(DateTime d) => DateUtils.dateOnly(d).difference(hoy()).inDays;

String fecha(DateTime? d) =>
    d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String relativo(DateTime d) {
  final n = diasHasta(d);
  if (n == 0) return 'Hoy';
  if (n == 1) return 'Mañana';
  if (n == -1) return 'Ayer';
  return n > 0 ? 'En $n días' : 'Hace ${-n} días';
}

/// Equipo de un cliente (un ascensor, una caldera, un extintor): tiene vida propia, trabajos que se hacen
/// sobre él, documentos y vencimientos legales.
class Equipo {
  String id, clienteId, tipo, nombre, marca, modelo, numeroSerie, ubicacion, notas;
  DateTime? instalacion;
  EstadoMaquina estado;

  /// Rutas de sus documentos en el bucket `documentos` (certificados, libro de mantenimiento, fotos).
  List<String> documentos;

  Equipo({
    required this.id,
    required this.clienteId,
    this.tipo = 'Otro',
    this.nombre = '',
    this.marca = '',
    this.modelo = '',
    this.numeroSerie = '',
    this.ubicacion = '',
    this.notas = '',
    this.instalacion,
    this.estado = EstadoMaquina.operativa,
    List<String>? documentos,
  }) : documentos = documentos ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'tipo': tipo,
    'nombre': nombre,
    'marca': marca,
    'modelo': modelo,
    'numeroSerie': numeroSerie,
    'ubicacion': ubicacion,
    'notas': notas,
    'instalacion': _f(instalacion),
    'estado': estado.index,
    'documentos': documentos,
  };

  factory Equipo.fromJson(Map<String, dynamic> j) => Equipo(
    id: _s(j, 'id'),
    clienteId: _s(j, 'clienteId'),
    tipo: j['tipo'] as String? ?? 'Otro',
    nombre: _s(j, 'nombre'),
    marca: _s(j, 'marca'),
    modelo: _s(j, 'modelo'),
    numeroSerie: _s(j, 'numeroSerie'),
    ubicacion: _s(j, 'ubicacion'),
    notas: _s(j, 'notas'),
    instalacion: _d(j, 'instalacion'),
    estado: EstadoMaquina.values[j['estado'] as int? ?? 0],
    documentos: List<String>.from(j['documentos'] as List? ?? []),
  );

  Equipo copia() => Equipo.fromJson(toJson());
}

/// Vencimiento legal de un equipo (inspección OCA, revisión obligatoria, certificado): avisa
/// [avisarDias] antes de [vence].
class Vencimiento {
  String id, equipoId, nombre;
  DateTime vence;
  int avisarDias;

  Vencimiento({required this.id, required this.equipoId, this.nombre = '', required this.vence, this.avisarDias = 30});

  /// Vencido, o dentro del plazo de aviso.
  bool get avisar => diasHasta(vence) <= avisarDias;

  Map<String, dynamic> toJson() => {
    'id': id,
    'equipoId': equipoId,
    'nombre': nombre,
    'vence': _f(vence),
    'avisarDias': avisarDias,
  };

  factory Vencimiento.fromJson(Map<String, dynamic> j) => Vencimiento(
    id: _s(j, 'id'),
    equipoId: _s(j, 'equipoId'),
    nombre: _s(j, 'nombre'),
    vence: _d(j, 'vence') ?? DateTime.now(),
    avisarDias: j['avisarDias'] as int? ?? 30,
  );
}

/// Minutos desde las 00:00 → "09:05".
String hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Suma días de calendario (sumar una Duration falla con el cambio de hora).
DateTime masDias(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
