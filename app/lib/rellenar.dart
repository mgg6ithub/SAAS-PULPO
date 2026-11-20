import 'dart:math';

/// Botón «Rellenar» de las ventanas de crear (solo al desarrollar): datos de prueba al azar para no escribirlo
/// todo a mano. Los nombres nunca se repiten con lo que ya hay.
final azar = Random();

T alAzar<T>(List<T> xs) => xs[azar.nextInt(xs.length)];

/// [base] si nadie lo usa; si no, «base 2», «base 3»… (sin distinguir mayúsculas).
String unico(String base, Iterable<String> usados, {String separador = ' '}) {
  final ya = {for (final u in usados) u.trim().toLowerCase()};
  if (!ya.contains(base.toLowerCase())) return base;
  for (var i = 2; ; i++) {
    final n = '$base$separador$i';
    if (!ya.contains(n.toLowerCase())) return n;
  }
}

const maquinasPrueba = [
  ('Camión cisterna', 'CAM', 'Transporte de residuos líquidos'),
  ('Compresor de tornillo', 'CMP', 'Aire comprimido para la planta'),
  ('Prensa hidráulica', 'PRE', 'Estampación de piezas'),
  ('Carretilla elevadora', 'CAR', 'Movimiento de palés en almacén'),
  ('Bomba centrífuga', 'BOM', 'Trasiego de agua de proceso'),
  ('Caldera de vapor', 'CAL', 'Vapor para limpieza de tanques'),
  ('Grupo electrógeno', 'GEN', 'Energía de emergencia'),
];

const componentesPrueba = [
  ('Motor', 'MOT'),
  ('Ruedas', 'RUE'),
  ('Correa de transmisión', 'COR'),
  ('Filtro de aire', 'FIL'),
  ('Bomba de vacío', 'BVA'),
  ('Frenos', 'FRE'),
  ('Rodamientos', 'ROD'),
];

const fabricantesPrueba = [
  ('Volvo', 'FH 500'),
  ('Scania', 'R450'),
  ('Atlas Copco', 'GA 37'),
  ('Toyota', '8FBE15'),
  ('Grundfos', 'CR 32'),
  ('Caterpillar', 'DE110'),
];

const mantenimientosPrueba = [
  ('Cambio de aceite', 'Vaciar, cambiar filtro y rellenar'),
  ('Revisión de frenos', 'Pastillas, discos y circuito'),
  ('Engrase general', 'Puntos de engrase según manual'),
  ('Cambio de filtros', 'Aire, aceite y combustible'),
  ('Inspección de correas', 'Tensión y desgaste'),
  ('Limpieza de radiador', 'Soplar y revisar fugas'),
];

const nombresPrueba = ['Ana', 'Luis', 'Marta', 'Jorge', 'Lucía', 'Pablo', 'Elena', 'Iker', 'Sara', 'Diego'];
const apellidosPrueba = ['García', 'Martínez', 'López', 'Sánchez', 'Pérez', 'Gómez', 'Ruiz', 'Díaz', 'Moreno'];

String telefonoPrueba() => '6${List.generate(8, (_) => azar.nextInt(10)).join()}';
