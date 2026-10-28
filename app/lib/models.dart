import 'package:flutter/material.dart';

import 'theme.dart';

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

enum EstadoMaquina { operativa, revision, averiada }

extension EstadoMaquinaX on EstadoMaquina {
  String get etiqueta => const ['Operativa', 'En revisión', 'Averiada'][index];
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
  );

  Trabajador copia() => Trabajador.fromJson(toJson());
}

/// Tarea de mantenimiento sobre una máquina. Sin cliente = plantilla.
class Tarea {
  String id, nombre, tipo, marca, modelo, numeroSerie, ubicacion, notas;
  String? clienteId, plantillaId;
  DateTime? instalacion, ultimo, proximo;

  /// Cuándo pidió el cliente este mantenimiento.
  DateTime? solicitud;

  /// Hora de inicio el día del próximo mantenimiento, en minutos desde las 00:00 (null = sin hora).
  int? inicioMin;

  /// Franja horaria en la que se puede hacer (minutos desde las 00:00); null = hora exacta o sin hora.
  int? ventanaDesdeMin, ventanaHastaMin;

  bool get conFranja => ventanaDesdeMin != null && ventanaHastaMin != null;

  /// Lo que se calcula que dura, en minutos.
  int duracionMin;
  EstadoMaquina estadoMaquina;
  Criticidad criticidad;
  Periodicidad periodicidad;
  bool activa;
  List<String> competencias, trabajadorIds;

  /// Si es un subtrabajo, el trabajo (o subtrabajo) del que cuelga. Los subtrabajos viven en
  /// `store.subtareas`, no en `store.tareas`, y comparten el cliente de su trabajo raíz.
  String? padreId;

  /// Días en que se hizo (el más reciente al final).
  List<DateTime> historial;

  Tarea({
    required this.id,
    this.clienteId,
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
    this.ventanaDesdeMin,
    this.ventanaHastaMin,
    this.duracionMin = 60,
    this.estadoMaquina = EstadoMaquina.operativa,
    this.criticidad = Criticidad.media,
    this.periodicidad = Periodicidad.mensual,
    this.activa = true,
    List<String>? competencias,
    List<String>? trabajadorIds,
    this.padreId,
    List<DateTime>? historial,
  }) : plantilla = plantilla ?? clienteId == null,
       competencias = competencias ?? [],
       trabajadorIds = trabajadorIds ?? [],
       historial = historial ?? [];

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
    'ventanaDesdeMin': ventanaDesdeMin,
    'ventanaHastaMin': ventanaHastaMin,
    'duracionMin': duracionMin,
    'estadoMaquina': estadoMaquina.index,
    'criticidad': criticidad.index,
    'periodicidad': periodicidad.index,
    'activa': activa,
    'competencias': competencias,
    'trabajadorIds': trabajadorIds,
    'padreId': padreId,
    'historial': [for (final d in historial) _f(d)],
  };

  factory Tarea.fromJson(Map<String, dynamic> j) => Tarea(
    id: _s(j, 'id'),
    clienteId: j['clienteId'] as String?,
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
    ventanaDesdeMin: j['ventanaDesdeMin'] as int?,
    ventanaHastaMin: j['ventanaHastaMin'] as int?,
    duracionMin: j['duracionMin'] as int? ?? 60,
    estadoMaquina: EstadoMaquina.values[j['estadoMaquina'] as int? ?? 0],
    criticidad: Criticidad.values[j['criticidad'] as int? ?? 2],
    periodicidad: Periodicidad.values[j['periodicidad'] as int? ?? 1],
    activa: j['activa'] as bool? ?? true,
    competencias: List<String>.from(j['competencias'] as List? ?? []),
    trabajadorIds: List<String>.from(j['trabajadorIds'] as List? ?? []),
    padreId: j['padreId'] as String?,
    historial: [for (final x in j['historial'] as List? ?? []) DateTime.parse(x as String)],
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

/// Minutos desde las 00:00 → "09:05".
String hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Suma días de calendario (sumar una Duration falla con el cambio de hora).
DateTime masDias(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
