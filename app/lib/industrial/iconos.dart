import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import '../widgets.dart';

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

/// Catálogo amplio para el botón «+» del formulario, por grupos. Claves estables, como arriba.
const gruposIconos = <(String, List<(String, String, IconData)>)>[
  // Dominion: departamento de petroquímicas y maquinaria industrial pesada. Primero, para tenerlo a mano.
  (
    'Dominion · Petroquímica y maquinaria pesada',
    [
      ('dom_refineria', 'Refinería', Icons.factory_rounded),
      ('dom_planta', 'Planta química', Icons.science_rounded),
      ('dom_barril', 'Barril de crudo', Icons.oil_barrel_rounded),
      ('dom_tanque', 'Tanque de almacenamiento', Icons.propane_tank_rounded),
      ('dom_cisterna', 'Camión cisterna', Icons.local_shipping_rounded),
      ('dom_bomba_crudo', 'Bomba de trasiego', Icons.local_gas_station_rounded),
      ('dom_tuberia', 'Línea de proceso', Icons.plumbing_rounded),
      ('dom_intercambiador', 'Intercambiador de calor', Icons.heat_pump_rounded),
      ('dom_horno', 'Horno de proceso', Icons.local_fire_department_rounded),
      ('dom_antorcha', 'Antorcha', Icons.whatshot_rounded),
      ('dom_reactor', 'Reactor', Icons.blur_circular_rounded),
      ('dom_columna', 'Columna de destilación', Icons.view_agenda_outlined),
      ('dom_separador', 'Separador', Icons.filter_list_rounded),
      ('dom_secador', 'Secador térmico', Icons.dry_rounded),
      ('dom_vapor', 'Línea de vapor', Icons.cloud_queue_rounded),
      ('dom_gas', 'Gas', Icons.gas_meter_outlined),
      ('dom_quimico', 'Producto químico', Icons.biotech_rounded),
      ('dom_peligro', 'Material peligroso', Icons.dangerous_outlined),
      ('dom_atex', 'Zona ATEX', Icons.warning_rounded),
      ('dom_derrame', 'Derrame', Icons.water_damage_rounded),
      ('dom_hidrolimpieza', 'Hidrolimpieza', Icons.shower_rounded),
      ('dom_aspiracion', 'Camión de aspiración', Icons.cyclone_rounded),
      ('dom_soplante', 'Soplante', Icons.wind_power_rounded),
      ('dom_compresor', 'Compresor de proceso', Icons.compress_rounded),
      ('dom_turbina', 'Turbina', Icons.toys_rounded),
      ('dom_grua', 'Grúa pesada', Icons.construction_rounded),
      ('dom_excavadora', 'Maquinaria de obra', Icons.front_loader),
      ('dom_carretilla', 'Carretilla elevadora', Icons.forklift),
      ('dom_andamio', 'Andamio', Icons.grid_on_rounded),
      ('dom_soldadura', 'Soldadura', Icons.flash_on_rounded),
      ('dom_inspeccion', 'Inspección', Icons.manage_search_rounded),
      ('dom_epi', 'EPI / seguridad', Icons.health_and_safety_outlined),
      ('dom_casco', 'Técnico de campo', Icons.engineering_rounded),
      ('dom_contenedor', 'Contenedor de residuos', Icons.delete_sweep_outlined),
      ('dom_puerto', 'Terminal marítima', Icons.anchor_rounded),
      ('dom_generador', 'Grupo electrógeno', Icons.electric_bolt_rounded),
    ],
  ),
  (
    'Maquinaria',
    [
      ('maq_robot', 'Robot', Icons.smart_toy_outlined),
      ('maq_engranajes', 'Engranajes', Icons.settings_suggest_outlined),
      ('maq_ajustes', 'Mecanismo', Icons.settings_applications_outlined),
      ('maq_torno', 'Torno', Icons.rotate_right_rounded),
      ('maq_prensa', 'Prensa', Icons.compress_rounded),
      ('maq_cinta', 'Cinta transportadora', Icons.conveyor_belt),
      ('maq_carretilla', 'Carretilla elevadora', Icons.forklift),
      ('maq_grua', 'Grúa', Icons.construction_rounded),
      ('maq_excavadora', 'Excavadora', Icons.front_loader),
      ('maq_hormigonera', 'Hormigonera', Icons.blender_outlined),
      ('maq_palet', 'Palé', Icons.pallet),
      ('maq_caja', 'Embalaje', Icons.inventory_2_outlined),
      ('maq_almacen', 'Almacén', Icons.warehouse_outlined),
      ('maq_estanteria', 'Estantería', Icons.shelves),
      ('maq_balanza', 'Báscula', Icons.scale_outlined),
      ('maq_impresora', 'Impresora industrial', Icons.print_outlined),
      ('maq_escaner', 'Lector', Icons.qr_code_scanner_rounded),
      ('maq_lavado', 'Lavadora industrial', Icons.local_laundry_service_outlined),
      ('maq_cocina', 'Cocina industrial', Icons.soup_kitchen_outlined),
      ('maq_microondas', 'Horno', Icons.microwave_outlined),
      ('maq_ascensor', 'Ascensor', Icons.elevator_outlined),
      ('maq_escalera', 'Escalera mecánica', Icons.escalator_outlined),
      ('maq_puerta', 'Puerta automática', Icons.sensor_door_outlined),
      ('maq_persiana', 'Persiana / portón', Icons.garage_outlined),
    ],
  ),
  (
    'Fluidos y presión',
    [
      ('flu_valvula', 'Válvula', Icons.tune_outlined),
      ('flu_tuberia', 'Tubería', Icons.plumbing_rounded),
      ('flu_grifo', 'Grifo', Icons.water_damage_outlined),
      ('flu_agua', 'Agua', Icons.water_outlined),
      ('flu_gota', 'Gota', Icons.opacity_rounded),
      ('flu_aceite', 'Aceite', Icons.oil_barrel_outlined),
      ('flu_propano', 'Gas', Icons.propane_tank_outlined),
      ('flu_propano2', 'Bombona', Icons.propane_outlined),
      ('flu_presion', 'Presión', Icons.compress_rounded),
      ('flu_manometro', 'Manómetro', Icons.speed_rounded),
      ('flu_vapor', 'Vapor', Icons.cloud_outlined),
      ('flu_filtro', 'Filtro', Icons.filter_alt_outlined),
      ('flu_aspersor', 'Aspersor', Icons.shower_outlined),
      ('flu_piscina', 'Depósito / piscina', Icons.pool_outlined),
      ('flu_ola', 'Caudal', Icons.waves_rounded),
      ('flu_lavabo', 'Sanitario', Icons.wash_outlined),
    ],
  ),
  (
    'Aire y clima',
    [
      ('cli_ventilador', 'Ventilador', Icons.mode_fan_off_outlined),
      ('cli_aire', 'Aire', Icons.air_rounded),
      ('cli_climatizador', 'Climatizador', Icons.ac_unit_rounded),
      ('cli_calor', 'Calefacción', Icons.heat_pump_outlined),
      ('cli_termometro', 'Temperatura', Icons.thermostat_outlined),
      ('cli_fuego', 'Quemador / llama', Icons.local_fire_department_outlined),
      ('cli_caldera', 'Caldera', Icons.fireplace_outlined),
      ('cli_humedad', 'Humedad', Icons.water_drop_outlined),
      ('cli_purificador', 'Purificador', Icons.air_outlined),
      ('cli_chimenea', 'Chimenea', Icons.roofing_outlined),
      ('cli_nieve', 'Frío / cámara', Icons.severe_cold_rounded),
      ('cli_sol', 'Solar térmica', Icons.wb_sunny_outlined),
    ],
  ),
  (
    'Electricidad y energía',
    [
      ('ele_rayo', 'Energía', Icons.bolt_rounded),
      ('ele_enchufe', 'Toma', Icons.power_outlined),
      ('ele_cuadro', 'Cuadro eléctrico', Icons.electric_meter_outlined),
      ('ele_bateria', 'Batería', Icons.battery_charging_full_rounded),
      ('ele_solar', 'Placa solar', Icons.solar_power_outlined),
      ('ele_eolico', 'Aerogenerador', Icons.wind_power_outlined),
      ('ele_generador', 'Generador', Icons.electric_bolt_rounded),
      ('ele_cargador', 'Cargador', Icons.ev_station_outlined),
      ('ele_bombilla', 'Iluminación', Icons.lightbulb_outline_rounded),
      ('ele_foco', 'Foco', Icons.highlight_outlined),
      ('ele_cable', 'Cableado', Icons.cable_rounded),
      ('ele_interruptor', 'Interruptor', Icons.toggle_on_outlined),
      ('ele_torre', 'Torre eléctrica', Icons.cell_tower_rounded),
      ('ele_transformador', 'Transformador', Icons.electrical_services_rounded),
      ('ele_nuclear', 'Radiación', Icons.warning_amber_rounded),
    ],
  ),
  (
    'Control y electrónica',
    [
      ('ctl_chip', 'Controlador', Icons.memory_rounded),
      ('ctl_router', 'Router', Icons.router_outlined),
      ('ctl_servidor', 'Servidor', Icons.dns_outlined),
      ('ctl_ordenador', 'Ordenador', Icons.computer_outlined),
      ('ctl_pantalla', 'Pantalla', Icons.monitor_outlined),
      ('ctl_tablet', 'Panel táctil', Icons.tablet_android_outlined),
      ('ctl_sensor', 'Sensor', Icons.sensors_rounded),
      ('ctl_wifi', 'Red', Icons.wifi_rounded),
      ('ctl_antena', 'Antena', Icons.settings_input_antenna_rounded),
      ('ctl_camara', 'Cámara', Icons.videocam_outlined),
      ('ctl_alarma', 'Alarma', Icons.notifications_active_outlined),
      ('ctl_reloj', 'Temporizador', Icons.timer_outlined),
      ('ctl_grafico', 'Monitorización', Icons.monitor_heart_outlined),
      ('ctl_dial', 'Regulador', Icons.tune_rounded),
      ('ctl_almacenamiento', 'Almacenamiento', Icons.storage_rounded),
      ('ctl_huella', 'Control de acceso', Icons.fingerprint_rounded),
    ],
  ),
  (
    'Vehículos',
    [
      ('veh_coche', 'Coche', Icons.directions_car_outlined),
      ('veh_furgoneta', 'Furgoneta', Icons.airport_shuttle_outlined),
      ('veh_autobus', 'Autobús', Icons.directions_bus_outlined),
      ('veh_tren', 'Tren', Icons.train_outlined),
      ('veh_barco', 'Barco', Icons.directions_boat_outlined),
      ('veh_avion', 'Avión', Icons.flight_outlined),
      ('veh_moto', 'Moto', Icons.two_wheeler_outlined),
      ('veh_bici', 'Bicicleta', Icons.pedal_bike_outlined),
      ('veh_patinete', 'Patinete', Icons.electric_scooter_outlined),
      ('veh_tranvia', 'Tranvía', Icons.tram_outlined),
      ('veh_remolque', 'Remolque', Icons.rv_hookup_outlined),
      ('veh_rueda', 'Neumático', Icons.tire_repair_outlined),
      ('veh_lavado', 'Túnel de lavado', Icons.local_car_wash_outlined),
      ('veh_aparcamiento', 'Aparcamiento', Icons.local_parking_rounded),
    ],
  ),
  (
    'Herramientas',
    [
      ('her_llave', 'Llave', Icons.build_circle_outlined),
      ('her_martillo', 'Martillo', Icons.hardware_outlined),
      ('her_carpinteria', 'Carpintería', Icons.carpenter_outlined),
      ('her_pintura', 'Pintura', Icons.format_paint_outlined),
      ('her_rodillo', 'Rodillo', Icons.imagesearch_roller_outlined),
      ('her_cepillo', 'Limpieza', Icons.cleaning_services_outlined),
      ('her_regla', 'Medición', Icons.straighten_rounded),
      ('her_escuadra', 'Escuadra', Icons.square_foot_rounded),
      ('her_tijeras', 'Corte', Icons.content_cut_rounded),
      ('her_soldadura', 'Soldadura', Icons.flash_on_rounded),
      ('her_hacha', 'Hacha', Icons.forest_outlined),
      ('her_tornillo', 'Fijación', Icons.hive_outlined),
      ('her_casco', 'Seguridad', Icons.engineering_outlined),
      ('her_extintor', 'Extintor', Icons.fire_extinguisher_rounded),
      ('her_botiquin', 'Botiquín', Icons.medical_services_outlined),
      ('her_escalera', 'Escalera', Icons.stairs_outlined),
    ],
  ),
  (
    'Instalaciones',
    [
      ('ins_edificio', 'Edificio', Icons.apartment_outlined),
      ('ins_nave', 'Nave', Icons.home_work_outlined),
      ('ins_oficina', 'Oficina', Icons.business_outlined),
      ('ins_tienda', 'Tienda', Icons.storefront_outlined),
      ('ins_hospital', 'Hospital', Icons.local_hospital_outlined),
      ('ins_colegio', 'Colegio', Icons.school_outlined),
      ('ins_hotel', 'Hotel', Icons.hotel_outlined),
      ('ins_restaurante', 'Restaurante', Icons.restaurant_outlined),
      ('ins_gasolinera', 'Gasolinera', Icons.local_gas_station_rounded),
      ('ins_laboratorio', 'Laboratorio', Icons.science_outlined),
      ('ins_bio', 'Biotecnología', Icons.biotech_outlined),
      ('ins_reciclaje', 'Reciclaje', Icons.recycling_rounded),
      ('ins_basura', 'Residuos', Icons.delete_outline_rounded),
      ('ins_jardin', 'Jardín', Icons.yard_outlined),
      ('ins_puente', 'Estructura', Icons.account_balance_outlined),
      ('ins_valla', 'Vallado', Icons.fence_outlined),
    ],
  ),
  (
    'Señales',
    [
      ('sen_aviso', 'Aviso', Icons.report_problem_outlined),
      ('sen_info', 'Información', Icons.info_outline_rounded),
      ('sen_estrella', 'Importante', Icons.star_outline_rounded),
      ('sen_bandera', 'Marcado', Icons.flag_outlined),
      ('sen_candado', 'Bloqueado', Icons.lock_outline_rounded),
      ('sen_escudo', 'Protegido', Icons.shield_outlined),
      ('sen_etiqueta', 'Etiqueta', Icons.label_outline_rounded),
      ('sen_ubicacion', 'Ubicación', Icons.place_outlined),
      ('sen_cubo', 'Pieza', Icons.view_in_ar_outlined),
      ('sen_capas', 'Conjunto', Icons.layers_outlined),
      ('sen_categoria', 'Categoría', Icons.category_outlined),
      ('sen_circulo', 'Genérico', Icons.circle_outlined),
    ],
  ),
];

/// Equipos de proceso dibujados a mano (no existen en Material): SVG de 24 px y trazo 2, como los Material,
/// en `assets/iconos/<nombre>.svg`. La clave lleva delante `pq_`.
const iconosDibujados = <(String, String)>[
  ('pq_bomba_centrifuga', 'Bomba centrífuga'),
  ('pq_bomba_engranajes', 'Bomba de engranajes'),
  ('pq_bomba_embolo', 'Bomba de émbolo'),
  ('pq_bomba_diafragma', 'Bomba de diafragma'),
  ('pq_intercambiador_tubos', 'Intercambiador de tubos'),
  ('pq_intercambiador_placas', 'Intercambiador de placas'),
  ('pq_agitador', 'Agitador'),
  ('pq_tanque_homogeneizacion', 'Tanque de homogeneización'),
  ('pq_isotanque', 'Isotanque'),
  ('pq_contenedor', 'Contenedor'),
  ('pq_cisterna', 'Cisterna'),
  ('pq_deposito_horizontal', 'Depósito horizontal'),
  ('pq_esfera_glp', 'Esfera de GLP'),
  ('pq_silo', 'Silo'),
  ('pq_columna_destilacion', 'Columna de destilación'),
  ('pq_reactor', 'Reactor encamisado'),
  ('pq_ciclon', 'Ciclón separador'),
  ('pq_manometro', 'Manómetro'),
  ('pq_transmisor_presion', 'Transmisor de presión'),
  ('pq_caudalimetro', 'Caudalímetro'),
  ('pq_instrumento', 'Instrumento'),
  ('pq_valvula_seguridad', 'Válvula de seguridad'),
  ('pq_valvula_compuerta', 'Válvula de compuerta'),
  ('pq_valvula_bola', 'Válvula de bola'),
  ('pq_valvula_retencion', 'Válvula de retención'),
  ('pq_compresor', 'Compresor'),
  ('pq_soplante', 'Soplante'),
  ('pq_secador', 'Secador'),
  ('pq_filtro_cesta', 'Filtro de cesta'),
  ('pq_horno_proceso', 'Horno de proceso'),
  ('pq_antorcha', 'Antorcha'),
  ('pq_brida', 'Bridas'),
  ('pq_motor_electrico', 'Motor eléctrico'),
];

/// Todos los iconos que se pueden elegir, como (clave, nombre).
final todosLosIconos = <(String, String)>[
  for (final i in iconosIndustriales) (i.$1, i.$2),
  ...iconosDibujados,
  for (final g in gruposIconos)
    for (final i in g.$2) (i.$1, i.$2),
];

IconData iconoIndustrial(String clave) => [
  ...iconosIndustriales,
  for (final g in gruposIconos) ...g.$2,
].firstWhere((i) => i.$1 == clave, orElse: () => iconosIndustriales.first).$3;

/// Icono de un activo: de Material o dibujado (SVG). Sin color, el del tema de iconos (como [Icon]).
class IconoActivo extends StatelessWidget {
  final String clave;
  final double? size;
  final Color? color;
  const IconoActivo(this.clave, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    if (!clave.startsWith('pq_')) return Icon(iconoIndustrial(clave), size: size, color: color);
    final tema = IconTheme.of(context);
    final lado = size ?? tema.size ?? 24;
    // Los Material dejan ~2 px de aire en 24; los dibujados también, así que miden lo mismo.
    return SvgPicture.asset(
      'assets/iconos/${clave.substring(3)}.svg',
      width: lado,
      height: lado,
      colorFilter: ColorFilter.mode(color ?? tema.color ?? P.texto, BlendMode.srcIn),
    );
  }
}

/// Ventana con el catálogo amplio: buscador y los iconos por grupos. Devuelve la clave elegida.
Future<String?> elegirIcono(BuildContext context, String actual) => showDialog<String>(
  context: context,
  builder: (c) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
      child: _CatalogoIconos(actual),
    ),
  ),
);

class _CatalogoIconos extends StatefulWidget {
  final String actual;
  const _CatalogoIconos(this.actual);

  @override
  State<_CatalogoIconos> createState() => _CatalogoIconosState();
}

class _CatalogoIconosState extends State<_CatalogoIconos> {
  String q = '';

  Widget _boton((String, String) i) {
    final (clave, nombre) = i;
    final elegido = clave == widget.actual;
    return IconButton(
      tooltip: nombre,
      isSelected: elegido,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: elegido ? P.morado.withValues(alpha: .1) : Colors.transparent,
        foregroundColor: elegido ? P.morado : P.textoSuave,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
      ),
      onPressed: () => Navigator.pop(context, clave),
      icon: IconoActivo(clave, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = q.trim().toLowerCase();
    final grupos =
        <(String, List<(String, String)>)>[
              ('Equipos de proceso', iconosDibujados),
              ('Básicos', [for (final i in iconosIndustriales) (i.$1, i.$2)]),
              for (final g in gruposIconos) (g.$1, [for (final i in g.$2) (i.$1, i.$2)]),
            ]
            .map(
              (g) => (
                g.$1,
                [
                  for (final i in g.$2)
                    if (t.isEmpty || i.$2.toLowerCase().contains(t) || g.$1.toLowerCase().contains(t)) i,
                ],
              ),
            )
            .where((g) => g.$2.isNotEmpty)
            .toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Iconos',
            style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${todosLosIconos.length} iconos para máquinas, piezas e instalaciones.',
            style: TextStyle(fontSize: 13, color: P.textoSuave),
          ),
          const SizedBox(height: 14),
          Buscador(hint: 'Buscar icono…', onChanged: (v) => setState(() => q = v)),
          const SizedBox(height: 10),
          Flexible(
            child: grupos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Ningún icono coincide',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: P.textoSuave),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (titulo, iconos) in grupos) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            titulo,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: P.textoSuave),
                          ),
                        ),
                        Wrap(spacing: 4, runSpacing: 4, children: [for (final i in iconos) _boton(i)]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
