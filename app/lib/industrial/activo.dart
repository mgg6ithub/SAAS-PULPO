/// Máquina o componente de iPultec. Forman un árbol como trabajos y subtrabajos: un activo (sin
/// [padreId]) tiene componentes y cada componente puede tener subcomponentes.
class Activo {
  String id;
  String? padreId;
  String tag, nombre, fabricante, modelo, numeroSerie, division, repuestos, notas;

  /// Horas de uso del contador (la última lectura).
  double horas;
  bool activo;

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
  });

  /// "CAM-01 · Camión cisterna", o lo que haya.
  String get titulo => [tag, nombre].where((x) => x.isNotEmpty).join(' · ');

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
  );

  Activo copia() => Activo.fromJson(toJson());
}
