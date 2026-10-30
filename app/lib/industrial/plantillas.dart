import '../models.dart';

/// Catálogo inicial industrial; conserva los ids al adaptar las cuatro plantillas antiguas.
List<Tarea> plantillasIndustriales() => [
  Tarea(
    id: 'p1',
    nombre: 'Camión',
    tipo: 'Camión',
    plantilla: true,
    periodicidad: Periodicidad.mensual,
    competencias: ['Mecánica'],
    notas: 'Revisar motor, niveles, filtros, frenos y neumáticos.',
  ),
  Tarea(
    id: 'p2',
    nombre: 'Prensa hidráulica',
    tipo: 'Prensa',
    plantilla: true,
    periodicidad: Periodicidad.mensual,
    competencias: ['Hidráulica'],
    notas: 'Comprobar presión, fugas, protecciones y parada de emergencia.',
  ),
  Tarea(
    id: 'p3',
    nombre: 'Equipo de agua a presión',
    tipo: 'Agua a presión',
    plantilla: true,
    periodicidad: Periodicidad.mensual,
    competencias: ['Mecánica'],
    notas: 'Revisar bomba, mangueras, boquillas y presión de trabajo.',
  ),
  Tarea(
    id: 'p4',
    nombre: 'Compresor',
    tipo: 'Compresor',
    plantilla: true,
    periodicidad: Periodicidad.trimestral,
    competencias: ['Neumática'],
    notas: 'Revisar filtros, lubricación, purga y válvula de seguridad.',
  ),
];

/// Solo las plantillas de serie: las personalizadas y las OT existentes se conservan.
List<Tarea> adaptarPlantillasIndustriales(List<Tarea> tareas) {
  const anteriores = [
    'Revisión caldera de gas',
    'Mantenimiento de ascensor',
    'Poda y riego de zonas verdes',
    'Limpieza de rellanos y portal',
  ];
  const tiposAnteriores = ['Caldera', 'Ascensor', 'Jardinería', 'Limpieza'];
  final nuevas = plantillasIndustriales();
  return tareas.map((t) {
    final i = anteriores.indexOf(t.nombre);
    if (!t.esPlantilla || i < 0 || t.tipo != tiposAnteriores[i]) return t;
    return nuevas[i].copia()..id = t.id;
  }).toList();
}
