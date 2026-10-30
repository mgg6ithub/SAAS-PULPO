import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Lo grave que es una avería: con los mismos colores que los tipos de mantenimiento.
enum Gravedad { leve, media, grave }

extension GravedadX on Gravedad {
  String get etiqueta => const ['Leve', 'Media', 'Grave'][index];
  Color get color => const [P.verde, P.ambar, P.rojo][index];

  /// El tipo de la OT que la arregla: grave = el activo no puede funcionar.
  TipoMantenimiento get tipo =>
      this == Gravedad.grave ? TipoMantenimiento.correctivoCritico : TipoMantenimiento.correctivoNoCritico;
}

/// `conOt`: ya tiene una OT que la arregla ([Incidencia.trabajoId]).
enum EstadoIncidencia { abierta, conOt, cerrada }

extension EstadoIncidenciaX on EstadoIncidencia {
  String get etiqueta => const ['Abierta', 'Con OT', 'Cerrada'][index];
  Color get color => [P.rojo, P.azul, P.gris][index];
}

/// Aviso de avería de un activo o componente de iPultec, con su gravedad y fotos. Puede acabar en una OT.
class Incidencia {
  String id, activoId, descripcion;
  String? trabajoId;
  Gravedad gravedad;
  EstadoIncidencia estado;
  List<String> fotos;
  DateTime creada;

  Incidencia({
    required this.id,
    required this.activoId,
    this.trabajoId,
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
    descripcion: j['descripcion'] as String? ?? '',
    gravedad: Gravedad.values[j['gravedad'] as int? ?? 1],
    estado: EstadoIncidencia.values[j['estado'] as int? ?? 0],
    fotos: List<String>.from(j['fotos'] as List? ?? []),
    creada: DateTime.parse(j['creada'] as String),
  );

  Incidencia copia() => Incidencia.fromJson(toJson());
}
