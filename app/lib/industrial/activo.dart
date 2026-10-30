import 'dart:math' as math;

import '../models.dart' show TipoMantenimiento;

enum FrecuenciaActivo { sinDefinir, horas, meses, fecha }

/// Máquina o componente de iPultec. Forman un árbol como trabajos y subtrabajos: un activo (sin
/// [padreId]) tiene componentes y cada componente puede tener subcomponentes.
class Activo {
  String id;
  String? padreId;
  String tag, nombre, fabricante, modelo, numeroSerie, division, repuestos, notas;

  /// Horas de uso del contador (la última lectura).
  double horas;
  bool activo;
  FrecuenciaActivo frecuencia;
  double? cadaHoras;
  int? cadaMeses;
  DateTime? fechaMantenimiento, ultimoMantenimiento;
  double horasUltimoMantenimiento, horasUso;
  bool usoSemanal;
  DateTime fechaLectura;

  /// Estado de mantenimiento del activo: preventivo, correctivo no crítico o crítico.
  TipoMantenimiento tipo;

  Activo({
    required this.id,
    this.padreId,
    this.tag = '',
    this.nombre = '',
    this.fabricante = '',
    this.modelo = '',
    this.numeroSerie = '',
    this.division = '',
    this.repuestos = '',
    this.notas = '',
    this.horas = 0,
    this.activo = true,
    this.frecuencia = FrecuenciaActivo.sinDefinir,
    this.cadaHoras,
    this.cadaMeses,
    this.fechaMantenimiento,
    this.ultimoMantenimiento,
    this.horasUltimoMantenimiento = 0,
    this.horasUso = 0,
    this.usoSemanal = false,
    DateTime? fechaLectura,
    this.tipo = TipoMantenimiento.preventivo,
  }) : fechaLectura = fechaLectura ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  /// "CAM-01 · Camión cisterna", o lo que haya.
  String get titulo => [tag, nombre].where((x) => x.isNotEmpty).join(' · ');

  double get horasDesdeMantenimiento => math.max(0, horas - horasUltimoMantenimiento);
  double? get horasRestantes => cadaHoras == null ? null : cadaHoras! - horasDesdeMantenimiento;
  double get usoDiario => usoSemanal ? horasUso / 7 : horasUso;

  /// Se estima desde la fecha de la lectura real. El paso del tiempo no reinicia la cuenta.
  DateTime? get proximoMantenimiento {
    switch (frecuencia) {
      case FrecuenciaActivo.sinDefinir:
        return null;
      case FrecuenciaActivo.fecha:
        return fechaMantenimiento;
      case FrecuenciaActivo.horas:
        if (cadaHoras == null || cadaHoras! <= 0) return null;
        final quedan = horasRestantes!;
        if (quedan <= 0) return fechaLectura;
        if (usoDiario <= 0) return null;
        final dias = quedan / usoDiario;
        if (!dias.isFinite || dias > 3652500) return null;
        final base = DateTime(fechaLectura.year, fechaLectura.month, fechaLectura.day);
        return DateTime(base.year, base.month, base.day + dias.ceil());
      case FrecuenciaActivo.meses:
        if (cadaMeses == null || cadaMeses! <= 0) return null;
        final base = ultimoMantenimiento ?? fechaLectura;
        final mes = DateTime(base.year, base.month + cadaMeses!, 1);
        final ultimoDia = DateTime(mes.year, mes.month + 1, 0).day;
        return DateTime(mes.year, mes.month, math.min(base.day, ultimoDia));
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'padreId': padreId,
    'tag': tag,
    'nombre': nombre,
    'fabricante': fabricante,
    'modelo': modelo,
    'numeroSerie': numeroSerie,
    'division': division,
    'repuestos': repuestos,
    'notas': notas,
    'horas': horas,
    'activo': activo,
    'frecuencia': frecuencia.index,
    'cadaHoras': cadaHoras,
    'cadaMeses': cadaMeses,
    'fechaMantenimiento': fechaMantenimiento?.toIso8601String(),
    'ultimoMantenimiento': ultimoMantenimiento?.toIso8601String(),
    'horasUltimoMantenimiento': horasUltimoMantenimiento,
    'horasUso': horasUso,
    'usoSemanal': usoSemanal,
    'fechaLectura': fechaLectura.toIso8601String(),
    'tipo': tipo.index,
  };

  factory Activo.fromJson(Map<String, dynamic> j) => Activo(
    id: j['id'] as String,
    padreId: j['padreId'] as String?,
    tag: j['tag'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    fabricante: j['fabricante'] as String? ?? '',
    modelo: j['modelo'] as String? ?? '',
    numeroSerie: j['numeroSerie'] as String? ?? '',
    division: j['division'] as String? ?? '',
    repuestos: j['repuestos'] as String? ?? '',
    notas: j['notas'] as String? ?? '',
    horas: (j['horas'] as num? ?? 0).toDouble(),
    activo: j['activo'] as bool? ?? true,
    frecuencia: FrecuenciaActivo.values[j['frecuencia'] as int? ?? 0],
    cadaHoras: (j['cadaHoras'] as num?)?.toDouble(),
    cadaMeses: j['cadaMeses'] as int?,
    fechaMantenimiento: DateTime.tryParse(j['fechaMantenimiento'] as String? ?? ''),
    ultimoMantenimiento: DateTime.tryParse(j['ultimoMantenimiento'] as String? ?? ''),
    horasUltimoMantenimiento: (j['horasUltimoMantenimiento'] as num?)?.toDouble() ?? 0,
    horasUso: (j['horasUso'] as num?)?.toDouble() ?? 0,
    usoSemanal: j['usoSemanal'] as bool? ?? false,
    fechaLectura: DateTime.tryParse(j['fechaLectura'] as String? ?? ''),
    tipo: TipoMantenimiento.values[j['tipo'] as int? ?? 0],
  );

  Activo copia() => Activo.fromJson(toJson());
}
