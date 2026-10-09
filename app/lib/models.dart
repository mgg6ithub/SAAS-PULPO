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

enum EstadoMaquina { operativa, revision, averiada }

extension EstadoMaquinaX on EstadoMaquina {
  String get etiqueta => const ['Operativa', 'En revisión', 'Averiada'][index];
  Color get color => const [P.verde, P.ambar, P.rojo][index];
}

enum Periodicidad { semanal, mensual, trimestral, semestral, anual }

extension PeriodicidadX on Periodicidad {
  String get etiqueta => const ['Semanal', 'Mensual', 'Trimestral', 'Semestral', 'Anual'][index];
  int get dias => const [7, 30, 91, 182, 365][index];
}

/// Cliente al que se le da mantenimiento: comunidad, colegio, hospital, empresa...
class Cliente {
  String id, nombre, cif, direccion, ciudad, cp, provincia, telefono, email, contacto, telefonoContacto, notas;
  bool activa;
  DateTime fechaAlta;
  int color;

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
    this.activa = true,
    DateTime? fechaAlta,
    this.color = 0,
  }) : fechaAlta = fechaAlta ?? DateTime.now();

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
    'activa': activa,
    'fechaAlta': _f(fechaAlta),
    'color': color,
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
    activa: j['activa'] as bool? ?? true,
    fechaAlta: _d(j, 'fechaAlta'),
    color: j['color'] as int? ?? 0,
  );

  Cliente copia() => Cliente.fromJson(toJson());
}

class Trabajador {
  String id, nombre, apellidos, telefono, email, info, titulos;
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

  /// Lo que se calcula que dura, en minutos.
  int duracionMin;
  EstadoMaquina estadoMaquina;
  Periodicidad periodicidad;
  bool activa;
  List<String> competencias, trabajadorIds;

  Tarea({
    required this.id,
    this.clienteId,
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
    this.duracionMin = 60,
    this.estadoMaquina = EstadoMaquina.operativa,
    this.periodicidad = Periodicidad.mensual,
    this.activa = true,
    List<String>? competencias,
    List<String>? trabajadorIds,
  }) : competencias = competencias ?? [],
       trabajadorIds = trabajadorIds ?? [];

  bool get esPlantilla => clienteId == null;

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
    'duracionMin': duracionMin,
    'estadoMaquina': estadoMaquina.index,
    'periodicidad': periodicidad.index,
    'activa': activa,
    'competencias': competencias,
    'trabajadorIds': trabajadorIds,
  };

  factory Tarea.fromJson(Map<String, dynamic> j) => Tarea(
    id: _s(j, 'id'),
    clienteId: j['clienteId'] as String?,
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
    duracionMin: j['duracionMin'] as int? ?? 60,
    estadoMaquina: EstadoMaquina.values[j['estadoMaquina'] as int? ?? 0],
    periodicidad: Periodicidad.values[j['periodicidad'] as int? ?? 1],
    activa: j['activa'] as bool? ?? true,
    competencias: List<String>.from(j['competencias'] as List? ?? []),
    trabajadorIds: List<String>.from(j['trabajadorIds'] as List? ?? []),
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
