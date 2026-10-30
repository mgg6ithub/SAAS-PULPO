import 'package:flutter/material.dart';

/// Catálogo estable: se guarda la clave, no el código interno de la fuente.
const iconosIndustriales = <(String, String, IconData)>[
  ('brazo', 'Brazo industrial', Icons.precision_manufacturing_outlined),
  ('camion', 'Camión', Icons.local_shipping_outlined),
  ('fabrica', 'Máquina industrial', Icons.factory_outlined),
  ('motor', 'Motor', Icons.settings_outlined),
  ('compresor', 'Compresor', Icons.air_rounded),
  ('bomba', 'Bomba de agua', Icons.water_drop_outlined),
  ('electrico', 'Equipo eléctrico', Icons.electrical_services_outlined),
  ('herramientas', 'Herramientas', Icons.handyman_outlined),
  ('mantenimiento', 'Equipo de mantenimiento', Icons.build_outlined),
  ('tractor', 'Tractor', Icons.agriculture_outlined),
  ('combustible', 'Depósito de combustible', Icons.local_gas_station_outlined),
  ('medidor', 'Medidor', Icons.speed_outlined),
];

IconData iconoIndustrial(String clave) =>
    iconosIndustriales.firstWhere((i) => i.$1 == clave, orElse: () => iconosIndustriales.first).$3;
