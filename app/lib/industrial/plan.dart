import '../models.dart';

/// Mantenimiento periódico de un activo o componente de iPultec: cada cuántos días u horas toca, de qué
/// tipo es, qué categoría de técnico puede hacerlo, con qué repuestos y cómo. De él salen las OT.
class PlanMantenimiento {
  String id, activoId, nombre, descripcion, categoria, repuestos, procedimiento;
  TipoMantenimiento tipo;

  /// Cada cuántos días o cada cuántas horas de uso (lo que llegue antes); null = sin ese límite.
  int? cadaDias, cadaHoras;
  int duracionMin;
  DateTime? ultimo, proximo;
  double? ultimoHoras;
  bool activa;

  PlanMantenimiento({
    required this.id,
    required this.activoId,
    this.nombre = '',
    this.descripcion = '',
    this.tipo = TipoMantenimiento.preventivo,
    this.cadaDias,
    this.cadaHoras,
    this.categoria = '',
    this.repuestos = '',
    this.procedimiento = '',
    this.duracionMin = 60,
    this.ultimo,
    this.ultimoHoras,
    this.proximo,
    this.activa = true,
  });

  /// "Cada 90 días · cada 500 h", o lo que haya.
  String get cada => [
    if (cadaDias != null) 'cada $cadaDias ${cadaDias == 1 ? 'día' : 'días'}',
    if (cadaHoras != null) 'cada $cadaHoras h',
  ].join(' · ');

  /// La periodicidad de la OT que sale de aquí: la fija que coincide con [cadaDias], o única.
  Periodicidad get periodicidad =>
      Periodicidad.values.firstWhere((p) => p.repite && p.dias == cadaDias, orElse: () => Periodicidad.unica);

  /// Borrador de la OT de este mantenimiento, para revisarla y guardarla en el formulario de OT.
  Tarea ot(String id) => Tarea(
    id: id,
    nombre: nombre,
    activoId: activoId,
    // Sin cliente sería plantilla: una OT de un activo es un trabajo de verdad.
    plantilla: false,
    tipoMantenimiento: tipo,
    proximo: proximo ?? hoy(),
    periodicidad: periodicidad,
    criticidad: Criticidad.rutinaria,
    duracionMin: duracionMin,
    competencias: [if (categoria.isNotEmpty) categoria],
    notas: [procedimiento, if (repuestos.isNotEmpty) 'Repuestos: $repuestos'].where((x) => x.isNotEmpty).join('\n\n'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'activoId': activoId,
    'nombre': nombre,
    'descripcion': descripcion,
    'tipo': tipo.index,
    'cadaDias': cadaDias,
    'cadaHoras': cadaHoras,
    'categoria': categoria,
    'repuestos': repuestos,
    'procedimiento': procedimiento,
    'duracionMin': duracionMin,
    'ultimo': ultimo?.toIso8601String(),
    'ultimoHoras': ultimoHoras,
    'proximo': proximo?.toIso8601String(),
    'activa': activa,
  };

  factory PlanMantenimiento.fromJson(Map<String, dynamic> j) => PlanMantenimiento(
    id: j['id'] as String,
    activoId: j['activoId'] as String,
    nombre: j['nombre'] as String? ?? '',
    descripcion: j['descripcion'] as String? ?? '',
    tipo: TipoMantenimiento.values[j['tipo'] as int? ?? 0],
    cadaDias: j['cadaDias'] as int?,
    cadaHoras: j['cadaHoras'] as int?,
    categoria: j['categoria'] as String? ?? '',
    repuestos: j['repuestos'] as String? ?? '',
    procedimiento: j['procedimiento'] as String? ?? '',
    duracionMin: j['duracionMin'] as int? ?? 60,
    ultimo: j['ultimo'] == null ? null : DateTime.parse(j['ultimo'] as String),
    ultimoHoras: (j['ultimoHoras'] as num?)?.toDouble(),
    proximo: j['proximo'] == null ? null : DateTime.parse(j['proximo'] as String),
    activa: j['activa'] as bool? ?? true,
  );

  PlanMantenimiento copia() => PlanMantenimiento.fromJson(toJson());
}
