import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Lo grave que es una avería: con los mismos colores que los tipos de mantenimiento.
enum Gravedad { leve, media, grave }

extension GravedadX on Gravedad {
  /// Los mismos nombres que la criticidad de los mantenimientos y las OT.
  String get etiqueta => const ['Correctivo no crítico', 'Correctivo no crítico', 'Correctivo crítico'][index];
  Color get color => const [P.ambar, P.ambar, P.rojo][index];

  /// El tipo de la OT que la arregla: grave = el activo no puede funcionar.
  TipoMantenimiento get tipo =>
      this == Gravedad.grave ? TipoMantenimiento.correctivoCritico : TipoMantenimiento.correctivoNoCritico;
}

/// `conOt`: ya tiene una OT que la arregla ([Incidencia.trabajoId]); `completada`: esa OT se cerró;
/// `desestimada`: se cerró sin hacer nada.
enum EstadoIncidencia { abierta, conOt, completada, desestimada }

extension EstadoIncidenciaX on EstadoIncidencia {
  String get etiqueta => const ['Abierta', 'Con OT', 'Completada', 'Desestimada'][index];
  // Cada estado, su icono (sin los puntos de la criticidad).
  // Completada en verde y desestimada en rojo (también sus iconos en los filtros).
  Color get color => [P.rojo, P.azul, P.verde, P.rojo][index];
  IconData get icono => const [
    Icons.report_outlined,
    Icons.assignment_outlined,
    Icons.task_alt_rounded,
    Icons.block_rounded,
  ][index];

  /// Abierta o con OT: aún hay algo que hacer.
  bool get pendiente => index < 2;
}

/// Aviso de avería de un activo o componente de Pultec, con su gravedad y fotos. Puede acabar en una OT.
class Incidencia {
  String id, activoId, descripcion;
  String? trabajoId, tecnicoId, origenTrabajoId, creadaPor;

  /// Mantenimiento vinculado: al completarse la incidencia, la base reinicia su contador.
  String? planId;

  /// Cuándo se completó o se desestimó.
  DateTime? cerradaEl;

  /// Última corrección de quien la comunicó (null = nunca editada).
  DateTime? editadaEl;
  Gravedad gravedad;
  EstadoIncidencia estado;
  List<String> fotos;
  DateTime creada;

  Incidencia({
    required this.id,
    required this.activoId,
    this.trabajoId,
    this.tecnicoId,
    this.origenTrabajoId,
    this.creadaPor,
    this.planId,
    this.cerradaEl,
    this.editadaEl,
    this.descripcion = '',
    this.gravedad = Gravedad.media,
    this.estado = EstadoIncidencia.abierta,
    List<String>? fotos,
    DateTime? creada,
  }) : fotos = fotos ?? [],
       creada = creada ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'activoId': activoId,
    'trabajoId': trabajoId,
    'tecnicoId': tecnicoId,
    'origenTrabajoId': origenTrabajoId,
    'creadaPor': creadaPor,
    'planId': planId,
    'cerradaEl': cerradaEl?.toIso8601String(),
    'editadaEl': editadaEl?.toIso8601String(),
    'descripcion': descripcion,
    'gravedad': gravedad.index,
    'estado': estado.index,
    'fotos': fotos,
    'creada': creada.toIso8601String(),
  };

  factory Incidencia.fromJson(Map<String, dynamic> j) => Incidencia(
    id: j['id'] as String,
    activoId: j['activoId'] as String,
    trabajoId: j['trabajoId'] as String?,
    tecnicoId: j['tecnicoId'] as String?,
    origenTrabajoId: j['origenTrabajoId'] as String?,
    creadaPor: j['creadaPor'] as String?,
    planId: j['planId'] as String?,
    cerradaEl: j['cerradaEl'] == null ? null : DateTime.parse(j['cerradaEl'] as String),
    editadaEl: j['editadaEl'] == null ? null : DateTime.parse(j['editadaEl'] as String),
    descripcion: j['descripcion'] as String? ?? '',
    gravedad: Gravedad.values[j['gravedad'] as int? ?? 1],
    estado: EstadoIncidencia.values[j['estado'] as int? ?? 0],
    fotos: List<String>.from(j['fotos'] as List? ?? []),
    creada: DateTime.parse(j['creada'] as String),
  );

  Incidencia copia() => Incidencia.fromJson(toJson());
}
